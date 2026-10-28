## Burbuja «Escribiendo…» (tipo `typing_bubble` del catalogo del Mundo 4; 2026-10-28,
## paso 3 de docs/propuesta-mundo-4.md §8, §3.4 y patron 18 de §3.8): una burbuja de
## chat (ChatBubble) que AUN NO EXISTE. Al dispararse (`trigger`: Isak pisa la burbuja
## con ese id; o `trigger_zone` [x, y, ancho, alto] en celdas: Isak entra en ella)
## salen TRES PUNTOS en su sitio, uno cada dot_s (0,33 s), y al cumplirse type_s
## (1,0 s) la burbuja aparece SOLIDA. Los puntos son el aviso (sfx_w4_typing desde el
## paso 20). No se materializa con Isak dentro (espera a que salga).
## - `stay_forever` (por defecto): se queda para siempre.
## - Ciclo (`cycle_s` y `on_s`): aparece, se queda on_s, pasa a «Se elimino este
##   mensaje» con un aviso de warn_frames cuadros a anim_fps (parpadea) y sin colision,
##   y vuelve a escribirse (puntos y type_s) para estar solida otra vez al cumplirse
##   cycle_s desde que aparecio.
## Una vez disparada no se desdispara; vuelve al estado inicial al reaparecer Isak.
## Tiempo del mundo (el Debug alarga la espera). Patron del mundo: saltar con el
## SEGUNDO punto para caer sobre la burbuja recien aparecida.
class_name TypingBubble
extends ChatBubble

enum Phase { IDLE, TYPING, SOLID, DELETING, DELETED }

## Empiezan los puntos.
signal typing_started
## Aparece solida.
signal appeared
## Pasa a «Se elimino este mensaje».
signal vanished

## Id de la burbuja que la dispara al pisarla (&"" = sin burbuja).
@export var trigger_id: StringName = &""
## Zona que la dispara al entrar Isak: [x, y, ancho, alto] en celdas del nivel
## ([] = sin zona).
@export var trigger_zone: Array = []
## Ciclo: periodo desde que aparece hasta que vuelve a aparecer (0 = se queda).
@export var cycle_s: float = 0.0
## Ciclo: tiempo solida antes del aviso de eliminarse.
@export var on_s: float = 0.0
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true

var _phase: Phase = Phase.IDLE
var _t: float = 0.0
var _trigger_bubble: ChatBubble


func _ready() -> void:
	super._ready()
	EventBus.player_respawned.connect(_on_player_respawned)
	reset()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Vuelve al estado inicial (sin disparar).
func reset() -> void:
	_phase = Phase.IDLE
	_t = 0.0
	deleted = false
	_set_solid(false)


## Avanza `dt` segundos de tiempo del mundo. Publico para las pruebas.
func advance(dt: float) -> void:
	if _phase == Phase.IDLE:
		if _should_trigger():
			trigger()
		return
	_t += dt
	match _phase:
		Phase.TYPING:
			if _t >= get_type_s() and not _isak_overlaps():
				_appear()
		Phase.SOLID:
			if has_cycle() and _t >= on_s:
				_phase = Phase.DELETING
				_t = 0.0
		Phase.DELETING:
			if _t >= get_warn_s():
				_phase = Phase.DELETED
				_t = 0.0
				deleted = true
				_set_solid(false)
				vanished.emit()
		Phase.DELETED:
			if _t >= get_deleted_s():
				deleted = false
				_start_typing()
	queue_redraw()


## Dispara los puntos (sin pisar: pruebas). No hace nada si ya estaba disparada.
func trigger() -> void:
	if _phase != Phase.IDLE:
		return
	_start_typing()


# --- Consultas ---

## Zona de disparo (global en el nivel: celdas por tile; Rect2() sin zona).
func get_trigger_rect() -> Rect2:
	if trigger_zone.size() != 4:
		return Rect2()
	var t: float = World4ObjectsConfig.tile_size()
	return Rect2(float(trigger_zone[0]) * t, float(trigger_zone[1]) * t,
		float(trigger_zone[2]) * t, float(trigger_zone[3]) * t)


func get_phase() -> Phase:
	return _phase


func is_triggered() -> bool:
	return _phase != Phase.IDLE


func is_typing() -> bool:
	return _phase == Phase.TYPING


## Ayuda de Eco: antes de dispararse no existe (no hay nada que explicar todavia).
func is_help_available() -> bool:
	return is_triggered() and super.is_help_available()


## Puntos que se ven (0-3): uno cada dot_s mientras escribe.
func get_dots() -> int:
	if _phase != Phase.TYPING:
		return 0
	return clampi(1 + floori(_t / maxf(get_dot_s(), 0.001)), 1, 3)


func has_cycle() -> bool:
	return cycle_s > 0.0 and on_s > 0.0


func get_type_s() -> float:
	return float(_cfg.get("type_s", 1.0))


func get_dot_s() -> float:
	return float(_cfg.get("dot_s", 0.33))


func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 0.01)


## Tiempo eliminada (sin colision) antes de volver a escribirse.
func get_deleted_s() -> float:
	return maxf(cycle_s - on_s - get_warn_s() - get_type_s(), 0.0)


## En el aviso de eliminarse (parpadea).
func is_warning() -> bool:
	return _phase == Phase.DELETING


## Tiempo (del mundo) que lleva en su fase.
func get_phase_time() -> float:
	return _t


# --- Interno ---

func _initial_solid() -> bool:
	return false


func _start_typing() -> void:
	_phase = Phase.TYPING
	_t = 0.0
	_set_solid(false)
	typing_started.emit()


func _appear() -> void:
	_phase = Phase.SOLID
	_t = 0.0
	_set_solid(true)
	appeared.emit()


func _should_trigger() -> bool:
	if trigger_id != &"":
		var bubble: ChatBubble = _get_trigger_bubble()
		if bubble != null and bubble.is_stepped_on():
			return true
	if trigger_zone.size() == 4:
		var isak: Isak = _find_isak()
		if isak != null and not isak.is_dead():
			if get_trigger_rect().intersects(LevelLookup.isak_body_rect(isak)):
				return true
	return false


func _get_trigger_bubble() -> ChatBubble:
	if _trigger_bubble != null and is_instance_valid(_trigger_bubble):
		return _trigger_bubble
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(ChatBubble.GROUP):
		var bubble := node as ChatBubble
		if bubble != null and bubble != self and bubble.object_id == trigger_id:
			_trigger_bubble = bubble
			return bubble
	return null


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


func _draw() -> void:
	match _phase:
		Phase.IDLE:
			return
		Phase.TYPING:
			_draw_dots()
		Phase.SOLID:
			draw_bubble(text, true, 1.0)
		Phase.DELETING:
			var fps: float = maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)
			var on: bool = int(floor(_t * fps)) % 2 == 0
			draw_bubble(text, true, 1.0 if on else 0.45)
		Phase.DELETED:
			draw_bubble(ChatBubble.DELETED_TEXT, false, 1.0)


## En la oscuridad los puntos se ven siempre (son luz) y el borde al 30 %.
func draw_dark_overlay(canvas: CanvasItem) -> void:
	if _phase == Phase.TYPING:
		_draw_dots(canvas)
	else:
		super.draw_dark_overlay(canvas)


## Burbuja pequena con contorno y los puntos crema (nunca cian: los de Eco son cian).
func _draw_dots(canvas: CanvasItem = self) -> void:
	var cream: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var back: Color = World4ObjectsConfig.color("gris_oscuro", Color("#3c4250"))
	var shade: Color = World4ObjectsConfig.color("crema_sombra", Color("#b8ad94"))
	var h: float = get_card_height()
	var w: float = minf(get_card_size().x, float(_cfg.get("typing_width_px", 64)))
	var x0: float = 0.0 if author_side == &"left" else get_card_size().x - w
	var rect := Rect2(Vector2(x0, 0.0), Vector2(w, h))
	canvas.draw_rect(rect, back)
	canvas.draw_rect(rect, shade, false, 2.0)
	var r: float = float(_cfg.get("dot_radius_px", 4))
	for i: int in get_dots():
		canvas.draw_circle(rect.position + Vector2(w * (0.25 + 0.25 * float(i)), h * 0.5), r, cream)
