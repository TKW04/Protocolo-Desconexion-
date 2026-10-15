# Pruebas del HUD (scenes/ui/hud.tscn): assets pixel art y fuente bitmap del
# paso 12 (cargan, tramos de senal y bateria, icono ambar, glifos, pixel base),
# refleja GameState via EventBus,
# acota valores, sigue el color del Debug del mundo, estado de Sync Rate bajo,
# animacion de rastro de dano y liberacion limpia. Tambien las teclas de
# depuracion de la arena (acciones hud_debug_*).
extends GutTest

const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/levels/test_arena.tscn")
const ArenaScript = preload("res://scripts/levels/test_arena.gd")
const EPS: float = 0.001
## Margen sobre retardo + duracion del vaciado del rastro.
const DRAIN_MARGIN_S: float = 0.3

var _saved: Dictionary = {}
var _config: HudConfig = HudConfig.shared()


func before_each() -> void:
	_saved = {
		"sync_rate": GameState.sync_rate,
		"debug_energy": GameState.debug_energy,
		"attention_points": GameState.attention_points,
		"current_world": GameState.current_world,
		"reduce": GameState.reduce_low_sync_effects,
		"pulse": GameState.is_ability_unlocked(GameState.ABILITY_PULSE),
	}
	GameState.current_world = GameState.FIRST_WORLD
	GameState.reduce_low_sync_effects = false
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.attention_points = GameState.ATTENTION_POINTS_MIN


func after_each() -> void:
	GameState.sync_rate = _saved.sync_rate
	GameState.debug_energy = _saved.debug_energy
	GameState.attention_points = _saved.attention_points
	GameState.current_world = _saved.current_world
	GameState.reduce_low_sync_effects = _saved.reduce
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved.pulse)


func _make_hud() -> Hud:
	return add_child_autofree(HUD_SCENE.instantiate()) as Hud


# --- Datos ---

func test_config_loads_from_json() -> void:
	var config: HudConfig = HudConfig.load_from_file()
	assert_not_null(config)
	assert_almost_eq(config.low_sync_threshold, 20.0, EPS, "Umbral de Sync Rate bajo: docs 3.3 (menor al 20%)")
	for world: int in range(GameState.FIRST_WORLD, GameState.LAST_WORLD + 1):
		assert_true(config.debug_colors.has(world), "Color del Debug para el mundo %d" % world)
	for name: StringName in [&"text", &"signal", &"damage", &"low_sync", &"attention_icon", &"debug_key"]:
		assert_true(config.colors.has(name), "Color '%s' en data/hud.json" % name)


func test_world_1_debug_color_is_cyan() -> void:
	var c: Color = _config.debug_color_for_world(1)
	assert_true(c.b > c.r and c.g > c.r, "El Debug del Mundo 1 es cian")


# --- Arte definitivo (paso 12) ---

func test_hud_assets_exist_and_load() -> void:
	assert_false(_config.assets.is_empty(), "data/hud.json lista los assets")
	for name: StringName in _config.assets:
		var tex: Texture2D = _config.asset_texture(name)
		assert_not_null(tex, "El asset '%s' carga" % name)
		if tex == null:
			continue
		var frame: Vector2i = _config.asset_frame_size(name)
		var info: Dictionary = _config.assets[name]
		assert_eq(Vector2i(tex.get_size()), Vector2i(frame.x * int(info.columns), frame.y * int(info.rows)),
			"Tamano de '%s' segun su rejilla" % name)
		assert_eq(frame.x % 8 + frame.y % 8, 0, "Cuadro de '%s' multiplo de 8" % name)
	assert_not_null(_config.load_font(), "La fuente bitmap carga")
	assert_true(ResourceLoader.exists(_config.key_swap_shader_path), "Shader de cambio de color")


func test_pixel_base_is_integer_scale() -> void:
	var hud: Hud = _make_hud()
	assert_eq(_config.hud_pixel_scale, 2, "Pixel base del HUD: x2 a 1280x720")
	assert_eq(hud.get_pixel_scale(), Vector2.ONE * _config.hud_pixel_scale)


## Tramos de data/hud.json: la barra i se enciende con Sync Rate > signal_thresholds[i].
func test_signal_bars_by_sync_rate_band() -> void:
	var hud: Hud = _make_hud()
	var cases: Dictionary = {100.0: 4, 76.0: 4, 75.0: 3, 51.0: 3, 50.0: 2, 26.0: 2, 25.0: 1, 15.0: 1, 1.0: 1, 0.0: 0}
	for sync: float in cases:
		GameState.sync_rate = sync
		assert_eq(hud.get_signal_bars(), cases[sync], "Barras con Sync Rate %d" % sync)
	assert_eq(_config.signal_thresholds.size(), 4, "4 barras de senal")


func test_battery_segments_by_energy() -> void:
	var hud: Hud = _make_hud()
	var cases: Dictionary = {100.0: 5, 81.0: 5, 80.0: 4, 60.0: 3, 40.0: 2, 21.0: 2, 20.0: 1, 5.0: 1, 0.0: 0}
	for energy: float in cases:
		GameState.debug_energy = energy
		assert_eq(hud.get_battery_segments(), cases[energy], "Segmentos con energia %d" % energy)
	assert_eq(_config.battery_thresholds.size(), 5, "Bateria de 5 segmentos")


## Estilo circuito (docs/estilizacion-energia.md): la bateria vacia no tiene
## ningun pixel del color del Debug (ni segmentos ni el rayo del marco).
func test_empty_battery_art_has_no_debug_color() -> void:
	var key: Color = _config.color(&"debug_key")
	var shell: Image = _config.asset_texture(&"battery_shell").get_image()
	var segments: Image = _config.asset_texture(&"battery_segments").get_image()
	var frame: Vector2i = _config.asset_frame_size(&"battery_shell")
	assert_true(_has_color(shell, Rect2i(Vector2i(0, HudMeter.ShellRow.CHARGED * frame.y), frame), key),
		"Con energia, el rayo esta en el color del Debug")
	assert_false(_has_color(shell, Rect2i(Vector2i(0, HudMeter.ShellRow.EMPTY * frame.y), frame), key),
		"Vacia: rayo apagado")
	var empty_row := Rect2i(0, HudMeter.SegmentRow.EMPTY * frame.y, segments.get_width(), frame.y)
	assert_false(_has_color(segments, empty_row, key), "Segmentos vacios sin color del Debug")
	var battery := HudMeter.new()
	battery.kind = HudMeter.Kind.BATTERY
	battery.setup(_config)
	battery.value = 0.0
	assert_eq(battery.get_shell_row(), HudMeter.ShellRow.EMPTY)
	battery.value = 0.05
	assert_eq(battery.get_shell_row(), HudMeter.ShellRow.CHARGED)
	battery.free()


func _has_color(image: Image, rect: Rect2i, color: Color) -> bool:
	image.decompress()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5 and c.to_html(false) == color.to_html(false):
				return true
	return false


func test_charge_ring_steps_are_discrete() -> void:
	var ring := HudMeter.new()
	ring.kind = HudMeter.Kind.CHARGE_RING
	ring.setup(_config)
	ring.value = 0.0
	assert_eq(ring.get_ring_frame(), -1, "Sin carga no hay cuadro")
	ring.value = 0.55
	assert_eq(ring.get_ring_frame(), ceili(0.55 * _config.charge_ring_steps) - 1)
	ring.value = 1.0
	assert_eq(ring.get_ring_frame(), _config.charge_ring_steps - 1)
	assert_eq(_config.asset_columns(&"charge_ring"), _config.charge_ring_steps, "Un cuadro por paso")
	ring.free()


func test_attention_icon_is_amber() -> void:
	var hud: Hud = _make_hud()
	var amber := Color.html("#ffa000")
	assert_eq(hud.get_attention_icon_color(), amber)
	var image: Image = _config.asset_texture(&"attention_icon").get_image()
	image.decompress()
	var counts: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5:
				var key: String = c.to_html(false)
				counts[key] = counts.get(key, 0) + 1
	var best: String = ""
	for key: String in counts:
		if best.is_empty() or counts[key] > counts[best]:
			best = key
	assert_eq(best, amber.to_html(false), "El color dominante del icono es el ambar")
	assert_true(counts.has(Color.html("#a85f00").to_html(false)), "Con ambar_sombra")


func test_font_has_all_hud_glyphs() -> void:
	var hud: Hud = _make_hud()
	var font: Font = hud.get_font()
	assert_true(font is FontFile, "Fuente bitmap propia (FontFile)")
	assert_eq(font.resource_path, _config.font_path)
	for ch: String in _config.font_glyphs:
		assert_true(font.has_char(ch.unicode_at(0)), "Glifo '%s'" % ch)
	# Todo lo que el HUD escribe usa solo glifos de la fuente.
	var texts: Array[String] = [Hud.PERCENT_FORMAT % 100, Hud.PERCENT_FORMAT % 0, Hud.WIDEST_ATTENTION, "0123456789"]
	for text: String in texts:
		for ch: String in text:
			assert_true(ch in _config.font_glyphs, "'%s' de '%s' esta en font_glyphs" % [ch, text])


func test_battery_uses_world_debug_color_for_world_1() -> void:
	assert_eq(_config.debug_color_for_world(1), Color.html("#3dfff5"), "HUD del Mundo 1: #3dfff5")
	assert_eq(_config.color(&"debug_key"), _config.debug_color_for_world(1),
		"El arte de la bateria esta dibujado en el cian del Mundo 1")


# --- Estado inicial ---

func test_hud_shows_current_state_on_ready() -> void:
	GameState.sync_rate = 50.0
	GameState.debug_energy = 30.0
	GameState.attention_points = 4
	var hud: Hud = _make_hud()
	assert_almost_eq(hud.get_sync_ratio(), 0.5, EPS)
	assert_almost_eq(hud.get_sync_trail(), 0.5, EPS, "El estado inicial no se anima")
	assert_eq(hud.get_sync_text(), "50 %")
	assert_almost_eq(hud.get_energy_ratio(), 0.3, EPS)
	assert_eq(hud.get_attention_text(), "4")


# --- Reflejo de GameState ---

func test_sync_rate_updates_bar_and_text() -> void:
	var hud: Hud = _make_hud()
	GameState.sync_rate = 73.0
	assert_almost_eq(hud.get_sync_ratio(), 0.73, EPS)
	assert_eq(hud.get_sync_text(), "73 %")


func test_energy_updates_bar() -> void:
	var hud: Hud = _make_hud()
	GameState.debug_energy = 0.0
	assert_almost_eq(hud.get_energy_ratio(), 0.0, EPS)
	GameState.debug_energy = 60.0
	assert_almost_eq(hud.get_energy_ratio(), 0.6, EPS)


## Al gastar la ultima energia (ultimo disparo del laser) la bateria se ve
## vacia al instante: ningun segmento encendido ni en rastro, tambien con
## disparos seguidos (el rastro iba por detras) y con restos de coma flotante.
func test_battery_fully_empty_at_zero_energy() -> void:
	var hud: Hud = _make_hud()
	GameState.debug_energy = 30.0
	hud.finish_animations()
	for energy: float in [20.0, 10.0, 0.0]:
		GameState.debug_energy = energy
	assert_eq(hud.get_battery_segments(), 0, "Ningun segmento encendido")
	assert_almost_eq(hud.get_energy_trail(), 0.0, EPS, "Sin rastro de consumo pendiente")
	var battery := hud.get_node("Frame/Row/Battery") as HudMeter
	assert_eq(battery.get_trail_count(), 0, "Ningun segmento en rastro")
	assert_eq(battery.get_shell_row(), HudMeter.ShellRow.EMPTY, "Rayo de la carcasa apagado")
	GameState.debug_energy = 0.00001
	assert_eq(hud.get_battery_segments(), 0, "Restos de coma flotante: vacia")
	await wait_seconds(_config.drain_delay_s + _config.drain_duration_s + DRAIN_MARGIN_S)
	assert_eq(hud.get_battery_segments(), 0)
	assert_almost_eq(hud.get_energy_trail(), 0.0, EPS)


func test_attention_counter_updates() -> void:
	var hud: Hud = _make_hud()
	GameState.attention_points = 12
	assert_eq(hud.get_attention_text(), "12")


func test_values_clamped_to_range() -> void:
	var hud: Hud = _make_hud()
	GameState.sync_rate = 250.0
	assert_almost_eq(hud.get_sync_ratio(), 1.0, EPS)
	assert_eq(hud.get_sync_text(), "100 %")
	GameState.sync_rate = -40.0
	assert_almost_eq(hud.get_sync_ratio(), 0.0, EPS)
	assert_eq(hud.get_sync_text(), "0 %")
	GameState.debug_energy = 999.0
	assert_almost_eq(hud.get_energy_ratio(), 1.0, EPS)
	GameState.attention_points = -5
	assert_eq(hud.get_attention_text(), "0")


func test_hud_clamps_raw_eventbus_values() -> void:
	var hud: Hud = _make_hud()
	EventBus.sync_rate_changed.emit(180.0, 100.0)
	assert_almost_eq(hud.get_sync_ratio(), 1.0, EPS)
	EventBus.energy_changed.emit(-20.0, 100.0)
	assert_almost_eq(hud.get_energy_ratio(), 0.0, EPS)
	EventBus.attention_points_changed.emit(-3)
	assert_eq(hud.get_attention_text(), "0")
	EventBus.energy_changed.emit(10.0, 0.0)
	assert_almost_eq(hud.get_energy_ratio(), 0.0, EPS, "Maximo 0: sin division por cero")
	# Restaura el HUD al estado real.
	GameState.emit_state()


func test_attention_point_recharges_energy() -> void:
	var hud: Hud = _make_hud()
	GameState.debug_energy = 0.0
	GameState.add_attention_points(2)
	assert_eq(hud.get_attention_text(), "2")
	assert_almost_eq(GameState.debug_energy, 2 * GameState.ENERGY_PER_ATTENTION_POINT, EPS, "A10: +10 por punto")
	assert_almost_eq(hud.get_energy_ratio(), 0.2, EPS)


func test_row_width_stable_when_numbers_change() -> void:
	var hud: Hud = _make_hud()
	await wait_process_frames(1)
	var width: float = hud.get_row_width()
	GameState.sync_rate = 5.0
	GameState.attention_points = 12
	await wait_process_frames(1)
	assert_almost_eq(hud.get_row_width(), width, EPS, "La fila no se mueve al cambiar los numeros")


# --- Indicador de carga del Debug ---

func test_charge_ring_follows_activation_progress() -> void:
	var hud: Hud = _make_hud()
	await wait_process_frames(1)
	assert_almost_eq(hud.get_activation_progress(), 0.0, EPS, "Sin carga no se dibuja")
	var width: float = hud.get_row_width()
	EventBus.debug_activation_progress_changed.emit(0.5)
	assert_almost_eq(hud.get_activation_progress(), 0.5, EPS)
	EventBus.debug_activation_progress_changed.emit(1.0)
	assert_almost_eq(hud.get_activation_progress(), 1.0, EPS)
	await wait_process_frames(1)
	assert_almost_eq(hud.get_row_width(), width, EPS, "El anillo conserva su hueco: la fila no se mueve")
	EventBus.debug_activation_progress_changed.emit(0.0)
	assert_almost_eq(hud.get_activation_progress(), 0.0, EPS)


func test_charge_ring_uses_world_debug_color() -> void:
	var hud: Hud = _make_hud()
	assert_eq(hud.get_charge_color(), _config.debug_color_for_world(GameState.FIRST_WORLD))
	GameState.current_world = 3
	assert_eq(hud.get_charge_color(), _config.debug_color_for_world(3))
	assert_eq(hud.get_charge_color(), hud.get_energy_color(), "Mismo color que la bateria")


func test_charge_ring_driven_by_debug_mode() -> void:
	var saved_debug: bool = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	var hud: Hud = _make_hud()
	var dt: float = 1.0 / 60.0
	var hold_s: float = DebugModeConfig.shared().activation_hold_s
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in roundi(hold_s * 0.5 / dt):
		DebugMode.step(dt, true)
	assert_almost_eq(hud.get_activation_progress(), 0.5, 0.02, "El HUD recibe la carga por EventBus")
	DebugMode.step(dt, false)
	assert_almost_eq(hud.get_activation_progress(), 0.0, EPS, "Soltar antes la borra")
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, saved_debug)


# --- Animaciones ---

func test_damage_trail_drains_after_delay() -> void:
	var hud: Hud = _make_hud()
	GameState.apply_sync_damage(30.0)
	assert_almost_eq(hud.get_sync_ratio(), 0.7, EPS, "El valor cae al instante")
	assert_almost_eq(hud.get_sync_trail(), 1.0, EPS, "El rastro de dano se queda en el valor anterior")
	await wait_seconds(_config.drain_delay_s + _config.drain_duration_s + DRAIN_MARGIN_S)
	assert_almost_eq(hud.get_sync_trail(), 0.7, EPS, "El rastro termina en el valor nuevo")


func test_gain_has_no_trail() -> void:
	var hud: Hud = _make_hud()
	GameState.debug_energy = 20.0
	hud.finish_animations()
	GameState.debug_energy = 80.0
	assert_almost_eq(hud.get_energy_ratio(), 0.8, EPS)
	assert_almost_eq(hud.get_energy_trail(), 0.8, EPS)


# --- Color del Debug por mundo ---

func test_energy_color_follows_world() -> void:
	var hud: Hud = _make_hud()
	assert_eq(hud.get_energy_color(), _config.debug_color_for_world(1))
	GameState.current_world = 2
	assert_eq(hud.get_energy_color(), _config.debug_color_for_world(2))
	GameState.current_world = 4
	assert_eq(hud.get_energy_color(), _config.debug_color_for_world(4))
	assert_ne(_config.debug_color_for_world(1), _config.debug_color_for_world(2))


func test_new_hud_uses_current_world_color() -> void:
	GameState.current_world = 3
	var hud: Hud = _make_hud()
	assert_eq(hud.get_energy_color(), _config.debug_color_for_world(3))


# --- Sync Rate bajo ---

func test_low_sync_signal_emitted_on_threshold() -> void:
	watch_signals(EventBus)
	GameState.sync_rate = _config.low_sync_threshold
	assert_signal_not_emitted(EventBus, "low_sync_changed", "Justo en el umbral no es bajo (menor al 20%)")
	assert_false(GameState.is_sync_low())
	GameState.sync_rate = _config.low_sync_threshold - 1.0
	assert_signal_emitted_with_parameters(EventBus, "low_sync_changed", [true])
	assert_true(GameState.is_sync_low())
	GameState.sync_rate = _config.low_sync_threshold - 5.0
	assert_signal_emit_count(EventBus, "low_sync_changed", 1, "Solo se emite al cruzar el umbral")
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	assert_signal_emitted_with_parameters(EventBus, "low_sync_changed", [false])


func test_hud_low_sync_state() -> void:
	var hud: Hud = _make_hud()
	assert_false(hud.is_low_sync_shown())
	GameState.sync_rate = 15.0
	assert_true(hud.is_low_sync_shown())
	assert_true(hud.is_blinking())
	assert_eq(hud.get_signal_color(), _config.color(&"low_sync"))
	assert_eq(hud.get_sync_text_color(), _config.color(&"low_sync"))
	GameState.sync_rate = 50.0
	assert_false(hud.is_low_sync_shown())
	assert_eq(hud.get_signal_color(), _config.color(&"signal"))


func test_reduced_effects_stop_blinking() -> void:
	var hud: Hud = _make_hud()
	GameState.sync_rate = 10.0
	GameState.reduce_low_sync_effects = true
	assert_true(hud.is_low_sync_shown(), "Sigue marcado en rojo")
	assert_false(hud.is_blinking(), "Accesibilidad: sin parpadeo")


func test_new_hud_starts_low_if_already_low() -> void:
	GameState.sync_rate = 10.0
	var hud: Hud = _make_hud()
	assert_true(hud.is_low_sync_shown())


# --- Ciclo de vida ---

func test_hud_frees_cleanly() -> void:
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	add_child(hud)
	GameState.apply_sync_damage(40.0)
	GameState.add_attention_points(1)
	hud.queue_free()
	await wait_process_frames(2)
	assert_false(is_instance_valid(hud))
	assert_false(EventBus.sync_rate_changed.get_connections().any(
		func(c: Dictionary) -> bool: return not is_instance_valid(c.callable.get_object())),
		"Sin conexiones colgando en EventBus")
	# Emitir tras liberar no debe fallar.
	GameState.sync_rate = 80.0
	assert_almost_eq(GameState.sync_rate, 80.0, EPS)


# --- Arena: HUD y teclas de depuracion ---

func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_arena_has_hud_and_debug_actions() -> void:
	var arena: Node = add_child_autofree(ARENA_SCENE.instantiate())
	assert_true(arena.get_node_or_null(^"Hud") is Hud, "La arena instancia el HUD")
	for action: StringName in [&"hud_debug_sync_down", &"hud_debug_sync_up", &"hud_debug_energy_down", &"hud_debug_attention_add"]:
		assert_true(InputMap.has_action(action), "Accion %s en el Input Map" % action)
		assert_false(InputMap.action_get_events(action).is_empty(), "%s tiene tecla" % action)


func test_arena_debug_keys_change_game_state() -> void:
	var arena: Node = add_child_autofree(ARENA_SCENE.instantiate())
	(arena.get_node(^"Isak") as Isak).input = PlayerInput.new()
	await wait_process_frames(1)
	GameState.debug_energy = 50.0
	arena._unhandled_input(_press(&"hud_debug_sync_down"))
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - ArenaScript.DEBUG_SYNC_STEP, EPS)
	arena._unhandled_input(_press(&"hud_debug_sync_up"))
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, EPS)
	arena._unhandled_input(_press(&"hud_debug_energy_down"))
	assert_almost_eq(GameState.debug_energy, 50.0 - ArenaScript.DEBUG_ENERGY_STEP, EPS)
	arena._unhandled_input(_press(&"hud_debug_attention_add"))
	assert_eq(GameState.attention_points, ArenaScript.DEBUG_ATTENTION_STEP)
	assert_almost_eq(GameState.debug_energy,
		50.0 - ArenaScript.DEBUG_ENERGY_STEP + GameState.ENERGY_PER_ATTENTION_POINT, EPS)
