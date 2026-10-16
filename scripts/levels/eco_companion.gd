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
## - Lleva la Q de la ayuda (2026-10-16, decision del usuario): HelpSystem
##   (la fuente de verdad del objeto candidato) le pasa el objeto con Q
##   (set_help_target); Eco deja su sitio y vuela junto al objeto (encima, por
##   el lado contrario a Isak, help_offset_px; sin tapar a Isak ni salirse de la
##   pantalla), brilla en ambar (glow_in -> animaciones _amber con halo que late
##   -> glow_out) y la Q se dibuja sobre el (get_prompt_position). Al pulsar Q
##   (begin_help_explanation) conserva el brillo y el sitio mientras explica (el
##   juego en pausa; Eco usa tiempo real); al cerrar la linea vuelve suavemente
##   a seguir a Isak con su color. Nunca se queda atascado: suelta el objeto si
##   deja de ser candidato (aprendido, fuera de rango, ajuste «Ocultar»), si
##   desaparece o se oculta, si el arbol se pausa sin estar explicando (menu de
##   pausa), si Isak muere o entra en un vortice, y si la explicacion no llega a
##   mostrarse (help_explain_grace_s sin hablar).
## - Sin colision. Se dibuja en el lienzo del mundo (por debajo de la Q y del
##   HUD) y en el arbol antes de los enemigos y de Isak: nunca los tapa.
## - Tiempo REAL (PROCESS_MODE_ALWAYS): anima mientras habla con el juego en
##   pausa y no se ralentiza con el Debug. Avanza con advance(delta).
class_name EcoCompanion
extends Node2D

enum State { HIDDEN, APPEARING, FOLLOW, DEPARTING, DISAPPEARING }
## Brillo ambar de la ayuda: apagado, encendiendose, encendido, apagandose.
enum Glow { OFF, IN, ON, OUT }

const DATA_PATH: String = "res://data/eco_companion.json"
const SCENE_PATH: String = "res://scenes/levels/eco_companion.tscn"
const GROUP: StringName = &"eco_companion"
const DIM_SUFFIX: String = "_dim"
const ANIM_IDLE: StringName = &"idle"
const ANIM_TALK: StringName = &"talk"
const ANIM_NOTICE: StringName = &"notice"
const ANIM_APPEAR: StringName = &"appear"
const ANIM_DISAPPEAR: StringName = &"disappear"
const ANIM_GLOW_IN: StringName = &"glow_in"
const ANIM_GLOW_OUT: StringName = &"glow_out"
const AMBER_SUFFIX: String = "_amber"
## Opacidad de Isak por debajo de la cual ya fue absorbido por el vortice.
const ABSORBED_ALPHA: float = 0.01

## Cambia de estado (pruebas y capturas).
signal state_changed(state: State)
## Cambia el objeto con ayuda que Eco senala (null: vuelve a Isak).
signal help_target_changed(target: Node2D)

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
var _help_target: Node2D
## Hay objeto senalado (aunque se haya liberado: un objeto liberado compara
## igual a null).
var _has_help_target: bool = false
var _help_id: StringName = &""
var _help_point: Vector2 = Vector2.ZERO
var _explaining: bool = false
var _explain_wait: float = 0.0
## Vuelve de un objeto: seguimiento mas suave y sin recolocarse con destello.
var _returning: bool = false
var _glow: Glow = Glow.OFF
var _glow_time: float = 0.0
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


## Punto al que va ahora: detras y encima de Isak, junto al objeto con ayuda
## o el centro del vortice de salida mientras se va.
func get_target_position() -> Vector2:
	if not _valid_isak():
		return _anchor
	var feet: Vector2 = _isak.global_position
	if _state == State.DEPARTING:
		var center: Array = _data.get("depart_center_offset_px", [0, -48])
		return feet + Vector2(float(center[0]), float(center[1]))
	if is_helping():
		return _help_point
	return get_follow_position()


## Su sitio junto a Isak (detras y encima), sin contar la ayuda.
func get_follow_position() -> Vector2:
	if not _valid_isak():
		return _anchor
	var feet: Vector2 = _isak.global_position
	var offset: Array = _data.get("offset_px", [48, 112])
	var behind: float = float(offset[0])
	var target := Vector2(feet.x - _side * behind, feet.y - float(offset[1]))
	# Al girarse Isak, Eco cruza por encima de el.
	if behind > 0.0:
		var near: float = clampf(1.0 - absf(_anchor.x - feet.x) / behind, 0.0, 1.0)
		target.y -= float(_data.get("cross_lift_px", 20)) * near
	return target


## Objeto con ayuda que senala ahora (null si sigue a Isak).
func get_help_target() -> Node2D:
	return _help_target if _help_target != null and is_instance_valid(_help_target) else null


## Senala un objeto con ayuda o explica una: no sigue a Isak.
func is_helping() -> bool:
	return get_help_target() != null or _explaining


func is_explaining() -> bool:
	return _explaining


func get_glow() -> Glow:
	return _glow


## Brilla en ambar (o se esta encendiendo o apagando).
func is_glowing() -> bool:
	return _glow != Glow.OFF


## Nombre de la animacion que se ve de verdad (con sufijos _amber / _dim o
## glow_in / glow_out).
func get_shown_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""


## Punto donde se apoya la Q (centro en x, borde inferior en y): encima de Eco.
func get_prompt_position() -> Vector2:
	var offset: Array = _data.get("help_prompt_offset_px", [0, -34])
	return global_position + Vector2(float(offset[0]), float(offset[1]))


# --- Acciones ---

## HelpSystem le pasa el objeto con Q (null: ninguno). Mientras explica una
## ayuda no cambia. Falso si no lo acepta (oculto, hub o explicando).
func set_help_target(target: Node2D, help_id: StringName = &"") -> bool:
	if _explaining:
		return false
	if target != null and not is_instance_valid(target):
		target = null
	if target == get_help_target():
		return target != null
	if target != null and (_dim or not _can_help()):
		target = null
		if get_help_target() == null:
			return false
	if target == null:
		_end_help()
		return false
	_help_target = target
	_has_help_target = true
	_help_id = help_id if help_id != &"" else HelpCatalog.help_id_of(target)
	_returning = false
	_help_point = _compute_help_point()
	_glow_on()
	help_target_changed.emit(target)
	return true


## Se ha pedido la ayuda del objeto senalado: Eco se queda junto a el con el
## brillo mientras explica; al terminar la linea (eco_line_finished) vuelve.
func begin_help_explanation() -> void:
	if _dim or not is_shown():
		return
	_explaining = true
	_explain_wait = float(_data.get("help_explain_grace_s", 0.5))
	_glow_on()


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
	_check_help(delta)
	_advance_glow(delta)
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
			if _anchor.distance_to(get_follow_position()) > _teleport_distance():
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


func _can_help() -> bool:
	return _valid_isak() and not _isak.is_dead() and not _isak.is_warping() and _isak.is_visible_in_tree() \
			and GameSettings.is_eco_help_shown() and (_state == State.FOLLOW or _state == State.APPEARING)


## Suelta el objeto si ya no hay ayuda posible y actualiza el punto junto a el.
func _check_help(delta: float) -> void:
	if _returning and _anchor.distance_to(get_follow_position()) <= float(_data.get("help_return_done_px", 24)):
		_returning = false
	if not is_helping():
		if _has_help_target:
			_end_help()  # El objeto se libero.
		return
	if not _can_help():
		_end_help()
		return
	if _explaining:
		if _talking:
			_explain_wait = float(_data.get("help_explain_grace_s", 0.5))
		else:
			_explain_wait -= delta
			if _explain_wait <= 0.0:
				_end_help()
				return
		if get_help_target() != null:
			_help_point = _compute_help_point()
		return
	var target: Node2D = get_help_target()
	if not target.is_visible_in_tree() or not target.is_inside_tree() or get_tree().paused:
		_end_help()
		return
	_help_point = _compute_help_point()


func _end_help() -> void:
	var had: bool = _has_help_target or _explaining
	_has_help_target = false
	_help_target = null
	_help_id = &""
	_explaining = false
	if had:
		_returning = true
		if _glow == Glow.ON or _glow == Glow.IN:
			_glow = Glow.OUT
			_glow_time = 0.0
		help_target_changed.emit(null)


## Punto junto al objeto: encima de donde se apoya su Q (prompt_px), algo
## hacia el lado contrario a Isak, por encima de Isak si lo tapara y dentro de
## la pantalla.
func _compute_help_point() -> Vector2:
	var target: Node2D = get_help_target()
	if target == null:
		return _help_point
	var base: Vector2 = target.global_position + HelpCatalog.shared().prompt_offset(_help_id)
	var feet: Vector2 = _isak.global_position if _valid_isak() else base
	var side: float = signf(base.x - feet.x)
	if side == 0.0:
		side = _side
	var off: Array = _data.get("help_offset_px", [28, -44])
	var point := base + Vector2(side * float(off[0]), float(off[1]))
	var radius: float = float(_data.get("help_radius_px", 24))
	var clear: Array = _data.get("help_isak_clear_px", [36, 112])
	var body := Rect2(feet.x - float(clear[0]), feet.y - float(clear[1]), float(clear[0]) * 2.0, float(clear[1]))
	if body.grow(radius).has_point(point):
		point.y = minf(point.y, body.position.y - radius)
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var view := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
		var screen: Rect2 = viewport.get_canvas_transform().affine_inverse() * view
		var margin: Array = _data.get("help_screen_margin_px", [32, 72])
		var lo: Vector2 = screen.position + Vector2(float(margin[0]), float(margin[1]))
		var hi: Vector2 = screen.end - Vector2(float(margin[0]), float(margin[0]))
		if lo.x < hi.x and lo.y < hi.y:
			point = point.clamp(lo, hi)
	return point


func _teleport_distance() -> float:
	var base: float = float(_data.get("teleport_distance_px", 256))
	if is_helping() or _returning:
		base += float(_data.get("help_teleport_margin_px", 320))
	return base


func _glow_on() -> void:
	if _glow == Glow.OFF or _glow == Glow.OUT:
		_glow = Glow.IN
		_glow_time = 0.0


func _advance_glow(delta: float) -> void:
	if _glow == Glow.OFF or _glow == Glow.ON:
		return
	_glow_time += delta
	if _glow_time >= _anim_length(ANIM_GLOW_IN if _glow == Glow.IN else ANIM_GLOW_OUT):
		_glow = Glow.ON if _glow == Glow.IN else Glow.OFF
		_glow_time = 0.0


func _anim_length(anim: StringName) -> float:
	var frames: SpriteFrames = _sprite.sprite_frames if _sprite != null else null
	if frames == null or not frames.has_animation(anim):
		return 0.0
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.001)


func _snap_to_target() -> void:
	_anchor = get_target_position()
	_velocity = Vector2.ZERO


## Amortiguacion critica (SmoothDamp) hacia el objetivo.
func _follow(delta: float) -> void:
	if delta <= 0.0:
		return
	var target: Vector2 = get_target_position()
	var key: String = "help_smooth_time_s" if is_helping() or _returning else "smooth_time_s"
	var smooth: float = maxf(float(_data.get(key, _data.get("smooth_time_s", 0.25))), 0.0001)
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
	var time: float = _anim_time
	var frames: SpriteFrames = _sprite.sprite_frames
	if not _dim and frames != null and (_state == State.FOLLOW or _state == State.DEPARTING):
		if _glow == Glow.IN or _glow == Glow.OUT:
			var glow_anim: StringName = ANIM_GLOW_IN if _glow == Glow.IN else ANIM_GLOW_OUT
			if frames.has_animation(glow_anim):
				anim_name = glow_anim
				time = _glow_time
		elif _glow == Glow.ON:
			var amber := StringName(String(_anim) + AMBER_SUFFIX)
			if frames.has_animation(amber):
				anim_name = amber
	if frames != null and frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.animation = anim_name
		var count: int = frames.get_frame_count(anim_name)
		var fps: float = maxf(frames.get_animation_speed(anim_name), 0.001)
		var index: int = floori(time * fps)
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
	_end_help()
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
	if _explaining:
		_end_help()


func _on_help_prompt_shown(_target: Node2D) -> void:
	_notice_left = float(_data.get("notice_s", 0.3))
