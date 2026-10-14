# Pruebas del aspecto y del efecto en el mundo del Debug Mode: efecto de
# pantalla (capa entre el mundo y el HUD, color del mundo), plataformas
# ocultas (visibles y solidas solo con el Debug; Isak cae si se apaga encima;
# contorno de alto contraste) e Isak con la misma fisica durante el Debug.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const HIDDEN_SCENE: PackedScene = preload("res://scenes/levels/hidden_platform.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const FLOAT_TOLERANCE: float = 0.01
## Plataforma de prueba (px): ancha y fina, con la superficie en y = 0.
const PLATFORM_SIZE: Vector2 = Vector2(512.0, 32.0)
## Pasos tras apagar el Debug para comprobar la caida.
const FALL_CHECK_STEPS: int = 20

var _saved: Dictionary = {}
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_each() -> void:
	_saved = {
		"energy": GameState.debug_energy,
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"world": GameState.current_world,
		"contrast": GameState.debug_high_contrast_outline,
	}
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.current_world = GameState.FIRST_WORLD
	GameState.debug_high_contrast_outline = false
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.debug_energy = _saved.energy
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.current_world = _saved.world
	GameState.debug_high_contrast_outline = _saved.contrast


## Pulsacion larga hasta activar (sin esperar la transicion).
func _hold_to_activate() -> void:
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)


## Activa con la pulsacion larga, suelta y espera la transicion de entrada.
func _debug_on() -> void:
	_hold_to_activate()
	for i: int in ceili(_config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)


## Pulsacion corta: apaga el Debug si esta activo (empieza la salida suave).
func _press_off() -> void:
	DebugMode.step(DT, true)
	DebugMode.step(DT, false)


## Apaga con una pulsacion y espera la transicion de salida.
func _debug_off() -> void:
	_press_off()
	for i: int in ceili(_config.fade_out_s / DT) + 1:
		DebugMode.step(DT, false)


func _make_platform() -> HiddenPlatform:
	var platform: HiddenPlatform = HIDDEN_SCENE.instantiate() as HiddenPlatform
	platform.size = PLATFORM_SIZE
	platform.position = Vector2(0.0, PLATFORM_SIZE.y * 0.5)
	return platform


# --- Efecto de pantalla ---

func test_overlay_between_world_and_hud() -> void:
	var overlay: DebugOverlay = DebugMode.get_overlay()
	assert_not_null(overlay)
	var hud: Hud = add_child_autofree(HUD_SCENE.instantiate()) as Hud
	assert_gt(overlay.layer, 0, "Por encima del mundo (capa 0)")
	assert_lt(overlay.layer, hud.layer, "Por debajo del HUD: el HUD no se tine")


func test_overlay_fades_with_debug() -> void:
	var overlay: DebugOverlay = DebugMode.get_overlay()
	assert_false(overlay.is_effect_visible(), "Sin Debug no hay efecto")
	_hold_to_activate()
	assert_true(overlay.is_effect_visible())
	assert_between(overlay.get_intensity(), EPS, 1.0 - EPS, "Entrada gradual")
	_debug_on()
	assert_almost_eq(overlay.get_intensity(), 1.0, EPS)
	_debug_off()
	assert_false(overlay.is_effect_visible(), "Tras la salida se oculta")


func test_tint_color_follows_world() -> void:
	var overlay: DebugOverlay = DebugMode.get_overlay()
	var hud_config: HudConfig = HudConfig.shared()
	for world: int in range(GameState.FIRST_WORLD, GameState.LAST_WORLD + 1):
		GameState.current_world = world
		assert_eq(overlay.get_tint_color(), hud_config.debug_color_for_world(world), "Mundo %d" % world)
	GameState.current_world = GameState.FIRST_WORLD
	var cyan: Color = overlay.get_tint_color()
	assert_true(cyan.b > cyan.r and cyan.g > cyan.r, "Mundo 1 = cian")


# --- Plataformas ocultas ---

func test_hidden_platform_only_in_debug() -> void:
	var platform: HiddenPlatform = add_child_autofree(_make_platform())
	await wait_process_frames(1)
	assert_true(platform.is_in_group(HiddenPlatform.GROUP))
	assert_false(platform.is_solid(), "Sin Debug no es solida")
	assert_false(platform.is_shown(), "Sin Debug no se ve")
	_debug_on()
	await wait_process_frames(1)
	assert_true(platform.is_solid(), "Con Debug es solida")
	assert_true(platform.is_shown(), "Con Debug se ve")
	_press_off()
	assert_false(platform.is_solid(), "Al apagarlo deja de ser solida al instante")
	_debug_off()
	await wait_process_frames(1)
	assert_false(platform.is_shown(), "Y desaparece tras la transicion")


func test_hidden_platform_outline_follows_world_and_contrast() -> void:
	var platform: HiddenPlatform = add_child_autofree(_make_platform())
	var hud_config: HudConfig = HudConfig.shared()
	assert_eq(platform.get_outline_color(), hud_config.debug_color_for_world(1))
	assert_eq(platform.get_outline_width(), _config.hidden_outline_width_px)
	GameState.current_world = 2
	assert_eq(platform.get_outline_color(), hud_config.debug_color_for_world(2))
	GameState.current_world = 1
	var normal: Color = platform.get_outline_color()
	GameState.debug_high_contrast_outline = true
	assert_gt(platform.get_outline_width(), _config.hidden_outline_width_px, "Alto contraste: mas grueso")
	assert_gt(platform.get_outline_color().get_luminance(), normal.get_luminance(), "Alto contraste: mas claro")


func test_isak_stands_on_hidden_platform_and_falls_when_debug_ends() -> void:
	_debug_on()
	var sim := IsakSim.new(DT)
	var world := Node2D.new()
	world.add_child(_make_platform())
	var isak: Isak = IsakSim.ISAK_SCENE.instantiate() as Isak
	sim.attach(isak)
	isak.position = Vector2(0.0, -1.0)
	world.add_child(isak)
	add_child_autofree(world)
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	assert_true(isak.is_on_floor(), "Con Debug Isak se apoya en la plataforma oculta")
	assert_almost_eq(isak.global_position.y, 0.0, 1.0)
	_press_off()
	sim.step(FALL_CHECK_STEPS)
	assert_false(isak.is_on_floor(), "Sin Debug la plataforma desaparece")
	assert_gt(isak.global_position.y, 0.0, "Isak cae")
	assert_eq(sim.state(), PlayerState.FALL)


# --- Isak no cambia con el Debug ---

## Altura del salto (px) y velocidad de caminar alcanzada, con el Debug o sin el.
func _measure(debug: bool) -> Dictionary:
	DebugMode.reset()
	if debug:
		_debug_on()
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child(world)
	sim.take_manual_control()
	# move_and_slide() integra con el delta del motor: esperar a un paso real.
	await wait_physics_frames(1)
	sim.settle()
	var y0: float = sim.isak.global_position.y
	var min_y: float = y0
	sim.press_jump()
	var limit: int = sim.steps_for(IsakSim.MAX_WAIT_S)
	var steps: int = 0
	while sim.state() in [PlayerState.JUMP, PlayerState.FALL] and steps < limit:
		steps += 1
		min_y = minf(min_y, sim.isak.global_position.y)
		sim.step()
		if debug:
			DebugMode.step(DT, false)
	sim.settle()
	sim.input.move_axis = 1.0
	var p: PlayerPhysics = sim.isak.physics
	sim.step(sim.steps_for(p.walk_speed / p.ground_acceleration))
	var result: Dictionary = {"height": y0 - min_y, "walk": sim.isak.velocity.x,
		"scale": GameState.world_time_scale}
	# Se libera ya: el siguiente Isak aparece en el mismo sitio.
	remove_child(world)
	world.free()
	return result


func test_isak_physics_unchanged_during_debug() -> void:
	var normal: Dictionary = await _measure(false)
	var slowed: Dictionary = await _measure(true)
	gut.p("sin Debug: %s / con Debug: %s" % [normal, slowed])
	assert_almost_eq(slowed.scale, _config.world_time_scale, EPS, "El mundo estaba ralentizado")
	var p: PlayerPhysics = PlayerPhysics.load_from_file(PlayerPhysics.DEFAULT_PATH)
	assert_almost_eq(slowed.height, p.jump_height_px, absf(p.jump_velocity) * DT, "Misma altura de salto")
	assert_almost_eq(slowed.height, normal.height, FLOAT_TOLERANCE, "Igual que sin Debug")
	assert_almost_eq(slowed.walk, p.walk_speed, FLOAT_TOLERANCE, "Misma velocidad de caminar")
	assert_almost_eq(slowed.walk, normal.walk, FLOAT_TOLERANCE)
