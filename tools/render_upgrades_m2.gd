## Capturas a 1:1 (1280x720) de los EFECTOS de la tanda M2 de las mejoras de Calc
## (docs/propuesta-mejoras.md, 2026-10-17) en salas reales del Mundo 1. Usa su
## propio guardado (user://render_upgrades_m2_save.json, se borra al terminar).
##   01_ocultarte_activo.png        mensajes_test: Isak oculto (semitransparente, glitch y
##                                  contorno cian) y el punto rojo que pierde el rastro («?»)
##   02_ocultarte_hud.png           ampliacion x3 del HUD: icono «oculto» y barra de lo que queda
##   03_ocultarte_aviso_a.png       energia por debajo del 20 %: glitch fuerte (cuadro encendido)
##   04_ocultarte_aviso_b.png       el mismo aviso medio ciclo despues (parpadeo)
##   05_ocultarte_aviso_hud.png     ampliacion x3 del HUD en el aviso (icono apagado / barra blanca)
##   06_ocultarte_corte.png         al llegar al 10 %: se apaga solo con el destello del glitch
##   07_laser_perfora.png           Laser 5: el haz atraviesa tres Burbujas (destellos) y sigue
##   08_pulso_retorno.png           Pulso 5: Burbuja aturdida con «+4» de energia encima
##   09_debug_persistente.png       1-2, piso 2: Debug 3 apagado hace 0,5 s; Isak sigue de pie en
##                                  la plataforma oculta, que se ve y es solida
##   10_debug_persistente_aviso.png el mismo en el ultimo medio segundo: cuadro apagado del parpadeo
##                                  (Isak aun se sostiene: sigue solida hasta los 1,5 s)
## (La 11, power bank «Sin espacio», se retiro el 2026-10-25: el power bank es un
## coleccionable puro sin tope.)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_upgrades_m2.gd [-- carpeta_salida]
extends SceneTree

const ROOM: String = "res://scenes/levels/mensajes_test.tscn"
const TOWER: String = "res://scenes/levels/1-2.tscn"
const BUBBLE: String = "res://scenes/enemies/alert_bubble.tscn"
const DEFAULT_OUT: String = "user://upgrades_m2"
const SAVE_PATH: String = "user://render_upgrades_m2_save.json"
const TILE: float = 64.0

var _ok: bool = true
var _state: Node
var _debug: Node
var _fake: RefCounted


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_state = root.get_node("GameState")
	_debug = root.get_node("DebugMode")
	_state.call(&"use_save_path", SAVE_PATH, true)
	for ally: StringName in [&"eco", &"notas", &"calc"]:
		_state.call(&"meet_ally", ally)
	_state.call(&"obtain_ability", &"pulse")
	_state.call(&"obtain_ability", &"laser")
	_state.call(&"obtain_ability", &"debug")
	var levels: Dictionary = _state.get(&"upgrade_levels")
	for track: StringName in [&"pulso", &"laser", &"debug", &"sync", &"energia"]:
		levels[track] = 5
	await _hide_shots(out_dir)
	await _pierce_shot(out_dir)
	await _pulse_return_shot(out_dir)
	await _debug_shots(out_dir)
	print("render_upgrades_m2: %s" % ("OK" if _ok else "FALLO"))
	_state.call(&"use_save_path", SAVE_PATH, true)
	SaveFile.delete(SAVE_PATH)
	quit(0 if _ok else 1)


# --- Ocultarte ---

func _hide_shots(out_dir: String) -> void:
	var room: Node = await _load_room()
	var isak: Node2D = room.call(&"get_isak")
	# Cerca del punto rojo de la izquierda para que despierte y persiga.
	var badge: Node2D = room.get_node(^"Enemies/badge_1")
	isak.global_position = Vector2(badge.global_position.x - 4.0 * TILE, 11.0 * TILE)
	isak.call(&"snap_camera")
	_state.set(&"sync_rate", _state.call(&"get_sync_rate_max"))
	_state.set(&"debug_energy", _state.call(&"get_debug_energy_max"))
	for i: int in 90:
		await physics_frame
	_check(bool(badge.call(&"is_chasing")), "el punto rojo no persigue")
	await _press(&"hide_pressed")
	_check(bool(isak.call(&"is_hidden")), "no se activa el Ocultarte")
	for i: int in 24:
		await physics_frame
	_check(bool(badge.call(&"is_lost")), "el punto rojo no pierde el rastro")
	await _save(out_dir, "01_ocultarte_activo.png")
	await _save_hud_zoom(out_dir, "02_ocultarte_hud.png")
	# Aviso: energia por debajo del 20 %.
	_state.set(&"debug_energy", float(_state.call(&"get_debug_energy_max")) * 0.19)
	var mode: RefCounted = isak.call(&"get_hide_mode")
	await _wait_blink(mode, true)
	await _save(out_dir, "03_ocultarte_aviso_a.png")
	await _wait_blink(mode, false)
	await _save(out_dir, "04_ocultarte_aviso_b.png")
	await _save_hud_zoom(out_dir, "05_ocultarte_aviso_hud.png")
	# Corte al 10 %.
	for i: int in 200:
		await physics_frame
		if not bool(isak.call(&"is_hidden")):
			break
	_check(not bool(isak.call(&"is_hidden")), "no se corta al 10 %")
	_check(bool(mode.call(&"is_flashing")), "sin destello al cortarse")
	await physics_frame
	await _save(out_dir, "06_ocultarte_corte.png")
	room.queue_free()
	await process_frame


func _wait_blink(mode: RefCounted, on: bool) -> void:
	for i: int in 60:
		await process_frame
		var mat: ShaderMaterial = mode.call(&"get_material")
		if mat == null:
			continue
		var t: float = float(mat.get_shader_parameter(&"time_s"))
		var hz: float = float(mat.get_shader_parameter(&"warn_blink_hz"))
		if (fmod(t * hz, 1.0) >= 0.5) == on:
			return


# --- Laser 5 ---

func _pierce_shot(out_dir: String) -> void:
	var room: Node = await _load_room()
	for enemy: Node in room.get_node(^"Enemies").get_children():
		enemy.queue_free()
	var isak: Node2D = room.call(&"get_isak")
	isak.global_position = Vector2(2.5 * TILE, 11.0 * TILE)
	isak.set(&"facing", 1.0)
	isak.call(&"snap_camera")
	_state.set(&"debug_energy", _state.call(&"get_debug_energy_max"))
	var bubbles: Array[Node2D] = []
	for col: float in [6.5, 8.5, 10.5]:
		var b: Node2D = (load(BUBBLE) as PackedScene).instantiate()
		b.set(&"patrol_range_px", 0.0)
		b.set(&"free_on_pop", false)
		room.get_node(^"Enemies").add_child(b)
		# Mas vida para que se vean atravesadas (parpadeo) y no reventadas.
		b.set(&"max_health", 6.0)
		b.global_position = Vector2(col * TILE, 11.0 * TILE)
		b.set_physics_process(false)
		bubbles.append(b)
	for i: int in 20:
		await physics_frame
	var fired: Array[Node2D] = []
	var on_fired := func(p: Node2D) -> void: fired.append(p)
	isak.connect(&"laser_fired", on_fired)
	await _press(&"laser_pressed")
	for i: int in 10:
		if not fired.is_empty():
			break
		await physics_frame
	isak.disconnect(&"laser_fired", on_fired)
	_check(not fired.is_empty(), "no sale el laser")
	if fired.is_empty():
		room.queue_free()
		return
	var shot: Node2D = fired[0]
	shot.set(&"auto_process", false)
	while not bool(shot.call(&"is_finished")) and shot.global_position.x < 11.2 * TILE:
		shot.call(&"step", 1.0 / 60.0)
		for node: Node in room.get_children():
			if String(node.name).contains("UpgradeFx_pierce_spark"):
				node.set(&"auto_process", false)
	var pierced: int = (shot.call(&"get_pierced") as Array).size()
	_check(pierced == 3, "no atraviesa las tres Burbujas (%d)" % pierced)
	for node: Node in room.get_children():
		if String(node.name).contains("UpgradeFx_pierce_spark"):
			node.set(&"auto_process", false)
			node.call(&"advance", 0.1)
	await _save_frozen(out_dir, "07_laser_perfora.png")
	room.queue_free()
	await process_frame


# --- Pulso 5 ---

func _pulse_return_shot(out_dir: String) -> void:
	var room: Node = await _load_room()
	for enemy: Node in room.get_node(^"Enemies").get_children():
		enemy.queue_free()
	var isak: Node2D = room.call(&"get_isak")
	isak.global_position = Vector2(3.5 * TILE, 11.0 * TILE)
	isak.set(&"facing", 1.0)
	isak.call(&"snap_camera")
	var b: Node2D = (load(BUBBLE) as PackedScene).instantiate()
	b.set(&"patrol_range_px", 0.0)
	room.get_node(^"Enemies").add_child(b)
	b.global_position = Vector2(4.6 * TILE, 11.0 * TILE)
	b.set_physics_process(false)
	_state.set(&"debug_energy", 60.0)
	for i: int in 20:
		await physics_frame
	await _press(&"pulse_pressed")
	for i: int in 4:
		await physics_frame
	_check(bool(b.call(&"is_stunned")), "el pulso no aturde")
	_check(is_equal_approx(float(_state.get(&"debug_energy")), 64.0), "el pulso de retorno no da +4")
	# Tiempo real (la ventana puede ir a mas de 60 fps): «+4» en su cuadro 2.
	await create_timer(0.22).timeout
	await _save_frozen(out_dir, "08_pulso_retorno.png")
	room.queue_free()
	await process_frame


# --- Debug 3 ---

func _debug_shots(out_dir: String) -> void:
	_debug.set(&"input_enabled", false)
	_debug.call(&"reset")
	var tower: Node = (load(TOWER) as PackedScene).instantiate()
	root.add_child(tower)
	var isak: Node2D = tower.call(&"get_isak")
	_fake = _new_input()
	isak.set(&"input", _fake)
	for i: int in 10:
		await physics_frame
	_state.set(&"debug_energy", _state.call(&"get_debug_energy_max"))
	# Debug activo (carga de 0,4 s con el Debug 5) y Isak sobre la plataforma oculta.
	for i: int in 30:
		_debug.call(&"step", 1.0 / 60.0, true)
		await physics_frame
	_debug.call(&"step", 1.0 / 60.0, false)
	_check(bool(_debug.call(&"is_active")), "el Debug no se activa")
	for i: int in 20:
		_debug.call(&"step", 1.0 / 60.0, false)
		await physics_frame
	isak.global_position = Vector2(3.5 * TILE, 38.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	isak.call(&"snap_camera")
	for i: int in 30:
		_debug.call(&"step", 1.0 / 60.0, false)
		await physics_frame
	_check(bool(isak.call(&"is_on_floor")), "Isak no esta sobre la plataforma oculta")
	# Apagar: el revelado sigue 1,5 s.
	_debug.call(&"step", 1.0 / 60.0, true)
	_debug.call(&"step", 1.0 / 60.0, false)
	for i: int in 30:
		_debug.call(&"step", 1.0 / 60.0, false)
		await physics_frame
	_check(not bool(_debug.call(&"is_active")), "el Debug no se apaga")
	_check(bool(_debug.call(&"is_revealing")) and bool(isak.call(&"is_on_floor")), "sin revelado persistente")
	await _save(out_dir, "09_debug_persistente.png")
	for i: int in 200:
		_debug.call(&"step", 1.0 / 60.0, false)
		await physics_frame
		if bool(_debug.call(&"is_reveal_blink_off")) and float(_debug.call(&"get_reveal_linger_left")) < 0.4:
			break
	await _save(out_dir, "10_debug_persistente_aviso.png")
	_debug.call(&"reset")
	_debug.set(&"input_enabled", true)
	tower.queue_free()
	await process_frame


# --- Utilidades ---

func _load_room() -> Node:
	var room: Node = (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	var isak: Node2D = room.call(&"get_isak")
	_fake = _new_input()
	isak.set(&"input", _fake)
	for i: int in 10:
		await physics_frame
	return room


func _new_input() -> RefCounted:
	return (load("res://scripts/player/player_input.gd") as GDScript).new()


## Pulsa un flanco de la entrada falsa durante un paso de fisica.
func _press(field: StringName) -> void:
	_fake.set(field, true)
	await physics_frame
	_fake.set(field, false)


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_upgrades_m2: " + why)


func _save_frozen(out_dir: String, file_name: String) -> void:
	paused = true
	await _save(out_dir, file_name)
	paused = false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_upgrades_m2: %s (%s)" % [path, error_string(err)])


## Ampliacion x3 de la esquina superior derecha (HUD).
func _save_hud_zoom(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var region: Image = image.get_region(Rect2i(1280 - 420, 0, 420, 110))
	region.resize(region.get_width() * 3, region.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var path: String = out_dir.path_join(file_name)
	var err: Error = region.save_png(path)
	print("render_upgrades_m2: %s (%s)" % [path, error_string(err)])
