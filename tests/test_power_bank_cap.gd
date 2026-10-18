# Tope de power banks (tanda M2 de docs/propuesta-mejoras.md §5.1, 2026-10-17):
# 3 a la vez (completos + vacios; max_total de data/power_bank.json), 200 de
# capacidad cada uno. Con el tope lleno el power bank de mapa no se recoge: sale
# «Sin espacio» y el objeto se queda en el mapa (no se apunta). El nivel 5 de una
# pista gasta uno completo y libera hueco. El sobrante de los drops sigue
# llenando los vacios como antes. Calc no vende power banks.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/power_bank_pickup.tscn")
const PATH: String = "user://test_power_bank_cap_save.json"
const EPS: float = 0.001

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func after_each() -> void:
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
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


func test_cap_and_capacity_come_from_data() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/power_bank.json"))
	assert_eq(int(data["max_total"]), 3)
	assert_eq(GameState.get_power_bank_max_total(), 3)
	assert_almost_eq(GameState.get_power_bank_capacity(), 200.0, EPS, "200 de energia cada uno")
	assert_eq(GameState.get_power_bank_no_room_data().get("text"), "Sin espacio")


func test_total_counts_full_and_empty() -> void:
	assert_true(GameState.can_take_power_bank())
	GameState.power_banks = 1
	GameState.empty_power_banks = 1
	assert_eq(GameState.get_power_bank_total(), 2)
	assert_true(GameState.can_take_power_bank(), "2 de 3: cabe otro")
	GameState.empty_power_banks = 2
	assert_eq(GameState.get_power_bank_total(), 3)
	assert_false(GameState.can_take_power_bank(), "3 de 3: tope lleno")


func test_collect_respects_cap_and_is_not_recorded() -> void:
	GameState.power_banks = 2
	GameState.empty_power_banks = 1
	assert_false(GameState.collect_power_bank_pickup(&"1-2", &"pb_c"), "Tope lleno")
	assert_false(GameState.is_pickup_collected(&"1-2", &"pb_c"), "No se apunta: se puede volver a por el")
	assert_eq(GameState.empty_power_banks, 1)
	assert_false(GameState.has_unsaved_changes())
	GameState.power_banks = 1
	assert_true(GameState.collect_power_bank_pickup(&"1-2", &"pb_c"), "Con hueco se recoge")
	assert_eq(GameState.empty_power_banks, 2)


func test_map_pickup_stays_with_no_room_notice() -> void:
	GameState.power_banks = 3
	var level: GeneratedLevel = _level_with_pickup(&"pb_lleno")
	var pickup := level.get_node(^"Objects/pb_lleno") as PowerBankPickup
	watch_signals(pickup)
	watch_signals(EventBus)
	pickup._on_body_entered(level.get_isak())
	assert_false(pickup.is_taken(), "No se recoge")
	assert_false(pickup.is_queued_for_deletion(), "Se queda en el mapa")
	assert_true(pickup.is_no_room_shown(), "Sale el aviso")
	assert_eq(pickup.get_no_room_text(), "Sin espacio")
	assert_signal_emitted(pickup, "no_room")
	assert_signal_emitted(EventBus, "power_bank_no_room")
	assert_false(GameState.is_pickup_collected(&"1-1", &"pb_lleno"))
	assert_eq(GameState.power_banks, 3)
	assert_eq(GameState.empty_power_banks, 0)
	# Al irse Isak el aviso dura show_s y se apaga.
	pickup._on_body_exited(level.get_isak())
	pickup._process(2.0)
	assert_false(pickup.is_no_room_shown(), "El aviso se apaga")
	# Pagar un nivel 5 libera hueco: al volver se recoge.
	GameState.power_banks = 2
	pickup._on_body_entered(level.get_isak())
	assert_true(pickup.is_taken(), "Con hueco se recoge")
	assert_eq(GameState.empty_power_banks, 1)
	assert_true(GameState.is_pickup_collected(&"1-1", &"pb_lleno"))
	level.free()


func test_level_5_purchase_frees_a_slot() -> void:
	EcoProgress.meet_calc()
	GameState.upgrade_levels[&"sync"] = 4
	GameState.lap = GameState.LAP_HARD
	GameState.attention_points = 25
	GameState.power_banks = 3
	assert_false(GameState.can_take_power_bank())
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.power_banks, 2, "El nivel 5 gasta un power bank completo")
	assert_true(GameState.can_take_power_bank(), "Y deja hueco")


func test_drop_overflow_still_fills_empty_banks() -> void:
	GameState.empty_power_banks = 3
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.add_debug_energy(250.0)
	assert_eq(GameState.power_banks, 1, "200 llenan uno")
	assert_eq(GameState.empty_power_banks, 2)
	assert_almost_eq(GameState.power_bank_charge, 50.0, EPS)
	assert_eq(GameState.get_power_bank_total(), 3, "El tope no cambia al cargarlos")


func test_migration_refunds_may_exceed_cap() -> void:
	GameState.power_banks = 3
	GameState.add_empty_power_bank(1)
	assert_eq(GameState.get_power_bank_total(), 4, "El tope solo impide recoger")
	assert_false(GameState.can_take_power_bank())


func test_calc_does_not_sell_power_banks() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades.json"))
	for track: Dictionary in data["tracks"]:
		assert_ne(String(track["id"]), "power_bank")
		for level: Dictionary in track["levels"]:
			for effect: Dictionary in level["effects"]:
				assert_false(String(effect["target"]).contains("power_bank"), "Ningun nivel da power banks")
