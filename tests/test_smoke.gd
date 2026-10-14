# Prueba de humo: comprueba que el proyecto arranca con sus autoloads
# y que GameState acota el Sync Rate a su máximo.
extends GutTest

const OVER_MAX_EXTRA: float = 50.0

var _saved_sync_rate: float


func before_each() -> void:
	_saved_sync_rate = GameState.sync_rate


func after_each() -> void:
	GameState.sync_rate = _saved_sync_rate


func test_autoloads_exist() -> void:
	var root: Window = get_tree().root
	assert_not_null(root.get_node_or_null(^"GameState"), "GameState debe estar registrado como autoload")
	assert_not_null(root.get_node_or_null(^"EventBus"), "EventBus debe estar registrado como autoload")


func test_sync_rate_clamped_to_max() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MAX + OVER_MAX_EXTRA
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "sync_rate no debe superar SYNC_RATE_MAX")
