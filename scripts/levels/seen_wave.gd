## Ola de «Visto» (tipo `seen_wave` del catalogo del Mundo 4; 2026-10-28, paso 7 de
## docs/propuesta-mundo-4.md §8, §3.5 y decision 4 de §9; patron 22 de §3.8): un
## FRENTE vertical de toda la altura del nivel que avanza desde la izquierda en
## tiempo del mundo (el Debug la frena) y deja detras el nivel en gris con
## «Leido 03:47». Una por nivel. Estados:
##   - WAITING: quieta en su columna inicial hasta que Isak cruza start_col.
##   - MOVING: avanza a la velocidad de la seccion en la que esta el frente
##     (`sections`: {x_from, x_to, speed_tiles_s[, speed_to_tiles_s]}; con
##     speed_to acelera de una a otra a lo largo de la seccion; fuera de toda
##     seccion, default_speed_tiles_s).
##   - STOPPED: parada (`stops`: {id, at_col, resume_col}); el frente se queda en
##     at_col hasta que Isak cruza resume_col (sale de la parada). Cada parada se
##     usa una vez por recorrido.
##   - HOLDING: alcanzo a Isak: -edge_damage de Sync SIN MATAR (nunca baja de 1) y
##     Isak congelado freeze_s (Isak.freeze, FREEZE_SOURCE_WAVE); el frente espera.
##     Al descongelarse SOLO retrocede retreat_tiles (4) desde la espalda de Isak;
##     con Agitar (frozen_ended con broken) se queda a shake_gap_tiles (1).
##   - OFF: al llegar a end_col se para y se apaga para siempre.
## Si Isak muere o reaparece (EventBus.player_respawned) la ola vuelve a la parada
## de su seccion (la ultima en la que se paro; sin ninguna, a WAITING en su sitio).
## El frozen_ended que Isak emite al morir congelado se ignora (lo resuelve la
## reaparicion). Aspecto PROVISIONAL por codigo: velo gris, columna de checks que
## laten y la linea roja del frente (dana). Origen: esquina superior izquierda de
## su celda (su columna es la del frente al empezar).
class_name SeenWave
extends Node2D

const GROUP: StringName = &"seen_wave"

enum State { WAITING, MOVING, STOPPED, HOLDING, OFF }

signal state_changed(state: State)
## Alcanzo a Isak (danado: si quito Sync).
signal caught_isak(damaged: bool)
## Isak se descongelo: `broken` = con Agitar; el frente queda en front_x.
signal released(broken: bool, front_x: float)
signal stopped_at(stop_id: StringName)
signal resumed(stop_id: StringName)

@export var object_id: StringName = &""
## Isak la pone en marcha al cruzar esta columna.
@export var start_col: int = 20
## Columna donde se para y se apaga (-1 = nunca).
@export var end_col: int = -1
@export var default_speed_tiles_s: float = 1.0
## Secciones de velocidad por la columna del frente.
@export var sections: Array = []
## Paradas: {id, at_col, resume_col}.
@export var stops: Array = []
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true
## Isak al que alcanza (si es null se busca con LevelLookup).
var isak: Isak
## Alto del frente (px); 0 = el del nivel (GeneratedLevel.get_size_px).
var height_px: float = 0.0

var _cfg: Dictionary = World4ObjectsConfig.section("seen_wave")
## Rotulo del frente: tamaño y margen sobre el borde de abajo de la vista (px).
const LABEL_FONT_PX: int = 16
const LABEL_MARGIN_PX: float = 120.0
var _font: Font
var _state: State = State.WAITING
var _front_x: float = 0.0
var _stop_idx: int = -1
var _used_stops: Dictionary = {}
var _state_before_hold: State = State.MOVING
var _thaw_pending: int = 0
var _connected: Isak
var _anim_t: float = 0.0

const THAW_NONE: int = 0
const THAW_SOLO: int = 1
const THAW_SHAKE: int = 2


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.player_respawned.connect(_on_player_respawned)
	z_index = int(_cfg.get("z_index", 30))
	reset()


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Estado inicial del nivel: en su columna, esperando a Isak.
func reset() -> void:
	_front_x = global_position.x
	_stop_idx = -1
	_used_stops.clear()
	_thaw_pending = THAW_NONE
	_set_state(State.WAITING)
	queue_redraw()


## Avanza `dt` segundos de tiempo del mundo. Publico para las pruebas.
func advance(dt: float) -> void:
	_anim_t += dt
	var target: Isak = _find_isak()
	_connect(target)
	if _thaw_pending != THAW_NONE:
		_resolve_thaw(target)
	match _state:
		State.WAITING:
			if target != null and not target.is_dead() and target.global_position.x > _col_x(start_col):
				_set_state(State.MOVING)
		State.MOVING:
			_move(dt)
		State.STOPPED:
			var stop: Dictionary = stops[_stop_idx]
			if target != null and not target.is_dead() \
					and target.global_position.x > _col_x(int(stop.get("resume_col", 0))):
				_set_state(State.MOVING)
				resumed.emit(StringName(String(stop.get("id", ""))))
	if _state in [State.WAITING, State.MOVING, State.STOPPED]:
		_check_contact(target)
	queue_redraw()


# --- Consultas ---

func get_state() -> State:
	return _state


func get_front_x() -> float:
	return _front_x


func set_front_x(x: float) -> void:
	_front_x = x
	queue_redraw()


func is_off() -> bool:
	return _state == State.OFF


## Velocidad (tiles/s) para el frente en la columna `col` (float).
func speed_at(col: float) -> float:
	for raw: Variant in sections:
		if not raw is Dictionary:
			continue
		var s: Dictionary = raw
		var a: float = float(s.get("x_from", 0))
		var b: float = float(s.get("x_to", 0))
		if col >= a and col < b:
			var v0: float = float(s.get("speed_tiles_s", default_speed_tiles_s))
			if s.has("speed_to_tiles_s") and b > a:
				return lerpf(v0, float(s["speed_to_tiles_s"]), clampf((col - a) / (b - a), 0.0, 1.0))
			return v0
	return default_speed_tiles_s


## Parada en la que esta (o la ultima en la que se paro); &"" sin ninguna.
func get_stop_id() -> StringName:
	if _stop_idx < 0 or _stop_idx >= stops.size():
		return &""
	return StringName(String((stops[_stop_idx] as Dictionary).get("id", "")))


func get_freeze_s() -> float:
	return float(_cfg.get("freeze_s", 2.0))


func get_damage() -> float:
	return float(_cfg.get("edge_damage", 10.0))


func get_retreat_tiles() -> float:
	return float(_cfg.get("retreat_tiles", 4.0))


func get_shake_gap_tiles() -> float:
	return float(_cfg.get("shake_gap_tiles", 1.0))


## Distancia (px) del frente a la espalda de Isak (negativa si lo alcanza).
func distance_to_isak() -> float:
	var target: Isak = _find_isak()
	if target == null:
		return INF
	return LevelLookup.isak_body_rect(target).position.x - _front_x


# --- Interno ---

func _tile() -> float:
	return World4ObjectsConfig.tile_size()


func _col_x(col: int) -> float:
	var level_x: float = global_position.x - float(_own_col()) * _tile()
	return level_x + float(col) * _tile()


## Columna de su celda (origen en el nivel: el nivel generado empieza en x = 0).
func _own_col() -> int:
	return int(round(position.x / _tile()))


func _move(dt: float) -> void:
	var col: float = (_front_x - _col_x(0)) / _tile()
	_front_x += speed_at(col) * _tile() * dt
	for i: int in stops.size():
		if _used_stops.has(i) or not stops[i] is Dictionary:
			continue
		var at: float = _col_x(int((stops[i] as Dictionary).get("at_col", 0)))
		if _front_x >= at:
			_front_x = at
			_used_stops[i] = true
			_stop_idx = i
			_set_state(State.STOPPED)
			stopped_at.emit(get_stop_id())
			return
	if end_col >= 0 and _front_x >= _col_x(end_col):
		_front_x = _col_x(end_col)
		_set_state(State.OFF)


func _check_contact(target: Isak) -> void:
	if target == null or target.is_dead():
		return
	if LevelLookup.isak_body_rect(target).position.x > _front_x:
		return
	var damaged: bool = not target.is_invulnerable()
	if damaged:
		# Sin matar: nunca baja de 1 (decision 4 de §9).
		GameState.apply_sync_damage(minf(get_damage(), maxf(GameState.sync_rate - 1.0, 0.0)))
	_state_before_hold = State.STOPPED if _state == State.STOPPED else State.MOVING
	var frozen_now: bool = target.freeze(get_freeze_s(), Isak.FREEZE_SOURCE_WAVE) or target.is_frozen()
	caught_isak.emit(damaged)
	if frozen_now:
		_thaw_pending = THAW_NONE
		_set_state(State.HOLDING)
	else:
		# No se pudo congelar (de espaldas, en un vortice): retrocede como al descongelarse.
		_retreat(target, get_retreat_tiles())


func _resolve_thaw(target: Isak) -> void:
	var pending: int = _thaw_pending
	_thaw_pending = THAW_NONE
	if _state != State.HOLDING or target == null or target.is_dead():
		# Al morir congelado: lo resuelve la reaparicion (vuelta a la parada).
		return
	var broken: bool = pending == THAW_SHAKE
	_retreat(target, get_shake_gap_tiles() if broken else get_retreat_tiles())
	_set_state(_state_before_hold)
	released.emit(broken, _front_x)


func _retreat(target: Isak, tiles: float) -> void:
	_front_x = LevelLookup.isak_body_rect(target).position.x - tiles * _tile()


func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	state_changed.emit(next)


func _find_isak() -> Isak:
	if isak == null or not is_instance_valid(isak) or not isak.is_inside_tree():
		isak = LevelLookup.find_isak(self)
	return isak


func _connect(target: Isak) -> void:
	if target == _connected:
		return
	if _connected != null and is_instance_valid(_connected) and _connected.frozen_ended.is_connected(_on_frozen_ended):
		_connected.frozen_ended.disconnect(_on_frozen_ended)
	_connected = target
	if target != null:
		target.frozen_ended.connect(_on_frozen_ended)


func _on_frozen_ended(broken: bool) -> void:
	if _state == State.HOLDING:
		_thaw_pending = THAW_SHAKE if broken else THAW_SOLO


## Muerte o reaparicion: a la parada de su seccion (o a esperar en su sitio).
func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	_thaw_pending = THAW_NONE
	if _state == State.OFF:
		return
	if _stop_idx < 0:
		_front_x = global_position.x
		_set_state(State.WAITING)
	else:
		_front_x = _col_x(int((stops[_stop_idx] as Dictionary).get("at_col", 0)))
		_set_state(State.STOPPED)
	queue_redraw()


# --- Dibujo ---

func _level_height() -> float:
	if height_px > 0.0:
		return height_px
	var node: Node = get_parent()
	while node != null:
		if node.has_method(&"get_size_px"):
			return float((node.call(&"get_size_px") as Vector2i).y)
		node = node.get_parent()
	return 14.0 * _tile()


func _draw() -> void:
	var h: float = _level_height()
	var top: float = -global_position.y
	var front: float = _front_x - global_position.x
	var left: float = _col_x(0) - global_position.x
	var alpha: float = 1.0
	if _state == State.OFF:
		alpha = 0.35
	var gray: Color = World4ObjectsConfig.color("gris_oscuro", Color("#3a3f4c"))
	if front > left:
		draw_rect(Rect2(Vector2(left, top), Vector2(front - left, h)), Color(gray, float(_cfg.get("veil_alpha", 0.45)) * alpha))
	if _state == State.OFF:
		return
	var green: Color = World4ObjectsConfig.color("verde_apagado", Color("#7d9a80"))
	var cream: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var red: Color = World4ObjectsConfig.color("alerta", Color("#e8473c"))
	draw_line(Vector2(front, top), Vector2(front, top + h), red, 2.0)
	var beat: float = 0.5 + 0.5 * sin(_anim_t * TAU * float(_cfg.get("beat_hz", 2.0)))
	var step_px: float = _tile()
	var y: float = top + step_px * 0.5
	while y < top + h:
		var c := Vector2(front - 14.0, y)
		var col := Color(green, 0.55 + 0.45 * beat)
		draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-4, 5), c + Vector2(3, -6)]), col, 2.0)
		draw_polyline(PackedVector2Array([c + Vector2(-2, 0), c + Vector2(2, 5), c + Vector2(9, -6)]), col, 2.0)
		y += step_px
	var label: String = String(_cfg.get("label", "Leído 03:47"))
	var font: Font = _label_font()
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_PX).x
	var view: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var at: Vector2 = label_position(view, width) - global_position
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_PX, Color(cream, 0.8))


## Donde se escribe el rotulo «Leído 03:47» (global, linea base): a la izquierda
## del frente y dentro de la vista, sobre su borde de abajo; si a la izquierda no
## cabe (frente pegado al borde de la pantalla), a la derecha del frente.
## (2026-10-28, paso 22: en las capturas salia al pie del nivel, fuera de la
## vista, y cortado por el borde izquierdo.)
func label_position(view: Rect2, width: float) -> Vector2:
	var y: float = clampf(view.end.y - LABEL_MARGIN_PX, view.position.y + LABEL_MARGIN_PX, view.end.y)
	var x: float = _front_x - width - 24.0
	if x < view.position.x + 8.0:
		x = _front_x + 12.0
	return Vector2(x, y)


func _label_font() -> Font:
	if _font == null:
		var path: String = String(World4ObjectsConfig.section("chat_bubble").get("font", "res://assets/sprites/ui/text_font.fnt"))
		_font = load(path) as Font if ResourceLoader.exists(path) else null
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font
