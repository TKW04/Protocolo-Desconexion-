## Linterna companera (2026-10-28, paso 4 de docs/propuesta-mundo-4.md §8 y §3.6;
## docs/propuesta-asistentes-y-vidas.md §2.4): con la Linterna conocida
## (GameState.has_met_ally("linterna")), una lucecita que sigue a Isak a la altura de su
## mano, DEBAJO de Eco (offset_px; z_index por debajo de Eco), sin colision. Solo se
## ENCIENDE dentro de una zona «Modo oscuro» (DarkZone, que abre el circulo de luz);
## fuera, apagada (un punto tenue). La crea LevelRunner junto a Eco (attach) en cada
## nivel; aparece en cuanto se conoce (EventBus.ally_met). Sigue en tiempo real (es de
## Isak). Aspecto PROVISIONAL por codigo (seccion flashlight de data/world4_objects.json).
class_name FlashlightCompanion
extends Node2D

const GROUP: StringName = &"flashlight_companion"

## Se enciende o apaga (al entrar o salir de una zona oscura).
signal light_changed(on: bool)

## Si es false, _process no avanza (las pruebas llaman a advance()).
var auto_advance: bool = true

var _isak: Isak
var _cfg: Dictionary = World4ObjectsConfig.section("flashlight")
var _on: bool = false
var _t: float = 0.0


## Crea la companera de `isak` como hija de `parent` (el nivel).
static func attach(isak: Isak, parent: Node) -> FlashlightCompanion:
	var light := FlashlightCompanion.new()
	light.name = "FlashlightCompanion"
	light._isak = isak
	parent.add_child(light)
	return light


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_cfg.get("companion_z", 0))
	EventBus.ally_met.connect(_on_ally_met)
	visible = is_known()
	advance(0.0)


func _exit_tree() -> void:
	if EventBus.ally_met.is_connected(_on_ally_met):
		EventBus.ally_met.disconnect(_on_ally_met)


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


## Sigue a Isak y se enciende si esta en una zona oscura. Publico para las pruebas.
func advance(delta: float) -> void:
	_t += delta
	if _isak == null or not is_instance_valid(_isak):
		return
	var offset: Array = _cfg.get("offset_px", [-22, -44])
	global_position = _isak.global_position + Vector2(float(offset[0]) * _isak.facing, float(offset[1]))
	var on: bool = is_known() and not _isak.is_dead() and _in_dark()
	if on != _on:
		_on = on
		light_changed.emit(on)
	queue_redraw()


func is_known() -> bool:
	return GameState.has_met_ally(GameState.ALLY_LINTERNA)


## Encendida (Isak en una zona oscura con la Linterna conocida).
func is_on() -> bool:
	return _on


func _in_dark() -> bool:
	if not is_inside_tree():
		return false
	var center: Vector2 = LevelLookup.isak_body_rect(_isak).get_center()
	return DarkZone.covering(get_tree(), center) != null


func _on_ally_met(ally: StringName) -> void:
	if ally == GameState.ALLY_LINTERNA:
		visible = true
		advance(0.0)


func _draw() -> void:
	var cream: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var gray: Color = World4ObjectsConfig.color("gris_medio", Color("#6b7280"))
	if _on:
		var pulse: float = 0.5 + 0.5 * sin(_t * TAU * 0.8)
		draw_circle(Vector2.ZERO, 9.0 + pulse * 2.0, Color(cream, 0.25))
		draw_circle(Vector2.ZERO, 4.0, cream)
	else:
		draw_circle(Vector2.ZERO, 3.0, Color(gray, 0.8))
