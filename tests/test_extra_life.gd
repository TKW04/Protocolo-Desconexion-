# Vida extra y pared con glitch del secreto D del 1-1 (paso 14 de §10 de
# docs/propuesta-asistentes-y-vidas.md, 2026-10-16): sin Debug la pared es
# solida y la vida extra no se ve ni se coge; con el Debug activo e Isak cerca
# la pared se disuelve y deja ver la vida extra en su celda; recogerla sube
# lives_max para siempre (+1 tambien en el intento), la apunta en found_secrets
# (1-1 / D) y no reaparece (otra carga del mapa, guardar y cargar); un game over
# sin guardar la devuelve y lives_max vuelve al de la copia. HUD con 4 vidas,
# ayuda con Q y ficha del album.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/extra_life_pickup.tscn")
const GLITCH_SCENE: PackedScene = preload("res://scenes/levels/glitch_wall.tscn")
const PATH: String = "user://test_extra_life.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const LEVEL: StringName = &"1-1"
const SECRET: StringName = &"D"
const FORBIDDEN: Array[String] = ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]

var _saved_path: String
var _pulse_was: bool
var _debug_was: bool
var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_debug_was = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	get_tree().paused = false
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was)


# --- Utilidades ---

func _load() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)


func _place(col: float, row: int) -> void:
	_sim.input.move_axis = 0.0
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0
	_sim.settle()


func _wall() -> GlitchWall:
	return _level.get_node(^"Objects/glitch_wall_298_8") as GlitchWall


func _pickup() -> ExtraLifePickup:
	return _level.get_node_or_null(^"Objects/vida_extra_1_1") as ExtraLifePickup


func _activate_debug() -> void:
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT) + 1:
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


## Camina hacia la derecha `seconds` (fisica real de Isak, con frames de fisica
## para que las Area2D se enteren).
func _walk_right(seconds: float) -> void:
	_sim.input.move_axis = 1.0
	for i: int in roundi(seconds / DT):
		_sim.step()
		if i % 4 == 0:
			await wait_physics_frames(1)
	_sim.input.move_axis = 0.0


## Con Debug obtenido: Isak junto a la pared, Debug activo, la pared se abre y
## camina hasta la vida extra.
func _open_wall_and_collect() -> void:
	_place(295.0, 9)
	_activate_debug()
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return _wall().is_open(), 3.0)
	assert_true(_wall().is_open(), "La pared se abrio con el Debug")
	await _walk_right(1.5)
	await wait_physics_frames(2)


# --- Sin Debug ---

func test_wall_is_solid_and_life_hidden_without_debug() -> void:
	await _load()
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "En el 1-1 no hay Debug")
	var pickup: ExtraLifePickup = _pickup()
	assert_not_null(pickup, "La vida extra esta en la celda de la pared (298, 9)")
	assert_eq(pickup.secret_id, SECRET)
	assert_eq(pickup.get_wall(), _wall(), "La tapa la pared con glitch")
	assert_false(pickup.is_shown())
	assert_false(pickup.visible, "Oculta: sin Q ni dibujo")
	_place(295.0, 9)
	DebugMode.step(DT, true)  # el Debug bloqueado no se enciende
	assert_false(DebugMode.is_active())
	await _walk_right(2.0)
	await wait_physics_frames(2)
	assert_true(_wall().is_solid(), "Sigue solida")
	assert_false(_wall().is_open())
	assert_lt(_isak.global_position.x, 298.0 * T, "No la atraviesa")
	assert_eq(GameState.lives_max, GameState.LIVES_MAX_DEFAULT, "No se cogio")
	assert_false(GameState.is_secret_found(LEVEL, SECRET))


func test_debug_far_from_wall_does_not_open_it() -> void:
	EcoProgress.obtain_debug()
	await _load()
	_place(285.0, 9)
	_activate_debug()
	await wait_physics_frames(10)
	assert_false(_wall().is_dissolving() or _wall().is_open(), "Lejos (mas de 3 tiles) no se abre")


# --- Con Debug ---

func test_debug_opens_wall_and_extra_life_is_collected_once() -> void:
	EcoProgress.obtain_debug()
	await _load()
	GameState.refill_lives()
	assert_eq(GameState.lives, 3)
	watch_signals(_wall())
	await _open_wall_and_collect()
	assert_signal_emitted(_wall(), "dissolve_started")
	assert_signal_emitted(_wall(), "opened")
	assert_false(_wall().is_solid(), "Abierta ya no es solida")
	assert_eq(GameState.lives_max, 4, "Sube el maximo para siempre")
	assert_eq(GameState.lives, 4, "Y suma una vida al intento")
	assert_true(GameState.is_secret_found(LEVEL, SECRET), "Registro 1-1 / D")
	assert_true(GameState.has_unsaved_changes(), "Cambio sin guardar")
	assert_false(GameState.collect_extra_life(LEVEL, SECRET), "Una sola vez por mapa")
	assert_eq(GameState.lives_max, 4)
	await wait_seconds(0.8)
	assert_null(_pickup(), "Tras la recogida se libera")


func test_collected_life_does_not_reappear_on_reentry_or_after_load() -> void:
	EcoProgress.obtain_debug()
	await _load()
	await _open_wall_and_collect()
	assert_eq(GameState.lives_max, 4)
	_level.free()
	DebugMode.reset()
	await _load()
	await wait_physics_frames(2)
	assert_null(_pickup(), "Al reentrar al mapa no reaparece")
	assert_true(GameState.save_game())
	_level.free()
	GameState.reset_progress()
	assert_eq(GameState.lives_max, 3)
	assert_true(GameState.load_game())
	assert_eq(GameState.lives_max, 4, "lives_max se guarda")
	assert_true(GameState.is_secret_found(LEVEL, SECRET), "El secreto se guarda")
	assert_eq(GameState.to_save_data()["found_secrets"].get("1-1"), ["D"])
	await _load()
	await wait_physics_frames(2)
	assert_null(_pickup(), "Tras cargar no reaparece")


func test_game_over_without_saving_gives_the_life_back() -> void:
	EcoProgress.obtain_debug()
	assert_true(GameState.save_game(), "Copia sin la vida extra")
	await _load()
	await _open_wall_and_collect()
	assert_eq(GameState.lives_max, 4)
	_level.free()
	DebugMode.reset()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_eq(GameState.lives_max, 3, "lives_max vuelve al de la copia")
	assert_eq(GameState.lives, 3)
	assert_false(GameState.is_secret_found(LEVEL, SECRET), "La vida extra vuelve a estar disponible")
	GameState.recover_trash()
	assert_eq(GameState.lives_max, 3)
	await _load()
	await wait_physics_frames(2)
	assert_not_null(_pickup(), "Vuelve a estar en el mapa")


func test_saved_life_survives_game_over() -> void:
	GameState.collect_extra_life(LEVEL, SECRET)
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	GameState.recover_trash()
	assert_eq(GameState.lives_max, 4, "Guardada, el game over no la quita")
	assert_true(GameState.is_secret_found(LEVEL, SECRET))


# --- Objeto suelto ---

func test_pickup_without_wall_is_shown_and_found_one_is_not_created() -> void:
	var pickup := PICKUP_SCENE.instantiate() as ExtraLifePickup
	pickup.secret_id = &"Z"
	add_child_autofree(pickup)
	await wait_frames(2)
	assert_true(pickup.is_shown(), "Sin pared, visible")
	assert_eq(pickup.get_level_id(), GameState.NO_LEVEL)
	var wall := GLITCH_SCENE.instantiate() as GlitchWall
	add_child_autofree(wall)
	var hidden := PICKUP_SCENE.instantiate() as ExtraLifePickup
	hidden.secret_id = &"Y"
	hidden.position = Vector2(0.0, T)
	add_child_autofree(hidden)
	await wait_frames(2)
	assert_false(hidden.is_shown(), "Tapada por la pared")
	assert_false(hidden.collect(), "Oculta no se recoge")
	wall.open_with_debug()
	await wait_seconds(1.0)
	assert_true(wall.is_open())
	assert_true(hidden.is_shown(), "Al abrirse la pared aparece")


# --- HUD ---

func test_hud_shows_new_life_icon() -> void:
	EcoProgress.obtain_debug()
	await _load()
	GameState.refill_lives()
	var hud := _level.get_node(^"Hud") as Hud
	assert_true(hud.is_lives_shown())
	assert_eq(hud.get_life_icon_count(), 3)
	GameState.collect_extra_life(LEVEL, SECRET)
	assert_eq(hud.get_life_icon_count(), 4, "Un icono mas")
	assert_eq(hud.get_lives_lit(), 4)
	hud.finish_animations()
	for i: int in 6:
		GameState.add_max_life()
	assert_eq(hud.get_life_icon_count(), 1, "Mas de 8: un icono y «x<n>»")


# --- Ayuda y album ---

func test_help_and_album_card_exist() -> void:
	var catalog: HelpCatalog = HelpCatalog.shared()
	assert_true(catalog.has(&"extra_life"))
	var text: String = catalog.text(&"extra_life")
	assert_eq(text, "Una vida extra: sube tu máximo de vidas. Guárdala: si caes sin guardar, la pierdes.")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/help.json"))
	var entry: Dictionary = data["types"]["extra_life"]
	assert_eq(entry["category"], "object", "Ficha en la pestana Objetos")
	for word: String in FORBIDDEN:
		assert_false(text.contains(word), "Sin «%s»" % word)
		assert_false(String(entry["title"]).contains(word))
	assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_extra_life.png"))
	assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_extra_life_silhouette.png"))
	var catalog_objects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world1_objects.json"))
	assert_eq(catalog_objects["types"]["extra_life_pickup"]["help_id"], "extra_life")
	# La Q de la pared no cambia.
	assert_eq(catalog.text(&"glitch_wall"), "Eso es un error de visualización. Ignóralo, por favor.")
