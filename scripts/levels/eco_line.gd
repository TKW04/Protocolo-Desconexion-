## Disparador de una linea de Eco (tipo `eco_line` de la lista `objects` del
## nivel, V7; PROPUESTA V6). Zona invisible de width_tiles x height_tiles desde
## la esquina superior izquierda de la celda (x, y). Cuando Isak entra, pide al
## cuadro de texto de Eco (EcoTextBox, por EventBus.eco_line_requested) que
## muestre `text` durante al menos `duration_s`. Con `once` (por defecto) solo
## se dispara la primera vez. No es solida y no toca a Isak. Con `important`
## (historia, cosas relevantes) el cuadro pausa el juego hasta que el jugador
## la cierra; si no, no pausa.
## Detecta la capa de fisica `player` (2).
## Con `trigger_event` (rediseno del 1-1 para el laser, 2026-10-15) no hay zona:
## la linea salta al emitirse esa senal de EventBus (p. ej. &"laser_fired": la
## primera vez que Isak dispara el laser en el nivel), con las mismas reglas de
## `once`. Valores admitidos: `allowed` de eco_line en data/world1_objects.json.
class_name EcoLine
extends Area2D

const GROUP: StringName = &"eco_line"

## Se ha disparado la linea (antes de que el cuadro la muestre).
signal triggered(text: String)

@export var object_id: StringName = &""
@export_multiline var text: String = ""
@export_range(1, 64) var width_tiles: int = 1
@export_range(1, 64) var height_tiles: int = 4
## Tiempo minimo en pantalla del texto completo (s); el cuadro alarga los textos largos.
@export var duration_s: float = 4.0
@export var once: bool = true
## Senal de EventBus que dispara la linea en vez de la zona (vacio = zona).
@export var trigger_event: StringName = &""
## Linea importante: pausa el juego y espera confirmacion del jugador.
@export var important: bool = false

var _fired_count: int = 0
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	if trigger_event != &"":
		_connect_event()
		return
	_build()
	body_entered.connect(_on_body_entered)


## Dispara la linea (zona o senal), respetando `once`. Verdadero si se mostro.
func fire() -> bool:
	if once and _fired_count > 0:
		return false
	_fired_count += 1
	triggered.emit(text)
	EventBus.eco_line_requested.emit(text, duration_s, important)
	return true


func _connect_event() -> void:
	monitoring = false
	monitorable = false
	for info: Dictionary in EventBus.get_signal_list():
		if StringName(info["name"]) == trigger_event:
			var args: int = (info["args"] as Array).size()
			EventBus.connect(trigger_event, fire.unbind(args) if args > 0 else fire)
			return
	push_warning("EcoLine %s: EventBus no tiene la senal '%s'" % [object_id, trigger_event])


func get_fired_count() -> int:
	return _fired_count


func has_fired() -> bool:
	return _fired_count > 0


## Zona de disparo en coordenadas locales (px).
func get_zone_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	return Rect2(Vector2.ZERO, Vector2(width_tiles * t, height_tiles * t))


func _build() -> void:
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var zone: Rect2 = get_zone_rect()
	rect.size = zone.size
	_shape.shape = rect
	_shape.position = zone.get_center()
	add_child(_shape)


func _on_body_entered(body: Node2D) -> void:
	if not body is Isak:
		return
	if fire() and once:
		set_deferred(&"monitoring", false)
