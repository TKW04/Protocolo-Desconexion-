#!/usr/bin/env python3
"""Sonidos PROVISIONALES del juego (2026-10-20; docs/lista-sonidos.md, «Integracion»).

Sintesis simple con numpy + wave (sin IA ni librerias de audio): ondas seno,
triangulo y cuadrada suavizada, ruido filtrado y envolventes cortas, en la
linea del tono general de la lista (chiptune suave, sin agudos estridentes).
Escribe WAV mono de 16 bits a 44,1 kHz en assets/audio/<archivo>.wav, con los
nombres que espera data/audio.json (nombre = ID; variantes con _1, _2...).

Son un andamio para probar la mezcla: el amigo del usuario los sustituye por
los definitivos con el MISMO nombre (.wav u .ogg); este script no se vuelve a
ejecutar sobre los reales (pisaria los .wav con el mismo nombre). Con
--only <id> regenera solo los archivos que empiezan por ese ID.

Uso: python3 tools/gen_audio_placeholders.py [--out assets/audio] [--only sfx_isak_jump]
"""
from __future__ import annotations

import argparse
import os
import sys
import wave

import numpy as np

RATE = 44100
PEAK = 10 ** (-6 / 20)  # -6 dBFS
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * RATE)) / RATE


def phase(freq) -> np.ndarray:
    """Fase acumulada de una frecuencia constante o variable (barridos)."""
    f = np.asarray(freq, dtype=np.float64)
    return 2 * np.pi * np.cumsum(f) / RATE


def sine(freq, dur: float) -> np.ndarray:
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), t_axis(dur).shape)
    return np.sin(phase(f))


def tri(freq, dur: float) -> np.ndarray:
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), t_axis(dur).shape)
    p = (phase(f) / (2 * np.pi)) % 1.0
    return 4 * np.abs(p - 0.5) - 1


def soft_square(freq, dur: float, hardness: float = 4.0) -> np.ndarray:
    """Cuadrada redondeada (tanh de un seno): pulso de chiptune sin aspereza."""
    return np.tanh(hardness * sine(freq, dur)) / np.tanh(hardness)


def noise(dur: float, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1, 1, len(t_axis(dur)))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Filtro de un polo (suaviza ruido y bordes)."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n: int, attack: float = 0.005, release: float = 0.05, curve: float = 1.0) -> np.ndarray:
    """Envolvente ataque lineal + caida exponencial hasta 0 al final."""
    t = np.arange(n) / RATE
    dur = n / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    decay = np.exp(-curve * t / max(dur, 1e-4) * 4)
    r = np.clip((dur - t) / max(release, 1e-4), 0, 1)
    return a * decay * r


def pad(x: np.ndarray, dur: float) -> np.ndarray:
    n = int(dur * RATE)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def mix_at(base: np.ndarray, part: np.ndarray, start: float) -> np.ndarray:
    i = int(start * RATE)
    end = min(len(base), i + len(part))
    base[i:end] += part[: end - i]
    return base


def note(freq: float, dur: float, wave_fn=sine, curve: float = 1.0) -> np.ndarray:
    x = wave_fn(freq, dur)
    return x * env(len(x), 0.004, min(0.05, dur / 3), curve)


def normalize(x: np.ndarray, peak: float = PEAK) -> np.ndarray:
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x if m == 0 else x / m * peak


def sweep(f0: float, f1: float, dur: float) -> np.ndarray:
    return np.linspace(f0, f1, len(t_axis(dur)))


# --- Sonidos ---

def build(rng: np.random.Generator) -> dict[str, np.ndarray]:
    s: dict[str, np.ndarray] = {}
    # Isak: movimiento.
    d = 0.12
    s["sfx_isak_jump"] = soft_square(sweep(300, 620, d), d, 2.5) * env(len(t_axis(d)), 0.004, 0.04, 1.2)
    d = 0.1
    thump = sine(sweep(140, 55, d), d) * env(len(t_axis(d)), 0.002, 0.05, 1.5)
    s["sfx_isak_land"] = thump + 0.25 * lowpass(noise(d, rng), 900) * env(len(t_axis(d)), 0.001, 0.03, 3)
    for i in range(1, 5):
        d = 0.06
        click = lowpass(noise(d, rng), 1400 + 250 * i) * env(len(t_axis(d)), 0.001, 0.03, 4)
        body = 0.5 * sine(150 + 18 * i, d) * env(len(t_axis(d)), 0.001, 0.03, 5)
        s[f"sfx_isak_step_{i}"] = normalize(click + body, 10 ** (-12 / 20))
    # Habilidades.
    d = 0.32
    wob = sine(sweep(220, 440, d) * (1 + 0.04 * np.sin(2 * np.pi * 18 * t_axis(d))), d)
    s["sfx_isak_pulse"] = (wob + 0.35 * tri(sweep(440, 880, d), d)) * env(len(t_axis(d)), 0.01, 0.12, 1.0)
    d = 0.22
    s["sfx_isak_laser_fire"] = tri(sweep(1400, 650, d), d) * env(len(t_axis(d)), 0.002, 0.08, 1.4)
    d = 0.24
    whoosh = lowpass(noise(d, rng), 2200) * np.sin(np.pi * t_axis(d) / d) ** 2
    s["sfx_isak_dash"] = whoosh + 0.3 * sine(sweep(500, 260, d), d) * env(len(t_axis(d)), 0.01, 0.1)
    d = 0.26
    steps = np.repeat(rng.choice([180, 240, 320, 140, 260], 13), int(d * RATE / 13) + 1)[: len(t_axis(d))]
    s["sfx_isak_hurt"] = soft_square(steps, d, 3) * env(len(t_axis(d)), 0.002, 0.08, 1.2)
    # Recogibles e interruptores.
    s["sfx_attention_point"] = np.concatenate([note(880, 0.06, tri, 2), note(1320, 0.1, tri, 1.5)])
    box = np.zeros(int(0.9 * RATE))
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix_at(box, note(f, 0.55, sine, 1.4) + 0.2 * pad(note(f * 2, 0.4, sine, 2.5), 0.55), 0.11 * k)
    s["sfx_memory_pickup"] = box
    d = 0.5
    clk = lowpass(noise(0.02, rng), 3000) * env(len(t_axis(0.02)), 0.0005, 0.01, 3)
    hum = 0.6 * note(196, 0.22, tri, 1.5)
    s["sfx_dnd_switch"] = mix_at(mix_at(np.zeros(int(d * RATE)), clk, 0.0), hum, 0.02)
    s["sfx_checkpoint"] = mix_at(mix_at(mix_at(np.zeros(int(0.55 * RATE)),
        note(523.25, 0.4, tri), 0.0), note(659.25, 0.38, tri), 0.06), note(783.99, 0.36, tri), 0.12)
    # Ritmo (senales de accesibilidad): vibracion grave y avisos suaves.
    d = 0.08
    buzz = soft_square(95, d, 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 35 * t_axis(d)))
    s["sfx_metronome_tick"] = lowpass(buzz, 700) * env(len(t_axis(d)), 0.003, 0.03, 0.8)
    s["sfx_metronome_speedup"] = mix_at(mix_at(np.zeros(int(0.3 * RATE)), s["sfx_metronome_tick"], 0.0),
        s["sfx_metronome_tick"], 0.14)
    warn = np.zeros(int(0.75 * RATE))
    for k, f in enumerate([740, 622, 523]):
        mix_at(warn, note(f, 0.14, sine, 1.5), 0.25 * k)
    s["sfx_blink_warn"] = warn
    d = 0.5
    bell = sum(a * sine(f, d) * np.exp(-t_axis(d) * r) for f, a, r in
        [(392, 1.0, 6), (392 * 2.76, 0.35, 10), (392 * 5.4, 0.12, 16), (196, 0.4, 5)])
    s["sfx_alarm_bell_wave"] = lowpass(bell, 2500) * env(len(t_axis(d)), 0.003, 0.15, 0.4)
    # Blips de texto: Eco por acceso (Cache servicial, Kernel insistente, Raiz seco).
    s["vox_eco_blip_cache"] = note(880, 0.035, sine, 1.5)
    s["vox_eco_blip_kernel"] = note(988, 0.028, lambda f, dd: soft_square(f, dd, 1.6), 1.8)
    s["vox_eco_blip_raiz"] = note(440, 0.03, tri, 3)
    s["vox_calc_blip"] = note(660, 0.03, lambda f, dd: soft_square(f, dd, 3), 1.2)
    s["vox_notas_blip"] = 0.6 * lowpass(noise(0.03, rng), 2500) * env(len(t_axis(0.03)), 0.002, 0.015, 2)
    # UI.
    s["ui_move"] = note(660, 0.04, tri, 2)
    s["ui_confirm"] = np.concatenate([note(660, 0.05, tri, 2), note(990, 0.07, tri, 1.5)])
    s["ui_back"] = np.concatenate([note(660, 0.05, tri, 2), note(494, 0.07, tri, 1.5)])
    # Ambiente del hub: aire de cuarto y zumbido minimo, en bucle sin costura.
    d = 8.0
    t = t_axis(d)
    air = lowpass(noise(d, rng), 380)
    fade = int(0.5 * RATE)
    ramp = np.linspace(0, 1, fade)
    air[:fade] = air[:fade] * ramp + air[-fade:] * (1 - ramp)  # cruce: el final enlaza con el principio
    air = air[: len(t) - fade]
    t = t[: len(air)]
    hum = 0.25 * sine(60, len(t) / RATE) + 0.1 * sine(120, len(t) / RATE)
    swell = 1 + 0.15 * np.sin(2 * np.pi * t / (len(t) / RATE))
    s["amb_hub"] = normalize(air / max(np.max(np.abs(air)), 1e-9) * 0.8 * swell + hum, 10 ** (-18 / 20))
    return s


def write_wav(path: str, data: np.ndarray) -> None:
    pcm = np.clip(data, -1, 1)
    pcm = (pcm * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(ROOT, "assets", "audio"))
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(20261020)
    sounds = build(rng)
    written = 0
    for name, data in sounds.items():
        if args.only and not name.startswith(args.only):
            continue
        quiet = name.startswith(("amb_", "sfx_isak_step"))
        write_wav(os.path.join(args.out, name + ".wav"), data if quiet else normalize(data))
        written += 1
    print(f"gen_audio_placeholders: {written} archivos en {os.path.relpath(args.out, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
