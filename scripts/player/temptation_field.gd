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
##
## Dano de las Ofertas (2026-10-30, peticion del usuario: «cuando te halen, te quiten vida en
## base a un porcentaje del descuento»; docs/propuesta-mundo-5.md §8.1): mientras una Oferta
## (fuente con DAMAGE_METHOD; ni la lista de deseos ni la maquina de El Vendedor) tira de
## Isak en un estado que lo deja tirar (is_tempted, sin el pulso), tras un aviso rojo de
## damage_warning_s le quita su dano (discount_pct x damage_per_pct, minimo damage_min) cada
## damage_interval_s; varias suman con tope damage_cap por golpe. NUNCA MATA: no baja de
## damage_floor (como la congelacion). Salir de la zona lo reinicia (el siguiente, con aviso).
## Lo lleva tick_damage (estatico: una sola cuenta para todas las Ofertas), que llama en
## cada paso la Oferta lider (OfferSign.step). Valores en la seccion field.
class_name TemptationField
extends RefCounted

const DATA_PATH: String = "res://data/enemies/offer_sign.json"
const GROUP: StringName = &"offer_sign"
const PULL_METHOD: StringName = &"get_pull_weight"
## Fuentes del tiron que ademas hacen dano (OfferSign.get_temptation_damage).
const DAMAGE_METHOD: StringName = &"get_temptation_damage"
const ZONE_METHOD: StringName = &"is_tempting_point"

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

## Dano de las Ofertas: una cuenta compartida (tick_damage). Aviso en curso (s que faltan,
## o -1 sin aviso), tiempo hasta el siguiente golpe y el ultimo golpe (para el dibujo).
static var _dmg_active: bool = false
static var _dmg_warning_left: float = -1.0
static var _dmg_timer: float = 0.0
static var _dmg_last_hit: float = 0.0
static var _dmg_flash_left: float = 0.0


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


## Valor de la seccion field (dano de las Ofertas y demas).
static func field_value(key: String, fallback: float) -> float:
	return float(_field_data().get(key, fallback))


## Dano de un golpe de una Oferta con `discount_pct` de descuento (minimo damage_min).
static func damage_for_discount(discount_pct: float) -> float:
	return maxf(discount_pct * field_value("damage_per_pct", 0.06), field_value("damage_min", 1.0))


## Avanza `dt` (tiempo del mundo) la cuenta del dano de las Ofertas sobre `isak` y devuelve el
## dano hecho en este paso (0 casi siempre). Ver la cabecera.
static func tick_damage(tree: SceneTree, isak: Isak, dt: float) -> float:
	_dmg_flash_left = maxf(_dmg_flash_left - dt, 0.0)
	var dmg: float = damage_now(tree, isak)
	if dmg <= 0.0:
		reset_damage()
		return 0.0
	if not _dmg_active:
		_dmg_active = true
		_dmg_warning_left = field_value("damage_warning_s", 0.75)
		_dmg_timer = _dmg_warning_left
	_dmg_timer -= dt
	if _dmg_warning_left > 0.0:
		_dmg_warning_left = maxf(_dmg_warning_left - dt, 0.0)
	if _dmg_timer > 0.0:
		return 0.0
	_dmg_timer += maxf(field_value("damage_interval_s", 1.0), 0.05)
	_dmg_warning_left = -1.0
	var floor_sync: float = field_value("damage_floor", 1.0)
	var before: float = GameState.sync_rate
	var after: float = maxf(before - dmg, minf(before, floor_sync))
	if after >= before:
		return 0.0
	GameState.sync_rate = after
	_dmg_last_hit = before - after
	_dmg_flash_left = field_value("damage_flash_s", 0.5)
	return _dmg_last_hit


## Dano que harian ahora las Ofertas que tiran de `isak` (suma con tope; 0 si no tiran o
## si Isak esta en un estado que las ignora, en el pulso, invulnerable o muerto).
static func damage_now(tree: SceneTree, isak: Isak) -> float:
	if tree == null or isak == null or not is_instance_valid(isak) or isak.is_dead() or not isak.is_tempted():
		return 0.0
	if isak.get_state_name() == PlayerState.PULSE or isak.is_invulnerable():
		return 0.0
	var point: Vector2 = LevelLookup.isak_body_rect(isak).get_center()
	var total: float = 0.0
	for node: Node in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method(DAMAGE_METHOD) \
				or not node.has_method(ZONE_METHOD):
			continue
		# En su zona y despierta (tambien justo encima, donde la zona muerta ya no tira).
		if not bool(node.call(ZONE_METHOD, point)):
			continue
		total += float(node.call(DAMAGE_METHOD))
	return minf(total, field_value("damage_cap", 6.0))


## Fuera de la zona (o sin tiron): la cuenta vuelve a empezar con aviso.
static func reset_damage() -> void:
	_dmg_active = false
	_dmg_warning_left = -1.0
	_dmg_timer = 0.0


## Aviso rojo antes del primer golpe (las Ofertas lo dibujan).
static func is_damage_warning() -> bool:
	return _dmg_active and _dmg_warning_left > 0.0


## Ultimo golpe de las Ofertas mientras dura su destello (0 si no hay).
static func get_damage_flash() -> float:
	return _dmg_last_hit if _dmg_flash_left > 0.0 else 0.0


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
