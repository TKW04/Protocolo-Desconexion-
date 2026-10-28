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
	# Isak fijo en FEET (2026-10-16): la sala no tiene suelo y, con la fisica en marcha, Isak caia
	# y salia del radio de la Q segun los cuadros reales que pasaran en cada await (la prueba del
	# lector laser fallaba a veces al correr varios archivos juntos). Ninguna prueba necesita que
	# Isak se mueva: la ayuda depende de su posicion y del estado is_help_live de cada objeto.
	_freeze_isak()
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
	reader.set_process(false)  # Su ventana no avanza sola: la prueba no depende del tiempo real.
	_place(reader, &"laser_receiver")
	await wait_process_frames(1)
	assert_eq(_isak.global_position, FEET, "Isak sigue en FEET (sin caer), a un tile del lector")
	reader.on_laser_hit(1.0, null)
	_run(0.2)
	assert_true(reader.is_powered(), "Con corriente")
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


## Banner obligatorio con el dash (1-3, ayuda propia spam_banner_dash): igual, nunca se destruye.
func test_dash_banner_helps_in_every_phase() -> void:
	var banner := BANNER_SCENE.instantiate() as SpamBanner
	_place(banner, &"spam_banner_dash")
	banner.set_physics_process(false)
	banner.knockback_to_entry = true
	await wait_process_frames(1)
	for state: StringName in [SpamBanner.STATE_REST, SpamBanner.STATE_WARN, SpamBanner.STATE_SWEEP]:
		for i: int in 400:
			if banner.get_state() == state:
				break
			banner.step(STEP)
		assert_eq(banner.get_state(), state)
		_run(STEP * 2.0)
		assert_true(HelpCatalog.is_help_live(banner), "Banner obligatorio en %s: ayuda" % state)
		assert_eq(_help.get_target(), banner, "Banner obligatorio en %s: candidato" % state)


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


func test_collected_memory_pickup_gives_no_help() -> void:
	var pickup := _scene("memory_pickup") as MemoryPickup
	pickup.memory_id = &"msg_1_1"
	_place(pickup, &"memory_pickup")
	await _assert_inert_drops_help(pickup, func() -> void: pickup.collect(), "mensaje recogido")


## Interruptor «No molestar» (1-3, paso 8 de propuesta-1-3.md): encendido no ayuda.
func test_switched_on_dnd_switch_gives_no_help() -> void:
	var sw := _scene("dnd_switch") as DndSwitch
	_place(sw, &"dnd_switch")
	await _assert_inert_drops_help(sw, func() -> void: sw.switch_on(), "interruptor No molestar encendido")
	_assert_no_reread(sw, &"dnd_switch", "interruptor No molestar encendido")


## Plataforma que vibra (1-3): nunca se destruye; sin metronomo, siempre encendida.
func test_blink_platform_always_helps() -> void:
	var platform := _scene("blink_platform") as BlinkPlatform
	_place(platform, &"blink_platform")
	await wait_process_frames(1)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(platform), "Plataforma que vibra: ayuda")
	assert_eq(_help.get_target(), platform, "Plataforma que vibra: candidato")


## Tarjeta fragil (Mundo 2, paso 4 de docs/propuesta-mundo-2.md): rota no ayuda; repuesta, si.
func test_broken_fragile_card_gives_no_help() -> void:
	_freeze_isak()
	var card := (load("res://scenes/levels/fragile_card.tscn") as PackedScene).instantiate() as FragileCard
	card.set_physics_process(false)
	_place(card, &"fragile_card")
	await _assert_inert_drops_help(card, func() -> void: card.break_now(), "tarjeta fragil rota")
	_assert_no_reread(card, &"fragile_card", "tarjeta fragil rota")
	for i: int in 300:
		card.advance(STEP)
	assert_true(HelpCatalog.is_help_live(card), "Repuesta vuelve a ayudar")


## Historia (Mundo 2): nunca se destruye (apagada, sigue siendo una Historia).
func test_story_card_always_helps() -> void:
	var card := (load("res://scenes/levels/story_card.tscn") as PackedScene).instantiate() as StoryCard
	_place(card, &"story_card")
	await wait_process_frames(1)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(card), "Historia: ayuda")
	assert_eq(_help.get_target(), card, "Historia: candidato")


## Seccion en bucle (Mundo 2, paso 5): resuelta no ayuda.
func test_solved_loop_section_gives_no_help() -> void:
	_freeze_isak()
	var loop := (load("res://scenes/levels/loop_section.tscn") as PackedScene).instantiate() as LoopSection
	loop.set_physics_process(false)
	_place(loop, &"loop_section")
	await _assert_inert_drops_help(loop, func() -> void:
		loop.exit_rect = [-1000, -1000, 2000, 2000]
		loop.step(STEP), "bucle resuelto")
	_assert_no_reread(loop, &"loop_section", "bucle resuelto")


## Video en autoplay (Mundo 2, paso 6): roto (laser aturdido) no ayuda; aturdido, si.
func test_broken_autoplay_video_gives_no_help() -> void:
	var video := (load("res://scenes/enemies/autoplay_video.tscn") as PackedScene).instantiate() as AutoplayVideo
	video.set_physics_process(false)
	_place(video, &"autoplay_video")
	await wait_process_frames(1)
	video.drops = {}
	video.stun()
	assert_true(HelpCatalog.is_help_live(video), "Video aturdido: sigue ayudando")
	await _assert_inert_drops_help(video, func() -> void:
		video.stun()
		video.on_laser_hit(10.0, null), "video roto")
	_assert_no_reread(video, &"autoplay_video", "video roto")


## Clon de «Un video mas» (Mundo 2, paso 7): eliminado no ayuda; aturdido, si.
func test_popped_video_clone_gives_no_help() -> void:
	var clone := (load("res://scenes/enemies/video_clone.tscn") as PackedScene).instantiate() as VideoClone
	clone.set_physics_process(false)
	clone.free_on_pop = false
	_place(clone, &"video_clone")
	await wait_process_frames(1)
	clone.stun()
	assert_true(HelpCatalog.is_help_live(clone), "Clon aturdido: sigue ayudando")
	await _assert_inert_drops_help(clone, func() -> void: clone.on_laser_hit(1.0, null), "clon eliminado")
	_assert_no_reread(clone, &"video_clone", "clon eliminado")


## Comentarista (Mundo 2, paso 7): derrotado (laser aturdido) no ayuda; aturdido, si.
func test_defeated_commenter_gives_no_help() -> void:
	var commenter := (load("res://scenes/enemies/commenter.tscn") as PackedScene).instantiate() as Commenter
	commenter.set_physics_process(false)
	_place(commenter, &"commenter")
	await wait_process_frames(1)
	commenter.drops = {}
	commenter.stun()
	assert_true(HelpCatalog.is_help_live(commenter), "Comentarista aturdido: sigue ayudando")
	await _assert_inert_drops_help(commenter, func() -> void:
		commenter.stun()
		commenter.on_laser_hit(10.0, null), "comentarista derrotado")
	_assert_no_reread(commenter, &"commenter", "comentarista derrotado")


## Muro «Cargando mas…» (Mundo 2, paso 7): roto no ayuda.
func test_broken_loading_wall_gives_no_help() -> void:
	_freeze_isak()
	var wall := (load("res://scenes/levels/loading_wall.tscn") as PackedScene).instantiate() as LoadingWall
	wall.set_physics_process(false)
	_place(wall, &"loading_wall")
	await _assert_inert_drops_help(wall, func() -> void:
		for i: int in wall.pounds_needed:
			wall.register_pound(), "muro roto")
	_assert_no_reread(wall, &"loading_wall", "muro roto")


## Reproductor con el boton de pausa (Mundo 2, paso 8): pausado no ayuda.
func test_paused_pause_player_gives_no_help() -> void:
	var player := (load("res://scenes/levels/pause_player.tscn") as PackedScene).instantiate() as PausePlayer
	_place(player, &"pause_player")
	await _assert_inert_drops_help(player, func() -> void: player.switch_on(), "reproductor en pausa")
	_assert_no_reread(player, &"pause_player", "reproductor en pausa")
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, false)


## Campana de alarma (1-3): indestructible, ayuda en todas sus fases.
func test_alarm_bell_helps_in_every_phase() -> void:
	var bell := (load("res://scenes/enemies/alarm_bell.tscn") as PackedScene).instantiate() as AlarmBell
	_place(bell, &"alarm_bell")
	bell.set_physics_process(false)
	await wait_process_frames(1)
	for state: StringName in [AlarmBell.STATE_WARN, AlarmBell.STATE_WAVE, AlarmBell.STATE_REST]:
		for i: int in 400:
			if bell.get_state() == state:
				break
			bell.step(STEP)
		assert_eq(bell.get_state(), state)
		_run(STEP * 2.0)
		assert_true(HelpCatalog.is_help_live(bell), "Campana en %s: ayuda" % state)
		assert_eq(_help.get_target(), bell, "Campana en %s: candidato" % state)


# --- Alerta Mayor (paso 12 de docs/propuesta-jefe-alerta-mayor.md, 2026-10-21) ---

## El cuerpo del jefe (el Sprite2D que AlertMajor marca con alert_major): al
## desarmarse en pixeles se oculta y deja de ayudar.
func test_disarmed_boss_body_gives_no_help() -> void:
	var body := Sprite2D.new()
	body.texture = load("res://assets/sprites/bosses/alert_major_hover_00.png") as Texture2D
	_place(body, &"alert_major")
	await _assert_inert_drops_help(body, func() -> void: body.visible = false, "jefe desarmado")


## El nucleo solo ayuda mientras se ve (marcado o revelado); al apagarse, no.
func test_hidden_core_gives_no_help() -> void:
	var core := (load("res://scenes/bosses/weak_point.tscn") as PackedScene).instantiate() as WeakPoint
	_place(core, &"alert_major_core")
	await wait_process_frames(1)
	core.set_enabled(true)
	core.set_mark_duration(30.0)
	core.call(&"_mark")
	await _assert_inert_drops_help(core, func() -> void: core.set_enabled(false), "nucleo apagado")


func test_popped_boss_bubble_gives_no_help() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.set_physics_process(false)
	_place(bubble, &"alert_major_bubble")
	await wait_process_frames(1)
	bubble.drops = {}
	await _assert_inert_drops_help(bubble, func() -> void: bubble.pop(), "Burbuja de la alerta reventada")


func test_closed_boss_popup_gives_no_help() -> void:
	var overlay := _scene("overlay_popup") as OverlayPopup
	overlay.text = "¿Sigues ahí?"
	_place(overlay, &"alert_major_popup")
	await _assert_inert_drops_help(overlay, func() -> void: overlay.close(), "pop-up insistente cerrado")


func test_opened_shield_gives_no_help() -> void:
	var shield := _scene("overlay_popup") as OverlayPopup
	shield.text = ""
	shield.opaque = true
	shield.width_tiles = 2
	shield.height_tiles = 2
	_place(shield, &"boss_popup_shield")
	await _assert_inert_drops_help(shield, func() -> void: shield.close(), "pop-up escudo abierto")


func test_finished_shot_gives_no_help() -> void:
	_freeze_isak()
	var shot := NotificationShot.new()
	shot.auto_process = false
	shot.contact_damage = 0.0
	_place(shot, &"notification_shot")
	await _assert_inert_drops_help(shot, func() -> void:
		shot.travel_px = 0.0
		shot.step(STEP), "rafaga terminada")


func test_discarded_clone_gives_no_help() -> void:
	var clone := AlertMajorClone.new()
	_place(clone, &"alert_major_clone")
	await _assert_inert_drops_help(clone, func() -> void: clone.discard(false), "copia descartada")


## Carteles del feed con la ayuda del reloj y del borde (paso 11 del Mundo 2): no se destruyen ni se
## gastan, asi que siempre ayudan (la Q sale hasta aprender el tipo y luego la relectura).
func test_feed_signs_always_help() -> void:
	# hud_likes (Mundo 3): el cartel «Mi vida es increíble #bendecido» del 3-1 lleva la Q del contador.
	for help_id: StringName in [&"hud_clock", &"feed_edge", &"hud_likes"]:
		var sign := (load("res://scenes/levels/feed_sign.tscn") as PackedScene).instantiate() as FeedSign
		sign.text = "Para ti"
		_place(sign, help_id)
		assert_true(HelpCatalog.is_help_live(sign), "%s: el cartel siempre ayuda" % help_id)
		sign.free()


# --- Autoplay (paso 20 de docs/propuesta-mundo-2.md, 2026-10-23) ---

## La pantalla y el cabezal gris: al desarmarse en pixeles se ocultan y dejan de ayudar.
func test_disarmed_autoplay_screen_and_playhead_give_no_help() -> void:
	var screen := Sprite2D.new()
	screen.centered = false
	screen.texture = load("res://assets/sprites/bosses/autoplay_screen_placeholder.png") as Texture2D
	_place(screen, &"autoplay")
	await _assert_inert_drops_help(screen, func() -> void: screen.visible = false, "pantalla desarmada")
	screen.free()
	var playhead := Sprite2D.new()
	playhead.texture = load("res://assets/sprites/bosses/autoplay_playhead_placeholder.png") as Texture2D
	_place(playhead, &"autoplay_playhead")
	await _assert_inert_drops_help(playhead, func() -> void: playhead.visible = false, "cabezal desarmado")


## El boton de pausa solo ayuda mientras se ve (en pausa o revelado); apagado, no.
func test_hidden_pause_button_gives_no_help() -> void:
	var core := (load("res://scenes/bosses/weak_point.tscn") as PackedScene).instantiate() as WeakPoint
	core.mark_trigger = WeakPoint.TRIGGER_GROUND_POUND
	_place(core, &"autoplay_pause_button")
	await wait_process_frames(1)
	core.set_enabled(true)
	core.set_mark_duration(30.0)
	core.call(&"_mark")
	await _assert_inert_drops_help(core, func() -> void: core.set_enabled(false), "boton de pausa apagado")


## Las tarjetas de la cinta no se destruyen: siempre ayudan.
func test_conveyor_card_always_helps() -> void:
	var card := MovingPlatform.new()
	card.size = Vector2(192.0, 24.0)
	card.travel = Vector2.ZERO
	_place(card, &"autoplay_card")
	await wait_process_frames(1)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(card), "Tarjeta: ayuda")
	assert_eq(_help.get_target(), card, "Tarjeta: candidato")


## La cuenta solo ayuda mientras se ve.
func test_hidden_countdown_gives_no_help() -> void:
	var state: Dictionary = {"showing": true}
	var marker := Autoplay.CountdownHelp.new()
	marker.available = func() -> bool: return bool(state["showing"])
	_place(marker, &"autoplay_countdown")
	await _assert_inert_drops_help(marker, func() -> void: state["showing"] = false, "cuenta que ya no se ve")


## Un clip (ola, barrido o rayo) pierde la ayuda al acabar: Autoplay le quita la etiqueta.
func test_finished_clip_gives_no_help() -> void:
	_freeze_isak()
	var banner := BANNER_SCENE.instantiate() as SpamBanner
	banner.manual = true
	banner.set_physics_process(false)
	_place(banner, &"autoplay_clip")
	await wait_process_frames(1)
	_run(0.2)
	assert_eq(_help.get_target(), banner, "Clip avisando: candidato con Q")
	# El banner sigue en el arbol (es el mismo para la siguiente ola): solo pierde la etiqueta.
	HelpCatalog.tag(banner, &"")
	_run(STEP)
	assert_null(_help.get_target(), "Clip acabado: sin Q")
	assert_false(_help.is_prompt_visible(), "Clip acabado: la Q desaparece")
	assert_false(_eco.is_helping(), "Clip acabado: Eco suelta el banner")
	_help.update_still(5.0)
	_help.refresh()
	assert_false(_help.is_reread_visible(), "Clip acabado: sin relectura")


## El abanico de la «Cuenta atras»: terminado, no ayuda.
func test_finished_fan_shot_gives_no_help() -> void:
	_freeze_isak()
	var shot := NotificationShot.new()
	shot.auto_process = false
	shot.contact_damage = 0.0
	_place(shot, &"autoplay_fan")
	await _assert_inert_drops_help(shot, func() -> void:
		shot.travel_px = 0.0
		shot.step(STEP), "abanico terminado")


# --- La Curadora (paso 19 de docs/propuesta-mundo-3.md, 2026-10-27) ---

## El marco: al desarmarse en pixeles se oculta y deja de ayudar.
func test_disarmed_curator_frame_gives_no_help() -> void:
	var frame := Sprite2D.new()
	frame.centered = false
	frame.texture = load("res://assets/sprites/bosses/curator_frame_placeholder.png") as Texture2D
	_place(frame, &"curator_boss")
	await _assert_inert_drops_help(frame, func() -> void: frame.visible = false, "marco desarmado")


## La lente solo ayuda mientras baja a encuadrar; el marco que se cierra, mientras avisa o se cierra.
func test_curator_lens_and_closing_frame_only_while_shown() -> void:
	var state: Dictionary = {"lens": true, "closing": true}
	var lens := Curator.HelpMarker.new()
	lens.available = func() -> bool: return bool(state["lens"])
	_place(lens, &"curator_lens")
	await _assert_inert_drops_help(lens, func() -> void: state["lens"] = false, "lente que vuelve a subir")
	lens.free()
	var closing := Curator.HelpMarker.new()
	closing.available = func() -> bool: return bool(state["closing"])
	_place(closing, &"closing_frame")
	await _assert_inert_drops_help(closing, func() -> void: state["closing"] = false, "marco ya abierto")


# --- El Visto (paso 20 de docs/propuesta-mundo-4.md, 2026-10-28) ---

## El cuerpo solo ayuda mientras se ve (oculto o tras el golpe final, no); el escudo,
## mientras esta levantado; el «escribiendo…» gigante, mientras se llenan los puntos.
func test_seen_body_shield_and_typing_only_while_shown() -> void:
	var state: Dictionary = {"seen_boss": true, "seen_shield": true, "seen_typing": true}
	var whys: Dictionary = {"seen_boss": "El Visto oculto", "seen_shield": "escudo caido", "seen_typing": "«escribiendo…» en silencio"}
	for id: String in state:
		var marker := Seen.HelpMarker.new()
		marker.available = func() -> bool: return bool(state[id])
		_place(marker, StringName(id))
		await _assert_inert_drops_help(marker, func() -> void: state[id] = false, String(whys[id]))
		marker.free()


# --- Mundo 3: niveles (paso 20 de docs/propuesta-mundo-3.md, 2026-10-27) ---

func _w3_scene(type: String) -> Node2D:
	var types: Dictionary = World3ObjectsConfig.data().get("types", {})
	var path: String = String((types.get(type, {}) as Dictionary).get("scene", ""))
	return (load(path) as PackedScene).instantiate() as Node2D


## Comprueba que `node` es el candidato, aplica `action` (el uso o el estado que
## en otros tipos lo volveria inerte) y comprueba que sigue siendo el candidato.
func _assert_keeps_helping(node: Node2D, action: Callable, why: String) -> void:
	await wait_process_frames(1)
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(node), "%s: ayuda" % why)
	assert_eq(_help.get_target(), node, "%s: candidato con Q" % why)
	action.call()
	_run(0.2)
	assert_true(HelpCatalog.is_help_live(node), "%s: sigue ayudando" % why)
	assert_eq(_help.get_target(), node, "%s: sigue siendo el candidato" % why)


## Corazon: recogido no ayuda; los que suelta el Ladron (temporales) nunca llevan la Q.
func test_collected_heart_pickup_gives_no_help() -> void:
	var heart := _w3_scene("heart_pickup") as HeartPickup
	_place(heart, &"heart_pickup")
	await _assert_inert_drops_help(heart, func() -> void: assert_true(heart.collect()), "corazon recogido")
	_assert_no_reread(heart, &"heart_pickup", "corazon recogido")
	var dropped := _w3_scene("heart_pickup") as HeartPickup
	dropped.dropped = true
	_place(dropped, &"heart_pickup")
	await wait_process_frames(1)
	_run(0.2)
	assert_false(HelpCatalog.is_help_live(dropped), "Corazon soltado: sin Q")
	assert_null(_help.get_target(), "Corazon soltado: no es candidato")


## Publicacion: reutilizable (enfriandose tras dar likes sigue ayudando, como el cargador).
func test_used_like_source_keeps_helping() -> void:
	var source := _w3_scene("like_source") as LikeSource
	_place(source, &"like_source")
	await _assert_keeps_helping(source, func() -> void:
		assert_true(source.like(), "da likes")
		assert_false(source.is_ready(), "se enfria"), "publicacion usada")


## «Borrar publicaciones»: reutilizable; tras poner el contador a 0 sigue ayudando.
func test_used_like_reset_keeps_helping() -> void:
	GameState.set_likes(12)
	var reset := _w3_scene("like_reset") as LikeReset
	_place(reset, &"like_reset")
	await _assert_keeps_helping(reset, func() -> void:
		reset.clear_likes()
		assert_eq(GameState.likes, 0, "contador a 0"), "borrar publicaciones usado")


## Plataforma de likes: no se destruye; apagada (sin el umbral) o encendida, ayuda.
func test_like_platform_helps_on_and_off() -> void:
	GameState.set_likes(0)
	var platform := _w3_scene("like_platform") as LikePlatform
	platform.threshold = 5
	_place(platform, &"like_platform")
	await _assert_keeps_helping(platform, func() -> void:
		GameState.set_likes(10)
		platform.snap()
		assert_true(platform.meets_threshold(), "umbral cumplido con 10 likes"), "plataforma de likes con el umbral")
	GameState.set_likes(0)
	platform.snap()
	_run(0.2)
	assert_false(platform.is_solid(), "apagada sin likes")
	assert_true(HelpCatalog.is_help_live(platform), "Apagada: sigue ayudando")


## Marco pequeno: decorado fijo, siempre explica (con Pellizcar o sin el).
func test_small_frame_always_helps() -> void:
	var frame := _w3_scene("small_frame") as SmallFrame
	_place(frame, &"small_frame")
	await _assert_keeps_helping(frame, func() -> void: GameState.obtain_ability(&"compress"),
		"marco pequeno con Pellizcar")


## Espejo: indestructible; tras rebotar un laser sigue ayudando.
func test_mirror_always_helps() -> void:
	var mirror := _w3_scene("mirror") as Mirror
	_place(mirror, &"mirror")
	await _assert_keeps_helping(mirror, func() -> void: mirror.on_laser_hit(1.0, null), "espejo tras un laser")


## Pared de espejo: indestructible, siempre ayuda.
func test_mirror_wall_always_helps() -> void:
	var wall := _w3_scene("mirror_wall") as MirrorWall
	wall.auto_process = false
	_place(wall, &"mirror_wall")
	wall.isak = _isak
	await _assert_keeps_helping(wall, func() -> void: wall.advance(1.0), "pared de espejo")


## Plataforma del reflejo: invisible en el mundo sin el Debug (solo se ve en el espejo), asi
## que sin el Debug no lleva la Q (la explica la pared de espejo); oculta no es candidato.
func test_hidden_mirror_only_platform_gives_no_help() -> void:
	var platform := _w3_scene("mirror_only") as MirrorOnlyPlatform
	_place(platform, &"mirror_only")
	await wait_process_frames(1)
	_run(0.2)
	assert_false(platform.is_visible_in_world(), "Sin Debug no se ve")
	assert_false(HelpCatalog.is_help_live(platform), "Oculta: sin Q")
	assert_null(_help.get_target(), "Oculta: no es candidato")
	assert_true(platform.is_solid(), "Pero sigue siendo solida")


## «Recortar»: encendida (Pellizcar ya dado) no ayuda, como el interruptor No molestar.
func test_switched_on_crop_tool_gives_no_help() -> void:
	var crop := _w3_scene("crop_tool") as CropTool
	_place(crop, &"crop_tool")
	await _assert_inert_drops_help(crop, func() -> void: crop.switch_on(), "Recortar encendida")
	_assert_no_reread(crop, &"crop_tool", "Recortar encendida")


## Filtro: no se destruye; con el Debug o sin el, ayuda.
func test_filter_zone_always_helps() -> void:
	var zone := _w3_scene("filter_zone") as FilterZone
	zone.label_text = "Filtro: Prueba"
	_place(zone, &"filter_zone")
	await _assert_keeps_helping(zone, func() -> void: zone.advance(1.0), "filtro")


## Espejo cazador: indestructible; congelado por el pulso sigue ayudando.
func test_frozen_hunter_mirror_keeps_helping() -> void:
	var hunter := _w3_scene("hunter_mirror") as HunterMirror
	hunter.auto_process = false
	_place(hunter, &"hunter_mirror")
	hunter.isak = _isak
	await _assert_keeps_helping(hunter, func() -> void:
		hunter.freeze()
		assert_true(hunter.is_frozen(), "congelado"), "espejo cazador congelado")


## Placa «Posa aquí» y puerta de marco: se reutilizan (cada vez que el reflejo o Isak posan),
## asi que siempre ayudan.
func test_pose_plate_and_frame_door_always_help() -> void:
	var plate := _w3_scene("pose_plate") as PosePlate
	plate.auto_process = false
	_place(plate, &"pose_plate")
	plate.isak = _isak
	await _assert_keeps_helping(plate, func() -> void: plate.advance(1.0), "placa")
	plate.free()
	var door := _w3_scene("frame_door") as FrameDoor
	door.auto_process = false
	_place(door, &"frame_door")
	await _assert_keeps_helping(door, func() -> void: door.advance(1.0), "puerta de marco")


# --- Mundo 3: enemigos (paso 20) ---

## Influencer bot: aturdido sigue ayudando; derrotado (laser aturdido) no.
func test_defeated_influencer_bot_gives_no_help() -> void:
	var bot := (load("res://scenes/enemies/influencer_bot.tscn") as PackedScene).instantiate() as InfluencerBot
	bot.set_physics_process(false)
	_place(bot, &"influencer_bot")
	bot.target = _isak
	await wait_process_frames(1)
	bot.drops = {}
	bot.stun()
	assert_true(HelpCatalog.is_help_live(bot), "Influencer aturdido: sigue ayudando")
	await _assert_inert_drops_help(bot, func() -> void:
		bot.stun()
		bot.on_laser_hit(10.0, null)
		assert_true(bot.is_defeated(), "derrotado"), "influencer derrotado")
	_assert_no_reread(bot, &"influencer_bot", "influencer derrotado")


## Ladron de likes: aturdido sigue ayudando; derrotado no.
func test_defeated_like_thief_gives_no_help() -> void:
	var thief := (load("res://scenes/enemies/like_thief.tscn") as PackedScene).instantiate() as LikeThief
	thief.set_physics_process(false)
	thief.patrol_range_px = 0.0
	_place(thief, &"like_thief")
	thief.target = _isak
	await wait_process_frames(1)
	thief.drops = {}
	thief.stun()
	assert_true(HelpCatalog.is_help_live(thief), "Ladron aturdido: sigue ayudando")
	await _assert_inert_drops_help(thief, func() -> void:
		thief.stun()
		thief.on_laser_hit(10.0, null)
		assert_true(thief.is_defeated(), "derrotado"), "ladron derrotado")
	_assert_no_reread(thief, &"like_thief", "ladron derrotado")


## Reflejo falso: dormido en la pared no ayuda; fuera, si; al volver a la pared, no.
func test_vanished_false_reflection_gives_no_help() -> void:
	var reflection := (load("res://scenes/enemies/false_reflection.tscn") as PackedScene).instantiate() \
		as FalseReflection
	reflection.auto_process = false
	_place(reflection, &"false_reflection")
	reflection.target = _isak
	await wait_process_frames(1)
	_run(0.2)
	assert_false(HelpCatalog.is_help_live(reflection), "Dormido: sin Q")
	assert_null(_help.get_target(), "Dormido: no es candidato")
	reflection.emerge()
	assert_true(reflection.is_present(), "fuera de la pared")
	await _assert_inert_drops_help(reflection, func() -> void: reflection.vanish(), "reflejo de vuelta a la pared")


func test_every_help_type_is_covered() -> void:
	var covered: Array[StringName] = [&"popup_blocker", &"alert_bubble", &"receiver", &"bridge", &"glitch_wall",
		&"exit_terminal", &"attention_point", &"ability_pickup", &"power_bank_pickup", &"energy_drop", &"sync_drop",
		&"extra_life", &"charger", &"sync_point", &"laser_receiver", &"relay_receiver", &"ad_cover", &"debug_chip",
		&"notification_badge", &"spam_banner", &"spam_banner_dash", &"reminder_platform", &"snooze_button", &"overlay_popup",
		&"update_bar", &"power_switch", &"laser_switch", &"debug_switch", &"charge_dock", &"memory_pickup",
		&"dnd_switch", &"blink_platform", &"alarm_bell", &"alert_major", &"alert_major_core", &"alert_major_bubble",
		&"alert_major_popup", &"boss_popup_shield", &"notification_shot", &"alert_major_clone", &"fragile_card",
		&"story_card", &"loop_section", &"autoplay_video", &"video_clone", &"commenter", &"loading_wall",
		&"pause_player", &"hud_clock", &"feed_edge", &"autoplay", &"autoplay_playhead", &"autoplay_pause_button",
		&"autoplay_card", &"autoplay_countdown", &"autoplay_clip", &"autoplay_fan",
		&"curator_boss", &"curator_lens", &"closing_frame",
		&"heart_pickup", &"like_source", &"like_reset", &"like_platform", &"small_frame", &"mirror", &"mirror_wall",
		&"mirror_only", &"crop_tool", &"filter_zone", &"hunter_mirror", &"pose_plate", &"frame_door", &"hud_likes",
		&"influencer_bot", &"like_thief", &"false_reflection",
		&"chat_bubble", &"typing_bubble", &"seen_zone", &"flashlight_pickup", &"autocorrect_bubble", &"undo_prompt",
		&"typed_wall", &"troll", &"sticker", &"ghost", &"troll_mimic", &"lurker",
		&"seen_boss", &"seen_shield", &"seen_typing"]
	for id: StringName in HelpCatalog.shared().ids():
		assert_true(covered.has(id), "Tipo %s sin prueba de «lo destruido no ayuda»" % id)


# --- Acertijo de la azotea del 1-2 (encuentro con Calc, 2026-10-17, tanda H1 del paso 14) ---

func test_activated_power_switch_gives_no_help() -> void:
	var sw := _scene("power_switch") as PowerSwitch
	sw.pulses_required = 1
	_place(sw, &"power_switch")
	await _assert_inert_drops_help(sw, func() -> void: sw.activate(), "interruptor de pulso activado")
	_assert_no_reread(sw, &"power_switch", "interruptor de pulso activado")


func test_activated_laser_switch_gives_no_help() -> void:
	var sw := _scene("laser_switch") as LaserSwitch
	_place(sw, &"laser_switch")
	await _assert_inert_drops_help(sw, func() -> void: sw.activate(), "interruptor laser activado")
	_assert_no_reread(sw, &"laser_switch", "interruptor laser activado")


func test_hidden_or_activated_debug_switch_gives_no_help() -> void:
	var sw := _scene("debug_switch") as PowerSwitch
	_place(sw, &"debug_switch")
	await wait_process_frames(1)
	_run(0.2)
	assert_false(HelpCatalog.is_help_live(sw), "Oculto: sin Q")
	assert_null(_help.get_target())
	sw.reveal()
	await _assert_inert_drops_help(sw, func() -> void: sw.activate(), "panel oculto activado")
	_assert_no_reread(sw, &"debug_switch", "panel oculto activado")


func test_armed_charge_dock_gives_no_help() -> void:
	var dock := _scene("charge_dock") as ChargeDock
	dock.required_ids = ["nada"]
	_place(dock, &"charge_dock")
	await _assert_inert_drops_help(dock, func() -> void:
		dock.required_ids = []
		dock.advance(0.0), "punto de carga armado")
	_assert_no_reread(dock, &"charge_dock", "punto de carga armado")


# --- Mundo 4 (paso 10 de docs/propuesta-mundo-4.md) ---

func _w4_scene(type: String) -> Node2D:
	var types: Dictionary = World4ObjectsConfig.data().get("types", {})
	var path: String = String((types.get(type, {}) as Dictionary).get("scene", ""))
	return (load(path) as PackedScene).instantiate() as Node2D


## Burbuja: la fija ayuda siempre; la eliminada es decorado y nunca ayuda.
func test_chat_bubbles_help_unless_deleted() -> void:
	var bubble := _w4_scene("chat_bubble") as ChatBubble
	bubble.text = "¿Sigues despierto?"
	_place(bubble, &"chat_bubble")
	await _assert_keeps_helping(bubble, func() -> void: pass, "burbuja fija")
	bubble.free()
	var deleted := _w4_scene("chat_bubble") as ChatBubble
	deleted.text = "nada"
	deleted.deleted = true
	_place(deleted, &"chat_bubble")
	await wait_process_frames(1)
	_run(0.2)
	assert_false(HelpCatalog.is_help_live(deleted), "Eliminada: sin Q")
	assert_null(_help.get_target())


## «Escribiendo…»: antes de dispararse no existe y no ayuda; disparada, si.
func test_typing_bubble_helps_once_triggered() -> void:
	var typing := _w4_scene("typing_bubble") as TypingBubble
	typing.text = "ya voy"
	typing.trigger_zone = [0, 0, 1, 1]
	_place(typing, &"typing_bubble")
	await wait_process_frames(1)
	_run(0.2)
	assert_false(HelpCatalog.is_help_live(typing), "Sin disparar: sin Q")
	typing.trigger()
	await _assert_keeps_helping(typing, func() -> void: typing.advance(1.5), "escribiendo disparada")


## Zona «Visto» y autocorrector: no se destruyen; ayudan siempre.
func test_seen_zone_and_autocorrect_always_help() -> void:
	var zone := _w4_scene("seen_zone") as SeenZone
	_place(zone, &"seen_zone")
	await _assert_keeps_helping(zone, func() -> void: zone.advance(1.0), "zona Visto")
	zone.free()
	var auto := _w4_scene("autocorrect_bubble") as AutocorrectBubble
	auto.text = "te echo de menos"
	auto.corrected = "te echo"
	_place(auto, &"autocorrect_bubble")
	await _assert_keeps_helping(auto, func() -> void: pass, "autocorrector")


## Linterna: recogida no ayuda.
func test_collected_flashlight_gives_no_help() -> void:
	var lamp := _w4_scene("flashlight_pickup") as FlashlightPickup
	_place(lamp, &"flashlight_pickup")
	await _assert_inert_drops_help(lamp, func() -> void: lamp.collect(), "Linterna recogida")
	GameState.allies_met.erase(&"linterna")


## «¿Deshacer escritura?»: usado (muro deshecho) no ayuda, como la «Recortar».
func test_switched_on_undo_prompt_gives_no_help() -> void:
	var prompt := _w4_scene("undo_prompt") as UndoPrompt
	_place(prompt, &"undo_prompt")
	await _assert_inert_drops_help(prompt, func() -> void: prompt.switch_on(), "Deshacer escritura usado")
	_assert_no_reread(prompt, &"undo_prompt", "Deshacer escritura usado")
	GameState.reset_progress()


## Muro de texto: borrado por el «¿Deshacer escritura?» no ayuda.
func test_erased_typed_wall_gives_no_help() -> void:
	var wall := _w4_scene("typed_wall") as TypedWall
	_place(wall, &"typed_wall")
	await _assert_inert_drops_help(wall, func() -> void:
		assert_true(wall.undo()), "muro de texto borrado")


## Troll, Sticker y Fantasma: aturdidos siguen ayudando; derrotados no.
func test_defeated_world4_enemies_give_no_help() -> void:
	for kind: String in ["troll", "sticker", "ghost"]:
		var enemy := (load("res://scenes/enemies/%s.tscn" % kind) as PackedScene).instantiate() as Node2D
		enemy.set_physics_process(false)
		_place(enemy, StringName(kind))
		enemy.set(&"target", _isak)
		if kind == "ghost":
			enemy.set(&"detect_tiles", 0.0)  # que no se esfume con Isak al lado
		await wait_process_frames(1)
		enemy.set_physics_process(false)
		enemy.set(&"drops", {})
		enemy.call(&"stun")
		assert_true(HelpCatalog.is_help_live(enemy), "%s aturdido: sigue ayudando" % kind)
		await _assert_inert_drops_help(enemy, func() -> void:
			enemy.call(&"stun")
			enemy.call(&"on_laser_hit", 10.0, null)
			enemy.call(&"on_laser_hit", 10.0, null)
			assert_true(bool(enemy.call(&"is_defeated")), "%s derrotado" % kind), "%s derrotado" % kind)
		enemy.free()


## Acechador (2026-10-28, peligros ocultos del Modo oscuro): el Sticker con lurk que
## duerme a oscuras no ayuda (la Q lo delataria); en cuanto se despierta, si.
func test_lurking_sticker_gives_help_only_once_seen() -> void:
	GameState.allies_met.erase(&"linterna")  # sin Linterna: a oscuras de verdad (con ella, a 1 tile se veria)
	var zone := (load("res://scenes/levels/dark_zone.tscn") as PackedScene).instantiate() as DarkZone
	zone.position = FEET + Vector2(-6.0 * TILE, -6.0 * TILE)
	zone.width_tiles = 14
	zone.height_tiles = 7
	zone.auto_process = false
	_root.add_child(zone)
	var sticker := (load("res://scenes/enemies/sticker.tscn") as PackedScene).instantiate() as Sticker
	sticker.set_physics_process(false)
	_place(sticker, &"lurker")
	sticker.target = _isak
	sticker.lurk = true
	sticker.detect_tiles = 0.0  # que no se despierte solo con Isak al lado
	sticker.trigger_tiles = 0.0
	await wait_process_frames(2)
	sticker.set_physics_process(false)
	_run(0.2)
	assert_true(sticker.is_lurking(), "Acecha a oscuras")
	assert_false(HelpCatalog.is_help_live(sticker), "Acechando: sin Q")
	assert_null(_help.get_target(), "Sin candidato")
	sticker._change_state(Sticker.STATE_CHASE)
	_run(0.2)
	assert_false(sticker.is_lurking())
	assert_true(HelpCatalog.is_help_live(sticker), "Despierto: ayuda")
	assert_eq(_help.get_target(), sticker, "Candidato con Q en cuanto se ve")
	sticker.free()
	zone.free()


## Troll disfrazado: disfrazado no ayuda (la Q lo delataria); descubierto, si.
func test_disguised_troll_mimic_gives_no_help() -> void:
	var mimic := (load("res://scenes/enemies/troll_mimic.tscn") as PackedScene).instantiate() as TrollMimic
	mimic.set_physics_process(false)
	_place(mimic, &"troll_mimic")
	await wait_process_frames(1)
	_run(0.2)
	assert_true(mimic.is_disguised())
	assert_false(HelpCatalog.is_help_live(mimic), "Disfrazado: sin Q")
	# Agitar esta retirado (2026-10-28); su logica conservada sigue descubriendolo (aqui, como atajo de la prueba).
	assert_true(mimic.receive_shockwave(mimic.global_position, 160.0, 3.0), "Agitar lo descubre")
	assert_false(mimic.is_disguised())
	assert_true(HelpCatalog.is_help_live(mimic), "Descubierto: ayuda")

