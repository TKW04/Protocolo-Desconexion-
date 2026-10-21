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
## Modo hub (2026-10-15, enable_hub_mode): icono de ajustes (abre el menu de
## pausa; 2026-10-16) y Modo Avion en lugar de la senal e
## indicador «sin guardar» en ambar (seccion hud de data/hub.json).
## Vidas (intentos; 2026-10-16, docs/propuesta-asistentes-y-vidas.md §5.1 y §9):
## a la izquierda de la senal, un mini telefono por vida hasta lives_max (lleno
## o vacio; hud_lives.png) o, con mas de max_icons, un icono y «x<n>» (seccion
## lives de data/hud.json). EventBus.lives_changed. Oculto hasta que las vidas
## cuentan (primera llegada al hub) y en el hub. Al perder una, el icono que se
## apaga parpadea y da un bote. Se crea por codigo (no toca hud.tscn).
## Ocultarte (Pulso 4 de las mejoras de Calc, tanda M2): mientras esta activo,
## bajo la barra y a la izquierda del contador de power banks, el icono «oculto»
## (hud_hide.png) y una barra con lo que queda hasta el corte al 10 %
## (HideMode.remaining_fraction); por debajo del 20 % de Sync Rate o energia el
## icono y la barra parpadean (aviso de que se va a apagar). Seccion hide de
## data/hud.json; se crea por codigo (no toca hud.tscn).
## Barra del jefe (2026-10-21, paso 9 de docs/propuesta-jefe-alerta-mayor.md):
## BossBar (hija "BossBar", seccion boss_bar de data/hud.json), arriba en el
## centro; aparece sola con EventBus.boss_started. Se crea por codigo.
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

## Modo hub (enable_hub_mode): Modo Avion en lugar de la senal e indicador
## «sin guardar». Se crea por codigo (no toca hud.tscn ni data/hud.json).
var _hub_mode: bool = false
var _airplane: TextureRect
## Icono de ajustes del modo hub (abre el menu de pausa).
var _settings: TextureRect
var _unsaved_box: HBoxContainer
var _unsaved_icon: TextureRect
var _unsaved_label: Label

## Vidas (intentos): caja a la izquierda de la senal.
var _lives_box: HBoxContainer
var _lives_icons: Array[TextureRect] = []
var _lives_label: Label
var _lives_full: Texture2D
var _lives_empty: Texture2D
var _lives: int = GameState.LIVES_MAX_DEFAULT
var _lives_max: int = GameState.LIVES_MAX_DEFAULT
var _lives_active: bool = false
## Icono que parpadea tras perder una vida (null si ninguno).
var _lost_icon: Control

## Ocultarte: caja bajo la barra con el icono y la barra de lo que queda.
var _boss_bar: BossBar
var _hide_box: HBoxContainer
var _hide_icon: TextureRect
var _hide_bar: HideBar
var _hide_on: Texture2D
var _hide_off: Texture2D
var _hide_active: bool = false
var _hide_hold_left: float = 0.0
var _hide_time: float = 0.0


## Barra del Ocultarte (lo que queda hasta el corte): borde, fondo y relleno.
class HideBar:
	extends Control
	var ratio: float = 1.0
	var border := Color("#aeb8d2")
	var back := Color("#0b0e1a")
	var fill := Color("#3dfff5")

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, border)
		var inner := r.grow(-1.0)
		draw_rect(inner, back)
		var w: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0))
		if w > 0.0:
			draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)


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
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.hide_changed.connect(_on_hide_changed)
	EventBus.hide_ended.connect(_on_hide_ended)
	_boss_bar = BossBar.new()
	add_child(_boss_bar)
	EventBus.state_refresh_requested.emit()
	# El primer estado no se anima.
	_finish_animations()


func _exit_tree() -> void:
	_kill_tweens()


func _process(delta: float) -> void:
	_blink_time += delta
	_update_low_sync_visual()
	_update_hide(delta)


# --- Consultas (pruebas y depuracion) ---

## Barra del jefe (oculta fuera de una pelea).
func get_boss_bar() -> BossBar:
	return _boss_bar


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
	for icon: TextureRect in _lives_icons:
		icon.scale = Vector2.ONE
		icon.modulate.a = 1.0
	_lost_icon = null


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
	_build_lives(c, font)
	_build_hide(c)


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


# --- Ocultarte (Pulso 4, tanda M2) ---

func _build_hide(c: HudConfig) -> void:
	var d: Dictionary = c.hide
	_hide_box = HBoxContainer.new()
	_hide_box.name = "Hide"
	_hide_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_box.add_theme_constant_override("separation", int(d.get("spacing_px", 2)))
	_hide_box.alignment = BoxContainer.ALIGNMENT_END
	_hide_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hide_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hide_box.offset_right = -c.margin_px
	_hide_box.offset_top = c.bar_height_px + int(d.get("offset_y_px", 2))
	_hide_box.offset_bottom = _hide_box.offset_top + c.bar_height_px
	_frame.add_child(_hide_box)
	var sheet: Texture2D = c.asset_texture(&"hide") if c.assets.has(&"hide") else null
	var frame: Vector2i = c.asset_frame_size(&"hide")
	_hide_on = _lives_frame(sheet, frame, 0, [0, 0, frame.x, frame.y])
	_hide_off = _lives_frame(sheet, frame, 1, [0, 0, frame.x, frame.y])
	_hide_icon = TextureRect.new()
	_hide_icon.name = "Icon"
	_hide_icon.texture = _hide_on
	_hide_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_hide_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hide_box.add_child(_hide_icon)
	_hide_bar = HideBar.new()
	_hide_bar.name = "Bar"
	_hide_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar: Array = d.get("bar_size_px", [20, 4])
	_hide_bar.custom_minimum_size = Vector2(float(bar[0]), float(bar[1]))
	_hide_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hide_bar.border = Color(String(d.get("bar_border", "#aeb8d2")))
	_hide_bar.back = Color(String(d.get("bar_back", "#0b0e1a")))
	_hide_bar.fill = Color(String(d.get("bar_fill", "#3dfff5")))
	_hide_box.add_child(_hide_bar)
	_hide_box.visible = false


func _on_hide_changed(active: bool) -> void:
	_hide_active = active
	if active:
		_hide_hold_left = 0.0
		_hide_time = 0.0
	_update_hide(0.0)


## Al cortarse solo (10 %) el indicador se queda un momento apagado.
func _on_hide_ended(reason: StringName) -> void:
	if reason == HideMode.REASON_CUT:
		_hide_hold_left = float(_config.hide.get("cut_hold_s", 0.6))
	_update_hide(0.0)


func _update_hide(delta: float) -> void:
	if _hide_box == null:
		return
	_hide_hold_left = maxf(_hide_hold_left - delta, 0.0)
	var shown: bool = _hide_active or _hide_hold_left > 0.0
	_hide_box.visible = shown
	if not shown:
		return
	_hide_time += delta
	var d: Dictionary = _config.hide
	var warn: bool = _hide_active and HideMode.is_low()
	var blink_off: bool = warn and fmod(_hide_time * float(d.get("blink_hz", 4.0)), 1.0) >= 0.5
	_hide_icon.texture = _hide_off if (blink_off or not _hide_active) else _hide_on
	_hide_bar.ratio = HideMode.remaining_fraction() if _hide_active else 0.0
	_hide_bar.fill = Color(String(d.get("warn_fill" if warn else "bar_fill", "#3dfff5")))
	_hide_bar.visible = not blink_off
	_hide_bar.queue_redraw()
	# A la izquierda del contador de power banks (si se ve).
	var right: float = _config.margin_px
	if _power_bank_box != null and _power_bank_box.visible:
		right += _power_bank_box.get_combined_minimum_size().x + float(d.get("gap_px", 4))
	_hide_box.offset_right = -right


## Indicador del Ocultarte visible, su barra (0-1) y si parpadea apagado ahora.
func is_hide_indicator_shown() -> bool:
	return _hide_box != null and _hide_box.visible


func get_hide_bar_ratio() -> float:
	return _hide_bar.ratio if _hide_bar != null else 0.0


func is_hide_icon_dim() -> bool:
	return _hide_icon != null and _hide_icon.texture == _hide_off


func get_hide_box() -> Control:
	return _hide_box


# --- Vidas (intentos) ---

func _build_lives(c: HudConfig, font: Font) -> void:
	var d: Dictionary = c.lives
	_lives_box = HBoxContainer.new()
	_lives_box.name = "Lives"
	_lives_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives_box.add_theme_constant_override("separation", int(d.get("spacing_px", 1)))
	_row.add_child(_lives_box)
	_row.move_child(_lives_box, 0)
	var spacer := Control.new()
	spacer.name = "Gap"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size.x = maxf(0.0, float(d.get("gap_to_signal_px", 3)) - float(c.spacing_px))
	var sheet: Texture2D = c.asset_texture(&"lives")
	var frame: Vector2i = c.asset_frame_size(&"lives")
	var rect: Array = d.get("icon_rect_px", [0, 0, frame.x, frame.y])
	_lives_full = _lives_frame(sheet, frame, 0, rect)
	_lives_empty = _lives_frame(sheet, frame, 1, rect)
	_lives_label = Label.new()
	_lives_label.name = "Count"
	_lives_label.add_theme_font_override("font", font)
	_lives_label.add_theme_font_size_override("font_size", c.font_size)
	_lives_label.add_theme_color_override("font_color", NEUTRAL_MODULATE)
	_lives_label.material = c.new_key_swap_material(c.color(&"text"), c.color(&"text"))
	_lives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives_label.visible = false
	_lives_box.add_child(_lives_label)
	_lives_box.add_child(spacer)
	_lives_box.visible = false


static func _lives_frame(sheet: Texture2D, frame: Vector2i, column: int, rect: Array) -> Texture2D:
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(column * frame.x + float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	return atlas


func _on_lives_changed(lives: int, lives_max: int, active: bool) -> void:
	var lost: bool = active and _lives_active and lives < _lives and lives_max == _lives_max
	var gained: bool = active and _lives_active and lives_max > _lives_max
	_lives = maxi(lives, 0)
	_lives_max = maxi(lives_max, 1)
	_lives_active = active
	_refresh_lives()
	if lost:
		_animate_life_lost()
	elif gained:
		_animate_life_gained()


## Repinta los iconos (o el contador «x<n>») y la visibilidad.
func _refresh_lives() -> void:
	if _lives_box == null:
		return
	_lives_box.visible = _lives_active and not _hub_mode
	var max_icons: int = int(_config.lives.get("max_icons", 8))
	var compact: bool = _lives_max > max_icons
	var count: int = 1 if compact else _lives_max
	while _lives_icons.size() < count:
		var icon := TextureRect.new()
		icon.name = "Life%d" % _lives_icons.size()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if _lives_full != null:
			icon.custom_minimum_size = _lives_full.get_size()
		_lives_box.add_child(icon)
		_lives_box.move_child(icon, _lives_icons.size())
		_lives_icons.append(icon)
	while _lives_icons.size() > count:
		var extra: TextureRect = _lives_icons.pop_back()
		extra.queue_free()
		_lives_box.remove_child(extra)
	for i: int in _lives_icons.size():
		var full: bool = (_lives > 0) if compact else i < _lives
		_lives_icons[i].texture = _lives_full if full else _lives_empty
	_lives_label.visible = compact
	_lives_label.text = String(_config.lives.get("format", "x%d")) % _lives


## Parpadeo y bote del icono que se acaba de apagar (o del unico en modo «x<n>»).
func _animate_life_lost() -> void:
	if _lives_icons.is_empty():
		return
	var index: int = 0 if _lives_icons.size() == 1 else clampi(_lives, 0, _lives_icons.size() - 1)
	var icon: TextureRect = _lives_icons[index]
	_lost_icon = icon
	var d: Dictionary = _config.lives
	var blinks: int = maxi(1, int(d.get("lost_blinks", 3)))
	var step: float = float(d.get("lost_blink_s", 0.6)) / float(blinks * 2)
	icon.pivot_offset = icon.custom_minimum_size * 0.5
	var pop := _new_tween()
	pop.tween_property(icon, ^"scale", Vector2.ONE * float(d.get("lost_pop_scale", 1.35)), step)
	pop.tween_property(icon, ^"scale", Vector2.ONE, step)
	var blink := _new_tween()
	for i: int in blinks:
		blink.tween_property(icon, ^"modulate:a", 0.15, step)
		blink.tween_property(icon, ^"modulate:a", 1.0, step)
	blink.tween_callback(func() -> void: _lost_icon = null)


## Vida extra (lives_max sube): el icono nuevo (el ultimo; o el unico en modo
## «x<n>») aparece con un bote desde gained_from_scale y un destello
## (gained_flash_s; seccion lives de data/hud.json).
func _animate_life_gained() -> void:
	if _lives_icons.is_empty():
		return
	var icon: TextureRect = _lives_icons[_lives_icons.size() - 1]
	var d: Dictionary = _config.lives
	var step: float = float(d.get("gained_pop_s", 0.4)) * 0.5
	icon.pivot_offset = icon.custom_minimum_size * 0.5
	icon.scale = Vector2.ONE * float(d.get("gained_from_scale", 0.2))
	var pop := _new_tween()
	pop.tween_property(icon, ^"scale", Vector2.ONE * float(d.get("gained_pop_scale", 1.5)), step)
	pop.tween_property(icon, ^"scale", Vector2.ONE, step)
	var flash := _new_tween()
	icon.modulate.a = 0.3
	flash.tween_property(icon, ^"modulate:a", 1.0, float(d.get("gained_flash_s", 0.3)))


## Vidas mostradas: iconos llenos (o la cifra en modo «x<n>») y visibilidad.
func is_lives_shown() -> bool:
	return _lives_box != null and _lives_box.visible


func get_life_icon_count() -> int:
	return _lives_icons.size()


## Iconos llenos que se ven ahora.
func get_lives_lit() -> int:
	var lit: int = 0
	for icon: TextureRect in _lives_icons:
		if icon.texture == _lives_full:
			lit += 1
	return lit


## Texto «x<n>» (solo visible con mas de max_icons vidas maximas).
func get_lives_text() -> String:
	return _lives_label.text if _lives_label != null and _lives_label.visible else ""


## Se esta animando la perdida de una vida.
func is_life_loss_animating() -> bool:
	return _lost_icon != null


func get_life_icons() -> Array[TextureRect]:
	return _lives_icons.duplicate()


# --- Modo hub (docs/propuesta-hub-y-guardado.md §1 y §4.3) ---

## Pasa el HUD al modo hub: la senal (Sync Rate) se sustituye por el icono de
## Modo Avion (en el hub no hay dano) y, junto al contador de puntos, sale el
## indicador «sin guardar» (punto y texto en el rol unsaved_color, ambar) cuando
## GameState.has_unsaved_changes(). `config`: seccion hud de data/hub.json.
## Iconos de assets/sprites/hub/icons/ (airplane_icon y unsaved_icon).
func enable_hub_mode(config: Dictionary) -> void:
	if _hub_mode:
		return
	_hub_mode = true
	_refresh_lives()
	_signal.visible = false
	_sync_label.visible = false
	var icon_size: Array = config.get("icon_size_px", [16, 16])
	_airplane = _hub_icon("AirplaneMode", String(config.get("airplane_icon", "")), icon_size)
	_row.add_child(_airplane)
	_row.move_child(_airplane, 0)
	# Ajustes (2026-10-16): en la esquina, antes del Modo Avion; un clic abre el
	# menu de pausa (como la accion pause).
	_settings = _hub_icon("Settings", String(config.get("settings_icon", "")), icon_size)
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_settings.gui_input.connect(_on_settings_gui_input)
	_row.add_child(_settings)
	_row.move_child(_settings, 0)
	var unsaved_color: Color = HubData.color(String(config.get("unsaved_color", "ambar")))
	_unsaved_box = HBoxContainer.new()
	_unsaved_box.name = "Unsaved"
	_unsaved_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unsaved_box.add_theme_constant_override("separation", int(config.get("unsaved_spacing_px", 3)))
	_row.add_child(_unsaved_box)
	_unsaved_icon = _hub_icon("Icon", String(config.get("unsaved_icon", "")), icon_size)
	_unsaved_box.add_child(_unsaved_icon)
	_unsaved_label = Label.new()
	_unsaved_label.name = "Text"
	_unsaved_label.add_theme_font_override("font", load(String(config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font)
	_unsaved_label.add_theme_font_size_override("font_size", int(config.get("font_size", 12)))
	_unsaved_label.add_theme_color_override("font_color", NEUTRAL_MODULATE)
	_unsaved_label.material = _config.new_key_swap_material(Color.html(String(config.get("font_key_color", "#f2f4f8"))), unsaved_color)
	_unsaved_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unsaved_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unsaved_label.text = String(config.get("unsaved_text", "Sin guardar"))
	_unsaved_box.add_child(_unsaved_label)
	EventBus.unsaved_changes_changed.connect(_on_unsaved_changes_changed)
	_on_unsaved_changes_changed(GameState.has_unsaved_changes())


## Icono del HUD del hub (TextureRect de `size_px` px de arte).
func _hub_icon(node_name: String, path: String, size_px: Array) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = load(path) as Texture2D if not path.is_empty() else null
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(float(size_px[0]), float(size_px[1]))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Iconos del modo hub (ajustes, Modo Avion y «sin guardar»), para pruebas.
func get_hub_icons() -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	if _hub_mode:
		out.append(_settings)
		out.append(_airplane)
		out.append(_unsaved_icon)
	return out


## Icono de ajustes del modo hub (null fuera del hub).
func get_settings_icon() -> TextureRect:
	return _settings if _hub_mode else null


## Abre el menu de pausa del arbol (icono de ajustes). Verdadero si se abrio.
func open_pause_menu() -> bool:
	var menu: PauseMenu = PauseMenu.find_in(get_tree()) if is_inside_tree() else null
	return menu != null and menu.request_open()


func _on_settings_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if open_pause_menu():
			_settings.accept_event()


func is_hub_mode() -> bool:
	return _hub_mode


## Modo Avion visible (y la senal oculta).
func is_airplane_mode_shown() -> bool:
	return _hub_mode and _airplane.visible and not _signal.visible


## El indicador ocupa siempre su sitio (la fila no se mueve al guardar): se
## oculta con la opacidad.
func is_unsaved_indicator_shown() -> bool:
	return _hub_mode and _unsaved_box.modulate.a > 0.0


func get_unsaved_text() -> String:
	return _unsaved_label.text if _hub_mode else ""


func get_unsaved_color() -> Color:
	return _label_color(_unsaved_label) if _hub_mode else Color.TRANSPARENT


func _on_unsaved_changes_changed(has_changes: bool) -> void:
	if _unsaved_box != null:
		_unsaved_box.modulate.a = 1.0 if has_changes else 0.0


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
