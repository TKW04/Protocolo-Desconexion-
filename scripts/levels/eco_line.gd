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
## Pausa de inicio (2026-10-15): si Isak entra en la zona mientras su llegada aun
## no se ve (Isak.is_warp_hidden(): fundido de entrada o vortice de llegada), la
## linea espera a Isak.warp_revealed y sale entonces si Isak sigue en la zona.
## Asi una linea importante (la bienvenida del 1-1) no pausa el juego con la
## pantalla todavia en negro: el nivel ya se ve cuando aparece el mensaje.
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
## Linea de historia ligada a una habilidad (2026-10-16; p. ej. eco_laser con
## &"laser"): si al empezar el nivel Isak ya la tiene (obtenida o desbloqueada),
## la linea no sale (como el objeto que la da, que tampoco aparece). Vacio:
## sale siempre (segun `once`).
@export var unless_ability: StringName = &""

var _fired_count: int = 0
var _skipped: bool = false
var _shape: CollisionShape2D
## Isak entro en la zona durante una llegada oculta: se espera a que se vea.
var _waiting_isak: Isak


func _ready() -> void:
	add_to_group(GROUP)
	if _owns_linked_ability():
		# Isak ya tenia la habilidad al empezar: inerte (sin zona ni senal).
		_skipped = true
		monitoring = false
		monitorable = false
		return
	if trigger_event != &"":
		_connect_event()
		return
	_build()
	body_entered.connect(_on_body_entered)


## Dispara la linea (zona o senal), respetando `once`. Verdadero si se mostro.
func fire() -> bool:
	if _skipped or (once and _fired_count > 0):
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


## La linea no sale en este nivel: Isak ya tenia `unless_ability` al empezar.
func is_skipped() -> bool:
	return _skipped


func _owns_linked_ability() -> bool:
	return unless_ability != &"" and (GameState.is_ability_obtained(unless_ability)
		or GameState.is_ability_unlocked(unless_ability))


func get_fired_count() -> int:
	return _fired_count


func has_fired() -> bool:
	return _fired_count > 0


## La linea espera a que se vea la llegada de Isak para salir.
func is_waiting_for_reveal() -> bool:
	return _waiting_isak != null and is_instance_valid(_waiting_isak)


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
	var isak := body as Isak
	if isak == null:
		return
	if isak.is_warp_hidden():
		_wait_for_reveal(isak)
		return
	_fire_from_zone()


func _fire_from_zone() -> void:
	if fire() and once:
		set_deferred(&"monitoring", false)


func _wait_for_reveal(isak: Isak) -> void:
	if _waiting_isak == isak:
		return
	_waiting_isak = isak
	isak.warp_revealed.connect(_on_isak_revealed, CONNECT_ONE_SHOT)


func _on_isak_revealed() -> void:
	var isak: Isak = _waiting_isak
	_waiting_isak = null
	if is_instance_valid(isak) and monitoring and overlaps_body(isak):
		_fire_from_zone()
