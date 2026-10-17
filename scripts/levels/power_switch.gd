## Interruptor de pulso (tipo `power_switch`) y panel oculto (tipo
## `debug_switch`) del acertijo de la azotea del 1-2 (2026-10-17, tanda H1 del
## paso 14; docs/propuesta-calc-encuentro.md; seccion power_switch de
## data/world1_objects.json; arte de tools/gen_calc_encounter.py).
## - Panel en la pared del FONDO: Isak se pone delante. Cada PULSO que alcanza
##   su zona (hit_rect, misma prueba que PulseReceiver) cuenta uno: Isak se pone
##   de espaldas mirando el panel (Isak.face_back, como en las estaciones del
##   hub) pose_s segundos de tiempo del mundo y vuelve de perfil (face_side); se
##   enciende una luz por pulso. Con pulses_required pulsos se ACTIVA para
##   siempre (activated): las luces del cuarto (DarkRoom) suben por tercios con
##   su progreso y la pared con glitch enlazada se vuelve puerta.
## - Activado no hace nada mas ni da Q (lo usado no ayuda).
## - hidden_until_debug (debug_switch): no se ve ni responde hasta que el Debug
##   esta activo cerca (reveal_radius_px); desde entonces queda MARCADO (se ve
##   tenue sin el Debug) y responde al pulso aunque el Debug se apague.
## - done_if_ally: con ese asistente conocido al cargar, arranca activado.
## El origen es la esquina superior izquierda de su celda (Isak de pie en ella).
class_name PowerSwitch
extends Node2D

const GROUP: StringName = &"power_switch"
const FRAMES_PATH: String = "res://assets/sprites/calc_encounter_frames.tres"

## Un pulso ha contado (`count` de `required`).
signal pulsed(count: int, required: int)
## Se ha activado (todas las luces).
signal activated(id: StringName)
## Panel oculto: el Debug lo ha descubierto.
signal revealed

@export var object_id: StringName = &""
@export_range(1, 6) var pulses_required: int = 3
## Panel oculto (debug_switch): solo se ve y responde una vez visto con el Debug.
@export var hidden_until_debug: bool = false
## Con este asistente ya conocido al cargar, arranca activado ("" = nunca).
@export var done_if_ally: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("power_switch")
var _count: int = 0
var _active: bool = false
var _revealed: bool = false
var _sprite: AnimatedSprite2D
var _lamps: Array[Sprite2D] = []
var _time: float = 0.0
var _hit_time: float = -1.0
var _pose_left: float = 0.0
var _posed: Isak


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(CalcRoom.LINK_GROUP)
	_build()
	EventBus.pulse_fired.connect(receive_pulse)
	if CalcRoom.skipped_for(done_if_ally):
		_count = pulses_required
		_active = true
		_revealed = true
	_apply()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func is_activated() -> bool:
	return _active


func get_count() -> int:
	return _count


func get_required() -> int:
	return pulses_required


## Progreso de 0 a 1 (las luces del cuarto suben por tercios con el).
func get_progress() -> float:
	return clampf(float(_count) / float(maxi(pulses_required, 1)), 0.0, 1.0)


## Panel oculto ya visto con el Debug (o normal).
func is_revealed() -> bool:
	return not hidden_until_debug or _revealed


## Luces encendidas ahora (pruebas).
func get_lit_lamps() -> int:
	var n: int = 0
	for lamp: Sprite2D in _lamps:
		if lamp.get_meta(&"on", false):
			n += 1
	return n


func get_animation() -> StringName:
	return _sprite.animation


## Isak sigue de espaldas por este interruptor.
func is_posing() -> bool:
	return _pose_left > 0.0


## Ayuda de Eco (HelpCatalog.is_help_live): activado (o sin descubrir) no ayuda.
func is_help_available() -> bool:
	return not _active and is_revealed()


func get_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [8, -14, 48, 48])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


# --- Acciones ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si ha contado.
func receive_pulse(area: Area2D) -> bool:
	if _active or not is_revealed() or not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	_count = mini(_count + 1, pulses_required)
	_hit_time = 0.0
	if isak != null and is_instance_valid(isak) and not isak.is_dead() and isak.face_back():
		_posed = isak
		_pose_left = float(_config.get("pose_s", 0.45))
	pulsed.emit(_count, pulses_required)
	if _count >= pulses_required:
		_active = true
		activated.emit(object_id)
	_apply()
	return true


## Se activa sin pulsos (todas las luces; lo usan las pruebas). Falso si ya lo estaba.
func activate() -> bool:
	if _active:
		return false
	_count = pulses_required
	_active = true
	_revealed = true
	activated.emit(object_id)
	_apply()
	return true


## Descubre el panel oculto (lo llama advance con el Debug activo cerca).
func reveal() -> bool:
	if _revealed or not hidden_until_debug:
		return false
	_revealed = true
	revealed.emit()
	_apply()
	return true


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += maxf(dt, 0.0)
	if hidden_until_debug and not _revealed and DebugMode.is_active() and _isak_near():
		reveal()
	if _pose_left > 0.0:
		_pose_left -= dt
		if _pose_left <= 0.0:
			_pose_left = 0.0
			if _posed != null and is_instance_valid(_posed) and _posed.is_facing_back():
				_posed.face_side()
			_posed = null
	if _hit_time >= 0.0:
		_hit_time += dt
	_update_sprite()
	_update_visibility()


# --- Interno ---

func _prefix() -> String:
	return "debug_switch" if hidden_until_debug else "power_switch"


func _build() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.position = LaserReceiver._vec(_config.get("sprite_center_px", [32, 4]))
	_sprite.animation = StringName(_prefix() + "_off")
	add_child(_sprite)
	var lamp_center: Vector2 = LaserReceiver._vec(_config.get("lamp_center_px", [32, -21]))
	var spacing: float = float(_config.get("lamp_spacing_px", 10))
	for i: int in pulses_required:
		var lamp := Sprite2D.new()
		lamp.name = "Lamp%d" % i
		lamp.position = lamp_center + Vector2((i - (pulses_required - 1) * 0.5) * spacing, 0.0)
		add_child(lamp)
		_lamps.append(lamp)


func _apply() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	for i: int in _lamps.size():
		var on: bool = i < _count
		_lamps[i].set_meta(&"on", on)
		_lamps[i].texture = frames.get_frame_texture(&"switch_lamp_on" if on else &"switch_lamp_off", 0)
	_update_sprite()
	_update_visibility()


func _update_sprite() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	var hit := StringName(_prefix() + "_hit")
	var anim := StringName(_prefix() + ("_on" if _active else "_off"))
	var t: float = _time
	if _hit_time >= 0.0:
		var hit_len: float = frames.get_frame_count(hit) / maxf(frames.get_animation_speed(hit), 0.001)
		if _hit_time < hit_len:
			anim = hit
			t = _hit_time
		else:
			_hit_time = -1.0
	if _sprite.animation != anim:
		_sprite.animation = anim
	var count: int = frames.get_frame_count(anim)
	var index: int = floori(t * frames.get_animation_speed(anim))
	_sprite.frame = index % count if frames.get_animation_loop(anim) else mini(index, count - 1)


## Panel oculto: invisible sin descubrir (salvo con el Debug encendido, que lo
## va mostrando con su intensidad); descubierto, tenue sin el Debug.
func _update_visibility() -> void:
	if not hidden_until_debug:
		return
	var intensity: float = DebugMode.get_intensity()
	if not _revealed:
		visible = intensity > 0.0
		modulate.a = intensity
	else:
		visible = true
		modulate.a = lerpf(float(_config.get("marked_alpha", 0.55)), 1.0, intensity) if not _active else 1.0


func _isak_near() -> bool:
	var isak: Isak = CalcRoom.find_isak(self)
	return isak != null and isak.global_position.distance_to(get_hit_rect().get_center()) \
		<= float(_config.get("reveal_radius_px", 256.0))
