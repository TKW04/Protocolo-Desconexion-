## Hub REAL del Mundo 1 (docs/propuesta-hub-y-guardado.md §2; paso 5 de §6.2):
## sala 2D caminable de una pantalla (size_tiles 20x11 de 64 px), camara fija
## (limites de la camara de Isak = la pantalla), suelo = dock (filas desde
## floor_row), paredes en los bordes y techo. Todo sale de la seccion room de
## data/hub.json.
## Al entrar:
## - Isak aparece en P (spawn_cell; pies en el borde inferior de la celda) por
##   un vortice de llegada (WarpVortex.arrive): sin control hasta que se cierra
##   (senal arrived).
## - La energia de Debug (y el Sync Rate) se llenan (refill_on_enter).
## - Habilidades del hub (abilities_available: pulso si, Debug no; se restauran
##   al salir, como en GeneratedLevel); las obtenidas no se tocan.
## - El HUD pasa al modo hub (Modo Avion e indicador «sin guardar» en ambar).
## Arte final (assets/sprites/hub/, tools/gen_hub_objects.py): fondo con la foto
## rota (Background: animacion off, pieza 1 con contorno cian que parpadea; on,
## pieza 1 encendida cuando la carpeta del mundo background_on_world esta
## completada), dock de tiles (suelo), indicador de pagina, repisas de una via y
## carpetas. Estaciones (stations: escena HubStation en una celda, con su
## SpriteFrames `frames`) y huecos apagados del dock (dormant: siluetas de
## Notas, Linterna y Papelera; `frames` + `animation` o `texture`) se crean
## desde los datos en un nodo "Visual". Notas (NotasStation, antes «copia
## local») guarda y tiene el album; mientras el hub esta abierto y Notas esta
## encendida, el aviso al salir con cambios ofrece guardar (grupo
## QuitGuard.SAVE_STATION_GROUP). Calc (CalcStation, paso 8) vende las mejoras.
## ASISTENTES (2026-10-16, docs/propuesta-asistentes-y-vidas.md §2.2, §2.3 y §8):
## una estacion con requires_ally esta apagada (HubStation.set_powered) hasta que
## GameState conoce a ese asistente (EventBus.ally_met la enciende al momento):
## Notas hasta su presentacion y Calc hasta su encuentro. La primera vez que
## Isak llega al hub (Notas desconocida), al terminar la llegada empieza la
## presentacion de Notas (NotasIntro) con el cuadro de texto del hub
## (EcoTextBox, hijo "EcoTextBox").
## ENCUENTRO CON CALC (2026-10-17, tanda H3 del paso 14 del 1-2): si Calc se
## teletransporto al hub en esta sesion (azotea del 1-2; GameState.
## is_ally_arrival_pending) y no es conocida, Calc espera despierta en su
## estacion (sin tienda) y, al terminar la llegada (tras la presentacion de
## Notas si tambien toca), empieza CalcIntro: pausa, lineas de Calc (estilo LCD)
## con la de Eco entre medias y meet_ally("calc"). Con un game over no hay
## encuentro (el rollback pierde la llegada pendiente).
## Carpetas (paso 7; seccion folders y worlds): una FolderStation por mundo
## sobre su repisa (shelf_height_px sobre el dock, alcanzable de un salto). Al
## elegir un subnivel, Isak (de espaldas) se va por el vortice de salida
## (WarpVortex.depart) y se carga level_runner_scene (scenes/main.tscn) con ese
## nivel (LevelRunner.start_level_id), sustituyendo a la escena actual
## (scene_switcher lo cambia en pruebas).
## FLUJO DEL JUEGO (paso 9): LevelRunner (scenes/main.tscn) carga esta escena
## como hija al completar un nivel (hub_scene de data/flow.json), con
## hold_arrival (el vortice de llegada espera a que el fundido deje ver el hub:
## release_arrival) y level_handler (al elegir un subnivel, el propio
## LevelRunner funde y carga el nivel en lugar de sustituir la escena). Abierta
## sola (scenes/hub/hub.tscn) sigue cargando scenes/main.tscn con el nivel.
## Eco companero (EcoCompanion, variante atenuada: sin cobertura) entra y sale
## con Isak si Eco es conocido; no es una estacion.
## GAME OVER Y PAPELERA (2026-10-16, docs/propuesta-asistentes-y-vidas.md §5.2,
## paso 12 de §10): la Papelera (seccion papelera; columna 10 del dock) duerme
## hasta el primer game over; con contenido parpadea y se recupera al acercarse.
## Si LevelRunner trae el informe del rollback (rollback_report), al terminar la
## llegada Eco lo cuenta (GameOverIntro, data/game_over.json). Mientras la
## papelera tenga contenido las carpetas no se abren (HubWorlds.can_enter), Notas
## no guarda y el aviso al salir no ofrece guardar (can_save_now).
## CARGADOR (2026-10-16; seccion charger): el objeto charger de los niveles en la
## columna 16 del dock (50 de energia, reutilizable, 20 s; se activa al tocarlo).
## No se guarda ni marca «sin guardar»; se crea de nuevo en cada visita.
## MENU DE PAUSA (2026-10-16): la accion pause y el icono de ajustes del HUD
## (junto al Modo Avion) abren el PauseMenu del flujo (el de LevelRunner) o, con
## el hub abierto solo, uno propio (hijo "PauseMenu"). No se abre
## (blocks_pause_menu) hasta terminar la llegada, durante la salida por el
## vortice ni con el panel de una estacion o carpeta abierto.
## COMENTARIOS DE CALC (2026-10-27, paso 17 de docs/propuesta-mundo-3.md §2.3;
## seccion calc.remarks de data/hub.json): al terminar la llegada (y la
## presentacion de Notas y el encuentro con Calc, si tocan; nunca tras un game
## over), si se llega de `after_level` (arrived_from_level, lo da LevelRunner) y
## Calc es conocida, Calc dice una vez por partida guardada su linea en el LCD
## (no importante: no pausa). Visto = GameState.mark_notice_seen("calc_remark_<id>").
## VARIAS PAGINAS (2026-10-27, paso 2 de docs/propuesta-hub-mundos-4-6.md §3.2;
## room.pages de data/hub.json): una sola sala de hasta 3 paginas de 20 x 11. Se
## construyen las paginas seguidas desde la 1 que existen (get_page_state):
## antes de vencer a La Curadora solo la 1, identica a la de siempre; con el
## acertijo pendiente (3-boss sin hub_update_4_6) tambien la 2 «en instalacion»
## (vacia hasta el paso 3), con el glitch del borde derecho de la pagina 1
## (HubEdgeGlitch) y el indicador de 2 puntos; con el upgrade, las 3. La camara
## queda fija en la pagina actual y, al cruzar Isak el borde, se desliza
## (page_slide_s, Isak en pausa). La llegada es en la pagina de la carpeta del
## mundo del que se vuelve (P2/P3), si esa pagina existe; si no, en P.
## DEBUG (comprobado en el paso 2, tests/test_hub_pages.gd): el Debug obtenido
## se puede usar en el hub (las habilidades obtenidas no se tocan; reset() solo
## lo apaga al entrar).
## ACERTIJO «ACTUALIZACION DEL SISTEMA» (2026-10-27, paso 3 de
## docs/propuesta-hub-mundos-4-6.md §2; data/hub_update.json): con la pagina 2
## «en instalacion» se monta en ella HubUpdatePuzzle (hijo "UpdatePuzzle",
## verificaciones V1-V3 e instalador) y un segundo cargador junto a P2
## (cargador_p2). Mientras esta activo y no inerte (Papelera llena), Isak puede
## usar en el hub el dash, el golpe al suelo y Pellizcar obtenidos
## (Isak.hub_gestures). Con 3/3, el pulso al instalador emite
## update_install_requested. Las verificaciones no se guardan: cada visita
## empieza en 0/3.
## INSTALACION Y UPGRADE (2026-10-27, paso 5 de docs/propuesta-hub-mundos-4-6.md
## §3; seccion hub_update_install de data/hub.json): update_install_requested
## empieza HubUpdateInstall (hijo "UpdateInstall": pausa, barra de 3 s,
## destello, linea importante de Notas). En el destello, apply_update_install
## instala el upgrade (GameState.install_hub_upgrade: solo «sin guardar»; un game
## over sin guardar lo pierde y el acertijo se repite), quita el acertijo y
## reconstruye la sala con las 3 paginas: carpetas M4 y M5 en la pagina 2 y M6
## (con su candado de 5 ranuras) en la 3, el instalador como decorado apagado
## (InstallerDecor) y la pieza 4 del fondo en off (M4 disponible). Las carpetas
## de cada pagina salen de HubWorlds.folder_worlds(pagina) con su `col` local a
## la pagina; las ocultas (requires_upgrade sin instalar) no se construyen.
## Pieza 4: arte PROVISIONAL por codigo (room.pieces con `provisional`) hasta el
## paso 7.
## TEXTOS Y PISTAS (2026-10-27, paso 6 de docs/propuesta-hub-mundos-4-6.md):
## comentario de Calc al volver de 3-boss (calc.remarks con
## requires_pending_upgrade) y, al terminar de deslizarse a la pagina del
## acertijo, la linea de Eco (HubUpdatePuzzle.start_intro); las pistas 3 y 4 y
## la linea de progreso de Notas son de HubUpdatePuzzle.
class_name HubRoom
extends Node2D

## Estacion donde se guarda (Notas).
const SAVE_STATION_ID: StringName = &"notas"
const TEXT_BOX_SCENE: String = "res://scenes/ui/eco_text_box.tscn"

## Isak termino de llegar (tiene el control).
signal arrived
## La pieza del fondo del mundo `world` se recompone y se ilumina (tras vencer
## al jefe que completa la carpeta; audio: sfx_hub_wallpaper_piece).
signal wallpaper_piece_lit(world: int)
## Se va a cargar el subnivel `level_id` (Isak ya se fue por el vortice).
signal level_requested(level_id: StringName)
## La camara termino de deslizarse a la pagina `page` (audio futuro:
## sfx_hub_page_slide, paso 7).
signal page_changed(page: int)
## Con 3/3 se ha pulsado el instalador del acertijo de la pagina 2: se pide
## instalar `upgrade_id` (paso 5 de docs/propuesta-hub-mundos-4-6.md: empieza la
## instalacion, HubUpdateInstall).
signal update_install_requested(upgrade_id: StringName)

## Estados de una pagina del hub (get_page_state).
const PAGE_OPEN: StringName = &"open"
const PAGE_INSTALLING: StringName = &"installing"
const PAGE_CLOSED: StringName = &"closed"

## Si es valido, recibe la raiz preparada (LevelRunner de level_runner_scene con
## start_level_id) en lugar de sustituir la escena actual (pruebas).
var scene_switcher: Callable = Callable()
## Si es valido, se llama con el id del subnivel elegido (tras el vortice de
## salida) en lugar de cargar level_runner_scene: lo usa LevelRunner, que tiene
## el hub como hija. El hub no se quita del arbol: lo quita quien lo llama.
var level_handler: Callable = Callable()
## Si es verdadero (antes de entrar al arbol), el vortice de llegada espera a
## release_arrival() (LevelRunner: al terminar el fundido de entrada).
var hold_arrival: bool = false
## Informe del rollback del game over (GameState.apply_rollback) con el que se
## llega (lo da LevelRunner antes de entrar al arbol); vacio = llegada normal.
var rollback_report: Dictionary = {}
## Se llega tras completar por primera vez el nivel que enciende la pieza del
## fondo (el jefe del mundo; lo da LevelRunner antes de entrar al arbol): la
## pieza espera apagada a que termine la llegada y entonces se enciende con un
## destello (piece_light_s, piece_flashes de la seccion room).
var light_piece_on_arrival: bool = false
## Mundo de la pieza que se enciende al llegar (0 = la del fondo,
## background_on_world). Lo da LevelRunner con light_piece_on_arrival
## (2026-10-23, paso 18 de docs/propuesta-mundo-2.md: pieza ambar del Mundo 2).
var light_piece_world: int = 0
## Nivel del que se llega (LevelRunner._show_hub; "" al abrir el hub solo).
## Lo leen los comentarios de Calc (calc.remarks de data/hub.json).
var arrived_from_level: String = ""

var _room: Dictionary = HubData.section("room")
var _isak: Isak
var _hud: Hud
var _arrival: WarpVortex
var _arrived: bool = false
var _stations: Dictionary[StringName, HubStation] = {}
var _dormant: Dictionary[StringName, Node2D] = {}
var _folders: Dictionary[StringName, FolderStation] = {}
var _background: AnimatedSprite2D
var _departure: WarpVortex
var _entering_level: StringName = &""
var _previous_abilities: Dictionary = {}
var _companion: EcoCompanion
var _text_box: EcoTextBox
var _notas_intro: NotasIntro
var _papelera: Papelera
var _charger: Charger
var _game_over_intro: GameOverIntro
var _calc_intro: CalcIntro
var _piece_pending: bool = false
var _piece_lighting: bool = false
## Piezas del fondo de otros mundos (room.pieces): capas encima del fondo con
## animaciones hidden (mundo bloqueado), off (desbloqueado, sin completar) y on.
var _pieces: Dictionary[int, AnimatedSprite2D] = {}
## Paginas construidas (seguidas desde la 1; 1 antes de La Curadora).
var _page_count: int = 0
var _current_page: int = 1
var _sliding: bool = false
var _slide_tween: Tween
var _page_indicators: Dictionary[int, HubPageIndicator] = {}
var _edge_glitch: HubEdgeGlitch
var _update_puzzle: HubUpdatePuzzle
var _charger_p2: Charger
var _update_install_requested: StringName = &""
var _update_install: HubUpdateInstall
var _installer_decor: Node2D


func _enter_tree() -> void:
	GameState.current_world = int(_room.get("world", GameState.FIRST_WORLD))
	_previous_abilities.clear()
	var abilities: Dictionary = _room.get("abilities_available", {})
	for key: Variant in abilities:
		var ability := StringName(String(key))
		if GameState.is_ability_obtained(ability):
			continue
		_previous_abilities[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, bool(abilities[key]))
	if not bool(abilities.get(String(GameState.ABILITY_DEBUG), false)):
		DebugMode.reset()


func _exit_tree() -> void:
	for ability: StringName in _previous_abilities:
		if GameState.is_ability_obtained(ability):
			continue
		GameState.set_ability_unlocked(ability, bool(_previous_abilities[ability]))
	_previous_abilities.clear()


func _ready() -> void:
	_isak = get_node(^"Isak") as Isak
	# En el hub no hay regeneracion pasiva ni Ocultarte (tanda M2).
	_isak.level_mode = false
	_hud = get_node_or_null(^"Hud") as Hud
	_text_box = (load(TEXT_BOX_SCENE) as PackedScene).instantiate() as EcoTextBox
	_text_box.name = "EcoTextBox"
	add_child(_text_box)
	add_to_group(PauseMenu.BLOCKER_GROUP)
	if PauseMenu.find_in(get_tree()) == null:
		add_child(PauseMenu.new())
	_page_count = _count_pages()
	_current_page = get_arrival_page()
	_build_room()
	_build_dormant()
	_build_papelera()
	_build_charger()
	_build_stations()
	_build_folders()
	_build_update_puzzle()
	_build_installer_decor()
	EventBus.ally_met.connect(_on_ally_met)
	page_changed.connect(_on_page_changed)
	if not rollback_report.is_empty():
		_game_over_intro = GameOverIntro.new()
		_game_over_intro.name = "GameOverIntro"
		_game_over_intro.report = rollback_report
		_game_over_intro.text_box = _text_box
		add_child(_game_over_intro)
	elif not GameState.has_met_ally(GameState.ALLY_NOTAS):
		_notas_intro = NotasIntro.new()
		_notas_intro.name = "NotasIntro"
		_notas_intro.station = get_notas()
		_notas_intro.text_box = _text_box
		add_child(_notas_intro)
	if rollback_report.is_empty() and CalcIntro.is_pending():
		_calc_intro = CalcIntro.new()
		_calc_intro.name = "CalcIntro"
		_calc_intro.station = get_calc()
		_calc_intro.text_box = _text_box
		add_child(_calc_intro)
		if _calc_intro.station != null:
			_calc_intro.station.set_arrived(true)
	add_to_group(QuitGuard.SAVE_STATION_GROUP)
	if bool(_room.get("refill_on_enter", true)):
		GameState.refill_debug_energy()
		GameState.sync_rate = GameState.get_sync_rate_max()
	if _hud != null:
		_hud.enable_hub_mode(HubData.section("hud"))
	_place_isak()
	_papelera.isak = _isak
	if _update_puzzle != null:
		_update_puzzle.set_isak(_isak)
	# Eco entra con Isak, atenuado (sin cobertura; no guarda ni compra).
	_companion = EcoCompanion.attach(_isak, self, true)
	_start_arrival()


# --- Consultas ---

## Se puede guardar aqui (QuitGuard: el aviso al salir ofrece «Guardar y
## salir»): el hub tiene Notas y esta encendida.
func can_save_now() -> bool:
	var station: HubStation = get_station(SAVE_STATION_ID)
	return is_inside_tree() and station != null and station.is_powered() and not GameState.has_trash_pending()


## El menu de pausa no se abre ahora (PauseMenu.BLOCKER_GROUP): llegada sin
## terminar, salida por el vortice, Isak sin control o de espaldas, o un panel
## de estacion o carpeta abierto.
func blocks_pause_menu() -> bool:
	if not _arrived or not _entering_level.is_empty() or _sliding:
		return true
	var calc_intro: CalcIntro = get_calc_intro()
	if calc_intro != null and calc_intro.is_running():
		return true
	if is_update_installing():
		return true
	if _isak == null or not is_instance_valid(_isak) or _isak.is_warping() or _isak.is_facing_back():
		return true
	for station: HubStation in _stations.values():
		if station.is_panel_open():
			return true
	for folder: FolderStation in _folders.values():
		if folder.is_panel_open():
			return true
	return false


## Papelera del dock.
func get_papelera() -> Papelera:
	return _papelera


## Cargador de energia del dock (seccion charger; null si no hay).
func get_charger() -> Charger:
	return _charger


## Lineas de Eco tras el game over (null si se llego sin rollback).
func get_game_over_intro() -> GameOverIntro:
	return _game_over_intro if _game_over_intro != null and is_instance_valid(_game_over_intro) else null


## Notas (guardar y album).
func get_notas() -> NotasStation:
	return get_station(SAVE_STATION_ID) as NotasStation


## Presentacion de Notas (null si Notas ya era conocida al entrar).
func get_notas_intro() -> NotasIntro:
	return _notas_intro if _notas_intro != null and is_instance_valid(_notas_intro) else null


## Encuentro con Calc (null si no tocaba al entrar).
func get_calc_intro() -> CalcIntro:
	return _calc_intro if _calc_intro != null and is_instance_valid(_calc_intro) else null


## Cuadro de texto del hub (presentacion de Notas y encuentro con Calc).
func get_text_box() -> EcoTextBox:
	return _text_box


func get_isak() -> Isak:
	return _isak


## Eco companero (atenuado en el hub).
func get_eco_companion() -> EcoCompanion:
	return _companion if _companion != null and is_instance_valid(_companion) else null


func get_hud() -> Hud:
	return _hud


## Suelta el vortice de llegada retenido (hold_arrival). Falso si no habia.
func release_arrival() -> bool:
	var vortex: WarpVortex = get_arrival_vortex()
	return vortex != null and vortex.release()


## Calc (tienda de mejoras; apagada hasta conocerla).
func get_calc() -> CalcStation:
	return get_station(&"calc") as CalcStation


func get_arrival_vortex() -> WarpVortex:
	return _arrival if _arrival != null and is_instance_valid(_arrival) else null


func has_arrived() -> bool:
	return _arrived


func get_station(id: StringName) -> HubStation:
	return _stations.get(id, null)


func get_station_ids() -> Array[StringName]:
	return _stations.keys()


## Hueco apagado del dock `id` (notas, linterna, papelera).
func get_dormant(id: StringName) -> Node2D:
	return _dormant.get(id, null)


func get_dormant_ids() -> Array[StringName]:
	return _dormant.keys()


## Carpeta del mundo `id` (m1, m2, m3).
func get_folder(id: StringName) -> FolderStation:
	return _folders.get(id, null)


func get_folder_ids() -> Array[StringName]:
	return _folders.keys()


## Borde superior de las repisas (y de su colision) en px.
func get_shelf_top_y() -> float:
	return get_floor_y() - float(HubData.section("folders").get("shelf_height_px", 160))


## Animacion del fondo: off (pieza 1 con contorno) u on (encendida).
func get_background_state() -> StringName:
	return _background.animation if _background != null else &""


## Subnivel al que se esta entrando (vacio si ninguno).
func get_entering_level() -> StringName:
	return _entering_level


func get_departure_vortex() -> WarpVortex:
	return _departure if _departure != null and is_instance_valid(_departure) else null


## Tamano de una pagina en tiles (room.size_tiles: 20 x 11).
func get_page_size_tiles() -> Vector2i:
	var s: Array = _room.get("size_tiles", [20, 11])
	return Vector2i(int(s[0]), int(s[1]))


## Ancho de una pagina en px.
func get_page_width_px() -> float:
	return float(get_page_size_tiles().x) * HubData.tile_size()


## Tamano de la parte construida de la sala en tiles (las paginas que existen:
## 20 x 11 antes de La Curadora, hasta 60 x 11) y en px.
func get_size_tiles() -> Vector2i:
	var page: Vector2i = get_page_size_tiles()
	return Vector2i(page.x * get_page_count(), page.y)


func get_size_px() -> Vector2:
	return Vector2(get_size_tiles()) * HubData.tile_size()


## Tamano de la sala completa (todas las paginas de room.pages: 60 x 11).
func get_room_size_tiles() -> Vector2i:
	var page: Vector2i = get_page_size_tiles()
	return Vector2i(page.x * get_pages().size(), page.y)


## Paginas de room.pages (o una sola con camera_rect_px y spawn_cell de room).
func get_pages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _room.get("pages", []):
		if entry is Dictionary:
			out.append(entry)
	if out.is_empty():
		out.append({"camera_rect_px": _room.get("camera_rect_px", [0, 0, 1280, 720]),
			"spawn_cell": _room.get("spawn_cell", [5, 8]), "spawn_facing": _room.get("spawn_facing", 1.0)})
	return out


func _page_entry(page: int) -> Dictionary:
	var pages: Array[Dictionary] = get_pages()
	return pages[clampi(page, 1, pages.size()) - 1]


## Estado de la pagina `page` (1-3) con el progreso actual: PAGE_OPEN (sin
## requires_upgrade o con el upgrade instalado), PAGE_INSTALLING (while_pending
## installing y el acertijo pendiente: 3-boss sin el upgrade) o PAGE_CLOSED (no
## existe). La disponibilidad de las carpetas va aparte (HubWorlds).
func get_page_state(page: int) -> StringName:
	var pages: Array[Dictionary] = get_pages()
	if page < 1 or page > pages.size():
		return PAGE_CLOSED
	var entry: Dictionary = pages[page - 1]
	var upgrade := StringName(String(entry.get("requires_upgrade", "")))
	if upgrade.is_empty() or GameState.has_hub_upgrade(upgrade):
		return PAGE_OPEN
	if String(entry.get("while_pending", "")) == String(PAGE_INSTALLING) and HubWorlds.is_hub_upgrade_pending(upgrade):
		return PAGE_INSTALLING
	return PAGE_CLOSED


## Paginas que existen (seguidas desde la 1). Fijo desde que el hub entra al
## arbol: se construyen al entrar.
func get_page_count() -> int:
	return _page_count if _page_count > 0 else _count_pages()


func _count_pages() -> int:
	var count: int = 0
	for page: int in range(1, get_pages().size() + 1):
		if get_page_state(page) == PAGE_CLOSED:
			break
		count = page
	return maxi(count, 1)


## Pagina en la que esta la camara (la de destino al terminar un deslizamiento).
func get_current_page() -> int:
	return _current_page


## La camara se esta deslizando entre paginas (Isak en pausa).
func is_page_sliding() -> bool:
	return _sliding


## Pagina de la llegada: la de la carpeta del mundo de arrived_from_level (P2/P3
## al volver de un nivel de los Mundos 4-6) si existe; si no, la 1.
func get_arrival_page() -> int:
	if arrived_from_level.is_empty():
		return 1
	var entry: Dictionary = HubWorlds.world_of_level(StringName(arrived_from_level))
	if entry.is_empty():
		# Mundo sin subniveles registrados todavia: por el prefijo «<mundo>-».
		var prefix: String = arrived_from_level.get_slice("-", 0)
		if prefix.is_valid_int():
			for world_entry: Dictionary in HubWorlds.worlds():
				if int(world_entry.get("world", 0)) == int(prefix):
					entry = world_entry
	if entry.is_empty():
		return 1
	var page: int = HubWorlds.world_page(entry)
	return page if page >= 1 and page <= get_page_count() else 1


## Indicador de paginas de la pagina `page` (null con una sola pagina: PageDot).
func get_page_indicator(page: int) -> HubPageIndicator:
	return _page_indicators.get(page, null)


## Glitch del borde derecho de la pagina 1 (null si la 2 no esta en instalacion).
func get_edge_glitch() -> HubEdgeGlitch:
	return _edge_glitch


## Acertijo de la pagina 2 (null si la pagina 2 no esta en instalacion).
func get_update_puzzle() -> HubUpdatePuzzle:
	return _update_puzzle


## Cargador del acertijo junto a P2 (null sin acertijo).
func get_update_charger() -> Charger:
	return _charger_p2


## Upgrade cuya instalacion se ha pedido en esta visita (&"" si ninguno). Lo
## consumira el paso 5.
func get_update_install_requested() -> StringName:
	return _update_install_requested


func is_update_install_requested() -> bool:
	return not _update_install_requested.is_empty()


## Instalacion en curso o terminada en esta visita (null si no se ha pedido).
func get_update_install() -> HubUpdateInstall:
	return _update_install if _update_install != null and is_instance_valid(_update_install) else null


## La instalacion esta en marcha (juego en pausa).
func is_update_installing() -> bool:
	var install: HubUpdateInstall = get_update_install()
	return install != null and install.is_running()


## Instalador apagado como decorado de la pagina 2 (null sin el upgrade).
func get_installer_decor() -> Node2D:
	return _installer_decor


## Rectangulo que ve la camara en la pagina `page` (por defecto, la actual).
func get_camera_rect(page: int = -1) -> Rect2i:
	var entry: Dictionary = _page_entry(_current_page if page < 1 else page)
	var r: Array = entry.get("camera_rect_px", _room.get("camera_rect_px", [0, 0, 1280, 720]))
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


## Rectangulo que ve ahora la camara de Isak (sus limites).
func get_view_rect() -> Rect2i:
	var camera := _isak.get_node_or_null(^"Camera2D") as Camera2D if _isak != null else null
	if camera == null:
		return get_camera_rect()
	return Rect2i(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left,
		camera.limit_bottom - camera.limit_top)


## Altura del suelo (borde superior del dock) en px.
func get_floor_y() -> float:
	return float(_room.get("floor_row", 9)) * HubData.tile_size()


## Posicion de la llegada de la pagina `page` (pies de Isak; por defecto, la
## pagina de la llegada: P en la 1).
func get_spawn_position(page: int = -1) -> Vector2:
	var entry: Dictionary = _page_entry(get_arrival_page() if page < 1 else page)
	var cell: Array = entry.get("spawn_cell", _room.get("spawn_cell", [5, 8]))
	var t: float = HubData.tile_size()
	return Vector2((float(cell[0]) + 0.5) * t, (float(cell[1]) + 1.0) * t)


# --- Interno ---

func _place_isak() -> void:
	_isak.global_position = get_spawn_position(_current_page)
	_isak.velocity = Vector2.ZERO
	var facing: float = float(_page_entry(_current_page).get("spawn_facing", _room.get("spawn_facing", 1.0)))
	_isak.facing = signf(facing)
	var sprite := _isak.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.flip_h = _isak.facing < 0.0
	_set_camera_left(float(get_camera_rect(_current_page).position.x))


## Limites de la camara de Isak en una pagina cuyo borde izquierdo esta en `x`
## (el ancho y la altura de camera_rect_px: la camara queda fija ahi).
func _set_camera_left(x: float) -> void:
	var camera := _isak.get_node_or_null(^"Camera2D") as Camera2D if _isak != null else null
	if camera == null:
		return
	var rect: Rect2i = get_camera_rect(_current_page)
	camera.limit_left = int(roundf(x))
	camera.limit_top = rect.position.y
	camera.limit_right = int(roundf(x)) + rect.size.x
	camera.limit_bottom = rect.end.y
	camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	if _sliding or get_page_count() <= 1 or _isak == null or not is_instance_valid(_isak):
		return
	if not _entering_level.is_empty() or _isak.is_warping():
		return
	var page: int = clampi(int(floorf(_isak.global_position.x / get_page_width_px())) + 1, 1, get_page_count())
	if page != _current_page:
		slide_to_page(page)


## Desliza la camara a la pagina `page` (page_slide_s s; Isak en pausa) y emite
## page_changed al terminar. Falso si no existe o ya se esta deslizando.
func slide_to_page(page: int) -> bool:
	if _sliding or page < 1 or page > get_page_count() or page == _current_page:
		return false
	var from: float = float(get_camera_rect(_current_page).position.x)
	var to: float = float(get_camera_rect(page).position.x)
	_current_page = page
	_sliding = true
	if _isak != null and is_instance_valid(_isak):
		_isak.set_physics_process(false)
	var duration: float = maxf(float(_room.get("page_slide_s", 0.35)), 0.01)
	_slide_tween = create_tween()
	_slide_tween.tween_method(_set_camera_left, from, to, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.finished.connect(_end_slide)
	return true


## Termina al instante el deslizamiento en curso (pruebas y capturas).
func finish_page_slide() -> void:
	if _sliding and _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.custom_step(1000.0)


func _end_slide() -> void:
	_set_camera_left(float(get_camera_rect(_current_page).position.x))
	_sliding = false
	_slide_tween = null
	if _isak != null and is_instance_valid(_isak):
		_isak.set_physics_process(true)
	page_changed.emit(_current_page)


func _start_arrival() -> void:
	_arrival = WarpVortex.arrive(_isak, self, hold_arrival)
	_arrival.finished.connect(_on_arrival_finished)


func _on_arrival_finished() -> void:
	_arrived = true
	arrived.emit()
	if _piece_pending:
		_light_piece()
	var game_over: GameOverIntro = get_game_over_intro()
	if game_over != null:
		game_over.start()
		return
	var intro: NotasIntro = get_notas_intro()
	if intro != null and intro.start():
		# El encuentro con Calc, si toca, despues de la presentacion de Notas.
		intro.finished.connect(_start_calc_intro, CONNECT_ONE_SHOT)
		return
	_start_calc_intro()


func _start_calc_intro() -> void:
	var calc_intro: CalcIntro = get_calc_intro()
	if calc_intro != null and calc_intro.start():
		calc_intro.finished.connect(start_calc_remark, CONNECT_ONE_SHOT)
		return
	start_calc_remark()


## Prefijo de seen_notices de los comentarios de Calc.
const CALC_REMARK_NOTICE: String = "calc_remark_%s"


## Comentario de Calc que toca al llegar de arrived_from_level ({} si ninguno):
## el primero de calc.remarks con ese after_level, Calc conocida y sin ver.
func pending_calc_remark() -> Dictionary:
	if arrived_from_level.is_empty() or not GameState.has_met_ally(GameState.ALLY_CALC):
		return {}
	for entry: Variant in (HubData.section("calc") as Dictionary).get("remarks", []):
		if not entry is Dictionary:
			continue
		var remark: Dictionary = entry
		if String(remark.get("after_level", "")) != arrived_from_level:
			continue
		if GameState.is_notice_seen(StringName(CALC_REMARK_NOTICE % String(remark.get("id", "")))):
			continue
		if String(remark.get("text", "")).is_empty():
			continue
		# requires_pending_upgrade (paso 6 del hub 4-6): solo con ese upgrade del
		# hub pendiente (el acertijo a la vista; no en Kernel/Raiz ya instalado).
		var upgrade: String = String(remark.get("requires_pending_upgrade", ""))
		if not upgrade.is_empty() and not HubWorlds.is_hub_upgrade_pending(StringName(upgrade)):
			continue
		return remark
	return {}


## Dice el comentario de Calc pendiente (no importante). Verdadero si salio.
func start_calc_remark() -> bool:
	var remark: Dictionary = pending_calc_remark()
	if remark.is_empty() or _text_box == null:
		return false
	GameState.mark_notice_seen(StringName(CALC_REMARK_NOTICE % String(remark.get("id", ""))))
	_text_box.show_line(String(remark.get("text", "")), float(remark.get("duration_s", -1.0)), false, &"calc")
	return true


## Al llegar a la pagina del acertijo por primera vez, la linea de Eco
## (HubUpdatePuzzle.start_intro; una vez por partida guardada).
func _on_page_changed(page: int) -> void:
	if _update_puzzle == null or not is_instance_valid(_update_puzzle):
		return
	if page == int(HubUpdatePuzzle.load_data().get("page", 2)):
		_update_puzzle.start_intro()


## Un asistente recien conocido enciende sus estaciones (requires_ally).
func _on_ally_met(ally: StringName) -> void:
	for entry: Dictionary in _room.get("stations", []):
		if StringName(String(entry.get("requires_ally", ""))) == ally:
			var station: HubStation = get_station(StringName(String(entry.get("id", ""))))
			if station != null:
				station.set_powered(true)


func _build_room() -> void:
	var t: float = HubData.tile_size()
	var size: Vector2 = get_size_px()
	var screen: Rect2 = Rect2(get_camera_rect())
	var floor_y: float = get_floor_y()
	var room := Node2D.new()
	room.name = "Room"
	add_child(room)
	move_child(room, 0)
	_background = AnimatedSprite2D.new()
	_background.name = "Background"
	_background.centered = false
	_background.sprite_frames = load(String(_room.get("background", ""))) as SpriteFrames
	room.add_child(_background)
	# Paginas 2 y 3: fondo PROVISIONAL de un color (el arte llega en el paso 7).
	for page: int in range(2, get_page_count() + 1):
		var page_rect: Rect2i = get_camera_rect(page)
		var fill := ColorRect.new()
		fill.name = "PageBackground%d" % page
		fill.color = Color(String(_room.get("page_background_color", "#3a4862")))
		fill.position = Vector2(page_rect.position)
		fill.size = Vector2(page_rect.size)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_child(fill)
	for entry: Dictionary in _room.get("pieces", []):
		var piece := AnimatedSprite2D.new()
		var world: int = int(entry.get("world", 0))
		piece.name = "Piece%d" % world
		piece.centered = false
		var frames_path: String = String(entry.get("frames", ""))
		if not frames_path.is_empty():
			piece.sprite_frames = load(frames_path) as SpriteFrames
		elif entry.get("provisional", null) is Dictionary:
			_make_provisional_piece(piece, entry["provisional"])
		var at: Array = entry.get("position_px", [0, 0])
		piece.position = Vector2(float(at[0]), float(at[1]))
		room.add_child(piece)
		_pieces[world] = piece
	refresh_background()
	_build_dock(room, screen, floor_y)
	_build_page_indicators(room)
	_build_edge_glitch(room)
	var bodies := StaticBody2D.new()
	bodies.name = "Collision"
	bodies.collision_layer = 1
	bodies.collision_mask = 0
	room.add_child(bodies)
	var thick: float = t
	var height: float = maxf(size.y, screen.size.y)
	# Suelo (dock), paredes a los lados de la pantalla y techo.
	_add_box(bodies, "Floor", Rect2(-thick, floor_y, size.x + thick * 2.0, height - floor_y + thick))
	_add_box(bodies, "WallLeft", Rect2(-thick, -thick, thick, height + thick * 2.0))
	_add_box(bodies, "WallRight", Rect2(size.x, -thick, thick, height + thick * 2.0))
	_add_box(bodies, "Ceiling", Rect2(0.0, -thick, size.x, thick))


## Pieza del fondo PROVISIONAL por codigo (room.pieces con `provisional`; paso 7
## para el arte): SpriteFrames vacias con hidden, off (2 cuadros, como las
## demas) y on, y un hijo que dibuja el contorno (off, parpadea) o el relleno (on)
## de polygon_px en `color`.
func _make_provisional_piece(piece: AnimatedSprite2D, cfg: Dictionary) -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var empty := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	for spec: Array in [[&"hidden", 1, 1.0], [&"off", 2, 1.5], [&"on", 1, 1.0]]:
		var anim: StringName = spec[0]
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, float(spec[2]))
		for i: int in int(spec[1]):
			frames.add_frame(anim, empty)
	piece.sprite_frames = frames
	var art := _ProvisionalPiece.new()
	art.name = "ProvisionalArt"
	art.piece = piece
	art.color = Color(String(cfg.get("color", "#ff7f66")))
	for p: Variant in cfg.get("polygon_px", []):
		art.polygon.append(Vector2(float((p as Array)[0]), float((p as Array)[1])))
	piece.add_child(art)
	piece.frame_changed.connect(art.queue_redraw)
	piece.animation_changed.connect(art.queue_redraw)


## Indicador de paginas en la fila page_dot_row de cada pagina: con una sola,
## el PageDot de siempre; con varias, un HubPageIndicator por pagina (su punto
## lleno y los demas en anillo; la 2 «en instalacion», cargando).
func _build_page_indicators(room: Node2D) -> void:
	var dot_path: String = String(_room.get("page_dot", ""))
	if dot_path.is_empty():
		return
	var t: float = HubData.tile_size()
	var y: float = (float(_room.get("page_dot_row", 10)) + 0.5) * t
	var count: int = get_page_count()
	if count <= 1:
		var dot := Sprite2D.new()
		dot.name = "PageDot"
		dot.texture = load(dot_path) as Texture2D
		dot.position = Vector2(get_page_width_px() * 0.5, y)
		room.add_child(dot)
		return
	var loading: int = 0
	for page: int in range(1, count + 1):
		if get_page_state(page) == PAGE_INSTALLING:
			loading = page
	var other_path: String = String(_room.get("page_dot_other", ""))
	for page: int in range(1, count + 1):
		var indicator := HubPageIndicator.new()
		indicator.name = "PageIndicator%d" % page
		indicator.count = count
		indicator.current = page
		indicator.loading_page = loading
		indicator.spacing_px = float(_room.get("page_dot_spacing_px", 16))
		indicator.loading_s = float(_room.get("page_dot_loading_s", 1.2))
		indicator.current_texture = load(dot_path) as Texture2D
		indicator.other_texture = load(other_path) as Texture2D if not other_path.is_empty() else null
		var rect: Rect2i = get_camera_rect(page)
		indicator.position = Vector2(float(rect.position.x) + get_page_width_px() * 0.5, y)
		room.add_child(indicator)
		_page_indicators[page] = indicator


## Glitch del borde derecho de la pagina 1 mientras la 2 esta «en instalacion».
func _build_edge_glitch(room: Node2D) -> void:
	var cfg: Dictionary = _room.get("edge_glitch", {})
	if cfg.is_empty() or get_page_count() < 2 or get_page_state(2) != PAGE_INSTALLING:
		return
	var t: float = HubData.tile_size()
	var rows: Array = cfg.get("rows", [5, 8])
	_edge_glitch = HubEdgeGlitch.new()
	_edge_glitch.name = "EdgeGlitch"
	_edge_glitch.position = Vector2(float(cfg.get("col", 19)) * t, float(rows[0]) * t)
	_edge_glitch.size = Vector2(t, float(int(rows[1]) - int(rows[0]) + 1) * t)
	var colors: Array[Color] = []
	for value: Variant in cfg.get("colors", []):
		colors.append(Color(String(value)))
	if not colors.is_empty():
		_edge_glitch.colors = colors
	_edge_glitch.flicker_every_s = float(cfg.get("flicker_every_s", 1.5))
	room.add_child(_edge_glitch)


## La pieza del fondo se esta encendiendo (destello tras vencer al jefe).
func is_piece_lighting() -> bool:
	return _piece_lighting


## La pieza espera a que termine la llegada para encenderse.
func is_piece_pending() -> bool:
	return _piece_pending


## Enciende la pieza con un destello: piece_flashes parpadeos en piece_light_s
## (tiempo real) y despues la animacion on; emite wallpaper_piece_lit.
func _light_piece() -> void:
	_piece_pending = false
	_piece_lighting = true
	var world: int = get_light_world()
	var sprite: AnimatedSprite2D = get_piece_sprite(world)
	var flashes: int = maxi(int(_room.get("piece_flashes", 3)), 1)
	var total: float = maxf(float(_room.get("piece_light_s", 0.9)), 0.05)
	var step: float = total / float(flashes * 2)
	var tween: Tween = create_tween()
	for i: int in flashes:
		tween.tween_callback(func() -> void:
			if sprite != null and sprite.sprite_frames.has_animation(&"on"):
				sprite.play(&"on"))
		tween.tween_interval(step)
		tween.tween_callback(func() -> void:
			if sprite != null and sprite.sprite_frames.has_animation(&"off"):
				sprite.play(&"off"))
		tween.tween_interval(step)
	tween.tween_callback(func() -> void:
		_piece_lighting = false
		refresh_background()
		wallpaper_piece_lit.emit(world))


## Mundo de la pieza que se enciende al llegar.
func get_light_world() -> int:
	return light_piece_world if light_piece_world > 0 else int(_room.get("background_on_world", 1))


## Sprite de la pieza del mundo `world` (el fondo para background_on_world; la
## capa de room.pieces para los demas; null si no hay).
func get_piece_sprite(world: int) -> AnimatedSprite2D:
	if world == int(_room.get("background_on_world", 1)):
		return _background
	return _pieces.get(world, null)


## Animacion actual de la pieza del mundo `world` (pruebas).
func get_piece_animation(world: int) -> StringName:
	var sprite: AnimatedSprite2D = get_piece_sprite(world)
	return sprite.animation if sprite != null else &""


## Fondo: pieza 1 encendida si la carpeta de background_on_world esta completada;
## las de room.pieces: on (carpeta completada), off (mundo desbloqueado: el
## contorno parpadea) u hidden (bloqueado).
func refresh_background() -> void:
	if _background == null or _background.sprite_frames == null:
		return
	var on_world: int = int(_room.get("background_on_world", 1))
	var light_world: int = get_light_world()
	for entry: Dictionary in HubWorlds.worlds():
		var world: int = int(entry.get("world", 0))
		var sprite: AnimatedSprite2D = get_piece_sprite(world)
		if sprite == null or sprite.sprite_frames == null:
			continue
		var lit: bool = HubWorlds.folder_state(entry) == HubWorlds.STATE_COMPLETED
		if lit and light_piece_on_arrival and world == light_world and not _arrived and not _piece_lighting:
			_piece_pending = true
			lit = false
		var anim: StringName = &"on" if lit else &"off"
		if world != on_world and not lit and not HubWorlds.is_world_unlocked(entry):
			anim = &"hidden"
		if world == light_world and _piece_lighting:
			continue
		if sprite.sprite_frames.has_animation(anim) and (sprite.animation != anim or not sprite.is_playing()):
			sprite.play(anim)


## Dock de tiles: fila del suelo (bordes y centro) y relleno hasta el borde de
## la pantalla.
func _build_dock(room: Node2D, screen: Rect2, floor_y: float) -> void:
	var dock: Dictionary = _room.get("dock", {})
	if dock.is_empty():
		return
	var t: float = HubData.tile_size()
	var holder := Node2D.new()
	holder.name = "Dock"
	room.add_child(holder)
	var cols: int = get_size_tiles().x
	var every: int = maxi(1, int(dock.get("fill_alt_every", 5)))
	var offset: int = int(dock.get("fill_alt_offset", 2))
	for c: int in cols:
		var top_key: String = "top_left" if c == 0 else ("top_right" if c == cols - 1 else "top_center")
		_add_tile(holder, String(dock.get(top_key, "")), Vector2(c * t, floor_y))
		var y: float = floor_y + t
		while y < screen.end.y:
			var fill_key: String = "fill_alt" if c % every == offset else "fill"
			_add_tile(holder, String(dock.get(fill_key, "")), Vector2(c * t, y))
			y += t


func _add_tile(parent: Node, path: String, pos: Vector2) -> Sprite2D:
	var tile := Sprite2D.new()
	tile.centered = false
	tile.texture = load(path) as Texture2D if not path.is_empty() else null
	tile.position = pos
	parent.add_child(tile)
	return tile


func _add_box(body: StaticBody2D, node_name: String, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


## Huecos apagados del dock, de pie sobre el suelo en su columna.
func _build_dormant() -> void:
	var holder := Node2D.new()
	holder.name = "Dormant"
	add_child(holder)
	move_child(holder, 1)
	var t: float = HubData.tile_size()
	for entry: Dictionary in _room.get("dormant", []):
		var id := StringName(String(entry.get("id", "")))
		var size_px: Array = entry.get("size_px", [64, 96])
		var size := Vector2(float(size_px[0]), float(size_px[1]))
		var node := Node2D.new()
		node.name = String(entry.get("node", String(id).capitalize()))
		node.position = Vector2(float(entry.get("col", 0)) * t + (t - size.x) * 0.5, get_floor_y() - size.y)
		node.set_meta(&"dormant_id", id)
		holder.add_child(node)
		var visual: Node2D = _visual_for(entry, size)
		visual.name = "Visual"
		node.add_child(visual)
		_dormant[id] = node


## Papelera (seccion papelera), de pie sobre el dock en su columna.
func _build_papelera() -> void:
	var cfg: Dictionary = HubData.section("papelera")
	var t: float = HubData.tile_size()
	_papelera = Papelera.new()
	_papelera.name = String(cfg.get("node", "Papelera"))
	var size: Vector2 = _papelera.get_size()
	_papelera.position = Vector2(float(cfg.get("col", 10)) * t + (t - size.x) * 0.5, get_floor_y() - size.y)
	add_child(_papelera)
	move_child(_papelera, 2)


## Cargador de energia (seccion charger de data/hub.json): el mismo objeto
## `charger` de los niveles (scenes/levels/charger.tscn) con los valores por
## defecto del catalogo (types.charger.defaults de data/world1_objects.json:
## 50 de energia, reutilizable, 20 s de enfriamiento), en su columna del dock
## (celda de la fila sobre el suelo, como en un nivel). Se activa al tocarlo.
## Reutilizable: no se guarda ni marca «sin guardar» y su enfriamiento empieza
## de cero en cada visita (se crea con el hub).
func _build_charger() -> void:
	var cfg: Dictionary = HubData.section("charger")
	if cfg.is_empty():
		return
	var t: float = HubData.tile_size()
	_charger = _make_charger(String(cfg.get("node", "Charger")), StringName(String(cfg.get("id", "cargador_hub"))),
		Vector2(float(cfg.get("col", 16)) * t, get_floor_y() - t))
	add_child(_charger)
	move_child(_charger, 2)


## Cargador del hub (seccion charger) con su nombre, id y posicion.
func _make_charger(node_name: String, id: StringName, at: Vector2) -> Charger:
	var cfg: Dictionary = HubData.section("charger")
	var scene := load(String(cfg.get("scene", "res://scenes/levels/charger.tscn"))) as PackedScene
	var charger := scene.instantiate() as Charger
	charger.name = node_name
	charger.object_id = id
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(Charger.CONFIG_PATH))
	if catalog is Dictionary:
		var type_cfg: Variant = ((catalog as Dictionary).get("types", {}) as Dictionary).get("charger", {})
		var defaults: Dictionary = (type_cfg as Dictionary).get("defaults", {}) if type_cfg is Dictionary else {}
		charger.amount = float(defaults.get("amount", charger.amount))
		charger.reusable = bool(defaults.get("reusable", charger.reusable))
		charger.cooldown_s = float(defaults.get("cooldown_s", charger.cooldown_s))
	charger.frames_path = String(cfg.get("frames", ""))
	charger.position = at
	return charger


## Acertijo «Actualizacion del sistema» en la pagina 2 «en instalacion» (paso 3).
func _build_update_puzzle() -> void:
	var data: Dictionary = HubUpdatePuzzle.load_data()
	var page: int = int(data.get("page", 2))
	if page > get_page_count() or get_page_state(page) != PAGE_INSTALLING:
		return
	var origin: Vector2 = Vector2(get_camera_rect(page).position)
	_update_puzzle = HubUpdatePuzzle.new()
	_update_puzzle.name = "UpdatePuzzle"
	_update_puzzle.position = origin
	_update_puzzle.text_box = _text_box
	add_child(_update_puzzle)
	move_child(_update_puzzle, 2)
	_update_puzzle.install_requested.connect(_on_update_install_requested)
	var cfg: Dictionary = data.get("charger", {})
	if not cfg.is_empty() and not HubData.section("charger").is_empty():
		var t: float = HubData.tile_size()
		_charger_p2 = _make_charger("ChargerP2", StringName(String(cfg.get("id", "cargador_p2"))),
			origin + Vector2(float(cfg.get("col", 5)) * t, get_floor_y() - t))
		add_child(_charger_p2)
		move_child(_charger_p2, 2)


## Instalador apagado como decorado de la pagina 2 (§3.1 paso 5) cuando el
## upgrade ya esta instalado (hub_update_install.installer_decor_cell). Sin
## colision ni prompt. Arte PROVISIONAL (terminal de HubProvisionalArt, atenuado).
func _build_installer_decor() -> void:
	if _installer_decor != null and is_instance_valid(_installer_decor):
		_installer_decor.queue_free()
	_installer_decor = null
	var page: int = int(HubUpdatePuzzle.load_data().get("page", 2))
	var upgrade := StringName(String(HubUpdatePuzzle.load_data().get("upgrade", "hub_update_4_6")))
	if page > get_page_count() or get_page_state(page) != PAGE_OPEN or not GameState.has_hub_upgrade(upgrade):
		return
	var cfg: Dictionary = HubData.section("hub_update_install")
	var t: float = HubData.tile_size()
	var cell: Array = cfg.get("installer_decor_cell", [7, 6])
	var size: Array = cfg.get("installer_decor_size_tiles", [2, 3])
	var art := HubProvisionalArt.new()
	art.kind = &"terminal"
	art.size = Vector2(float(size[0]), float(size[1])) * t
	art.modulate = Color(0.55, 0.55, 0.6)
	_installer_decor = Node2D.new()
	_installer_decor.name = "InstallerDecor"
	_installer_decor.position = Vector2(get_camera_rect(page).position) + Vector2(float(cell[0]), float(cell[1])) * t
	_installer_decor.add_child(art)
	add_child(_installer_decor)
	move_child(_installer_decor, 2)


func _on_update_install_requested(upgrade_id: StringName) -> void:
	_update_install_requested = upgrade_id
	update_install_requested.emit(upgrade_id)
	_start_update_install(upgrade_id)


## Empieza la secuencia de §3.1 (HubUpdateInstall). Falso si ya hay una.
func _start_update_install(upgrade_id: StringName) -> bool:
	if get_update_install() != null or GameState.has_hub_upgrade(upgrade_id):
		return false
	if _update_puzzle != null and is_instance_valid(_update_puzzle):
		var installer: HubInstaller = _update_puzzle.get_installer()
		if installer != null and installer.is_panel_open():
			installer.close(true)
	_update_install = HubUpdateInstall.new()
	_update_install.name = "UpdateInstall"
	_update_install.upgrade_id = upgrade_id
	_update_install.text_box = _text_box
	_update_install.apply = apply_update_install
	if _update_puzzle != null and is_instance_valid(_update_puzzle):
		var colors: Array[Color] = []
		for id: StringName in _update_puzzle.get_check_ids():
			colors.append(_update_puzzle.get_check(id).frame_color)
		if not colors.is_empty():
			_update_install.colors = colors
	add_child(_update_install)
	return _update_install.start()


## Instala el upgrade `upgrade_id` y deja el hub en su forma final (lo llama
## HubUpdateInstall en el destello; tambien sirve en pruebas): marca «sin
## guardar», quita el acertijo y reconstruye sala, paginas y carpetas. Falso si
## ya estaba instalado.
func apply_update_install(upgrade_id: StringName) -> bool:
	if not GameState.install_hub_upgrade(upgrade_id):
		return false
	if _update_puzzle != null and is_instance_valid(_update_puzzle):
		remove_child(_update_puzzle)
		_update_puzzle.queue_free()
	_update_puzzle = null
	_page_count = _count_pages()
	var old_room: Node = get_node_or_null(^"Room")
	if old_room != null:
		remove_child(old_room)
		old_room.queue_free()
	_pieces.clear()
	_page_indicators.clear()
	_edge_glitch = null
	_build_room()
	for node_name: String in ["Shelves", "Folders"]:
		var old: Node = get_node_or_null(NodePath(node_name))
		if old != null:
			remove_child(old)
			old.queue_free()
	_folders.clear()
	_build_folders()
	_build_installer_decor()
	if _isak != null and is_instance_valid(_isak):
		_set_camera_left(float(get_camera_rect(_current_page).position.x))
	return true


func _build_stations() -> void:
	var holder := Node2D.new()
	holder.name = "Stations"
	add_child(holder)
	move_child(holder, 2)
	var t: float = HubData.tile_size()
	for entry: Dictionary in _room.get("stations", []):
		var scene := load(String(entry.get("scene", "res://scenes/hub/hub_station.tscn"))) as PackedScene
		var station := scene.instantiate() as HubStation
		var id := StringName(String(entry.get("id", "")))
		station.name = String(entry.get("node", String(id).capitalize()))
		station.station_id = id
		var cell: Array = entry.get("cell", [0, 0])
		station.position = Vector2(float(cell[0]) * t, float(cell[1]) * t)
		if entry.has("text"):
			station.text = String(entry["text"])
		if entry.has("frames"):
			station.frames = String(entry["frames"])
		var ally: String = String(entry.get("requires_ally", ""))
		if not ally.is_empty():
			station.set_powered(GameState.has_met_ally(StringName(ally)))
		holder.add_child(station)
		_stations[id] = station


## Arte final: `frames` (SpriteFrames; animacion `animation`, por defecto off)
## o `texture`. Si no hay ninguno, el provisional de `kind`.
func _visual_for(entry: Dictionary, size: Vector2) -> Node2D:
	var frames_path: String = String(entry.get("frames", ""))
	if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = load(frames_path) as SpriteFrames
		sprite.centered = false
		var anim := StringName(String(entry.get("animation", "off")))
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
		return sprite
	var texture_path: String = String(entry.get("texture", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var image := Sprite2D.new()
		image.centered = false
		image.texture = load(texture_path) as Texture2D
		return image
	var art := HubProvisionalArt.new()
	art.kind = StringName(String(entry.get("kind", "slot")))
	art.size = size
	return art


## Repisas de una via y carpetas de los mundos (secciones folders y worlds).
func _build_folders() -> void:
	var cfg: Dictionary = HubData.section("folders")
	var t: float = HubData.tile_size()
	var shelves := Node2D.new()
	shelves.name = "Shelves"
	add_child(shelves)
	move_child(shelves, 1)
	var holder := Node2D.new()
	holder.name = "Folders"
	add_child(holder)
	move_child(holder, 2)
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	shelves.add_child(body)
	var size_tiles: Array = cfg.get("size_tiles", [2, 2])
	var width: int = int(size_tiles[0])
	var extra: int = int(cfg.get("shelf_extra_tiles", 1))
	var shelf_y: float = get_shelf_top_y()
	var tiles: Dictionary = cfg.get("shelf", {})
	var scene := load(String(cfg.get("scene", "res://scenes/hub/folder_station.tscn"))) as PackedScene
	var entries: Array[Dictionary] = []
	for page: int in range(1, get_page_count() + 1):
		if get_page_state(page) != PAGE_OPEN:
			continue
		for world_entry: Dictionary in HubWorlds.folder_worlds(page):
			if HubWorlds.folder_state(world_entry) != HubWorlds.STATE_HIDDEN:
				entries.append(world_entry)
	for entry: Dictionary in entries:
		var id := StringName(String(entry.get("id", "")))
		# `col` es local a la pagina de la carpeta.
		var col: int = int(entry.get("col", 0)) + (HubWorlds.world_page(entry) - 1) * get_page_size_tiles().x
		var first: int = col - extra
		var last: int = col + width - 1 + extra
		for c: int in range(first, last + 1):
			var key: String = "left" if c == first else ("right" if c == last else "center")
			_add_tile(shelves, String(tiles.get(key, "")), Vector2(c * t, shelf_y)).name = "Shelf_%s_%d" % [id, c]
		var shape := CollisionShape2D.new()
		shape.name = "Shelf_%s" % id
		var box := RectangleShape2D.new()
		box.size = Vector2((last - first + 1) * t, float(cfg.get("shelf_collision_px", 12)))
		shape.shape = box
		shape.one_way_collision = true
		shape.position = Vector2(first * t + box.size.x * 0.5, shelf_y + box.size.y * 0.5)
		body.add_child(shape)
		var folder := scene.instantiate() as FolderStation
		folder.name = "Folder_%s" % id
		folder.station_id = id
		folder.world_entry = entry
		folder.position = Vector2(col * t, shelf_y - folder.height_tiles * t + float(cfg.get("folder_sink_px", 0)))
		holder.add_child(folder)
		folder.level_chosen.connect(_on_folder_level_chosen)
		_folders[id] = folder


# --- Entrar a un subnivel ---

## Entra al subnivel `level_id` (si HubWorlds.can_enter): Isak se va por el
## vortice de salida y despues se carga el nivel. Falso si no se puede o si ya
## se esta entrando a otro.
func enter_level(level_id: StringName) -> bool:
	if not _entering_level.is_empty() or not HubWorlds.can_enter(level_id):
		return false
	_entering_level = level_id
	if _isak == null or not is_instance_valid(_isak):
		_load_level()
		return true
	if not _isak.is_facing_back():
		_isak.face_back()
	_departure = WarpVortex.depart(_isak, self)
	_departure.finished.connect(_load_level)
	return true


func _on_folder_level_chosen(_station: FolderStation, level_id: StringName) -> void:
	enter_level(level_id)


## Carga level_runner_scene con el subnivel elegido y sustituye al hub. El hub
## sale del arbol ANTES de que entre el nivel: asi restaura sus habilidades
## (_exit_tree) sin pisar las que aplica el nivel.
func _load_level() -> void:
	_swap_to_level.call_deferred()


func _swap_to_level() -> void:
	var id: StringName = _entering_level
	level_requested.emit(id)
	if level_handler.is_valid():
		level_handler.call(id)
		return
	var path: String = String(HubData.section("folders").get("level_runner_scene", "res://scenes/main.tscn"))
	var runner := (load(path) as PackedScene).instantiate()
	if runner is LevelRunner:
		(runner as LevelRunner).start_level_id = String(id)
	var tree: SceneTree = get_tree()
	if get_parent() != null:
		get_parent().remove_child(self)
	if scene_switcher.is_valid():
		scene_switcher.call(runner)
		return
	tree.root.add_child(runner)
	tree.current_scene = runner
	queue_free()


## Contorno o relleno PROVISIONAL de una pieza del fondo (ver _make_provisional_piece).
class _ProvisionalPiece:
	extends Node2D
	var piece: AnimatedSprite2D
	var color: Color = Color("#ff7f66")
	var polygon: PackedVector2Array = PackedVector2Array()

	func _draw() -> void:
		if piece == null or polygon.size() < 3:
			return
		var closed: PackedVector2Array = polygon.duplicate()
		closed.append(polygon[0])
		match piece.animation:
			&"on":
				draw_colored_polygon(polygon, Color(color, 0.45))
				draw_polyline(closed, color, 4.0)
			&"off":
				draw_polyline(closed, Color(color, 1.0 if piece.frame == 0 else 0.35), 4.0)
