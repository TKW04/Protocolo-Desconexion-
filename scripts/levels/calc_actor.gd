## Calc en el nivel (tipo `calc_actor`; encuentro con Calc en la azotea del 1-2,
## 2026-10-17, tanda H1 del paso 14; docs/propuesta-calc-encuentro.md; seccion
## calc_actor de data/world1_objects.json; arte de tools/gen_calc_encounter.py).
## 1. OFF (calc_low): apagada, con el 3 % de bateria parpadeando, en la primera
##    celda de path_cells (los pies abajo-centro de la celda).
## 2. Cuando el ChargeDock con id == dock_id se arma: WAKE (calc_wake), WALK
##    (calc_walk) por los puntos de path_cells (el ultimo es el sitio de los
##    pies del dock: ChargeDock.get_calc_feet) a walk_speed_px_s.
## 3. CHARGING (calc_charging): el dock la carga (set_battery) hasta el 100 %.
## 4. CHARGED (calc_charged, cara despierta) charged_hold_s y TELEPORT: los
##    anillos del vortice de Isak (warp_frames) se abren alrededor de ella
##    mientras se desvanece (calc_teleport) y se cierran.
## 5. GONE: oculta; emite teleported y EventBus.ally_teleported("calc") y el
##    dock tiene corriente (ChargeDock.finish). NO llama a GameState.meet_ally:
##    Calc se da por conocida al encontrarla en el hub (tanda H3).
## Sin colision ni Q (es historia). Con done_if_ally conocido al cargar, no
## esta (GONE). Tiempo del mundo (el Debug la ralentiza; la pausa la para).
class_name CalcActor
extends Node2D

enum State { OFF, WAKE, WALK, CHARGING, CHARGED, TELEPORT, GONE }

const GROUP: StringName = &"calc_actor"
const ALLY: StringName = &"calc"

signal state_changed(state: State)
## Se fue al hub por el vortice.
signal teleported

@export var object_id: StringName = &""
@export var dock_id: StringName = &""
## Celdas [columna, fila] del recorrido (la primera, donde esta apagada).
@export var path_cells: Array = []
@export var done_if_ally: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("calc_actor")
var _state: State = State.OFF
var _time: float = 0.0
var _state_time: float = 0.0
var _battery: float = 3.0
var _points: Array[Vector2] = []
var _next: int = 1
var _feet: Vector2 = Vector2.ZERO
var _sprite: AnimatedSprite2D
var _vortex: AnimatedSprite2D
var _vortex_time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(CalcRoom.LINK_GROUP)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Calc"
	_sprite.sprite_frames = load(String(_config.get("frames", "res://assets/sprites/calc_actor_frames.tres"))) as SpriteFrames
	_sprite.animation = &"calc_low"
	add_child(_sprite)
	_vortex = AnimatedSprite2D.new()
	_vortex.name = "Vortex"
	_vortex.sprite_frames = load(String(_config.get("warp_frames", "res://assets/sprites/warp_objects_frames.tres"))) as SpriteFrames
	_vortex.animation = &"vortex_open"
	_vortex.visible = false
	_vortex.show_behind_parent = false
	add_child(_vortex)
	_battery = float(World1ObjectsConfig.section("charge_dock").get("start_percent", 3))
	var t: float = World1ObjectsConfig.tile_size()
	for cell: Variant in path_cells:
		# El generador escribe [col, fila] como Vector2.
		if cell is Vector2 or cell is Vector2i:
			_points.append(Vector2((cell.x + 0.5) * t, (cell.y + 1.0) * t))
		elif cell is Array and (cell as Array).size() >= 2:
			_points.append(Vector2((float(cell[0]) + 0.5) * t, (float(cell[1]) + 1.0) * t))
	if _points.is_empty():
		_points.append(global_position + Vector2(t * 0.5, t))
	_feet = _points[0]
	if CalcRoom.skipped_for(done_if_ally):
		_set_state(State.GONE)
	_update_visual()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


## Ya se fue al hub (pieza hecha).
func is_activated() -> bool:
	return _state == State.GONE


## Pies de Calc (global).
func get_feet() -> Vector2:
	return _feet


func get_battery() -> float:
	return _battery


func get_animation() -> StringName:
	return _sprite.animation


func is_vortex_visible() -> bool:
	return _vortex.visible


func get_dock() -> ChargeDock:
	return CalcRoom.find(self, dock_id) as ChargeDock


## Recorrido en px (pies), con el sitio del dock como ultimo punto.
func get_path_points() -> Array[Vector2]:
	return _points


func get_outline_rect() -> Rect2:
	return Rect2(_feet - Vector2(32, 96), Vector2(64, 96))


# --- Acciones (las llama el dock) ---

## Bateria que muestra el dock mientras carga.
func set_battery(percent: float) -> void:
	_battery = clampf(percent, 0.0, 100.0)


## Bateria llena: cara despierta y, tras charged_hold_s, el teletransporte.
func on_charged() -> void:
	if _state == State.CHARGING:
		_battery = 100.0
		_set_state(State.CHARGED)


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	_state_time += dt
	match _state:
		State.OFF:
			var dock: ChargeDock = get_dock()
			if dock != null and dock.is_armed():
				var feet: Vector2 = dock.get_calc_feet()
				if _points.size() < 2 or not _points[_points.size() - 1].is_equal_approx(feet):
					if _points.size() >= 2:
						_points[_points.size() - 1] = feet
					else:
						_points.append(feet)
				_set_state(State.WAKE)
		State.WAKE:
			if _state_time >= _anim_length(&"calc_wake"):
				_next = 1
				_set_state(State.WALK)
		State.WALK:
			_walk(dt)
		State.CHARGED:
			if _state_time >= float(_config.get("charged_hold_s", 0.8)):
				_vortex_time = 0.0
				_set_state(State.TELEPORT)
		State.TELEPORT:
			_vortex_time += dt
			if _vortex_time >= _vortex_length():
				_finish()
	_update_visual()


# --- Interno ---

func _walk(dt: float) -> void:
	var speed: float = float(_config.get("walk_speed_px_s", 70.0))
	var left: float = speed * dt
	while left > 0.0 and _next < _points.size():
		var target: Vector2 = _points[_next]
		var d: float = _feet.distance_to(target)
		if d <= left:
			_feet = target
			left -= d
			_next += 1
		else:
			if absf(target.x - _feet.x) > 0.01:
				_sprite.flip_h = target.x < _feet.x
			_feet = _feet.move_toward(target, left)
			left = 0.0
	if _next >= _points.size():
		_sprite.flip_h = false
		var dock: ChargeDock = get_dock()
		_set_state(State.CHARGING)
		if dock != null:
			dock.start_charging(self)


func _finish() -> void:
	_set_state(State.GONE)
	var dock: ChargeDock = get_dock()
	teleported.emit()
	EventBus.ally_teleported.emit(ALLY)
	if dock != null:
		dock.finish()


func _set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	_state_time = 0.0
	state_changed.emit(state)


func _anim_length(anim: StringName) -> float:
	var frames: SpriteFrames = _sprite.sprite_frames
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.001)


## Vortice: abrir, spins vueltas y cerrar.
func _vortex_length() -> float:
	var frames: SpriteFrames = _vortex.sprite_frames
	var total: float = 0.0
	for anim: StringName in [&"vortex_open", &"vortex_close"]:
		total += frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.001)
	var spin: float = frames.get_frame_count(&"vortex_spin") / maxf(frames.get_animation_speed(&"vortex_spin"), 0.001)
	return total + spin * maxi(int(_config.get("spins", 2)), 1)


func _update_visual() -> void:
	visible = _state != State.GONE
	_sprite.position = _feet - global_position - Vector2(0.0, 48.0)
	var anim: StringName = &"calc_low"
	var t: float = _time
	match _state:
		State.WAKE:
			anim = &"calc_wake"
			t = _state_time
		State.WALK:
			anim = &"calc_walk"
		State.CHARGING:
			anim = &"calc_charging"
		State.CHARGED:
			anim = &"calc_charged"
		State.TELEPORT:
			anim = &"calc_teleport"
			var open: float = _anim_len(_vortex, &"vortex_open")
			t = maxf(_vortex_time - open, 0.0)
	_show(_sprite, anim, t)
	_vortex.visible = _state == State.TELEPORT
	if _vortex.visible:
		_vortex.position = _feet - global_position + LaserReceiver._vec(_config.get("vortex_offset_px", [0, -48]))
		var open_len: float = _anim_len(_vortex, &"vortex_open")
		var spin_len: float = _anim_len(_vortex, &"vortex_spin") * maxi(int(_config.get("spins", 2)), 1)
		if _vortex_time < open_len:
			_show(_vortex, &"vortex_open", _vortex_time)
		elif _vortex_time < open_len + spin_len:
			_show(_vortex, &"vortex_spin", fmod(_vortex_time - open_len, _anim_len(_vortex, &"vortex_spin")))
		else:
			_show(_vortex, &"vortex_close", _vortex_time - open_len - spin_len)


func _anim_len(sprite: AnimatedSprite2D, anim: StringName) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.001)


func _show(sprite: AnimatedSprite2D, anim: StringName, t: float) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	var frames: SpriteFrames = sprite.sprite_frames
	var count: int = frames.get_frame_count(anim)
	var index: int = floori(t * frames.get_animation_speed(anim))
	sprite.frame = index % count if frames.get_animation_loop(anim) else mini(index, count - 1)
