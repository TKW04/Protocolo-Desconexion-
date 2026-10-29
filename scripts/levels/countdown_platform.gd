## Cuenta regresiva «¡Solo por hoy!» (tipo `countdown_platform` del catalogo del Mundo 5;
## 2026-10-29, paso 5 de docs/propuesta-mundo-5.md §8 y §3.7; patron 28 «Falsa
## urgencia»). Plataforma SOLIDA de width_tiles x 1 (la tarjeta, card_height_px arriba
## de su celda) con un cartel de cuenta (count_s, 5 -> 0 s del mundo):
## - Cuenta: solida. Los ultimos warn_frames cuadros a anim_fps (9 a 12 fps) PARPADEA.
## - A 0 SE PLIEGA fold_s (1 s; sin colision: Isak cae, sin dano) y VUELVE con otra
##   cuenta («¡Ultimas horas!»). La urgencia es falsa: siempre vuelve.
## - No se materializa con Isak dentro (la regla de BlinkPlatform): espera a que salga.
## - «Tercer ciclo» (secreto B del 5-1): si Isak ESPERA cerca (a watch_radius_tiles)
##   truth_cycle - 1 cuentas seguidas sin usarla (sin ponerse encima), la siguiente es la
##   de verdad: «Vale, esta vez es verdad» y se queda truth_s (10 s). Una vez por intento.
## - trigger: id de un atajo con trampa countdown (ShortcutDoor): hasta que salte la
##   trampa la plataforma espera solida y sin cuenta; al saltar, start(). Sin trigger
##   cuenta desde el principio.
## Tiempo del mundo (el Debug lo ralentiza). El origen es la esquina superior izquierda
## de su primera celda. Aspecto PROVISIONAL por codigo (seccion countdown_platform de
## data/world5_objects.json).
class_name CountdownPlatform
extends StaticBody2D

const GROUP: StringName = &"countdown_platform"
const LAYER_WORLD: int = 1
const STATE_WAITING: StringName = &"waiting"
const STATE_COUNTING: StringName = &"counting"
const STATE_TRUTH: StringName = &"truth"
const STATE_FOLDED: StringName = &"folded"
const SEG_COUNT: int = 5

## Empieza una cuenta (`cycle` 1, 2...; `truth` = la de verdad).
signal count_started(cycle: int, truth: bool)
## Empieza el parpadeo de aviso antes de plegarse.
signal warning_started
## Se pliega (deja de ser solida).
signal folded
## Vuelve (se vuelve solida).
signal unfolded
## Cada segundo entero de la cuenta (sfx_w5_countdown, accesibilidad; paso 20).
signal second_ticked(seconds_left: int)

@export var object_id: StringName = &""
@export_range(1, 3) var width_tiles: int = 2
## Segundos de cada cuenta (<= 0: count_s de la seccion).
@export var count_s: float = 0.0
## Id del atajo con trampa countdown que la pone en marcha ("" = cuenta desde el principio).
@export var trigger_id: StringName = &""
## Cuentas seguidas que hay que esperar para la de verdad (0 = sin «tercer ciclo»).
@export var truth_cycle: int = 3
## De una via (como las '-'); false = solida.
@export var one_way: bool = false

var _cfg: Dictionary = {}
var _state: StringName = STATE_COUNTING
var _left: float = 0.0
var _cycle: int = 0
var _unused_streak: int = 0
var _used: bool = false
var _truth_done: bool = false
var _warned: bool = false
var _last_second: int = -1
var _time: float = 0.0
var _shape: CollisionShape2D
var _isak: Isak


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("countdown_platform")
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	var size: Vector2 = get_card_size()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	_shape.one_way_collision = one_way
	add_child(_shape)
	if trigger_id != &"":
		_state = STATE_WAITING
	else:
		_begin_count()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_solid() -> bool:
	return _state != STATE_FOLDED


func is_waiting() -> bool:
	return _state == STATE_WAITING


func is_truth() -> bool:
	return _state == STATE_TRUTH


## Numero de la cuenta actual (1 la primera; 0 esperando el trigger).
func get_cycle() -> int:
	return _cycle


## Segundos (tiempo del mundo) que le quedan a la cuenta (0 plegada o esperando).
func get_time_left() -> float:
	return _left if _state == STATE_COUNTING or _state == STATE_TRUTH else 0.0


## Segundos que le quedan plegada (0 si no lo esta; si espera a que Isak salga, 0).
func get_fold_left() -> float:
	return maxf(_left, 0.0) if _state == STATE_FOLDED else 0.0


func get_count_s() -> float:
	return count_s if count_s > 0.0 else float(_cfg.get("count_s", 5.0))


func get_fold_s() -> float:
	return float(_cfg.get("fold_s", 1.0))


func get_truth_s() -> float:
	return float(_cfg.get("truth_s", 10.0))


## Aviso: warn_frames cuadros a anim_fps (s de tiempo del mundo).
func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)


func is_warning() -> bool:
	return (_state == STATE_COUNTING or _state == STATE_TRUTH) and _left <= get_warn_s()


## Texto del cartel: «¡Solo por hoy!» (primera), «¡Ultimas horas!» (las demas) o
## «Vale, esta vez es verdad» (la de verdad); vacio esperando el trigger.
func get_sign_text() -> String:
	if _state == STATE_WAITING:
		return ""
	if _state == STATE_TRUTH:
		return String(_cfg.get("text_truth", "Vale, esta vez es verdad"))
	if _cycle <= 1:
		return String(_cfg.get("text_first", "¡Solo por hoy!"))
	return String(_cfg.get("text_again", "¡Últimas horas!"))


## Segmentos encendidos de la cuenta (SEG_COUNT llena).
func get_lit_segments() -> int:
	if _state == STATE_WAITING:
		return SEG_COUNT
	if _state == STATE_FOLDED:
		return 0
	var total: float = get_truth_s() if _state == STATE_TRUTH else get_count_s()
	return clampi(ceili(SEG_COUNT * _left / maxf(total, 0.001) - 0.0001), 0, SEG_COUNT)


func get_card_size() -> Vector2:
	return Vector2(width_tiles * World5ObjectsConfig.tile_size(), float(_cfg.get("card_height_px", 32)))


func get_card_rect() -> Rect2:
	return Rect2(global_position, get_card_size())


## Cuentas seguidas que Isak ha esperado cerca sin usarla.
func get_unused_streak() -> int:
	return _unused_streak


func is_help_available() -> bool:
	return true


# --- Acciones ---

## La pone en marcha (trampa countdown de un atajo). Sin efecto si ya contaba.
func start() -> void:
	if _state != STATE_WAITING:
		return
	_begin_count()


## Avanza `dt` segundos de tiempo del mundo (publico para las pruebas).
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	match _state:
		STATE_COUNTING, STATE_TRUTH:
			if _isak_on_top():
				_used = true
			_left -= dt
			var sec: int = ceili(_left - 0.0001)
			if sec != _last_second and sec >= 0:
				_last_second = sec
				second_ticked.emit(sec)
			if is_warning() and not _warned:
				_warned = true
				warning_started.emit()
			if _left <= 0.0:
				_end_count()
		STATE_FOLDED:
			_left -= dt
			if _left <= 0.0 and not _isak_overlaps():
				_set_solid(true)
				unfolded.emit()
				_begin_count()
	queue_redraw()


# --- Interno ---

func _begin_count() -> void:
	_cycle += 1
	_used = false
	_warned = false
	var truth: bool = truth_cycle > 1 and not _truth_done and _unused_streak >= truth_cycle - 1
	if truth:
		_truth_done = true
		_state = STATE_TRUTH
		_left = get_truth_s()
	else:
		_state = STATE_COUNTING
		_left = get_count_s()
	_last_second = ceili(_left - 0.0001)
	_set_solid(true)
	count_started.emit(_cycle, truth)


func _end_count() -> void:
	if not _used and _isak_watching():
		_unused_streak += 1
	else:
		_unused_streak = 0
	_state = STATE_FOLDED
	_left = get_fold_s()
	_set_solid(false)
	folded.emit()


func _set_solid(on: bool) -> void:
	if _shape != null:
		_shape.disabled = not on


func _find_isak() -> Isak:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	return _isak


func _isak_overlaps() -> bool:
	var isak: Isak = _find_isak()
	if isak == null:
		return false
	return LevelLookup.isak_body_rect(isak).intersects(get_card_rect())


## Isak de pie sobre la tarjeta (la usa).
func _isak_on_top() -> bool:
	var isak: Isak = _find_isak()
	if isak == null or isak.is_dead():
		return false
	var r: Rect2 = get_card_rect()
	var feet: Vector2 = isak.global_position
	var half: float = isak.get_hitbox_size().x * 0.5
	return absf(feet.y - r.position.y) <= float(_cfg.get("on_top_tolerance_px", 6.0)) \
		and feet.x + half > r.position.x and feet.x - half < r.end.x


## Isak espera cerca (a watch_radius_tiles en horizontal del centro de la tarjeta).
func _isak_watching() -> bool:
	var isak: Isak = _find_isak()
	if isak == null or isak.is_dead():
		return false
	var r: Rect2 = get_card_rect()
	return absf(isak.global_position.x - r.get_center().x) <= float(_cfg.get("watch_radius_tiles", 6.0)) * World5ObjectsConfig.tile_size()


# --- Dibujo ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var size: Vector2 = get_card_size()
	var card := Rect2(Vector2.ZERO, size)
	var ink: Color = _c("ink", "negro_medio")
	var yellow: Color = _c("card", "amarillo_rebajas")
	var font: Font = ThemeDB.fallback_font
	if _state == STATE_FOLDED:
		# Plegada: contorno discontinuo.
		var grey: Color = _c("off", "gris_etiqueta")
		var x: float = 0.0
		while x < size.x:
			draw_line(Vector2(x, 0.0), Vector2(minf(x + 8.0, size.x), 0.0), grey, 2.0)
			draw_line(Vector2(x, size.y), Vector2(minf(x + 8.0, size.x), size.y), grey, 2.0)
			x += 16.0
	else:
		var blink: bool = is_warning() and int(floor(_left * float(_cfg.get("anim_fps", 12.0)))) % 2 == 1
		draw_rect(card, ink)
		draw_rect(card.grow(-2.0), _c("off", "gris_etiqueta") if blink else yellow)
		# Segmentos de la cuenta.
		var lit: int = get_lit_segments()
		var seg_w: float = (size.x - 8.0) / float(SEG_COUNT)
		for i: int in SEG_COUNT:
			var seg := Rect2(Vector2(4.0 + i * seg_w + 1.0, size.y - 8.0), Vector2(seg_w - 2.0, 4.0))
			draw_rect(seg, _c("seg", "magenta_neon") if i < lit else ink)
		if _state != STATE_WAITING:
			draw_string(font, Vector2(0.0, size.y - 11.0), str(maxi(ceili(_left - 0.0001), 0)), HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 14, ink)
	var text: String = get_sign_text()
	if not text.is_empty():
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		var plate := Rect2(Vector2(size.x * 0.5 - w * 0.5, -22.0), Vector2(w, 18.0))
		draw_rect(plate, ink)
		draw_rect(plate, _c("seg", "magenta_neon"), false, 1.0)
		draw_string(font, Vector2(plate.position.x, plate.end.y - 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 12,
			_c("text", "crema_cartel"))
