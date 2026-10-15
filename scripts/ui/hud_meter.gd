## Indicador del HUD dibujado con las texturas pixel art de assets/sprites/ui/
## (tools/gen_hud_assets.py), en pixeles de arte (el HUD entero se escala).
## - SIGNAL: barras de senal (Sync Rate), encendidas por tramos.
## - BATTERY: bateria de segmentos (energia de Debug), encendidos por tramos.
##   El marco tiene dos filas: con energia (rayo encendido) y vacia (rayo
##   apagado, sin ningun pixel del color del Debug).
## - ATTENTION_ICON: icono del contador de puntos de atencion.
## - CHARGE_RING: anillo de carga de la pulsacion larga del Debug en pasos
##   discretos (0 = no se dibuja, pero conserva su hueco para que la fila no
##   se mueva).
## Rutas, cuadros y tramos salen de HudConfig (data/hud.json). La bateria y el
## anillo estan dibujados en el color clave (debug_key) y un shader lo cambia
## por fill_color (color del Debug del mundo).
class_name HudMeter
extends Control

enum Kind { SIGNAL, BATTERY, ATTENTION_ICON, CHARGE_RING }

## Filas de hud_signal.png (orden de SIGNAL_STATES en tools/gen_hud_assets.py).
enum SignalRow { OFF, ON, LOW, TRAIL }
## Filas de hud_battery_segments.png (orden de SEG_STATES).
enum SegmentRow { EMPTY, FULL, TRAIL }
## Filas de hud_battery_shell.png (orden de SHELL_STATES).
enum ShellRow { CHARGED, EMPTY }

const SIGNAL_ASSET: StringName = &"signal"
const SHELL_ASSET: StringName = &"battery_shell"
const SEGMENTS_ASSET: StringName = &"battery_segments"
const ATTENTION_ASSET: StringName = &"attention_icon"
const RING_ASSET: StringName = &"charge_ring"

@export var kind: Kind = Kind.SIGNAL

## Valor mostrado (0-1).
var value: float = 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## Rastro del dano (0-1): lo que se acaba de perder, en el estado de rastro.
var trail: float = 1.0:
	set(v):
		trail = clampf(v, 0.0, 1.0)
		queue_redraw()
## Color principal: senal (blanco o rojo de Sync Rate bajo), color del Debug
## (bateria y anillo) o ambar (icono). Lo consultan el HUD y las pruebas.
var fill_color: Color = Color.WHITE:
	set(v):
		fill_color = v
		_update_material()
		queue_redraw()
## Senal en estado de Sync Rate bajo (barras en alerta).
var low: bool = false:
	set(v):
		low = v
		queue_redraw()

var _config: HudConfig = HudConfig.shared()
var _texture: Texture2D
var _shell: Texture2D


func setup(config: HudConfig) -> void:
	_config = config
	match kind:
		Kind.SIGNAL:
			_texture = config.asset_texture(SIGNAL_ASSET)
		Kind.BATTERY:
			_texture = config.asset_texture(SEGMENTS_ASSET)
			_shell = config.asset_texture(SHELL_ASSET)
		Kind.CHARGE_RING:
			_texture = config.asset_texture(RING_ASSET)
		_:
			_texture = config.asset_texture(ATTENTION_ASSET)
	if kind == Kind.BATTERY or kind == Kind.CHARGE_RING:
		material = config.new_key_swap_material(config.color(&"debug_key"), fill_color)
	custom_minimum_size = get_meter_size()
	queue_redraw()


func _update_material() -> void:
	var swap: ShaderMaterial = material as ShaderMaterial
	if swap != null:
		swap.set_shader_parameter(&"target_color", fill_color)


func get_meter_size() -> Vector2:
	return Vector2(_config.asset_frame_size(_asset_name()))


func _asset_name() -> StringName:
	match kind:
		Kind.SIGNAL:
			return SIGNAL_ASSET
		Kind.BATTERY:
			return SHELL_ASSET
		Kind.CHARGE_RING:
			return RING_ASSET
		_:
			return ATTENTION_ASSET


## Barras de senal encendidas con el valor actual (tramos de data/hud.json).
func get_lit_count() -> int:
	return HudConfig.lit_count(value, _thresholds())


## Partes en estado de rastro (entre el valor y el rastro).
func get_trail_count() -> int:
	return maxi(HudConfig.lit_count(trail, _thresholds()) - get_lit_count(), 0)


## Fila del marco de la bateria: vacia (rayo apagado) sin segmentos encendidos.
func get_shell_row() -> int:
	return ShellRow.CHARGED if get_lit_count() > 0 else ShellRow.EMPTY


## Cuadro del anillo de carga (0 a steps-1) o -1 si no se dibuja.
func get_ring_frame() -> int:
	if value <= 0.0:
		return -1
	var steps: int = _config.charge_ring_steps
	return clampi(ceili(value * steps) - 1, 0, steps - 1)


func _thresholds() -> Array[float]:
	return _config.battery_thresholds if kind == Kind.BATTERY else _config.signal_thresholds


func _draw() -> void:
	if _texture == null:
		return
	# Centrado vertical (en pixeles enteros) dentro del alto del contenedor.
	var top: float = floorf((size.y - get_meter_size().y) * 0.5)
	match kind:
		Kind.SIGNAL:
			_draw_parts(top, _signal_row)
		Kind.BATTERY:
			var shell := Vector2(_config.asset_frame_size(SHELL_ASSET))
			draw_texture_rect_region(_shell, Rect2(Vector2(0.0, top), shell),
					Rect2(Vector2(0.0, get_shell_row() * shell.y), shell))
			_draw_parts(top, _segment_row)
		Kind.ATTENTION_ICON:
			draw_texture(_texture, Vector2(0.0, top))
		Kind.CHARGE_RING:
			var frame: int = get_ring_frame()
			if frame >= 0:
				_draw_frame(frame, 0, top)


func _signal_row(lit: bool, in_trail: bool) -> int:
	if lit:
		return SignalRow.LOW if low else SignalRow.ON
	return SignalRow.TRAIL if in_trail else SignalRow.OFF


func _segment_row(lit: bool, in_trail: bool) -> int:
	if lit:
		return SegmentRow.FULL
	return SegmentRow.TRAIL if in_trail else SegmentRow.EMPTY


## Cada parte (columna del atlas) en su estado; los cuadros se superponen.
func _draw_parts(top: float, row_for: Callable) -> void:
	var lit: int = get_lit_count()
	var trailing: int = lit + get_trail_count()
	for i: int in _thresholds().size():
		_draw_frame(i, row_for.call(i < lit, i < trailing), top)


func _draw_frame(column: int, row: int, top: float) -> void:
	var frame := Vector2(_config.asset_frame_size(_asset_name_for_atlas()))
	var src := Rect2(Vector2(column, row) * frame, frame)
	draw_texture_rect_region(_texture, Rect2(Vector2(0.0, top), frame), src)


## La bateria mide como su marco, pero sus segmentos vienen de otra hoja.
func _asset_name_for_atlas() -> StringName:
	return SEGMENTS_ASSET if kind == Kind.BATTERY else _asset_name()
