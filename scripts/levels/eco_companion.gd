## Eco como companero visible (docs/propuesta-asistentes-y-vidas.md §2.1, paso 4
## de §10; valores en data/eco_companion.json, arte de
## tools/gen_eco_companion.py). Esfera flotante que sigue a Isak siempre que Eco
## es conocido (GameState.has_met_ally("eco")): en los niveles la crea
## LevelRunner y en el hub HubRoom (variante atenuada, `dim`: sin cobertura; no
## ofrece guardar ni comprar, no es una estacion).
## - Entra y sale con Isak: con una llegada (Isak.warp_began(true)) se esconde
##   y aparece appear_delay_s despues de que Isak se vea (warp_revealed); con
##   una salida (warp_began(false)) se acerca al vortice y, cuando Isak ya fue
##   absorbido (opacidad 0), desaparece. Si Eco pasa a conocido a mitad de
##   nivel (EventBus.ally_met), aparece entonces.
## - Seguimiento suave con amortiguacion critica hacia un punto detras y encima
##   de Isak (por el lado contrario al que mira; cruza por encima al girarse) y
##   oscilacion vertical. Mira hacia donde mira Isak (flip_h). Si se aleja
##   demasiado, se recoloca con un destello.
## - Reacciona (notice) al empezar a hablar Eco (EventBus.eco_line_started) y al
##   salir una Q (EventBus.help_prompt_shown); mientras habla, talk.
## - Sin colision. Se dibuja en el lienzo del mundo (por debajo de la Q y del
##   HUD) y en el arbol antes de los enemigos y de Isak: nunca los tapa.
## - Tiempo REAL (PROCESS_MODE_ALWAYS): anima mientras habla con el juego en
##   pausa y no se ralentiza con el Debug. Avanza con advance(delta).
class_name EcoCompanion
extends Node2D

enum State { HIDDEN, APPEARING, FOLLOW, DEPARTING, DISAPPEARING }

const DATA_PATH: String = "res://data/eco_companion.json"
const SCENE_PATH: String = "res://scenes/levels/eco_companion.tscn"
const GROUP: StringName = &"eco_companion"
const DIM_SUFFIX: String = "_dim"
const ANIM_IDLE: StringName = &"idle"
const ANIM_TALK: StringName = &"talk"
const ANIM_NOTICE: StringName = &"notice"
const ANIM_APPEAR: StringName = &"appear"
const ANIM_DISAPPEAR: StringName = &"disappear"
## Opacidad de Isak por debajo de la cual ya fue absorbido por el vortice.
const ABSORBED_ALPHA: float = 0.01

## Cambia de estado (pruebas y capturas).
signal state_changed(state: State)

## Si es false, _process no avanza (las pruebas llaman a advance()).
@export var auto_advance: bool = true

var _data: Dictionary = {}
var _isak: Isak
var _dim: bool = false
var _state: State = State.HIDDEN
var _anchor: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _delay_left: float = 0.0
## Hay una llegada o salida de Isak en curso: no aparecer hasta warp_revealed.
var _awaiting_reveal: bool = false
var _talking: bool = false
var _notice_left: float = 0.0
var _side: float = 1.0
var _anim: StringName = &""
var _anim_time: float = 0.0
@onready var _sprite: AnimatedSprite2D = $Sprite


## Crea el companero de `isak` bajo `parent` (normalmente el padre de Isak),
## colocado en el arbol detras de los enemigos y de Isak. `dim`: variante del
## hub (atenuada).
static func attach(isak: Isak, parent: Node, dim: bool = false) -> EcoCompanion:
	var eco := (load(SCENE_PATH) as PackedScene).instantiate() as EcoCompanion
	eco._isak = isak
	eco._dim = dim
	parent.add_child(eco)
	eco._place_in_tree(parent)
	return eco


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	_data = load_data()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	var frames_path: String = String(_data.get("frames", ""))
	if not frames_path.is_empty():
		_sprite.sprite_frames = load(frames_path) as SpriteFrames
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * maxi(1, int(_data.get("sprite_scale", 1)))
	if _dim:
		modulate.a = float(_data.get("hub_alpha", 0.8))
	visible = false
	EventBus.ally_met.connect(_on_ally_met)
	EventBus.eco_line_started.connect(_on_eco_line_started)
	EventBus.eco_line_finished.connect(_on_eco_line_finished)
	EventBus.help_prompt_shown.connect(_on_help_prompt_shown)
	if _valid_isak():
		_isak.warp_began.connect(_on_isak_warp_began)
		_isak.warp_revealed.connect(_on_isak_warp_revealed)
		_awaiting_reveal = _isak.is_warp_hidden()
		_side = _isak.facing if _isak.facing != 0.0 else 1.0
		_anchor = get_target_position()
		global_position = _anchor


func _exit_tree() -> void:
	for pair: Array in [[EventBus.ally_met, _on_ally_met], [EventBus.eco_line_started, _on_eco_line_started],
			[EventBus.eco_line_finished, _on_eco_line_finished],
			[EventBus.help_prompt_shown, _on_help_prompt_shown]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


# --- Consultas ---

func get_state() -> State:
	return _state


## Eco se ve (apareciendo, siguiendo, yendose o desapareciendo).
func is_shown() -> bool:
	return _state != State.HIDDEN


func is_dim() -> bool:
	return _dim


func get_isak() -> Isak:
	return _isak


func get_sprite() -> AnimatedSprite2D:
	return _sprite


## Animacion mostrada (sin el sufijo _dim).
func get_animation() -> StringName:
	return _anim


## Punto que sigue (sin la oscilacion).
func get_anchor() -> Vector2:
	return _anchor


## Punto al que va ahora: detras y encima de Isak (o el centro del vortice de
## salida mientras se va).
func get_target_position() -> Vector2:
	if not _valid_isak():
		return _anchor
	var feet: Vector2 = _isak.global_position
	if _state == State.DEPARTING:
		var center: Array = _data.get("depart_center_offset_px", [0, -48])
		return feet + Vector2(float(center[0]), float(center[1]))
	var offset: Array = _data.get("offset_px", [48, 112])
	var behind: float = float(offset[0])
	var target := Vector2(feet.x - _side * behind, feet.y - float(offset[1]))
	# Al girarse Isak, Eco cruza por encima de el.
	if behind > 0.0:
		var near: float = clampf(1.0 - absf(_anchor.x - feet.x) / behind, 0.0, 1.0)
		target.y -= float(_data.get("cross_lift_px", 20)) * near
	return target


# --- Acciones ---

## Aparece ya en `from` (global) y vuela desde alli hasta su sitio junto a
## Isak (sin destello): el encuentro con Eco del 1-1 (EcoEncounter) le pasa la
## esfera que flotaba. Falso si Eco no es conocido o Isak no se ve.
func appear_at(from: Vector2) -> bool:
	if not _can_appear():
		return false
	_anchor = from
	_velocity = Vector2.ZERO
	_delay_left = 0.0
	_set_state(State.FOLLOW)
	_update_visual(0.0)
	return true


## Avanza `delta` segundos de tiempo real.
func advance(delta: float) -> void:
	delta = maxf(delta, 0.0)
	_time += delta
	_notice_left = maxf(0.0, _notice_left - delta)
	if _valid_isak() and not _isak.is_facing_back() and _isak.facing != 0.0:
		_side = signf(_isak.facing)
	match _state:
		State.HIDDEN:
			if _can_appear():
				_delay_left -= delta
				if _delay_left <= 0.0:
					_snap_to_target()
					_set_state(State.APPEARING)
		State.APPEARING:
			_follow(delta)
			if _anim_done():
				_set_state(State.FOLLOW)
		State.FOLLOW:
			_follow(delta)
			if _anchor.distance_to(get_target_position()) > float(_data.get("teleport_distance_px", 256)):
				_snap_to_target()
				_set_state(State.APPEARING)
		State.DEPARTING:
			_follow(delta)
			if not _valid_isak() or _isak.modulate.a <= ABSORBED_ALPHA:
				_set_state(State.DISAPPEARING)
		State.DISAPPEARING:
			if _anim_done():
				_set_state(State.HIDDEN)
	_update_visual(delta)


# --- Interno ---

func _place_in_tree(parent: Node) -> void:
	for node_name: Variant in _data_or_load().get("draw_behind_nodes", []):
		var sibling: Node = parent.get_node_or_null(NodePath(String(node_name)))
		if sibling != null and sibling != self:
			parent.move_child(self, sibling.get_index())
			return
	if _valid_isak() and _isak.get_parent() == parent:
		parent.move_child(self, _isak.get_index())


func _data_or_load() -> Dictionary:
	if _data.is_empty():
		_data = load_data()
	return _data


func _can_appear() -> bool:
	return GameState.has_met_ally(GameState.ALLY_ECO) and _valid_isak() and not _awaiting_reveal \
			and not _isak.is_warp_hidden() and _isak.is_visible_in_tree() and not _isak.is_dead()


func _snap_to_target() -> void:
	_anchor = get_target_position()
	_velocity = Vector2.ZERO


## Amortiguacion critica (SmoothDamp) hacia el objetivo.
func _follow(delta: float) -> void:
	if delta <= 0.0:
		return
	var target: Vector2 = get_target_position()
	var smooth: float = maxf(float(_data.get("smooth_time_s", 0.25)), 0.0001)
	var omega: float = 2.0 / smooth
	var x: float = omega * delta
	var decay: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector2 = _anchor - target
	var temp: Vector2 = (_velocity + omega * change) * delta
	_velocity = (_velocity - omega * temp) * decay
	_anchor = target + (change + temp) * decay


func _set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	match state:
		State.APPEARING:
			_play(ANIM_APPEAR)
		State.DISAPPEARING:
			_play(ANIM_DISAPPEAR)
		State.HIDDEN:
			_anim = &""
	state_changed.emit(state)


func _update_visual(delta: float) -> void:
	visible = _state != State.HIDDEN
	if not visible:
		return
	if _state == State.FOLLOW or _state == State.DEPARTING:
		var want: StringName = ANIM_IDLE
		if _notice_left > 0.0:
			want = ANIM_NOTICE
		elif _talking:
			want = ANIM_TALK
		if want != _anim:
			_play(want)
	_anim_time += delta
	var anim_name: StringName = _full_name(_anim)
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames != null and frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.animation = anim_name
		var count: int = frames.get_frame_count(anim_name)
		var fps: float = maxf(frames.get_animation_speed(anim_name), 0.001)
		var index: int = floori(_anim_time * fps)
		_sprite.frame = index % count if frames.get_animation_loop(anim_name) else mini(index, count - 1)
	_sprite.flip_h = _side < 0.0
	var amp: float = float(_data.get("bob_amplitude_px", 4))
	var bob: float = sin(TAU * float(_data.get("bob_hz", 0.8)) * _time) * amp
	global_position = (_anchor + Vector2(0.0, bob)).round()


func _play(anim: StringName) -> void:
	_anim = anim
	_anim_time = 0.0


func _anim_done() -> bool:
	var frames: SpriteFrames = _sprite.sprite_frames if _sprite != null else null
	var anim_name: StringName = _full_name(_anim)
	if frames == null or not frames.has_animation(anim_name):
		return true
	var fps: float = maxf(frames.get_animation_speed(anim_name), 0.001)
	return _anim_time >= frames.get_frame_count(anim_name) / fps


func _full_name(anim: StringName) -> StringName:
	return StringName(String(anim) + DIM_SUFFIX) if _dim else anim


func _valid_isak() -> bool:
	return _isak != null and is_instance_valid(_isak)


func _on_isak_warp_began(hidden: bool) -> void:
	_awaiting_reveal = true
	if hidden:
		# Llegada (o reaparicion): se va y vuelve cuando Isak se vea.
		if _state != State.HIDDEN and _state != State.DISAPPEARING:
			_set_state(State.DISAPPEARING)
	elif _state == State.FOLLOW or _state == State.APPEARING:
		_set_state(State.DEPARTING)


func _on_isak_warp_revealed() -> void:
	_awaiting_reveal = false
	_delay_left = float(_data.get("appear_delay_s", 0.3))


func _on_ally_met(ally: StringName) -> void:
	if ally == GameState.ALLY_ECO:
		_delay_left = 0.0


func _on_eco_line_started(_text: String) -> void:
	_talking = true
	_notice_left = float(_data.get("notice_s", 0.3))


func _on_eco_line_finished() -> void:
	_talking = false


func _on_help_prompt_shown(_target: Node2D) -> void:
	_notice_left = float(_data.get("notice_s", 0.3))
