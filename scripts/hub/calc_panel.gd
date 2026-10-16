## Panel de tienda de Calc dormida (docs/propuesta-hub-y-guardado.md §3.1 y
## §3.2; paso 8 de §6.2). Sustituye a la compra de la pantalla provisional del
## hub (retirada en el paso 9) con las MISMAS reglas, precios y efectos:
## GameState.purchase_upgrade sobre el catalogo de data/upgrades.json. Calc
## esta dormida: no habla; solo hay texto de interfaz (seccion calc de
## data/hub.json).
## - Lineas: saldo de puntos de atencion (ambar), power banks (con su carga) y
##   «Sin guardar» / «Todo guardado».
## - Una opcion por mejora: «Nombre - coste - estado» (Disponible, Comprada,
##   Faltan puntos, Falta power bank); las compradas y las que no se pueden
##   pagar se ven apagadas.
## - Detalle de la elegida bajo la lista: «<label>: <base> a <value>».
## - Pulso compra la elegida (mensaje de compra o de lo que falta); comprar solo
##   marca «sin guardar» (guardado manual en la copia local). Salto cierra.
class_name CalcPanel
extends HubPanel

## Se intento comprar `id` (GameState.PurchaseResult).
signal purchase_attempted(id: StringName, result: int)

var _calc: Dictionary = HubData.section("calc")


func _ready() -> void:
	super._ready()
	EventBus.unsaved_changes_changed.connect(_on_unsaved_changes_changed)


## Rellena el panel con el estado actual de GameState (conserva la eleccion).
func refresh() -> void:
	if _title == null:
		return
	var texts: Dictionary = _calc.get("texts", {})
	var colors: Dictionary = _calc.get("colors", {})
	set_title(String(texts.get("title", "")))
	var unsaved: bool = GameState.has_unsaved_changes()
	set_lines([
		{"text": points_text(), "color": String(colors.get("points", "ambar"))},
		{"text": power_banks_text(), "color": String(colors.get("power_banks", "acento_cian"))},
		{"text": String(texts.get("status_unsaved" if unsaved else "status_saved", "")),
			"color": String(colors.get("unsaved" if unsaved else "saved", "texto_tenue"))},
	])
	var options: Array = []
	for entry: UpgradeCatalog.Entry in UpgradeCatalog.shared().entries():
		var role: String = String(colors.get("upgrade", "texto_claro"))
		var check: int = GameState.check_purchase(entry.id)
		if check == GameState.PurchaseResult.ALREADY_OWNED:
			role = String(colors.get("upgrade_owned", "texto_tenue"))
		elif check != GameState.PurchaseResult.OK:
			role = String(colors.get("upgrade_unaffordable", "gris_foto"))
		options.append({"id": entry.id, "text": upgrade_text(entry.id), "role": role})
	set_options(options)
	_refresh_detail()
	set_help(String(texts.get("help", "")))
	super.refresh()


## «Puntos de atención: 30».
func points_text() -> String:
	return String(_calc.get("texts", {}).get("points", "%d")) % GameState.attention_points


## «Power banks: 1 (carga 0/100)».
func power_banks_text() -> String:
	return String(_calc.get("texts", {}).get("power_banks", "%d %d %d")) % [
		GameState.power_banks, floori(GameState.power_bank_charge), roundi(GameState.get_power_bank_capacity())]


## Ids de las mejoras en el orden del panel (el del catalogo).
func get_upgrade_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: UpgradeCatalog.Entry in UpgradeCatalog.shared().entries():
		out.append(entry.id)
	return out


## Mejora elegida (vacio si no hay).
func get_selected_upgrade() -> StringName:
	return get_selected_option()


## Texto de la mejora `id`: «Pulso amplio - 25 pts - Disponible».
func upgrade_text(id: StringName) -> String:
	var texts: Dictionary = _calc.get("texts", {})
	var entry: UpgradeCatalog.Entry = UpgradeCatalog.shared().get_entry(id)
	var cost: String
	if entry.cost_power_banks > 0:
		cost = String(texts.get("cost_points_and_banks", "%d %d")) % [entry.cost_points, entry.cost_power_banks]
	else:
		cost = String(texts.get("cost_points", "%d")) % entry.cost_points
	return String(texts.get("upgrade_row", "%s %s %s")) % [entry.name, cost, state_text(id)]


## Estado de la mejora `id` (Comprada, Disponible, Faltan puntos, Falta power bank).
func state_text(id: StringName) -> String:
	var texts: Dictionary = _calc.get("texts", {})
	match GameState.check_purchase(id):
		GameState.PurchaseResult.ALREADY_OWNED:
			return String(texts.get("state_owned", ""))
		GameState.PurchaseResult.NOT_ENOUGH_POINTS:
			return String(texts.get("state_not_enough_points", ""))
		GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS:
			return String(texts.get("state_not_enough_power_banks", ""))
	return String(texts.get("state_available", ""))


## Detalle de la mejora `id` (por defecto la elegida): «Radio del pulso: 96 px a 112 px».
func detail_text(id: StringName = &"") -> String:
	if id.is_empty():
		id = get_selected_upgrade()
	if id.is_empty():
		return ""
	var entry: UpgradeCatalog.Entry = UpgradeCatalog.shared().get_entry(id)
	return String(_calc.get("texts", {}).get("detail", "%s %s%s %s%s")) % [
		entry.label, format_number(GameState.base_value(entry.target)), entry.unit,
		format_number(entry.value), entry.unit]


## Compra la mejora elegida (GameState.purchase_upgrade) y muestra el resultado.
## Devuelve el GameState.PurchaseResult.
func purchase_selected() -> int:
	var id: StringName = get_selected_upgrade()
	var result: int = GameState.purchase_upgrade(id)
	var texts: Dictionary = _calc.get("texts", {})
	var colors: Dictionary = _calc.get("colors", {})
	var key: String = "message_bought"
	match result:
		GameState.PurchaseResult.ALREADY_OWNED:
			key = "message_owned"
		GameState.PurchaseResult.NOT_ENOUGH_POINTS:
			key = "message_not_enough_points"
		GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS:
			key = "message_not_enough_power_banks"
	var message: String = String(texts.get(key, ""))
	if result == GameState.PurchaseResult.OK:
		message = message % UpgradeCatalog.shared().get_entry(id).name
	refresh()
	set_message(message, String(colors.get("message_bought" if result == GameState.PurchaseResult.OK else "message",
		"texto_claro")))
	purchase_attempted.emit(id, result)
	return result


## Numero para pantalla: sin decimales si es entero; coma decimal.
static func format_number(value: float) -> String:
	if is_nan(value):
		return "?"
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2).replace(".", ",")


# --- HubPanel ---

func _on_confirm(_id: StringName) -> void:
	purchase_selected()


func _on_selection_changed() -> void:
	_refresh_detail()


# --- Interno ---

func _refresh_detail() -> void:
	set_detail(detail_text(), String(_calc.get("colors", {}).get("detail", "texto_tenue")))


func _on_unsaved_changes_changed(_has_changes: bool) -> void:
	if is_open():
		var message: String = get_message()
		refresh()
		_message.text = message
		_layout()
