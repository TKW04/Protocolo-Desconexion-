## Devoluciones (tipo `refund_desk` del catalogo del Mundo 5; 2026-10-29, paso 3 de
## docs/propuesta-mundo-5.md §8 y §3.6). Mostrador del secreto A del 5-1. Un PULSO DE
## ESPALDAS (PayPoint) devuelve al saldo lo de `refunds` de data/economy.json (lo drenado
## por Suscripciones y lo pagado en atajos con trampa) del intento actual de ESE nivel
## (GameState.claim_refunds: ni Calc ni otros niveles) y bonus_points propios del
## secreto, que se dan una sola vez por partida guardada (GameState.mark_pickup_collected
## con el id del mostrador; sin nivel, siempre). Una vez por intento (uses_per_attempt;
## el nivel se crea de nuevo en cada intento): despues, «Cerrado». Aspecto PROVISIONAL
## por codigo (seccion refund_desk de data/world5_objects.json).
class_name RefundDesk
extends PayPoint

const GROUP: StringName = &"refund_desk"
const BONUS_PREFIX: String = "refund_bonus:"

## Ha devuelto `refunded` puntos del registro y `bonus` del secreto.
signal refunded(amount: int, bonus: int)

var _uses: int = 0
var _last_total: int = 0


func _section_name() -> String:
	return "refund_desk"


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)


# --- Consultas ---

func _section() -> Dictionary:
	return economy().get("refund_desk", {})


func get_refund_kinds() -> Array:
	return _section().get("refunds", [GameState.REFUND_SUBSCRIPTION, GameState.REFUND_SHORTCUT_TRAP])


func get_bonus_points() -> int:
	return int(_section().get("bonus_points", 2))


func get_uses_left() -> int:
	return maxi(int(_section().get("uses_per_attempt", 1)) - _uses, 0)


func is_closed() -> bool:
	return get_uses_left() <= 0


## Lo que devolveria ahora del registro del nivel (sin el bonus).
func get_pending() -> int:
	return GameState.get_refundable(GameState.current_level, get_refund_kinds())


## El bonus del secreto ya se dio (en esta partida guardada).
func is_bonus_claimed() -> bool:
	return GameState.is_pickup_collected(GameState.current_level, _bonus_id())


func is_help_available() -> bool:
	return not is_closed()


# --- Acciones ---

func _on_pulsed(_isak: Isak) -> void:
	claim()


## Devuelve (lo usan el pulso y las pruebas). Devuelve el total devuelto (registro +
## bonus); -1 si ya estaba cerrado.
func claim() -> int:
	if is_closed():
		show_message(String(_cfg.get("text_closed", "Cerrado")))
		spark(REJECT_USED)
		return -1
	_uses += 1
	var level: StringName = GameState.current_level
	var back: int = GameState.claim_refunds(level, get_refund_kinds())
	var bonus: int = 0
	if get_bonus_points() > 0 and GameState.mark_pickup_collected(level, _bonus_id()):
		bonus = get_bonus_points()
		GameState.add_attention_points(bonus)
		GameState.request_save()
	_last_total = back + bonus
	show_message(String(_cfg.get("text_done", "Devuelto: {amount}")).replace("{amount}", str(_last_total)))
	refunded.emit(back, bonus)
	return _last_total


func _bonus_id() -> StringName:
	return StringName(BONUS_PREFIX + String(object_id if object_id != &"" else StringName(name)))


# --- Dibujo ---

func _draw() -> void:
	var dr: Array = _cfg.get("desk_rect", [2, 24, 60, 40])
	var desk := Rect2(float(dr[0]), float(dr[1]), float(dr[2]), float(dr[3]))
	draw_rect(desk, _c("desk", "gris_escaparate"))
	draw_rect(Rect2(desk.position, Vector2(desk.size.x, 6.0)), _c("top", "gris_etiqueta"))
	var title: String = String(_cfg.get("text_closed", "Cerrado")) if is_closed() else String(_cfg.get("text_title", "Devoluciones"))
	# El cartel crece con su texto (paso 22, capturas: «Devoluciones» salia cortado en «Devolucio»).
	var text_w: float = ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
	var plate_w: float = maxf(desk.size.x - 4.0, text_w)
	var plate := Rect2(Vector2(desk.get_center().x - plate_w * 0.5, desk.position.y - 26.0), Vector2(plate_w, 18.0))
	draw_rect(plate, _c("sign", "crema_cartel"))
	draw_string(ThemeDB.fallback_font, Vector2(plate.position.x, plate.end.y - 4.0), title,
		HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 11, _c("ink", "negro_medio"))
	if not is_closed():
		draw_diamond(desk.get_center() + Vector2(0.0, 4.0), 7.0, _c("text", "amarillo_rebajas"))
	draw_feedback(Vector2(desk.get_center().x, plate.position.y))
