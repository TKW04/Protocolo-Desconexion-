## La Papelera en el nivel (tipo `papelera_actor` del catalogo del Mundo 4;
## 2026-10-28, paso 8 de docs/propuesta-mundo-4.md §8, §3.7 y §4.2.2; nivel 4-2,
## sala «Mensajes borrados»). Ajustes en la seccion papelera_actor de
## data/world4_objects.json.
##
## Actor de historia sin colision ni Q con el arte de su estacion del hub
## (papelera_frames.tres de tools/gen_hub_objects.py: «active», tambaleandose,
## mientras tiene algo que decir; «empty» despues), de pie en su celda. Habla en el
## cuadro de texto del nivel como interlocutor `papelera` (speakers de
## data/eco_text_box.json, estilo panel con su icono). Momento de historia
## (`story`, stories de la seccion):
## 1. Con Isak a talk_radius_tiles o menos (en horizontal, vivo, fuera del vortice),
##    las lineas `intro` (importantes: pausan) y marca el aviso `notice`
##    (seen_notices, un solo uso por partida guardada, sin subir la version del
##    guardado).
## 2. Cuando Isak usa el «¿Deshacer escritura?» (EventBus.writing_undone, si la
##    historia tiene `after_undo`; desde el 2026-10-28, al retirarse Agitar) o
##    obtiene la habilidad `ability` (EventBus.ability_obtained), la linea `after`
##    en voz baja (no importante, ya sin pausa: va detras de las importantes).
## Con el aviso ya visto o la habilidad ya obtenida al cargar, calla (arte
## «empty»). En el hub no cambia nada de la Papelera. Tiempo del mundo.
class_name PapeleraActor
extends Node2D

enum State { WAITING, TOLD, DONE }

const GROUP: StringName = &"papelera_actor"
const SPEAKER: StringName = &"papelera"

## Ha dicho una linea (`kind`: intro o after).
signal line_said(text: String, important: bool, kind: StringName)

@export var object_id: StringName = &""
## Id del momento de historia (stories de la seccion papelera_actor).
@export var story: String = ""

var _config: Dictionary = World4ObjectsConfig.section("papelera_actor")
var _state: State = State.WAITING
var _time: float = 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(GROUP)
	HelpCatalog.tag(self, &"")
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Papelera"
	_sprite.sprite_frames = load(String(_config.get("frames", "res://assets/sprites/hub/papelera_frames.tres"))) \
		as SpriteFrames
	_sprite.centered = false
	_sprite.position = LaserReceiver._vec(_config.get("sprite_offset_px", [0, -32]))
	add_child(_sprite)
	var data: Dictionary = get_story()
	var ability: StringName = StringName(String(data.get("ability", "")))
	if data.is_empty() or GameState.is_notice_seen(get_notice_id()) \
			or (ability != &"" and GameState.is_ability_obtained(ability)):
		_state = State.DONE
	EventBus.ability_obtained.connect(_on_ability_obtained)
	EventBus.writing_undone.connect(_on_writing_undone)
	_update_sprite()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


## Datos del momento de historia (vacio si no existe).
func get_story() -> Dictionary:
	var stories: Variant = _config.get("stories", {})
	if not stories is Dictionary:
		return {}
	var data: Variant = (stories as Dictionary).get(story, {})
	return data if data is Dictionary else {}


func get_notice_id() -> StringName:
	return StringName(String(get_story().get("notice", story)))


func get_intro_lines() -> Array[String]:
	var out: Array[String] = []
	for line: Variant in get_story().get("intro", []):
		out.append(String(line))
	return out


func get_after_line() -> String:
	return String(get_story().get("after", ""))


## Ayuda de Eco: es historia, nunca ayuda.
func is_help_available() -> bool:
	return false


func get_animation() -> StringName:
	return _sprite.animation


## Centro del pie de la Papelera (global).
func get_feet() -> Vector2:
	var t: float = World4ObjectsConfig.tile_size()
	return global_position + Vector2(t * 0.5, t)


# --- Acciones ---

## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += maxf(dt, 0.0)
	if _state == State.WAITING:
		var isak: Isak = LevelLookup.find_isak(self)
		if isak != null and _in_range(isak):
			tell()
	_update_sprite()


## Dice las lineas de la presentacion (lo usan la cercania y las pruebas). Falso si
## ya las dijo o calla.
func tell() -> bool:
	if _state != State.WAITING:
		return false
	_state = State.TOLD
	GameState.mark_notice_seen(get_notice_id())
	for line: String in get_intro_lines():
		_say(line, true, &"intro")
	_update_sprite()
	return true


# --- Interno ---

func _in_range(isak: Isak) -> bool:
	if isak.is_dead() or isak.is_warping():
		return false
	var radius: float = float(_config.get("talk_radius_tiles", 3.0)) * World4ObjectsConfig.tile_size()
	return absf(isak.global_position.x - get_feet().x) <= radius \
		and absf(isak.global_position.y - get_feet().y) <= radius


func _on_writing_undone(_id: StringName) -> void:
	if _state != State.TOLD or not bool(get_story().get("after_undo", false)):
		return
	_finish()


func _on_ability_obtained(ability: StringName) -> void:
	if _state != State.TOLD or ability == &"" or ability != StringName(String(get_story().get("ability", ""))):
		return
	_finish()


## La linea `after` y en silencio para siempre.
func _finish() -> void:
	_state = State.DONE
	var after: String = get_after_line()
	if not after.is_empty():
		_say(after, false, &"after")
	_update_sprite()


## Cuadro de texto del nivel (hijo EcoTextBox de la raiz) como interlocutor
## papelera; sin cuadro, por EventBus como una linea de Eco.
func _say(text: String, important: bool, kind: StringName) -> void:
	line_said.emit(text, important, kind)
	var box: Node = _text_box()
	if box != null:
		box.call(&"show_line", text, float(_config.get("duration_s", -1.0)), important, SPEAKER)
	else:
		EventBus.eco_line_requested.emit(text, float(_config.get("duration_s", -1.0)), important)


func _text_box() -> Node:
	var node: Node = get_parent()
	while node != null:
		var box: Node = node.get_node_or_null(^"EcoTextBox")
		if box != null:
			return box
		node = node.get_parent()
	return null


func _update_sprite() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		return
	var anim: StringName = &"empty" if _state == State.DONE else &"active"
	if not frames.has_animation(anim):
		return
	if _sprite.animation != anim:
		_sprite.animation = anim
	var count: int = frames.get_frame_count(anim)
	var index: int = floori(_time * frames.get_animation_speed(anim))
	_sprite.frame = index % count if frames.get_animation_loop(anim) else mini(index, count - 1)
