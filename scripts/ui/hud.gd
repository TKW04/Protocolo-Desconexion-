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
## Aspecto provisional: todo sale de data/hud.json (HudConfig); el arte
## definitivo con la paleta del Mundo 1 se hace en el paso 12.
## PENDIENTE: ruido/distorsion de pantalla con Sync Rate bajo (shader nuevo,
## sin propuesta concreta en docs). Gancho: EventBus.low_sync_changed y
## GameState.reduce_low_sync_effects.
## ClockSlot: hueco oculto reservado para la hora del Mundo 2 (C8, PROPUESTA).
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
## Anillo de carga del Debug sin carga (no se dibuja).
const NO_CHARGE: float = 0.0
## Parpadeo: fraccion de cada ciclo en que la senal se ve entera.
const BLINK_ON_FRACTION: float = 0.5

var _config: HudConfig = HudConfig.shared()
var _sync_ratio: float = FULL
var _energy_ratio: float = FULL
var _attention_points: int = 0
var _world: int = GameState.FIRST_WORLD
var _is_low_sync: bool = false
var _reduce_effects: bool = false
var _blink_time: float = 0.0
## Rastro de dano en curso por indicador.
var _drain_tweens: Dictionary[HudMeter, Tween] = {}
## Todas las animaciones creadas (para cortarlas de golpe).
var _all_tweens: Array[Tween] = []

@onready var _background: ColorRect = $Background
@onready var _row: HBoxContainer = $Row
@onready var _clock_slot: Label = $ClockSlot
@onready var _signal: HudMeter = $Row/Signal
@onready var _sync_label: Label = $Row/SyncLabel
@onready var _battery: HudMeter = $Row/Battery
@onready var _charge: HudMeter = $Row/DebugCharge
@onready var _attention_icon: HudMeter = $Row/AttentionIcon
@onready var _attention_label: Label = $Row/AttentionLabel


func _ready() -> void:
	_apply_config()
	EventBus.sync_rate_changed.connect(_on_sync_rate_changed)
	EventBus.energy_changed.connect(_on_energy_changed)
	EventBus.attention_points_changed.connect(_on_attention_points_changed)
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.low_sync_changed.connect(_on_low_sync_changed)
	EventBus.reduce_low_sync_effects_changed.connect(_on_reduce_effects_changed)
	EventBus.debug_activation_progress_changed.connect(_on_debug_activation_progress_changed)
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


func is_low_sync_shown() -> bool:
	return _is_low_sync


func is_blinking() -> bool:
	return _is_low_sync and not _reduce_effects


func get_signal_color() -> Color:
	return _signal.fill_color


func get_sync_text_color() -> Color:
	return _sync_label.get_theme_color(&"font_color")


func get_row_width() -> float:
	return _row.get_combined_minimum_size().x


## Termina al instante las animaciones en curso (pruebas y capturas).
func _finish_animations() -> void:
	_kill_tweens()
	_signal.trail = _signal.value
	_battery.trail = _battery.value
	for node: Control in [_signal, _battery, _attention_icon, _attention_label]:
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
	_background.color = c.color(&"background")
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
	_attention_icon.empty_color = c.color(&"background")
	_battery.fill_color = c.debug_color_for_world(_world)
	_charge.fill_color = c.debug_color_for_world(_world)
	_charge.value = NO_CHARGE
	for label: Label in [_sync_label, _attention_label, _clock_slot]:
		label.add_theme_font_size_override("font_size", c.font_size)
		label.add_theme_color_override("font_color", c.color(&"text"))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reserve_width(_sync_label, WIDEST_PERCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_reserve_width(_attention_label, WIDEST_ATTENTION, HORIZONTAL_ALIGNMENT_LEFT)
	_sync_label.text = PERCENT_FORMAT % roundi(GameState.SYNC_RATE_MAX)
	_attention_label.text = str(_attention_points)


func _reserve_width(label: Label, widest: String, align: HorizontalAlignment) -> void:
	var font: Font = label.get_theme_font(&"font")
	var width: float = font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, _config.font_size).x
	label.custom_minimum_size.x = ceilf(width)
	label.horizontal_alignment = align


# --- EventBus ---

func _on_sync_rate_changed(new_value: float, max_value: float) -> void:
	var ratio: float = _ratio(new_value, max_value)
	_sync_label.text = PERCENT_FORMAT % roundi(ratio * GameState.SYNC_RATE_MAX)
	_set_meter(_signal, ratio, _sync_ratio)
	_sync_ratio = ratio


func _on_energy_changed(new_value: float, max_value: float) -> void:
	var ratio: float = _ratio(new_value, max_value)
	_set_meter(_battery, ratio, _energy_ratio)
	_energy_ratio = ratio


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


func _on_debug_activation_progress_changed(progress: float) -> void:
	_charge.value = progress


func _on_low_sync_changed(is_low: bool) -> void:
	_is_low_sync = is_low
	_blink_time = 0.0
	_signal.fill_color = _config.color(&"low_sync") if is_low else _config.color(&"signal")
	_sync_label.add_theme_color_override("font_color",
		_config.color(&"low_sync") if is_low else _config.color(&"text"))
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
	if _drain_tweens.has(meter) and _drain_tweens[meter].is_valid():
		_drain_tweens[meter].kill()
	_drain_tweens.erase(meter)
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
