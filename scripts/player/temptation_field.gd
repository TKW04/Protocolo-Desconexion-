## Tentacion sobre Isak (Mundo 5 «La Tienda»; paso 2 de docs/propuesta-mundo-5.md §8,
## reglas de §3.3 y decision 6 de §9). Fuerza HORIZONTAL con numeros fijos (seccion
## field de data/enemies/offer_sign.json) que suman las Ofertas (OfferSign, grupo
## offer_sign) cuya zona contiene el centro del cuerpo de Isak:
## - peso = suma de get_pull_weight(punto) de cada Oferta (strength con el signo de
##   hacia donde tira: + derecha, - izquierda; opuestas se restan);
## - deriva = peso x drift_px_s con tope drift_cap_px_s (60 con una, 90 con dos o mas);
## - multiplicador de andar o correr: alejandose 1 - (1 - away_mult) x |peso| con suelo
##   away_min_mult (0,6 con una, 0,45 con dos); acercandose 1 + (toward_mult - 1) x
##   |peso| con el peso topado a drift_cap / drift (1,15 con una, 1,225 como mucho).
## Isak lo aplica en apply_horizontal: objetivo = eje x velocidad x multiplicador + deriva
## (andar alejandose de una Oferta: 132 - 60 = 72 px/s; siempre se sale). El dash, los
## combos y los demas estados que no llaman a apply_horizontal la ignoran (Isak.is_tempted).
class_name TemptationField
extends RefCounted

const DATA_PATH: String = "res://data/enemies/offer_sign.json"
const GROUP: StringName = &"offer_sign"
const PULL_METHOD: StringName = &"get_pull_weight"

static var _shared_field: Dictionary = {}

var drift_px_s: float = 60.0
var away_mult: float = 0.6
var toward_mult: float = 1.15
var drift_cap_px_s: float = 90.0
var away_min_mult: float = 0.45
var dead_zone_px: float = 4.0

## Peso del ultimo sample (con signo; 0 = sin tiron).
var weight: float = 0.0
## Ofertas que tiraban en el ultimo sample.
var sources: int = 0


## Campo con los valores de data/enemies/offer_sign.json (los de por defecto si no se lee).
static func load_default() -> TemptationField:
	var field := TemptationField.new()
	field.configure(_field_data())
	return field


static func _field_data() -> Dictionary:
	if _shared_field.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary and (parsed as Dictionary).get("field") is Dictionary:
			_shared_field = (parsed as Dictionary)["field"]
		else:
			push_error("TemptationField: no se pudo leer la seccion field de %s" % DATA_PATH)
	return _shared_field


func configure(d: Dictionary) -> void:
	drift_px_s = float(d.get("drift_px_s", drift_px_s))
	away_mult = float(d.get("away_mult", away_mult))
	toward_mult = float(d.get("toward_mult", toward_mult))
	drift_cap_px_s = float(d.get("drift_cap_px_s", drift_cap_px_s))
	away_min_mult = float(d.get("away_min_mult", away_min_mult))
	dead_zone_px = float(d.get("dead_zone_px", dead_zone_px))


## Suma el tiron de las Ofertas de `tree` en `point` (global; el centro del cuerpo
## de Isak). Devuelve el peso.
func sample(tree: SceneTree, point: Vector2) -> float:
	weight = 0.0
	sources = 0
	if tree == null:
		return 0.0
	for node: Node in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method(PULL_METHOD):
			continue
		var w: float = float(node.call(PULL_METHOD, point, dead_zone_px))
		if not is_zero_approx(w):
			weight += w
			sources += 1
	return weight


## Sin tiron (Isak en un estado que la ignora).
func clear() -> void:
	weight = 0.0
	sources = 0


func is_pulling() -> bool:
	return not is_zero_approx(weight)


## Deriva horizontal (px/s, con signo) hacia la suma de Ofertas.
func get_drift() -> float:
	return clampf(weight * drift_px_s, -drift_cap_px_s, drift_cap_px_s)


## Multiplicador de la velocidad de andar o correr con el eje `axis` (-1..1).
func get_multiplier(axis: float) -> float:
	if is_zero_approx(axis) or is_zero_approx(weight):
		return 1.0
	var w: float = absf(weight)
	if signf(axis) == signf(weight):
		var cap_w: float = drift_cap_px_s / maxf(drift_px_s, 0.001)
		return 1.0 + (toward_mult - 1.0) * minf(w, cap_w)
	return maxf(away_min_mult, 1.0 - (1.0 - away_mult) * w)


## Velocidad horizontal objetivo con el eje `axis` y la velocidad `speed` (andar,
## correr o comprimido).
func target_speed(axis: float, speed: float) -> float:
	return axis * speed * get_multiplier(axis) + get_drift()
