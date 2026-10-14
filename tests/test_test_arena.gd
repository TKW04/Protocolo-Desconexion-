# Prueba de humo de scenes/levels/test_arena.tscn: carga, Isak cae al suelo
# y queda en Idle con la fisica real del motor.
extends GutTest

const ARENA_SCENE: PackedScene = preload("res://scenes/levels/test_arena.tscn")
const SETTLE_FRAMES: int = 60

var _pulse_was_unlocked: bool


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)


func test_isak_lands_idle_in_arena() -> void:
	var arena: Node = add_child_autofree(ARENA_SCENE.instantiate())
	var isak: Isak = arena.get_node("Isak") as Isak
	isak.input = PlayerInput.new()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(isak.is_on_floor(), "Isak debe apoyarse en el suelo de la arena")
	assert_eq(isak.get_state_name(), PlayerState.IDLE)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "La arena desbloquea el pulso")
