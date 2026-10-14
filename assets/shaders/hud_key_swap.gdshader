// HUD: sustituye un color clave del arte por otro (cambio de paleta exacto, sin mezclas).
// Uso: la bateria y el anillo de carga estan dibujados en debug_cian (key_color) y aqui se
// cambian por el color del Debug del mundo actual (data/hud.json, debug_colors); los numeros
// de la fuente estan en banner_blanco y pasan a alerta con Sync Rate bajo. Si key_color y
// target_color coinciden, la imagen sale tal cual. Los colores se pasan sin conversion
// (mismo espacio que la textura en 2D).
shader_type canvas_item;

uniform vec4 key_color = vec4(0.239, 1.0, 0.961, 1.0);
uniform vec4 target_color = vec4(0.239, 1.0, 0.961, 1.0);
// Distancia RGB maxima para considerar que un pixel es el color clave (medio paso de 8 bits).
uniform float tolerance = 0.004;

varying vec4 vertex_modulate;

void vertex() {
	vertex_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	if (all(lessThanEqual(abs(rgb - key_color.rgb), vec3(tolerance)))) {
		rgb = target_color.rgb;
	}
	COLOR = vec4(rgb, tex.a) * vertex_modulate;
}
