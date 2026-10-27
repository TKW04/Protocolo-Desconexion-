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
    world2(s, rng)
    world3(s, rng)
    hub_4_6(s, rng)
    return s


def loop_bars(notes: list[float], step: float, wave_fn, bass: list[float], beat: float) -> np.ndarray:
    """Bucle de chiptune suave: arpegio `notes` cada `step` s sobre un bajo de una
    nota por compas (`bass`, 4 tiempos de `beat` s). Sin costura: la duracion es
    un numero entero de pasos y todo se apaga dentro de su paso."""
    bars = len(bass)
    dur = bars * 4 * beat
    out = np.zeros(int(round(dur * RATE)))
    n = int(round(dur / step))
    for i in range(n):
        out = mix_at(out, 0.5 * note(notes[i % len(notes)], step * 0.9, wave_fn, 1.6), i * step)
    for b, f in enumerate(bass):
        for k in range(4):
            out = mix_at(out, 0.6 * note(f, beat * 0.8, tri, 1.0), (b * 4 + k) * beat)
    return out


def world2(s: dict[str, np.ndarray], rng: np.random.Generator) -> None:
    """Mundo 2 «El Feed» (paso 20 de docs/propuesta-mundo-2.md, §6.4): provisionales con los IDs de
    data/audio.json; los definitivos los hace el amigo del usuario con el mismo nombre."""
    # Golpe al suelo: caida corta y golpe grave con polvo.
    d = 0.32
    thump = sine(sweep(140, 45, d), d) * env(len(t_axis(d)), 0.002, 0.15, 1.6)
    dust = 0.35 * lowpass(noise(d, rng), 1200) * env(len(t_axis(d)), 0.001, 0.12, 2.5)
    s["sfx_gesture_ground_pound"] = mix_at(np.zeros(int(0.36 * RATE)), thump + dust, 0.04)
    # Video que arranca su clip: «tic» de play.
    s["sfx_w2_autoplay_start"] = np.concatenate([note(660, 0.04, tri, 2), note(880, 0.08, soft_square, 1.4)])
    # Tarjeta fragil: grieta (ruido agudo corto) y rotura (ruido + caida).
    d = 0.12
    s["sfx_w2_card_crack"] = lowpass(noise(d, rng), 4000) * env(len(t_axis(d)), 0.001, 0.05, 3)
    d = 0.3
    s["sfx_w2_card_break"] = (0.7 * lowpass(noise(d, rng), 2500) + 0.4 * tri(sweep(500, 180, d), d)) \
        * env(len(t_axis(d)), 0.001, 0.12, 1.8)
    # Historia: contador (accesibilidad): dos tics.
    s["sfx_w2_story_timer"] = np.concatenate([note(1046, 0.05, tri, 2), np.zeros(int(0.06 * RATE)),
        note(1046, 0.05, tri, 2)])
    # Nace un clon: burbuja que sube.
    d = 0.18
    s["sfx_w2_clone_spawn"] = soft_square(sweep(330, 760, d), d, 2) * env(len(t_axis(d)), 0.005, 0.06, 1.2)
    # Comentarista escupe: «ptu» corto.
    d = 0.14
    s["sfx_w2_commenter_spit"] = (tri(sweep(900, 400, d), d) + 0.3 * lowpass(noise(d, rng), 2000)) \
        * env(len(t_axis(d)), 0.002, 0.06, 2)
    # Cambio o inversion del scroll (accesibilidad): tres notas que suben.
    s["sfx_w2_scroll_speed"] = np.concatenate([note(523, 0.06, tri, 2), note(659, 0.06, tri, 2),
        note(784, 0.1, tri, 1.5)])
    # El reloj salta una hora: dos campanadas suaves.
    s["sfx_w2_clock_skip"] = np.concatenate([note(784, 0.12, sine, 1.2), note(587, 0.2, sine, 1.0)])
    # Tocar el borde: zumbido grave de error.
    d = 0.25
    s["sfx_w2_edge_hit"] = soft_square(sweep(220, 150, d), d, 3) * env(len(t_axis(d)), 0.003, 0.1, 1.2)
    # El bucle se repite (sutil): un «swish» bajo.
    d = 0.35
    s["sfx_w2_loop_wrap"] = 0.6 * lowpass(noise(d, rng), 700) * env(len(t_axis(d)), 0.1, 0.2, 0.8)
    # Muro «Cargando mas...»: crujido.
    d = 0.2
    s["sfx_w2_loading_wall_crack"] = (lowpass(noise(d, rng), 1800) + 0.5 * sine(sweep(160, 90, d), d)) \
        * env(len(t_axis(d)), 0.001, 0.08, 2)
    # Reproductor: el gesto obtenido (pausa: dos notas que bajan y se quedan).
    s["sfx_w2_pause_player"] = np.concatenate([note(784, 0.12, soft_square, 1.2), note(523, 0.3, tri, 0.8)])
    # Ambiente del feed: aire con un pulso de «scroll» lento, en bucle sin costura (8 s).
    d = 8.0
    t = t_axis(d)
    air = lowpass(noise(d, rng), 500)
    fade = int(0.5 * RATE)
    ramp = np.linspace(0, 1, fade)
    air[:fade] = air[:fade] * ramp + air[-fade:] * (1 - ramp)
    air = air[: len(t) - fade]
    t = t[: len(air)]
    hum = 0.2 * sine(90, len(t) / RATE)
    swell = 1 + 0.2 * np.sin(2 * np.pi * 4 * t / (len(t) / RATE))
    s["amb_w2_feed"] = normalize(air / max(np.max(np.abs(air)), 1e-9) * 0.8 * swell + hum, 10 ** (-18 / 20))
    # Musica del nivel (bucle de 8 s) y del jefe (la misma mezcla, mas rapida y con pulso).
    s["mus_w2_level"] = normalize(loop_bars([523, 659, 784, 659], 0.25, tri, [131, 175, 147, 196], 0.5),
        10 ** (-14 / 20))
    s["mus_boss2"] = normalize(loop_bars([523, 784, 659, 988, 784, 659], 0.125, soft_square, [131, 131, 175, 196], 0.375),
        10 ** (-14 / 20))
    # Jefe: intro (play que arranca), miniatura del clip, cuenta, pausa y reanudar.
    s["sfx_boss2_intro"] = np.concatenate([note(392, 0.1, soft_square, 1.2), note(523, 0.1, soft_square, 1.2),
        note(784, 0.3, soft_square, 0.8)])
    s["sfx_boss2_clip_preview"] = np.concatenate([note(988, 0.04, tri, 2), note(1175, 0.06, tri, 2)])
    s["sfx_boss2_countdown"] = note(880, 0.09, soft_square, 1.8)
    s["sfx_boss2_pause"] = np.concatenate([note(659, 0.08, soft_square, 1.5), note(440, 0.18, tri, 1.0)])
    s["sfx_boss2_resume"] = np.concatenate([note(440, 0.08, soft_square, 1.5), note(659, 0.12, tri, 1.2)])


def world3(s: dict[str, np.ndarray], rng: np.random.Generator) -> None:
    """Mundo 3 «La Vitrina» (paso 19 de docs/propuesta-mundo-3.md, §6.4): provisionales con los IDs de
    data/audio.json; los definitivos los hace el amigo del usuario con el mismo nombre. Va despues de
    world2: el generador de ruido es comun y asi los del Mundo 1 y 2 no cambian."""
    # Pellizcar y recuperar el tamano: barrido que baja (se encoge) y que sube.
    d = 0.18
    s["sfx_gesture_pinch"] = tri(sweep(880, 440, d), d) * env(len(t_axis(d)), 0.004, 0.07, 1.4)
    s["sfx_gesture_unpinch"] = tri(sweep(440, 880, d), d) * env(len(t_axis(d)), 0.004, 0.07, 1.4)
    # Likes: coger un corazon (dos notas que suben), el Ladron roba (dos que bajan con «zip»).
    s["sfx_w3_like_collect"] = np.concatenate([note(988, 0.04, sine, 2), note(1319, 0.07, sine, 1.6)])
    d = 0.2
    zip_ = 0.4 * lowpass(noise(d, rng), 3000) * env(len(t_axis(d)), 0.002, 0.08, 2)
    s["sfx_w3_like_stolen"] = mix_at(np.concatenate([note(784, 0.06, tri, 2), note(523, 0.12, tri, 1.5)]),
        zip_, 0.0)
    # Plataforma de likes que aparece o avisa: acorde corto de cristal.
    s["sfx_w3_like_platform"] = mix_at(note(659, 0.2, sine, 1.4), 0.5 * note(988, 0.18, sine, 1.8), 0.02)
    # Publicacion (suma likes) y «Borrar publicaciones» (los quita).
    s["sfx_w3_like_source"] = np.concatenate([note(784, 0.05, tri, 2), note(988, 0.05, tri, 2),
        note(1175, 0.09, tri, 1.5)])
    d = 0.3
    s["sfx_w3_like_reset"] = (0.5 * lowpass(noise(d, rng), 1500) + 0.5 * tri(sweep(660, 220, d), d)) \
        * env(len(t_axis(d)), 0.002, 0.12, 1.4)
    # Flash: carga (zumbido que sube, aviso obligatorio) y disparo (destello blanco de ruido).
    d = 0.6
    s["sfx_w3_flash_charge"] = sine(sweep(400, 1600, d), d) * env(len(t_axis(d)), 0.05, 0.05, 0.6) * 0.6
    d = 0.25
    s["sfx_w3_flash"] = (lowpass(noise(d, rng), 6000) + 0.3 * sine(2093, d)) * env(len(t_axis(d)), 0.001, 0.1, 2.5)
    # Rebote en un espejo: «ting» metalico.
    d = 0.22
    s["sfx_w3_mirror_bounce"] = sum(a * sine(f, d) * np.exp(-t_axis(d) * r) for f, a, r in
        [(1568, 1.0, 14), (1568 * 2.4, 0.3, 22)]) * env(len(t_axis(d)), 0.001, 0.05, 0.4)
    # Filtro cerca (peligro oculto): brillo desafinado (dos senos a 7 Hz de distancia).
    d = 0.6
    s["sfx_w3_filter_shimmer"] = 0.5 * (sine(1046, d) + sine(1053, d)) * np.sin(np.pi * t_axis(d) / d) ** 2
    # «Recortar»: el gesto obtenido (tijeretazo y nota que se queda).
    d = 0.08
    snip = lowpass(noise(d, rng), 5000) * env(len(t_axis(d)), 0.001, 0.03, 4)
    s["sfx_w3_crop_tool"] = np.concatenate([snip, snip, note(659, 0.3, tri, 0.9)])
    # Giro del espejo cazador (accesibilidad, acompana al brillo): tic doble agudo.
    s["sfx_w3_hunter_turn"] = np.concatenate([note(1397, 0.03, tri, 2), np.zeros(int(0.04 * RATE)),
        note(1760, 0.04, tri, 2)])
    # Sale un Reflejo falso: barrido de cristal hacia arriba.
    d = 0.3
    s["sfx_w3_reflection_spawn"] = 0.6 * sine(sweep(523, 1046, d) * (1 + 0.01 * np.sin(2 * np.pi * 9 * t_axis(d))), d) \
        * env(len(t_axis(d)), 0.02, 0.15, 1.0)
    # Placa de pose pisada: «clac» grave.
    d = 0.12
    s["sfx_w3_pose_plate"] = (sine(sweep(180, 110, d), d) + 0.3 * lowpass(noise(d, rng), 1500)) \
        * env(len(t_axis(d)), 0.001, 0.05, 2)
    # Ambiente de la galeria: aire de sala con un brillo lejano, en bucle sin costura (8 s).
    d = 8.0
    t = t_axis(d)
    air = lowpass(noise(d, rng), 450)
    fade = int(0.5 * RATE)
    ramp = np.linspace(0, 1, fade)
    air[:fade] = air[:fade] * ramp + air[-fade:] * (1 - ramp)
    air = air[: len(t) - fade]
    t = t[: len(air)]
    hum = 0.12 * sine(110, len(t) / RATE) + 0.05 * sine(880, len(t) / RATE)
    swell = 1 + 0.15 * np.sin(2 * np.pi * 2 * t / (len(t) / RATE))
    s["amb_w3_gallery"] = normalize(air / max(np.max(np.abs(air)), 1e-9) * 0.8 * swell + hum, 10 ** (-18 / 20))
    # Musica del nivel (bucle de 8 s, vals lento de galeria) y del jefe (mas rapida, con pulso).
    s["mus_w3_level"] = normalize(loop_bars([659, 784, 988, 784], 0.25, sine, [165, 220, 196, 147], 0.5),
        10 ** (-14 / 20))
    s["mus_boss3"] = normalize(loop_bars([659, 988, 784, 1175, 988, 784], 0.125, tri, [165, 165, 220, 196], 0.375),
        10 ** (-14 / 20))
    # Jefe: intro (obturador y «3-2-1»), se gira de espaldas y el marco que se cierra (accesibilidad).
    d = 0.05
    shutter = lowpass(noise(d, rng), 4000) * env(len(t_axis(d)), 0.001, 0.02, 3)
    s["sfx_boss3_intro"] = np.concatenate([shutter, np.zeros(int(0.05 * RATE)), note(523, 0.1, sine, 1.2),
        note(659, 0.1, sine, 1.2), note(988, 0.3, sine, 0.8)])
    d = 0.4
    s["sfx_boss3_turn"] = (0.6 * lowpass(noise(d, rng), 900) + 0.5 * tri(sweep(330, 196, d), d)) \
        * env(len(t_axis(d)), 0.05, 0.15, 1.0)
    d = 0.5
    s["sfx_boss3_frame_close"] = soft_square(sweep(196, 392, d), d, 2) * env(len(t_axis(d)), 0.01, 0.08, 0.8) * 0.7


def hub_4_6(s: dict[str, np.ndarray], rng: np.random.Generator) -> None:
    """Hub de los Mundos 4-6 (paso 7 de docs/propuesta-hub-mundos-4-6.md, 2026-10-27): acertijo
    «Actualizacion del sistema», instalacion, paginas y candado. Va despues de world3 (el generador de
    ruido es comun: asi los anteriores no cambian)."""
    # Verificacion completada: tres notas que suben, limpias (sin rojo: nada hace dano en el hub).
    s["sfx_hub_update_check"] = np.concatenate([note(659, 0.05, tri, 2), note(784, 0.05, tri, 2),
        note(1046, 0.14, sine, 1.2)])
    # Instalacion en marcha (la barra de 3 s): pulso que sube con tics de progreso.
    d = 3.0
    t = t_axis(d)
    rise = 0.35 * tri(sweep(220, 440, d), d) * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t) ** 2)
    ticks = np.zeros(len(t))
    for k in range(12):
        ticks = mix_at(ticks, 0.4 * note(880 + 40 * k, 0.03, tri, 2), k * 0.25)
    s["sfx_hub_install_bar"] = (rise + ticks) * env(len(t), 0.05, 0.1, 1.0)
    # Instalacion terminada (el destello): acorde que se abre.
    d = 0.7
    chord = sum(a * note(f, d, sine, 0.7) for f, a in ((523, 0.6), (659, 0.5), (784, 0.5), (1046, 0.4)))
    sparkle = 0.15 * lowpass(noise(d, rng), 6000) * env(len(t_axis(d)), 0.001, 0.2, 2.5)
    s["sfx_hub_install"] = chord + sparkle
    # Deslizar de pagina: «swish» corto y suave.
    d = 0.3
    s["sfx_hub_page_slide"] = 0.6 * lowpass(noise(d, rng), 1400) * np.sin(np.pi * t_axis(d) / d) ** 2 \
        + 0.15 * sine(sweep(300, 500, d), d) * env(len(t_axis(d)), 0.05, 0.1)
    # Carpeta bloqueada (candado): «clac» metalico corto.
    d = 0.15
    s["sfx_hub_folder_locked"] = (0.6 * sine(sweep(900, 600, d), d) * np.exp(-t_axis(d) * 30)
        + 0.3 * lowpass(noise(d, rng), 3000) * env(len(t_axis(d)), 0.001, 0.03, 4))


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
        quiet = name.startswith(("amb_", "mus_", "sfx_isak_step"))
        write_wav(os.path.join(args.out, name + ".wav"), data if quiet else normalize(data))
        written += 1
    print(f"gen_audio_placeholders: {written} archivos en {os.path.relpath(args.out, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
