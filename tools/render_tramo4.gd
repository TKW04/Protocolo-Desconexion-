## Capturas a 1:1 (1280x720) del paso 14b:
##   1_popup_abierto.png      Isak de pie junto al pop-up (boton a la altura del celular)
##   2_popup_cerrandose.png   justo despues del pulso (G): animacion de cierre
##   3_popup_cerrado.png      el paso libre
##   4_puerta.png             la puerta "Marcar como leído" con su etiqueta y brillo
##   5_puerta_entrando.png    Isak entrando (puerta abriendose, Isak desvaneciendose)
##   6_hub_provisional.png    la pantalla provisional de regreso al hub
##   7_techo_burbuja.png      Tramo 3 del 1-1 (geometria real del JSON): techo bajo y Burbuja
##   8_techo_aturdida.png     la Burbuja aturdida con el pulso, Isak cruzandola
## Escenas: scenes/levels/tramo4_test.tscn y, para el techo, un montaje con las
## columnas 66-102 de data/levels/1-1.json.
## Necesita ventana (no funciona con --headless). Se puede lanzar con
## --write-movie para guardar tambien todos los cuadros.
## Uso: Godot --path . -s tools/render_tramo4.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/tramo4_test.tscn"
const OBJECTS_TEST: String = "res://scripts/levels/world1_objects_test.gd"
const ISAK_SCENE: String = "res://scenes/player/isak.tscn"
const BUBBLE_SCENE: String = "res://scenes/enemies/alert_bubble.tscn"
const BG_SCENE: String = "res://scenes/levels/world1_background.tscn"
const DEFAULT_OUT: String = "user://tramo4"
const SETTLE_FRAMES: int = 30
const COL_FROM: int = 66
const COL_TO: int = 102


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	var popup: Node2D = level.get_node(^"PopupBlocker")
	# Isak pegado al pop-up, mirando a la derecha.
	await _walk_to(isak, popup.global_position.x - 17.0, 1.0)
	print("render_tramo4: Isak x=%.0f, celular=%s, boton=%s" % [isak.global_position.x,
		isak.global_position + isak.call(&"get_pulse_origin"), popup.call(&"get_button_rect")])
	await _save(out_dir, "1_popup_abierto.png")
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	for i: int in 3:
		await physics_frame
	print("render_tramo4: pop-up estado=%d cuadro=%d" % [popup.call(&"get_state"), popup.call(&"get_window_frame")])
	await _save(out_dir, "2_popup_cerrandose.png")
	for i: int in 40:
		await physics_frame
	print("render_tramo4: pop-up cerrado=%s" % popup.call(&"is_closed"))
	await _save(out_dir, "3_popup_cerrado.png")
	var door: Node2D = level.get_node(^"ExitDoor")
	await _walk_to(isak, door.global_position.x - 150.0, 1.0)
	await _save(out_dir, "4_puerta.png")
	Input.action_press(&"move_right")
	for i: int in 200:
		await physics_frame
		if int(door.call(&"get_state")) != 0:
			break
	Input.action_release(&"move_right")
	for i: int in 9:
		await physics_frame
	await _save(out_dir, "5_puerta_entrando.png")
	for i: int in 60:
		await physics_frame
	print("render_tramo4: puerta completada %d vez/veces" % door.call(&"get_completed_count"))
	await _save(out_dir, "6_hub_provisional.png")
	level.queue_free()
	await process_frame
	await _ceiling_shots(out_dir)
	quit(0)


func _ceiling_shots(out_dir: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/1-1.json"))
	var t: float = float(data["tile_size"])
	var grid: Array[String] = []
	for row: String in data["grid"]:
		grid.append(row.substr(COL_FROM, COL_TO - COL_FROM + 1))
	var world := Node2D.new()
	root.add_child(world)
	world.add_child((load(BG_SCENE) as PackedScene).instantiate())
	var tiles := TileMapLayer.new()
	tiles.position = Vector2(COL_FROM * t, 0.0)
	world.add_child(tiles)
	load(OBJECTS_TEST).paint_tiles(tiles, grid)
	var enemy: Dictionary = data["enemies"][0]
	var floor_y: float = (float(enemy["y"]) + 1.0) * t
	var bubble: Node2D = (load(BUBBLE_SCENE) as PackedScene).instantiate()
	bubble.position = Vector2((float(enemy["x"]) + 0.5) * t, floor_y)
	bubble.set(&"patrol_range_px", float(enemy["params"]["patrol_range_px"]))
	bubble.set(&"free_on_pop", false)
	world.add_child(bubble)
	var isak: Node2D = (load(ISAK_SCENE) as PackedScene).instantiate()
	isak.position = Vector2(79.0 * t, floor_y - 1.0)
	world.add_child(isak)
	var game_state: Node = root.get_node(^"GameState")
	var was_unlocked: bool = game_state.call(&"is_ability_unlocked", &"pulse")
	game_state.call(&"set_ability_unlocked", &"pulse", true)
	var camera: Camera2D = isak.get_node(^"Camera2D")
	camera.limit_top = 0
	camera.limit_bottom = 14 * int(t)
	for i: int in SETTLE_FRAMES:
		await physics_frame
	# Salta bajo el techo: la cabeza toca el techo.
	Input.action_press(&"jump")
	for i: int in 8:
		await physics_frame
	Input.action_release(&"jump")
	await _save(out_dir, "7_techo_burbuja.png")
	for i: int in 40:
		await physics_frame
	# Acercarse y aturdir.
	Input.action_press(&"move_right")
	for i: int in 300:
		await physics_frame
		if bubble.global_position.x - isak.global_position.x < 130.0:
			break
	Input.action_release(&"move_right")
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	for i: int in 25:
		await physics_frame
	Input.action_press(&"move_right")
	for i: int in 300:
		await physics_frame
		if isak.global_position.x >= bubble.global_position.x - 4.0:
			break
	Input.action_release(&"move_right")
	print("render_tramo4: Burbuja aturdida=%s, Sync Rate=%.0f" % [bubble.call(&"is_stunned"), game_state.get(&"sync_rate")])
	await _save(out_dir, "8_techo_aturdida.png")
	game_state.call(&"set_ability_unlocked", &"pulse", was_unlocked)


func _walk_to(isak: Node2D, x: float, facing: float) -> void:
	isak.global_position = Vector2(x - 40.0 * facing, isak.global_position.y)
	isak.set(&"velocity", Vector2.ZERO)
	for i: int in 6:
		await physics_frame
	var action: StringName = &"move_right" if facing > 0.0 else &"move_left"
	Input.action_press(action)
	for i: int in 120:
		await physics_frame
		if (isak.global_position.x - x) * facing >= 0.0 or absf((isak.get(&"velocity") as Vector2).x) < 1.0 and i > 10:
			break
	Input.action_release(action)
	for i: int in SETTLE_FRAMES:
		await physics_frame


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_tramo4: %s (%s)" % [path, error_string(err)])
