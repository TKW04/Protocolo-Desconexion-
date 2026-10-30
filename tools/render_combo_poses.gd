## Capturas de las poses de la Combinacion de Isak (AutoSprite, 2026-10-30; paso 24
## del Mundo 5) en la sala combos_test con el Isak real y las acciones del Input Map:
##   00_de_pie            Isak de pie (referencia de tamano y pies)
##   01_embestida         la Embestida en el aire (combo_ram)
##   02_embestida_suelo   la Embestida al aterrizar (ground_pound_land)
##   03_filo              el Filo a media carrera (combo_edge)
##   04_sismo_aire        el Sismo cayendo (combo_quake_air)
##   05_sismo_suelo       el Sismo al aterrizar (combo_quake_land)
## y de cada una un recorte ampliado x3 alrededor de Isak (<nombre>_x3.png).
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --fixed-fps 60 --path . -s tools/render_combo_poses.gd [-- carpeta_salida]
extends SceneTree

const ROOM: String = "combos_test"
const DEFAULT_OUT: String = "user://combo_poses"
const CROP: Vector2 = Vector2(200.0, 160.0)

var _out: String
var _ok: bool = true
var _isak: Node2D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	var state: Node = root.get_node(^"GameState")
	state.call(&"reset_progress")
	state.call(&"meet_ally", &"eco")
	for notice: StringName in [&"debug", &"laser", &"dash", &"combo", &"ground_pound", &"compress"]:
		state.call(&"mark_notice_seen", notice)
	var level: Node = (load("res://scenes/levels/%s.tscn" % ROOM) as PackedScene).instantiate()
	root.add_child(level)
	_isak = level.get_node(^"Isak")
	await _frames(40)
	for ability: StringName in [&"dash", &"compress", &"ground_pound", &"combo"]:
		state.call(&"set_ability_unlocked", ability, true)
	await _frames(20)
	await _save("00_de_pie")
	# Embestida: salto, dash aereo y abajo.
	await _press(&"jump", 10)
	await _press(&"gesture_swipe", 2)
	await _frames(3)
	Input.action_press(&"move_down")
	await _until_state(&"combo_ram", 30)
	await _frames(4)
	await _save("01_embestida")
	await _until_floor(90)
	await _frames(2)
	await _save("02_embestida_suelo")
	Input.action_release(&"move_down")
	await _frames(60)
	_refill(state)
	# Filo: salto, Comprimir y Deslizar hacia la izquierda (hay sitio).
	Input.action_press(&"move_left")
	await _frames(2)
	Input.action_release(&"move_left")
	await _press(&"jump", 8)
	await _press(&"gesture_pinch", 2)
	await _frames(8)
	await _press(&"gesture_swipe", 2)
	await _until_state(&"combo_edge", 10)
	await _frames(5)
	await _save("03_filo")
	await _until_floor(90)
	await _frames(30)
	_refill(state)
	# Sismo: comprimido, salto y abajo.
	await _press(&"jump", 14)
	Input.action_press(&"move_down")
	await _until_state(&"combo_quake", 30)
	await _frames(3)
	await _save("04_sismo_aire")
	await _until_floor(90)
	await _frames(2)
	await _save("05_sismo_suelo")
	Input.action_release(&"move_down")
	await _frames(30)
	quit(0 if _ok else 1)


func _refill(state: Node) -> void:
	state.set(&"debug_energy", 100.0)


func _press(action: StringName, hold: int) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)


func _until_state(name: StringName, limit: int) -> void:
	for i: int in limit:
		if _isak.call(&"get_state_name") == name:
			return
		await physics_frame
	_ok = false
	push_error("render_combo_poses: no llega a %s (esta en %s)" % [name, _isak.call(&"get_state_name")])


func _until_floor(limit: int) -> void:
	for i: int in limit:
		if (_isak as CharacterBody2D).is_on_floor():
			return
		await physics_frame
	_ok = false
	push_error("render_combo_poses: no aterriza")


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var sprite: AnimatedSprite2D = _isak.call(&"get_sprite")
	print("render_combo_poses: %s anim=%s cuadro=%d estado=%s" % [name, sprite.animation, sprite.frame,
		_isak.call(&"get_state_name")])
	_ok = image.save_png(_out.path_join(name + ".png")) == OK and _ok
	var feet: Vector2 = _isak.get_global_transform_with_canvas().origin
	var scale: Vector2 = Vector2(image.get_size()) / Vector2(root.get_visible_rect().size)
	var rect := Rect2i(Vector2i((feet - Vector2(CROP.x * 0.5, CROP.y - 24.0)) * scale), Vector2i(CROP * scale))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop: Image = image.get_region(rect)
	crop.resize(int(CROP.x) * 3, int(CROP.y) * 3, Image.INTERPOLATE_NEAREST)
	_ok = crop.save_png(_out.path_join(name + "_x3.png")) == OK and _ok
