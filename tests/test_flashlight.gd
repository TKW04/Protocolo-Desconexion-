# Linterna y Modo oscuro (paso 4 del plan de docs/propuesta-mundo-4.md §8, §3.6):
# la Linterna se recoge al tocarla y queda conocida (aliada de registro: sin «sin
# guardar» y un game over no la quita), no aparece si ya se conoce; la lucecita sigue
# a Isak y solo se enciende en una zona oscura; la zona abre un circulo de luz de 3
# tiles alrededor de Isak solo con la Linterna; lo escrito en tinta (texto y paso) solo
# existe bajo la luz; por encima del velo siempre se ven el contorno de lo que dana,
# los checks del «Visto», el borde de las burbujas y los puntos del «escribiendo…»;
# el hueco del hub se enciende al conocerla; la sala oscuro_test carga.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/flashlight_pickup.tscn")
const DARK_SCENE: PackedScene = preload("res://scenes/levels/dark_zone.tscn")
const INK_SCENE: PackedScene = preload("res://scenes/levels/ink_only.tscn")
const ZONE_SCENE: PackedScene = preload("res://scenes/levels/seen_zone.tscn")
const CHAT_SCENE: PackedScene = preload("res://scenes/levels/chat_bubble.tscn")
const TYPING_SCENE: PackedScene = preload("res://scenes/levels/typing_bubble.tscn")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_flashlight_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const TILE: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _hub: HubRoom


func before_each() -> void:
	_saved_path = GameState.save_path
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
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


## Zona oscura de w x h tiles con su esquina en (col, fila) (Isak en x ~ 0, pies en y = 0).
func _dark(col: float, row: float, w: int, h: int) -> DarkZone:
	var zone := DARK_SCENE.instantiate() as DarkZone
	zone.position = Vector2(col * TILE, row * TILE)
	zone.width_tiles = w
	zone.height_tiles = h
	zone.auto_process = false
	zone.isak = _isak
	_world.add_child(zone)
	return zone


func _ink(col: float, row: float, kind: String, value: String = "") -> InkOnly:
	var ink := INK_SCENE.instantiate() as InkOnly
	ink.position = Vector2(col * TILE, row * TILE)
	ink.kind = kind
	ink.text = value
	ink.auto_process = false
	_world.add_child(ink)
	return ink


# --- Recoger la Linterna ---

func test_pickup_on_touch_meets_ally_without_unsaved_changes() -> void:
	var pickup := PICKUP_SCENE.instantiate() as FlashlightPickup
	pickup.position = Vector2(3.0 * TILE, -TILE)
	pickup.isak = _isak
	_world.add_child(pickup)
	pickup.set_physics_process(false)
	assert_false(pickup.is_taken())
	assert_true(pickup.is_help_available())
	assert_false(pickup.check_pickup(), "Lejos no se recoge")
	var unsaved: bool = GameState.has_unsaved_changes()
	_isak.global_position.x = 3.5 * TILE
	assert_true(pickup.check_pickup(), "Al tocarla se recoge")
	assert_true(GameState.has_met_ally(GameState.ALLY_LINTERNA), "Linterna conocida")
	assert_eq(GameState.has_unsaved_changes(), unsaved, "Aliada de registro: no marca «sin guardar»")
	assert_false(pickup.visible)
	assert_false(pickup.is_help_available(), "Lo recogido no ayuda")
	assert_false(pickup.check_pickup(), "Una sola vez")


func test_pickup_absent_when_already_known() -> void:
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	var pickup := PICKUP_SCENE.instantiate() as FlashlightPickup
	_world.add_child(pickup)
	assert_true(pickup.is_taken(), "Con la Linterna conocida no aparece")
	assert_false(pickup.visible)


func test_game_over_keeps_the_flashlight() -> void:
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.has_met_ally(GameState.ALLY_LINTERNA), "Un game over no la quita")


# --- Zona oscura y luz ---

func test_dark_zone_opens_light_only_with_flashlight() -> void:
	var zone := _dark(-2.0, -4.0, 6, 5)
	zone.refresh()
	assert_true(zone.is_isak_inside())
	assert_false(zone.is_hole_open(), "Sin Linterna, a oscuras")
	assert_almost_eq(zone.get_veil_alpha(), 0.75, EPS, "chat_noche al 75 %")
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	zone.refresh()
	assert_true(zone.is_hole_open(), "Con la Linterna, circulo de luz")
	assert_almost_eq(zone.get_light_radius(), 3.0 * TILE, EPS, "3 tiles de radio")
	var center: Vector2 = zone.get_light_center()
	assert_true(zone.is_lit_at(center + Vector2(2.9 * TILE, 0.0)))
	assert_false(zone.is_lit_at(center + Vector2(3.2 * TILE, 0.0)), "Fuera del radio, oscuro")
	assert_true(DarkZone.lit_by_flashlight(get_tree(), center))
	_isak.global_position.x = 10.0 * TILE
	zone.refresh()
	assert_false(zone.is_isak_inside())
	assert_false(zone.is_hole_open(), "Isak fuera: sin circulo")
	assert_null(DarkZone.covering(get_tree(), _isak.global_position + Vector2(0.0, -40.0)))


func test_companion_follows_and_lights_only_in_dark() -> void:
	var light := FlashlightCompanion.attach(_isak, _world)
	light.auto_advance = false
	light.advance(DT)
	assert_false(light.visible, "Sin conocerla no se ve")
	assert_false(light.is_on())
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	assert_true(light.visible, "Aparece al conocerla (ally_met)")
	light.advance(DT)
	assert_false(light.is_on(), "Fuera de lo oscuro, apagada")
	assert_lt(light.global_position.y, _isak.global_position.y, "A la altura de la mano")
	assert_almost_eq(light.global_position.x, _isak.global_position.x - 22.0 * _isak.facing, 0.5, "Detras, bajo Eco")
	var zone := _dark(-2.0, -4.0, 6, 5)
	zone.refresh()
	light.advance(DT)
	assert_true(light.is_on(), "En una zona oscura se enciende")


# --- En tinta ---

func test_ink_decor_and_step_exist_only_under_light() -> void:
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	var zone := _dark(-6.0, -6.0, 20, 7)
	var near := _ink(1.0, -2.0, "decor", "por aquí")
	var far := _ink(8.0, -2.0, "decor", "lejos")
	var step := _ink(1.0, -2.0, "step")
	assert_eq(near.z_index, DarkZone.veil_z() + 1, "Por encima del velo")
	zone.refresh()
	for ink: InkOnly in [near, far, step]:
		ink.refresh(0.0)
	assert_true(near.is_lit(), "Bajo la luz: se ve")
	assert_false(far.is_lit(), "Fuera del circulo: no existe")
	assert_true(step.is_solid(), "El paso solo es solido bajo la luz")
	_isak.global_position.x = 12.0 * TILE
	zone.refresh()
	near.refresh(0.0)
	step.refresh(0.0)
	assert_false(near.is_lit())
	assert_false(step.is_solid(), "Lejos de la luz, el paso no esta")


func test_ink_without_flashlight_never_shows() -> void:
	var zone := _dark(-6.0, -6.0, 20, 7)
	var ink := _ink(1.0, -2.0, "decor", "por aquí")
	zone.refresh()
	ink.refresh(0.0)
	assert_false(ink.is_lit(), "Sin Linterna no hay tinta")


# --- Legibilidad por encima del velo ---

func test_always_visible_above_veil() -> void:
	var zone := _dark(-6.0, -6.0, 20, 7)
	var seen := ZONE_SCENE.instantiate() as SeenZone
	seen.position = Vector2(4.0 * TILE, -2.0 * TILE)
	seen.auto_process = false
	_world.add_child(seen)
	var chat := CHAT_SCENE.instantiate() as ChatBubble
	chat.position = Vector2(6.0 * TILE, -3.0 * TILE)
	chat.text = "¿Sigues ahí?"
	chat.width_tiles = 2
	_world.add_child(chat)
	var typing := TYPING_SCENE.instantiate() as TypingBubble
	typing.position = Vector2(9.0 * TILE, -3.0 * TILE)
	typing.text = "aquí"
	typing.auto_process = false
	_world.add_child(typing)
	var outside := CHAT_SCENE.instantiate() as ChatBubble
	outside.position = Vector2(30.0 * TILE, -3.0 * TILE)
	outside.text = "fuera"
	_world.add_child(outside)
	var spikes := SpikeHazard.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64.0, 24.0)
	shape.shape = rect
	spikes.add_child(shape)
	spikes.position = Vector2(2.0 * TILE, -12.0)
	_world.add_child(spikes)
	await wait_process_frames(2)
	assert_eq(seen.z_index, DarkZone.veil_z() + 1, "Los checks del «Visto» por encima del velo")
	assert_false(seen.z_as_relative)
	assert_true(chat.is_in_dark(), "Borde de la burbuja por encima del velo")
	assert_true(typing.is_in_dark(), "Los puntos del «escribiendo…» tambien")
	assert_false(outside.is_in_dark(), "Fuera de la zona, nada")
	assert_eq(zone.get_hazard_rects().size(), 1, "Contorno de lo que dana dentro")
	assert_almost_eq(float(World4ObjectsConfig.section("chat_bubble")["dark_border_alpha"]), 0.3, EPS, "Borde al 30 %")
	# Paso 22 (capturas): el contorno en alerta_sombra quedaba a ~1,6:1 sobre el velo;
	# en alerta, >= 3:1 sobre el fondo mas claro del Mundo 4 tapado por el velo.
	var outline: Color = zone.get_hazard_outline_color()
	assert_eq(outline, World4ObjectsConfig.color("alerta"), "Contorno en alerta")
	var veil: Color = World4ObjectsConfig.color("fondo_claro", Color("#4a6fc4")).lerp(
		World4ObjectsConfig.color("chat_noche"), float(World4ObjectsConfig.section("dark_zone").get("veil_alpha", 0.6)))
	assert_gt(_contrast(outline, veil), 3.0, "Contraste del contorno sobre el velo")


## Arreglo de las capturas del paso 22 (2026-10-28): bajo el velo el texto de una burbuja solo se ve bajo la luz.
func test_bubble_text_only_under_light() -> void:
	var zone := _dark(-6.0, -6.0, 20, 7)
	var near := CHAT_SCENE.instantiate() as ChatBubble
	near.position = Vector2(-1.0 * TILE, -2.0 * TILE)
	near.text = "hola"
	near.width_tiles = 2
	_world.add_child(near)
	var far := CHAT_SCENE.instantiate() as ChatBubble
	far.position = Vector2(9.0 * TILE, -2.0 * TILE)
	far.text = "lejos"
	far.width_tiles = 2
	_world.add_child(far)
	var outside := CHAT_SCENE.instantiate() as ChatBubble
	outside.position = Vector2(30.0 * TILE, -2.0 * TILE)
	outside.text = "fuera"
	_world.add_child(outside)
	await wait_process_frames(2)
	zone.refresh()
	assert_eq(near.count_visible_text_chars(), 0, "Sin Linterna no se lee nada bajo el velo")
	assert_eq(outside.count_visible_text_chars(), 5, "Fuera de la zona, todo el texto")
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	zone.refresh()
	assert_eq(near.count_visible_text_chars(), 4, "Bajo la luz, el texto entero")
	assert_eq(far.count_visible_text_chars(), 0, "Fuera del circulo, sin texto")


func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# --- Hub ---

func test_hub_slot_lights_when_known() -> void:
	EcoProgress.meet_notas()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var slot: Node2D = _hub.get_dormant(&"linterna")
	assert_not_null(slot)
	assert_false(bool(slot.get_meta(&"lit", true)), "Apagado sin conocerla")
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	assert_true(bool(slot.get_meta(&"lit", false)), "Se enciende al conocerla")
	_hub.free()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_true(bool(_hub.get_dormant(&"linterna").get_meta(&"lit", false)), "Y sigue encendido en la visita siguiente")


# --- Sala de prueba ---

func test_oscuro_test_room_loads() -> void:
	var scene := load("res://scenes/levels/oscuro_test.tscn") as PackedScene
	assert_not_null(scene, "Sala oscuro_test generada")
	var level := scene.instantiate()
	add_child_autofree(level)
	assert_eq(get_tree().get_nodes_in_group(DarkZone.GROUP).size(), 1)
	assert_eq(get_tree().get_nodes_in_group(FlashlightPickup.GROUP).size(), 1)
	assert_eq(get_tree().get_nodes_in_group(InkOnly.GROUP).size(), 2)
	var step := level.get_node(^"Objects/tinta_paso") as InkOnly
	assert_eq(step.kind, "step")
