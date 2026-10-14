## Genera scenes/player/isak_frames.tres (SpriteFrames) desde los PNG de Isak.
## Cada animacion cuenta sus cuadros (isak_<anim>_00.png, 01, ...) hasta el
## primero que falte. Los PNG salen de las hojas de hojas/ con
## tools/import_sheet.py (mapeo de celdas en docs/guia-sprites-ia.md, al final).
## Requiere que los PNG esten importados antes (Godot --headless --import).
## Todos los cuadros deben medir FRAME_SIZE (canvas de Isak a 1280x720) con los
## pies en la ultima fila y centrados; isak.tscn coloca el AnimatedSprite2D
## (centrado) en (0, -FRAME_SIZE.y / 2) para que los pies queden en el origen.
## Uso: Godot --headless --path . -s tools/build_isak_frames.gd
extends SceneTree

const SPRITE_DIR: String = "res://assets/sprites/isak/"
const OUTPUT_PATH: String = "res://scenes/player/isak_frames.tres"
const FILE_PATTERN: String = "isak_%s_%02d.png"
## Tamano esperado de cada cuadro (px).
const FRAME_SIZE: Vector2i = Vector2i(128, 128)

## Unico sitio donde se fijan las animaciones: nombre -> [fps, bucle, ping-pong].
## ping-pong: tras el ultimo cuadro repite los intermedios al reves (sin
## archivos extra), para bucles cuyo final no empalma con el principio.
##
## walk (25 cuadros): ~6 pasos por vuelta de ~36 px a escala del juego = ~216 px.
##   A walk_speed (220 px/s) la vuelta debe durar ~0,98 s -> ~25,5 fps; con 24 fps
##   los pies avanzan ~207 px/s: patina ~6 %.
## run (25 cuadros): 8 pasos por vuelta (piernas juntas en los cuadros ~2, 5, 8,
##   11, 14, 16-17, 19 y 22: un paso cada ~3,1 cuadros). La apertura maxima de
##   piernas mide ~130 px de origen y la bota ~25, asi que cada paso avanza
##   ~105 x 0,5393 = ~57 px: 8 x 57 = ~453 px por vuelta. A run_speed (360 px/s)
##   la vuelta debe durar ~1,26 s -> 25 / 1,26 = ~19,9 fps. Con 20 fps los pies
##   avanzan ~363 px/s: patina ~1 % (la estimacion de zancada tiene +/-15 %).
## jump_rise / jump_apex / jump_fall: no se reproducen en el tiempo; Isak elige
##   el cuadro por la velocidad vertical (Isak.update_air_animation).
## jump_land (5 cuadros a 24 fps = 0,21 s): solo visual al aterrizar en Idle.
## pulse (8 cuadros a 24 fps = 0,333 s = pulse_duration_s): el cuadro 0 ya es el
##   celular al frente, cuando nace la onda.
## hurt (7 cuadros a 24 fps = 0,29 s, dentro de hurt_duration_s = 0,3 s).
## death (19 cuadros a 12 fps = 1,58 s): una vez y se queda en el ultimo.
## terminal_*: 12 fps; intro 0,67 s, bucle 24 cuadros en ping-pong (46 pasos,
##   3,8 s), salida 0,67 s.
const ANIMATIONS: Dictionary[String, Array] = {
	"idle": [12.0, true, false],
	"walk": [24.0, true, false],
	"run": [20.0, true, false],
	"jump_rise": [12.0, false, false],
	"jump_apex": [12.0, false, false],
	"jump_fall": [12.0, false, false],
	"jump_land": [24.0, false, false],
	"pulse": [24.0, false, false],
	"hurt": [24.0, false, false],
	"death": [12.0, false, false],
	"terminal_intro": [12.0, false, false],
	"terminal_loop": [12.0, true, true],
	"terminal_outro": [12.0, false, false],
}


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var ok: bool = true
	for anim: String in ANIMATIONS:
		var textures: Array[Texture2D] = _load_sequence(anim)
		if textures.is_empty():
			ok = false
			continue
		var spec: Array = ANIMATIONS[anim]
		if spec[2] and textures.size() > 2:
			var back: Array[Texture2D] = textures.slice(1, textures.size() - 1)
			back.reverse()
			textures.append_array(back)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[0])
		frames.set_animation_loop(anim, spec[1])
		for texture: Texture2D in textures:
			frames.add_frame(anim, texture)
	if not ok:
		quit(1)
		return
	var err: Error = ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("build_isak_frames: no se pudo guardar '%s' (%s)." % [OUTPUT_PATH, error_string(err)])
		quit(1)
		return
	print("build_isak_frames: guardado %s (%d animaciones)" % [OUTPUT_PATH, ANIMATIONS.size()])
	quit(0)


func _load_sequence(anim: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var index: int = 0
	while true:
		var path: String = SPRITE_DIR + FILE_PATTERN % [anim, index]
		if not ResourceLoader.exists(path):
			break
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_error("build_isak_frames: no se pudo cargar '%s' (falta importar?)." % path)
			textures.clear()
			break
		if Vector2i(texture.get_size()) != FRAME_SIZE:
			push_error("build_isak_frames: '%s' mide %s y se esperaba %s." % [path, Vector2i(texture.get_size()), FRAME_SIZE])
			textures.clear()
			break
		textures.append(texture)
		index += 1
	if textures.is_empty():
		push_error("build_isak_frames: no hay cuadros para '%s'." % anim)
	return textures
