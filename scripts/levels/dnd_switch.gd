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
## Arte PROVISIONAL: panel del power_switch y una luna dibujada por codigo.
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


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	if is_already_owned():
		_on = true
		_inert = true
		HelpCatalog.tag(self, &"")
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
	_update_sprite()


# --- Interno ---

func _build() -> void:
	var frames := load(String(_config.get("frames", "res://assets/sprites/calc_encounter_frames.tres"))) as SpriteFrames
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.position = LaserReceiver._vec(_config.get("sprite_center_px", [32, 4]))
	_sprite.animation = _anim("anim_off", "power_switch_off")
	# La luna (_draw del interruptor) se dibuja encima del panel.
	_sprite.show_behind_parent = true
	add_child(_sprite)


func _anim(key: String, fallback: String) -> StringName:
	return StringName(String(_config.get(key, fallback)))


func _update_sprite() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		return
	var hit: StringName = _anim("anim_hit", "power_switch_hit")
	var anim: StringName = _anim("anim_on", "power_switch_on") if _on else _anim("anim_off", "power_switch_off")
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


## Luna creciente provisional (encendido): disco con un mordisco, en pasos de px.
func _draw() -> void:
	if not _on:
		return
	var center: Vector2 = LaserReceiver._vec(_config.get("moon_center_px", [32, -22]))
	var radius: float = float(_config.get("moon_radius_px", 6.0))
	var color := Color(String(_config.get("moon_color", "#9bb0e8")))
	var r: int = int(radius)
	for y: int in range(-r, r + 1):
		for x: int in range(-r, r + 1):
			var inside: bool = x * x + y * y <= r * r
			var bite: bool = (x - r * 0.5) * (x - r * 0.5) + (y + r * 0.3) * (y + r * 0.3) <= r * r * 0.7
			if inside and not bite:
				draw_rect(Rect2(center + Vector2(x, y), Vector2.ONE), color)
