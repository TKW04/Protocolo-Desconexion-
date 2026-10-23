# Barra del jefe en el HUD (paso 9 de docs/propuesta-jefe-alerta-mayor.md §6,
# 2026-10-21): oculta fuera de la pelea, aparece con boss_started, el contador
# sigue 99+ -> 88 ... -> 0, segmentos llenos = golpes que quedan (legible sin
# color: huecos los dados), muescas de fase pasadas, destello al cambiar de
# fase, vuelve al principio de la fase al reaparecer, se oculta tras el golpe
# final y si el jefe desaparece; nunca dice vuelta/Easy/Normal/Hard.
extends GutTest

const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")

var _hud: Hud
var _bar: BossBar
var _boss: BossBase
var _saved_energy: float
var _saved_sync: float


func before_each() -> void:
	_saved_energy = GameState.debug_energy
	_saved_sync = GameState.sync_rate
	_hud = HUD_SCENE.instantiate() as Hud
	add_child_autofree(_hud)
	_bar = _hud.get_boss_bar()


func after_each() -> void:
	GameState.debug_energy = _saved_energy
	GameState.sync_rate = _saved_sync


func _spawn(lap: int = 1) -> BossBase:
	_boss = BossBase.new()
	_boss.boss_id = &"alert_major"
	_boss.auto_process = false
	_boss.lap_override = lap
	add_child_autofree(_boss)
	return _boss


func _hits(n: int) -> void:
	for i: int in n:
		_boss.take_core_hit(1)


func test_hidden_until_the_fight_starts() -> void:
	assert_not_null(_bar, "El HUD crea la barra del jefe")
	assert_false(_bar.visible, "Oculta fuera de una pelea")
	_spawn()
	assert_false(_bar.visible, "Oculta antes de empezar")
	_boss.start()
	assert_true(_bar.visible, "Aparece con boss_started")
	assert_eq(_bar.get_boss(), _boss)
	assert_eq(_bar.get_counter_text(), "99+")
	assert_eq(_bar.get_segment_count(), 9, "Un segmento por golpe (Caché: 9)")
	assert_eq(_bar.get_lit_segments(), 9)
	assert_eq(_bar.get_passed_notches(), 0)
	var rect: Rect2 = _bar.get_screen_rect()
	assert_almost_eq(rect.get_center().x, 640.0, 1.0, "Arriba en el centro")
	assert_gt(rect.position.y, 32.0, "Debajo de la barra de estado")


func test_counter_follows_the_hits_and_phase_notches() -> void:
	_spawn()
	_boss.start()
	var expected: Array[String] = ["88", "77", "66", "55", "44", "33", "22", "11", "0"]
	for i: int in 9:
		_boss.take_core_hit(1)
		assert_eq(_bar.get_counter_text(), expected[i], "Golpe %d" % (i + 1))
		assert_eq(_bar.get_lit_segments(), 8 - i, "Llenos = golpes que quedan")
		if i == 2:
			assert_eq(_bar.get_passed_notches(), 1, "66: una muesca pasada")
			assert_true(_bar.is_phase_flashing(), "Destello al cambiar de fase")
		elif i == 5:
			assert_eq(_bar.get_passed_notches(), 2, "33: dos muescas pasadas")
	assert_true(_bar.is_hiding(), "Tras el golpe final se oculta sola")


func test_respawn_restores_the_phase_in_the_bar() -> void:
	_spawn()
	_boss.start()
	_hits(4)
	assert_eq(_bar.get_counter_text(), "55")
	_boss.restart_phase()
	assert_eq(_bar.get_counter_text(), "66", "Al reaparecer, el principio de la fase")
	assert_eq(_bar.get_lit_segments(), 6)


func test_hides_after_defeat_and_when_the_boss_leaves() -> void:
	_spawn()
	_boss.start()
	_hits(9)
	assert_true(_bar.visible, "Se ve el 0 un momento")
	var wait: float = float(BossBar.load_config().get("hide_after_defeat_s", 1.2)) + 0.2
	await wait_seconds(wait)
	assert_false(_bar.visible, "Oculta tras el golpe final")
	_spawn()
	_boss.start()
	assert_true(_bar.visible)
	_boss.free()
	await wait_process_frames(2)
	assert_false(_bar.visible, "Oculta si el jefe sale del arbol")


func test_kernel_has_twelve_segments() -> void:
	_spawn(2)
	_boss.start()
	assert_eq(_bar.get_segment_count(), 12, "Kernel: 4/4/4")
	_hits(1)
	assert_eq(_bar.get_counter_text(), "91")


func test_text_never_names_laps() -> void:
	var notes: String = JSON.stringify(BossBar.load_config())
	_spawn(3)
	_boss.start()
	for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
		assert_false(_bar.get_counter_text().contains(word))
	assert_false(String(_boss.get_config().get("name", "")).contains("Raíz"), "Solo el nombre del jefe")
	assert_true(notes.contains("Nunca dice vuelta"))


# --- Paso 18 de docs/propuesta-mundo-2.md (2026-10-23): Autoplay ---

## Autoplay usa el estilo «barra de reproduccion» (styles.autoplay de
## data/hud.json): relleno = golpes que quedan / total, que baja con cada
## golpe, sube con la cuenta que cura y llega a 0 en el golpe final; Alerta
## Mayor sigue con sus segmentos.
func test_autoplay_bar_is_a_playback_bar() -> void:
	_boss = BossBase.new()
	_boss.boss_id = &"autoplay"
	_boss.auto_process = false
	_boss.lap_override = 1
	add_child_autofree(_boss)
	_boss.start()
	assert_true(_bar.visible)
	assert_eq(_bar.get_style(), "playback", "Barra de reproduccion")
	assert_eq(_bar.get_segment_count(), 9, "Caché: 3 golpes por fase")
	assert_almost_eq(_bar.get_playback_fraction(), 1.0, 0.001, "Llena al empezar")
	assert_eq(_bar.get_counter_text(), "99+")
	_boss.take_core_hit(1)
	assert_almost_eq(_bar.get_playback_fraction(), 8.0 / 9.0, 0.001, "Baja con el golpe")
	_boss.take_core_hit(1)
	_boss.take_core_hit(1)
	_boss.take_core_hit(1)
	assert_eq(_boss.get_phase(), 2)
	_boss.heal_hits(1)
	assert_almost_eq(_bar.get_playback_fraction(), 6.0 / 9.0, 0.001, "La cuenta que cura la rellena")
	assert_almost_eq(_bar.get_screen_rect().get_center().x, 640.0, 1.0, "Arriba en el centro")
	for i: int in 6:
		_boss.take_core_hit(1)
	assert_almost_eq(_bar.get_playback_fraction(), 0.0, 0.001, "Vacia en el golpe final")
	assert_true(_bar.is_hiding())


func test_alert_major_keeps_the_segments_after_autoplay() -> void:
	var other := BossBase.new()
	other.boss_id = &"autoplay"
	other.auto_process = false
	add_child_autofree(other)
	other.start()
	assert_eq(_bar.get_style(), "playback")
	other.queue_free()
	await wait_frames(2)
	_spawn()
	_boss.start()
	assert_eq(_bar.get_style(), "segments", "Alerta Mayor no hereda el estilo")
