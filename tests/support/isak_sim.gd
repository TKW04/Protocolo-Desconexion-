# Arnes de simulacion de Isak para pruebas: crea un mundo con suelo llano o
# usa una escena dada, inyecta un PlayerInput falso y avanza la fisica paso a
# paso con delta fijo llamando a Isak.step(). Sin input real ni frames reales.
# No empieza por "test_", asi que GUT no lo ejecuta como prueba.
extends RefCounted

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const FLOOR_SIZE: Vector2 = Vector2(8192.0, 128.0)
## Margen de pasos extra sobre los calculados con los datos.
const STEP_MARGIN: int = 10
## Limite de tiempo para esperar algo que deberia ocurrir en pocos segundos.
const MAX_WAIT_S: float = 10.0

var delta: float
var isak: Isak
var input: PlayerInput


func _init(step_delta: float = 1.0 / 60.0) -> void:
	delta = step_delta
	input = PlayerInput.new()


## Mundo con un suelo llano cuya superficie esta en y = 0 e Isak en el origen.
## Devuelve la raiz; el llamador la anade al arbol (p. ej. add_child_autofree).
func build_flat_world() -> Node2D:
	var world := Node2D.new()
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = FLOOR_SIZE
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0.0, FLOOR_SIZE.y * 0.5)
	world.add_child(floor_body)
	isak = ISAK_SCENE.instantiate() as Isak
	isak.input = input
	world.add_child(isak)
	return world


## Toma el control de un Isak ya instanciado (p. ej. el de una escena de nivel).
## Llamar antes de que entre en el arbol para que use la entrada falsa.
func attach(existing: Isak) -> void:
	isak = existing
	isak.input = input


## Desactiva el _physics_process real: a partir de aqui solo avanza con step().
func take_manual_control() -> void:
	isak.set_physics_process(false)


func step(count: int = 1) -> void:
	for i: int in count:
		isak.step(delta)
		input.clear_just_pressed()


## Avanza hasta que se cumpla `condition` o se agoten los pasos. Devuelve los pasos dados.
func step_until(condition: Callable, max_steps: int = -1) -> int:
	if max_steps < 0:
		max_steps = ceili(MAX_WAIT_S / delta)
	for i: int in max_steps:
		if condition.call():
			return i
		step()
	return max_steps


func settle() -> void:
	step_until(func() -> bool: return isak.is_on_floor() and state() == PlayerState.IDLE)


func state() -> StringName:
	return isak.get_state_name()


## Pasos necesarios para cubrir `seconds`, con margen.
func steps_for(seconds: float) -> int:
	return ceili(seconds / delta) + STEP_MARGIN


## Pasos enteros mas cercanos a `seconds` (sin margen).
func frames(seconds: float) -> int:
	return roundi(seconds / delta)


## Pulsa saltar durante un paso (flanco + mantenido) y lo suelta.
func press_jump() -> void:
	input.jump_pressed = true
	input.jump_held = true
	step()
	input.jump_held = false
