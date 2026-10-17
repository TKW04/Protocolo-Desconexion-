## Recordatorio (tipo `reminder_platform` del catalogo del Mundo 1; piso 3 del
## 1-2 y patron 3 «Posponer» de docs/propuesta-1-2.md §0.4 y §3.3; paso 6 de
## §10; docs/mundo-1-notificaciones.md §6.2: «plataforma con temporizador que
## cae cuando vence»).
##
## - Plataforma SOLIDA (capa world, no de una via) de width_tiles x 1 con la
##   tarjeta de card_height_px arriba de su celda.
## - Grupo (group_id): al pisar cualquier recordatorio en reposo del grupo
##   empieza la cuenta de timer_s de TODOS los del grupo que esten en reposo
##   (cuenta compartida: empiezan a la vez y van igual).
## - Cuenta en TIEMPO DEL MUNDO (el Debug la alarga x2; la pausa la para). Un
##   indicador de SEG_COUNT segmentos muestra lo que queda. Los ultimos warn_s
##   (6-12 cuadros a 12 fps; el esquema lo comprueba) avisa: el despertador
##   suena, la tarjeta parpadea y tiembla.
## - Al vencer CAE: deja de ser solida al instante (Isak cae al suelo de
##   debajo, sin dano) y se ve caer y romperse. Vuelve a su sitio a los
##   respawn_s (si Isak no esta donde vuelve) con una animacion de reposicion.
## - Posponer (SnoozeButton.extend): mientras cuenta, suma tiempo con tope.
## - Al reaparecer Isak (EventBus.player_respawned) vuelve a su estado inicial.
## El origen del nodo es la esquina superior izquierda de su primera celda.
class_name ReminderPlatform
extends StaticBody2D

enum State { IDLE, COUNTING, FALLING, GONE, RESPAWNING }

const GROUP: StringName = &"reminder_platform"
const LAYER_WORLD: int = 1
const SEG_COUNT: int = 4

## Ha empezado la cuenta (este recordatorio).
signal countdown_started(seconds: float)
## El Posponer le ha sumado tiempo (lo que queda ahora).
signal snoozed(seconds_left: float)
## Empiezan los ultimos warn_s.
signal warning_started
## Ha vencido: deja de ser solido y cae.
signal fell
## Ha vuelto a su sitio (solido, en reposo).
signal respawned

@export var object_id: StringName = &""
## Grupo de cuenta compartida (params.group).
@export var group_id: StringName = &""
@export_range(1, 3) var width_tiles: int = 2
## Segundos de cuenta (tiempo del mundo).
@export var timer_s: float = 2.5
## Ultimos segundos de aviso antes de caer.
@export var warn_s: float = 0.5
## Segundos caido antes de volver.
@export var respawn_s: float = 3.0

var _config: Dictionary = World1ObjectsConfig.section("reminder_platform")
var _state: State = State.IDLE
## Cuenta compartida del grupo: {left, reference, owner, snooze}. La crea quien
## arranca la cuenta y la comparten (por referencia) los que empiezan con el;
## solo la descuenta su duenio (owner), asi van exactamente igual.
var _clock: Dictionary = {}
var _warned: bool = false
var _state_time: float = 0.0
var _time: float = 0.0
var _zz_left: float = 0.0
var _falls: int = 0
var _shape: CollisionShape2D
var _sprite: AnimatedSprite2D
var _segments: Node2D
var _zz: AnimatedSprite2D
var _frames: SpriteFrames
var _isak: Isak


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_frames = load(String(_config.get("frames", ""))) as SpriteFrames
	var size: Vector2 = get_card_size()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	add_child(_shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = _frames
	_sprite.centered = false
	add_child(_sprite)
	_segments = Node2D.new()
	_segments.name = "Segments"
	_segments.draw.connect(_draw_segments)
	_sprite.add_child(_segments)
	_zz = AnimatedSprite2D.new()
	_zz.name = "Zz"
	_zz.sprite_frames = _frames
	_zz.animation = &"reminder_zz"
	_zz.centered = true
	_zz.position = Vector2(size.x - 10.0, -14.0)
	_zz.visible = false
	add_child(_zz)
	EventBus.player_respawned.connect(_on_player_respawned)
	_update_visual()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


func is_counting() -> bool:
	return _state == State.COUNTING


func is_warning() -> bool:
	return _state == State.COUNTING and _left() <= warn_s


## Solido y visible (en reposo o contando).
func is_solid() -> bool:
	return _state == State.IDLE or _state == State.COUNTING


## Segundos que quedan de cuenta (0 si no cuenta).
func get_time_left() -> float:
	return _left() if _state == State.COUNTING else 0.0


## Segmentos encendidos del indicador (SEG_COUNT en reposo).
func get_lit_segments() -> int:
	match _state:
		State.IDLE:
			return SEG_COUNT
		State.COUNTING:
			var reference: float = float(_clock.get("reference", timer_s))
			return clampi(ceili(SEG_COUNT * _left() / maxf(reference, 0.001) - 0.0001), 0, SEG_COUNT)
	return 0


func get_fall_count() -> int:
	return _falls


## Tarjeta (y colision) en px: width_tiles x card_height_px.
func get_card_size() -> Vector2:
	return Vector2(width_tiles * World1ObjectsConfig.tile_size(), float(_config.get("card_height_px", 32)))


func get_card_rect() -> Rect2:
	return Rect2(global_position, get_card_size())


## Ayuda de Eco (HelpCatalog.is_help_live): caido (o volviendo) no esta; en
## reposo o contando, si.
func is_help_available() -> bool:
	return is_solid()


## Los demas recordatorios del mismo grupo (y del mismo nivel), incluido este.
func get_group_members() -> Array[ReminderPlatform]:
	var out: Array[ReminderPlatform] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as ReminderPlatform
		if other != null and other.group_id == group_id and other.get_parent() == get_parent():
			out.append(other)
	return out


# --- Acciones ---

## Isak lo ha pisado: empieza la cuenta del grupo (los que esten en reposo),
## compartida. Verdadero si ha empezado ahora.
func trigger() -> bool:
	if _state != State.IDLE:
		return false
	var clock: Dictionary = {"left": timer_s, "reference": timer_s, "owner": self, "snooze": -1}
	for member: ReminderPlatform in get_group_members():
		member._start_with(clock)
	return true


## Empieza la cuenta de este recordatorio solo (sin efecto si no esta en reposo).
func start_countdown() -> void:
	_start_with({"left": timer_s, "reference": timer_s, "owner": self, "snooze": -1})


## Posponer: suma `extra` segundos a la cuenta (compartida) sin pasar de `cap`
## (si ya tenia mas, no cambia); `snooze_id` evita sumar dos veces el mismo
## impacto a una cuenta compartida. Solo contando; verdadero si estaba contando.
func extend(extra: float, cap: float, snooze_id: int = -1) -> bool:
	if _state != State.COUNTING:
		return false
	if snooze_id < 0 or int(_clock.get("snooze", -1)) != snooze_id:
		_clock["snooze"] = snooze_id
		var left: float = _left()
		_clock["left"] = maxf(left, minf(left + extra, cap))
		_clock["reference"] = maxf(float(_clock["left"]), timer_s)
	_warned = is_warning()
	_zz_left = float(_config.get("zz_s", 0.8))
	_update_visual()
	snoozed.emit(_left())
	return true


## Vence ya (pruebas y herramientas): cae con todo su grupo.
func expire() -> void:
	if _state == State.COUNTING:
		_clock["left"] = 0.0
		_fall_group()


## Vuelve al estado inicial: en su sitio, solido y en reposo.
func reset() -> void:
	_clock = {}
	_warned = false
	_zz_left = 0.0
	_set_state(State.IDLE)
	_shape.disabled = false


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += dt
	_state_time += dt
	if _zz_left > 0.0:
		_zz_left = maxf(_zz_left - dt, 0.0)
	match _state:
		State.IDLE:
			if _isak_standing():
				trigger()
		State.COUNTING:
			if _clock.get("owner") == self:
				_clock["left"] = maxf(_left() - dt, 0.0)
				if _left() <= 0.0:
					_fall_group()
			elif _left() <= 0.0:
				_fall()
			if _state == State.COUNTING and is_warning() and not _warned:
				_warned = true
				warning_started.emit()
		State.FALLING:
			if _state_time >= _anim_length(_anim(&"fall")):
				_set_state(State.GONE)
		State.GONE:
			if _state_time >= respawn_s and not _isak_overlaps():
				_set_state(State.RESPAWNING)
		State.RESPAWNING:
			if _state_time >= _anim_length(_anim(&"respawn")):
				_shape.disabled = false
				_set_state(State.IDLE)
				respawned.emit()
	_update_visual()


# --- Interno ---

func _left() -> float:
	return float(_clock.get("left", 0.0))


func _start_with(clock: Dictionary) -> void:
	if _state != State.IDLE:
		return
	_clock = clock
	_warned = false
	_set_state(State.COUNTING)
	countdown_started.emit(_left())


## Caen todos los que comparten esta cuenta.
func _fall_group() -> void:
	var clock: Dictionary = _clock
	for member: ReminderPlatform in get_group_members():
		if is_same(member._clock, clock) and member._state == State.COUNTING:
			member._fall()
	if _state == State.COUNTING:
		_fall()


func _fall() -> void:
	_falls += 1
	_shape.disabled = true
	_set_state(State.FALLING)
	fell.emit()


func _set_state(next: State) -> void:
	_state = next
	_state_time = 0.0
	_update_visual()


func _anim(state: StringName) -> StringName:
	return StringName("reminder_w%d_%s" % [clampi(width_tiles, 1, 3), state])


func _anim_length(anim: StringName) -> float:
	if _frames == null or not _frames.has_animation(anim):
		return 0.25
	return _frames.get_frame_count(anim) / maxf(_frames.get_animation_speed(anim), 0.01)


func _frame_at(anim: StringName, t: float) -> int:
	var count: int = _frames.get_frame_count(anim)
	var f: int = floori(t * _frames.get_animation_speed(anim))
	return f % count if _frames.get_animation_loop(anim) else mini(f, count - 1)


func _update_visual() -> void:
	if _sprite == null or _frames == null:
		return
	var anim: StringName
	var t: float = _state_time
	_sprite.visible = true
	_sprite.position = Vector2.ZERO
	match _state:
		State.IDLE:
			anim = _anim(&"idle")
			t = _time
		State.COUNTING:
			anim = _anim(&"warn") if is_warning() else _anim(&"idle")
			t = _time
			if is_warning():
				var shake: float = float(_config.get("shake_px", 2.0))
				_sprite.position.x = shake if _frame_at(anim, t) == 0 else -shake
		State.FALLING:
			anim = _anim(&"fall")
			_sprite.position.y = float(_config.get("fall_drop_px", 48.0)) * clampf(
				_state_time / maxf(_anim_length(anim), 0.01), 0.0, 1.0)
		State.GONE:
			anim = _anim(&"fall")
			_sprite.visible = false
		State.RESPAWNING:
			anim = _anim(&"respawn")
	_sprite.animation = anim
	_sprite.frame = _frame_at(anim, t)
	_segments.visible = _state == State.IDLE or _state == State.COUNTING
	_segments.queue_redraw()
	_zz.visible = _zz_left > 0.0 and _state == State.COUNTING
	if _zz.visible:
		_zz.frame = _frame_at(&"reminder_zz", _time)


func _draw_segments() -> void:
	if _frames == null:
		return
	var origin: Array = _config.get("segments_px", [23, 14])
	var step: float = float(_config.get("segment_step_px", 9))
	var lit: int = get_lit_segments()
	var warn: bool = is_warning()
	var blink_on: bool = int(floorf(_time * 12.0)) % 2 == 0
	for i: int in SEG_COUNT:
		var frame: int = 0
		if i < lit:
			frame = 2 if warn and blink_on else 1
		var tex: Texture2D = _frames.get_frame_texture(&"reminder_seg", frame)
		_segments.draw_texture(tex, Vector2(float(origin[0]) + step * i, float(origin[1])))


## Isak de pie encima de la tarjeta (en el suelo, pies a ras de su borde de arriba).
func _isak_standing() -> bool:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	if _isak == null or not _isak.is_on_floor() or _isak.is_dead():
		return false
	var feet: Vector2 = _isak.global_position
	var rect: Rect2 = get_card_rect()
	var tolerance: float = float(_config.get("stand_tolerance_px", 6.0))
	var half: float = _isak.hitbox_size.x * 0.5
	return absf(feet.y - rect.position.y) <= tolerance \
			and feet.x + half > rect.position.x and feet.x - half < rect.end.x


## Isak ocupa el sitio donde volveria (no aparece encima de el).
func _isak_overlaps() -> bool:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	if _isak == null:
		return false
	return LevelLookup.isak_body_rect(_isak).intersects(get_card_rect())


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()
