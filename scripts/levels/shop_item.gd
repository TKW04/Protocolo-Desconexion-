## Producto de la tienda (tipo `shop_item` del catalogo del Mundo 5; 2026-10-29, paso 3
## de docs/propuesta-mundo-5.md §8, §3.1 y §3.7). Producto en una estanteria con su
## etiqueta de precio. Un PULSO DE ESPALDAS (PayPoint) lo compra con el saldo real
## (GameState.spend_attention: sin deuda, «sin guardar») y da el efecto al instante:
## product sync = +25 de Sync Rate, energy = +40 de energia (prices.shop_item de
## data/economy.json). Uno por intento (uses_per_attempt; el nivel se crea de nuevo en
## cada intento): despues, «Agotado». Sin saldo, «Saldo insuficiente» y chispa gris.
## Aspecto PROVISIONAL por codigo (seccion shop_item de data/world5_objects.json).
class_name ShopItem
extends PayPoint

const GROUP: StringName = &"shop_item"
const PRODUCT_SYNC: StringName = &"sync"
const PRODUCT_ENERGY: StringName = &"energy"

## Comprado (`cost` puntos gastados).
signal bought(product: StringName, cost: int)

const RESULT_OK: int = 0
const RESULT_NO_FUNDS: int = 1
const RESULT_SOLD_OUT: int = 2

## sync o energy (params.product).
@export var product: StringName = PRODUCT_SYNC
## Precio propio (params.cost); -1 = el de data/economy.json.
@export var cost: int = -1

var _uses: int = 0


func _section_name() -> String:
	return "shop_item"


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)


# --- Consultas ---

func get_cost() -> int:
	if cost >= 0:
		return cost
	return int((price_section("shop_item").get(String(product), {}) as Dictionary).get("cost", 0))


## Lo que da el producto: Sync Rate (sync) o energia (energy).
func get_amount() -> float:
	var entry: Dictionary = price_section("shop_item").get(String(product), {})
	return float(entry.get(String(product), 0.0))


func get_uses_left() -> int:
	return maxi(int(price_section("shop_item").get("uses_per_attempt", 1)) - _uses, 0)


func is_sold_out() -> bool:
	return get_uses_left() <= 0


## Ayuda de Eco: lo agotado no ayuda.
func is_help_available() -> bool:
	return not is_sold_out()


# --- Acciones ---

func _on_pulsed(_isak: Isak) -> void:
	buy()


## Compra (lo usan el pulso y las pruebas). Devuelve RESULT_*.
func buy() -> int:
	if is_sold_out():
		show_message(String(_cfg.get("text_sold_out", "Agotado")))
		spark(REJECT_USED)
		return RESULT_SOLD_OUT
	var price: int = get_cost()
	if not GameState.spend_attention(price, GROUP):
		show_message(String(_cfg.get("text_no_funds", "Saldo insuficiente")))
		spark(REJECT_NO_FUNDS)
		return RESULT_NO_FUNDS
	_uses += 1
	match product:
		PRODUCT_SYNC:
			GameState.heal_sync(get_amount())
		PRODUCT_ENERGY:
			GameState.add_debug_energy(get_amount())
	show_message(String(_cfg.get("text_bought", "¡Gracias por su compra!")))
	bought.emit(product, price)
	return RESULT_OK


# --- Dibujo ---

func _draw() -> void:
	var sr: Array = _cfg.get("shelf_rect", [4, 30, 56, 8])
	var shelf := Rect2(float(sr[0]), float(sr[1]), float(sr[2]), float(sr[3]))
	draw_rect(Rect2(shelf.position.x, shelf.position.y - 34.0, shelf.size.x, 34.0 + shelf.size.y),
		Color(_c("frame", "gris_escaparate"), 0.6))
	draw_rect(shelf, _c("shelf", "gris_etiqueta"))
	var c := Vector2(shelf.get_center().x, shelf.position.y - 14.0)
	if not is_sold_out():
		if product == PRODUCT_SYNC:
			# Frasco de Sync: cruz.
			var col: Color = _c("sync", "magenta_neon")
			draw_rect(Rect2(c + Vector2(-10.0, -10.0), Vector2(20.0, 22.0)), col, false, 2.0)
			draw_rect(Rect2(c + Vector2(-2.0, -6.0), Vector2(4.0, 14.0)), col)
			draw_rect(Rect2(c + Vector2(-7.0, -1.0), Vector2(14.0, 4.0)), col)
		else:
			# Pila de energia.
			var col: Color = _c("energy", "violeta_neon")
			draw_rect(Rect2(c + Vector2(-8.0, -10.0), Vector2(16.0, 22.0)), col, false, 2.0)
			draw_rect(Rect2(c + Vector2(-3.0, -13.0), Vector2(6.0, 3.0)), col)
			draw_rect(Rect2(c + Vector2(-5.0, -2.0), Vector2(10.0, 11.0)), col)
	# Etiqueta de precio colgada de la balda.
	var tag := Rect2(Vector2(shelf.get_center().x - 18.0, shelf.end.y + 2.0), Vector2(36.0, 16.0))
	draw_rect(tag, _c("tag", "amarillo_rebajas"))
	if is_sold_out():
		draw_string(ThemeDB.fallback_font, Vector2(tag.position.x, tag.end.y - 4.0), "--",
			HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 12, _c("ink", "negro_medio"))
	else:
		draw_price(tag.get_center().x, tag.end.y - 4.0, str(get_cost()), 12, _c("ink", "negro_medio"))
	draw_feedback(Vector2(shelf.get_center().x, shelf.position.y - 30.0))
