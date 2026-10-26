# Power bank como COLECCIONABLE PURO (decision del usuario 2026-10-25,
# docs/propuesta-mejoras.md §5.1; sustituye al tope de 3, a los power banks
# vacios que se cargaban con el sobrante y al aviso «Sin espacio»): el de mapa
# llega completo y sin tope; el sobrante de energia con la barra llena se pierde;
# el nivel 5 de una pista gasta uno; contador por nivel (recogidos/total) en el
# HUD y en la carpeta; encontrados y gastados en Calc y Notas. Calc no los vende.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/power_bank_pickup.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const PATH: String = "user://test_power_bank_collectible_save.json"
const EPS: float = 0.001

var _saved_path: String
var _saved_level: StringName


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.use_save_path(PATH, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func after_each() -> void:
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _level_with_pickup(id: StringName) -> GeneratedLevel:
	var level := LEVEL_SCENE.instantiate() as GeneratedLevel
	var pickup := PICKUP_SCENE.instantiate() as PowerBankPickup
	pickup.name = String(id)
	pickup.object_id = id
	level.get_node(^"Objects").add_child(pickup)
	add_child(level)
	return level


func test_data_has_no_charge_cap_or_no_room() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/power_bank.json"))
	for key: String in ["capacity_energy", "max_total", "no_room", "attention_point_energy_overflows"]:
		assert_false(data.has(key), "Sin '%s' (coleccionable puro)" % key)
	assert_false(GameState.has_method(&"can_take_power_bank"), "Sin tope")
	assert_false(GameState.has_method(&"add_power_bank_charge"), "Sin carga")
	assert_false(&"empty_power_banks" in GameState, "Sin power banks vacios")


func test_map_pickup_gives_a_full_power_bank_without_cap() -> void:
	GameState.power_banks = 7
	assert_true(GameState.collect_power_bank_pickup(&"1-2", &"pb_a"), "Sin tope: siempre se recoge")
	assert_eq(GameState.power_banks, 8, "Llega completo")
	assert_true(GameState.is_pickup_collected(&"1-2", &"pb_a"))
	assert_true(GameState.has_unsaved_changes())
	assert_false(GameState.collect_power_bank_pickup(&"1-2", &"pb_a"), "Una sola vez")
	assert_eq(GameState.power_banks, 8)


func test_map_pickup_in_level_is_taken_and_does_not_reappear() -> void:
	GameState.power_banks = 3
	var level: GeneratedLevel = _level_with_pickup(&"pb_mapa")
	var pickup := level.get_node(^"Objects/pb_mapa") as PowerBankPickup
	assert_eq(pickup.get_sprite_state(), &"power_bank_full", "Se ve completo")
	watch_signals(pickup)
	pickup._on_body_entered(level.get_isak())
	assert_true(pickup.is_taken(), "Se recoge aunque ya tenga 3")
	assert_signal_emitted(pickup, "collected")
	assert_eq(GameState.power_banks, 4)
	assert_true(GameState.is_pickup_collected(&"1-1", &"pb_mapa"))
	level.free()
	level = _level_with_pickup(&"pb_mapa")
	var again: Node = level.get_node_or_null(^"Objects/pb_mapa")
	assert_true(again == null or again.is_queued_for_deletion(), "No reaparece")
	level.free()


func test_overflow_energy_is_lost() -> void:
	GameState.debug_energy = 90.0
	var overflow: float = GameState.add_debug_energy(25.0)
	assert_almost_eq(GameState.debug_energy, 100.0, EPS, "Primero llena la barra")
	assert_almost_eq(overflow, 15.0, EPS, "Devuelve lo que no cupo")
	GameState.add_debug_energy(1000.0)
	assert_eq(GameState.power_banks, 0, "El sobrante no crea ni carga power banks")


func test_level_5_spends_one_and_counts_found_and_spent() -> void:
	EcoProgress.meet_calc()
	GameState.upgrade_levels[&"sync"] = 4
	GameState.lap = GameState.LAP_HARD
	GameState.attention_points = 25
	GameState.power_banks = 2
	assert_eq(GameState.get_power_banks_spent(), 0)
	assert_eq(GameState.get_power_banks_found(), 2)
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.power_banks, 1, "El nivel 5 gasta un power bank")
	assert_eq(GameState.get_power_banks_spent(), 1, "Gastados")
	assert_eq(GameState.get_power_banks_found(), 2, "Encontrados no cambia al gastar")


func test_level_5_without_power_bank_is_refused() -> void:
	EcoProgress.meet_calc()
	GameState.upgrade_levels[&"sync"] = 4
	GameState.lap = GameState.LAP_HARD
	GameState.attention_points = 25
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS)
	var hub: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub.json"))
	assert_eq(String(hub["calc"]["texts"]["state_not_enough_power_banks"]), "Falta un power bank completo")


func test_level_progress_counts_map_power_banks() -> void:
	assert_eq(GameState.level_power_bank_ids(&"1-1"), [&"power_bank_pulso_amplio"] as Array[StringName])
	assert_eq(GameState.get_level_power_bank_progress(&"1-1"), Vector2i(0, 1))
	GameState.collect_power_bank_pickup(&"1-1", &"power_bank_pulso_amplio")
	assert_eq(GameState.get_level_power_bank_progress(&"1-1"), Vector2i(1, 1))
	assert_eq(GameState.get_level_power_bank_progress(&"2-1"), Vector2i(0, 0), "El 2-1 no tiene")
	assert_eq(GameState.get_level_power_bank_progress(GameState.NO_LEVEL), Vector2i(0, 0))


func test_hud_shows_level_counter_only_in_levels_with_power_banks() -> void:
	GameState.current_level = &"1-1"
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	assert_true(hud.is_power_bank_shown(), "El 1-1 tiene un power bank")
	assert_eq(hud.get_power_bank_text(), "0/1")
	GameState.collect_power_bank_pickup(&"1-1", &"power_bank_pulso_amplio")
	assert_eq(hud.get_power_bank_text(), "1/1", "Se actualiza al recogerlo")
	var font := load(String(GameState.get_power_bank_hud_data()["font"])) as FontFile
	for c: String in hud.get_power_bank_text():
		assert_true(font.has_char(c.unicode_at(0)), "Glifo '%s' en la fuente de textos" % c)
	hud.enable_hub_mode({})
	assert_false(hud.is_power_bank_shown(), "En el hub no sale")


func test_hud_hides_counter_in_levels_without_power_banks() -> void:
	GameState.current_level = &"2-1"
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	assert_false(hud.is_power_bank_shown())


func test_save_keeps_full_and_old_empty_ones_become_full() -> void:
	GameState.power_banks = 2
	var data: Dictionary = GameState.to_save_data()
	assert_eq(data["power_banks"], {"full": 2})
	SaveFile.write(PATH, {"version": 5, "power_banks": {"full": 1, "empty": 2, "charge": 120.0}})
	GameState.load_game()
	assert_eq(GameState.power_banks, 3, "Los vacios de un guardado anterior pasan a completos")


func test_trash_and_recover_keep_power_banks() -> void:
	GameState.power_banks = 2
	var trash: Dictionary = GameState.discard_to_trash()
	assert_eq(int(trash[GameState.TRASH_POWER_BANKS]), 2)
	assert_eq(GameState.power_banks, 0)
	assert_true(GameState.recover_trash())
	assert_eq(GameState.power_banks, 2)


func test_calc_does_not_sell_power_banks() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades.json"))
	for track: Dictionary in data["tracks"]:
		assert_ne(String(track["id"]), "power_bank")
		for level: Dictionary in track["levels"]:
			for effect: Dictionary in level["effects"]:
				assert_false(String(effect["target"]).contains("power_bank"), "Ningun nivel da power banks")
