## Interruptor «No molestar» (tipo `dnd_switch`; 2026-10-19, paso 3 del plan de
## docs/propuesta-1-3.md §7, §3.1 y §5.1; seccion dnd_switch de
## data/world1_objects.json). Panel en la pared del FONDO de la sala «Ajustes»
## del 1-3: un PULSO que alcanza su zona (hit_rect, misma prueba que
## PulseReceiver) lo enciende con Isak de espaldas pose_s (Isak.face_back, como
## el power_switch con un solo pulso) y da para siempre la habilidad `ability`
## (aqui el dash, gesto Deslizar) con GameState.obtain_ability, la misma logica
## que el ability_pickup: se guarda, va a la Papelera en un game over y se
## pierde en un rollback sin guardar. La primera vez Eco dice la linea de
## historia `story_line` (importante, TEXTO PROPUESTO, por decidir) y despues
## sale el aviso de control (AbilityNotices, al obtenerla: las importantes salen
## en orden).
## Un solo uso (regla de unless_ability de los objetos de historia): con la
## habilidad ya obtenida o desbloqueada al cargar arranca encendido e inerte,
## sin linea ni aviso. Encendido no ayuda ni responde.
## Arte por script (paso 8, 2026-10-20): dnd_objects_frames.tres de
## tools/gen_world1_dnd.py (apagado, golpeado y encendido con la luna).
## Tinte del nivel (paso 10 del plan, 2026-10-20; decision del usuario): al
## encenderse, un CanvasModulate (RoomTint, hijo del interruptor) tine todo el
## lienzo del mundo (no el HUD) hacia room_tint en room_tint_fade_s; si arranca
## encendido (inerte), el tinte esta puesto desde el principio.
## El origen es la esquina superior izquierda de su celda (Isak de pie en ella).
class_name DndSwitch
extends Node2D

const GROUP: StringName = &"dnd_switch"
const NAME_TAG: String = "{apodo}"

## Se ha encendido con un pulso (`first`: dio la habilidad por primera vez).
signal switched_on(id: StringName, first: bool)

@export var object_id: StringName = &""
## Habilidad que da (GameState.ABILITIES; en el 1-3, &"dash").
@export var ability: StringName = &"dash"
## Id de la linea de historia (story_lines de la seccion dnd_switch; "" = ninguna).
@export var story_line: String = ""

var _config: Dictionary = World1ObjectsConfig.section("dnd_switch")
var _on: bool = false
## Encendido al cargar (habilidad ya obtenida): no responde ni habla.
var _inert: bool = false
var _sprite: AnimatedSprite2D
var _time: float = 0.0
var _hit_time: float = -1.0
var _pose_left: float = 0.0
var _posed: Isak
var _tint: CanvasModulate
## Segundos de tiempo del mundo desde que empezo el tinte (-1 = sin tinte).
var _tint_time: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	if is_already_owned():
		_on = true
		_inert = true
		HelpCatalog.tag(self, &"")
		_start_tint(true)
	EventBus.pulse_fired.connect(receive_pulse)
	_update_sprite()
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func is_on() -> bool:
	return _on


## Arranco encendido porque la habilidad ya era de Isak.
func is_inert() -> bool:
	return _inert


## La habilidad ya es de Isak (obtenida o desbloqueada): el interruptor sobra.
func is_already_owned() -> bool:
	return ability != &"" and (GameState.is_ability_obtained(ability) or GameState.is_ability_unlocked(ability))


## Isak sigue de espaldas por este interruptor.
func is_posing() -> bool:
	return _pose_left > 0.0


## Ayuda de Eco (HelpCatalog.is_help_live): encendido no ayuda.
func is_help_available() -> bool:
	return not _on


## Color del tinte del nivel ahora mismo (blanco sin tinte).
func get_room_tint() -> Color:
	return _tint.color if _tint != null else Color.WHITE


## Color final del tinte (seccion dnd_switch, room_tint).
func get_room_tint_target() -> Color:
	var c: Array = _config.get("room_tint", [1.0, 1.0, 1.0, 1.0])
	return Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)


## El tinte del nivel esta puesto (o empezando).
func is_room_tinted() -> bool:
	return _tint != null


func get_animation() -> StringName:
	return _sprite.animation


func get_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [8, -14, 48, 48])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


## Linea de historia (con el apodo) o "".
func get_story_text() -> String:
	var lines: Variant = _config.get("story_lines", {})
	if story_line.is_empty() or not lines is Dictionary:
		return ""
	return String((lines as Dictionary).get(story_line, "")).replace(NAME_TAG, GameState.get_nickname())


# --- Acciones ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si lo ha encendido.
func receive_pulse(area: Area2D) -> bool:
	if _on or not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	if isak != null and is_instance_valid(isak) and not isak.is_dead() and isak.face_back():
		_posed = isak
		_pose_left = float(_config.get("pose_s", 0.45))
	return switch_on()


## Lo enciende y da la habilidad (lo usan el pulso y las pruebas). Falso si ya
## estaba encendido.
func switch_on() -> bool:
	if _on:
		return false
	_on = true
	_hit_time = 0.0
	var first: bool = ability != &"" and not GameState.is_ability_obtained(ability)
	if first:
		var story: String = get_story_text()
		if not story.is_empty():
			EventBus.eco_line_requested.emit(story, float(_config.get("story_duration_s", 4.0)), true)
	if ability != &"":
		GameState.obtain_ability(ability)
	_start_tint(false)
	switched_on.emit(object_id, first)
	_update_sprite()
	queue_redraw()
	return true


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += maxf(dt, 0.0)
	if _pose_left > 0.0:
		_pose_left -= dt
		if _pose_left <= 0.0:
			_pose_left = 0.0
			if _posed != null and is_instance_valid(_posed) and _posed.is_facing_back():
				_posed.face_side()
			_posed = null
	if _hit_time >= 0.0:
		_hit_time += dt
	if _tint != null and _tint_time >= 0.0:
		_tint_time += dt
		_update_tint()
	_update_sprite()


# --- Interno ---

func _start_tint(instant: bool) -> void:
	if _tint == null:
		_tint = CanvasModulate.new()
		_tint.name = "RoomTint"
		add_child(_tint)
	_tint_time = INF if instant else 0.0
	_update_tint()


func _update_tint() -> void:
	var fade: float = maxf(float(_config.get("room_tint_fade_s", 0.8)), 0.001)
	var k: float = clampf(_tint_time / fade, 0.0, 1.0)
	_tint.color = Color.WHITE.lerp(get_room_tint_target(), k)


func _build() -> void:
	var frames := load(String(_config.get("frames", "res://assets/sprites/dnd_objects_frames.tres"))) as SpriteFrames
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.position = LaserReceiver._vec(_config.get("sprite_center_px", [32, 4]))
	_sprite.animation = _anim("anim_off", "dnd_switch_off")
	add_child(_sprite)


func _anim(key: String, fallback: String) -> StringName:
	return StringName(String(_config.get(key, fallback)))


func _update_sprite() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		return
	var hit: StringName = _anim("anim_hit", "dnd_switch_hit")
	var anim: StringName = _anim("anim_on", "dnd_switch_on") if _on else _anim("anim_off", "dnd_switch_off")
	var t: float = _time
	if _hit_time >= 0.0 and frames.has_animation(hit):
		var hit_len: float = frames.get_frame_count(hit) / maxf(frames.get_animation_speed(hit), 0.001)
		if _hit_time < hit_len:
			anim = hit
			t = _hit_time
		else:
			_hit_time = -1.0
	if not frames.has_animation(anim):
		return
	if _sprite.animation != anim:
		_sprite.animation = anim
	var count: int = frames.get_frame_count(anim)
	var index: int = floori(t * frames.get_animation_speed(anim))
	_sprite.frame = index % count if frames.get_animation_loop(anim) else mini(index, count - 1)
