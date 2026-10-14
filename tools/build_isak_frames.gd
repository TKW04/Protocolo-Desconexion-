## Genera scenes/player/isak_frames.tres (SpriteFrames) desde los PNG placeholder.
## Requiere que los PNG esten importados antes (Godot --headless --import).
## Todos los cuadros deben medir FRAME_SIZE (canvas de Isak a 1280x720) con los
## pies abajo y centrados; isak.tscn coloca el AnimatedSprite2D (centrado) en
## (0, -FRAME_SIZE.y / 2) para que los pies queden en el origen del personaje.
## Uso: Godot --headless --path . -s tools/build_isak_frames.gd
extends SceneTree

const SPRITE_DIR: String = "res://assets/sprites/isak/"
const OUTPUT_PATH: String = "res://scenes/player/isak_frames.tres"
const FILE_PATTERN: String = "isak_%s_%02d_placeholder.png"
const ANIMATION_FPS: float = 12.0
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
	while true:
		var path: String = SPRITE_DIR + FILE_PATTERN % [anim, index]
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
	frames.set_animation_speed(anim, ANIMATION_FPS)
	frames.set_animation_loop(anim, loop)
	for texture: Texture2D in textures:
		frames.add_frame(anim, texture)
