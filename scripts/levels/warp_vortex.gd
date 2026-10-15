## Vortice de llegada y salida de Isak (2026-10-15; valores en data/warp.json,
## arte de tools/gen_warp_objects.py). Anillos cian estilo circuito que se abren,
## giran y se cierran:
## - ARRIVE (LevelRunner, al empezar el nivel y al reaparecer): Isak oculto y sin
##   control (Isak.begin_warp(true)); con `held` el vortice espera a release()
##   (el fundido de entrada); al empezar a cerrarse Isak se muestra
##   (Isak.reveal_warp) y se materializa en pasos discretos; al terminar
##   recupera el control (Isak.end_warp).
## - DEPART (ExitTerminal): Isak sin control (begin_warp(false)); al cerrarse se
##   desmaterializa (absorbido) y queda oculto y sin control.
## Avanza con tiempo del mundo (advance; se para con la pausa). Al terminar emite
## finished y se libera. El origen del nodo es el centro del vortice.
class_name WarpVortex
extends Node2D

enum Mode { ARRIVE, DEPART }
enum Phase { HELD, OPEN, SPIN, CLOSE, DONE }

const DATA_PATH: String = "res://data/warp.json"
const ANIM_OPEN: StringName = &"vortex_open"
const ANIM_SPIN: StringName = &"vortex_spin"
const ANIM_CLOSE: StringName = &"vortex_close"

## Los anillos empiezan a cerrarse (llegada: Isak ya se ve).
signal closing_started
## El vortice termino (llegada: Isak tiene el control; salida: Isak absorbido).
signal finished

var _data: Dictionary = {}
var _mode: Mode = Mode.ARRIVE
var _phase: Phase = Phase.HELD
var _isak: Isak
var _sprite: AnimatedSprite2D
var _time: float = 0.0
var _spins_left: int = 0


## Crea un vortice de llegada para `isak` bajo `parent` (justo antes de Isak si
## es su padre, para dibujarse detras). Isak queda oculto y sin control. Con
## `held`, no empieza hasta release().
static func arrive(isak: Isak, parent: Node, held: bool = false) -> WarpVortex:
	var vortex := WarpVortex.new()
	vortex._setup(Mode.ARRIVE, isak, parent)
	isak.begin_warp(true)
	isak.modulate.a = 0.0
	if not held:
		vortex.release()
	return vortex


## Crea un vortice de salida alrededor de `isak` bajo `parent` y lo empieza.
static func depart(isak: Isak, parent: Node) -> WarpVortex:
	var vortex := WarpVortex.new()
	vortex._setup(Mode.DEPART, isak, parent)
	isak.begin_warp(false)
	vortex.release()
	return vortex


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_mode() -> Mode:
	return _mode


func get_phase() -> Phase:
	return _phase


func is_done() -> bool:
	return _phase == Phase.DONE


func get_sprite() -> AnimatedSprite2D:
	return _sprite


## Animacion y cuadro mostrados (para pruebas y capturas).
func get_animation() -> StringName:
	return _sprite.animation


# --- Acciones ---

## Empieza la animacion si estaba esperando. Falso si ya habia empezado.
func release() -> bool:
	if _phase != Phase.HELD:
		return false
	_phase = Phase.OPEN
	_time = 0.0
	_sprite.visible = true
	_show(ANIM_OPEN, 0)
	return true


## Avanza `delta` segundos de tiempo del mundo.
func advance(delta: float) -> void:
	if _phase == Phase.HELD or _phase == Phase.DONE:
		return
	_time += maxf(delta, 0.0)
	# Puede cruzar varias fases en un paso largo.
	for i: int in 8:
		var anim: StringName = _phase_anim()
		var count: int = _sprite.sprite_frames.get_frame_count(anim)
		var fps: float = maxf(_sprite.sprite_frames.get_animation_speed(anim), 0.001)
		var length: float = count / fps
		if _time < length:
			var index: int = mini(floori(_time * fps), count - 1)
			_show(anim, index)
			if _phase == Phase.CLOSE:
				_fade_isak(float(index + 1) / float(count))
			return
		_time -= length
		if not _next_phase():
			return


# --- Interno ---

func _setup(mode: Mode, isak: Isak, parent: Node) -> void:
	_data = load_data()
	_mode = mode
	_isak = isak
	name = "ArrivalVortex" if mode == Mode.ARRIVE else "DepartVortex"
	var offset: Array = _data.get("center_offset_px", [0, -48])
	z_index = int(_data.get("z_index", 0))
	_spins_left = maxi(0, int(_data.get("spin_loops", 1)))
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = load(String(_data.get("frames", "res://assets/sprites/warp_objects_frames.tres"))) as SpriteFrames
	_sprite.centered = true
	_sprite.visible = false
	_sprite.animation = ANIM_OPEN
	add_child(_sprite)
	parent.add_child(self)
	if isak.get_parent() == parent:
		parent.move_child(self, isak.get_index())
	global_position = isak.global_position + Vector2(float(offset[0]), float(offset[1]))


func _phase_anim() -> StringName:
	match _phase:
		Phase.OPEN:
			return ANIM_OPEN
		Phase.SPIN:
			return ANIM_SPIN
	return ANIM_CLOSE


## Pasa a la fase siguiente. Falso si ha terminado.
func _next_phase() -> bool:
	match _phase:
		Phase.OPEN:
			if _spins_left > 0:
				_phase = Phase.SPIN
			else:
				_start_close()
		Phase.SPIN:
			_spins_left -= 1
			if _spins_left <= 0:
				_start_close()
		Phase.CLOSE:
			_finish()
			return false
	return true


func _start_close() -> void:
	_phase = Phase.CLOSE
	_show(ANIM_CLOSE, 0)
	_fade_isak(0.0)
	closing_started.emit()
	if _mode == Mode.ARRIVE and _valid_isak():
		_isak.reveal_warp()


func _finish() -> void:
	_phase = Phase.DONE
	_sprite.visible = false
	_fade_isak(1.0)
	if _mode == Mode.ARRIVE and _valid_isak():
		_isak.end_warp()
	finished.emit()
	queue_free()


## Opacidad de Isak en pasos discretos segun el progreso del cierre (0 a 1):
## llegada = se materializa; salida = se desvanece.
func _fade_isak(progress: float) -> void:
	if not _valid_isak():
		return
	var steps: int = maxi(1, int(_data.get("fade_steps", 4)))
	var k: float = float(clampi(floori(clampf(progress, 0.0, 1.0) * steps), 0, steps)) / float(steps)
	if _mode == Mode.ARRIVE:
		_isak.modulate.a = maxf(k, 1.0 / float(steps)) if _phase == Phase.CLOSE or _phase == Phase.DONE else 0.0
	else:
		_isak.modulate.a = 1.0 - k


func _show(anim: StringName, index: int) -> void:
	if _sprite.animation != anim:
		_sprite.animation = anim
	_sprite.frame = index


func _valid_isak() -> bool:
	return _isak != null and is_instance_valid(_isak)
