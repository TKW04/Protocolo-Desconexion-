# Reproductor con el boton de pausa (pause_player; 2026-10-22, paso 8 de
# docs/propuesta-mundo-2.md §8 y §3.4): un pulso de espaldas al boton lo pausa
# una sola vez y da el golpe al suelo (gesto Mantener presionado) para siempre
# (se guarda); Eco dice su frase del mundo (importante) y despues sale el aviso
# «Mantener presionado: mantén S / stick abajo»; con el gesto ya obtenido arranca
# pausado e inerte (sin linea, aviso ni Q); un game over sin guardar lo pierde y
# el reproductor vuelve a reproducir; guardado, va a la Papelera y se recupera.
# Sin tinte del nivel (eso es del interruptor «No molestar»). Ademas la sala de
# prueba reproductor_test con el Isak real.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ROOM_SCENE: String = "res://scenes/levels/reproductor_test.tscn"
const PATH: String = "user://test_pause_player_save.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND
const POUND_NOTICE: String = "Mantener presionado: mantén S / stick abajo"
const ECO_LINE: String = "Mira cuánto tiempo ahorramos juntos."

var _root: Node2D
var _isak: Isak
var _pulse: Area2D
var _saved_path: String
var _saved_pause: bool
var _lines: Array[Dictionary] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	GameState.set_ability_unlocked(POUND, false)
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)
	_root = Node2D.new()
	_root.name = "PausePlayerTest"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_root.add_child(_isak)
	add_child(_root)
	_isak.set_physics_process(false)
	_pulse = Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	shape.position = Vector2(0, -56)
	_pulse.add_child(shape)
	_isak.add_child(_pulse)
	await wait_process_frames(1)


func after_each() -> void:
	EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	GameState.reset_progress()
	GameState.set_ability_unlocked(POUND, false)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _on_line(text: String, _duration: float, important: bool) -> void:
	_lines.append({"text": text, "important": important})


func _player(cell: Vector2i = Vector2i(4, 9)) -> PausePlayer:
	var path: String = String(World2ObjectsConfig.data().get("types", {}).get("pause_player", {}).get("scene", ""))
	var node := (load(path) as PackedScene).instantiate() as PausePlayer
	node.object_id = &"reproductor_prueba"
	node.ability = POUND
	node.story_line = "pausa_2_2"
	node.position = Vector2(cell) * TILE
	_root.add_child(node)
	return node


func _isak_at(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)


func _fire_pulse() -> void:
	EventBus.pulse_fired.emit(_pulse)


func _notices() -> AbilityNotices:
	var notices := AbilityNotices.new()
	notices.auto_advance = false
	_root.add_child(notices)
	notices.begin_level()
	notices.advance(5.0)
	return notices


# --- Catalogo ---

func test_catalog_gives_only_the_ground_pound_with_the_world_line() -> void:
	var entry: Dictionary = World2ObjectsConfig.data().get("types", {}).get("pause_player", {})
	assert_eq(entry.get("scene"), "res://scenes/levels/pause_player.tscn")
	assert_eq(entry.get("help_id"), "pause_player")
	assert_eq(entry.get("allowed", {}).get("ability"), ["ground_pound"])
	var section: Dictionary = World2ObjectsConfig.section("pause_player")
	assert_eq(String(section.get("story_lines", {}).get("pausa_2_2", "")), ECO_LINE,
		"La frase del mundo de Eco, decidida en mundo-2 §7.5")
	assert_false(section.has("room_tint"), "Sin tinte del nivel")
	var help: Dictionary = HelpCatalog.shared().entry(&"pause_player")
	assert_eq(int(help.get("world", 0)), 2, "Ayuda del Mundo 2")


# --- Una sola vez ---

func test_one_pulse_gives_the_ground_pound_then_story_then_notice() -> void:
	var notices := _notices()
	var player := _player()
	await wait_process_frames(1)
	assert_false(player.is_on())
	assert_true(player.is_help_available())
	assert_eq(player.get_animation(), PausePlayer.ANIM_OFF)
	var before: float = player.get_progress()
	player.advance(1.0)
	assert_ne(player.get_progress(), before, "Reproduciendo: la barra avanza")
	_isak_at(10, 9)
	_fire_pulse()
	assert_false(player.is_on(), "Lejos: no llega")
	_isak_at(4, 9)
	watch_signals(player)
	_fire_pulse()
	assert_true(player.is_on(), "Un pulso al boton lo pausa")
	assert_signal_emitted_with_parameters(player, "switched_on", [&"reproductor_prueba", true])
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	assert_true(GameState.is_ability_obtained(POUND), "Obtiene el golpe al suelo para siempre")
	assert_true(GameState.is_ability_unlocked(POUND))
	assert_true(GameState.has_unsaved_changes(), "Queda «sin guardar», como toda habilidad")
	assert_true(GameState.to_save_data().get("abilities_obtained", []).has("ground_pound"), "En la copia")
	assert_eq(_lines.size(), 2, "Linea de Eco y aviso de control")
	assert_true(_lines[0].important and _lines[1].important, "Las dos importantes (pausan)")
	assert_eq(String(_lines[0].text), ECO_LINE, "Primero la frase de Eco")
	assert_eq(String(_lines[1].text), POUND_NOTICE, "Despues el aviso, leido del Input Map")
	assert_true(GameState.is_notice_seen(POUND))
	assert_eq(player.get_animation(), PausePlayer.ANIM_HIT)
	assert_false(player.is_room_tinted(), "No tine el nivel")
	player.advance(0.5)
	assert_false(_isak.is_facing_back(), "Vuelve de perfil tras pose_s")
	assert_eq(player.get_animation(), PausePlayer.ANIM_ON)
	var paused: float = player.get_progress()
	player.advance(2.0)
	assert_eq(player.get_progress(), paused, "En pausa: la barra no avanza")
	assert_false(player.is_help_available(), "Pausado no ayuda")
	_lines.clear()
	assert_false(player.receive_pulse(_pulse), "Se pulsa una sola vez")
	assert_eq(_lines.size(), 0)
	notices.free()


func test_with_the_ground_pound_already_obtained_it_starts_paused_and_inert() -> void:
	GameState.obtain_ability(POUND)
	GameState.mark_notice_seen(POUND)
	_lines.clear()
	var player := _player()
	await wait_process_frames(1)
	assert_true(player.is_on(), "Arranca pausado")
	assert_true(player.is_inert())
	assert_false(HelpCatalog.is_help_live(player), "Sin Q")
	assert_false(player.is_room_tinted())
	_isak_at(4, 9)
	_fire_pulse()
	assert_false(_isak.is_facing_back(), "No responde")
	assert_eq(_lines.size(), 0, "Ni linea ni aviso")


# --- Guardado, game over y Papelera ---

func test_saved_and_reloaded() -> void:
	_player().switch_on()
	assert_true(GameState.save_game())
	assert_true(SaveFile.read(PATH).get("abilities_obtained", []).has("ground_pound"))
	GameState.reset_progress()
	assert_false(GameState.is_ability_unlocked(POUND))
	assert_true(GameState.load_game())
	assert_true(GameState.is_ability_obtained(POUND), "Tras cargar sigue obtenido")
	assert_true(GameState.is_ability_unlocked(POUND))
	var again := _player(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert(), "Con la partida cargada no se repite")


func test_game_over_without_saving_loses_the_gesture_and_the_player_comes_back() -> void:
	assert_true(GameState.save_game(), "Copia sin el gesto")
	_player().switch_on()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.is_ability_obtained(POUND), "Lo no guardado se pierde")
	assert_false(GameState.is_ability_unlocked(POUND))
	assert_false(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("ground_pound"), "No estaba guardado")
	var again := _player(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_false(again.is_on(), "Tras el rollback sin el gesto, vuelve a reproducir")
	_lines.clear()
	assert_true(again.switch_on())
	assert_true(GameState.is_ability_obtained(POUND), "Se obtiene otra vez")
	assert_eq(_lines.size(), 1, "Con la linea de Eco")


func test_saved_gesture_goes_to_the_trash_and_comes_back() -> void:
	_player().switch_on()
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("ground_pound"),
		"Eco lo desecha a la Papelera")
	assert_false(GameState.is_ability_unlocked(POUND), "Hasta recuperarlo no hay golpe al suelo")
	assert_true(GameState.recover_trash())
	assert_true(GameState.is_ability_obtained(POUND), "Recuperado de la Papelera")
	var again := _player(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert())


# --- Sala de prueba ---

func test_reproductor_test_room_with_the_real_isak() -> void:
	_root.free()
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	var sim := IsakSim.new(DT)
	sim.attach(room.get_node(^"Isak") as Isak)
	add_child_autofree(room)
	sim.take_manual_control()
	await wait_physics_frames(1)
	var player := room.get_node(^"Objects/reproductor_prueba") as PausePlayer
	assert_not_null(player, "El reproductor de la sala")
	assert_false(GameState.is_ability_unlocked(POUND), "La sala empieza sin el golpe al suelo")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))
	sim.isak.global_position = Vector2((6 + 0.5) * TILE, 10 * TILE)
	sim.settle()
	sim.input.hold_held = true
	sim.step(sim.steps_for(0.6))
	assert_ne(sim.state(), PlayerState.GROUND_POUND, "Sin el gesto no hay golpe al suelo")
	sim.input.hold_held = false
	sim.step(2)
	sim.input.pulse_pressed = true
	sim.step()
	assert_true(player.is_on(), "El pulso de espaldas al boton lo pausa")
	assert_true(GameState.is_ability_obtained(POUND))
	player.advance(0.5)
	sim.step_until(func() -> bool: return sim.state() == PlayerState.IDLE and not sim.isak.is_facing_back(),
		sim.steps_for(1.5))
	var landed: Array[Rect2] = []
	sim.isak.ground_pound_landed.connect(func(rect: Rect2) -> void: landed.append(rect))
	sim.input.hold_held = true
	sim.step_until(func() -> bool: return landed.size() > 0, sim.steps_for(3.0))
	sim.input.hold_held = false
	assert_eq(landed.size(), 1, "Ya puede golpear el suelo")
	var hud := room.get_node_or_null(^"HUD") as Hud
	if hud == null:
		for child: Node in room.get_children():
			if child is Hud:
				hud = child
	assert_not_null(hud, "La sala tiene HUD")
	assert_true(hud.get_clock().is_shown(), "Mundo 2: el reloj del HUD se ve")
