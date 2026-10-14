## Isak: personaje jugable. CharacterBody2D con maquina de estados propia
## (scripts/player/states/). La fisica sale de data/isak_physics.json y las
## habilidades de data/isak_abilities.json. El input llega por PlayerInput,
## asi que las pruebas pueden inyectar una entrada falsa y llamar a step().
class_name Isak
extends CharacterBody2D

## Cambio de estado (nombres de PlayerState).
signal state_changed(previous: StringName, current: StringName)
## El pulso se ha disparado; `area` es PulseArea, activa mientras dura.
signal pulse_fired(area: Area2D)
## Isak lleva quieto mas del umbral y empieza la animacion de terminal.
signal idle_terminal_started
## Isak ha recibido un golpe.
signal hurt
## Isak ha muerto.
signal died

const ANIM_IDLE: StringName = &"idle"
const ANIM_TERMINAL: StringName = &"terminal"
const ANIM_WALK: StringName = &"walk"
const ANIM_RUN: StringName = &"run"
const ANIM_JUMP_RISE: StringName = &"jump_rise"
const ANIM_JUMP_FALL: StringName = &"jump_fall"
const ANIM_PULSE: StringName = &"pulse"

## Evita bucles si dos estados se devolvieran el control en el mismo paso.
const MAX_TRANSITIONS_PER_STEP: int = 4

const PULSE_EFFECT_SCENE: PackedScene = preload("res://scenes/player/pulse_effect.tscn")

@export_file("*.json") var physics_path: String = PlayerPhysics.DEFAULT_PATH
@export_file("*.json") var abilities_path: String = PlayerAbilities.DEFAULT_PATH
## Segundos quieto antes de la animacion de terminal (propuesta, ajustar jugando).
@export var terminal_idle_threshold_s: float = 4.0
## Tamano de la caja de colision (ancho, alto). Los pies estan en el origen.
@export var hitbox_size: Vector2 = Vector2(16.0, 40.0)
## Posicion del celular en el cuadro de pulso, mirando a la derecha (px desde los pies).
@export var pulse_effect_origin: Vector2 = Vector2(13.0, -35.0)
## Limites de la camara en px. Sin area = sin limites.
@export var camera_limits: Rect2i = Rect2i()

var physics: PlayerPhysics
var abilities: PlayerAbilities
## Fuente de intenciones. Si es null al entrar en el arbol se usa el Input Map.
var input: PlayerInput
## 1.0 = mira a la derecha, -1.0 = izquierda.
var facing: float = 1.0

var _states: Dictionary[StringName, PlayerState] = {}
var _state: PlayerState
var _state_name: StringName = PlayerState.NONE
var _jump_buffer_left: float = 0.0
var _coyote_left: float = 0.0
var _invulnerable_left: float = 0.0
var _idle_time: float = 0.0
var _terminal_playing: bool = false
var _knockback_direction: float = 0.0
var _ready_ok: bool = false
var _pulse_effect: PulseEffect

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: CollisionShape2D = $Hitbox
@onready var _pulse_area: Area2D = $PulseArea
@onready var _pulse_shape: CollisionShape2D = $PulseArea/CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	physics = PlayerPhysics.load_from_file(physics_path)
	abilities = PlayerAbilities.load_from_file(abilities_path)
	if physics == null or abilities == null:
		push_error("Isak: no se pudieron cargar los datos; Isak queda desactivado.")
		set_physics_process(false)
		return
	if input == null:
		input = ActionPlayerInput.new()
	_setup_shapes()
	_setup_camera()
	_states = {
		PlayerState.IDLE: IdleState.new(self),
		PlayerState.RUN: RunState.new(self),
		PlayerState.JUMP: JumpState.new(self),
		PlayerState.FALL: FallState.new(self),
		PlayerState.PULSE: PulseState.new(self),
		PlayerState.HURT: HurtState.new(self),
		PlayerState.DEAD: DeadState.new(self),
	}
	EventBus.sync_rate_changed.connect(_on_sync_rate_changed)
	_ready_ok = true
	change_state(PlayerState.IDLE)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso de simulacion completo. Publico para poder avanzar con delta fijo en pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	input.poll()
	_update_timers(delta)
	for i: int in MAX_TRANSITIONS_PER_STEP:
		var next: StringName = _state.get_transition()
		if next == PlayerState.NONE:
			break
		change_state(next)
	_state.physics_update(delta)
	move_and_slide()
	_update_coyote(delta)


func change_state(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("Isak: estado desconocido '%s'." % state_name)
		return
	var previous: StringName = _state_name
	if _state != null:
		_state.exit()
	_state = _states[state_name]
	_state_name = state_name
	_state.enter()
	state_changed.emit(previous, state_name)


func get_state_name() -> StringName:
	return _state_name


# --- Consultas que usan los estados ---

func has_move_input() -> bool:
	return not is_zero_approx(input.move_axis)


func wants_jump() -> bool:
	return _jump_buffer_left > 0.0


func can_jump() -> bool:
	return is_on_floor() or _coyote_left > 0.0


func can_pulse() -> bool:
	return is_on_floor() and GameState.is_ability_unlocked(GameState.ABILITY_PULSE)


func is_dead() -> bool:
	return _state_name == PlayerState.DEAD


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


# --- Fisica comun ---

## Acelera hacia axis * velocidad (caminar o correr). Con axis 0 aplica friccion.
## En el aire usa air_acceleration en ambos casos.
func apply_horizontal(axis: float, delta: float) -> void:
	if not is_zero_approx(axis):
		facing = signf(axis)
		_sprite.flip_h = facing < 0.0
	var speed: float = physics.run_speed if input.run_held else physics.walk_speed
	var rate: float = physics.air_acceleration
	if is_on_floor():
		rate = physics.ground_friction if is_zero_approx(axis) else physics.ground_acceleration
	velocity.x = move_toward(velocity.x, axis * speed, rate * delta)


## Gravedad normal al subir y multiplicada al caer.
func apply_gravity(delta: float) -> void:
	var g: float = physics.gravity
	if velocity.y >= 0.0:
		g *= physics.fall_gravity_multiplier
	velocity.y += g * delta


func start_jump() -> void:
	velocity.y = physics.jump_velocity
	_jump_buffer_left = 0.0
	_coyote_left = 0.0


func apply_knockback() -> void:
	velocity = Vector2(_knockback_direction * abilities.hurt_knockback_x, abilities.hurt_knockback_y)


# --- Dano y muerte ---

## Recibe un golpe. `direction` es hacia donde sale despedido (-1/1); 0 = hacia atras.
## Devuelve false si se ignora (muerto o invulnerable).
func take_hit(direction: float = 0.0) -> bool:
	if is_dead() or is_invulnerable() or not _ready_ok:
		return false
	_knockback_direction = signf(direction) if not is_zero_approx(direction) else -facing
	_invulnerable_left = abilities.hurt_invulnerability_s
	change_state(PlayerState.HURT)
	hurt.emit()
	return true


func die() -> void:
	if is_dead() or not _ready_ok:
		return
	change_state(PlayerState.DEAD)


## Lo llama DeadState al entrar.
func notify_died() -> void:
	died.emit()
	EventBus.player_died.emit()


# --- Tiempo quieto (Idle) ---

## Segundos que Isak lleva quieto en Idle sin input. Lo leen otros sistemas.
func get_idle_time() -> float:
	return _idle_time


func add_idle_time(delta: float) -> void:
	_idle_time += delta
	if not _terminal_playing and _idle_time >= terminal_idle_threshold_s:
		_terminal_playing = true
		play_animation(ANIM_TERMINAL)
		idle_terminal_started.emit()


func reset_idle_time() -> void:
	_idle_time = 0.0
	_terminal_playing = false


func is_terminal_playing() -> bool:
	return _terminal_playing


# --- Pulso ---

func set_pulse_area_active(active: bool) -> void:
	_pulse_shape.set_deferred(&"disabled", not active)
	if active:
		pulse_fired.emit(_pulse_area)


## Crea la onda visual del pulso en el celular. Lo llama PulseState al entrar.
func start_pulse_effect() -> void:
	stop_pulse_effect()
	_pulse_effect = PULSE_EFFECT_SCENE.instantiate() as PulseEffect
	_pulse_effect.setup(abilities.pulse_radius_px, abilities.pulse_duration_s)
	_pulse_effect.position = Vector2(pulse_effect_origin.x * facing, pulse_effect_origin.y)
	add_child(_pulse_effect)


func advance_pulse_effect(delta: float) -> void:
	if _pulse_effect != null:
		_pulse_effect.advance(delta)


## Libera la onda. Lo llama PulseState al salir (tambien si un golpe lo corta).
func stop_pulse_effect() -> void:
	if _pulse_effect != null and is_instance_valid(_pulse_effect):
		_pulse_effect.queue_free()
	_pulse_effect = null


## Onda activa o null.
func get_pulse_effect() -> PulseEffect:
	return _pulse_effect


# --- Presentacion ---

func play_animation(anim: StringName) -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _setup_shapes() -> void:
	var capsule := CapsuleShape2D.new()
	capsule.radius = hitbox_size.x * 0.5
	capsule.height = hitbox_size.y
	_hitbox.shape = capsule
	_hitbox.position = Vector2(0.0, -hitbox_size.y * 0.5)
	var circle := CircleShape2D.new()
	circle.radius = abilities.pulse_radius_px
	_pulse_shape.shape = circle
	_pulse_shape.disabled = true
	_pulse_area.position = Vector2(0.0, -hitbox_size.y * 0.5)


func _setup_camera() -> void:
	if not camera_limits.has_area():
		return
	_camera.limit_left = camera_limits.position.x
	_camera.limit_top = camera_limits.position.y
	_camera.limit_right = camera_limits.end.x
	_camera.limit_bottom = camera_limits.end.y


func _update_timers(delta: float) -> void:
	if input.jump_pressed:
		_jump_buffer_left = physics.jump_buffer_s
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func _update_coyote(delta: float) -> void:
	if is_on_floor():
		_coyote_left = physics.coyote_time_s
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)


func _on_sync_rate_changed(new_value: float, _max_value: float) -> void:
	if new_value <= GameState.SYNC_RATE_MIN:
		die()
