## Capturas a 1:1 (1280x720) del hub REAL (scenes/hub/hub.tscn, abierto
## directamente: aun no esta en el flujo del juego) con arte provisional. Usa
## su propio guardado (user://render_hub_save.json, se borra al terminar), nunca
## el del jugador. Antes de entrar simula haber completado el 1-1 con 9 puntos
## (cambios sin guardar).
##   01_llegada_vortice.png      Isak materializandose en P por el vortice
##   02_hub_llegada.png          Isak en P con el control; HUD con Modo Avion y «Sin guardar»
##   03_copia_local_prompt.png   Isak junto a la copia local: tecla del pulso
##   04_copia_local_panel.png    panel abierto (resumen) con Isak de espaldas
##   05_copia_local_confirmar.png confirmacion «¿Guardar copia local?»
##   06_copia_guardada.png       «Copia guardada», destello y el indicador apagado
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_hub.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://hub"
const SAVE_PATH: String = "user://render_hub_save.json"
const TILE: float = 64.0
const WAIT_FRAMES: int = 60 * 20

var _hub: Node
var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"use_save_path", SAVE_PATH, true)
	state.set(&"current_level", &"1-1")
	state.set(&"attention_points", 9)
	state.call(&"mark_level_completed", &"1-1")
	_hub = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_hub)
	# 1. Llegada: el vortice cerrandose con Isak a medias.
	var vortex: Node = _hub.call(&"get_arrival_vortex")
	_check(vortex != null, "no hay vortice de llegada")
	_check(await _wait(func() -> bool:
		return is_instance_valid(vortex) and int(vortex.call(&"get_phase")) == 3 \
			and (vortex.get_node(^"Sprite") as AnimatedSprite2D).frame >= 1), "el vortice no se cierra")
	await _save_frozen(out_dir, "01_llegada_vortice.png")
	_check(await _wait(func() -> bool: return _hub.call(&"has_arrived")), "Isak no llega")
	await _frames(20)
	await _save(out_dir, "02_hub_llegada.png")
	# 3. Junto a la copia local.
	var station: Node = _hub.call(&"get_station", &"copia_local")
	var isak: Node2D = _hub.call(&"get_isak")
	var fake: RefCounted = (load("res://scripts/player/player_input.gd") as GDScript).new()
	isak.set(&"input", fake)
	fake.set(&"move_axis", -1.0)
	_check(await _wait(func() -> bool: return isak.global_position.x < 3.0 * TILE), "Isak no llega a la estacion")
	isak.global_position = Vector2(2.6 * TILE, isak.global_position.y)
	fake.set(&"move_axis", 0.0)
	await _frames(30)
	_check(station.call(&"is_key_hint_visible"), "no sale la tecla del pulso")
	await _save(out_dir, "03_copia_local_prompt.png")
	# 4. Pulso: panel abierto con Isak de espaldas.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool: return station.call(&"is_panel_open") and isak.call(&"is_facing_back")),
		"no se abre el panel")
	await _frames(20)
	await _save(out_dir, "04_copia_local_panel.png")
	var panel: Node = station.call(&"get_copy_panel")
	panel.call(&"select_option", &"save")
	panel.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "05_copia_local_confirmar.png")
	panel.call(&"select_option", &"yes")
	panel.call(&"confirm")
	_check(not state.call(&"has_unsaved_changes"), "no se guardo")
	await _frames(2)
	await _save_frozen(out_dir, "06_copia_guardada.png")
	print("render_hub: %s" % ("OK" if _ok else "FALLO"))
	_hub.queue_free()
	await process_frame
	state.call(&"use_save_path", SAVE_PATH, true)
	quit(0 if _ok else 1)


func _wait(cond: Callable) -> bool:
	for i: int in WAIT_FRAMES:
		if cond.call():
			return true
		await process_frame
	return false


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_hub: " + why)


## Captura con el arbol en pausa (la fase actual no avanza mientras se guarda).
func _save_frozen(out_dir: String, file_name: String) -> void:
	paused = true
	await _save(out_dir, file_name)
	paused = false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_hub: %s (%s)" % [path, error_string(err)])
