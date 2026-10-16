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
#   data/power_bank.json), habilidades obtenidas con un ability_pickup (p. ej.
#   el laser, 2026-10-15) y niveles completados/desbloqueados. Se guarda en
#   save_path (user://save.json; en las pruebas otra ruta) con SaveFile.
# - Guardado MANUAL (decision 2026-10-15, docs/propuesta-hub-y-guardado.md):
#   los cambios de progreso solo marcan "sin guardar" (request_save,
#   has_unsaved_changes, EventBus.unsaved_changes_changed); solo save_game()
#   escribe (en el hub; la copia anterior queda en <ruta>.bak). Esquema v2:
#   vuelta (lap), secretos encontrados, tutorial del hub, fecha y tiempo de juego.
# - Vidas (intentos; 2026-10-16): lives (no se guarda) hasta lives_max; ver
#   are_lives_active, refill_lives y lose_life (docs/propuesta-asistentes-y-vidas.md §5.1).
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

## Guardado (SaveFile). Version del esquema de save.json (v2 desde 2026-10-15:
## lap, found_secrets, saved_at, play_time_s; v3 desde 2026-10-15 (3), paso 2 de
## docs/propuesta-asistentes-y-vidas.md §10: nickname, allies_met, learned_help
## y lives_max, que sustituyen a hub_tutorial_done). Se cargan las versiones 1 a
## SAVE_VERSION (las anteriores se migran); otra se aparta como .corrupt.
const SAVE_VERSION: int = 3
## Vueltas (docs/preguntas.md, tres vueltas): 1 Easy, 2 Normal, 3 Hard (nombres
## internos; de cara al jugador son niveles de acceso Caché, Kernel y Raíz, ver
## HubWorlds.access_name: la UI nunca dice vuelta ni Easy/Normal/Hard).
const LAP_EASY: int = 1
const LAP_NORMAL: int = 2
const LAP_HARD: int = 3
## Nivel cuyo final lleva al primer hub: al migrar un guardado v1/v2 con este
## nivel completado, Eco y Notas cuentan como conocidos (propuesta §6).
const HUB_TUTORIAL_LEVEL: StringName = &"1-1"
## Asistentes conocidos (allies_met; docs/propuesta-asistentes-y-vidas.md §2).
const ALLY_ECO: StringName = &"eco"
const ALLY_NOTAS: StringName = &"notas"
const ALLY_CALC: StringName = &"calc"
const ALLY_LINTERNA: StringName = &"linterna"
const ALLY_PAPELERA: StringName = &"papelera"
const ALLIES: Array[StringName] = [ALLY_ECO, ALLY_NOTAS, ALLY_CALC, ALLY_LINTERNA, ALLY_PAPELERA]
## Apodo con el que Eco llama al jugador si no elige otro (propuesta §2.1).
const NICKNAME_DEFAULT: String = "Isak"
## Largo maximo del apodo (propuesta §6; entrada del apodo, NicknameEntry).
const NICKNAME_MAX_LENGTH: int = 12
## Marcador de las lineas de Eco que se sustituye por el apodo (apply_nickname;
## EcoTextBox y HelpCatalog lo resuelven al mostrar el texto).
const NICKNAME_TAG: String = "{apodo}"
## Vidas (intentos) maximas de partida (propuesta §5.1; sube con cada vida extra).
const LIVES_MAX_DEFAULT: int = 3
## Argumento de usuario de las builds de depuracion que da por conocido un
## asistente al arrancar (p. ej. `-- --meet-ally=calc`): hasta que exista el
## encuentro con Calc al final del 1-2, es la forma de probar la tienda del hub.
const DEBUG_MEET_ALLY_ARG: String = "--meet-ally="
const SAVE_PATH_DEFAULT: String = "user://save.json"
## Ruta de guardado de las pruebas GUT (nunca el save real del usuario).
const SAVE_PATH_TESTS: String = "user://test_save.json"
## Ruta de guardado de los scripts de herramientas (-s tools/render_*.gd, bots):
## mueven a Isak y capturan puntos, asi que nunca usan el save real.
const SAVE_PATH_TOOLS: String = "user://tool_save.json"
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
## Laser (decision del usuario 2026-10-15): desbloqueable con un ability_pickup;
## gasta energia de Debug (data/isak_abilities.json, laser_*).
const ABILITY_LASER: StringName = &"laser"
const ABILITIES: Array[StringName] = [
	ABILITY_PULSE,
	ABILITY_DEBUG,
	ABILITY_DASH,
	ABILITY_GROUND_POUND,
	ABILITY_COMPRESS,
	ABILITY_SHOCKWAVE,
	ABILITY_LASER,
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
## Ids de power banks de mapa (power_bank_pickup) ya recogidos por nivel (id de
## nivel -> {id: true}). Como los puntos: no reaparecen al rejugar el nivel.
var collected_pickups: Dictionary[StringName, Dictionary] = {}
## Mejoras compradas (id de data/upgrades.json -> true).
var purchased_upgrades: Dictionary[StringName, bool] = {}
## Habilidades obtenidas para siempre con un ability_pickup (id -> true; p. ej.
## laser). Se guardan y, al cargar, quedan desbloqueadas en abilities_unlocked.
var obtained_abilities: Dictionary[StringName, bool] = {}
## Avisos de control ya mostrados (id de data/ability_notices.json -> true;
## AbilityNotices). Se guardan (seen_notices); en guardados antiguos sin esa
## clave, y siempre, las habilidades obtenidas cuentan como avisadas.
var seen_notices: Dictionary[StringName, bool] = {}

## Vuelta actual (LAP_EASY a LAP_HARD). Solo la cambiara el rollback.
var lap: int = LAP_EASY:
	set(value):
		lap = clampi(value, LAP_EASY, LAP_HARD)
## Secretos encontrados por nivel (id de nivel -> {id: true}). Registro para
## Linterna y Notas: el rollback no lo vacia (decision 2026-10-15).
var found_secrets: Dictionary[StringName, Dictionary] = {}
## Apodo con el que Eco llama al jugador (v3; por defecto NICKNAME_DEFAULT).
var nickname: String = NICKNAME_DEFAULT
## Asistentes ya conocidos (id de ALLIES -> true; v3). Sustituye a eco_met y a
## hub_tutorial_done (= "notas"). Registro: no marca "sin guardar" por si solo.
var allies_met: Dictionary[StringName, bool] = {}
## Tipos de ayuda con Q ya aprendidos (id de data/help.json -> true; v3). No
## marca "sin guardar": va a disco con la siguiente copia (como seen_notices).
var learned_help: Dictionary[StringName, bool] = {}
## Vidas (intentos) maximas (v3). Las vidas actuales no se guardan.
var lives_max: int = LIVES_MAX_DEFAULT
## Vidas (intentos) del intento en curso (no se guardan): refill_lives las
## repone a lives_max al empezar cada intento de nivel; lose_life resta una.
## Solo cuentan con are_lives_active() (desde la primera llegada al hub).
var lives: int = LIVES_MAX_DEFAULT

## Segundos de juego (con el arbol sin pausar). Se guarda con la copia.
var play_time_s: float = 0.0
## Fecha (UTC, "AAAA-MM-DDTHH:MM:SSZ") de la ultima copia guardada o cargada;
## vacia si no hay ninguna.
var saved_at: String = ""

## Ruta del guardado. Por defecto user://save.json; con la variable de entorno
## ISAK_SAVE_PATH, esa ruta; dentro de GUT, SAVE_PATH_TESTS, y con otro script
## (-s), SAVE_PATH_TOOLS (estas dos se borran al arrancar). Ver
## resolve_save_path(). Cambiala con use_save_path().
var save_path: String = SAVE_PATH_DEFAULT

var fragments_recovered: int = FRAGMENTS_MIN:
	set(value):
		fragments_recovered = maxi(value, FRAGMENTS_MIN)

var current_level: StringName = NO_LEVEL

## Ultimo punto de sincronizacion tocado en cada nivel (id de nivel -> id de
## checkpoint). Solo hay uno activo por nivel: el mas reciente. Lo escribe
## Checkpoint y lo borra el flujo de nivel (LevelRunner) al empezar de cero.
var last_checkpoint: Dictionary[StringName, StringName] = {}
## Niveles completados y niveles desbloqueados (por `unlocks` del JSON del
## nivel). Los apunta LevelRunner al terminar un nivel; van a disco con la
## siguiente copia manual (save_game).
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
## Hay progreso en memoria que no esta en disco (guardado manual).
var _unsaved: bool = false
## Valores base de isak_abilities.json (para el detalle de las mejoras).
var _base_abilities: PlayerAbilities


func _ready() -> void:
	EventBus.state_refresh_requested.connect(emit_state)
	var path: String = resolve_save_path(OS.get_cmdline_args(), OS.get_environment(SAVE_PATH_ENV))
	use_save_path(path, path == SAVE_PATH_TESTS or path == SAVE_PATH_TOOLS)
	if not is_running_tests() and not is_running_script():
		install_quit_guard()
	if OS.is_debug_build():
		apply_debug_meet_args(OS.get_cmdline_user_args())


## Builds de depuracion: cada `--meet-ally=<id>` de `args` da por conocido ese
## asistente (meet_ally; no marca «sin guardar»). Devuelve los que se conocieron.
func apply_debug_meet_args(args: PackedStringArray) -> Array[StringName]:
	var met: Array[StringName] = []
	for arg: String in args:
		if arg.begins_with(DEBUG_MEET_ALLY_ARG):
			var ally := StringName(arg.trim_prefix(DEBUG_MEET_ALLY_ARG))
			if ALLIES.has(ally) and meet_ally(ally):
				met.append(ally)
	return met


func _process(delta: float) -> void:
	play_time_s += delta


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


## Recoge el power bank de mapa `pickup_id` del nivel `level`: suma un power
## bank VACIO (decision 2026-10-14; se carga con el sobrante de los drops) y lo apunta como recogido (persistente). Falso si ya estaba
## recogido. Sin nivel (escenas de prueba) no se apunta nada y siempre cuenta.
func collect_power_bank_pickup(level: StringName, pickup_id: StringName) -> bool:
	if not mark_pickup_collected(level, pickup_id):
		return false
	add_empty_power_bank()
	return true


## Apunta el objeto de un solo uso `pickup_id` del nivel `level` como gastado
## (persistente: power banks de mapa, cargadores de un solo uso). Falso si ya lo
## estaba. Sin nivel (escenas de prueba) no apunta nada y devuelve verdadero.
func mark_pickup_collected(level: StringName, pickup_id: StringName) -> bool:
	if level == NO_LEVEL:
		return true
	if is_pickup_collected(level, pickup_id):
		return false
	if not collected_pickups.has(level):
		collected_pickups[level] = {}
	collected_pickups[level][pickup_id] = true
	request_save()
	return true


func is_pickup_collected(level: StringName, pickup_id: StringName) -> bool:
	return collected_pickups.has(level) and collected_pickups[level].has(pickup_id)


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


## Llena la barra de energia de Debug (hub provisional, decision 2026-10-15).
## No desborda a los power banks.
func refill_debug_energy() -> void:
	debug_energy = get_debug_energy_max()


## Recarga de un cargador (charger, 2026-10-15): suma hasta `amount` a la barra
## sin desbordar a los power banks (el desborde es solo de los drops). Devuelve
## la energia que entro de verdad (0 si la barra estaba llena).
func recharge_debug_energy(amount: float) -> float:
	var before: float = debug_energy
	add_debug_energy(amount, false)
	return debug_energy - before


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


## Coste efectivo de un disparo del laser: laser_energy_cost de
## data/isak_abilities.json con las mejoras compradas (la misma regla que
## Isak.apply_upgrades). Lo usa el HUD para ver la bateria vacia cuando ya no
## alcanza para disparar.
func get_laser_energy_cost() -> float:
	var target := &"isak_abilities.laser_energy_cost"
	return effective_value(target, base_value(target))


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


## Compra `id`: gasta puntos y power banks, la apunta y marca "sin guardar". Si no se puede
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

## Cambia la ruta de guardado. `fresh`: borra lo que hubiera (y su .bak) y
## empieza de cero; si no, carga lo guardado en esa ruta. Sin cambios pendientes.
func use_save_path(path: String, fresh: bool) -> void:
	save_path = path
	if fresh:
		SaveFile.delete(path)
		reset_progress()
	else:
		load_game()


## Verdadero si el juego corre dentro de GUT (no se toca el save real).
static func is_running_tests(args: PackedStringArray = OS.get_cmdline_args()) -> bool:
	for arg: String in args:
		if arg.contains("addons/gut/"):
			return true
	return false


## Verdadero si Godot ejecuta un script como bucle principal (-s / --script):
## GUT, bots y herramientas de capturas. El juego normal nunca lo hace.
static func is_running_script(args: PackedStringArray = OS.get_cmdline_args()) -> bool:
	return args.has("-s") or args.has("--script")


## Ruta de guardado segun los argumentos de Godot y ISAK_SAVE_PATH. Solo el
## arranque normal del juego (sin script) usa SAVE_PATH_DEFAULT.
static func resolve_save_path(args: PackedStringArray, env_path: String) -> String:
	if not env_path.is_empty():
		return env_path
	if is_running_tests(args):
		return SAVE_PATH_TESTS
	if is_running_script(args):
		return SAVE_PATH_TOOLS
	return SAVE_PATH_DEFAULT


## Borra el progreso persistente en memoria (no toca el disco) y la marca de
## cambios sin guardar (no queda nada que merezca guardarse).
func reset_progress() -> void:
	attention_points = ATTENTION_POINTS_MIN
	lap = LAP_EASY
	found_secrets.clear()
	nickname = NICKNAME_DEFAULT
	allies_met.clear()
	learned_help.clear()
	lives_max = LIVES_MAX_DEFAULT
	play_time_s = 0.0
	saved_at = ""
	captured_points.clear()
	collected_pickups.clear()
	purchased_upgrades.clear()
	for ability: StringName in obtained_abilities:
		set_ability_unlocked(ability, false)
	obtained_abilities.clear()
	seen_notices.clear()
	power_banks = 0
	empty_power_banks = 0
	power_bank_charge = 0.0
	completed_levels.clear()
	unlocked_levels.clear()
	_refresh_maxima()
	_set_unsaved(false)
	lives = lives_max


## Apunta que el progreso cambio y no esta en disco (guardado manual,
## 2026-10-15): NO escribe. Lo llaman capturar puntos, recoger objetos, comprar,
## obtener habilidades y completar o desbloquear niveles. Solo save_game() escribe.
func request_save() -> void:
	_set_unsaved(true)


## Crea el aviso al salir con cambios sin guardar (QuitGuard) y desactiva el
## cierre automatico de la ventana. Solo en el juego normal (no en GUT ni con
## scripts -s). Devuelve el QuitGuard (el que ya hubiera, si existe).
func install_quit_guard() -> QuitGuard:
	var existing: QuitGuard = get_quit_guard()
	if existing != null:
		return existing
	var guard := QuitGuard.new()
	guard.name = "QuitGuard"
	guard.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(guard)
	get_tree().set_auto_accept_quit(false)
	return guard


func get_quit_guard() -> QuitGuard:
	return get_node_or_null(^"QuitGuard") as QuitGuard


## Verdadero si hay progreso en memoria sin guardar en disco.
func has_unsaved_changes() -> bool:
	return _unsaved


## Guarda ya en save_path (copia manual): fija saved_at, escribe de forma
## atomica, deja la copia anterior en <ruta>.bak y limpia la marca de cambios
## sin guardar. Verdadero si se escribio (si falla, la marca sigue).
func save_game() -> bool:
	var previous_saved_at: String = saved_at
	saved_at = now_utc()
	if not SaveFile.write(save_path, to_save_data(), true):
		saved_at = previous_saved_at
		return false
	_set_unsaved(false)
	EventBus.game_saved.emit(save_path)
	return true


## Carga save_path. Si falta empieza de cero (falso). Si esta corrupto lo
## aparta como .corrupt y, si hay copia anterior (.bak) valida, carga esa;
## si no, empieza de cero. Una version desconocida se aparta y empieza de cero.
## Tras cargar no hay cambios sin guardar.
func load_game() -> bool:
	var data: Dictionary = SaveFile.read(save_path)
	reset_progress()
	if data.is_empty() and SaveFile.last_status == SaveFile.Status.CORRUPT:
		data = SaveFile.read_backup(save_path)
		if not data.is_empty():
			push_warning("GameState: se carga la copia anterior '%s%s'." % [save_path, SaveFile.BACKUP_SUFFIX])
			if apply_save_data(data):
				_set_unsaved(false)
				return true
			reset_progress()
		return false
	if data.is_empty():
		return false
	if not apply_save_data(data):
		push_warning("GameState: guardado '%s' con version no soportada; se aparta y se empieza de cero." % save_path)
		SaveFile.quarantine(save_path)
		reset_progress()
		return false
	_set_unsaved(false)
	return true


## Fecha y hora actuales en UTC ("AAAA-MM-DDTHH:MM:SSZ").
static func now_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


## Progreso persistente como diccionario JSON (esquema SAVE_VERSION).
func to_save_data() -> Dictionary:
	var captured: Dictionary = {}
	for level: StringName in captured_points:
		var ids: Array[String] = []
		for id: StringName in get_captured_points(level):
			ids.append(String(id))
		captured[String(level)] = ids
	var pickups: Dictionary = {}
	for level: StringName in collected_pickups:
		pickups[String(level)] = _keys_sorted(collected_pickups[level])
	var secrets: Dictionary = {}
	for level: StringName in found_secrets:
		secrets[String(level)] = _keys_sorted(found_secrets[level])
	return {
		"version": SAVE_VERSION,
		"attention_points": attention_points,
		"captured_points": captured,
		"collected_pickups": pickups,
		"upgrades_purchased": _keys_sorted(purchased_upgrades),
		"abilities_obtained": _keys_sorted(obtained_abilities),
		"seen_notices": _keys_sorted(seen_notices),
		"power_banks": {"full": power_banks, "empty": empty_power_banks, "charge": power_bank_charge},
		"completed_levels": _keys_sorted(completed_levels),
		"unlocked_levels": _keys_sorted(unlocked_levels),
		"lap": lap,
		"found_secrets": secrets,
		"nickname": nickname,
		"allies_met": _keys_sorted(allies_met),
		"learned_help": _keys_sorted(learned_help),
		"lives_max": lives_max,
		"saved_at": saved_at,
		"play_time_s": play_time_s,
	}


## Aplica un guardado (tolerante a campos que falten o con tipo raro). Falso si
## la version no se reconoce (no aplica nada). Migracion v1 -> v2: lap 1, sin
## secretos, sin fecha ni tiempo. Migracion v1/v2 -> v3 (propuesta §6): apodo
## "Isak", lives_max 3 y, si el 1-1 estaba completado o hub_tutorial_done era
## verdadero, Eco y Notas conocidos; con el 1-1 completado, ademas, las ayudas
## de los tipos de ese nivel aprendidas (un veterano no repite las Q).
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
	var pickups: Variant = data.get("collected_pickups", {})
	if pickups is Dictionary:
		for level: Variant in pickups:
			var picked: Dictionary = {}
			for id: StringName in _string_names(pickups[level]):
				picked[id] = true
			if not picked.is_empty():
				collected_pickups[StringName(String(level))] = picked
	for id: StringName in _string_names(data.get("upgrades_purchased", [])):
		if UpgradeCatalog.shared().has(id):
			purchased_upgrades[id] = true
	for id: StringName in _string_names(data.get("abilities_obtained", [])):
		if abilities_unlocked.has(id):
			obtained_abilities[id] = true
			set_ability_unlocked(id, true)
	for id: StringName in _string_names(data.get("seen_notices", [])):
		seen_notices[id] = true
	# Guardados de antes de los avisos de control (sin "seen_notices"): el
	# ability_pickup ya mostraba el aviso al obtener la habilidad.
	for id: StringName in obtained_abilities:
		seen_notices[id] = true
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
	var raw_lap: Variant = data.get("lap", LAP_EASY)
	lap = int(raw_lap) if (raw_lap is float or raw_lap is int) else LAP_EASY
	var secrets: Variant = data.get("found_secrets", {})
	if secrets is Dictionary:
		for level: Variant in secrets:
			var found: Dictionary = {}
			for id: StringName in _string_names(secrets[level]):
				found[id] = true
			if not found.is_empty():
				found_secrets[StringName(String(level))] = found
	if int(version) < 3:
		_migrate_to_v3(data)
	else:
		var raw_nickname: Variant = data.get("nickname", NICKNAME_DEFAULT)
		nickname = raw_nickname if raw_nickname is String and not (raw_nickname as String).strip_edges().is_empty() \
				else NICKNAME_DEFAULT
		for id: StringName in _string_names(data.get("allies_met", [])):
			if ALLIES.has(id):
				allies_met[id] = true
		for id: StringName in _string_names(data.get("learned_help", [])):
			learned_help[id] = true
		var raw_lives: Variant = data.get("lives_max", LIVES_MAX_DEFAULT)
		lives_max = maxi(LIVES_MAX_DEFAULT, int(raw_lives)) if (raw_lives is float or raw_lives is int) \
				else LIVES_MAX_DEFAULT
	# El pulso es el regalo de Eco (encuentro del 1-1, 2026-10-16): con Eco
	# conocido se tiene siempre. Cubre los guardados migrados con el 1-1
	# completado y los v3 de antes del encuentro (el 1-1 daba el pulso al
	# empezar): el encuentro no se repite y su aviso ya se vio.
	if allies_met.has(ALLY_ECO) and not obtained_abilities.has(ABILITY_PULSE):
		obtained_abilities[ABILITY_PULSE] = true
		set_ability_unlocked(ABILITY_PULSE, true)
		seen_notices[ABILITY_PULSE] = true
	# Calc apagada hasta conocerla (2026-10-16, propuesta §2.3): un guardado con
	# mejoras ya compradas (de cuando Calc dormida vendia desde el 1-1) la da por
	# conocida, para no dejar a nadie sin la tienda que ya uso.
	if not purchased_upgrades.is_empty():
		allies_met[ALLY_CALC] = true
	var raw_saved_at: Variant = data.get("saved_at", "")
	saved_at = raw_saved_at if raw_saved_at is String else ""
	play_time_s = _as_float(data.get("play_time_s", 0.0))
	_refresh_maxima()
	lives = lives_max
	return true


## Campos v3 de un guardado v1/v2 (ver apply_save_data).
func _migrate_to_v3(data: Dictionary) -> void:
	var veteran: bool = completed_levels.has(HUB_TUTORIAL_LEVEL)
	var tutorial: Variant = data.get("hub_tutorial_done", false)
	if veteran or (tutorial is bool and tutorial):
		allies_met[ALLY_ECO] = true
		allies_met[ALLY_NOTAS] = true
	if veteran:
		# Antes de v3 la tienda (Calc dormida) abria al terminar el 1-1: un
		# veterano conserva Calc conocida. Las partidas nuevas empiezan sin ella.
		allies_met[ALLY_CALC] = true
		for id: StringName in HelpCatalog.shared().types_of_level(HUB_TUTORIAL_LEVEL):
			learned_help[id] = true


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
	EventBus.unsaved_changes_changed.emit(_unsaved)
	_emit_lives()


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


## Apunta el secreto `secret_id` de `level` como encontrado (registro para
## Linterna y Notas). Falso si ya lo estaba o no hay nivel. Marca "sin guardar".
func mark_secret_found(level: StringName, secret_id: StringName) -> bool:
	if level == NO_LEVEL or is_secret_found(level, secret_id):
		return false
	if not found_secrets.has(level):
		found_secrets[level] = {}
	found_secrets[level][secret_id] = true
	request_save()
	return true


func is_secret_found(level: StringName, secret_id: StringName) -> bool:
	return found_secrets.has(level) and found_secrets[level].has(secret_id)


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


## Obtiene para siempre la habilidad `ability` (ability_pickup): la desbloquea,
## la apunta como obtenida (se guarda) y lo avisa con EventBus.ability_obtained.
## Falso si no existe o ya estaba obtenida.
func obtain_ability(ability: StringName) -> bool:
	if not abilities_unlocked.has(ability):
		push_error("GameState: unknown ability '%s'" % ability)
		return false
	if obtained_abilities.has(ability):
		return false
	obtained_abilities[ability] = true
	set_ability_unlocked(ability, true)
	EventBus.ability_obtained.emit(ability)
	request_save()
	return true


func is_ability_obtained(ability: StringName) -> bool:
	return obtained_abilities.has(ability)


## Verdadero si el jugador ya conoce al asistente `ally` (ALLIES).
func has_met_ally(ally: StringName) -> bool:
	return allies_met.has(ally)


## Apunta al asistente `ally` como conocido. Falso si ya lo era o no existe. No
## marca "sin guardar" (registro, como seen_notices).
func meet_ally(ally: StringName) -> bool:
	if not ALLIES.has(ally):
		push_error("GameState: unknown ally '%s'" % ally)
		return false
	if allies_met.has(ally):
		return false
	allies_met[ally] = true
	EventBus.ally_met.emit(ally)
	return true


## Apodo con el que Eco llama al jugador (NICKNAME_DEFAULT si no hay otro).
func get_nickname() -> String:
	return nickname if not nickname.strip_edges().is_empty() else NICKNAME_DEFAULT


## Cambia el apodo (limpio con sanitize_nickname). Si cambia, marca «sin
## guardar» (es progreso: va a disco con la siguiente copia) y emite
## EventBus.nickname_changed. Un apodo vacio tras limpiarlo no cambia nada.
## Verdadero si cambio.
func set_nickname(value: String) -> bool:
	var clean: String = sanitize_nickname(value)
	if clean.is_empty() or clean == nickname:
		return false
	nickname = clean
	request_save()
	EventBus.nickname_changed.emit(nickname)
	return true


## Apodo limpio: sin caracteres de control ni simbolos (solo letras, numeros y
## espacios), espacios repetidos reducidos a uno, recortado por los extremos y
## como mucho NICKNAME_MAX_LENGTH caracteres. Puede quedar vacio.
static func sanitize_nickname(value: String) -> String:
	var out: String = ""
	var last_space: bool = true
	for i: int in value.length():
		var ch: String = value[i]
		if ch == " " or ch == "\t":
			if not last_space:
				out += " "
			last_space = true
		elif is_nickname_char(ch):
			out += ch
			last_space = false
	out = out.strip_edges()
	if out.length() > NICKNAME_MAX_LENGTH:
		out = out.substr(0, NICKNAME_MAX_LENGTH).strip_edges()
	return out


## Caracter valido en un apodo: letra o numero (Unicode; la entrada del apodo
## ademas exige que la fuente de textos lo tenga). El espacio se trata aparte.
static func is_nickname_char(ch: String) -> bool:
	if ch.length() != 1:
		return false
	var code: int = ch.unicode_at(0)
	if code < 32 or (code >= 127 and code < 160):
		return false
	return ch.to_upper() != ch.to_lower() or (ch >= "0" and ch <= "9")


## Sustituye NICKNAME_TAG por el apodo (`nick`, o el actual si va vacio).
func apply_nickname(text: String, nick: String = "") -> String:
	return text.replace(NICKNAME_TAG, nick if not nick.is_empty() else get_nickname())


## Verdadero si la ayuda con Q del tipo `help_id` ya se aprendio.
func is_help_learned(help_id: StringName) -> bool:
	return learned_help.has(help_id)


## Apunta la ayuda del tipo `help_id` como aprendida (ninguna instancia de ese
## tipo vuelve a mostrar la Q). Falso si ya lo estaba. No marca "sin guardar"
## (propuesta §3.2): se guarda con la siguiente copia.
func learn_help(help_id: StringName) -> bool:
	if help_id == &"" or learned_help.has(help_id):
		return false
	learned_help[help_id] = true
	EventBus.help_learned.emit(help_id)
	return true


## «Olvidar ayudas» del album de Notas (propuesta §3.5): vacia learned_help
## (vuelven las Q y las siluetas) y marca «sin guardar». Falso si no habia
## ninguna.
func forget_help() -> bool:
	if learned_help.is_empty():
		return false
	learned_help.clear()
	request_save()
	EventBus.help_forgotten.emit()
	return true


func is_notice_seen(id: StringName) -> bool:
	return seen_notices.has(id)


## Apunta el aviso de control `id` como visto. Falso si ya lo era. No marca
## "sin guardar": va a disco con la siguiente copia manual, asi abrir el juego
## unos segundos no pide confirmacion al salir. Si se sale sin guardar, el aviso
## vuelve a salir.
func mark_notice_seen(id: StringName) -> bool:
	if seen_notices.has(id):
		return false
	seen_notices[id] = true
	return true


# --- Vidas (intentos; docs/propuesta-asistentes-y-vidas.md §5.1) ---

## Las vidas cuentan desde la primera llegada al hub (pregunta 1 de la
## propuesta, aprobada): con Notas conocida (su presentacion es lo primero del
## primer hub). Antes, en el primer recorrido del 1-1, las muertes son ilimitadas.
func are_lives_active() -> bool:
	return has_met_ally(ALLY_NOTAS)


## Repone las vidas a lives_max. Lo llama LevelRunner al empezar cada intento
## de nivel (desde el hub, al arrancar o con la tecla R); los puntos de
## sincronizacion NO las reponen.
func refill_lives() -> void:
	lives = lives_max
	_emit_lives()


## Resta una vida al morir (Sync Rate 0). Sin vidas activas no cambia nada.
## Verdadero si era la ultima: game over (apply_rollback).
func lose_life() -> bool:
	if not are_lives_active():
		return false
	lives = maxi(lives - 1, 0)
	EventBus.life_lost.emit(lives)
	_emit_lives()
	return lives == 0


## Hueco para la vida extra (paso 14 de §10, secreto D del 1-1; SIN
## implementar el objeto): sube el maximo para siempre y suma una vida al
## intento en curso. Marca «sin guardar».
func add_max_life() -> void:
	lives_max += 1
	lives += 1
	request_save()
	_emit_lives()


func _emit_lives() -> void:
	EventBus.lives_changed.emit(lives, lives_max, are_lives_active())


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


func _set_unsaved(value: bool) -> void:
	if _unsaved == value:
		return
	_unsaved = value
	EventBus.unsaved_changes_changed.emit(value)


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
