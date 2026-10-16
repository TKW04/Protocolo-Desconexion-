## Capturas a 1:1 (1280x720) de la vida extra del secreto D del 1-1 (paso 14 de
## §10 de docs/propuesta-asistentes-y-vidas.md) con el flujo de juego real
## (scenes/main.tscn) y un guardado propio (user://tool_save.json, se borra al
## arrancar; nunca el guardado del jugador). La partida ya conoce a Eco y a Notas
## (las vidas cuentan) y tiene el Debug obtenido (como tras el 1-2). Ya conoce
## todos los tipos del 1-1 salvo la pared con glitch y la vida extra:
##   00a_tramo_final.png      panorama del tramo final (columnas ~280-300):
##                            terminal de salida (290) y pared con glitch (298)
##   00b_eco_vuela_a_pared.png Isak se acerca a la pared: Eco vuela hacia ella
##                            brillando en dorado con la Q encima
##   00c_eco_junto_pared.png  Eco junto a la pared con la Q dorada
##   00d_ayuda_pared_pausa.png ayuda de la pared abierta (juego en pausa):
##                            el texto de glitch_wall de data/help.json
##   01_pared_glitch.png      la pared con glitch del final del 1-1, sin Debug
##   02_debug_revelando.png   Debug activo junto a la pared: se disuelve
##   02b_pared_disuelta_debug.png pared disuelta, aun con el Debug, y la vida extra
##   03_vida_extra.png        la pared disuelta con el Debug y la vida extra en su celda
##   04a_recogida.png         al recogerla: el «+1» subiendo y el icono nuevo del HUD
##   04_hud_4_vidas.png       despues: 4 vidas en el HUD
##   05_album_ficha.png       ficha «Vida extra» en el album de Notas (hub)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_extra_life.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const HUB_SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://extra_life_shots"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _main: Node
var _ok: bool = true
## Cierra solo las lineas importantes de Eco (falso mientras se captura la ayuda).
var _auto_confirm: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"meet_ally", &"eco")
	state.call(&"meet_ally", &"notas")
	state.call(&"mark_notice_seen", &"pulse")
	state.call(&"obtain_ability", &"pulse")
	state.call(&"mark_notice_seen", &"debug")
	state.call(&"obtain_ability", &"debug")
	_main = (load(SCENE) as PackedScene).instantiate()
	_main.set(&"start_level_id", "1-1")
	root.add_child(_main)
	# Todos los tipos del 1-1 aprendidos salvo la pared y la vida extra: en el
	# tramo final la unica Q es la de la pared.
	var catalog: Object = load("res://scripts/levels/help_catalog.gd").call(&"shared")
	for id: StringName in catalog.call(&"ids"):
		if id != &"glitch_wall" and id != &"extra_life":
			state.call(&"learn_help", id)
	var isak: Node2D = _main.call(&"get_isak")
	await _wait(func() -> bool: return not paused and not isak.call(&"is_warping"), 30.0)
	await _frames(30)
	var level: Node = _main.call(&"get_level")
	var wall: Node2D = level.get_node(^"Objects/glitch_wall_298_8")
	var pickup: Node2D = level.get_node(^"Objects/vida_extra_1_1")
	var help: Node = level.get_node(^"Help")
	var eco: Node = _main.call(&"get_eco_companion")
	# (a) Panorama del tramo final: la camara topa con el borde derecho del mapa.
	# Sin Q en el panorama (la apagada de relectura saldria con Isak quieto):
	# «Ayudas de Eco: Ocultar» solo para esta captura (ajustes de herramientas).
	var settings: Script = load("res://scripts/autoload/game_settings.gd")
	settings.call(&"set_eco_help_shown", false)
	isak.global_position = Vector2(292.0 * TILE, 10.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	await _frames(90)
	await _save(out_dir, "00a_tramo_final.png")
	settings.call(&"set_eco_help_shown", true)
	# (b) Isak se acerca andando a la pared (entrada falsa): Eco vuela a ella.
	var real_input: Object = isak.get(&"input")
	var fake: Object = load("res://scripts/player/player_input.gd").new()
	isak.set(&"input", fake)
	isak.global_position = Vector2(293.5 * TILE, 10.0 * TILE)
	await _frames(20)
	fake.set(&"move_axis", 1.0)
	_check(await _wait(func() -> bool: return help.call(&"get_target") == wall, 5.0), "la pared no es candidata")
	await create_timer(0.15).timeout
	await _save(out_dir, "00b_eco_vuela_a_pared.png")
	await create_timer(0.2).timeout
	fake.set(&"move_axis", 0.0)
	await create_timer(1.0).timeout
	_check(help.call(&"is_prompt_on_eco") and eco.call(&"get_help_target") == wall and eco.call(&"get_glow") == 2,
		"Eco no esta junto a la pared con la Q dorada")
	await _save(out_dir, "00c_eco_junto_pared.png")
	# (c) Ayuda abierta: el juego en pausa con el texto de la pared.
	_auto_confirm = false
	var press := InputEventAction.new()
	press.action = &"help"
	press.pressed = true
	root.push_input(press)
	await create_timer(2.5).timeout
	var box: Node = level.get_node(^"EcoTextBox")
	box.call(&"finish_typing")
	await create_timer(0.3).timeout
	var help_text: String = box.call(&"get_text")
	_check(paused and help_text == catalog.call(&"text", &"glitch_wall"), "la ayuda de la pared no se abre")
	print("render_extra_life: ayuda de la pared: «%s»" % help_text)
	await _save(out_dir, "00d_ayuda_pared_pausa.png")
	while box.call(&"confirm"):
		pass
	_auto_confirm = true
	await _frames(30)
	isak.set(&"input", real_input)
	isak.global_position = Vector2(295.5 * TILE, 10.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	await _frames(60)
	_check(wall.call(&"is_solid") and not pickup.visible, "pared solida y vida oculta sin Debug")
	await _save(out_dir, "01_pared_glitch.png")
	# Debug: pulsacion larga (sin leer el teclado).
	var debug: Node = root.get_node(^"DebugMode")
	debug.set(&"input_enabled", false)
	state.set(&"debug_energy", 100.0)
	var hold_s: float = debug.call(&"get_activation_hold_s")
	for i: int in roundi(hold_s / DT) + 2:
		debug.call(&"step", DT, true)
		await physics_frame
	debug.call(&"step", DT, false)
	_check(await _wait(func() -> bool: return wall.call(&"is_dissolving"), 5.0), "la pared no se disuelve")
	await create_timer(0.25).timeout
	await _save(out_dir, "02_debug_revelando.png")
	_check(await _wait(func() -> bool: return wall.call(&"is_open"), 5.0), "la pared no se abre")
	await create_timer(0.8).timeout
	_check(pickup.visible, "la vida extra no aparece con el Debug")
	await _save(out_dir, "02b_pared_disuelta_debug.png")
	debug.call(&"reset")
	debug.set(&"input_enabled", true)
	await create_timer(0.8).timeout
	_check(pickup.visible, "la vida extra no aparece")
	await _save(out_dir, "03_vida_extra.png")
	isak.global_position = Vector2(298.5 * TILE, 10.0 * TILE)
	await create_timer(0.12).timeout
	_check(int(state.get(&"lives_max")) == 4 and int(state.get(&"lives")) == 4, "no suben las vidas")
	await _save(out_dir, "04a_recogida.png")
	await create_timer(0.8).timeout
	await _save(out_dir, "04_hud_4_vidas.png")
	_main.queue_free()
	await _frames(3)
	# Album: hub con Notas conocida y la ficha aprendida.
	state.call(&"learn_help", &"extra_life")
	var hub: Node = (load(HUB_SCENE) as PackedScene).instantiate()
	root.add_child(hub)
	_check(await _wait(func() -> bool: return hub.call(&"has_arrived"), 20.0), "Isak no llega al hub")
	await _frames(20)
	var notas: Node = hub.call(&"get_notas")
	notas.call(&"open", hub.call(&"get_isak"))
	_check(await _wait(func() -> bool: return notas.call(&"is_panel_open"), 5.0), "no se abre Notas")
	await _frames(20)
	var panel: Node = notas.call(&"get_notas_panel")
	panel.call(&"select_option", &"album")
	panel.call(&"confirm")
	var album: Node = notas.call(&"get_album")
	album.call(&"set_tab", "object")
	var entries: Array = album.call(&"get_entries")
	for i: int in entries.size():
		if StringName(str((entries[i] as Dictionary).get("id", ""))) == &"extra_life":
			album.call(&"select_cell", i)
	album.call(&"skip_input_delay")
	album.call(&"confirm")
	await _frames(6)
	print("render_extra_life: ficha «%s»: %s" % [album.call(&"get_card_title"), album.call(&"get_card_text")])
	_check(album.call(&"get_card_title") == "Vida extra", "la ficha no es la de la vida extra")
	await _save(out_dir, "05_album_ficha.png")
	hub.queue_free()
	await _frames(2)
	print("render_extra_life: %s" % ("OK" if _ok else "FALLO"))
	quit(0 if _ok else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		push_error("render_extra_life: " + what)


func _wait(cond: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_confirm_lines()
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i: int in n:
		_confirm_lines()
		await process_frame


## Cierra (como el jugador) las lineas importantes de Eco, que pausan el juego.
func _confirm_lines() -> void:
	if not _auto_confirm or not is_instance_valid(_main):
		return
	var level: Node = _main.call(&"get_level")
	var box: Node = level.get_node_or_null(^"EcoTextBox") if is_instance_valid(level) else null
	while box != null and box.call(&"is_important") and box.call(&"confirm"):
		pass


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_extra_life: %s (%s)" % [path, error_string(err)])
