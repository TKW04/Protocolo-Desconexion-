# Lo destruido no ayuda (2026-10-16, fallo encontrado jugando el 1-1: tras
# cerrar el pop-up, Eco seguia junto a el con la Q). HelpCatalog.is_help_live:
# ni la Q, ni la relectura (Q apagada), ni Eco van a un objeto destruido,
# reventado, recogido, oculto, liberado o ya inerte; si deja de serlo mientras
# es el candidato, la Q desaparece y Eco vuelve a Isak. Una prueba por tipo con
# ayuda (los 14 de data/help.json, con su escena real).
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const TILE: float = 64.0
const FEET: Vector2 = Vector2(640.0, 400.0)
const STEP: float = 1.0 / 60.0

var _root: Node2D
var _isak: Isak
var _box: EcoTextBox
var _help: HelpSystem
var _eco: EcoCompanion
var _saved_pause_important: bool
var _settings_path: String


func before_each() -> void:
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	GameState.reset_progress()
	GameState.meet_ally(GameState.ALLY_ECO)
	_root = Node2D.new()
	_root.name = "InertHelpLevel"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_isak.position = FEET
	_root.add_child(_isak)
	_box = BOX_SCENE.instantiate() as EcoTextBox
	_box.name = "EcoTextBox"
	_root.add_child(_box)
	_help = HelpSystem.new()
	_help.name = "Help"
	_root.add_child(_help)
	add_child(_root)
	_eco = EcoCompanion.attach(_isak, _root)
	_eco.auto_advance = false
	_help.set_process(false)
	await wait_process_frames(2)
	_run(1.0)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	GameState.reset_progress()
	GameSettings.use_path(_settings_path, true)


func _run(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_eco.advance(STEP)
		_help.refresh()
		t += STEP


## Coloca `node` (con ayuda `help_id`) con su centro a un tile del centro de
## Isak y lo anade al nivel.
func _place(node: Node2D, help_id: StringName) -> Node2D:
	var center: Vector2 = FEET + Vector2(0.0, HelpCatalog.shared().isak_center_y()) + Vector2(TILE, 0.0)
	node.position = center - HelpCatalog.shared().center_offset(help_id)
	HelpCatalog.tag(node, help_id)
	_root.add_child(node)
	return node


func _scene(type: String) -> Node2D:
	var path: String = String(World1ObjectsConfig.type_entry(type).get("scene", ""))
	return (load(path) as PackedScene).instantiate() as Node2D


## Comprueba que `node` es el candidato con Eco junto a el, lo vuelve inerte
## con `make_inert` y comprueba que la Q desaparece y Eco vuelve a Isak.
func _assert_inert_drops_help(node: Node2D, make_inert: Callable, why: String) -> void:
	await wait_process_frames(1)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(node), "%s: antes ayuda" % why)
	assert_eq(_help.get_target(), node, "%s: candidato con Q" % why)
	assert_eq(_eco.get_help_target(), node, "%s: Eco junto a el" % why)
	make_inert.call()
	_run(STEP)
	assert_false(is_instance_valid(node) and HelpCatalog.is_help_live(node), "%s: ya no ayuda" % why)
	assert_null(_help.get_target(), "%s: sin Q" % why)
	assert_false(_help.is_prompt_visible(), "%s: la Q desaparece" % why)
	assert_false(_eco.is_helping(), "%s: Eco suelta el objeto" % why)
	_run(2.0)
	assert_lt(_eco.get_anchor().distance_to(_eco.get_follow_position()), 8.0, "%s: Eco vuelve a Isak" % why)
	assert_null(_help.get_target(), "%s: la Q no vuelve" % why)
	assert_false(_help.request_help(), "%s: help no hace nada" % why)
	assert_false(GameState.is_help_learned(HelpCatalog.help_id_of(node) if is_instance_valid(node) else &""),
		"%s: no se aprende nada" % why)


## Con el tipo aprendido: la Q apagada no sale sobre el objeto inerte.
func _assert_no_reread(node: Node2D, help_id: StringName, why: String) -> void:
	GameState.learn_help(help_id)
	_isak.velocity = Vector2.ZERO
	_help.update_still(5.0)
	_help.refresh()
	assert_ne(_help.get_reread_target(), node, "%s: sin Q apagada" % why)
	assert_false(_help.is_reread_visible(), "%s: sin relectura" % why)


# --- Por tipo ---

func test_closed_popup_gives_no_help() -> void:
	var popup := _scene("popup_blocker") as PopupBlocker
	_place(popup, &"popup_blocker")
	await _assert_inert_drops_help(popup, func() -> void: popup.close(), "pop-up cerrandose")
	popup.advance(2.0)
	assert_true(popup.is_closed())
	_run(STEP)
	assert_null(_help.get_target(), "pop-up cerrado: sin Q")
	_assert_no_reread(popup, &"popup_blocker", "pop-up cerrado")


func test_popped_bubble_gives_no_help() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.set_physics_process(false)
	_place(bubble, &"alert_bubble")
	await wait_process_frames(1)
	bubble.drops = {}  # Sus drops serian candidatos nuevos (con su propia ayuda).
	await _assert_inert_drops_help(bubble, func() -> void: bubble.pop(), "Burbuja reventada")
	if is_instance_valid(bubble):
		_assert_no_reread(bubble, &"alert_bubble", "Burbuja reventada")


func test_stunned_bubble_still_helps() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.set_physics_process(false)
	_place(bubble, &"alert_bubble")
	await wait_process_frames(1)
	bubble.stun()
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(bubble), "Aturdida sigue ahi (sirve de escalon): su ayuda no miente")
	assert_eq(_help.get_target(), bubble)


func test_activated_receiver_gives_no_help() -> void:
	var receiver := _scene("receiver") as PulseReceiver
	_place(receiver, &"receiver")
	await _assert_inert_drops_help(receiver, func() -> void: receiver.activate(), "receptor activado")
	_assert_no_reread(receiver, &"receiver", "receptor activado")


func test_extended_bridge_gives_no_help() -> void:
	var bridge := _scene("bridge_inactive") as PulseBridge
	_place(bridge, &"bridge")
	await _assert_inert_drops_help(bridge, func() -> void: bridge.activate(), "puente extendiendose")
	for i: int in 60:
		bridge.advance(0.1)
	assert_true(bridge.is_extended())
	_assert_no_reread(bridge, &"bridge", "puente extendido")


func test_dissolved_glitch_wall_gives_no_help() -> void:
	var wall := _scene("glitch_wall") as GlitchWall
	_place(wall, &"glitch_wall")
	await _assert_inert_drops_help(wall, func() -> void: wall.open_with_debug(), "pared disolviendose")
	for i: int in 60:
		wall.advance(0.1)
	assert_true(wall.is_open())
	_assert_no_reread(wall, &"glitch_wall", "pared disuelta")


func test_activated_exit_terminal_gives_no_help() -> void:
	var terminal := _scene("exit_terminal") as ExitTerminal
	_place(terminal, &"exit_terminal")
	await _assert_inert_drops_help(terminal, func() -> void: terminal.activate(null), "terminal activada")
	_assert_no_reread(terminal, &"exit_terminal", "terminal activada")


func test_collected_attention_point_gives_no_help() -> void:
	var point := (load("res://scenes/levels/attention_point.tscn") as PackedScene).instantiate() as AttentionPoint
	_place(point, &"attention_point")
	await _assert_inert_drops_help(point, func() -> void: point._on_body_entered(_isak), "punto recogido")


func test_collected_ability_pickup_gives_no_help() -> void:
	var pickup := _scene("ability_pickup") as AbilityPickup
	pickup.ability = &"laser"
	_place(pickup, &"ability_pickup")
	await _assert_inert_drops_help(pickup, func() -> void: pickup.collect_by(_isak), "chip recogido")


func test_collected_power_bank_gives_no_help() -> void:
	var pickup := _scene("power_bank_pickup") as PowerBankPickup
	_place(pickup, &"power_bank_pickup")
	await _assert_inert_drops_help(pickup, func() -> void: pickup._on_body_entered(_isak), "power bank recogido")


func test_collected_drops_give_no_help() -> void:
	for kind: StringName in [RechargePickup.KIND_ENERGY, RechargePickup.KIND_SYNC]:
		var pickup := RechargePickup.new()
		pickup.kind = kind
		pickup.amount = 5.0
		var help_id: StringName = RechargePickup.help_id_for(kind)
		_place(pickup, help_id)
		pickup._base_y = pickup.position.y
		await _assert_inert_drops_help(pickup, func() -> void: pickup.collect(), "drop %s recogido" % kind)


func test_extra_life_hidden_or_collected_gives_no_help() -> void:
	var wall := _scene("glitch_wall") as GlitchWall
	var pickup := _scene("extra_life_pickup") as ExtraLifePickup
	pickup.secret_id = &"D"
	_place(pickup, &"extra_life")
	wall.position = pickup.position
	HelpCatalog.tag(wall, &"")
	_root.add_child(wall)
	await wait_process_frames(2)
	_run(0.2)
	if not pickup.is_shown():
		assert_ne(_help.get_target(), pickup, "Tapada por la pared: sin Q")
		wall.open_with_debug()
		for i: int in 60:
			wall.advance(0.1)
		await wait_process_frames(2)
	assert_true(pickup.is_shown())
	await _assert_inert_drops_help(pickup, func() -> void: pickup.collect(), "vida extra recogida")


func test_spent_single_use_charger_gives_no_help() -> void:
	var charger := _scene("charger") as Charger
	charger.reusable = false
	_place(charger, &"charger")
	GameState.debug_energy = 0.0
	await _assert_inert_drops_help(charger, func() -> void: charger.try_use(_isak), "cargador gastado")


func test_reusable_charger_and_sync_point_keep_helping() -> void:
	var charger := _scene("charger") as Charger
	_place(charger, &"charger")
	await wait_process_frames(1)
	GameState.debug_energy = 0.0
	charger.try_use(_isak)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(charger), "Reutilizable: sigue siendo un cargador")
	assert_eq(_help.get_target(), charger)


func test_freed_and_hidden_targets_give_no_help() -> void:
	var node := Node2D.new()
	_place(node, &"receiver")
	_run(0.2)
	assert_eq(_help.get_target(), node)
	node.visible = false
	_run(STEP)
	assert_null(_help.get_target(), "Oculto: sin Q")
	assert_false(_eco.is_helping())
	node.visible = true
	_run(0.2)
	assert_eq(_help.get_target(), node)
	node.queue_free()
	assert_false(HelpCatalog.is_help_live(node), "Liberandose: ya no ayuda")
	_run(STEP)
	assert_null(_help.get_target(), "Liberandose: sin Q en el mismo cuadro")


func test_q_moves_to_the_next_live_candidate() -> void:
	var popup := _scene("popup_blocker") as PopupBlocker
	_place(popup, &"popup_blocker")
	var receiver := _scene("receiver") as PulseReceiver
	_place(receiver, &"receiver")
	receiver.position.x += TILE * 0.5
	await wait_process_frames(1)
	_run(0.2)
	assert_eq(_help.get_target(), popup, "El mas cercano")
	popup.close()
	_run(STEP)
	assert_eq(_help.get_target(), receiver, "Cerrado el pop-up, la Q pasa al receptor")


func test_every_help_type_is_covered() -> void:
	var covered: Array[StringName] = [&"popup_blocker", &"alert_bubble", &"receiver", &"bridge", &"glitch_wall",
		&"exit_terminal", &"attention_point", &"ability_pickup", &"power_bank_pickup", &"energy_drop", &"sync_drop",
		&"extra_life", &"charger", &"sync_point"]
	for id: StringName in HelpCatalog.shared().ids():
		assert_true(covered.has(id), "Tipo %s sin prueba de «lo destruido no ayuda»" % id)
