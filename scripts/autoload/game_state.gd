# GameState (autoload)
# Estado global de la partida. Única fuente de verdad para:
# - Sync Rate (la vida de Isak, en porcentaje).
# - Energía de Debug (barra secundaria que gasta el Debug Mode).
# - Puntos de atención (la moneda).
# - Fragmentos recuperados y nivel actual.
# - Habilidades desbloqueadas (se desbloquean por mundo).
# - Mundo actual y los ajustes de accesibilidad (Sync Rate bajo, contorno del Debug).
# - Escala de tiempo del mundo (world_time_scale): la fija DebugMode y la leen
#   los objetos del mundo con WorldTime.scaled_delta() (Isak y el HUD no).
# - Progreso persistente (decisiones del 2026-10-14): puntos acumulados, ids de
#   puntos de atención ya capturados por nivel, mejoras compradas
#   (data/upgrades.json), power banks (completos, vacios y carga parcial,
#   data/power_bank.json) y niveles completados/desbloqueados. Se guarda en
#   save_path (user://save.json; en las pruebas otra ruta) con SaveFile.
# Cada setter acota el valor y emite la señal correspondiente por EventBus.
# Reglas de juego que viven aquí: recarga de energía por punto de atención
# (A10), desbordamiento de energía a power bank, compra de mejoras y valores
# efectivos (base + mejoras). Quién gasta, cura o desbloquea vive en otros scripts.
extends Node

const SYNC_RATE_MAX: float = 100.0
const SYNC_RATE_MIN: float = 0.0
# Barra normalizada a 100 hasta que el diseño fije su capacidad real.
const DEBUG_ENERGY_MAX: float = 100.0
const DEBUG_ENERGY_MIN: float = 0.0
const ATTENTION_POINTS_MIN: int = 0
const FRAGMENTS_MIN: int = 0
const NO_LEVEL: StringName = &""
const FIRST_WORLD: int = 1
const LAST_WORLD: int = 6
## Escala de tiempo del mundo sin Debug (ver WorldTime).
const WORLD_TIME_SCALE_NORMAL: float = 1.0
## Energia que repone cada punto de atencion recogido (A10, aprobado). Valor
## base: la mejora "Recarga mejorada" lo cambia (get_energy_per_attention_point).
const ENERGY_PER_ATTENTION_POINT: float = 10.0

## Guardado (SaveFile). Version del esquema de save.json.
const SAVE_VERSION: int = 1
const SAVE_PATH_DEFAULT: String = "user://save.json"
## Ruta de guardado de las pruebas GUT (nunca el save real del usuario).
const SAVE_PATH_TESTS: String = "user://test_save.json"
## Variable de entorno que fuerza otra ruta de guardado (bots, pruebas).
const SAVE_PATH_ENV: String = "ISAK_SAVE_PATH"
const POWER_BANK_DATA_PATH: String = "res://data/power_bank.json"
## Valores base de los target "game_state.*" de las mejoras.
const BASE_VALUES: Dictionary[StringName, float] = {
	&"game_state.sync_rate_max": SYNC_RATE_MAX,
	&"game_state.debug_energy_max": DEBUG_ENERGY_MAX,
	&"game_state.energy_per_attention_point": ENERGY_PER_ATTENTION_POINT,
}

## Resultado de comprar una mejora.
enum PurchaseResult { OK, UNKNOWN, ALREADY_OWNED, NOT_ENOUGH_POINTS, NOT_ENOUGH_POWER_BANKS }

const ABILITY_PULSE: StringName = &"pulse"
const ABILITY_DEBUG: StringName = &"debug"
const ABILITY_DASH: StringName = &"dash"
const ABILITY_GROUND_POUND: StringName = &"ground_pound"
const ABILITY_COMPRESS: StringName = &"compress"
const ABILITY_SHOCKWAVE: StringName = &"shockwave"
const ABILITIES: Array[StringName] = [
	ABILITY_PULSE,
	ABILITY_DEBUG,
	ABILITY_DASH,
	ABILITY_GROUND_POUND,
	ABILITY_COMPRESS,
	ABILITY_SHOCKWAVE,
]

## Sync Rate actual; tope get_sync_rate_max() (100, o mas con "Sync reforzado").
var sync_rate: float = SYNC_RATE_MAX:
	set(value):
		var max_value: float = get_sync_rate_max()
		sync_rate = clampf(value, SYNC_RATE_MIN, max_value)
		EventBus.sync_rate_changed.emit(sync_rate, max_value)
		_update_low_sync()

## Energia de Debug; tope get_debug_energy_max() (100, o mas con "Bateria ampliada").
var debug_energy: float = DEBUG_ENERGY_MAX:
	set(value):
		var max_value: float = get_debug_energy_max()
		debug_energy = clampf(value, DEBUG_ENERGY_MIN, max_value)
		EventBus.energy_changed.emit(debug_energy, max_value)

## Puntos de atencion acumulados (la moneda). Persisten entre partidas y
## niveles (decision 2026-10-14): el flujo de nivel ya no los pone a 0.
var attention_points: int = ATTENTION_POINTS_MIN:
	set(value):
		attention_points = maxi(value, ATTENTION_POINTS_MIN)
		EventBus.attention_points_changed.emit(attention_points)

## Power banks completos (solo sirven para pagar mejoras).
var power_banks: int = 0:
	set(value):
		power_banks = maxi(value, 0)
		_emit_power_banks()

## Power banks que Isak tiene pero aun no estan llenos (decision 2026-10-14: un
## power bank comprado u obtenido llega VACIO y se carga con el sobrante de
## energia de los drops). Sin ninguno, el sobrante se pierde.
var empty_power_banks: int = 0:
	set(value):
		empty_power_banks = maxi(value, 0)
		_emit_power_banks()

## Carga del power bank vacio que se esta llenando (0 a get_power_bank_capacity();
## siempre 0 si no hay power banks vacios).
var power_bank_charge: float = 0.0:
	set(value):
		power_bank_charge = maxf(value, 0.0)
		_emit_power_banks()

## Ids de puntos de atencion ya capturados por nivel (id de nivel -> {id: true}).
## No reaparecen ni cuentan al rejugar el nivel.
var captured_points: Dictionary[StringName, Dictionary] = {}
## Mejoras compradas (id de data/upgrades.json -> true).
var purchased_upgrades: Dictionary[StringName, bool] = {}

## Ruta del guardado. Por defecto user://save.json; con la variable de entorno
## ISAK_SAVE_PATH, esa ruta; dentro de GUT, SAVE_PATH_TESTS (se borra al
## arrancar). Cambiala con use_save_path().
var save_path: String = SAVE_PATH_DEFAULT
## Si es false, request_save() no escribe nada.
var autosave_enabled: bool = true

var fragments_recovered: int = FRAGMENTS_MIN:
	set(value):
		fragments_recovered = maxi(value, FRAGMENTS_MIN)

var current_level: StringName = NO_LEVEL

## Ultimo punto de sincronizacion tocado en cada nivel (id de nivel -> id de
## checkpoint). Solo hay uno activo por nivel: el mas reciente. Lo escribe
## Checkpoint y lo borra el flujo de nivel (LevelRunner) al empezar de cero.
var last_checkpoint: Dictionary[StringName, StringName] = {}
## Niveles completados y niveles desbloqueados (por `unlocks` del JSON del
## nivel). Los guarda LevelRunner al terminar un nivel; aun no van a disco.
var completed_levels: Dictionary[StringName, bool] = {}
var unlocked_levels: Dictionary[StringName, bool] = {}

## Mundo actual (1-6). Decide el color del Debug.
var current_world: int = FIRST_WORLD:
	set(value):
		current_world = clampi(value, FIRST_WORLD, LAST_WORLD)
		EventBus.world_changed.emit(current_world)

## Ajuste de accesibilidad (docs 3.3 y 15.6): reducir el ruido y la distorsion
## de Sync Rate bajo. Aun no se guarda en disco (no hay menu de opciones).
var reduce_low_sync_effects: bool = false:
	set(value):
		reduce_low_sync_effects = value
		EventBus.reduce_low_sync_effects_changed.emit(value)

## Ajuste de accesibilidad (docs 15.6, "contorno claro para daltonismo"): las
## plataformas ocultas del Debug usan un contorno mas claro y grueso
## (data/debug_mode.json, high_contrast_*). Aun no se guarda en disco.
var debug_high_contrast_outline: bool = false:
	set(value):
		debug_high_contrast_outline = value
		EventBus.debug_high_contrast_outline_changed.emit(value)

## Escala de tiempo del mundo (1 = normal). Solo la escribe DebugMode; el
## mundo la consume con WorldTime.scaled_delta(). No es Engine.time_scale.
var world_time_scale: float = WORLD_TIME_SCALE_NORMAL:
	set(value):
		var clamped: float = maxf(value, 0.0)
		if clamped == world_time_scale:
			return
		world_time_scale = clamped
		EventBus.world_time_scale_changed.emit(world_time_scale)

## Umbral (en % de Sync Rate) del estado de Sync Rate bajo; de data/hud.json.
var low_sync_threshold: float = HudConfig.shared().low_sync_threshold

var _is_sync_low: bool = false

var abilities_unlocked: Dictionary[StringName, bool] = _build_locked_abilities()

var _power_bank_data: Dictionary = _load_power_bank_data()
var _save_pending: bool = false
## Valores base de isak_abilities.json (para el detalle de las mejoras).
var _base_abilities: PlayerAbilities


func _ready() -> void:
	EventBus.state_refresh_requested.connect(emit_state)
	if is_running_tests() and OS.get_environment(SAVE_PATH_ENV).is_empty():
		use_save_path(SAVE_PATH_TESTS, true)
	else:
		var env_path: String = OS.get_environment(SAVE_PATH_ENV)
		use_save_path(SAVE_PATH_DEFAULT if env_path.is_empty() else env_path, false)


## Sync Rate bajo: por debajo del umbral (estrictamente menor, docs: "menor al 20%").
func is_sync_low() -> bool:
	return _is_sync_low


## Resta Sync Rate (dano de prueba de la arena; el dano real llega en el paso 9).
func apply_sync_damage(amount: float) -> void:
	sync_rate -= maxf(amount, 0.0)


## Suma puntos de atencion; cada uno repone energia de Debug (A10; la mejora
## "Recarga mejorada" sube cuanto). Si la barra ya esta llena, el sobrante solo
## va al power bank cuando attention_point_energy_overflows es true (decision
## 2026-10-14: false, solo desbordan los drops de enemigos).
func add_attention_points(amount: int) -> void:
	if amount <= 0:
		return
	attention_points += amount
	add_debug_energy(amount * get_energy_per_attention_point(),
			bool(_power_bank_data.get("attention_point_energy_overflows", false)))


## Captura el punto de atencion `point_id` del nivel `level`: suma `value`
## puntos (con su energia) y lo apunta como capturado (persistente). Falso si
## ya estaba capturado: no cuenta otra vez. Sin nivel (escenas de prueba) no
## se apunta nada y siempre cuenta.
func capture_attention_point(level: StringName, point_id: StringName, value: int) -> bool:
	if level != NO_LEVEL:
		if is_attention_point_captured(level, point_id):
			return false
		if not captured_points.has(level):
			captured_points[level] = {}
		captured_points[level][point_id] = true
	add_attention_points(value)
	request_save()
	return true


func is_attention_point_captured(level: StringName, point_id: StringName) -> bool:
	return captured_points.has(level) and captured_points[level].has(point_id)


## Ids capturados en `level` (ordenados).
func get_captured_points(level: StringName) -> Array[StringName]:
	var names: Array[String] = []
	if captured_points.has(level):
		for id: Variant in captured_points[level]:
			names.append(String(id))
	names.sort()
	var out: Array[StringName] = []
	for id: String in names:
		out.append(StringName(id))
	return out


## Recarga de energia de Debug (drops de enemigos y jefes, puntos de atencion).
## Lo que no cabe en la barra carga los power banks vacios (si
## `overflow_to_power_bank`; ver add_power_bank_charge).
## Devuelve el sobrante que no entro en la barra.
func add_debug_energy(amount: float, overflow_to_power_bank: bool = true) -> float:
	if amount <= 0.0:
		return 0.0
	var room: float = maxf(get_debug_energy_max() - debug_energy, 0.0)
	var to_bar: float = minf(amount, room)
	if to_bar > 0.0:
		debug_energy += to_bar
	var overflow: float = amount - to_bar
	if overflow > 0.0 and overflow_to_power_bank:
		add_power_bank_charge(overflow)
	return overflow


## Suma un power bank VACIO (comprado u obtenido; decision 2026-10-14). Se
## llena con el sobrante de energia de los drops (add_power_bank_charge).
func add_empty_power_bank(count: int = 1) -> void:
	if count <= 0:
		return
	empty_power_banks += count
	request_save()


## Carga los power banks vacios con `amount` de energia: cada
## get_power_bank_capacity() llena uno, que pasa a completo. Lo que no cabe
## (sin power banks vacios) se pierde. Devuelve la energia que no se uso.
func add_power_bank_charge(amount: float) -> float:
	var capacity: float = get_power_bank_capacity()
	if amount <= 0.0 or capacity <= 0.0 or empty_power_banks <= 0:
		return maxf(amount, 0.0)
	var charge: float = power_bank_charge + amount
	var empties: int = empty_power_banks
	var completed: int = 0
	while empties > 0 and charge >= capacity - 0.0001:
		charge -= capacity
		empties -= 1
		completed += 1
	var wasted: float = 0.0
	if empties == 0:
		wasted = maxf(charge, 0.0)
		charge = 0.0
	empty_power_banks = empties
	power_bank_charge = maxf(charge, 0.0)
	if completed > 0:
		power_banks += completed
	request_save()
	return wasted


## Recarga de Sync Rate (drops de enemigos y jefes), acotada al maximo efectivo.
func heal_sync(amount: float) -> void:
	if amount <= 0.0:
		return
	sync_rate += amount


func get_power_bank_capacity() -> float:
	return float(_power_bank_data.get("capacity_energy", 200.0))


## Ajustes del contador del HUD (seccion "hud" de data/power_bank.json).
func get_power_bank_hud_data() -> Dictionary:
	return _power_bank_data.get("hud", {})


# --- Mejoras permanentes (data/upgrades.json) ---

func get_sync_rate_max() -> float:
	return effective_value(&"game_state.sync_rate_max", SYNC_RATE_MAX)


func get_debug_energy_max() -> float:
	return effective_value(&"game_state.debug_energy_max", DEBUG_ENERGY_MAX)


func get_energy_per_attention_point() -> float:
	return effective_value(&"game_state.energy_per_attention_point", ENERGY_PER_ATTENTION_POINT)


## Valor efectivo de `target` ("<origen>.<clave>"): `base` cambiado por las
## mejoras compradas (gana la ultima del catalogo que lo toque).
func effective_value(target: StringName, base: float) -> float:
	var value: float = base
	for entry: UpgradeCatalog.Entry in UpgradeCatalog.shared().entries():
		if entry.target == target and purchased_upgrades.has(entry.id):
			value = entry.value
	return value


## Aplica a `object` (p. ej. PlayerAbilities) las mejoras compradas cuyo target
## empieza por `source` + "." y cuya clave es una propiedad de `object`.
func apply_upgrades(object: Object, source: String) -> void:
	for entry: UpgradeCatalog.Entry in UpgradeCatalog.shared().entries():
		if entry.source() == source and purchased_upgrades.has(entry.id) and entry.key() in object:
			object.set(entry.key(), entry.value)


## Valor base (sin mejoras) de `target`; NAN si el target no existe.
func base_value(target: StringName) -> float:
	if BASE_VALUES.has(target):
		return BASE_VALUES[target]
	var source: String = String(target).get_slice(".", 0)
	var key: String = String(target).substr(source.length() + 1)
	var object: Object = null
	match source:
		"debug_mode":
			object = DebugModeConfig.shared()
		"isak_abilities":
			if _base_abilities == null:
				_base_abilities = PlayerAbilities.load_from_file()
			object = _base_abilities
	if object == null or key.is_empty() or not key in object:
		return NAN
	return float(object.get(key))


func is_upgrade_purchased(id: StringName) -> bool:
	return purchased_upgrades.has(id)


## Si se puede comprar `id` ahora (OK) o por que no.
func check_purchase(id: StringName) -> int:
	var entry: UpgradeCatalog.Entry = UpgradeCatalog.shared().get_entry(id)
	if entry == null:
		return PurchaseResult.UNKNOWN
	if purchased_upgrades.has(id):
		return PurchaseResult.ALREADY_OWNED
	if attention_points < entry.cost_points:
		return PurchaseResult.NOT_ENOUGH_POINTS
	if power_banks < entry.cost_power_banks:
		return PurchaseResult.NOT_ENOUGH_POWER_BANKS
	return PurchaseResult.OK


## Compra `id`: gasta puntos y power banks, la apunta y guarda. Si no se puede
## no cambia nada y devuelve el motivo.
func purchase_upgrade(id: StringName) -> int:
	var result: int = check_purchase(id)
	if result != PurchaseResult.OK:
		return result
	var entry: UpgradeCatalog.Entry = UpgradeCatalog.shared().get_entry(id)
	attention_points -= entry.cost_points
	power_banks -= entry.cost_power_banks
	purchased_upgrades[id] = true
	_refresh_maxima()
	EventBus.upgrade_purchased.emit(id)
	request_save()
	return PurchaseResult.OK


# --- Guardado (user://save.json) ---

## Cambia la ruta de guardado. `fresh`: borra lo que hubiera y empieza de cero;
## si no, carga lo guardado en esa ruta.
func use_save_path(path: String, fresh: bool) -> void:
	save_path = path
	if fresh:
		SaveFile.delete(path)
		reset_progress()
	else:
		load_game()


## Verdadero si el juego corre dentro de GUT (no se toca el save real).
static func is_running_tests() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.contains("addons/gut/"):
			return true
	return false


## Borra el progreso persistente en memoria (no toca el disco).
func reset_progress() -> void:
	attention_points = ATTENTION_POINTS_MIN
	captured_points.clear()
	purchased_upgrades.clear()
	power_banks = 0
	empty_power_banks = 0
	power_bank_charge = 0.0
	completed_levels.clear()
	unlocked_levels.clear()
	_refresh_maxima()


## Pide guardar al final del cuadro (agrupa varios cambios en una escritura).
func request_save() -> void:
	if not autosave_enabled or _save_pending:
		return
	_save_pending = true
	_flush_save.call_deferred()


## Guarda ya en save_path. Verdadero si se escribio.
func save_game() -> bool:
	_save_pending = false
	return SaveFile.write(save_path, to_save_data())


## Carga save_path. Si falta o esta corrupto empieza de cero (falso).
func load_game() -> bool:
	var data: Dictionary = SaveFile.read(save_path)
	reset_progress()
	if data.is_empty():
		return false
	if not apply_save_data(data):
		push_warning("GameState: guardado '%s' con version no soportada; se aparta y se empieza de cero." % save_path)
		SaveFile.quarantine(save_path)
		reset_progress()
		return false
	return true


## Progreso persistente como diccionario JSON (esquema SAVE_VERSION).
func to_save_data() -> Dictionary:
	var captured: Dictionary = {}
	for level: StringName in captured_points:
		var ids: Array[String] = []
		for id: StringName in get_captured_points(level):
			ids.append(String(id))
		captured[String(level)] = ids
	return {
		"version": SAVE_VERSION,
		"attention_points": attention_points,
		"captured_points": captured,
		"upgrades_purchased": _keys_sorted(purchased_upgrades),
		"power_banks": {"full": power_banks, "empty": empty_power_banks, "charge": power_bank_charge},
		"completed_levels": _keys_sorted(completed_levels),
		"unlocked_levels": _keys_sorted(unlocked_levels),
	}


## Aplica un guardado (tolerante a campos que falten o con tipo raro). Falso si
## la version no se reconoce (no aplica nada).
func apply_save_data(data: Dictionary) -> bool:
	var version: Variant = data.get("version", null)
	if not (version is float or version is int) or int(version) < 1 or int(version) > SAVE_VERSION:
		return false
	reset_progress()
	attention_points = _as_int(data.get("attention_points", 0))
	var captured: Variant = data.get("captured_points", {})
	if captured is Dictionary:
		for level: Variant in captured:
			var ids: Variant = captured[level]
			if not ids is Array:
				continue
			var ids_set: Dictionary = {}
			for id: Variant in ids:
				if id is String:
					ids_set[StringName(id)] = true
			captured_points[StringName(String(level))] = ids_set
	for id: StringName in _string_names(data.get("upgrades_purchased", [])):
		if UpgradeCatalog.shared().has(id):
			purchased_upgrades[id] = true
	var banks: Variant = data.get("power_banks", {})
	if banks is Dictionary:
		power_banks = _as_int(banks.get("full", 0))
		var charge: float = clampf(_as_float(banks.get("charge", 0.0)), 0.0, get_power_bank_capacity())
		# Guardados de antes de los power banks vacios (sin "empty"): la carga
		# parcial que tenian se conserva en un power bank vacio.
		var empty: int = _as_int(banks.get("empty", 1 if charge > 0.0 else 0))
		empty_power_banks = empty
		power_bank_charge = charge if empty > 0 else 0.0
	for id: StringName in _string_names(data.get("completed_levels", [])):
		completed_levels[id] = true
	for id: StringName in _string_names(data.get("unlocked_levels", [])):
		unlocked_levels[id] = true
	_refresh_maxima()
	return true


## Reemite todo el estado que muestra el HUD (al aparecer un HUD nuevo).
func emit_state() -> void:
	EventBus.world_changed.emit(current_world)
	EventBus.reduce_low_sync_effects_changed.emit(reduce_low_sync_effects)
	EventBus.debug_high_contrast_outline_changed.emit(debug_high_contrast_outline)
	EventBus.sync_rate_changed.emit(sync_rate, get_sync_rate_max())
	EventBus.energy_changed.emit(debug_energy, get_debug_energy_max())
	EventBus.attention_points_changed.emit(attention_points)
	EventBus.low_sync_changed.emit(_is_sync_low)
	_emit_power_banks()


## Fija el ultimo punto de sincronizacion de `level` (sustituye al anterior).
func set_last_checkpoint(level: StringName, checkpoint_id: StringName) -> void:
	if last_checkpoint.get(level, NO_LEVEL) == checkpoint_id:
		return
	last_checkpoint[level] = checkpoint_id
	EventBus.checkpoint_activated.emit(String(level), checkpoint_id)


## Ultimo punto de sincronizacion de `level` o &"" si no hay ninguno.
func get_last_checkpoint(level: StringName) -> StringName:
	return last_checkpoint.get(level, NO_LEVEL)


func clear_last_checkpoint(level: StringName) -> void:
	last_checkpoint.erase(level)


func mark_level_completed(level: StringName) -> void:
	completed_levels[level] = true
	request_save()


func is_level_completed(level: StringName) -> bool:
	return completed_levels.get(level, false)


func unlock_level(level: StringName) -> void:
	unlocked_levels[level] = true
	request_save()


func is_level_unlocked(level: StringName) -> bool:
	return unlocked_levels.get(level, false)


func is_ability_unlocked(ability: StringName) -> bool:
	return abilities_unlocked.get(ability, false)


func set_ability_unlocked(ability: StringName, unlocked: bool) -> void:
	if not abilities_unlocked.has(ability):
		push_error("GameState: unknown ability '%s'" % ability)
		return
	if abilities_unlocked[ability] == unlocked:
		return
	abilities_unlocked[ability] = unlocked
	EventBus.ability_unlock_changed.emit(ability, unlocked)


func _update_low_sync() -> void:
	var low: bool = sync_rate < low_sync_threshold
	if low == _is_sync_low:
		return
	_is_sync_low = low
	EventBus.low_sync_changed.emit(low)


func _build_locked_abilities() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for ability: StringName in ABILITIES:
		result[ability] = false
	return result


func _emit_power_banks() -> void:
	EventBus.power_banks_changed.emit(power_banks, power_bank_charge, get_power_bank_capacity())


## Reaplica los topes (y avisa al HUD) tras cambiar las mejoras.
func _refresh_maxima() -> void:
	sync_rate = sync_rate
	debug_energy = debug_energy


func _flush_save() -> void:
	if _save_pending:
		save_game()


static func _load_power_bank_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POWER_BANK_DATA_PATH))
	if not parsed is Dictionary:
		push_error("GameState: no se pudo leer '%s'." % POWER_BANK_DATA_PATH)
		return {}
	return parsed


static func _keys_sorted(dict: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in dict:
		out.append(String(key))
	out.sort()
	return out


static func _string_names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for item: Variant in raw:
			if item is String:
				out.append(StringName(item))
	return out


static func _as_int(raw: Variant) -> int:
	return maxi(int(raw), 0) if (raw is float or raw is int) else 0


static func _as_float(raw: Variant) -> float:
	return maxf(float(raw), 0.0) if (raw is float or raw is int) else 0.0
