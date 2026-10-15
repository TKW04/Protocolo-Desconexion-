## HUD de juego (docs 15.7 y propuesta A11): imita la barra de estado de un
## celular, arriba a la derecha.
## - Senal = Sync Rate (barras + porcentaje); parpadea por debajo del umbral.
## - Bateria = energia de Debug, en el color del Debug del mundo actual.
## - Contador de puntos de atencion con un icono pequeno, junto a la bateria.
## - Anillo de carga del Debug a la izquierda de la bateria: se llena mientras
##   se mantiene la accion `debug` (EventBus.debug_activation_progress_changed)
##   y desaparece al cancelar o activar.
## Solo escucha a EventBus (no lee nodos de juego). Al aparecer pide a
## GameState que reemita su estado con EventBus.state_refresh_requested.
## Aspecto definitivo del Mundo 1 (paso 12): texturas pixel art de
## assets/sprites/ui/ y fuente bitmap propia; todo se configura en
## data/hud.json (HudConfig). Pixel base: el HUD se maqueta en pixeles de arte
## dentro de Frame, que se escala x hud_pixel_scale (entero) a 1280x720.
## PENDIENTE: ruido/distorsion de pantalla con Sync Rate bajo (shader nuevo,
## sin propuesta concreta en docs). Gancho: EventBus.low_sync_changed y
## GameState.reduce_low_sync_effects.
## ClockSlot: hueco oculto reservado para la hora del Mundo 2 (C8, PROPUESTA).
## PowerBank (PROVISIONAL, 2026-10-14): contador minimo de power banks bajo la
## barra, a la derecha (icono dibujado con la carga parcial + "x<n>"); oculto
## sin power banks ni carga. Se crea por codigo para no tocar hud.tscn ni
## data/hud.json; sus ajustes estan en data/power_bank.json (hud).
## El porcentaje de Sync Rate muestra el valor real (puede pasar de 100 % con
## la mejora "Sync reforzado"); las barras siguen la fraccion del maximo.
## Bateria vacia por coste del laser (2026-10-15): con el laser desbloqueado,
## una energia menor que su coste (GameState.get_laser_energy_cost(), con
## mejoras) se ve como 0 (ningun segmento, rayo apagado, sin rastro), aunque
## quede un resto: ya no se puede disparar. Solo es visual: GameState.debug_energy
## no cambia. Sin laser sigue la regla de antes (vacia solo con 0). El Debug no
## cuenta: con ese resto aun se activa (duda en docs/preguntas.md).
class_name Hud
extends CanvasLayer

const PERCENT_FORMAT: String = "%d %%"
## Textos mas anchos esperados: reservan ancho fijo para que la fila no se
## mueva al cambiar los numeros.
const WIDEST_PERCENT: String = "100 %"
const WIDEST_ATTENTION: String = "999"
## Valor del rastro de dano/brillo cuando no hay animacion.
const NO_TRAIL: float = 0.0
const FULL: float = 1.0
## Fraccion de la bateria por debajo de la cual se ve vacia (restos de coma
## flotante del gasto continuo del Debug): con 0 de energia no queda ningun
## segmento encendido ni rastro.
const EMPTY_BATTERY_RATIO: float = 0.0001
## Anillo de carga del Debug sin carga (no se dibuja).
const NO_CHARGE: float = 0.0
## Parpadeo: fraccion de cada ciclo en que la senal se ve entera.
const BLINK_ON_FRACTION: float = 0.5
## Modulacion neutra de los textos: el color lo pone el shader de cambio de
## color clave (la fuente esta dibujada en el color "text").
const NEUTRAL_MODULATE: Color = Color.WHITE
const PANEL_ASSET: StringName = &"panel"
## Contador de power banks (glifos de la fuente del HUD: "x" y cifras).
const POWER_BANK_FORMAT: String = "x%d"

var _config: HudConfig = HudConfig.shared()
var _sync_ratio: float = FULL
var _energy_ratio: float = FULL
## Ultima energia recibida (real, sin la regla del laser) y su maximo: se
## vuelve a pintar si cambia el desbloqueo del laser o se compra una mejora.
var _energy_value: float = GameState.DEBUG_ENERGY_MAX
var _energy_max: float = GameState.DEBUG_ENERGY_MAX
var _attention_points: int = 0
var _world: int = GameState.FIRST_WORLD
var _is_low_sync: bool = false
var _reduce_effects: bool = false
var _blink_time: float = 0.0
## Rastro de dano en curso por indicador.
var _drain_tweens: Dictionary[HudMeter, Tween] = {}
## Todas las animaciones creadas (para cortarlas de golpe).
var _all_tweens: Array[Tween] = []

@onready var _frame: Control = $Frame
@onready var _background: NinePatchRect = $Frame/Background
@onready var _row: HBoxContainer = $Frame/Row
@onready var _clock_slot: Label = $Frame/ClockSlot
@onready var _signal: HudMeter = $Frame/Row/Signal
@onready var _sync_label: Label = $Frame/Row/SyncLabel
@onready var _battery: HudMeter = $Frame/Row/Battery
@onready var _charge: HudMeter = $Frame/Row/DebugCharge
@onready var _attention_icon: HudMeter = $Frame/Row/AttentionIcon
@onready var _attention_label: Label = $Frame/Row/AttentionLabel

var _power_bank_box: HBoxContainer
var _power_bank_icon: HudPowerBankIcon
var _power_bank_label: Label
var _power_banks: int = 0


func _ready() -> void:
	_apply_config()
	get_viewport().size_changed.connect(_fit_frame)
	EventBus.sync_rate_changed.connect(_on_sync_rate_changed)
	EventBus.energy_changed.connect(_on_energy_changed)
	EventBus.attention_points_changed.connect(_on_attention_points_changed)
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.low_sync_changed.connect(_on_low_sync_changed)
	EventBus.reduce_low_sync_effects_changed.connect(_on_reduce_effects_changed)
	EventBus.debug_activation_progress_changed.connect(_on_debug_activation_progress_changed)
	EventBus.power_banks_changed.connect(_on_power_banks_changed)
	EventBus.ability_unlock_changed.connect(_on_ability_unlock_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.state_refresh_requested.emit()
	# El primer estado no se anima.
	_finish_animations()


func _exit_tree() -> void:
	_kill_tweens()


func _process(delta: float) -> void:
	_blink_time += delta
	_update_low_sync_visual()


# --- Consultas (pruebas y depuracion) ---

func get_sync_ratio() -> float:
	return _signal.value


func get_sync_trail() -> float:
	return _signal.trail


func get_sync_text() -> String:
	return _sync_label.text


func get_energy_ratio() -> float:
	return _battery.value


func get_energy_trail() -> float:
	return _battery.trail


func get_energy_color() -> Color:
	return _battery.fill_color


## Progreso del anillo de carga del Debug (0-1).
func get_activation_progress() -> float:
	return _charge.value


func get_charge_color() -> Color:
	return _charge.fill_color


func get_attention_text() -> String:
	return _attention_label.text


## Contador de power banks: texto ("x2"), visible y carga parcial (0-1).
func get_power_bank_text() -> String:
	return _power_bank_label.text


func is_power_bank_shown() -> bool:
	return _power_bank_box.visible


func get_power_bank_charge_ratio() -> float:
	return _power_bank_icon.charge_ratio


func is_low_sync_shown() -> bool:
	return _is_low_sync


func is_blinking() -> bool:
	return _is_low_sync and not _reduce_effects


func get_signal_color() -> Color:
	return _signal.fill_color


func get_sync_text_color() -> Color:
	return _label_color(_sync_label)


func get_attention_icon_color() -> Color:
	return _attention_icon.fill_color


## Barras de senal y segmentos de bateria encendidos (tramos de data/hud.json).
func get_signal_bars() -> int:
	return _signal.get_lit_count()


func get_battery_segments() -> int:
	return _battery.get_lit_count()


## Fuente de los numeros del HUD.
func get_font() -> Font:
	return _sync_label.get_theme_font(&"font")


## Pixeles de pantalla por pixel de arte.
func get_pixel_scale() -> Vector2:
	return _frame.scale


func get_row_width() -> float:
	return _row.get_combined_minimum_size().x


## Termina al instante las animaciones en curso (pruebas y capturas).
func _finish_animations() -> void:
	_kill_tweens()
	_signal.trail = _signal.value
	_battery.trail = _battery.value
	for node: Control in [_signal, _battery, _attention_icon, _attention_label, _power_bank_label]:
		if node != null:
			node.scale = Vector2.ONE


func finish_animations() -> void:
	_finish_animations()


func _kill_tweens() -> void:
	for tween: Tween in _all_tweens:
		if tween.is_valid():
			tween.kill()
	_all_tweens.clear()
	_drain_tweens.clear()


func _new_tween() -> Tween:
	_all_tweens.assign(_all_tweens.filter(func(t: Tween) -> bool: return t.is_valid()))
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	_all_tweens.append(tween)
	return tween


# --- Aspecto ---

func _apply_config() -> void:
	var c: HudConfig = _config
	_frame.scale = Vector2.ONE * c.hud_pixel_scale
	_fit_frame()
	_background.texture = c.asset_texture(PANEL_ASSET)
	_background.patch_margin_bottom = c.panel_border_px
	_background.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_background.offset_bottom = c.bar_height_px
	_row.offset_top = 0
	_row.offset_bottom = c.bar_height_px
	_row.offset_right = -c.margin_px
	_row.add_theme_constant_override("separation", c.spacing_px)
	_clock_slot.offset_left = c.margin_px
	_clock_slot.offset_bottom = c.bar_height_px
	for meter: HudMeter in [_signal, _battery, _attention_icon, _charge]:
		meter.setup(c)
	_signal.fill_color = c.color(&"signal")
	_attention_icon.fill_color = c.color(&"attention_icon")
	_battery.fill_color = c.debug_color_for_world(_world)
	_charge.fill_color = c.debug_color_for_world(_world)
	_charge.value = NO_CHARGE
	var font: Font = c.load_font()
	for label: Label in [_sync_label, _attention_label, _clock_slot]:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", c.font_size)
		label.add_theme_color_override("font_color", NEUTRAL_MODULATE)
		label.material = c.new_key_swap_material(c.color(&"text"), c.color(&"text"))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reserve_width(_sync_label, WIDEST_PERCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_reserve_width(_attention_label, WIDEST_ATTENTION, HORIZONTAL_ALIGNMENT_LEFT)
	_sync_label.text = PERCENT_FORMAT % roundi(GameState.SYNC_RATE_MAX)
	_attention_label.text = str(_attention_points)
	_build_power_bank(c, font)


## Frame ocupa la pantalla en pixeles de arte (su escala la lleva a 1280x720).
func _fit_frame() -> void:
	_frame.size = get_viewport().get_visible_rect().size / _frame.scale


func _set_label_color(label: Label, color: Color) -> void:
	(label.material as ShaderMaterial).set_shader_parameter(&"target_color", color)


func _label_color(label: Label) -> Color:
	return (label.material as ShaderMaterial).get_shader_parameter(&"target_color")


func _reserve_width(label: Label, widest: String, align: HorizontalAlignment) -> void:
	var font: Font = label.get_theme_font(&"font")
	var width: float = font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, _config.font_size).x
	label.custom_minimum_size.x = ceilf(width)
	label.horizontal_alignment = align


# --- EventBus ---

func _on_sync_rate_changed(new_value: float, max_value: float) -> void:
	var ratio: float = _ratio(new_value, max_value)
	_sync_label.text = PERCENT_FORMAT % roundi(clampf(new_value, 0.0, max_value))
	_set_meter(_signal, ratio, _sync_ratio)
	_sync_ratio = ratio


## Con la bateria a 0 (p. ej. tras el ultimo disparo del laser) se vacia del
## todo y al instante: sin segmentos encendidos ni rastro de consumo pendiente
## (con disparos seguidos el rastro se quedaba atras y, durante una pausa, se
## congelaba). Con el laser desbloqueado, tambien con un resto menor que su
## coste (is_energy_shown_empty).
func _on_energy_changed(new_value: float, max_value: float) -> void:
	_energy_value = new_value
	_energy_max = max_value
	var ratio: float = _ratio(new_value, max_value)
	if ratio < EMPTY_BATTERY_RATIO or is_energy_shown_empty(new_value):
		ratio = 0.0
		_stop_drain(_battery)
		_battery.value = ratio
		_battery.trail = ratio
	else:
		_set_meter(_battery, ratio, _energy_ratio)
	_energy_ratio = ratio


## Si la bateria se ve vacia con `energy` aunque sea > 0: el laser esta
## desbloqueado y `energy` no alcanza para un disparo (misma tolerancia que
## Isak._has_laser_energy). Sin laser (o con coste 0) siempre falso.
static func is_energy_shown_empty(energy: float) -> bool:
	if not GameState.is_ability_unlocked(GameState.ABILITY_LASER):
		return false
	var cost: float = GameState.get_laser_energy_cost()
	return cost > 0.0 and energy + Isak.LASER_ENERGY_EPS < cost


## Al desbloquear o bloquear el laser (o comprar una mejora que cambie su
## coste) la regla de bateria vacia cambia: se vuelve a pintar la energia.
func _on_ability_unlock_changed(ability: StringName, _unlocked: bool) -> void:
	if ability == GameState.ABILITY_LASER:
		_on_energy_changed(_energy_value, _energy_max)


func _on_upgrade_purchased(_id: StringName) -> void:
	_on_energy_changed(_energy_value, _energy_max)


func _on_attention_points_changed(new_value: int) -> void:
	var value: int = maxi(new_value, GameState.ATTENTION_POINTS_MIN)
	_attention_label.text = str(value)
	if value > _attention_points:
		_pulse(_attention_icon)
		_pulse(_attention_label)
	_attention_points = value


func _on_world_changed(world: int) -> void:
	_world = world
	_battery.fill_color = _config.debug_color_for_world(world)
	_charge.fill_color = _config.debug_color_for_world(world)
	if _power_bank_icon != null:
		_power_bank_icon.fill_color = _config.debug_color_for_world(world)
		_power_bank_icon.queue_redraw()


func _on_power_banks_changed(full: int, charge: float, capacity: float) -> void:
	var ratio: float = clampf(charge / capacity, 0.0, FULL) if capacity > 0.0 else 0.0
	_power_bank_label.text = POWER_BANK_FORMAT % maxi(full, 0)
	_power_bank_icon.charge_ratio = ratio
	_power_bank_icon.queue_redraw()
	var show_empty: bool = bool(GameState.get_power_bank_hud_data().get("show_when_empty", false))
	# Tambien se ve con power banks vacios (llegan sin carga, decision 2026-10-14).
	_power_bank_box.visible = show_empty or full > 0 or ratio > 0.0 or GameState.empty_power_banks > 0
	if full > _power_banks:
		_pulse(_power_bank_label)
	_power_banks = full


func _build_power_bank(c: HudConfig, font: Font) -> void:
	var d: Dictionary = GameState.get_power_bank_hud_data()
	_power_bank_box = HBoxContainer.new()
	_power_bank_box.name = "PowerBank"
	_power_bank_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bank_box.add_theme_constant_override("separation", int(d.get("spacing_px", 2)))
	_power_bank_box.alignment = BoxContainer.ALIGNMENT_END
	_power_bank_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_power_bank_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_power_bank_box.offset_right = -c.margin_px
	_power_bank_box.offset_top = c.bar_height_px + int(d.get("offset_y_px", 2))
	_power_bank_box.offset_bottom = _power_bank_box.offset_top + c.bar_height_px
	_frame.add_child(_power_bank_box)
	_power_bank_icon = HudPowerBankIcon.new()
	_power_bank_icon.name = "Icon"
	var icon_size: Array = d.get("icon_size_px", [6, 10])
	_power_bank_icon.custom_minimum_size = Vector2(float(icon_size[0]), float(icon_size[1]))
	_power_bank_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_power_bank_icon.outline_color = c.color(&"text")
	_power_bank_icon.fill_color = c.debug_color_for_world(_world)
	_power_bank_box.add_child(_power_bank_icon)
	_power_bank_label = Label.new()
	_power_bank_label.name = "Count"
	_power_bank_label.add_theme_font_override("font", font)
	_power_bank_label.add_theme_font_size_override("font_size", c.font_size)
	_power_bank_label.add_theme_color_override("font_color", NEUTRAL_MODULATE)
	_power_bank_label.material = c.new_key_swap_material(c.color(&"text"), c.color(&"text"))
	_power_bank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_power_bank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bank_label.text = POWER_BANK_FORMAT % 0
	_power_bank_box.add_child(_power_bank_label)
	_power_bank_box.visible = bool(d.get("show_when_empty", false))


func _on_debug_activation_progress_changed(progress: float) -> void:
	_charge.value = progress


func _on_low_sync_changed(is_low: bool) -> void:
	_is_low_sync = is_low
	_blink_time = 0.0
	_signal.fill_color = _config.color(&"low_sync") if is_low else _config.color(&"signal")
	_signal.low = is_low
	_set_label_color(_sync_label, _config.color(&"low_sync") if is_low else _config.color(&"text"))
	_update_low_sync_visual()


func _on_reduce_effects_changed(enabled: bool) -> void:
	_reduce_effects = enabled
	_update_low_sync_visual()


# --- Animaciones ---

static func _ratio(value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return NO_TRAIL
	return clampf(value / max_value, 0.0, FULL)


## Baja: el valor cae ya y el rastro rojo se vacia con retardo. Sube: pulso.
func _set_meter(meter: HudMeter, ratio: float, previous: float) -> void:
	if is_equal_approx(ratio, previous):
		meter.value = ratio
		return
	_stop_drain(meter)
	if ratio < previous:
		meter.trail = maxf(meter.trail, previous)
		meter.value = ratio
		var tween: Tween = _new_tween()
		tween.tween_interval(_config.drain_delay_s)
		tween.tween_property(meter, ^"trail", ratio, _config.drain_duration_s) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_drain_tweens[meter] = tween
	else:
		meter.trail = ratio
		meter.value = ratio
		_pulse(meter)


func _stop_drain(meter: HudMeter) -> void:
	if _drain_tweens.has(meter) and _drain_tweens[meter].is_valid():
		_drain_tweens[meter].kill()
	_drain_tweens.erase(meter)


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var half: float = _config.gain_pulse_duration_s * 0.5
	var tween: Tween = _new_tween()
	tween.tween_property(node, ^"scale", Vector2.ONE * _config.gain_pulse_scale, half)
	tween.tween_property(node, ^"scale", Vector2.ONE, half)


func _update_low_sync_visual() -> void:
	var alpha: float = FULL
	if is_blinking():
		# Onda cuadrada: mitad del ciclo visible, mitad atenuada.
		var phase: float = fmod(_blink_time * _config.low_sync_blink_hz, FULL)
		alpha = FULL if phase < BLINK_ON_FRACTION else _config.low_sync_blink_min_alpha
	_signal.modulate.a = alpha
	_sync_label.modulate.a = alpha
