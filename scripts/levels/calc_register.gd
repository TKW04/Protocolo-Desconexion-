## Caja registradora de Calc (tipo `calc_register` del catalogo del Mundo 5; 2026-10-29,
## paso 7 de docs/propuesta-mundo-5.md §8, §3.7, §4.2.1 y decision 14 de §9; secreto A
## del 5-2). Ajustes en la seccion calc_register de data/world5_objects.json.
##
## Es el atajo (ShortcutDoor) SIN TRAMPA, nunca con ella: puerta SOLIDA de 1 x
## height_tiles con la pantalla LCD de Calc encima en vez del cartel amarillo («Atajo:
## 2 ◆ / Trampa: 0»). Un PULSO DE ESPALDAS paga prices.calc_register de
## data/economy.json (2; params.cost lo cambia) con el saldo real (sin deuda: «Saldo
## insuficiente» y chispa gris) y se abre el resto del intento; lo pagado NO va a
## Devoluciones (no hay trampa: es el precio que dice). Calc habla en el cuadro de
## texto con su estilo LCD (interlocutor calc, no importante): al acercarse Isak por
## primera vez en el intento (talk_radius_tiles), line_near; al pagar, line_paid
## (textos PROPUESTOS). Sin la estacion de Calc ni el actor: Calc sigue en el hub.
class_name CalcRegister
extends ShortcutDoor

const REGISTER_GROUP: StringName = &"calc_register"
const SPEAKER_CALC: StringName = &"calc"

## Calc ha dicho una linea (`kind`: near o paid).
signal calc_said(text: String, kind: StringName)

var _greeted: bool = false


func _init() -> void:
	trap = TRAP_NONE


func _section_name() -> String:
	return "calc_register"


func _ready() -> void:
	trap = TRAP_NONE
	super._ready()
	add_to_group(REGISTER_GROUP)
	paid.connect(_on_paid)


# --- Consultas ---

func get_cost() -> int:
	return cost if cost >= 0 else int(price_section("calc_register").get("cost", 2))


## Nunca hay trampa (aunque se ponga `trap`): ni salta, ni se ve con el Debug, ni es devoluble.
func has_trap() -> bool:
	return false


func has_greeted() -> bool:
	return _greeted


## Pantalla LCD (global), encima de la puerta.
func get_screen_rect() -> Rect2:
	var door: Rect2 = get_door_rect()
	var s: Array = _cfg.get("screen_size_px", [88, 34])
	var size := Vector2(float(s[0]), float(s[1]))
	return Rect2(Vector2(door.get_center().x - size.x * 0.5, door.position.y - size.y - 6.0), size)


# --- Acciones ---

## Calc dice `text` en el cuadro de texto con su LCD (sin cuadro, por EventBus).
func say(text: String, kind: StringName) -> void:
	if text.is_empty():
		return
	calc_said.emit(text, kind)
	var duration: float = float(_cfg.get("duration_s", -1.0))
	var box: Node = _text_box()
	if box != null:
		box.call(&"show_line", text, duration, false, SPEAKER_CALC)
	else:
		EventBus.eco_line_requested.emit(text, duration, false)


func _advance(dt: float) -> void:
	super._advance(dt)
	if _greeted or _open:
		return
	var isak: Isak = LevelLookup.find_isak(self)
	if isak == null or isak.is_dead() or isak.is_warping():
		return
	var radius: float = float(_cfg.get("talk_radius_tiles", 3.0)) * TILE
	if absf(isak.global_position.x - get_door_rect().get_center().x) <= radius \
			and absf(isak.global_position.y - get_door_rect().end.y) <= radius:
		_greeted = true
		say(_line("line_near"), &"near")


# --- Interno ---

func _on_paid(_cost: int) -> void:
	_greeted = true
	say(_line("line_paid"), &"paid")


func _line(key: String) -> String:
	return String(_cfg.get(key, "")).replace("{cost}", str(get_cost()))


func _text_box() -> Node:
	var node: Node = get_parent()
	while node != null:
		var box: Node = node.get_node_or_null(^"EcoTextBox")
		if box != null:
			return box
		node = node.get_parent()
	return null


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

func _draw() -> void:
	var door := Rect2(get_door_rect().position - global_position, get_door_rect().size)
	draw_rect(door.grow(3.0), _c("frame", "gris_escaparate"))
	draw_rect(door, _c("open", "tienda_noche") if _open else _c("door", "negro_medio"))
	# Cuerpo de la caja registradora y la pantalla LCD de Calc.
	var screen := Rect2(get_screen_rect().position - global_position, get_screen_rect().size)
	draw_rect(screen.grow(4.0), _c("body", "gris_escaparate"))
	draw_rect(screen, _c("lcd", "crema_sombra"))
	draw_rect(screen, _c("ink", "negro_medio"), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	var ink: Color = _c("lcd_ink", "negro_medio")
	var text: String = String(_cfg.get("text_screen", "Atajo: {cost}")).replace("{cost}", str(get_cost()))
	draw_price(screen.get_center().x, screen.position.y + 14.0, text, 11, ink)
	draw_string(font, Vector2(screen.position.x, screen.end.y - 5.0),
		String(_cfg.get("text_screen_trap", "Trampa: 0")), HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, 10, ink)
	draw_feedback(Vector2(door.get_center().x, screen.position.y - 4.0))
