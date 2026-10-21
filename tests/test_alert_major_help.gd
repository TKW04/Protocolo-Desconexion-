# Textos, ayudas Q y sonidos de Alerta Mayor (paso 12 de
# docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21): las 7 ayudas nuevas
# existen en data/help.json (Mundo 1, primer nivel 1-boss, ficha del album) y
# los nodos del jefe las llevan (cuerpo, nucleo solo visible, Burbujas,
# pop-ups, escudo, rafaga, copias); las lineas del jefe las dice Eco por el
# (interlocutor eco_boss, su blip vox_boss_eco_filter, sin pausa en los
# cambios de fase); mus_boss1 suena durante la pelea (BossMusic) y se quita en
# el golpe final.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-boss.tscn")
const DT: float = 1.0 / 60.0
const NEW_TYPES: Array[String] = ["alert_major", "alert_major_core", "alert_major_bubble", "alert_major_popup",
	"boss_popup_shield", "notification_shot", "alert_major_clone"]

var _level: GeneratedLevel
var _boss: AlertMajor


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func after_each() -> void:
	DebugMode.reset()
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _arena() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	add_child_autofree(_level)
	await wait_physics_frames(2)


func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		_boss.advance(DT)


func test_help_types_exist_with_album_cards() -> void:
	var catalog: HelpCatalog = HelpCatalog.shared()
	for id: String in NEW_TYPES:
		assert_true(catalog.has(StringName(id)), "%s en data/help.json" % id)
		var entry: Dictionary = catalog.entry(StringName(id))
		assert_eq(int(entry.get("world", 0)), 1, "%s: carpeta del Mundo 1" % id)
		assert_eq(String(entry.get("first_level", "")), "1-boss")
		assert_false(String(entry.get("text", "")).is_empty())
		for word: String in ["vuelta", "Easy", "Normal", "Hard"]:
			assert_false(String(entry.get("text", "")).contains(word))
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id),
			"%s: ficha del album" % id)
	assert_true(catalog.types_of_level(&"1-boss").size() >= NEW_TYPES.size())


func test_boss_nodes_carry_their_help() -> void:
	await _arena()
	var body: Node = _boss.get_node(^"Body")
	assert_eq(HelpCatalog.help_id_of(body), AlertMajor.HELP_BODY, "El cuerpo: alert_major")
	assert_true(HelpCatalog.is_help_live(body))
	var core: WeakPoint = _boss.get_core()
	assert_eq(HelpCatalog.help_id_of(core), AlertMajor.HELP_CORE)
	assert_false(HelpCatalog.is_help_live(core), "Nucleo oculto: sin ayuda (no delata donde esta)")
	_boss.start()
	_advance(2.0)
	var bubbles: Array[AlertBubble] = _boss.get_bubbles()
	assert_gt(bubbles.size(), 0, "Escupe Burbujas")
	for b: AlertBubble in bubbles:
		assert_eq(HelpCatalog.help_id_of(b), AlertMajor.HELP_BUBBLE, "Burbuja de la alerta")
	assert_true(_boss.start_burst() or _boss.get_phase() != 2)


func test_core_help_only_when_visible() -> void:
	await _arena()
	_boss.start()
	var core: WeakPoint = _boss.get_core()
	core.set_enabled(true)
	assert_false(core.is_help_available(), "Activo pero oculto: sin ayuda")
	DebugMode.input_enabled = false
	core.set_mark_duration(4.0)
	core.call(&"_mark")
	assert_true(core.is_help_available(), "Marcado: se ve y tiene ayuda")
	DebugMode.input_enabled = true


func test_phase_lines_use_the_boss_speaker_without_pause() -> void:
	await _arena()
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	_boss.start()
	while _boss.get_phase() < 2:
		_boss.take_core_hit(1)
	var texts: Dictionary = _boss.get_config().get("texts", {})
	assert_eq(box.get_speaker_id(), AlertMajor.SPEAKER, "Eco habla por el jefe")
	assert_eq(box.get_text(), String((texts.get("phase_lines", {}) as Dictionary).get("2", "")))
	assert_false(box.is_important(), "Los cambios de fase no pausan")
	assert_false(get_tree().paused)
	assert_eq(AudioManager.blip_id_for(AlertMajor.SPEAKER), &"vox_boss_eco_filter", "Blip con filtro")


func test_music_during_the_fight_and_not_after_the_final_blow() -> void:
	await _arena()
	assert_null(_boss.get_music(), "Sin musica antes de empezar")
	_boss.start()
	assert_not_null(_boss.get_music(), "mus_boss1 (BossMusic) en la pelea")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_null(_boss.get_music(), "Se quita en el golpe final")


func test_shot_shield_and_clones_are_tagged() -> void:
	await _arena()
	_boss.start()
	while _boss.get_phase() < 2:
		_boss.take_core_hit(1)
	var shield: OverlayPopup = _boss.get_shield()
	assert_eq(HelpCatalog.help_id_of(shield), AlertMajor.HELP_SHIELD, "Pop-up escudo")
	assert_true(_boss.start_burst())
	_advance(1.2)
	var shots: Array[NotificationShot] = _boss.get_shots()
	assert_gt(shots.size(), 0, "Rafaga en vuelo")
	for shot: NotificationShot in shots:
		assert_eq(HelpCatalog.help_id_of(shot), AlertMajor.HELP_SHOT)
	_advance(8.0)
	for popup: OverlayPopup in _boss.get_popups():
		assert_eq(HelpCatalog.help_id_of(popup), AlertMajor.HELP_POPUP, "Pop-up insistente")
	while _boss.get_phase() < 3:
		_boss.take_core_hit(1)
	_advance(2.0)
	var clones: Array[AlertMajorClone] = _boss.get_clones()
	assert_gt(clones.size(), 0, "Copias en la fase 3")
	for clone: AlertMajorClone in clones:
		assert_eq(HelpCatalog.help_id_of(clone), AlertMajor.HELP_CLONE)
		assert_true(clone.is_help_available())
