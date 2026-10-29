# Prueba de humo de scenes/levels/test_arena.tscn: carga, Isak cae al suelo
# y queda en Idle con la fisica real del motor; clasificacion de saltos de la
# ayuda de depuracion.
extends GutTest

const ARENA_SCENE: PackedScene = preload("res://scenes/levels/test_arena.tscn")
const ArenaScript = preload("res://scripts/levels/test_arena.gd")
const SETTLE_FRAMES: int = 60

var _pulse_was_unlocked: bool
## La arena desbloqueaba Agitar (paso 1 del Mundo 4; retirado el 2026-10-28, ya no): se devuelve por si acaso.
var _shockwave_was_unlocked: bool
## La arena desbloquea la Combinacion (2026-10-29, paso 1 del Mundo 5): se devuelve al terminar.
var _combo_was_unlocked: bool


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_shockwave_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_SHOCKWAVE)
	_combo_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_COMBO)


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, _shockwave_was_unlocked)
	GameState.set_ability_unlocked(GameState.ABILITY_COMBO, _combo_was_unlocked)


func test_isak_lands_idle_in_arena() -> void:
	var arena: Node = add_child_autofree(ARENA_SCENE.instantiate())
	var isak: Isak = arena.get_node("Isak") as Isak
	isak.input = PlayerInput.new()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(isak.is_on_floor(), "Isak debe apoyarse en el suelo de la arena")
	assert_eq(isak.get_state_name(), PlayerState.IDLE)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "La arena desbloquea el pulso")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_COMBO), "Y la Combinacion")


func test_jump_classification_for_debug_overlay() -> void:
	assert_eq(ArenaScript.classify_jump(PlayerState.FALL, false, true), "coyote")
	assert_eq(ArenaScript.classify_jump(PlayerState.FALL, true, false), "buffer")
	assert_eq(ArenaScript.classify_jump(PlayerState.IDLE, true, false), "buffer")
	assert_eq(ArenaScript.classify_jump(PlayerState.RUN, true, true), "normal")

