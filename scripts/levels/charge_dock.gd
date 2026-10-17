## Punto de carga de Calc (tipo `charge_dock`; acertijo de la azotea del 1-2,
## 2026-10-17, tanda H1 del paso 14; docs/propuesta-calc-encuentro.md; seccion
## charge_dock de data/world1_objects.json; arte de tools/gen_calc_encounter.py).
## Plataforma de 2x1 tiles (no solida) con un medidor de 10 segmentos:
## 1. IDLE (charge_dock_idle): espera a que todas las piezas de required_ids
##    esten hechas (CalcRoom.is_done).
## 2. READY (charge_dock_ready): armado; emite armed y Calc (CalcActor con
##    dock_id == object_id) viene y se coloca (start_charging).
## 3. CHARGING (charge_dock_charging, chispas): charge_s segundos de tiempo del
##    mundo; la bateria de Calc sube de start_percent a 100 (el medidor, por
##    segmentos). Al acabar, Calc se despide y se teletransporta.
## 4. CHARGED: Calc se esta yendo. 5. DONE (charge_dock_done): Calc se fue; el
##    punto tiene corriente (is_power_on, power_changed): la terminal con
##    power_source == object_id se enciende.
## Q solo en IDLE (despues ya no ayuda). Con done_if_ally conocido, DONE.
## El origen es la esquina superior izquierda de su primera celda.
class_name ChargeDock
extends Node2D

enum State { IDLE, READY, CHARGING, CHARGED, DONE }

const GROUP: StringName = &"charge_dock"

## Todas las piezas hechas: Calc puede venir.
signal armed
## Empieza a cargar a `actor`.
signal charging_started(actor: Node)
## Bateria al 100 %.
signal charged
## Tiene (o deja de tener) corriente.
signal power_changed(on: bool)

@export var object_id: StringName = &""
@export var required_ids: Array = []
@export var charge_s: float = 3.0
@export var done_if_ally: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("charge_dock")
var _state: State = State.IDLE
var _time: float = 0.0
var _charge_time: float = 0.0
var _actor: Node
var _sprite: AnimatedSprite2D
var _gauge: AnimatedSprite2D
var _sparks: Array[AnimatedSprite2D] = []


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(CalcRoom.LINK_GROUP)
	var frames := load(PowerSwitch.FRAMES_PATH) as SpriteFrames
	_sprite = _make(frames, &"charge_dock_idle", LaserReceiver._vec(_config.get("sprite_center_px", [64, 32])), "Dock")
	_gauge = _make(frames, &"charge_gauge", LaserReceiver._vec(_config.get("gauge_center_px", [118, 34])), "Gauge")
	for p: Variant in _config.get("spark_px", [[40, 40], [74, 36]]):
		var spark: AnimatedSprite2D = _make(frames, &"charge_spark", LaserReceiver._vec(p), "Spark")
		spark.visible = false
		_sparks.append(spark)
	if CalcRoom.skipped_for(done_if_ally):
		_state = State.DONE
	_update_visual()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


func is_armed() -> bool:
	return _state != State.IDLE


## Pieza hecha: Calc ya se fue y hay corriente.
func is_activated() -> bool:
	return _state == State.DONE


func is_power_on() -> bool:
	return _state == State.DONE


## Bateria de Calc (start_percent a 100) mientras carga; 100 despues.
func get_percent() -> float:
	var start: float = float(_config.get("start_percent", 3))
	match _state:
		State.IDLE, State.READY:
			return start
		State.CHARGING:
			return lerpf(start, 100.0, clampf(_charge_time / maxf(charge_s, 0.001), 0.0, 1.0))
	return 100.0


## Segmentos del medidor encendidos (0 a 10).
func get_lit_segments() -> int:
	return _gauge.frame


func get_animation() -> StringName:
	return _sprite.animation


func are_sparks_visible() -> bool:
	return not _sparks.is_empty() and _sparks[0].visible


## Donde se ponen los pies de Calc (global).
func get_calc_feet() -> Vector2:
	return global_position + LaserReceiver._vec(_config.get("calc_feet_px", [56, 52]))


## Ayuda de Eco (HelpCatalog.is_help_live): solo antes de armarse.
func is_help_available() -> bool:
	return _state == State.IDLE


func get_outline_rect() -> Rect2:
	return Rect2(global_position, Vector2(128, 64))


# --- Acciones ---

## Calc se ha colocado: empieza a cargar. Falso si no estaba armado.
func start_charging(actor: Node) -> bool:
	if _state != State.READY:
		return false
	_state = State.CHARGING
	_actor = actor
	_charge_time = 0.0
	charging_started.emit(actor)
	_update_visual()
	return true


## Calc se ha ido (teletransporte): hay corriente. Falso si no estaba cargada.
func finish() -> bool:
	if _state != State.CHARGED:
		return false
	_state = State.DONE
	_update_visual()
	power_changed.emit(true)
	return true


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	if _state == State.IDLE and CalcRoom.all_done(self, required_ids):
		_state = State.READY
		armed.emit()
	elif _state == State.CHARGING:
		_charge_time += dt
		if _actor != null and is_instance_valid(_actor) and _actor.has_method(&"set_battery"):
			_actor.call(&"set_battery", get_percent())
		if _charge_time >= charge_s:
			_state = State.CHARGED
			charged.emit()
			if _actor != null and is_instance_valid(_actor) and _actor.has_method(&"on_charged"):
				_actor.call(&"on_charged")
	_update_visual()


func _make(frames: SpriteFrames, anim: StringName, pos: Vector2, node_name: String) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = node_name
	sprite.sprite_frames = frames
	sprite.animation = anim
	sprite.position = pos
	add_child(sprite)
	return sprite


func _update_visual() -> void:
	var anim: StringName = &"charge_dock_idle"
	match _state:
		State.READY:
			anim = &"charge_dock_ready"
		State.CHARGING:
			anim = &"charge_dock_charging"
		State.CHARGED, State.DONE:
			anim = &"charge_dock_done"
	_loop(_sprite, anim, _time)
	var frames: SpriteFrames = _gauge.sprite_frames
	var count: int = frames.get_frame_count(&"charge_gauge")
	# Segmentos por decimas: 3 % ya enciende el primero (Calc no esta a cero).
	_gauge.frame = clampi(ceili(get_percent() / 100.0 * (count - 1)), 0, count - 1)
	var on: bool = _state == State.CHARGING
	for i: int in _sparks.size():
		_sparks[i].visible = on
		if on:
			_loop(_sparks[i], &"charge_spark", _time + i * 0.13)


func _loop(sprite: AnimatedSprite2D, anim: StringName, t: float) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	var frames: SpriteFrames = sprite.sprite_frames
	var count: int = frames.get_frame_count(anim)
	sprite.frame = floori(t * frames.get_animation_speed(anim)) % count if count > 0 else 0
