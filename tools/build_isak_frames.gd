## Genera scenes/player/isak_frames.tres (SpriteFrames) desde los PNG de Isak.
## Cada animacion cuenta sus cuadros (00, 01, ...) hasta el primero que falte.
## Usa el arte importado (isak_<anim>_NN.png, tools/import_sheet.py) y, si no
## existe, el placeholder (isak_<anim>_NN_placeholder.png).
## Requiere que los PNG esten importados antes (Godot --headless --import).
## Todos los cuadros deben medir FRAME_SIZE (canvas de Isak a 1280x720) con los
## pies abajo y centrados; isak.tscn coloca el AnimatedSprite2D (centrado) en
## (0, -FRAME_SIZE.y / 2) para que los pies queden en el origen del personaje.
## Uso: Godot --headless --path . -s tools/build_isak_frames.gd
extends SceneTree

const SPRITE_DIR: String = "res://assets/sprites/isak/"
const OUTPUT_PATH: String = "res://scenes/player/isak_frames.tres"
## Arte importado primero; el placeholder solo si no hay arte para esa animacion.
const FILE_PATTERNS: PackedStringArray = [
	"isak_%s_%02d.png",
	"isak_%s_%02d_placeholder.png",
]
## Velocidad por defecto (cuadros/s) de las animaciones sin entrada en ANIMATION_FPS.
const DEFAULT_FPS: float = 12.0
## Velocidad de cada animacion en cuadros/s (unico sitio donde se fija).
## walk (25 cuadros de la hoja del usuario): el ciclo tiene ~6 pasos (posiciones
## de paso, piernas juntas, en los cuadros ~4, 8, 12, 16-17, 21 y de nuevo ~25:
## un paso cada ~4,2 cuadros). A escala del juego (factor 96/178) las zancadas
## miden 47-52 px de punta a talon y la bota ~14 px, asi que cada paso avanza
## ~36 px: 6 x 36 = ~216 px por vuelta. A walk_speed (220 px/s) la vuelta debe
## durar ~0,98 s -> 25 / 0,98 = ~25,5 fps. Con 24 fps la vuelta dura 1,04 s
## (~207 px/s en los pies): patina ~6 %, imperceptible.
const ANIMATION_FPS: Dictionary[String, float] = {
	"idle": 12.0,
	"walk": 24.0,
}
## Tamano esperado de cada cuadro (px).
const FRAME_SIZE: Vector2i = Vector2i(128, 128)

## Animaciones de varios cuadros: nombre del archivo -> bucle.
const LOOPING_ANIMS: Dictionary[String, bool] = {
	"idle": true,
	"terminal": true,
	"walk": true,
	"run": true,
	"pulse": false,
}

## Cuadros del salto, en orden de archivo (00..04), como animaciones sueltas.
const JUMP_SOURCE: String = "jump"
const JUMP_ANIMS: PackedStringArray = [
	"jump_anticipation",
	"jump_rise",
	"jump_apex",
	"jump_fall",
	"jump_land",
]


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var ok: bool = true
	for anim: String in LOOPING_ANIMS:
		var textures: Array[Texture2D] = _load_sequence(anim)
		if textures.is_empty():
			ok = false
			continue
		_add_animation(frames, anim, textures, LOOPING_ANIMS[anim])
	var jump_textures: Array[Texture2D] = _load_sequence(JUMP_SOURCE)
	if jump_textures.size() != JUMP_ANIMS.size():
		push_error("build_isak_frames: se esperaban %d cuadros de salto y hay %d." % [JUMP_ANIMS.size(), jump_textures.size()])
		ok = false
	else:
		for i: int in JUMP_ANIMS.size():
			_add_animation(frames, JUMP_ANIMS[i], [jump_textures[i]], false)
	if not ok:
		quit(1)
		return
	var err: Error = ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("build_isak_frames: no se pudo guardar '%s' (%s)." % [OUTPUT_PATH, error_string(err)])
		quit(1)
		return
	print("build_isak_frames: guardado %s" % OUTPUT_PATH)
	quit(0)


func _load_sequence(anim: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var index: int = 0
	var pattern: String = ""
	for candidate: String in FILE_PATTERNS:
		if ResourceLoader.exists(SPRITE_DIR + candidate % [anim, 0]):
			pattern = candidate
			break
	while pattern != "":
		var path: String = SPRITE_DIR + pattern % [anim, index]
		if not ResourceLoader.exists(path):
			break
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_error("build_isak_frames: no se pudo cargar '%s' (falta importar?)." % path)
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


func _add_animation(frames: SpriteFrames, anim: String, textures: Array[Texture2D], loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, ANIMATION_FPS.get(anim, DEFAULT_FPS))
	frames.set_animation_loop(anim, loop)
	for texture: Texture2D in textures:
		frames.add_frame(anim, texture)
