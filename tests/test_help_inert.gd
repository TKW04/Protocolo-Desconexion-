# Lo destruido no ayuda (2026-10-16, fallo encontrado jugando el 1-1: tras
# cerrar el pop-up, Eco seguia junto a el con la Q). HelpCatalog.is_help_live:
# ni la Q, ni la relectura (Q apagada), ni Eco van a un objeto destruido,
# reventado, recogido, oculto, liberado o ya inerte; si deja de serlo mientras
# es el candidato, la Q desaparece y Eco vuelve a Isak. Una prueba por tipo con
# ayuda (los de data/help.json, con su escena real; desde el 2026-10-16 tambien
# el lector laser, el receptor enlazado, el anuncio y el chip del Debug del 1-2;
# y el recordatorio, el Posponer, el pop-up translucido y la barra del 99 %).
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const BADGE_SCENE: PackedScene = preload("res://scenes/enemies/notification_badge.tscn")
const BANNER_SCENE: PackedScene = preload("res://scenes/enemies/spam_banner.tscn")
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


func test_completed_laser_receiver_gives_no_help() -> void:
	var reader := _scene("laser_receiver") as LaserReceiver
	_place(reader, &"laser_receiver")
	await wait_process_frames(1)
	reader.on_laser_hit(1.0, null)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(reader), "Con corriente sigue siendo un lector")
	await _assert_inert_drops_help(reader, func() -> void: reader.complete(), "lector hecho")
	_assert_no_reread(reader, &"laser_receiver", "lector hecho")


func test_activated_relay_receiver_gives_no_help() -> void:
	var relay := _scene("relay_receiver") as RelayReceiver
	_place(relay, &"relay_receiver")
	await _assert_inert_drops_help(relay, func() -> void: relay.activate(), "receptor enlazado activado")
	_assert_no_reread(relay, &"relay_receiver", "receptor enlazado activado")


func test_broken_ad_cover_gives_no_help() -> void:
	var ad := _scene("ad_cover") as AdCover
	ad.text = "Saltar anuncio en 5…"
	_place(ad, &"ad_cover")
	await _assert_inert_drops_help(ad, func() -> void: ad.on_laser_hit(1.0, null), "anuncio roto")
	_assert_no_reread(ad, &"ad_cover", "anuncio roto")


func test_collected_debug_chip_gives_no_help() -> void:
	var pickup := _scene("ability_pickup") as AbilityPickup
	pickup.ability = &"debug"
	_place(pickup, &"ability_pickup")
	await wait_process_frames(1)
	assert_eq(HelpCatalog.help_id_of(pickup), &"debug_chip", "Su propia ayuda")
	await _assert_inert_drops_help(pickup, func() -> void: pickup.collect_by(_isak), "chip del Debug recogido")


## Punto rojo (1-2): ayuda disponible mientras exista y no este derrotado
## (dormido, persiguiendo o aturdido sigue siendo un punto rojo); derrotado, no.
func test_defeated_red_dot_gives_no_help() -> void:
	var badge := BADGE_SCENE.instantiate() as NotificationBadge
	_place(badge, &"notification_badge")
	badge.set_physics_process(false)
	await wait_process_frames(1)
	badge.drops = {}  # Sus drops serian candidatos nuevos (con su propia ayuda).
	badge.free_on_pop = false
	await _assert_inert_drops_help(badge, func() -> void: badge.pop(), "punto rojo derrotado")
	_assert_no_reread(badge, &"notification_badge", "punto rojo derrotado")


func test_stunned_red_dot_still_helps() -> void:
	var badge := BADGE_SCENE.instantiate() as NotificationBadge
	_place(badge, &"notification_badge")
	badge.set_physics_process(false)
	await wait_process_frames(1)
	badge.stun()
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(badge), "Aturdido sigue ahi (escalon, y el laser lo remata): su ayuda no miente")
	assert_eq(_help.get_target(), badge)


## Banner (1-2): nunca se destruye; en reposo, avisando o barriendo ayuda igual.
func test_banner_helps_in_every_phase() -> void:
	var banner := BANNER_SCENE.instantiate() as SpamBanner
	_place(banner, &"spam_banner")
	banner.set_physics_process(false)
	await wait_process_frames(1)
	for state: StringName in [SpamBanner.STATE_REST, SpamBanner.STATE_WARN, SpamBanner.STATE_SWEEP]:
		for i: int in 400:
			if banner.get_state() == state:
				break
			banner.step(STEP)
		assert_eq(banner.get_state(), state)
		_run(STEP * 2.0)
		assert_true(HelpCatalog.is_help_live(banner), "Banner en %s: ayuda" % state)
		assert_eq(_help.get_target(), banner, "Banner en %s: candidato" % state)


## Isak quieto en FEET (sin suelo en esta prueba caeria y saldria del radio de la Q
## segun los cuadros reales que pasen).
func _freeze_isak() -> void:
	_isak.set_physics_process(false)
	_isak.global_position = FEET
	_isak.velocity = Vector2.ZERO


## Recordatorio (1-2, piso 3): caido no esta (sin Q ni relectura); repuesto, si.
func test_fallen_reminder_gives_no_help() -> void:
	_freeze_isak()
	var reminder := _scene("reminder_platform") as ReminderPlatform
	reminder.group_id = &"inerte"
	reminder.set_physics_process(false)
	_place(reminder, &"reminder_platform")
	reminder.start_countdown()
	assert_true(HelpCatalog.is_help_live(reminder), "Contando sigue siendo un recordatorio")
	await _assert_inert_drops_help(reminder, func() -> void: reminder.expire(), "recordatorio caido")
	_assert_no_reread(reminder, &"reminder_platform", "recordatorio caido")
	for i: int in 300:
		reminder.advance(STEP)
	assert_true(HelpCatalog.is_help_live(reminder), "Repuesto vuelve a ayudar")


## Posponer: reutilizable; enfriandose o sin nada que posponer sigue ayudando.
func test_snooze_button_keeps_helping() -> void:
	_freeze_isak()
	var snooze := _scene("snooze_button") as SnoozeButton
	snooze.set_physics_process(false)
	_place(snooze, &"snooze_button")
	await wait_process_frames(1)
	snooze.on_laser_hit(1.0, null)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(snooze), "Sin cuenta que posponer, sigue siendo un Posponer")
	assert_eq(_help.get_target(), snooze)


func test_closed_overlay_gives_no_help() -> void:
	_freeze_isak()
	var overlay := _scene("overlay_popup") as OverlayPopup
	overlay.text = "Tienes 99+ mensajes que no son importantes"
	_place(overlay, &"overlay_popup")
	await _assert_inert_drops_help(overlay, func() -> void: overlay.close(), "pop-up translucido cerrado")
	_assert_no_reread(overlay, &"overlay_popup", "pop-up translucido cerrado")


func test_opened_update_bar_gives_no_help() -> void:
	_freeze_isak()
	var bar := _scene("update_bar") as UpdateBar
	bar.set_physics_process(false)
	_place(bar, &"update_bar")
	bar.arm()
	bar.advance(2.0)
	assert_true(HelpCatalog.is_help_live(bar), "Trabada sigue ayudando")
	await _assert_inert_drops_help(bar, func() -> void:
		bar.finish()
		bar.advance(3.0), "barra del 99 % abierta")
	_assert_no_reread(bar, &"update_bar", "barra del 99 % abierta")


func test_every_help_type_is_covered() -> void:
	var covered: Array[StringName] = [&"popup_blocker", &"alert_bubble", &"receiver", &"bridge", &"glitch_wall",
		&"exit_terminal", &"attention_point", &"ability_pickup", &"power_bank_pickup", &"energy_drop", &"sync_drop",
		&"extra_life", &"charger", &"sync_point", &"laser_receiver", &"relay_receiver", &"ad_cover", &"debug_chip",
		&"notification_badge", &"spam_banner", &"reminder_platform", &"snooze_button", &"overlay_popup",
		&"update_bar"]
	for id: StringName in HelpCatalog.shared().ids():
		assert_true(covered.has(id), "Tipo %s sin prueba de «lo destruido no ayuda»" % id)
