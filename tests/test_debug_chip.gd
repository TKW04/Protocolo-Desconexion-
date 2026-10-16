# Obtencion del Debug (paso 9 de docs/propuesta-1-2.md §10, §4.4; 2026-10-16):
# el chip (ability_pickup con ability debug) desbloquea el Debug para siempre
# (abilities_obtained, se guarda con la copia como el laser), llena la energia
# (refill_energy, decision aprobada), Eco dice su linea de historia como linea
# importante y DESPUES sale el aviso de control del Debug (AbilityNotices, leido
# del Input Map); con el Debug ya obtenido el chip no aparece ni repite nada.
# Tiene su propia ayuda con Q (debug_chip) y su arte (puzzle_objects_frames).
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/ability_pickup.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")

var _root: Node2D
var _isak: Isak
var _lines: Array[Dictionary] = []
var _saved_pause: bool


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	GameState.reset_progress()
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)
	_root = Node2D.new()
	_root.name = "DebugChipTest"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.set_physics_process(false)
	_root.add_child(_isak)
	add_child(_root)
	await wait_process_frames(1)


func after_each() -> void:
	EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	GameState.reset_progress()


func _on_line(text: String, _duration: float, important: bool) -> void:
	_lines.append({"text": text, "important": important})


func _chip(refill: bool = true) -> AbilityPickup:
	var pickup := PICKUP_SCENE.instantiate() as AbilityPickup
	pickup.object_id = &"debug_1_2"
	pickup.ability = GameState.ABILITY_DEBUG
	pickup.refill_energy = refill
	HelpCatalog.tag(pickup, &"ability_pickup")
	pickup.position = Vector2(200.0, 200.0)
	_root.add_child(pickup)
	return pickup


func _notices() -> AbilityNotices:
	var notices := AbilityNotices.new()
	notices.auto_advance = false
	_root.add_child(notices)
	notices.begin_level()
	notices.advance(5.0)
	return notices


func test_chip_unlocks_debug_for_good_and_fills_energy() -> void:
	GameState.debug_energy = 15.0
	var chip := _chip()
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG))
	assert_true(chip.collect_by(_isak))
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DEBUG), "Obtenido (se guarda como el laser)")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG))
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "Energia llena")
	assert_true(GameState.has_unsaved_changes(), "Queda «sin guardar», como toda habilidad")
	assert_true(GameState.to_save_data().get("abilities_obtained", []).has("debug"), "En la copia")


func test_without_refill_energy_is_left_alone() -> void:
	GameState.debug_energy = 15.0
	_chip(false).collect_by(_isak)
	assert_eq(GameState.debug_energy, 15.0)


func test_story_line_then_control_notice_both_important() -> void:
	GameState.set_nickname("Pixel")
	var notices := _notices()
	_lines.clear()
	_chip().collect_by(_isak)
	assert_eq(_lines.size(), 2, "Linea de historia y aviso de control")
	assert_true(_lines[0].important and _lines[1].important, "Las dos importantes (pausan)")
	assert_true(String(_lines[0].text).contains("diagnóstico"), "Primero, la historia de Eco")
	assert_true(String(_lines[0].text).contains("{apodo}"), "Con el apodo (lo sustituye el cuadro)")
	assert_true(GameState.apply_nickname(String(_lines[0].text)).contains("Pixel"))
	var expected: String = AbilityNotices.notice_text(GameState.ABILITY_DEBUG, AbilityNotices.load_data())
	assert_eq(String(_lines[1].text), expected, "Despues, el aviso del control")
	assert_true(expected.begins_with("Debug: mantén "), "Mantener, leido del Input Map")
	var key: String = AbilityNotices.control_text(&"debug", AbilityNotices.load_data())
	assert_true(expected.contains(key))
	assert_true(GameState.is_notice_seen(GameState.ABILITY_DEBUG))
	notices.free()


func test_story_box_shows_the_nickname() -> void:
	GameState.set_nickname("Pixel")
	var box := BOX_SCENE.instantiate() as EcoTextBox
	_root.add_child(box)
	await wait_process_frames(1)
	_chip().collect_by(_isak)
	await wait_process_frames(2)
	assert_true(box.get_text().contains("Pixel"), "El cuadro de Eco dice el apodo")
	assert_false(box.get_text().contains("{apodo}"))


func test_install_effect_runs_in_real_time_and_frees_itself() -> void:
	_chip().collect_by(_isak)
	var effect: InstallEffect = null
	for child: Node in _root.get_children():
		if child is InstallEffect:
			effect = child
	assert_not_null(effect, "Anillo y destello al instalarlo")
	assert_eq(effect.process_mode, Node.PROCESS_MODE_ALWAYS, "Se ve con la pausa de la linea")
	effect.advance(0.05)
	assert_true(effect.is_flashing(), "Destello del tinte del Debug")
	effect.advance(1.0)
	assert_true(effect.is_queued_for_deletion(), "Se libera solo")


func test_chip_does_not_appear_once_debug_is_obtained() -> void:
	_chip().collect_by(_isak)
	await wait_process_frames(1)
	_lines.clear()
	var again := _chip()
	await wait_process_frames(1)
	assert_true(not is_instance_valid(again) or again.is_queued_for_deletion(), "No reaparece")
	assert_true(again == null or not is_instance_valid(again) or not HelpCatalog.is_help_live(again), "Sin Q")
	assert_eq(_lines.size(), 0, "Ni historia ni aviso")


func test_after_rollback_without_it_the_chip_comes_back() -> void:
	_chip().collect_by(_isak)
	GameState.obtained_abilities.erase(GameState.ABILITY_DEBUG)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	var again := _chip()
	await wait_process_frames(1)
	assert_true(is_instance_valid(again) and not again.is_taken(), "Sin el Debug, el chip vuelve")


func test_chip_has_its_own_help_and_art() -> void:
	var chip := _chip()
	await wait_process_frames(1)
	assert_eq(HelpCatalog.help_id_of(chip), &"debug_chip", "Ayuda propia del chip del Debug")
	assert_true(HelpCatalog.shared().has(&"debug_chip"))
	var sprite := chip.get_node(^"Sprite") as EnergySprite
	assert_eq(sprite.animation, &"debug_chip_idle")
	var own := _chip()
	HelpCatalog.tag(own, &"")
	await wait_process_frames(1)
	assert_eq(HelpCatalog.help_id_of(own), &"", "Un help_id propio del nivel se respeta")


func test_laser_chip_is_unchanged() -> void:
	var pickup := PICKUP_SCENE.instantiate() as AbilityPickup
	pickup.ability = GameState.ABILITY_LASER
	HelpCatalog.tag(pickup, &"ability_pickup")
	_root.add_child(pickup)
	await wait_process_frames(1)
	assert_eq(HelpCatalog.help_id_of(pickup), &"ability_pickup")
	assert_eq(pickup.get_story_text(), "", "El laser cuenta su historia con su eco_line del 1-1")
	_lines.clear()
	var before: float = GameState.debug_energy
	pickup.collect_by(_isak)
	assert_eq(_lines.size(), 0)
	assert_eq(GameState.debug_energy, before)
