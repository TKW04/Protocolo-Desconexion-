# Acertijo «Actualizacion del sistema» de la pagina 2 del hub (2026-10-27, paso
# 3 de docs/propuesta-hub-mundos-4-6.md §2; HubUpdatePuzzle, data/hub_update.json).
# Positivos: cada verificacion se resuelve con las habilidades previstas (V1:
# Debug + laser + pulso; V2: golpe al suelo + salto + dash aereo + pulso; V3:
# laser por el espejo + Pellizcar + pulso) y con 3/3 el pulso al instalador
# PIDE la instalacion (la secuencia es del paso 5: tests/test_hub_update_install.gd). Negativos de §2.7: sin el Debug
# lector1 no se ve ni se le apunta; sin cable el pulso a RE no hace nada; la
# placa solo responde al golpe al suelo; la plataforma baja a los 3 s con aviso;
# sin dash V2 no se alcanza; sin marco iluminado o sin comprimirse no se entra
# al nicho; comprimido no hay pulso; con la Papelera llena todo esta inerte; las
# verificaciones se reinician en cada visita; sin atascos (lo temporal vuelve y
# se puede salir del nicho). Fisica real del hub con entrada falsa.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_update_puzzle.json"
const T: float = 64.0
## Borde izquierdo de la pagina 2 (x de la sala).
const X0: float = 1280.0
const FLOOR_Y: float = 576.0
const UPGRADE: StringName = &"hub_update_4_6"
const ALL: Array[StringName] = [&"pulse", &"laser", &"debug", &"dash", &"ground_pound", &"compress"]

var _hub: HubRoom
var _puzzle: HubUpdatePuzzle
var _isak: Isak
var _input: PlayerInput
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in ALL:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	_puzzle = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])


# --- Utilidades ---

func _obtain(abilities: Array[StringName]) -> void:
	for ability: StringName in abilities:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)


func _spawn() -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_puzzle = _hub.get_update_puzzle()
	_isak = _hub.get_isak()
	_input = PlayerInput.new()
	_isak.input = _input
	return _hub


## Hub con la Curadora vencida y las habilidades `abilities` obtenidas.
func _setup(abilities: Array[StringName] = ALL) -> void:
	_obtain(abilities)
	GameState.mark_level_completed(&"3-boss")
	_spawn()


## Coloca a Isak con los pies en (columna local `col` de la pagina 2, `feet_y`).
func _place(col: float, feet_y: float = FLOOR_Y, facing: float = 1.0) -> void:
	_isak.global_position = Vector2(X0 + col * T, feet_y)
	_isak.velocity = Vector2.ZERO
	_isak.facing = facing
	await wait_physics_frames(3)
	_hub.finish_page_slide()
	await wait_physics_frames(2)


func _tap(field: StringName) -> void:
	_input.set(field, true)
	await wait_physics_frames(2)
	_input.set(field, false)


func _wait_on_floor(max_frames: int = 180) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if _isak.is_on_floor() and absf(_isak.velocity.y) < 1.0:
			return


func _debug_on() -> void:
	for i: int in 120:
		DebugMode.step(1.0 / 60.0, true)
		if DebugMode.is_active():
			break


func _fire_laser() -> void:
	await _tap(&"laser_pressed")
	await wait_physics_frames(40)


## Pulso y espera a que acabe su pose (0,3 s).
func _pulse() -> void:
	await _tap(&"pulse_pressed")
	await wait_physics_frames(30)


# --- Montaje ---

func test_no_puzzle_before_the_curator_or_once_installed() -> void:
	_obtain(ALL)
	_spawn()
	assert_null(_puzzle, "Sin La Curadora no hay acertijo")
	assert_null(_hub.get_update_charger())
	assert_false(_isak.hub_gestures, "Sin acertijo, sin gestos en el hub")
	assert_ne(_isak.dash_denial(), &"", "Dash bloqueado en el hub")
	_hub.free()
	GameState.mark_level_completed(&"3-boss")
	assert_true(GameState.install_hub_upgrade(UPGRADE))
	_spawn()
	assert_null(_puzzle, "Instalado: la pagina 2 ya no esta en instalacion")


func test_puzzle_mounts_on_page_two_at_zero_of_three() -> void:
	_setup()
	assert_not_null(_puzzle, "Pagina 2 en instalacion: acertijo montado")
	assert_eq(_puzzle.global_position, Vector2(X0, 0.0), "Origen en la pagina 2")
	assert_eq(_puzzle.get_check_ids(), [&"v1", &"v2", &"v3"] as Array[StringName])
	assert_eq(_puzzle.get_done_count(), 0)
	assert_eq(_puzzle.get_check(&"v1").frame_color, Color("#3dfff5"), "Cian")
	assert_eq(_puzzle.get_check(&"v2").frame_color, Color("#ffa858"), "Ambar")
	assert_eq(_puzzle.get_check(&"v3").frame_color, Color("#a6ff2e"), "Verde acido")
	var installer: HubInstaller = _puzzle.get_installer()
	assert_eq(installer.get_size(), Vector2(128.0, 192.0), "Instalador de 2 x 3")
	assert_eq(installer.get_plate_text(), "Verificaciones 0/3")
	var charger: Charger = _hub.get_update_charger()
	assert_not_null(charger, "cargador_p2")
	assert_true(charger.global_position.x >= X0 and charger.global_position.x < X0 + 1280.0, "En la pagina 2")
	assert_true(_puzzle.is_frame_blocked(), "El hueco del marco empieza cerrado")
	assert_true(_isak.hub_gestures, "Acertijo activo: gestos en el hub")
	assert_eq(_isak.dash_denial(), &"", "Dash obtenido disponible en el hub")
	assert_eq(_isak.compress_denial(), &"")
	assert_eq(_isak.ground_pound_denial(), &"")
	assert_false(_puzzle.is_inert())


func test_any_order_counts_and_updates_the_installer() -> void:
	_setup()
	assert_true(_puzzle.get_check(&"v3").complete())
	assert_true(_puzzle.get_check(&"v1").complete())
	assert_false(_puzzle.get_check(&"v1").complete(), "Encendida se queda")
	assert_eq(_puzzle.get_done(), [&"v3", &"v1"] as Array[StringName])
	assert_eq(_puzzle.get_installer().get_plate_text(), "Verificaciones 2/3")
	assert_eq(_puzzle.get_installer().get_missing(), [&"v2"] as Array[StringName])


# --- V1 cian «Integridad» ---

func test_v1_reader_is_hidden_and_untargetable_without_debug() -> void:
	_setup()
	var reader: LaserReceiver = _puzzle.get_reader1()
	assert_false(reader.is_targetable(), "Sin el Debug no se ve")
	assert_eq(reader.collision_layer, 0, "Ni se le puede apuntar")
	await _place(3.5, FLOOR_Y, -1.0)
	await _fire_laser()
	assert_false(reader.is_powered(), "El laser pasa sin darle")
	assert_eq(reader.get_hit_count(), 0)
	_debug_on()
	await wait_physics_frames(2)
	assert_true(reader.is_targetable(), "Con el Debug se ve")
	assert_ne(reader.collision_layer, 0)
	await _fire_laser()
	assert_true(reader.is_powered(), "Con el Debug, laser a lector1: corriente")


func test_v1_relay_without_power_does_nothing_and_with_power_lights_v1() -> void:
	_setup()
	var relay: RelayReceiver = _puzzle.get_relay()
	var shelf_y: float = FLOOR_Y - 160.0
	await _place(5.5, shelf_y, -1.0)
	assert_true(_isak.is_on_floor(), "De pie en la repisa de RE")
	await _pulse()
	assert_eq(relay.get_rejection_count(), 1, "Sin cable: chispa gris")
	assert_false(_puzzle.get_check(&"v1").is_completed())
	# Debug + laser a lector1 desde el suelo y pulso a RE dentro de los 6 s.
	_debug_on()
	await _place(3.5, FLOOR_Y, -1.0)
	await _fire_laser()
	DebugMode.reset()
	assert_true(_puzzle.get_reader1().is_powered())
	await _place(5.5, shelf_y, -1.0)
	await _pulse()
	assert_true(relay.is_active(), "Con corriente, el pulso activa RE")
	assert_true(_puzzle.get_check(&"v1").is_completed(), "V1 encendida")
	assert_eq(_puzzle.get_done_count(), 1)


func test_v1_window_runs_out_and_can_be_repeated() -> void:
	_setup()
	var reader: LaserReceiver = _puzzle.get_reader1()
	reader.power()
	reader.advance(6.1)
	assert_false(reader.is_powered(), "La ventana de 6 s se acaba sola")
	await _place(5.5, FLOOR_Y - 160.0, -1.0)
	await _pulse()
	assert_false(_puzzle.get_check(&"v1").is_completed(), "Sin corriente no vale")
	reader.power()
	await _pulse()
	assert_true(_puzzle.get_check(&"v1").is_completed(), "Se repite sin castigo")


func test_relay_is_not_reached_from_the_floor() -> void:
	_setup()
	_puzzle.get_reader1().power()
	await _place(4.5, FLOOR_Y)
	await _pulse()
	assert_false(_puzzle.get_relay().is_active(), "RE pide subir a la repisa")


# --- V2 ambar «Bufer» ---

func test_plate_only_responds_to_ground_pound() -> void:
	_setup()
	var plate: PoundPlate = _puzzle.get_plate()
	await _place(9.5)
	await _pulse()
	assert_false(plate.is_platform_up(), "El pulso no hace nada a la placa")
	# El instalador esta al lado: ese pulso abre su panel; se cierra.
	if _puzzle.get_installer().is_panel_open():
		_puzzle.get_installer().close(true)
	await wait_physics_frames(4)
	assert_eq(_isak.ground_pound_denial(), &"", "El golpe sale")
	_input.hold_held = true
	for i: int in 60:
		await wait_physics_frames(1)
		if plate.is_platform_up():
			break
	_input.hold_held = false
	assert_true(plate.is_platform_up(), "El golpe al suelo sube la plataforma")
	await wait_physics_frames(2)
	assert_true(plate.is_platform_solid())


func test_platform_lowers_after_3_s_with_a_warning() -> void:
	_setup()
	var plate: PoundPlate = _puzzle.get_plate()
	plate.set_process(false)
	assert_true(plate.press())
	plate.advance(2.4)
	assert_true(plate.is_platform_up())
	assert_false(plate.is_warning())
	plate.advance(0.2)
	assert_true(plate.is_warning(), "Aviso en los ultimos 0,5 s")
	plate.advance(0.5)
	assert_false(plate.is_platform_up(), "Baja a los 3 s")
	await wait_physics_frames(2)
	assert_false(plate.is_platform_solid())
	assert_eq(plate.get_lowered_count(), 1)
	assert_true(plate.press(), "Se repite sin limite")
	assert_true(plate.is_platform_up())


## Desde la plataforma: corre, salta y (con `dash`) dash aereo en lo alto.
func _jump_from_platform(dash: bool) -> void:
	var plate: PoundPlate = _puzzle.get_plate()
	assert_true(plate.press())
	await wait_physics_frames(2)
	await _place(10.2, 448.0)
	assert_true(_isak.is_on_floor(), "De pie en la plataforma")
	_input.run_held = true
	_input.move_axis = 1.0
	for i: int in 120:
		await wait_physics_frames(1)
		if _isak.global_position.x >= X0 + 760.0:
			break
	_input.jump_pressed = true
	_input.jump_held = true
	await wait_physics_frames(2)
	_input.jump_pressed = false
	await wait_physics_frames(20)
	if dash:
		await _tap(&"dash_pressed")
	_input.jump_held = false
	for i: int in 120:
		await wait_physics_frames(1)
		if _isak.is_on_floor():
			break
	_input.move_axis = 0.0
	_input.run_held = false
	await wait_physics_frames(10)


func test_v2_is_reached_with_the_air_dash_and_lit_with_a_pulse() -> void:
	_setup()
	await _jump_from_platform(true)
	assert_almost_eq(_isak.global_position.y, 320.0, 2.0, "Sobre el bloque alto de V2")
	await _place(18.2, 320.0)
	await _pulse()
	assert_true(_puzzle.get_check(&"v2").is_completed(), "V2 encendida")


func test_without_dash_v2_is_not_reached() -> void:
	_setup([&"pulse", &"laser", &"debug", &"ground_pound", &"compress"])
	assert_ne(_isak.dash_denial(), &"", "Sin el dash obtenido")
	await _jump_from_platform(true)
	assert_almost_eq(_isak.global_position.y, FLOOR_Y, 2.0, "Cae al suelo")
	await _jump_from_platform(false)
	assert_almost_eq(_isak.global_position.y, FLOOR_Y, 2.0, "Ni corriendo sin dash")
	assert_false(_puzzle.get_check(&"v2").is_completed())


func test_block_is_out_of_reach_from_the_floor() -> void:
	_setup()
	await _place(15.5)
	_input.jump_pressed = true
	_input.jump_held = true
	_input.move_axis = 1.0
	await wait_physics_frames(2)
	_input.jump_pressed = false
	await _tap(&"dash_pressed")
	await _wait_on_floor()
	_input.jump_held = false
	_input.move_axis = 0.0
	assert_gt(_isak.global_position.y, 330.0, "Desde el suelo no se sube al bloque")


# --- V3 verde acido «Recorte» ---

func test_v3_laser_through_the_mirror_lights_the_frame() -> void:
	_setup()
	await _place(15.5)
	_input.move_axis = 1.0
	await wait_physics_frames(40)
	_input.move_axis = 0.0
	assert_lt(_isak.global_position.x, X0 + 17.0 * T, "Sin marco iluminado el hueco esta cerrado")
	await _place(13.5)
	await _fire_laser()
	assert_true(_puzzle.get_reader3().is_done(), "Laser al espejo, sube a lector3")
	assert_true(_puzzle.is_frame_lit(), "El marco se ilumina")
	await wait_physics_frames(2)
	assert_false(_puzzle.is_frame_blocked(), "El hueco queda abierto (permanente)")
	assert_false(_puzzle.get_check(&"v3").is_completed(), "Aun falta entrar y pulsar")


func test_v3_needs_compress_and_no_pulse_while_compressed() -> void:
	_setup()
	_puzzle.get_reader3().power()
	await wait_physics_frames(2)
	assert_true(_puzzle.is_frame_lit())
	# De tamano normal no cabe por el hueco de 1 tile.
	await _place(15.5)
	_input.move_axis = 1.0
	await wait_physics_frames(40)
	_input.move_axis = 0.0
	assert_lt(_isak.global_position.x, X0 + 17.0 * T, "Sin comprimirse no se entra al nicho")
	# Comprimido si.
	await _tap(&"pinch_pressed")
	assert_true(_isak.is_compressed())
	_input.move_axis = 1.0
	await wait_physics_frames(90)
	_input.move_axis = 0.0
	assert_gt(_isak.global_position.x, X0 + 18.0 * T, "Comprimido entra al nicho")
	await _pulse()
	assert_false(_puzzle.get_check(&"v3").is_completed(), "Comprimido no hay pulso")
	await _tap(&"pinch_pressed")
	await wait_physics_frames(20)
	assert_false(_isak.is_compressed(), "El nicho mide 2 tiles: vuelve al tamano")
	await _pulse()
	assert_true(_puzzle.get_check(&"v3").is_completed(), "V3 encendida")
	# Sin atasco: se vuelve a comprimir y se sale.
	await _tap(&"pinch_pressed")
	_input.move_axis = -1.0
	await wait_physics_frames(90)
	_input.move_axis = 0.0
	assert_lt(_isak.global_position.x, X0 + 17.0 * T, "Se sale del nicho comprimido")


func test_without_compress_the_niche_cannot_be_entered() -> void:
	_setup([&"pulse", &"laser", &"debug", &"dash", &"ground_pound"])
	_puzzle.get_reader3().power()
	await _place(15.5)
	await _tap(&"pinch_pressed")
	assert_false(_isak.is_compressed(), "Sin Pellizcar obtenido")
	_input.move_axis = 1.0
	await wait_physics_frames(60)
	_input.move_axis = 0.0
	assert_lt(_isak.global_position.x, X0 + 17.0 * T)
	assert_false(_puzzle.get_check(&"v3").is_completed())


# --- Instalador ---

func test_installer_with_less_than_three_lists_what_is_missing() -> void:
	_setup()
	_puzzle.get_check(&"v1").complete()
	var requested: Array[StringName] = []
	_hub.update_install_requested.connect(func(id: StringName) -> void: requested.append(id))
	await _place(8.0)
	await _pulse()
	var installer: HubInstaller = _puzzle.get_installer()
	assert_true(installer.is_panel_open(), "El pulso abre el panel")
	var lines: PackedStringArray = installer.get_panel().get_lines()
	assert_eq(lines[0], "Verificaciones 1/3")
	assert_eq(lines[1], "Falta: Búfer, Recorte")
	assert_true(requested.is_empty(), "Con menos de 3/3 no se pide nada")
	installer.close(true)


func test_three_of_three_requests_the_install_once() -> void:
	_setup()
	for id: StringName in [&"v1", &"v2", &"v3"]:
		_puzzle.get_check(id).complete()
	assert_true(_puzzle.is_complete())
	var requested: Array[StringName] = []
	_hub.update_install_requested.connect(func(id: StringName) -> void: requested.append(id))
	await _place(8.0)
	await _pulse()
	assert_eq(requested, [UPGRADE] as Array[StringName], "Con 3/3 se pide instalar")
	assert_true(_hub.is_update_install_requested())
	assert_eq(_hub.get_update_install_requested(), UPGRADE)
	assert_true(_puzzle.is_install_requested())
	assert_true(_hub.is_update_installing(), "Empieza la instalacion (paso 5; tests/test_hub_update_install.gd)")
	assert_false(GameState.has_hub_upgrade(UPGRADE), "Aun no instalado: la barra se esta llenando")
	assert_false(_puzzle.get_installer().is_panel_open(), "La instalacion cierra el panel del instalador")
	_puzzle.get_installer().open(_isak)
	assert_eq(requested.size(), 1, "Se pide una vez por visita")


# --- Papelera, reinicio por visita ---

func test_puzzle_is_inert_with_the_trash_full() -> void:
	_obtain(ALL)
	GameState.mark_level_completed(&"3-boss")
	assert_true(GameState.save_game())
	GameState.apply_rollback()
	assert_true(GameState.has_trash_pending(), "Game over: lo guardado a la Papelera")
	_spawn()
	assert_not_null(_puzzle, "La pagina 2 sigue en instalacion")
	assert_true(_puzzle.is_inert())
	assert_false(_isak.hub_gestures, "Sin gestos en el hub")
	assert_false(_puzzle.get_check(&"v1").complete(), "Verificaciones inertes")
	assert_false(_puzzle.get_plate().press(), "Placa inerte")
	var installer: HubInstaller = _puzzle.get_installer()
	assert_eq(installer.get_plate_text(), "Recupera tus archivos de la papelera")
	await _place(8.0)
	await _pulse()
	assert_true(installer.is_panel_open())
	assert_eq(installer.get_panel().get_lines()[0], "Recupera tus archivos de la papelera")
	installer.close(true)
	assert_true(GameState.recover_trash())
	_puzzle.refresh_inert()
	assert_false(_puzzle.is_inert(), "Al recuperarla vuelve a funcionar")
	assert_true(_isak.hub_gestures)
	assert_true(_puzzle.get_check(&"v1").complete())


func test_checks_reset_on_every_visit() -> void:
	_setup()
	_puzzle.get_check(&"v1").complete()
	_puzzle.get_check(&"v2").complete()
	_puzzle.get_reader3().power()
	assert_eq(_puzzle.get_done_count(), 2)
	_hub.free()
	_spawn()
	assert_eq(_puzzle.get_done_count(), 0, "No se guardan: 0/3 al volver")
	assert_true(_puzzle.is_frame_blocked(), "El marco vuelve a estar cerrado")
	assert_false(_puzzle.get_relay().is_active())
