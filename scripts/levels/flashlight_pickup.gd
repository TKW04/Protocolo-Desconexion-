## Linterna (tipo `flashlight_pickup` del catalogo del Mundo 4; 2026-10-28, paso 4 de
## docs/propuesta-mundo-4.md §8 y §3.6; docs/propuesta-asistentes-y-vidas.md §2.4):
## objeto de la sala de llegada del 4-1 que se recoge al TOCARLO (el cuerpo de Isak
## solapa su caja). Al recogerla, la Linterna queda CONOCIDA (GameState.meet_ally
## ("linterna"): aliada de registro como Calc, no marca «sin guardar» y un game over no
## la quita) y desde entonces es una lucecita que sigue a Isak (FlashlightCompanion)
## y abre la luz en las zonas «Modo oscuro» (DarkZone). Con la Linterna ya conocida no
## aparece (como el ability_pickup con la habilidad obtenida). Ayuda Q desde el paso 10;
## la linea de Eco al recogerla (paso 20, texto propuesto) es un eco_line del nivel con
## trigger_event ally_met (GameState.meet_ally emite EventBus.ally_met). Aspecto PROVISIONAL
## por codigo (seccion flashlight de data/world4_objects.json). El origen es la esquina
## superior izquierda de su celda.
class_name FlashlightPickup
extends Node2D

const GROUP: StringName = &"flashlight_pickup"

## Isak la ha recogido.
signal collected

@export var object_id: StringName = &""
## Isak que la recoge (si es null se busca con LevelLookup).
var isak: Isak

var _cfg: Dictionary = World4ObjectsConfig.section("flashlight")
var _taken: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_taken = GameState.has_met_ally(GameState.ALLY_LINTERNA)
	visible = not _taken


func _physics_process(delta: float) -> void:
	_t += delta
	if not _taken:
		check_pickup()
		queue_redraw()


## Recoge la Linterna si el cuerpo de Isak toca su caja. Devuelve verdadero si la ha recogido ahora.
func check_pickup() -> bool:
	if _taken:
		return false
	if isak == null or not is_instance_valid(isak) or not isak.is_inside_tree():
		isak = LevelLookup.find_isak(self)
	if isak == null or isak.is_dead():
		return false
	if not LevelLookup.isak_body_rect(isak).intersects(get_pickup_rect()):
		return false
	collect()
	return true


## La recoge sin tocarla (pruebas).
func collect() -> void:
	if _taken:
		return
	_taken = true
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	visible = false
	collected.emit()


func is_taken() -> bool:
	return _taken


## Lo recogido no ayuda (HelpCatalog.is_help_live).
func is_help_available() -> bool:
	return not _taken


## Caja de recogida (global): la celda menos pickup_inset_px por lado.
func get_pickup_rect() -> Rect2:
	var t: float = World4ObjectsConfig.tile_size()
	var inset: float = float(_cfg.get("pickup_inset_px", 12))
	return Rect2(global_position + Vector2(inset, inset), Vector2(t - inset * 2.0, t - inset))


func _draw() -> void:
	if _taken:
		return
	var t: float = World4ObjectsConfig.tile_size()
	var bob: float = sin(_t * TAU * 0.5) * 2.0
	var body: Color = World4ObjectsConfig.color("gris_claro", Color("#a9aebb"))
	var head: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var ink: Color = World4ObjectsConfig.color("chat_noche", Color("#0f1422"))
	var c := Vector2(t * 0.5, t * 0.6 + bob)
	draw_circle(c + Vector2(0.0, -14.0), 16.0, Color(head, 0.18))
	draw_rect(Rect2(c + Vector2(-5.0, -4.0), Vector2(10.0, 20.0)), body)
	draw_rect(Rect2(c + Vector2(-5.0, -4.0), Vector2(10.0, 20.0)), ink, false, 1.0)
	draw_rect(Rect2(c + Vector2(-8.0, -12.0), Vector2(16.0, 8.0)), head)
	draw_rect(Rect2(c + Vector2(-8.0, -12.0), Vector2(16.0, 8.0)), ink, false, 1.0)
