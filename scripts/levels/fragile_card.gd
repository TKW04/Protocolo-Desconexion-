## Tarjeta fragil (tipo `fragile_card` del catalogo del Mundo 2; 2026-10-22, paso 4
## de docs/propuesta-mundo-2.md §8, §3.4). Reutiliza el recordatorio del Mundo 1
## (ReminderPlatform: cuenta, segmentos, aviso, caida y vuelta) con otras reglas:
## - Cuenta SOLA (sin grupo) al pisarla (trigger "on_step"): timer_s en tiempo
##   del mundo, una grieta que crece y 4 segmentos; los ultimos warn_s parpadea y
##   tiembla; al vencer cae sin dano y vuelve a los respawn_s si nadie ocupa su
##   sitio. Con trigger "pound_only" pisarla no hace nada.
## - El GOLPE AL SUELO la rompe al instante si la onda la alcanza
##   (EventBus.ground_pound_landed): bajo los pies o dentro de la onda. Mientras
##   cae, is_broken_by_pound() deja a Isak seguir cayendo a traves de ella.
## - Variantes: `one_way` (de una via: se sube saltando desde abajo) y `variant`
##   "upright" (de pie: pared de width_tiles x 2 que bloquea un paso, no cuenta al
##   pisarla, solo la rompe la onda y no vuelve hasta que Isak reaparece).
## - `hidden` (propiedad hidden_card): sin el Debug parece una tarjeta normal (sin grieta ni segmentos); con
##   el Debug se ve la grieta (la salida oculta de un bucle).
## - Al reaparecer Isak (EventBus.player_respawned) vuelve a su estado inicial.
## Aspecto PROVISIONAL por codigo con la paleta provisional del Mundo 2 (seccion
## fragile_card de data/world2_objects.json). El origen del nodo es la esquina
## superior izquierda de su primera celda.
class_name FragileCard
extends ReminderPlatform

const FRAGILE_GROUP: StringName = &"fragile_card"
const VARIANT_FLOOR: String = "floor"
const VARIANT_UPRIGHT: String = "upright"
const TRIGGER_ON_STEP: String = "on_step"
const TRIGGER_POUND_ONLY: String = "pound_only"

## La rompe el golpe al suelo.
signal broken_by_pound

@export var variant: String = VARIANT_FLOOR
@export var trigger_mode: String = TRIGGER_ON_STEP
@export var one_way: bool = false
@export var hidden_card: bool = false

var _w2: Dictionary = World2ObjectsConfig.section("fragile_card")
var _broken_by_pound: bool = false
var _pound_breaks: int = 0


## Valores por defecto de la tarjeta fragil (los del catalogo; la escena del nivel
## los sustituye con sus params): cuenta mas corta que la del recordatorio.
func _init() -> void:
	timer_s = 0.6
	warn_s = 0.5
	respawn_s = 3.0


func _ready() -> void:
	add_to_group(FRAGILE_GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	if variant == VARIANT_UPRIGHT:
		trigger_mode = TRIGGER_POUND_ONLY
	var size: Vector2 = get_card_size()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	_shape.one_way_collision = one_way and variant != VARIANT_UPRIGHT
	add_child(_shape)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)
	_update_visual()


# --- Consultas ---

func get_card_size() -> Vector2:
	var tile: float = World2ObjectsConfig.tile_size()
	if variant == VARIANT_UPRIGHT:
		return Vector2(width_tiles * tile, tile * 2.0)
	return Vector2(width_tiles * tile, float(_w2.get("card_height_px", 32)))


## Isak sigue cayendo a traves de ella (se acaba de romper con el golpe).
func is_broken_by_pound() -> bool:
	return _broken_by_pound and not is_solid()


func get_pound_break_count() -> int:
	return _pound_breaks


## Grieta de 0 (entera) a 1 (a punto de caer).
func get_crack() -> float:
	if _state != State.COUNTING:
		return 0.0
	return clampf(1.0 - get_time_left() / maxf(timer_s, 0.001), 0.0, 1.0)


## Ayuda de Eco: entera (en reposo o contando); oculta sin el Debug, no.
func is_help_available() -> bool:
	return is_solid() and (not hidden_card or DebugMode.get_intensity() > 0.0)


# --- Acciones ---

## Pisarla: con trigger on_step empieza su cuenta (sola).
func trigger() -> bool:
	if trigger_mode != TRIGGER_ON_STEP or _state != State.IDLE:
		return false
	start_countdown()
	return true


## Sin grupos: cae sola.
func get_group_members() -> Array[ReminderPlatform]:
	return [self] as Array[ReminderPlatform]


## La rompe la onda (o una prueba): cae ya, sin colision. Falso si no estaba entera.
func break_now() -> bool:
	if not is_solid():
		return false
	_broken_by_pound = true
	_pound_breaks += 1
	_clock = {}
	_fall()
	broken_by_pound.emit()
	return true


func reset() -> void:
	_broken_by_pound = false
	super.reset()


func advance(dt: float) -> void:
	# La de pie no vuelve sola: espera a que Isak reaparezca.
	if _state == State.GONE and variant == VARIANT_UPRIGHT:
		_time += dt
		_state_time += dt
		return
	super.advance(dt)
	if _state == State.IDLE:
		_broken_by_pound = false


# --- Interno ---

func _on_ground_pound_landed(rect: Rect2, _source: Node2D) -> void:
	if is_solid() and rect.intersects(get_card_rect()):
		break_now()


func _anim_length(_anim_name: StringName) -> float:
	return float(_w2.get("fall_s", 0.3))


func _update_visual() -> void:
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = get_card_size()
	var revealed: bool = not hidden_card or DebugMode.get_intensity() > 0.0
	var offset := Vector2.ZERO
	var alpha: float = 1.0
	match _state:
		State.GONE:
			return
		State.FALLING:
			var k: float = clampf(_state_time / maxf(_anim_length(&""), 0.01), 0.0, 1.0)
			offset.y = float(_w2.get("fall_drop_px", 48.0)) * k
			alpha = 1.0 - k
		State.RESPAWNING:
			alpha = clampf(_state_time / maxf(_anim_length(&""), 0.01), 0.0, 1.0)
		State.COUNTING:
			if is_warning() and int(floorf(_time * 12.0)) % 2 == 0:
				offset.x = float(_w2.get("shake_px", 2.0))
	var rect := Rect2(offset, size)
	FeedCardDraw.card(self, rect, alpha, one_way)
	if not revealed:
		return
	var crack_color: Color = World2ObjectsConfig.color("blanco")
	if hidden_card:
		crack_color = World2ObjectsConfig.color("debug_ambar")
	var crack: float = 1.0 if _state == State.FALLING else get_crack()
	FeedCardDraw.crack(self, rect, maxf(crack, float(_w2.get("idle_crack", 0.15))), Color(crack_color, alpha))
	if trigger_mode == TRIGGER_ON_STEP and (_state == State.IDLE or _state == State.COUNTING):
		var warn_blink: bool = is_warning() and int(floorf(_time * 12.0)) % 2 == 0
		FeedCardDraw.segments(self, rect, get_lit_segments(), SEG_COUNT, warn_blink)
