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
## Sale un disparo del laser (tras la anticipacion).
signal laser_fired(projectile: LaserProjectile)
## Intento de laser sin energia suficiente: no sale el disparo.
signal laser_denied
## Isak ya se ve tras empezar una llegada oculta (begin_warp(true)): las lineas
## de Eco que esperaban a que apareciera ya pueden salir.
signal warp_revealed

## Nombres de animacion de scenes/player/isak_frames.tres (los fija
## tools/build_isak_frames.gd, con sus fps).
const ANIM_IDLE: StringName = &"idle"
const ANIM_TERMINAL_INTRO: StringName = &"terminal_intro"
const ANIM_TERMINAL_LOOP: StringName = &"terminal_loop"
const ANIM_TERMINAL_OUTRO: StringName = &"terminal_outro"
const ANIM_WALK: StringName = &"walk"
const ANIM_RUN: StringName = &"run"
const ANIM_JUMP_RISE: StringName = &"jump_rise"
const ANIM_JUMP_APEX: StringName = &"jump_apex"
const ANIM_JUMP_FALL: StringName = &"jump_fall"
const ANIM_JUMP_LAND: StringName = &"jump_land"
const ANIM_PULSE: StringName = &"pulse"
const ANIM_HURT: StringName = &"hurt"
const ANIM_DEATH: StringName = &"death"
## Pose del laser: cuadros del pulso en que sube el celular (6, 5 y 0, ver
## DERIVED en tools/build_isak_frames.gd). Isak elige el cuadro.
const ANIM_LASER: StringName = &"laser"
## Pose estatica de espaldas (un cuadro, isak_back_idle_00.png): Isak mira al
## fondo (p. ej. al monitor de la terminal de salida). La ponen face_back() y
## face_side().
const ANIM_BACK_IDLE: StringName = &"back_idle"
## Estados en los que la pose del laser se corta (tienen animacion propia).
const LASER_POSE_BREAKING_STATES: Array[StringName] = [PlayerState.PULSE, PlayerState.HURT, PlayerState.DEAD]
## Margen al pasar del tiempo de anticipacion al cuadro de la pose.
const LASER_POSE_EPS: float = 0.0001
## Cuadro de la animacion de pulso en el que nace la onda (celular al frente).
const PULSE_WAVE_FRAME: int = 0
## Velocidad vertical (px/s, valor absoluto) por debajo de la cual se muestra el
## apogeo del salto; por encima, subida o caida. Solo visual.
const AIR_APEX_SPEED: float = 240.0
## Parpadeo durante la invulnerabilidad: periodo (s) y opacidad del medio ciclo apagado.
const BLINK_PERIOD_S: float = 0.12
const BLINK_ALPHA: float = 0.35

## Evita bucles si dos estados se devolvieran el control en el mismo paso.
const MAX_TRANSITIONS_PER_STEP: int = 4

const PULSE_EFFECT_SCENE: PackedScene = preload("res://scenes/player/pulse_effect.tscn")
const LASER_PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/laser_projectile.tscn")
## Tolerancia al comparar la energia con el coste del laser.
const LASER_ENERGY_EPS: float = 0.0001

@export_file("*.json") var physics_path: String = PlayerPhysics.DEFAULT_PATH
@export_file("*.json") var abilities_path: String = PlayerAbilities.DEFAULT_PATH
## Segundos quieto antes de la animacion de terminal (propuesta, ajustar jugando).
@export var terminal_idle_threshold_s: float = 4.0
## Tamano de la capsula de colision (ancho, alto) en px a 1280x720. Los pies
## estan en el origen.
@export var hitbox_size: Vector2 = Vector2(32.0, 80.0)
## Posicion del celular en el cuadro de pulso, mirando a la derecha (px desde
## los pies). La onda visual y PulseArea nacen aqui (ver get_pulse_origin()).
## Medido en isak_pulse_00.png (brazo extendido): celular en (36, -56).
@export var pulse_effect_origin: Vector2 = Vector2(36.0, -56.0)
## Celular en cada cuadro de la pose del laser (ANIM_LASER), mirando a la
## derecha, en px desde los pies. Medido en isak_pulse_06/05/00.png (frente
## del celular). El ultimo es pulse_effect_origin: el disparo sale con el brazo
## extendido, en el mismo punto que la onda del pulso. El destello de la
## anticipacion y el proyectil nacen aqui (ver get_laser_origin()).
@export var laser_pose_phone_offsets: Array[Vector2] = [Vector2(22.0, -61.0), Vector2(25.0, -60.0), Vector2(36.0, -56.0)]
## Segundos que Isak mantiene el brazo extendido tras disparar (solo visual;
## menor que laser_cooldown_s para que al caminar no patine mucho).
@export var laser_pose_hold_s: float = 0.25
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
## El ultimo cambio de estado fue un aterrizaje (Fall -> Idle).
var _landed: bool = false
var _ready_ok: bool = false
var _pulse_effect: PulseEffect
## Laser: enfriamiento restante y anticipacion pendiente (< 0 = sin disparo en
## camino). Tiempo real, como el resto de Isak.
var _laser_cooldown_left: float = 0.0
var _laser_windup_left: float = -1.0
var _laser_muzzle: LaserMuzzle
## Pose del laser: tiempo restante con el brazo extendido tras el disparo
## (< 0 = sin pose) y cuadro mostrado de ANIM_LASER (-1 = sin pose).
var _laser_pose_hold_left: float = -1.0
var _laser_pose_frame: int = -1
## Llegada o salida en curso (begin_warp/end_warp): control bloqueado (entrada
## neutra) y sin recibir golpes. _warp_hidden: aun no se ha mostrado.
var _warping: bool = false
var _warp_hidden: bool = false
## Entrada quieta que ven los estados mientras dura la llegada o la salida.
var _warp_input := PlayerInput.new()
## De espaldas (face_back/face_side): pose ANIM_BACK_IDLE, control bloqueado
## (entrada quieta, como en el vortice) y sin recibir golpes.
var _facing_back: bool = false

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
	# Mejoras permanentes compradas (p. ej. "Pulso amplio"): cambian el valor
	# efectivo; data/isak_abilities.json no se toca.
	GameState.apply_upgrades(abilities, "isak_abilities")
	if input == null:
		input = ActionPlayerInput.new()
	_setup_shapes()
	_setup_camera()
	_laser_muzzle = LaserMuzzle.new()
	_laser_muzzle.name = "LaserMuzzle"
	_laser_muzzle.configure(abilities.laser_visual)
	add_child(_laser_muzzle)
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
	_sprite.animation_finished.connect(_on_animation_finished)
	_ready_ok = true
	change_state(PlayerState.IDLE)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso de simulacion completo. Publico para poder avanzar con delta fijo en pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	input.poll()
	# Durante la llegada o la salida los estados ven una entrada quieta; la del
	# jugador (o la falsa de las pruebas) se sigue leyendo y se repone al final.
	var source: PlayerInput = input
	if _warping or _facing_back:
		input = _warp_input
	_update_timers(delta)
	for i: int in MAX_TRANSITIONS_PER_STEP:
		var next: StringName = _state.get_transition()
		if next == PlayerState.NONE:
			break
		change_state(next)
	_state.physics_update(delta)
	move_and_slide()
	_update_coyote(delta)
	_update_laser(delta)
	_update_blink()
	if input == _warp_input:
		input = source


func change_state(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("Isak: estado desconocido '%s'." % state_name)
		return
	var previous: StringName = _state_name
	if state_name in LASER_POSE_BREAKING_STATES:
		_end_laser_pose(false)
	if _state != null:
		_state.exit()
	_state = _states[state_name]
	_state_name = state_name
	_landed = previous == PlayerState.FALL and state_name == PlayerState.IDLE
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


## El laser se puede usar: desbloqueado (GameState.ABILITY_LASER), vivo y sin
## estar recibiendo un golpe. Vale en el suelo y en el aire.
func can_laser() -> bool:
	return _ready_ok and GameState.is_ability_unlocked(GameState.ABILITY_LASER) \
			and not is_dead() and _state_name != PlayerState.HURT


func get_laser_cooldown_left() -> float:
	return _laser_cooldown_left


## Verdadero mientras la anticipacion del laser esta en curso.
func is_laser_charging() -> bool:
	return _laser_windup_left >= 0.0


func get_laser_muzzle() -> LaserMuzzle:
	return _laser_muzzle


## Verdadero mientras Isak muestra la pose del laser (sube el celular o lo
## mantiene extendido tras el disparo). Solo visual.
func is_laser_posing() -> bool:
	return _laser_pose_frame >= 0


## Celular de la pose del laser (cuadro actual) relativo a los pies, segun
## hacia donde mira Isak. Sin pose: el del brazo extendido (ultimo cuadro).
func get_laser_origin() -> Vector2:
	var offsets: Array[Vector2] = laser_pose_phone_offsets
	if offsets.is_empty():
		return get_pulse_origin()
	var index: int = clampi(_laser_pose_frame, 0, offsets.size() - 1) if is_laser_posing() else offsets.size() - 1
	return Vector2(offsets[index].x * facing, offsets[index].y)


func is_dead() -> bool:
	return _state_name == PlayerState.DEAD


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Verdadero si se acaba de entrar en Idle aterrizando (lo usa IdleState).
func just_landed() -> bool:
	return _landed


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
	if is_dead() or is_invulnerable() or _warping or _facing_back or not _ready_ok:
		return false
	_knockback_direction = signf(direction) if not is_zero_approx(direction) else -facing
	_invulnerable_left = abilities.hurt_invulnerability_s
	change_state(PlayerState.HURT)
	hurt.emit()
	return true


func die() -> void:
	if is_dead() or not _ready_ok:
		return
	_clear_back_pose()
	change_state(PlayerState.DEAD)


## Reaparece en `at` (pies) tras morir o caer fuera del nivel (lo llama
## LevelRunner): quieto, vivo y con `invulnerable_s` de invulnerabilidad (con
## el mismo parpadeo que tras un golpe). No toca el Sync Rate (GameState).
func respawn(at: Vector2, invulnerable_s: float = 0.0) -> void:
	if not _ready_ok:
		return
	global_position = at
	velocity = Vector2.ZERO
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	_knockback_direction = 0.0
	_invulnerable_left = maxf(invulnerable_s, 0.0)
	modulate.a = 1.0
	stop_pulse_effect()
	set_pulse_area_active(false)
	_cancel_laser()
	_end_laser_pose(false)
	_laser_cooldown_left = 0.0
	_clear_back_pose()
	reset_idle_time()
	change_state(PlayerState.IDLE)
	play_animation(ANIM_IDLE)
	_camera.reset_smoothing()
	_update_blink()


# --- Llegada y salida (fundido de LevelRunner, vortice WarpVortex) ---

## Empieza una llegada o salida: el control queda bloqueado (los estados ven una
## entrada quieta; la fisica sigue) y los golpes no le hacen nada. `hidden`:
## Isak aun no se ha mostrado al jugador (llegada); las lineas de Eco de zona
## esperan a warp_revealed.
func begin_warp(hidden: bool = true) -> void:
	_warping = true
	_warp_hidden = hidden


## Isak ya se ve: emite warp_revealed (una vez por llegada). El control sigue
## bloqueado hasta end_warp().
func reveal_warp() -> void:
	if not _warp_hidden:
		return
	_warp_hidden = false
	warp_revealed.emit()


## Termina la llegada o salida: devuelve el control (y revela si faltaba).
func end_warp() -> void:
	_warping = false
	reveal_warp()


## Llegada o salida en curso (control bloqueado).
func is_warping() -> bool:
	return _warping


## Llegada en curso en la que Isak aun no se ha mostrado.
func is_warp_hidden() -> bool:
	return _warp_hidden


# --- Pose de espaldas (terminal de salida; pensada tambien para el hub) ---

## Pone a Isak de espaldas (ANIM_BACK_IDLE, sin voltear): queda quieto (los
## estados ven una entrada quieta; la gravedad sigue) y no recibe golpes hasta
## face_side(). Corta el laser y la terminal holografica. Falso si no se puede
## (muerto, sin datos o ya de espaldas).
func face_back() -> bool:
	if not _ready_ok or is_dead() or _facing_back:
		return false
	_cancel_laser()
	_end_laser_pose(false)
	reset_idle_time()
	_facing_back = true
	velocity.x = 0.0
	_sprite.flip_h = false
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames != null and frames.has_animation(ANIM_BACK_IDLE):
		_sprite.play(ANIM_BACK_IDLE)
		_sprite.set_frame_and_progress(0, 0.0)
	return true


## Vuelve de perfil (hacia `facing`) con la animacion del estado actual y
## devuelve el control (salvo que siga una llegada o salida). Falso si no
## estaba de espaldas.
func face_side() -> bool:
	if not _facing_back:
		return false
	_clear_back_pose()
	reset_idle_time()
	_restore_state_animation()
	return true


## Isak esta de espaldas (face_back).
func is_facing_back() -> bool:
	return _facing_back


func _clear_back_pose() -> void:
	_facing_back = false
	if _sprite != null:
		_sprite.flip_h = facing < 0.0


## Lo llama DeadState al entrar.
func notify_died() -> void:
	died.emit()
	EventBus.player_died.emit()


# --- Tiempo quieto (Idle) ---

## Segundos que Isak lleva quieto en Idle sin input. Lo leen otros sistemas.
func get_idle_time() -> float:
	return _idle_time


func add_idle_time(delta: float) -> void:
	# De espaldas no cuenta: la terminal holografica no se ve en esa pose.
	if _facing_back:
		return
	_idle_time += delta
	if not _terminal_playing and _idle_time >= terminal_idle_threshold_s:
		_terminal_playing = true
		play_animation(ANIM_TERMINAL_INTRO)
		idle_terminal_started.emit()


func reset_idle_time() -> void:
	_idle_time = 0.0
	_terminal_playing = false


func is_terminal_playing() -> bool:
	return _terminal_playing


## Corta la terminal por input sin cambiar de estado: si el holograma estaba a
## la vista, reproduce la salida y luego vuelve a idle. Reinicia el tiempo quieto.
func cut_terminal() -> void:
	if _terminal_playing:
		var anim: StringName = _sprite.animation
		if anim == ANIM_TERMINAL_INTRO or anim == ANIM_TERMINAL_LOOP:
			play_animation(ANIM_TERMINAL_OUTRO)
		else:
			play_animation(ANIM_IDLE)
	reset_idle_time()


# --- Pulso ---

## Centro del pulso (celular) relativo a los pies, segun hacia donde mira Isak.
## Lo comparten PulseArea (zona de golpe) y la onda visual.
func get_pulse_origin() -> Vector2:
	return Vector2(pulse_effect_origin.x * facing, pulse_effect_origin.y)


func set_pulse_area_active(active: bool) -> void:
	_pulse_shape.set_deferred(&"disabled", not active)
	if active:
		_pulse_area.position = get_pulse_origin()
		pulse_fired.emit(_pulse_area)
		EventBus.pulse_fired.emit(_pulse_area)


## Crea la onda visual del pulso en el celular. Lo llama PulseState al entrar.
func start_pulse_effect() -> void:
	stop_pulse_effect()
	_pulse_effect = PULSE_EFFECT_SCENE.instantiate() as PulseEffect
	_pulse_effect.setup(abilities.pulse_radius_px, abilities.pulse_duration_s)
	_pulse_effect.position = get_pulse_origin()
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


# --- Laser (2026-10-15, data/isak_abilities.json laser_*) ---

## Pulsar laser: si hay energia suficiente empieza la anticipacion
## (laser_windup_s) y despues sale el disparo; si no, chispa y laser_denied.
## Cualquiera de los dos inicia el enfriamiento (laser_cooldown_s).
func _update_laser(delta: float) -> void:
	_laser_cooldown_left = maxf(_laser_cooldown_left - delta, 0.0)
	_update_laser_pose_hold(delta)
	if is_laser_charging():
		if not can_laser():
			_cancel_laser()
			_end_laser_pose(true)
		else:
			_laser_windup_left -= delta
			if _laser_windup_left <= 0.0:
				_laser_windup_left = -1.0
				_fire_laser()
			else:
				_show_laser_pose_frame(_windup_pose_frame())
	elif input.laser_pressed and _laser_cooldown_left <= 0.0 and can_laser():
		_laser_cooldown_left = abilities.laser_cooldown_s
		if not _has_laser_energy():
			_deny_laser()
		elif abilities.laser_windup_s <= 0.0:
			_fire_laser()
		else:
			_laser_windup_left = abilities.laser_windup_s
			# Si el brazo ya estaba extendido (disparos seguidos) no vuelve a subir.
			_show_laser_pose_frame(_windup_pose_frame())
			_laser_muzzle.show_charge(abilities.laser_windup_s, facing)
	if _laser_muzzle != null:
		_laser_muzzle.position = get_laser_origin()
		_laser_muzzle.advance(delta)


## Cuadro de la pose durante la anticipacion: sube el celular a lo largo de
## laser_windup_s y llega al ultimo cuadro (brazo extendido) al disparar.
func _windup_pose_frame() -> int:
	var count: int = laser_pose_phone_offsets.size()
	if is_laser_posing() and _laser_pose_frame >= count - 1:
		return count - 1
	var done: float = 1.0 - clampf(_laser_windup_left / maxf(abilities.laser_windup_s, LASER_POSE_EPS), 0.0, 1.0)
	return clampi(floori(done * count + LASER_POSE_EPS), 0, count - 1)


## Muestra el cuadro `index` de ANIM_LASER (sin reproducir: Isak lo elige).
func _show_laser_pose_frame(index: int) -> void:
	_laser_pose_frame = index
	_laser_pose_hold_left = -1.0
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(ANIM_LASER):
		return
	if _sprite.animation != ANIM_LASER:
		_sprite.animation = ANIM_LASER
	_sprite.pause()
	_sprite.frame = clampi(index, 0, frames.get_frame_count(ANIM_LASER) - 1)


## Tras el disparo: brazo extendido durante laser_pose_hold_s.
func _hold_laser_pose() -> void:
	_show_laser_pose_frame(laser_pose_phone_offsets.size() - 1)
	_laser_pose_hold_left = laser_pose_hold_s


func _update_laser_pose_hold(delta: float) -> void:
	if _laser_pose_hold_left < 0.0:
		return
	_laser_pose_hold_left -= delta
	if _laser_pose_hold_left <= 0.0:
		_end_laser_pose(true)


## Quita la pose. Con `restore`, vuelve a la animacion del estado actual
## (los estados que tienen la suya propia la ponen ellos al entrar).
func _end_laser_pose(restore: bool) -> void:
	if not is_laser_posing():
		return
	_laser_pose_frame = -1
	_laser_pose_hold_left = -1.0
	if restore:
		_restore_state_animation()


func _restore_state_animation() -> void:
	match _state_name:
		PlayerState.IDLE:
			play_animation(ANIM_TERMINAL_INTRO if _terminal_playing else ANIM_IDLE)
		PlayerState.RUN:
			play_animation(ANIM_RUN if input.run_held else ANIM_WALK)
		PlayerState.JUMP, PlayerState.FALL:
			update_air_animation()


func _has_laser_energy() -> bool:
	return GameState.debug_energy + LASER_ENERGY_EPS >= abilities.laser_energy_cost


## Cobra la energia y crea el proyectil en el celular, hacia donde mira Isak,
## como hermano de Isak (no se mueve con el). Null si ya no hay energia.
func _fire_laser() -> LaserProjectile:
	_laser_muzzle.clear()
	if not _has_laser_energy():
		_deny_laser()
		_end_laser_pose(true)
		return null
	GameState.debug_energy -= abilities.laser_energy_cost
	# Brazo extendido: el proyectil sale del celular de ese cuadro.
	_hold_laser_pose()
	var projectile := LASER_PROJECTILE_SCENE.instantiate() as LaserProjectile
	projectile.setup(abilities, facing, self)
	var holder: Node = get_parent() if get_parent() != null else self
	holder.add_child(projectile)
	projectile.global_position = global_position + get_laser_origin()
	laser_fired.emit(projectile)
	EventBus.laser_fired.emit(projectile)
	return projectile


func _deny_laser() -> void:
	_laser_muzzle.show_fizzle(facing)
	laser_denied.emit()
	EventBus.laser_denied.emit()


func _cancel_laser() -> void:
	_laser_windup_left = -1.0
	if _laser_muzzle != null:
		_laser_muzzle.clear()


# --- Presentacion ---

## Mientras dura la pose del laser o la de espaldas los estados no cambian la
## animacion (al acabar, _end_laser_pose o face_side ponen la del estado).
func play_animation(anim: StringName) -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(anim) or is_laser_posing() or _facing_back:
		return
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


## Reproduce `anim` desde el cuadro 0 aunque ya fuera la animacion actual
## (acciones de un solo uso: pulso, golpe, muerte).
func restart_animation(anim: StringName) -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	_sprite.play(anim)
	_sprite.set_frame_and_progress(0, 0.0)


## Animacion actual del sprite (para pruebas y depuracion).
func get_animation() -> StringName:
	return _sprite.animation


## Duracion en segundos de `anim` a velocidad normal (0 si no existe o hace
## bucle). La usa LevelRunner para esperar a que acabe la animacion de muerte.
func get_animation_length(anim: StringName) -> float:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(anim) or frames.get_animation_loop(anim):
		return 0.0
	var fps: float = frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	var total: float = 0.0
	for i: int in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / fps


## Cuadro actual de la animacion del sprite.
func get_animation_frame() -> int:
	return _sprite.frame


## En el aire: subida, apogeo o caida segun velocity.y, y el cuadro dentro de
## cada fase segun la velocidad (no por tiempo). Lo llaman JumpState y FallState.
func update_air_animation() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or is_laser_posing() or _facing_back:
		return
	var vy: float = velocity.y
	var anim: StringName = ANIM_JUMP_APEX
	var t: float = (vy + AIR_APEX_SPEED) / (2.0 * AIR_APEX_SPEED)
	if vy < -AIR_APEX_SPEED:
		anim = ANIM_JUMP_RISE
		t = inverse_lerp(physics.jump_velocity, -AIR_APEX_SPEED, vy)
	elif vy > AIR_APEX_SPEED:
		anim = ANIM_JUMP_FALL
		t = inverse_lerp(AIR_APEX_SPEED, -physics.jump_velocity, vy)
	if not frames.has_animation(anim):
		return
	var count: int = frames.get_frame_count(anim)
	var index: int = clampi(floori(clampf(t, 0.0, 1.0) * count), 0, count - 1)
	if _sprite.animation != anim:
		_sprite.animation = anim
	_sprite.pause()
	_sprite.frame = index


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
	_pulse_area.position = get_pulse_origin()


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


## Parpadeo mientras dura la invulnerabilidad tras un golpe (no al morir).
func _update_blink() -> void:
	var dim: bool = is_invulnerable() and not is_dead() \
			and fmod(_invulnerable_left, BLINK_PERIOD_S) < BLINK_PERIOD_S * 0.5
	_sprite.modulate.a = BLINK_ALPHA if dim else 1.0


func _on_animation_finished() -> void:
	if _state_name != PlayerState.IDLE:
		return
	match _sprite.animation:
		ANIM_TERMINAL_INTRO:
			if _terminal_playing:
				play_animation(ANIM_TERMINAL_LOOP)
		ANIM_TERMINAL_OUTRO, ANIM_JUMP_LAND:
			if not _terminal_playing:
				play_animation(ANIM_IDLE)


func _update_coyote(delta: float) -> void:
	if is_on_floor():
		_coyote_left = physics.coyote_time_s
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)


func _on_sync_rate_changed(new_value: float, _max_value: float) -> void:
	if new_value <= GameState.SYNC_RATE_MIN:
		die()
