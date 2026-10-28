# Burbujas del Mundo 4 (chat_bubble, typing_bubble, autocorrect_bubble; paso 3 del plan
# de docs/propuesta-mundo-4.md §8, §3.1 y §3.4): largo por el texto (1 tile por cada 6
# caracteres, 1-8), de una via, pisada que avisa, eliminada sin colision, avatar de
# amigo; «escribiendo…» que se dispara al pisar otra burbuja o al entrar en su zona,
# tres puntos (uno cada 0,33 s) y solida a 1,0 s, que no se materializa con Isak dentro,
# con ciclo (solida, aviso de 9 cuadros, eliminada, otra vez) y en tiempo del mundo;
# autocorrector con cursor de 0,75 s al acercarse a <= 3 tiles que cambia el largo y el
# sitio en su ranura, una vez por intento; todo vuelve a su estado inicial al reaparecer;
# la sala burbujas_test carga. Isak avanza con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const CHAT_SCENE: PackedScene = preload("res://scenes/levels/chat_bubble.tscn")
const TYPING_SCENE: PackedScene = preload("res://scenes/levels/typing_bubble.tscn")
const AUTOCORRECT_SCENE: PackedScene = preload("res://scenes/levels/autocorrect_bubble.tscn")
const PATH: String = "user://test_chat_bubbles_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const TILE: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved_debug: bool = false


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _setup(bubble: ChatBubble, col: float, row: float, value: String) -> void:
	bubble.position = Vector2(col * TILE, row * TILE)
	bubble.text = value
	bubble.width_tiles = ChatBubble.width_for_text(value)


func _chat(col: float, row: float, value: String) -> ChatBubble:
	var bubble := CHAT_SCENE.instantiate() as ChatBubble
	_setup(bubble, col, row, value)
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	return bubble


func _typing(col: float, row: float, value: String) -> TypingBubble:
	var bubble := TYPING_SCENE.instantiate() as TypingBubble
	_setup(bubble, col, row, value)
	bubble.auto_process = false
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	return bubble


func _autocorrect(col: float, row: float, before: String, after: String) -> AutocorrectBubble:
	var bubble := AUTOCORRECT_SCENE.instantiate() as AutocorrectBubble
	_setup(bubble, col, row, before)
	bubble.corrected = after
	bubble.corrected_width_tiles = ChatBubble.width_for_text(after)
	bubble.auto_process = false
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	return bubble


## Pone a Isak de pie sobre `bubble` (cae desde 4 px encima) y avanza hasta apoyarse.
func _stand_on(bubble: ChatBubble) -> void:
	var r: Rect2 = bubble.get_card_rect()
	_isak.global_position = Vector2(r.get_center().x, r.position.y - 4.0)
	_isak.velocity = Vector2.ZERO
	_sim.step(8)
	bubble._update_stepping()


# --- Largo y datos ---

func test_width_rule_and_config() -> void:
	assert_eq(ChatBubble.width_for_text(""), 1, "Minimo 1")
	assert_eq(ChatBubble.width_for_text("hola"), 1)
	assert_eq(ChatBubble.width_for_text("123456"), 1, "6 caracteres = 1 tile")
	assert_eq(ChatBubble.width_for_text("1234567"), 2, "Redondeo hacia arriba")
	assert_eq(ChatBubble.width_for_text("¿Sigues despierto?"), 3)
	assert_eq(ChatBubble.width_for_text("x".repeat(60)), 8, "Maximo 8")
	var cfg: Dictionary = World4ObjectsConfig.section("chat_bubble")
	assert_eq(int(cfg["chars_per_tile"]), ChatBubble.CHARS_PER_TILE, "La misma regla que tools/build_level.py")
	assert_almost_eq(float(cfg["type_s"]), 1.0, EPS, "Escribiendo 1,0 s")
	assert_almost_eq(float(cfg["dot_s"]), 0.33, EPS)
	var bubble := _chat(3.0, -3.0, "¿Sigues despierto?")
	assert_almost_eq(bubble.get_card_size().x, 3.0 * TILE, EPS, "El largo del mensaje es el de la plataforma")


# --- Burbuja fija ---

func test_chat_bubble_is_one_way_and_reports_stepping() -> void:
	var bubble := _chat(2.0, -3.0, "¿Sigues despierto?")
	assert_true(bubble.is_solid())
	var shape := bubble.get_node(^"Shape") as CollisionShape2D
	assert_true(shape.one_way_collision, "De una via")
	var steps: Array = []
	bubble.stepped.connect(func() -> void: steps.append(true))
	_stand_on(bubble)
	assert_true(_isak.is_on_floor(), "Se puede pisar")
	assert_almost_eq(_isak.global_position.y, -3.0 * TILE, 1.0, "Encima de la tarjeta")
	assert_true(bubble.is_stepped_on())
	assert_eq(steps.size(), 1, "Avisa al pisarla")
	bubble._update_stepping()
	assert_eq(steps.size(), 1, "Una vez por pisada")


func test_deleted_bubble_has_no_collision() -> void:
	var bubble := CHAT_SCENE.instantiate() as ChatBubble
	_setup(bubble, 2.0, -3.0, "nada, olvídalo")
	bubble.deleted = true
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	assert_false(bubble.is_solid(), "Se eliminó este mensaje: sin colision")
	assert_eq(bubble.get_shown_text(), ChatBubble.DELETED_TEXT)
	_stand_on(bubble)
	assert_false(bubble.is_stepped_on())
	assert_gt(_isak.global_position.y, -3.0 * TILE + 4.0, "Cae a traves")


## Paso 22 (capturas): en una tarjeta corta el aviso de eliminada salia cortado
## («Se eliminó este me»); si no cabe se dibuja «Eliminado» y, en 1 tile, nada.
func test_deleted_text_fits_its_card() -> void:
	var short := CHAT_SCENE.instantiate() as ChatBubble
	_setup(short, 2.0, -3.0, "Lía: ¿estás?")
	short.deleted = true
	_world.add_child(short)
	var width: float = short.get_card_size().x - 12.0
	assert_eq(short.fit_text(short.get_shown_text(), width), ChatBubble.DELETED_SHORT_TEXT, "2 tiles: no cabe")
	assert_eq(short.get_shown_text(), ChatBubble.DELETED_TEXT, "El texto de la burbuja no cambia")
	var wide := CHAT_SCENE.instantiate() as ChatBubble
	_setup(wide, 2.0, -6.0, ChatBubble.DELETED_TEXT)
	wide.deleted = true
	_world.add_child(wide)
	assert_eq(wide.fit_text(wide.get_shown_text(), wide.get_card_size().x - 12.0), ChatBubble.DELETED_TEXT,
		"4 tiles: cabe entero")
	assert_eq(short.fit_text(ChatBubble.DELETED_TEXT, 64.0 - 12.0), "", "1 tile: solo el contorno")
	assert_eq(short.fit_text("¿Sigues despierto?", 10.0), "¿Sigues despierto?", "Los demas textos no cambian")


func test_friend_initial() -> void:
	var bubble := CHAT_SCENE.instantiate() as ChatBubble
	_setup(bubble, 2.0, -3.0, "¿Mañana vienes?")
	bubble.friend_id = &"lia"
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	assert_eq(bubble.get_friend_initial(), "L", "Avatar con la inicial")
	assert_true(bubble.is_solid(), "La de amigo no se rompe")
	assert_true(bubble.is_help_available())


# --- «Escribiendo…» ---

func test_typing_triggered_by_stepping_another_bubble() -> void:
	var fixed := _chat(2.0, -3.0, "¿Sigues despierto?")
	fixed.object_id = &"fija"
	var typing := _typing(7.0, -3.0, "sí, aquí")
	typing.trigger_id = &"fija"
	assert_false(typing.is_solid(), "Aun no existe")
	assert_false(typing.is_triggered())
	typing.advance(DT)
	assert_false(typing.is_triggered(), "Sin pisar nada")
	_stand_on(fixed)
	typing.advance(DT)
	assert_true(typing.is_typing(), "Pisar la anterior la dispara")
	assert_eq(typing.get_dots(), 1, "Primer punto")
	typing.advance(0.33)
	assert_eq(typing.get_dots(), 2, "Segundo a los 0,33 s")
	typing.advance(0.33)
	assert_eq(typing.get_dots(), 3, "Tercero a los 0,67 s")
	assert_false(typing.is_solid())
	typing.advance(0.33)
	assert_false(typing.is_solid(), "A los 0,99 s aun no")
	typing.advance(0.02)
	assert_true(typing.is_solid(), "Solida al cumplirse 1,0 s")
	assert_eq(typing.get_dots(), 0)
	typing.advance(10.0)
	assert_true(typing.is_solid(), "Por defecto se queda")


func test_typing_does_not_materialize_with_isak_inside() -> void:
	var typing := _typing(0.0, -1.0, "sí, aquí")
	typing.trigger()
	_isak.global_position = Vector2(typing.get_card_rect().get_center().x, 0.0)
	_isak.velocity = Vector2.ZERO
	typing.advance(1.2)
	assert_false(typing.is_solid(), "Con Isak dentro no se materializa")
	assert_true(typing.is_typing())
	_isak.global_position.x += 4.0 * TILE
	typing.advance(DT)
	assert_true(typing.is_solid(), "Al salir, si")


func test_typing_triggered_by_zone() -> void:
	var typing := _typing(8.0, -3.0, "jaja")
	var col: int = floori(_isak.global_position.x / TILE)
	typing.trigger_zone = [col + 3, -2, 2, 2]
	typing.advance(DT)
	assert_false(typing.is_triggered(), "Isak fuera de la zona")
	_isak.global_position.x += 3.5 * TILE
	typing.advance(DT)
	assert_true(typing.is_typing(), "Entrar en la zona la dispara")


func test_typing_cycle() -> void:
	var typing := _typing(8.0, -3.0, "jaja")
	typing.cycle_s = 4.0
	typing.on_s = 2.0
	typing.trigger()
	typing.advance(1.0)
	assert_true(typing.is_solid())
	typing.advance(2.0)
	assert_true(typing.is_warning(), "Aviso de eliminarse tras on_s")
	assert_true(typing.is_solid(), "Aun solida durante el aviso")
	typing.advance(0.75)
	assert_eq(typing.get_phase(), TypingBubble.Phase.DELETED, "Se eliminó este mensaje")
	assert_false(typing.is_solid())
	assert_almost_eq(typing.get_deleted_s(), 4.0 - 2.0 - 0.75 - 1.0, EPS)
	typing.advance(0.26)
	assert_true(typing.is_typing(), "Vuelve a escribirse")
	typing.advance(1.0)
	assert_true(typing.is_solid(), "Solida otra vez a los cycle_s de aparecer")


func test_typing_counts_world_time() -> void:
	var typing := _typing(8.0, -3.0, "jaja")
	typing.auto_process = true
	typing.trigger()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	var scale: float = WorldTime.scale()
	assert_lt(scale, 1.0)
	for i: int in _sim.frames(1.0):
		typing._physics_process(DT)
	assert_false(typing.is_solid(), "El Debug alarga la espera")
	assert_almost_eq(typing.get_phase_time(), 1.0 * scale, 0.05)


func test_typing_resets_on_respawn() -> void:
	var typing := _typing(8.0, -3.0, "jaja")
	typing.trigger()
	typing.advance(1.2)
	assert_true(typing.is_solid())
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_false(typing.is_triggered(), "Vuelve a su estado inicial")
	assert_false(typing.is_solid())


# --- Autocorrector ---

func test_autocorrect_cursor_then_shorter() -> void:
	var bubble := _autocorrect(6.0, -3.0, "te echo de menos", "te echo")
	assert_eq(bubble.get_width_tiles(), 3, "Antes: 3 tiles")
	var cursor: Array = []
	bubble.cursor_started.connect(func() -> void: cursor.append(true))
	bubble.advance(DT)
	assert_eq(bubble.get_phase(), AutocorrectBubble.Phase.BEFORE, "Isak lejos (mas de 3 tiles)")
	_isak.global_position.x = bubble.global_position.x - 2.5 * TILE
	bubble.advance(DT)
	assert_eq(bubble.get_phase(), AutocorrectBubble.Phase.CURSOR, "A <= 3 tiles: el cursor parpadea")
	assert_eq(cursor.size(), 1)
	assert_almost_eq(bubble.get_cursor_s(), 0.75, EPS, "9 cuadros a 12 fps")
	bubble.advance(0.7)
	assert_eq(bubble.get_width_tiles(), 3, "Durante el cursor, el texto de antes")
	bubble.advance(0.06)
	assert_true(bubble.is_corrected())
	assert_eq(bubble.get_shown_text(), "te echo")
	assert_eq(bubble.get_width_tiles(), 2, "Cambia de largo")
	var shape := bubble.get_node(^"Shape") as CollisionShape2D
	assert_almost_eq((shape.shape as RectangleShape2D).size.x, 2.0 * TILE, EPS, "La colision tambien")
	assert_almost_eq(bubble.get_card_rect().position.x, bubble.global_position.x, EPS, "Anclada a la izquierda")


func test_autocorrect_anchor_right_moves_in_slot() -> void:
	var bubble := _autocorrect(6.0, -3.0, "te echo de menos", "te echo")
	bubble.anchor_side = &"right"
	bubble.reset()
	assert_eq(bubble.get_slot_tiles(), 3)
	bubble.start_cursor()
	bubble.advance(0.8)
	assert_almost_eq(bubble.get_card_rect().position.x, bubble.global_position.x + TILE, EPS,
		"Pegada a la derecha de su ranura: cambia de sitio")


func test_autocorrect_triggered_by_stepping_and_once_per_attempt() -> void:
	var bubble := _autocorrect(2.0, -3.0, "te echo de menos", "te echo")
	bubble.trigger_tiles = 1.0
	_stand_on(bubble)
	bubble.advance(DT)
	assert_eq(bubble.get_phase(), AutocorrectBubble.Phase.CURSOR, "Pisarla la dispara")
	bubble.advance(0.8)
	assert_true(bubble.is_corrected())
	bubble.advance(5.0)
	assert_true(bubble.is_corrected(), "Una sola vez por intento")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(bubble.get_phase(), AutocorrectBubble.Phase.BEFORE, "Vuelve al reaparecer")
	assert_eq(bubble.get_width_tiles(), 3)


# --- Sala de prueba ---

func test_burbujas_test_room_loads() -> void:
	var scene := load("res://scenes/levels/burbujas_test.tscn") as PackedScene
	assert_not_null(scene, "Sala burbujas_test generada")
	var level := scene.instantiate()
	add_child_autofree(level)
	assert_eq(get_tree().get_nodes_in_group(ChatBubble.GROUP).size(), 6, "Seis burbujas")
	var typing := level.get_node(^"Objects/escribiendo_1") as TypingBubble
	assert_eq(typing.trigger_id, &"burbuja_fija")
	assert_eq(typing.width_tiles, 2, "«sí, aquí»: 8 caracteres = 2 tiles")
	var cycle := level.get_node(^"Objects/escribiendo_ciclo") as TypingBubble
	assert_eq(cycle.trigger_zone, [22, 6, 2, 4])
	var auto := level.get_node(^"Objects/autocorrector_1") as AutocorrectBubble
	assert_eq(auto.corrected_width_tiles, 2)
	assert_eq(auto.author_side, &"left")
	var lia := level.get_node(^"Objects/burbuja_lia") as ChatBubble
	assert_eq(lia.friend_id, &"lia")


## Paso 22 (capturas): el sello «3 meses» salia cortado; ahora se coloca por su ancho.
func test_long_stamp_fits_inside_the_card() -> void:
	var bubble := _chat(2.0, -3.0, "Ok, cuando quieras hablar, aquí estoy.")
	bubble.stamp = "3 meses"
	var short := _chat(2.0, -6.0, "¿Sigues por ahí?")
	short.stamp = "22:40"
	assert_gt(bubble.stamp_width(), 34.0, "«3 meses» no cabia en el hueco fijo de 34 px")
	assert_lt(bubble.stamp_width() + 6.0, bubble.get_card_size().x, "Cabe dentro de la tarjeta")
	assert_gt(short.stamp_width(), 0.0)
