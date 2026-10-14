// Debug Mode (docs 15.6): tinte del color del Debug del mundo y vineta.
// Se dibuja en un CanvasLayer por encima del mundo y por debajo del HUD, asi
// que la textura de pantalla solo contiene el mundo (el HUD no se tine).
// Los valores salen de data/debug_mode.json (DebugOverlay los pasa aqui).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 tint_color : source_color = vec4(0.31, 0.89, 1.0, 1.0);
// 0 = sin efecto, 1 = efecto completo (transicion de entrada/salida).
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Mezcla del tinte sobre la imagen.
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;
// Fraccion de la pantalla, desde cada borde, que ocupa la vineta.
uniform float vignette_size : hint_range(0.0, 0.5) = 0.15;
// Opacidad de la vineta en el borde.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
// Escalones de la vineta (pixel art: sin degradado continuo). 0 = continuo.
uniform float vignette_steps = 3.0;
// Brillo de la version monocroma tenida (compensa la luminancia del color).
uniform float tint_gain = 1.3;
// Oscurecimiento del color del Debug en la vineta.
uniform float vignette_shade = 0.45;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec3 base = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(base, LUMA);
	vec3 mono = luma * tint_color.rgb * tint_gain;
	vec3 color = mix(base, mono, tint_strength * intensity);

	vec2 edge = min(SCREEN_UV, vec2(1.0) - SCREEN_UV);
	vec2 inner = smoothstep(vec2(0.0), vec2(vignette_size), edge);
	float v = 1.0 - inner.x * inner.y;
	if (vignette_steps > 0.0) {
		v = ceil(v * vignette_steps) / vignette_steps;
	}
	color = mix(color, tint_color.rgb * vignette_shade, v * vignette_strength * intensity);
	COLOR = vec4(color, 1.0);
}
