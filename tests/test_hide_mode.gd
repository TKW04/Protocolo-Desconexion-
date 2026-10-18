# Ocultarte (Pulso 4 de las mejoras de Calc; tanda M2 de docs/propuesta-mejoras.md
# §4, 2026-10-17): accion hide (H / L3, reasignable, aviso de control), activar
# solo por encima del 15 % de Sync Rate y energia, gasto por segundo (5 de energia
# y 1,5 de Sync), corte al 10 % del primero que llegue, se apaga al disparar,
# lanzar el pulso o recibir dano, no se combina con el Debug (en los dos
# sentidos), no se corre, los perseguidores (punto rojo) pierden el rastro y
# vuelven a su sitio, las Burbujas no; efecto en el sprite, Eco atenuado e
# indicador del HUD.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const BADGE_SCENE: PackedScene = preload("res://scenes/enemies/notification_badge.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const PATH: String = "user://test_hide_mode_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {
		"pulse": GameState.is_ability_unlocked(GameState.ABILITY_PULSE),
		"laser": GameState.is_ability_unlocked(GameState.ABILITY_LASER),
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
	}
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.upgrade_levels[&"pulso"] = 4
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_player_hidden(false)
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved.pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved.laser)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _press_hide() -> void:
	_sim.input.hide_pressed = true
	_sim.step()


func _hide() -> void:
	_press_hide()
	assert_true(_isak.is_hidden(), "Ocultarte activo")


func _run(seconds: float) -> void:
	_sim.step(roundi(seconds / DT))


# --- Datos y accion ---

func test_data_values() -> void:
	var d: Dictionary = HideMode.load_data()
	assert_almost_eq(float(d["energy_per_s"]), 5.0, EPS)
	assert_almost_eq(float(d["sync_per_s"]), 1.5, EPS)
	assert_almost_eq(float(d["enter_min_fraction"]), 0.15, EPS)
	assert_almost_eq(float(d["cut_fraction"]), 0.10, EPS)
	assert_almost_eq(float(d["warn_fraction"]), 0.20, EPS)
	assert_eq(String(d["outline_color"]).to_lower(), "#3dfff5", "Acento cian, sin rojos")


func test_hide_action_in_input_map_and_remappable() -> void:
	assert_true(InputMap.has_action(&"hide"))
	assert_true(ControlBindings.is_remappable(&"hide"))
	assert_eq(ControlBindings.action_name(&"hide"), "Ocultarte")
	var key: InputEvent = ControlBindings.primary(&"hide", ControlBindings.Device.KEYBOARD)
	assert_eq((key as InputEventKey).physical_keycode, KEY_H, "H")
	var pad: InputEvent = ControlBindings.primary(&"hide", ControlBindings.Device.PAD)
	assert_eq((pad as InputEventJoypadButton).button_index, JOY_BUTTON_LEFT_STICK, "L3")
	var notices: Dictionary = AbilityNotices.load_data()
	assert_eq(AbilityNotices.notice_text(&"hide", notices), "Ocultarte: H / L3 (mando)")
	GameSettings.use_path(GameSettings.settings_path(), true)
	var u := InputEventKey.new()
	u.physical_keycode = KEY_U
	assert_eq(ControlBindings.assign(&"hide", u), ControlBindings.Result.OK)
	assert_eq(AbilityNotices.notice_text(&"hide", notices), "Ocultarte: U / L3 (mando)", "El aviso sigue la tecla")
	ControlBindings.restore_defaults()
	GameSettings.use_path(GameSettings.settings_path(), true)
	assert_eq(AbilityNotices.notice_text(&"hide", notices), "Ocultarte: H / L3 (mando)")


func test_notice_only_with_the_upgrade() -> void:
	assert_true(AbilityNotices.is_available(&"hide"), "Con el Pulso 4")
	GameState.upgrade_levels[&"pulso"] = 3
	assert_false(AbilityNotices.is_available(&"hide"), "Sin el Pulso 4 no hay aviso")
	assert_false(GameState.is_hide_available())


# --- Activar ---

func test_not_available_without_pulse_4() -> void:
	GameState.upgrade_levels[&"pulso"] = 3
	_press_hide()
	assert_false(_isak.is_hidden())
	assert_eq(_isak.get_hide_mode().get_last_denied(), HideMode.Denied.NOT_OWNED)
	assert_false(GameState.is_player_hidden())


func test_activates_only_above_15_percent_of_both() -> void:
	GameState.sync_rate = 15.0
	_press_hide()
	assert_false(_isak.is_hidden(), "Sync al 15 %: no")
	assert_eq(_isak.get_hide_mode().get_last_denied(), HideMode.Denied.LOW_SYNC)
	GameState.sync_rate = 16.0
	GameState.debug_energy = 15.0
	_press_hide()
	assert_false(_isak.is_hidden(), "Energia al 15 %: no")
	assert_eq(_isak.get_hide_mode().get_last_denied(), HideMode.Denied.LOW_ENERGY)
	GameState.debug_energy = 16.0
	watch_signals(EventBus)
	_hide()
	assert_true(GameState.is_player_hidden())
	assert_signal_emitted_with_parameters(EventBus, "hide_changed", [true])


func test_only_on_the_floor_and_in_a_level() -> void:
	_isak.velocity.y = -600.0
	_isak.global_position.y -= 200.0
	_sim.step()
	_press_hide()
	assert_false(_isak.is_hidden(), "En el aire no se activa")
	_sim.settle()
	_isak.level_mode = false
	_press_hide()
	assert_false(_isak.is_hidden(), "En el hub no")
	assert_eq(_isak.get_hide_mode().get_last_denied(), HideMode.Denied.NOT_IN_LEVEL)


func test_second_press_turns_it_off_even_in_the_air() -> void:
	_hide()
	_sim.press_jump()
	_sim.step(5)
	assert_false(_isak.is_on_floor())
	watch_signals(EventBus)
	_press_hide()
	assert_false(_isak.is_hidden(), "Otra pulsacion lo apaga (tambien en el aire)")
	assert_signal_emitted_with_parameters(EventBus, "hide_ended", [HideMode.REASON_TOGGLE])


# --- Gasto y corte ---

func test_drains_energy_and_sync_per_second() -> void:
	_hide()
	_run(1.0)
	assert_almost_eq(GameState.debug_energy, 100.0 - 5.0, 0.15, "5 de energia por segundo")
	assert_almost_eq(GameState.sync_rate, 100.0 - 1.5, 0.1, "1,5 de Sync por segundo")


func test_cuts_at_10_percent_of_sync() -> void:
	GameState.sync_rate = 16.0
	_hide()
	watch_signals(EventBus)
	_sim.step_until(func() -> bool: return not _isak.is_hidden(), roundi(6.0 / DT))
	assert_false(_isak.is_hidden(), "Se apaga solo")
	assert_almost_eq(GameState.debug_energy, 100.0 - 5.0 * 4.0, 0.3, "Unos 4 s de gasto (6 / 1,5)")
	assert_almost_eq(GameState.sync_rate, 10.0, EPS, "El gasto se para en el 10 %: nunca mata")
	assert_signal_emitted_with_parameters(EventBus, "hide_ended", [HideMode.REASON_CUT])
	assert_true(_isak.get_hide_mode().is_flashing(), "Destello del glitch al cortarse")
	assert_false(_isak.is_dead())


func test_cuts_at_10_percent_of_energy_with_upgraded_max() -> void:
	GameState.upgrade_levels[&"energia"] = 4
	GameState.debug_energy = 20.0
	_hide()
	_run(2.5)
	assert_false(_isak.is_hidden(), "La energia llega antes al 10 %")
	assert_almost_eq(GameState.debug_energy, 13.0, EPS, "10 % de 130")


func test_warning_below_20_percent() -> void:
	_hide()
	assert_false(HideMode.is_low())
	GameState.debug_energy = 19.0
	assert_true(HideMode.is_low(), "Por debajo del 20 % de la energia: aviso")
	GameState.debug_energy = 100.0
	GameState.sync_rate = 19.0
	assert_true(HideMode.is_low(), "O del Sync Rate")
	_sim.step()
	var mat: ShaderMaterial = _isak.get_hide_mode().get_material()
	assert_almost_eq(float(mat.get_shader_parameter(&"warn")), 1.0, EPS, "El glitch avisa")
	assert_almost_eq(HideMode.remaining_fraction(), (GameState.sync_rate - 10.0) / 90.0, 0.01)


# --- Lo apagan ---

func test_pulse_turns_it_off() -> void:
	_hide()
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)
	assert_false(_isak.is_hidden(), "Atacar con el pulso te revela")


func test_laser_turns_it_off() -> void:
	_hide()
	_sim.input.laser_pressed = true
	_sim.step()
	assert_false(_isak.is_hidden(), "Disparar te revela al empezar la pose")


func test_damage_turns_it_off_and_hit_applies() -> void:
	_hide()
	assert_true(_isak.take_hit(1.0))
	assert_false(_isak.is_hidden(), "Recibir dano te revela")
	assert_true(_isak.is_invulnerable(), "La invulnerabilidad de siempre")


func test_debug_and_hide_never_combine() -> void:
	EcoProgress.obtain_debug()
	# Debug activo -> Ocultarte: el Debug se apaga.
	for i: int in roundi(DebugMode.get_activation_hold_s() / DT) + 2:
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())
	_hide()
	assert_false(DebugMode.is_active(), "Activar el Ocultarte apaga el Debug")
	# Ocultarte activo -> Debug: el Ocultarte se apaga.
	DebugMode.step(DT, false)
	for i: int in roundi(DebugMode.get_activation_hold_s() / DT) + 2:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active())
	assert_false(_isak.is_hidden(), "Activar el Debug apaga el Ocultarte")
	assert_false(GameState.is_player_hidden())


func test_no_running_while_hidden() -> void:
	_sim.input.move_axis = 1.0
	_sim.input.run_held = true
	_run(1.0)
	assert_almost_eq(_isak.velocity.x, _isak.physics.run_speed, 1.0, "Sin ocultarse corre")
	_hide()
	_run(1.0)
	assert_true(_isak.is_hidden())
	assert_almost_eq(_isak.velocity.x, _isak.physics.walk_speed, 1.0, "Oculto camina aunque mantenga correr")
	assert_false(_isak.is_running())


func test_respawn_and_death_turn_it_off() -> void:
	_hide()
	_isak.respawn(_isak.global_position)
	assert_false(_isak.is_hidden())
	_hide()
	_isak.die()
	assert_false(_isak.is_hidden(), "Morir lo apaga")


# --- Visual ---

func test_sprite_effect_fades_in_and_out() -> void:
	var sprite: AnimatedSprite2D = _isak.get_sprite()
	assert_null(sprite.material)
	_hide()
	_run(0.25)
	var mode: HideMode = _isak.get_hide_mode()
	assert_eq(sprite.material, mode.get_material(), "Shader del glitch en el sprite")
	assert_almost_eq(mode.get_amount(), 1.0, EPS, "Entrada de 0,2 s")
	assert_almost_eq(float(mode.get_material().get_shader_parameter(&"alpha_hidden")), 0.45, EPS)
	_press_hide()
	_run(0.25)
	assert_almost_eq(mode.get_amount(), 0.0, EPS)
	assert_null(sprite.material, "Sin efecto al acabar")


func test_eco_dims_while_hidden() -> void:
	var eco: EcoCompanion = EcoCompanion.attach(_isak, _world)
	_hide()
	assert_almost_eq(eco.modulate.a, 0.45, EPS, "Eco atenuado")
	_press_hide()
	assert_almost_eq(eco.modulate.a, 1.0, EPS)


func test_hud_indicator_bar_and_warning() -> void:
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	assert_false(hud.is_hide_indicator_shown())
	_hide()
	hud._process(DT)
	assert_true(hud.is_hide_indicator_shown(), "Icono y barra mientras dura")
	assert_almost_eq(hud.get_hide_bar_ratio(), 1.0, EPS)
	GameState.debug_energy = 55.0
	hud._process(DT)
	assert_almost_eq(hud.get_hide_bar_ratio(), 0.5, EPS, "Lo que queda hasta el 10 %")
	GameState.debug_energy = 18.0
	var dims: int = 0
	for i: int in 60:
		hud._process(DT)
		if hud.is_hide_icon_dim():
			dims += 1
	assert_gt(dims, 10, "Por debajo del 20 % el icono parpadea")
	assert_lt(dims, 50)
	_press_hide()
	hud._process(DT)
	assert_false(hud.is_hide_indicator_shown(), "Apagado a mano: se va")


# --- Enemigos ---

func _badge_near_isak() -> NotificationBadge:
	var badge := BADGE_SCENE.instantiate() as NotificationBadge
	badge.free_on_pop = false
	badge.target = _isak
	_world.add_child(badge)
	badge.set_physics_process(false)
	badge.global_position = _isak.global_position + Vector2(300.0, -40.0)
	return badge


func test_chaser_loses_track_and_goes_home() -> void:
	var badge: NotificationBadge = _badge_near_isak()
	await wait_physics_frames(1)
	var home: Vector2 = badge.get_spawn_position()
	badge.step(DT)
	assert_true(badge.is_chasing(), "Despierta y persigue")
	for i: int in 20:
		badge.step(DT)
	_hide()
	badge.step(DT)
	assert_true(badge.is_lost(), "Pierde el rastro: «?»")
	var lost_fx: int = 0
	for node: Node in _world.get_children():
		if node is UpgradeFx and (node as UpgradeFx).kind == UpgradeFx.LOST_TRAIL:
			lost_fx += 1
	assert_eq(lost_fx, 1, "Con el «?» encima")
	for i: int in roundi(badge.lost_s / DT) + 2:
		badge.step(DT)
	assert_eq(badge.get_state(), NotificationBadge.STATE_RETURN, "Vuelve a su sitio")
	for i: int in 600:
		badge.step(DT)
		if badge.get_state() == NotificationBadge.STATE_IDLE:
			break
	assert_eq(badge.get_state(), NotificationBadge.STATE_IDLE, "Y se duerme")
	assert_lt(badge.global_position.distance_to(home), 5.0)
	badge.step(DT)
	assert_eq(badge.get_state(), NotificationBadge.STATE_IDLE, "Oculto cerca no lo despierta")
	# Revelarse cerca: lo vuelve a ver.
	_press_hide()
	badge.step(DT)
	assert_true(badge.is_chasing(), "Al revelarse cerca lo ve otra vez")


func test_bubble_keeps_its_route() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.target = _isak
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	bubble.global_position = _isak.global_position + Vector2(400.0, 0.0)
	await wait_physics_frames(1)
	var before: Vector2 = bubble.global_position
	_hide()
	for i: int in 30:
		bubble.step(DT)
	assert_eq(bubble.get_state(), AlertBubble.STATE_PATROL, "La Burbuja no mira: sigue patrullando")
	assert_ne(bubble.global_position, before, "Y se mueve por su ruta")
	assert_true(bubble.is_dangerous(), "Sigue haciendo dano al contacto")
