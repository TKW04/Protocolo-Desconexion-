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
#   puntos de atención ya capturados por nivel, niveles de las mejoras de Calc
#   por pistas (data/upgrades.json, upgrade_levels), power banks (coleccionable
#   puro desde el 2026-10-25: llegan completos, data/power_bank.json), habilidades obtenidas con un ability_pickup (p. ej.
#   el laser, 2026-10-15) y niveles completados/desbloqueados. Se guarda en
#   save_path (user://save.json; en las pruebas otra ruta) con SaveFile.
# - Guardado MANUAL (decision 2026-10-15, docs/propuesta-hub-y-guardado.md):
#   los cambios de progreso solo marcan "sin guardar" (request_save,
#   has_unsaved_changes, EventBus.unsaved_changes_changed); solo save_game()
#   escribe (en el hub; la copia anterior queda en <ruta>.bak). Esquema v2:
#   vuelta (lap), secretos encontrados, tutorial del hub, fecha y tiempo de juego.
# - Vidas (intentos; 2026-10-16): lives (no se guarda) hasta lives_max; ver
#   are_lives_active, refill_lives y lose_life. Game over y papelera:
#   apply_rollback (regla unica, tambien para el futuro rollback del jefe
#   final), discard_to_trash, recover_trash y has_trash_pending
#   (docs/propuesta-asistentes-y-vidas.md §5).
# Cada setter acota el valor y emite la señal correspondiente por EventBus.
# Reglas de juego que viven aquí: recarga de energía por punto de atención
# (A10), compra de mejoras (el nivel 5 gasta un power bank) y valores
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
## Energia que repone cada punto de atencion recogido (A10, aprobado). La
## mejora "Recarga mejorada" que lo cambiaba se retiro con las pistas (tanda M1,
## 2026-10-17); get_energy_per_attention_point sigue leyendo su valor efectivo.
const ENERGY_PER_ATTENTION_POINT: float = 10.0

## Guardado (SaveFile). Version del esquema de save.json (v2 desde 2026-10-15:
## lap, found_secrets, saved_at, play_time_s; v3 desde 2026-10-15 (3), paso 2 de
## docs/propuesta-asistentes-y-vidas.md §10: nickname, allies_met, learned_help
## y lives_max, que sustituyen a hub_tutorial_done; v4 desde 2026-10-17, tanda M1
## de docs/propuesta-mejoras.md: upgrade_levels por pista, que sustituye a
## upgrades_purchased, con devoluciones; v5 desde 2026-10-19, paso 2 de
## docs/propuesta-recuerdos.md §7: memories (ids de los recuerdos obtenidos y
## guardados) y memories_read; la migracion los crea vacios; v6 desde 2026-10-27,
## paso 0 de docs/propuesta-hub-mundos-4-6.md: hub_upgrades, upgrades instalados en
## el hub, que la migracion crea vacio). Se cargan las versiones 1 a
## SAVE_VERSION (las anteriores se migran); otra se aparta como .corrupt.
const SAVE_VERSION: int = 6
## Upgrades del hub (v6; docs/propuesta-hub-mundos-4-6.md §2.6 y §3.4): ids que
## se pueden instalar. «Actualización del sistema» (acertijo tras La Curadora)
## hace visibles las carpetas de los Mundos 4-6 (requires_upgrade de data/hub.json).
const HUB_UPGRADE_UPDATE_4_6: StringName = &"hub_update_4_6"
const HUB_UPGRADES: Array[StringName] = [HUB_UPGRADE_UPDATE_4_6]
## Vueltas (docs/preguntas.md, tres vueltas): 1 Easy, 2 Normal, 3 Hard (nombres
## internos; de cara al jugador son niveles de acceso Caché, Kernel y Raíz, ver
## HubWorlds.access_name: la UI nunca dice vuelta ni Easy/Normal/Hard).
const LAP_EASY: int = 1
const LAP_NORMAL: int = 2
const LAP_HARD: int = 3
## Mundo del jefe final (Isak Optimizado, La Nube): su capa Raíz la entrega la
## propia pelea justo antes del momento de decision (real_ending_missing).
const REAL_ENDING_FINAL_WORLD: int = 6
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
## Motivos de rollback (apply_rollback; docs/propuesta-asistentes-y-vidas.md
## §5.3: una sola regla para el game over y el rollback del jefe final). Hoy
## solo existe el game over; el del jefe final (paso 16) anadira el suyo.
const ROLLBACK_GAME_OVER: StringName = &"game_over"
## Claves del contenido de la papelera (get_trash) y del informe de apply_rollback.
const TRASH_POINTS: String = "attention_points"
const TRASH_POWER_BANKS: String = "power_banks"
const TRASH_UPGRADES: String = "upgrades"
const TRASH_ABILITIES: String = "abilities"
## Argumento de usuario de las builds de depuracion que da por conocido un
## asistente al arrancar (p. ej. `-- --meet-ally=calc`): abre la tienda de Calc
## sin pasar por su encuentro.
const DEBUG_MEET_ALLY_ARG: String = "--meet-ally="
## Argumento de usuario de las builds de depuracion que hace como si el
## asistente acabara de teletransportarse al hub (p. ej. `-- --start-level=hub
## --ally-teleported=calc`): sin conocerlo, la siguiente llegada al hub
## reproduce su encuentro (CalcIntro). Igual que EventBus.ally_teleported.
const DEBUG_ALLY_TELEPORTED_ARG: String = "--ally-teleported="
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
	&"game_state.pulse_stun_multiplier": 1.0,
	# Tanda M2 (2026-10-17): Sync 5 (Resincronizacion, Sync Rate por segundo fuera
	# de combate) y Energia 5 (recarga pasiva, % del maximo por segundo). Sin esas
	# mejoras no hay regeneracion pasiva (docs/preguntas.md, notas del paso 9).
	&"game_state.sync_regen_per_s": 0.0,
	&"game_state.energy_regen_pct_s": 0.0,
}
## Tipo de objeto del power bank de mapa en data/levels/<id>.json.
const POWER_BANK_PICKUP_TYPE: String = "power_bank_pickup"
## Patron del JSON de un nivel (contador de power banks por nivel).
const LEVEL_DATA_PATTERN: String = "res://data/levels/%s.json"

## Resultado de comprar el siguiente nivel de una pista (check_purchase /
## purchase_upgrade): pista desconocida, ya en el nivel maximo, habilidad sin
## obtener (chip «?»), por encima del tope del acceso actual, efecto aun no
## disponible («Proximamente», tanda M2), faltan puntos o falta power bank.
enum PurchaseResult {
	OK,
	UNKNOWN,
	MAX_LEVEL,
	NOT_ENOUGH_POINTS,
	NOT_ENOUGH_POWER_BANKS,
	ACCESS_LOCKED,
	NOT_IMPLEMENTED,
	ABILITY_MISSING,
}

const ABILITY_PULSE: StringName = &"pulse"
const ABILITY_DEBUG: StringName = &"debug"
const ABILITY_DASH: StringName = &"dash"
const ABILITY_GROUND_POUND: StringName = &"ground_pound"
const ABILITY_COMPRESS: StringName = &"compress"
const ABILITY_SHOCKWAVE: StringName = &"shockwave"
## Combinacion (2026-10-29, docs/propuesta-mundo-5.md §3.2): la da la «Prueba gratis» del 5-2.
const ABILITY_COMBO: StringName = &"combo"
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
	ABILITY_COMBO,
	ABILITY_LASER,
]

## Sync Rate actual; tope get_sync_rate_max() (100; hasta 130 con la pista Sync Rate).
var sync_rate: float = SYNC_RATE_MAX:
	set(value):
		var max_value: float = get_sync_rate_max()
		sync_rate = clampf(value, SYNC_RATE_MIN, max_value)
		EventBus.sync_rate_changed.emit(sync_rate, max_value)
		_update_low_sync()

## Energia de Debug; tope get_debug_energy_max() (100; hasta 130 con la pista Energia).
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

## Power banks que Isak tiene (sin gastar). Coleccionable puro (decision del
## usuario 2026-10-25, docs/propuesta-mejoras.md §5.1): el de mapa llega YA
## COMPLETO, sin tope ni carga; solo se gasta al comprar un nivel 5 en Calc
## (cost.power_banks de data/upgrades.json). Calc no los vende.
var power_banks: int = 0:
	set(value):
		power_banks = maxi(value, 0)
		_emit_power_banks()

## Ids de puntos de atencion ya capturados por nivel (id de nivel -> {id: true}).
## No reaparecen ni cuentan al rejugar el nivel.
var captured_points: Dictionary[StringName, Dictionary] = {}
## Ids de objetos de un solo uso (power banks de mapa, cargadores de un solo uso) ya recogidos por nivel (id de
## nivel -> {id: true}). Como los puntos: no reaparecen al rejugar el nivel.
var collected_pickups: Dictionary[StringName, Dictionary] = {}
## Nivel de cada pista de mejoras de Calc (id de pista de data/upgrades.json ->
## nivel 2-5; las que no estan siguen en el nivel 1, la base). Tanda M1.
var upgrade_levels: Dictionary[StringName, int] = {}
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
## Recuerdos obtenidos (ids de data/memories.json; docs/propuesta-recuerdos.md
## §4): recuerdos de jefe y mensajes de secretos. Obtener uno marca «sin
## guardar» (obtain_memory); guardado es registro: el rollback lo conserva y no
## va a la Papelera (como found_secrets); lo no guardado se pierde con el game over.
var memories: Dictionary[StringName, bool] = {}
## Recuerdos obtenidos ya leidos en Notas (los demas son «nuevos»: marca en el
## icono de Notas del hub). Leer no marca «sin guardar» (como learned_help).
var memories_read: Dictionary[StringName, bool] = {}
## Upgrades del hub instalados (id de HUB_UPGRADES -> true; v6,
## docs/propuesta-hub-mundos-4-6.md §2.6, decisiones del usuario del 2026-10-27).
## Instalar solo marca «sin guardar» (install_hub_upgrade): un game over sin
## guardar vuelve a la copia y lo pierde, como cualquier progreso sin guardar (no
## es excepcion). No va a la Papelera (es estado del hub, no un objeto). El
## rollback de fin de vuelta (Caché -> Kernel -> Raíz, paso 16 de asistentes, aun
## sin implementar) lo CONSERVA: el acertijo no se repite.
var hub_upgrades: Dictionary[StringName, bool] = {}
## Apodo con el que Eco llama al jugador (v3; por defecto NICKNAME_DEFAULT).
var nickname: String = NICKNAME_DEFAULT
## Asistentes ya conocidos (id de ALLIES -> true; v3). Sustituye a eco_met y a
## hub_tutorial_done (= "notas"). Registro: no marca "sin guardar" por si solo.
var allies_met: Dictionary[StringName, bool] = {}
## Asistentes que se han teletransportado al hub en esta SESION y aun no se han
## encontrado alli (id -> true; 2026-10-17, tanda H3 del paso 14 del 1-2): lo
## apunta EventBus.ally_teleported (Calc al irse de la azotea del 1-2) y lo
## consume la llegada al hub (HubRoom: encuentro con Calc, CalcIntro). NO se
## guarda (no va en save.json): si se cierra el juego antes de llegar al hub, el
## asistente sigue sin conocerse y el 1-2 repite su acertijo. Lo vacian
## reset_progress y apply_rollback (un game over pierde el intento).
var ally_arrivals: Dictionary[StringName, bool] = {}
## Tipos de ayuda con Q ya aprendidos (id de data/help.json -> true; v3). No
## marca "sin guardar": va a disco con la siguiente copia (como seen_notices).
var learned_help: Dictionary[StringName, bool] = {}
## Vidas (intentos) maximas (v3). Las vidas actuales no se guardan.
var lives_max: int = LIVES_MAX_DEFAULT
## Vidas (intentos) del intento en curso (no se guardan): refill_lives las
## repone a lives_max al empezar cada intento de nivel; lose_life resta una.
## Solo cuentan con are_lives_active() (desde la primera llegada al hub).
var lives: int = LIVES_MAX_DEFAULT
## Papelera (propuesta §2.5 y §5.2): lo que Eco desecho en el ultimo rollback y
## aun no se ha recuperado (claves TRASH_*). Vive en memoria: el disco conserva
## la copia, asi que cerrar el juego con la papelera llena no pierde nada.
var _trash: Dictionary = {}
## Al recuperar la papelera quedan cambios sin guardar (el apodo, que nunca se
## pierde, era distinto del de la copia).
var _unsaved_after_trash: bool = false
## Segundos de juego (con el arbol sin pausar: no cuentan el menu de pausa, las
## lineas importantes ni las ayudas). Se guarda con la copia.
var play_time_s: float = 0.0
## Fecha (UTC, "AAAA-MM-DDTHH:MM:SSZ") de la ultima copia guardada o cargada;
## vacia si no hay ninguna.
var saved_at: String = ""

## Ruta del guardado. Por defecto user://save.json; con la variable de entorno
## ISAK_SAVE_PATH, esa ruta; dentro de GUT, SAVE_PATH_TESTS, y con otro script
## (-s), SAVE_PATH_TOOLS (estas dos se borran al arrancar). Ver
## resolve_save_path(). Cambiala con use_save_path().
var save_path: String = SAVE_PATH_DEFAULT
## Al arrancar (use_save_path sin `fresh`) se cargo una partida guardada valida
## (save_path, o su .bak si el principal estaba corrupto). Con ella el juego
## (LevelRunner, scenes/main.tscn) arranca en el hub; sin ella, partida nueva en
## el 1-1 (2026-10-16). reset_progress lo apaga (borrar el guardado con F9, un
## rollback o las rutas de pruebas y herramientas, que empiezan de cero).
var started_from_save: bool = false

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
## de Sync Rate bajo. Es un ajuste del jugador: lo carga y guarda GameSettings
## (settings.cfg, «Efectos de Sync bajo» del menu de pausa; 2026-10-16).
var reduce_low_sync_effects: bool = false:
	set(value):
		reduce_low_sync_effects = value
		EventBus.reduce_low_sync_effects_changed.emit(value)

## Ajuste de accesibilidad (docs 15.6, "contorno claro para daltonismo"): las
## plataformas ocultas del Debug usan un contorno mas claro y grueso
## (data/debug_mode.json, high_contrast_*). Es un ajuste del jugador: lo carga
## y guarda GameSettings («Contorno del Debug» del menu de pausa; 2026-10-16).
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
## Ocultarte (Pulso 4, tanda M2) activo: lo pone HideMode (Isak) y lo leen los
## enemigos que «ven» (NotificationBadge) y la regeneracion pasiva. No se guarda.
var _player_hidden: bool = false
## Pulso de retorno (Pulso 5): enemigos (ruta del nodo) que ya dieron su energia
## en este intento de nivel (begin_attempt lo vacia). No se guarda.
var _pulse_return_claimed: Dictionary[String, bool] = {}

## Likes del Mundo 3 (2026-10-26, paso 2 de docs/propuesta-mundo-3.md §3.1 y §2.3):
## contador de 0 a get_likes_max() (30) POR INTENTO. NO va en save.json (los likes no se
## guardan: es el tema del mundo). Empieza en 0 con cada intento (begin_attempt),
## se apunta al activar un punto de sincronizacion y vuelve a ese valor al
## reaparecer tras morir (o a 0 sin punto). likes_checkpoint_serial cuenta los
## puntos activados en el intento: un corazon recogido despues del ultimo vuelve
## al reaparecer (HeartPickup). Tope y demas valores en la seccion likes de
## data/world3_objects.json (get_likes_max; LIKES_MAX_DEFAULT si falta).
const LIKES_MAX_DEFAULT: int = 30
var likes: int = 0
var _likes_at_checkpoint: int = 0
var likes_checkpoint_serial: int = 0


func _ready() -> void:
	EventBus.state_refresh_requested.connect(emit_state)
	EventBus.player_respawned.connect(_on_player_respawned_likes)
	var path: String = resolve_save_path(OS.get_cmdline_args(), OS.get_environment(SAVE_PATH_ENV))
	use_save_path(path, path == SAVE_PATH_TESTS or path == SAVE_PATH_TOOLS)
	# Ajustes (settings.cfg, aparte del guardado): las rutas de pruebas y
	# herramientas empiezan de cero, como sus guardados.
	var settings: String = GameSettings.resolve_path(OS.get_cmdline_args(), OS.get_environment(GameSettings.PATH_ENV))
	GameSettings.use_path(settings, settings == GameSettings.PATH_TESTS or settings == GameSettings.PATH_TOOLS)
	if not is_running_tests() and not is_running_script():
		install_quit_guard()
	EventBus.ally_teleported.connect(_on_ally_teleported)
	if OS.is_debug_build():
		apply_debug_meet_args(OS.get_cmdline_user_args())
		apply_debug_teleport_args(OS.get_cmdline_user_args())


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


## Builds de depuracion: cada `--ally-teleported=<id>` de `args` apunta ese
## asistente como recien teletransportado al hub (como EventBus.ally_teleported).
## Devuelve los que se apuntaron.
func apply_debug_teleport_args(args: PackedStringArray) -> Array[StringName]:
	var out: Array[StringName] = []
	for arg: String in args:
		if arg.begins_with(DEBUG_ALLY_TELEPORTED_ARG):
			var ally := StringName(arg.trim_prefix(DEBUG_ALLY_TELEPORTED_ARG))
			if note_ally_teleported(ally):
				out.append(ally)
	return out


## Apunta que `ally` se teletransporto al hub (sesion). Falso si no existe o ya
## es conocido (no hay encuentro que esperar).
func note_ally_teleported(ally: StringName) -> bool:
	if not ALLIES.has(ally) or allies_met.has(ally):
		return false
	ally_arrivals[ally] = true
	return true


## `ally` espera en el hub a que Isak lo encuentre (teletransportado en esta
## sesion y aun no conocido).
func is_ally_arrival_pending(ally: StringName) -> bool:
	return ally_arrivals.has(ally) and not allies_met.has(ally)


## Quita la llegada pendiente de `ally` (el hub ya hizo el encuentro).
func clear_ally_arrival(ally: StringName) -> void:
	ally_arrivals.erase(ally)


func _on_ally_teleported(ally: StringName) -> void:
	note_ally_teleported(ally)


func _process(delta: float) -> void:
	play_time_s += delta


## Sync Rate bajo: por debajo del umbral (estrictamente menor, docs: "menor al 20%").
func is_sync_low() -> bool:
	return _is_sync_low


## Resta Sync Rate (dano de prueba de la arena; el dano real llega en el paso 9).
func apply_sync_damage(amount: float) -> void:
	sync_rate -= maxf(amount, 0.0)


## Suma puntos de atencion; cada uno repone energia de Debug (A10; la mejora
## "Recarga mejorada" sube cuanto). Lo que no cabe en la barra se pierde.
func add_attention_points(amount: int) -> void:
	if amount <= 0:
		return
	attention_points += amount
	add_debug_energy(amount * get_energy_per_attention_point())


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
## bank COMPLETO (coleccionable puro, decision 2026-10-25; sin tope ni carga) y
## lo apunta como recogido (persistente; un rollback lo devuelve como el resto
## de lo no guardado). Falso si ya estaba recogido. Sin nivel (escenas de
## prueba) no se apunta nada y siempre cuenta.
func collect_power_bank_pickup(level: StringName, pickup_id: StringName) -> bool:
	if not mark_pickup_collected(level, pickup_id):
		return false
	power_banks += 1
	request_save()
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


## Recarga de energia de Debug (drops de enemigos y jefes, puntos de atencion,
## cargadores). Lo que no cabe en la barra se pierde (desde el 2026-10-25 los
## power banks no se cargan: son coleccionables completos).
## Devuelve el sobrante que no entro en la barra.
func add_debug_energy(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var room: float = maxf(get_debug_energy_max() - debug_energy, 0.0)
	var to_bar: float = minf(amount, room)
	if to_bar > 0.0:
		debug_energy += to_bar
	return amount - to_bar


## Llena la barra de energia de Debug (hub provisional, decision 2026-10-15).
func refill_debug_energy() -> void:
	debug_energy = get_debug_energy_max()


## Recarga de un cargador (charger, 2026-10-15): suma hasta `amount` a la barra
## (el sobrante se pierde). Devuelve la energia que entro de verdad (0 si la
## barra estaba llena).
func recharge_debug_energy(amount: float) -> float:
	var before: float = debug_energy
	add_debug_energy(amount)
	return debug_energy - before


## Recarga de Sync Rate (drops de enemigos y jefes), acotada al maximo efectivo.
func heal_sync(amount: float) -> void:
	if amount <= 0.0:
		return
	sync_rate += amount


## Power banks gastados en Calc: suma de cost.power_banks de los niveles
## comprados de cada pista (data/upgrades.json; hoy, los niveles 5).
func get_power_banks_spent() -> int:
	var catalog: UpgradeCatalog = UpgradeCatalog.shared()
	var spent: int = 0
	for track: StringName in upgrade_levels:
		for level: int in range(UpgradeCatalog.LEVEL_MIN + 1, get_upgrade_level(track) + 1):
			var entry: UpgradeCatalog.Level = catalog.get_level(track, level)
			if entry != null:
				spent += maxi(entry.cost_power_banks, 0)
	return spent


## Power banks encontrados en la partida: los que se tienen mas los gastados
## (hub y Calc muestran encontrados y gastados; decision 2026-10-25).
func get_power_banks_found() -> int:
	return power_banks + get_power_banks_spent()


## Ids de los power banks de mapa del nivel `level` (objetos power_bank_pickup
## de data/levels/<id>.json; params.id). Vacio si no hay datos.
static func level_power_bank_ids(level: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if level == NO_LEVEL:
		return out
	var path: String = LEVEL_DATA_PATTERN % String(level)
	if not FileAccess.file_exists(path):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return out
	for obj: Variant in (data as Dictionary).get("objects", []):
		if obj is Dictionary and String((obj as Dictionary).get("type", "")) == POWER_BANK_PICKUP_TYPE:
			var params: Variant = (obj as Dictionary).get("params", {})
			var id: String = String((params as Dictionary).get("id", "")) if params is Dictionary else ""
			if not id.is_empty():
				out.append(StringName(id))
	return out


## Power banks del nivel `level`: x = recogidos, y = total del mapa (como los
## puntos de atencion: «Power bank 0/1» en el HUD del nivel y en la carpeta).
func get_level_power_bank_progress(level: StringName) -> Vector2i:
	var ids: Array[StringName] = level_power_bank_ids(level)
	var found: int = 0
	for id: StringName in ids:
		if is_pickup_collected(level, id):
			found += 1
	return Vector2i(found, ids.size())


## Ajustes del contador del HUD (seccion "hud" de data/power_bank.json).
func get_power_bank_hud_data() -> Dictionary:
	return _power_bank_data.get("hud", {})


# --- Mejoras de Calc por pistas (data/upgrades.json, tanda M1) ---

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


## Sync 5 (Resincronizacion): Sync Rate por segundo fuera de combate (0 sin la
## mejora; PassiveRegen, data/passive_regen.json).
func get_sync_regen_per_s() -> float:
	return effective_value(&"game_state.sync_regen_per_s", 0.0)


## Energia 5 (recarga pasiva): % del maximo por segundo (0 sin la mejora).
func get_energy_regen_pct_s() -> float:
	return effective_value(&"game_state.energy_regen_pct_s", 0.0)


## Ocultarte (Pulso 4) comprado y el pulso obtenido: la accion hide funciona en
## los niveles (HideMode).
func is_hide_available() -> bool:
	return effective_value(&"ability.hide", 0.0) > 0.5 and is_ability_unlocked(ABILITY_PULSE)


## Ocultarte activo (Pulso 4; lo pone HideMode). Los enemigos que «ven» pierden
## el rastro; la Burbuja y las patrullas no miran.
func is_player_hidden() -> bool:
	return _player_hidden


## Solo HideMode (y las pruebas): cambia el estado y avisa con EventBus.hide_changed.
func set_player_hidden(hidden: bool) -> void:
	if _player_hidden == hidden:
		return
	_player_hidden = hidden
	EventBus.hide_changed.emit(hidden)


## Empieza un intento de nivel (LevelRunner.start_level: carpeta, arranque, R):
## el Pulso de retorno vuelve a dar energia una vez por enemigo.
func begin_attempt() -> void:
	_pulse_return_claimed.clear()
	set_player_hidden(false)
	reset_likes()


# --- Likes (Mundo 3; no se guardan) ---

## Tope del contador (max de la seccion likes de data/world3_objects.json: 30).
func get_likes_max() -> int:
	return int(World3ObjectsConfig.section("likes").get("max", LIKES_MAX_DEFAULT))


## Fija el contador (recortado a 0-get_likes_max()) y avisa si cambia.
func set_likes(value: int) -> void:
	var clamped: int = clampi(value, 0, get_likes_max())
	if clamped == likes:
		return
	likes = clamped
	EventBus.likes_changed.emit(likes, get_likes_max())


## Suma `amount` likes sin pasar del tope. Devuelve los que entraron.
func add_likes(amount: int) -> int:
	var before: int = likes
	set_likes(likes + maxi(amount, 0))
	return likes - before


## Quita hasta `amount` likes (golpe, Ladron). Devuelve los que se perdieron.
func lose_likes(amount: int) -> int:
	var before: int = likes
	set_likes(likes - maxi(amount, 0))
	return before - likes


## Intento nuevo (o fin del nivel): 0 likes y sin valor de punto de sincronizacion.
func reset_likes() -> void:
	_likes_at_checkpoint = 0
	likes_checkpoint_serial = 0
	likes = 0
	EventBus.likes_changed.emit(likes, get_likes_max())


## Valor que se recupera al morir (el del ultimo punto de sincronizacion o 0).
func get_likes_at_checkpoint() -> int:
	return _likes_at_checkpoint


## Apunta los likes de ahora como los del punto de sincronizacion.
func note_likes_checkpoint() -> void:
	_likes_at_checkpoint = likes
	likes_checkpoint_serial += 1


## Muerte: el contador vuelve al valor del ultimo punto de sincronizacion.
func restore_likes_checkpoint() -> void:
	set_likes(_likes_at_checkpoint)


func _on_player_respawned_likes(_at: Vector2, after_death: bool) -> void:
	if after_death:
		restore_likes_checkpoint()


## Pulso de retorno (Pulso 5, tanda M2): el pulso acaba de aturdir a `enemy`.
## Con la mejora da pulse_energy_on_stun de energia (4) a la barra (sin desborde),
## UNA vez por enemigo y por intento (begin_attempt). Devuelve
## la energia del retorno (4) si se cobro ahora y 0 sin mejora o ya cobrado (con
## la barra llena se cobra igual y no entra nada: no desborda). Emite
## EventBus.pulse_energy_returned con lo que entro de verdad.
func claim_pulse_return(enemy: Node) -> float:
	var target := &"isak_abilities.pulse_energy_on_stun"
	var amount: float = effective_value(target, 0.0)
	if amount <= 0.0 or enemy == null or not is_instance_valid(enemy):
		return 0.0
	var key: String = String(enemy.get_path()) if enemy.is_inside_tree() else str(enemy.get_instance_id())
	if _pulse_return_claimed.has(key):
		return 0.0
	_pulse_return_claimed[key] = true
	var gained: float = recharge_debug_energy(amount)
	EventBus.pulse_energy_returned.emit(enemy, amount, gained)
	return amount


## El Pulso de retorno ya dio su energia por `enemy` en este intento.
func is_pulse_return_claimed(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var key: String = String(enemy.get_path()) if enemy.is_inside_tree() else str(enemy.get_instance_id())
	return _pulse_return_claimed.has(key)


## Multiplicador del aturdimiento del pulso (Pulso 3: x1,5). Lo aplican los
## enemigos que el pulso aturde (AlertBubble, NotificationBadge) al recibirlo.
func get_pulse_stun_multiplier() -> float:
	return effective_value(&"game_state.pulse_stun_multiplier", 1.0)


## Valor efectivo de `target` ("<origen>.<clave>"): `base` cambiado por los
## niveles comprados e implementados de cada pista (cada nivel suma su efecto a
## los anteriores; si dos tocan el mismo target gana el mas alto).
func effective_value(target: StringName, base: float) -> float:
	var value: float = base
	for effect: UpgradeCatalog.Effect in _owned_effects():
		if effect.target == target:
			value = effect.value
	return value


## Aplica a `object` (p. ej. PlayerAbilities) los efectos comprados cuyo target
## empieza por `source` + "." y cuya clave es una propiedad de `object`.
func apply_upgrades(object: Object, source: String) -> void:
	for effect: UpgradeCatalog.Effect in _owned_effects():
		if effect.source() == source and effect.key() in object:
			object.set(effect.key(), effect.value)


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


## Nivel actual de la pista `track` (1 = base; 1 tambien si no existe).
func get_upgrade_level(track: StringName) -> int:
	return int(upgrade_levels.get(track, UpgradeCatalog.LEVEL_MIN))


## Nivel mas alto que el acceso actual (lap: 1 Cache, 2 Kernel, 3 Raiz) deja
## comprar en `track` (Cache 3, Kernel 4, Raiz 5; min_lap de los datos).
func get_upgrade_access_cap(track: StringName) -> int:
	return UpgradeCatalog.shared().access_cap(track, lap)


## La pista se puede ver y comprar: su habilidad (requires_ability) esta
## obtenida en la partida actual. Si no, la tienda muestra el chip «?».
func is_upgrade_track_available(track: StringName) -> bool:
	var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
	if t == null:
		return false
	return t.requires_ability.is_empty() or is_ability_obtained(t.requires_ability)


## Verdadero si se tiene la mejora `id`: un legacy_id de las mejoras sueltas de
## antes (wide_pulse = pulso 2, requires_upgrade de los niveles) o "pista:nivel".
func is_upgrade_purchased(id: StringName) -> bool:
	var needed: Array = resolve_upgrade_id(id)
	return not needed.is_empty() and get_upgrade_level(needed[0]) >= int(needed[1])


## [pista, nivel] de un legacy_id o de "pista:nivel" (vacio si no se conoce).
static func resolve_upgrade_id(id: StringName) -> Array:
	var text := String(id)
	if text.contains(":"):
		var track := StringName(text.get_slice(":", 0))
		var level_text: String = text.get_slice(":", 1)
		if not level_text.is_valid_int() or UpgradeCatalog.shared().get_level(track, int(level_text)) == null:
			return []
		return [track, int(level_text)]
	return UpgradeCatalog.shared().resolve_legacy(id)


## Si se puede comprar ahora el siguiente nivel de `track` (OK) o por que no.
func check_purchase(track: StringName) -> int:
	var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
	if t == null:
		return PurchaseResult.UNKNOWN
	var next: UpgradeCatalog.Level = t.get_level(get_upgrade_level(track) + 1)
	if next == null:
		return PurchaseResult.MAX_LEVEL
	if not is_upgrade_track_available(track):
		return PurchaseResult.ABILITY_MISSING
	if next.min_lap > lap:
		return PurchaseResult.ACCESS_LOCKED
	if not next.implemented:
		return PurchaseResult.NOT_IMPLEMENTED
	if attention_points < next.cost_points:
		return PurchaseResult.NOT_ENOUGH_POINTS
	if power_banks < next.cost_power_banks:
		return PurchaseResult.NOT_ENOUGH_POWER_BANKS
	return PurchaseResult.OK


## Siguiente nivel de `track` (null si ya esta en el maximo o no existe).
func get_next_upgrade_level(track: StringName) -> UpgradeCatalog.Level:
	return UpgradeCatalog.shared().get_level(track, get_upgrade_level(track) + 1)


## Compra el siguiente nivel de `track`: gasta puntos (y el power bank del
## nivel 5), sube el nivel y marca "sin guardar". Si no se puede no cambia
## nada y devuelve el motivo (PurchaseResult).
func purchase_upgrade(track: StringName) -> int:
	var result: int = check_purchase(track)
	if result != PurchaseResult.OK:
		return result
	var next: UpgradeCatalog.Level = get_next_upgrade_level(track)
	attention_points -= next.cost_points
	power_banks -= next.cost_power_banks
	upgrade_levels[track] = next.level
	_refresh_maxima()
	EventBus.upgrade_purchased.emit(track)
	request_save()
	return PurchaseResult.OK


## Hay alguna pista por encima del nivel 1.
func has_any_upgrade() -> bool:
	for track: StringName in upgrade_levels:
		if upgrade_levels[track] > UpgradeCatalog.LEVEL_MIN:
			return true
	return false


## Niveles por encima del 1 como diccionario JSON {pista: nivel}, por pista.
func get_upgrade_levels_data() -> Dictionary:
	var out: Dictionary = {}
	for key: String in _keys_sorted(upgrade_levels):
		var level: int = upgrade_levels[StringName(key)]
		if level > UpgradeCatalog.LEVEL_MIN:
			out[key] = level
	return out


## Pone los niveles de un diccionario {pista: nivel} (guardado v4 y papelera);
## ignora pistas desconocidas y acota cada nivel a 1-5.
func _set_upgrade_levels(raw: Variant) -> void:
	if not raw is Dictionary:
		return
	var catalog: UpgradeCatalog = UpgradeCatalog.shared()
	for key: Variant in raw:
		var track := StringName(String(key))
		var value: Variant = raw[key]
		if not catalog.has_track(track) or not (value is float or value is int):
			continue
		var level: int = clampi(int(value), UpgradeCatalog.LEVEL_MIN, catalog.get_track(track).max_level())
		if level > UpgradeCatalog.LEVEL_MIN:
			upgrade_levels[track] = maxi(level, get_upgrade_level(track))


## Efectos de los niveles comprados e implementados (en orden de pista y nivel).
func _owned_effects() -> Array[UpgradeCatalog.Effect]:
	var out: Array[UpgradeCatalog.Effect] = []
	if upgrade_levels.is_empty():
		return out
	for track: UpgradeCatalog.Track in UpgradeCatalog.shared().tracks():
		var owned: int = get_upgrade_level(track.id)
		for level: int in range(UpgradeCatalog.LEVEL_MIN + 1, owned + 1):
			var entry: UpgradeCatalog.Level = track.get_level(level)
			if entry != null and entry.implemented:
				out.append_array(entry.effects)
	return out


# --- Guardado (user://save.json) ---

## Cambia la ruta de guardado. `fresh`: borra lo que hubiera (y su .bak) y
## empieza de cero; si no, carga lo guardado en esa ruta. Sin cambios pendientes.
## Apunta en started_from_save si se cargo una partida (arranque en el hub).
func use_save_path(path: String, fresh: bool) -> void:
	save_path = path
	if fresh:
		SaveFile.delete(path)
		reset_progress()
	else:
		started_from_save = load_game()


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
	reset_likes()
	lap = LAP_EASY
	found_secrets.clear()
	memories.clear()
	memories_read.clear()
	hub_upgrades.clear()
	nickname = NICKNAME_DEFAULT
	allies_met.clear()
	ally_arrivals.clear()
	learned_help.clear()
	_pulse_return_claimed.clear()
	set_player_hidden(false)
	lives_max = LIVES_MAX_DEFAULT
	play_time_s = 0.0
	saved_at = ""
	captured_points.clear()
	collected_pickups.clear()
	upgrade_levels.clear()
	for ability: StringName in obtained_abilities:
		set_ability_unlocked(ability, false)
	obtained_abilities.clear()
	seen_notices.clear()
	power_banks = 0
	completed_levels.clear()
	unlocked_levels.clear()
	_refresh_maxima()
	_set_unsaved(false)
	started_from_save = false
	lives = lives_max
	_unsaved_after_trash = false
	if not _trash.is_empty():
		_trash.clear()
		EventBus.trash_changed.emit(false)


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
	# Con la papelera llena no se guarda: el estado sin lo desechado
	# sobrescribiria la copia buena (propuesta §5.2).
	if has_trash_pending():
		return false
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
		"upgrade_levels": _upgrade_levels_save_data(),
		"abilities_obtained": _keys_sorted(obtained_abilities),
		"seen_notices": _keys_sorted(seen_notices),
		"power_banks": {"full": power_banks},
		"completed_levels": _keys_sorted(completed_levels),
		"unlocked_levels": _keys_sorted(unlocked_levels),
		"lap": lap,
		"found_secrets": secrets,
		"memories": _keys_sorted(memories),
		"memories_read": _keys_sorted(memories_read),
		"hub_upgrades": _keys_sorted(hub_upgrades),
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
	if int(version) >= 4:
		_set_upgrade_levels(data.get("upgrade_levels", {}))
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
		# Coleccionable puro desde el 2026-10-25: los power banks vacios de un
		# guardado anterior (recogidos en el mapa) pasan a completos; la carga
		# parcial ("charge") ya no existe y se ignora.
		power_banks = maxi(_as_int(banks.get("full", 0)), 0) + maxi(_as_int(banks.get("empty", 0)), 0)
	var legacy_upgrades: Array[StringName] = _string_names(data.get("upgrades_purchased", []))
	if int(version) < 4:
		_migrate_upgrades_to_v4(legacy_upgrades)
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
	# v5 (recuerdos): un guardado anterior no los tiene y empieza con la lista
	# vacia (migracion). Ids que el catalogo no conoce se ignoran.
	if int(version) >= 5:
		var catalog: MemoryCatalog = MemoryCatalog.shared()
		for id: StringName in _string_names(data.get("memories", [])):
			if catalog.has(id):
				memories[id] = true
		for id: StringName in _string_names(data.get("memories_read", [])):
			if memories.has(id):
				memories_read[id] = true
	# v6 (upgrades del hub): un guardado anterior no los tiene y empieza sin
	# ninguno (migracion). Quien ya vencio a La Curadora ve el acertijo al cargar:
	# «acertijo pendiente» se calcula (HubWorlds.is_hub_upgrade_pending), no se
	# guarda. Ids que no estan en HUB_UPGRADES se ignoran.
	if int(version) >= 6:
		for id: StringName in _string_names(data.get("hub_upgrades", [])):
			if HUB_UPGRADES.has(id):
				hub_upgrades[id] = true
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
	# mejoras ya compradas (de cuando Calc dormida vendia desde el 1-1; o un v4
	# con algun nivel comprado) la da por conocida, para no dejar a nadie sin la
	# tienda que ya uso.
	if has_any_upgrade() or (int(version) < 4 and not legacy_upgrades.is_empty()):
		allies_met[ALLY_CALC] = true
	var raw_saved_at: Variant = data.get("saved_at", "")
	saved_at = raw_saved_at if raw_saved_at is String else ""
	play_time_s = _as_float(data.get("play_time_s", 0.0))
	_refresh_maxima()
	lives = lives_max
	return true


## Migracion v1-v3 -> v4 (docs/propuesta-mejoras.md §7.3; seccion migration de
## data/upgrades.json): cada mejora suelta comprada pasa al nivel de su pista
## (si es mas alto que el que ya hubiera) y se devuelve la diferencia de precio
## en puntos y power banks (completos; sin tope). Las ids desconocidas se ignoran.
func _migrate_upgrades_to_v4(legacy_ids: Array[StringName]) -> void:
	var catalog: UpgradeCatalog = UpgradeCatalog.shared()
	var refund_points: int = 0
	var refund_banks: int = 0
	for id: StringName in legacy_ids:
		var entry: Dictionary = catalog.migration_for(id)
		if entry.is_empty():
			continue
		var track := StringName(String(entry.get("track", "")))
		if catalog.has_track(track):
			_set_upgrade_levels({String(track): int(entry.get("level", UpgradeCatalog.LEVEL_MIN))})
		var refund: Variant = entry.get("refund", {})
		if refund is Dictionary:
			refund_points += maxi(int(refund.get("attention_points", 0)), 0)
			refund_banks += maxi(int(refund.get("power_banks", 0)), 0)
	attention_points += refund_points
	power_banks += refund_banks


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
	EventBus.likes_changed.emit(likes, get_likes_max())


## Fija el ultimo punto de sincronizacion de `level` (sustituye al anterior).
## Apunta tambien los likes del intento (vuelven a este valor al morir).
func set_last_checkpoint(level: StringName, checkpoint_id: StringName) -> void:
	if last_checkpoint.get(level, NO_LEVEL) == checkpoint_id:
		return
	last_checkpoint[level] = checkpoint_id
	note_likes_checkpoint()
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


## Upgrade del hub `id` instalado (v6; docs/propuesta-hub-mundos-4-6.md §2.6).
func has_hub_upgrade(id: StringName) -> bool:
	return hub_upgrades.has(id)


## Instala el upgrade del hub `id` (HUB_UPGRADES): solo marca «sin guardar»
## (guardado manual: se guarda en Notas) y lo anuncia con
## EventBus.hub_upgrade_installed. Falso si ya estaba o si `id` no se conoce.
func install_hub_upgrade(id: StringName) -> bool:
	if not HUB_UPGRADES.has(id) or hub_upgrades.has(id):
		return false
	hub_upgrades[id] = true
	request_save()
	EventBus.hub_upgrade_installed.emit(id)
	return true


func is_ability_unlocked(ability: StringName) -> bool:
	return abilities_unlocked.get(ability, false)


# --- Recuerdos (docs/propuesta-recuerdos.md §4 y §7 paso 2) ---

## Obtiene el recuerdo `id` (data/memories.json): queda en memories sin leer y
## marca «sin guardar» (hasta guardar en Notas, un game over lo pierde). Falso
## si ya estaba o el id no existe.
func obtain_memory(id: StringName) -> bool:
	if not MemoryCatalog.shared().has(id):
		push_error("GameState: unknown memory '%s'" % id)
		return false
	if memories.has(id):
		return false
	memories[id] = true
	memories_read.erase(id)
	request_save()
	EventBus.memory_obtained.emit(id)
	return true


func has_memory(id: StringName) -> bool:
	return memories.has(id)


## Todos los recuerdos de data/memories.json en el registro: las 18 capas de
## jefe y todos los mensajes de secretos (condicion del final real, decision
## del 2026-10-19; §10 de la propuesta).
func has_all_memories() -> bool:
	var ids: Array[StringName] = MemoryCatalog.shared().ids()
	if ids.is_empty():
		return false
	for id: StringName in ids:
		if not memories.has(id):
			return false
	return true


## Recuerdos que faltan para el final real (paso 8 de docs/propuesta-recuerdos.md,
## §11.4), en el orden de data/memories.json: todo id del catalogo que no esta en
## memories (las capas de jefe y los mensajes de secretos; cuenta lo obtenido aunque
## no se haya guardado, porque Isak Optimizado entrega su capa Raíz justo antes de
## la comprobacion). `before_final_boss`: sin la capa Raíz del Mundo 6 (la entrega
## la propia pelea), para avisar en el hub de lo que aun hay que buscar.
func real_ending_missing(before_final_boss: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	var final_layer: StringName = MemoryCatalog.shared().boss_id(REAL_ENDING_FINAL_WORLD, LAP_HARD)
	for id: StringName in MemoryCatalog.shared().ids():
		if memories.has(id) or (before_final_boss and id == final_layer):
			continue
		out.append(id)
	return out


## Gancho del final real (docs/06-finales.md §14.1; propuesta-recuerdos.md §8.2,
## §10 y §11.4): en Raíz (LAP_HARD) y con TODOS los recuerdos de data/memories.json
## (las 18 capas de jefe y todos los mensajes de secretos; has_all_memories). Lo
## consultara el momento de decision tras la entrega de Isak Optimizado (el final
## aun no existe).
func real_ending_unlocked() -> bool:
	return lap == LAP_HARD and has_all_memories()


## Apunta el recuerdo obtenido `id` como leido (al abrir su ficha en Notas). No
## marca «sin guardar». Falso si no esta obtenido o ya estaba leido.
func mark_memory_read(id: StringName) -> bool:
	if not memories.has(id) or memories_read.has(id):
		return false
	memories_read[id] = true
	EventBus.memory_read.emit(id)
	return true


func is_memory_read(id: StringName) -> bool:
	return memories_read.has(id)


## Hay algun recuerdo obtenido sin leer (marca del icono de Notas del hub).
func has_unread_memories() -> bool:
	for id: StringName in memories:
		if not memories_read.has(id):
			return true
	return false


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


## Sube el maximo de vidas para siempre (se guarda en lives_max) y suma una
## vida al intento en curso. Marca «sin guardar». La usa collect_extra_life.
func add_max_life() -> void:
	lives_max += 1
	lives += 1
	request_save()
	_emit_lives()


## Vida extra (paso 14 de §10; ExtraLifePickup, p. ej. el secreto D del 1-1):
## una sola vez por mapa e id. Apunta el secreto `secret_id` de `level` en
## found_secrets (registro: «1-1» / «D») y sube lives_max (+1 tambien ahora).
## Como todo lo obtenido, va a disco con la siguiente copia: con un game over
## sin guardar, apply_rollback vuelve a la copia y la vida extra reaparece.
## Falso (sin cambios) si ya estaba encontrada o no hay nivel.
func collect_extra_life(level: StringName, secret_id: StringName) -> bool:
	if level == NO_LEVEL or secret_id == &"" or is_secret_found(level, secret_id):
		return false
	mark_secret_found(level, secret_id)
	add_max_life()
	EventBus.extra_life_collected.emit(level, secret_id)
	return true


func _emit_lives() -> void:
	EventBus.lives_changed.emit(lives, lives_max, are_lives_active())


# --- Rollback y papelera (propuesta §5.2-§5.4) ---

## Rollback: UNA sola regla para el game over y el rollback del jefe final
## (propuesta §5.3). `reason`:
## - ROLLBACK_GAME_OVER (0 vidas): el estado vuelve a la ultima copia guardada
##   en disco (load_game): lo obtenido despues de guardar se pierde (no va a la
##   papelera) y los niveles completados despues hay que rejugarlos. Sin copia,
##   se empieza de cero.
## - (Futuro, paso 16) rollback del jefe final: partira del estado en memoria
##   con lap + 1 y los mapas restaurados; anade aqui su rama y reutiliza el resto.
## Despues, en todos los casos:
## - Nunca se pierde (registro y regalo de Eco; decision del usuario): Eco,
##   Notas, Calc y demas asistentes conocidos, el apodo, las ayudas aprendidas
##   (album) y el pulso. Los recuerdos guardados (memories) vuelven con la
##   copia y no van a la papelera; los obtenidos sin guardar se pierden.
##   Igual los upgrades del hub (hub_upgrades, v6): vuelven con la copia, no van
##   a la papelera y el instalado sin guardar se pierde (el acertijo se repite).
## - Eco «desecha» lo guardado (habilidades salvo el pulso, power banks, puntos
##   de atencion y mejoras): pasa a la papelera (discard_to_trash) y se recupera
##   todo de golpe en el hub (recover_trash).
## - La papelera queda activada (allies_met "papelera") y las vidas, repuestas.
## Devuelve el informe {reason, had_copy, first, trash_has_content, trash} y lo
## emite con EventBus.rollback_applied. Vacio si `reason` no se conoce.
func apply_rollback(reason: StringName = ROLLBACK_GAME_OVER) -> Dictionary:
	if reason != ROLLBACK_GAME_OVER:
		push_error("GameState: rollback desconocido '%s'" % reason)
		return {}
	var keep_allies: Dictionary = allies_met.duplicate()
	# Lo no guardado se pierde, tambien una llegada al hub aun sin encuentro.
	ally_arrivals.clear()
	var keep_nickname: String = nickname
	var keep_help: Dictionary = learned_help.duplicate()
	var keep_pulse: bool = obtained_abilities.has(ABILITY_PULSE)
	var keep_read: Dictionary = memories_read.duplicate()
	var had_copy: bool = load_game()
	# Los recuerdos guardados vuelven con la copia (registro: no van a la
	# papelera); lo leido de los que siguen se queda leido.
	for id: StringName in keep_read:
		if memories.has(id):
			memories_read[id] = true
	var copy_nickname: String = nickname
	for ally: StringName in keep_allies:
		allies_met[ally] = true
	nickname = keep_nickname
	learned_help.clear()
	for id: StringName in keep_help:
		learned_help[id] = true
	if keep_pulse and not obtained_abilities.has(ABILITY_PULSE):
		obtained_abilities[ABILITY_PULSE] = true
		set_ability_unlocked(ABILITY_PULSE, true)
		seen_notices[ABILITY_PULSE] = true
	var first: bool = not allies_met.has(ALLY_PAPELERA)
	allies_met[ALLY_PAPELERA] = true
	if first:
		EventBus.ally_met.emit(ALLY_PAPELERA)
	var trash: Dictionary = discard_to_trash()
	_unsaved_after_trash = nickname != copy_nickname
	if trash.is_empty():
		_set_unsaved(_unsaved_after_trash)
		_unsaved_after_trash = false
	refill_lives()
	var report: Dictionary = {
		"reason": reason,
		"had_copy": had_copy,
		"first": first,
		"trash_has_content": not trash.is_empty(),
		"trash": trash.duplicate(true),
	}
	EventBus.rollback_applied.emit(report)
	return report


## Eco desecha lo guardado: habilidades obtenidas (salvo el pulso), power banks,
## puntos de atencion y mejoras salen del estado y quedan en la papelera. No hay
## cambios sin guardar (el disco tiene la copia). Devuelve lo desechado (vacio
## si no habia nada que desechar: la papelera queda vacia).
func discard_to_trash() -> Dictionary:
	var abilities: Array[String] = []
	for ability: StringName in obtained_abilities:
		if ability != ABILITY_PULSE:
			abilities.append(String(ability))
	abilities.sort()
	var trash: Dictionary = {
		TRASH_POINTS: attention_points,
		TRASH_POWER_BANKS: power_banks,
		TRASH_UPGRADES: get_upgrade_levels_data(),
		TRASH_ABILITIES: abilities,
	}
	if attention_points <= 0 and power_banks <= 0 \
			and not has_any_upgrade() and abilities.is_empty():
		trash = {}
	attention_points = ATTENTION_POINTS_MIN
	power_banks = 0
	upgrade_levels.clear()
	for id: String in abilities:
		obtained_abilities.erase(StringName(id))
		set_ability_unlocked(StringName(id), false)
	_refresh_maxima()
	_trash = trash
	_set_unsaved(false)
	EventBus.trash_changed.emit(has_trash_pending())
	return trash.duplicate(true)


## Hay contenido en la papelera pendiente de recuperar: las carpetas no se
## abren, no se puede guardar en Notas y el aviso al salir no avisa.
func has_trash_pending() -> bool:
	return not _trash.is_empty()


## Copia del contenido de la papelera (claves TRASH_*; vacio si no hay nada).
func get_trash() -> Dictionary:
	return _trash.duplicate(true)


## Recupera de golpe todo lo de la papelera (al acercarse a ella en el hub). El
## estado vuelve a ser el de la copia guardada: sin cambios sin guardar (salvo
## un apodo nuevo, que no se pierde). Falso si no habia nada.
func recover_trash() -> bool:
	if _trash.is_empty():
		return false
	var trash: Dictionary = _trash
	_trash = {}
	attention_points += int(trash.get(TRASH_POINTS, 0))
	power_banks += int(trash.get(TRASH_POWER_BANKS, 0))
	_set_upgrade_levels(trash.get(TRASH_UPGRADES, {}))
	for id: Variant in trash.get(TRASH_ABILITIES, []):
		var ability := StringName(String(id))
		if abilities_unlocked.has(ability):
			obtained_abilities[ability] = true
			set_ability_unlocked(ability, true)
	_refresh_maxima()
	# Cambios hechos con la papelera llena (p. ej. el apodo en Notas) siguen
	# pendientes.
	_set_unsaved(_unsaved or _unsaved_after_trash)
	_unsaved_after_trash = false
	EventBus.trash_changed.emit(false)
	EventBus.trash_recovered.emit(trash.duplicate(true))
	return true


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
	EventBus.power_banks_changed.emit(power_banks)


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


## upgrade_levels del guardado v4: todas las pistas del catalogo con su nivel
## (1 = base), en el orden del catalogo.
func _upgrade_levels_save_data() -> Dictionary:
	var out: Dictionary = {}
	for track: StringName in UpgradeCatalog.shared().track_ids():
		out[String(track)] = get_upgrade_level(track)
	return out


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
