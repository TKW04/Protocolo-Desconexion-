# Regeneracion pasiva (tanda M2 de docs/propuesta-mejoras.md §5.2 y §6,
# 2026-10-17): SOLO con Sync Rate 5 (1 Sync/s fuera de combate hasta el 60 % del
# maximo) y Energia 5 (0,5 % del maximo por segundo, 3 s despues del ultimo gasto;
# no con el Debug ni el Ocultarte; nunca desborda a los power banks). Sin esas
# mejoras no hay regeneracion pasiva. Condiciones en data/passive_regen.json.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const PATH: String = "user://test_passive_regen_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_player_hidden(false)
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


## Avanza `regen` `seconds` segundos (pasos de DT) junto a `isak` (puede ser null).
func _run(regen: PassiveRegen, seconds: float, isak: Node2D = null) -> void:
	for i: int in roundi(seconds / DT):
		regen.step(DT, isak)


func test_data_and_rates() -> void:
	var regen := PassiveRegen.new()
	assert_almost_eq(regen.out_of_combat_s, 6.0, EPS)
	assert_almost_eq(regen.sync_cap_fraction, 0.6, EPS)
	assert_almost_eq(regen.energy_delay_s, 3.0, EPS)
	assert_almost_eq(GameState.get_sync_regen_per_s(), 0.0, EPS, "Sin mejora no hay regeneracion")
	assert_almost_eq(GameState.get_energy_regen_pct_s(), 0.0, EPS)
	GameState.upgrade_levels[&"sync"] = 5
	GameState.upgrade_levels[&"energia"] = 5
	assert_almost_eq(GameState.get_sync_regen_per_s(), 1.0, EPS, "Sync 5: 1/s")
	assert_almost_eq(GameState.get_energy_regen_pct_s(), 0.5, EPS, "Energia 5: 0,5 %/s")
	assert_almost_eq(GameState.get_debug_energy_max(), 130.0, EPS, "Energia 5 no sube la capacidad")
	assert_almost_eq(GameState.get_sync_rate_max(), 130.0, EPS)


func test_no_regeneration_without_upgrades() -> void:
	GameState.sync_rate = 20.0
	GameState.debug_energy = 20.0
	var regen := PassiveRegen.new()
	_run(regen, 15.0)
	assert_almost_eq(GameState.sync_rate, 20.0, EPS, "Regla de siempre: sin regeneracion pasiva")
	assert_almost_eq(GameState.debug_energy, 20.0, EPS)


func test_sync_5_regenerates_out_of_combat_up_to_60_percent() -> void:
	GameState.upgrade_levels[&"sync"] = 5
	GameState.sync_rate = 50.0
	var regen := PassiveRegen.new()
	_run(regen, 5.9)
	assert_almost_eq(GameState.sync_rate, 50.0, EPS, "Antes de 6 s fuera de combate no sube")
	_run(regen, 2.1)
	assert_almost_eq(GameState.sync_rate, 52.0, 0.1, "Despues, 1 por segundo")
	_run(regen, 200.0)
	assert_almost_eq(GameState.sync_rate, 78.0, EPS, "Tope: 60 % del maximo efectivo (78 de 130)")
	GameState.sync_rate = 100.0
	_run(regen, 5.0)
	assert_almost_eq(GameState.sync_rate, 100.0, EPS, "Nunca baja lo que hay por encima del 60 %")


func test_sync_5_stops_in_combat() -> void:
	GameState.upgrade_levels[&"sync"] = 5
	GameState.sync_rate = 30.0
	var regen := PassiveRegen.new()
	_run(regen, 7.0)
	var before: float = GameState.sync_rate
	assert_gt(before, 30.0)
	# Un golpe (el Sync baja) reinicia los 6 s.
	GameState.sync_rate = before - 10.0
	_run(regen, 5.0)
	assert_almost_eq(GameState.sync_rate, before - 10.0, EPS, "Recibir dano: vuelve a esperar 6 s")
	# Disparar o lanzar el pulso tambien (Isak llama a note_combat).
	_run(regen, 0.5)
	regen.note_combat()
	_run(regen, 5.0)
	assert_almost_eq(GameState.sync_rate, before - 10.0, EPS, "Disparo o pulso: vuelve a esperar")
	_run(regen, 1.5)
	assert_gt(GameState.sync_rate, before - 10.0, "Fuera de combate otra vez")


func test_sync_5_active_enemy_nearby_is_combat() -> void:
	GameState.upgrade_levels[&"sync"] = 5
	GameState.sync_rate = 30.0
	var isak := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(isak)
	isak.global_position = Vector2(0.0, 0.0)
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	add_child_autofree(bubble)
	bubble.global_position = Vector2(200.0, 0.0)
	bubble.set_physics_process(false)
	var regen := PassiveRegen.new()
	assert_true(regen.is_in_combat(isak), "Burbuja patrullando a menos de 384 px: en combate")
	_run(regen, 8.0, isak)
	assert_almost_eq(GameState.sync_rate, 30.0, EPS, "Sin regeneracion con un enemigo activo cerca")
	bubble.stun()
	assert_false(regen.is_in_combat(isak), "Aturdida no cuenta")
	bubble.global_position = Vector2(2000.0, 0.0)
	bubble.reset_patrol()
	bubble.global_position = Vector2(2000.0, 0.0)
	assert_false(regen.is_in_combat(isak), "Lejos no cuenta")


func test_energy_5_regenerates_after_3_seconds() -> void:
	GameState.upgrade_levels[&"energia"] = 5
	GameState.debug_energy = 100.0
	var regen := PassiveRegen.new()
	GameState.debug_energy = 50.0  # gasto (disparo)
	_run(regen, 2.9)
	assert_almost_eq(GameState.debug_energy, 50.0, EPS, "Espera 3 s tras el ultimo gasto")
	_run(regen, 1.1)
	# 0,5 % de 130 = 0,65 por segundo.
	assert_almost_eq(GameState.debug_energy, 50.0 + 0.65 * 1.0, 0.05, "0,5 % del maximo por segundo")
	GameState.debug_energy -= 10.0
	_run(regen, 2.0)
	var after_spend: float = GameState.debug_energy
	_run(regen, 0.5)
	assert_almost_eq(GameState.debug_energy, after_spend, EPS, "Cada gasto reinicia los 3 s")


func test_energy_5_never_overflows_and_not_with_debug_or_hide() -> void:
	GameState.upgrade_levels[&"energia"] = 5
	GameState.empty_power_banks = 1
	GameState.debug_energy = 129.9
	var regen := PassiveRegen.new()
	_run(regen, 10.0)
	assert_almost_eq(GameState.debug_energy, 130.0, EPS, "Llena la barra")
	assert_almost_eq(GameState.power_bank_charge, 0.0, EPS, "Nunca desborda a los power banks")
	# Con el Ocultarte activo no recarga.
	GameState.debug_energy = 40.0
	regen.reset()
	GameState.set_player_hidden(true)
	_run(regen, 6.0)
	assert_almost_eq(GameState.debug_energy, 40.0, EPS, "No durante el Ocultarte")
	GameState.set_player_hidden(false)
	# Con el Debug activo tampoco.
	EcoProgress.obtain_debug()
	DebugMode.input_enabled = false
	DebugMode.step(DT, true)
	for i: int in 70:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active())
	var energy: float = GameState.debug_energy
	regen.reset()
	_run(regen, 4.0)
	assert_true(GameState.debug_energy <= energy + EPS, "No durante el Debug (solo gasta)")


func test_sync_5_not_while_hidden() -> void:
	GameState.upgrade_levels[&"sync"] = 5
	GameState.sync_rate = 30.0
	var regen := PassiveRegen.new()
	GameState.set_player_hidden(true)
	_run(regen, 10.0)
	assert_almost_eq(GameState.sync_rate, 30.0, EPS, "No durante el Ocultarte")


func test_isak_regenerates_in_level_but_not_in_hub_mode() -> void:
	GameState.upgrade_levels[&"energia"] = 5
	var isak := ISAK_SCENE.instantiate() as Isak
	isak.input = PlayerInput.new()
	add_child_autofree(isak)
	GameState.debug_energy = 50.0
	isak.get_passive_regen().reset()
	for i: int in roundi(5.0 / DT):
		isak.step(DT)
	assert_gt(GameState.debug_energy, 50.5, "En un nivel recarga")
	isak.level_mode = false
	var energy: float = GameState.debug_energy
	for i: int in roundi(5.0 / DT):
		isak.step(DT)
	assert_almost_eq(GameState.debug_energy, energy, EPS, "En el hub no")
	# Al reaparecer se reinicia la espera.
	isak.level_mode = true
	isak.respawn(Vector2.ZERO)
	assert_almost_eq(isak.get_passive_regen().get_since_spend_s(), 0.0, EPS)
