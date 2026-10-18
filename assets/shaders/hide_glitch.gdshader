// Ocultarte (Pulso 4, tanda M2 de las mejoras de Calc; data/hide_mode.json):
// Isak semitransparente con glitch de filas horizontales, tinte y contorno de
// 1 px en acento cian (el mismo en todos los mundos), sin hoja nueva de Isak.
// Lo pone HideMode en el AnimatedSprite2D de Isak solo mientras hace falta.
// amount: 0-1 (entrada y salida de 0,2 s). warn: 0-1 (aviso: Sync o energia por
// debajo del 20 %: glitch mas fuerte y parpadeo). flash: 0-1 (destello al cortarse
// solo). Pixeles de textura: el sprite de Isak se dibuja a escala 1.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_hidden : hint_range(0.0, 1.0) = 0.45;
uniform float tint : hint_range(0.0, 1.0) = 0.25;
uniform vec4 outline_color : source_color = vec4(0.239, 1.0, 0.961, 1.0);
uniform float glitch_px = 2.0;
uniform float warn_glitch_px = 3.0;
uniform float row_px = 3.0;
uniform float time_s = 0.0;
uniform float glitch_hz = 12.0;
uniform float warn : hint_range(0.0, 1.0) = 0.0;
uniform float warn_alpha : hint_range(0.0, 1.0) = 0.25;
uniform float warn_blink_hz = 6.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

// Color de modulate (y el parpadeo de la invulnerabilidad) sin la textura: en
// fragment() COLOR ya trae el texel multiplicado.
varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// 1 dentro de la textura, 0 fuera (sin repetir bordes).
float inside(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float tick = floor(time_s * glitch_hz);
	float band = floor(UV.y / px.y / max(row_px, 1.0));
	float h = hash(band * 7.13 + tick * 3.71);
	float strength = clamp(amount + flash, 0.0, 1.0);
	float max_shift = mix(glitch_px, warn_glitch_px, warn) + flash * warn_glitch_px;
	float dir = h > 0.8 ? 1.0 : (h < 0.12 ? -1.0 : 0.0);
	float shift = floor(dir * max_shift * strength * (0.5 + 0.5 * hash(band + tick)) + 0.5);
	vec2 uv = UV + vec2(shift * px.x, 0.0);
	vec4 c = texture(TEXTURE, uv) * inside(uv);
	vec2 r = uv + vec2(px.x, 0.0);
	vec2 l = uv - vec2(px.x, 0.0);
	vec2 d = uv + vec2(0.0, px.y);
	vec2 u = uv - vec2(0.0, px.y);
	float near = texture(TEXTURE, r).a * inside(r) + texture(TEXTURE, l).a * inside(l)
			+ texture(TEXTURE, d).a * inside(d) + texture(TEXTURE, u).a * inside(u);
	vec4 col = c;
	// Tinte cian y, en las filas que el glitch desplaza, un brillo cian mas fuerte.
	col.rgb = mix(col.rgb, outline_color.rgb, clamp(tint * strength + abs(dir) * 0.35 * strength, 0.0, 1.0));
	if (c.a < 0.5 && near > 0.5) {
		col = vec4(outline_color.rgb, strength);
	}
	float a = mix(1.0, alpha_hidden, amount);
	float blink = step(0.5, fract(time_s * warn_blink_hz));
	a = mix(a, min(a, warn_alpha), warn * amount * blink);
	col.a *= max(a, flash * 0.9);
	COLOR = col * modulate_color;
}
