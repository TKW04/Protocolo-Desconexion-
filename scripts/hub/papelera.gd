## Papelera del hub (docs/propuesta-asistentes-y-vidas.md §2.5 y §5.2, paso 12
## de §10; seccion papelera de data/hub.json). En el dock (columna 10), de pie
## sobre el suelo. Su estado sale de GameState:
## - DORMANT: aun no ha hecho falta (sin "papelera" en allies_met): el hueco
##   apagado de siempre, sin prompt.
## - ACTIVE: hay contenido de un game over pendiente de recuperar
##   (GameState.has_trash_pending): parpadea y se tambalea. Basta con que Isak se
##   acerque (recover_radius_tiles en horizontal; sin boton ni pulso, con el
##   juego sin pausa) para recuperarlo todo de golpe (GameState.recover_trash):
##   animacion de vaciado (EMPTYING) y despues queda vacia.
## - EMPTY: activada y vacia (tras recuperar, o tras un game over sin nada que
##   devolver), quieta.
## No es solida ni una estacion: no tiene panel.
class_name Papelera
extends Node2D

enum State { DORMANT, ACTIVE, EMPTYING, EMPTY }

const ANIM_DORMANT: StringName = &"dormant"
const ANIM_ACTIVE: StringName = &"active"
const ANIM_EMPTYING: StringName = &"emptying"
const ANIM_EMPTY: StringName = &"empty"
## Altura del centro de Isak sobre sus pies (para medir la cercania).
const ISAK_CENTER_Y_PX: float = 48.0

## Se recupero todo (`trash`: lo que tenia).
signal recovered(trash: Dictionary)

## Isak (lo da HubRoom); sin el no se recupera por cercania.
var isak: Isak

var _config: Dictionary = HubData.section("papelera")
var _state: State = State.DORMANT
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Visual"
	_sprite.centered = false
	var path: String = String(_config.get("frames", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		_sprite.sprite_frames = load(path) as SpriteFrames
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	EventBus.trash_changed.connect(_on_trash_changed)
	EventBus.ally_met.connect(_on_ally_met)
	refresh()


func _physics_process(_delta: float) -> void:
	check_recover()


# --- Consultas ---

func get_state() -> State:
	return _state


## Animacion del arte (dormant, active, emptying, empty).
func get_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""


func get_size() -> Vector2:
	var s: Array = _config.get("size_px", [64, 96])
	return Vector2(float(s[0]), float(s[1]))


## Centro (global) de la papelera.
func get_center() -> Vector2:
	return global_position + get_size() * 0.5


## Distancia horizontal a la que se recupera (px).
func get_recover_radius() -> float:
	return float(_config.get("recover_radius_tiles", 1.5)) * HubData.tile_size()


## `point` (centro de Isak) esta lo bastante cerca para recuperar.
func is_near(point: Vector2) -> bool:
	return absf(point.x - get_center().x) <= get_recover_radius() \
		and absf(point.y - get_center().y) <= get_size().y


# --- Acciones ---

## Vuelve a leer el estado de GameState (no interrumpe el vaciado).
func refresh() -> void:
	if _state == State.EMPTYING:
		return
	if GameState.has_trash_pending():
		_set_state(State.ACTIVE)
	elif GameState.has_met_ally(GameState.ALLY_PAPELERA):
		_set_state(State.EMPTY)
	else:
		_set_state(State.DORMANT)


## Si Isak esta cerca, con contenido y el juego sin pausa, lo recupera todo.
## Verdadero si recupero.
func check_recover() -> bool:
	if _state != State.ACTIVE or isak == null or not is_instance_valid(isak) or get_tree().paused:
		return false
	if not is_near(isak.global_position + Vector2(0.0, -ISAK_CENTER_Y_PX)):
		return false
	return recover()


## Recupera todo de golpe (GameState.recover_trash) y se vacia. Falso si no
## habia nada.
func recover() -> bool:
	var trash: Dictionary = GameState.get_trash()
	if not GameState.recover_trash():
		return false
	_set_state(State.EMPTYING)
	recovered.emit(trash)
	return true


## Termina el vaciado al instante (pruebas y capturas).
func finish_emptying() -> void:
	if _state == State.EMPTYING:
		_state = State.DORMANT
		refresh()


# --- Interno ---

func _set_state(state: State) -> void:
	_state = state
	var anim: StringName = ANIM_DORMANT
	match state:
		State.ACTIVE:
			anim = ANIM_ACTIVE
		State.EMPTYING:
			anim = ANIM_EMPTYING
		State.EMPTY:
			anim = ANIM_EMPTY
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim) \
			and (_sprite.animation != anim or not _sprite.is_playing()):
		_sprite.play(anim)


func _on_animation_finished() -> void:
	finish_emptying()


func _on_trash_changed(_pending: bool) -> void:
	refresh()


func _on_ally_met(ally: StringName) -> void:
	if ally == GameState.ALLY_PAPELERA:
		refresh()
