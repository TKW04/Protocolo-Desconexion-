# Cargador de energia del hub (2026-10-16; seccion charger de data/hub.json):
# el mismo objeto charger de los niveles (Charger, scenes/levels/charger.tscn)
# en la columna 16 del dock, con las reglas del catalogo (50 de energia,
# reutilizable, 20 s de enfriamiento) y la misma interaccion (tocarlo). No se
# guarda ni marca «sin guardar», se reinicia en cada visita, no solapa las
# zonas de las estaciones y funciona con la papelera llena. Usa su propia ruta
# de guardado.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_charger.json"
const T: float = 64.0
const COL: int = 16
const HUB_FRAMES: String = "res://assets/sprites/hub/charger_frames.tres"
## Media anchura de Isak de sobra (su cuerpo es mas estrecho que un tile).
const ISAK_HALF_W: float = 32.0

var _hub: HubRoom
var _saved_path: String
var _saved_pulse: bool
var _saved_debug: bool
var _saved_laser: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	_saved_laser = GameState.is_ability_unlocked(GameState.ABILITY_LASER)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	get_tree().paused = false
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved_laser)


func _spawn() -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	_hub.get_isak().input = PlayerInput.new()
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	return _hub


## Zona de contacto del cargador en coordenadas globales.
func _contact_rect(charger: Charger) -> Rect2:
	for child: Node in charger.get_children():
		var shape := child as CollisionShape2D
		if shape != null and shape.shape is RectangleShape2D:
			var size: Vector2 = (shape.shape as RectangleShape2D).size
			return Rect2(charger.global_position + shape.position - size * 0.5, size)
	return Rect2()


## Zona en la que Isak toca el cargador: la de contacto ensanchada por Isak.
func _touch_span(charger: Charger) -> Rect2:
	return _contact_rect(charger).grow_individual(ISAK_HALF_W, 0.0, ISAK_HALF_W, 0.0)


func _x_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x


func test_hub_has_the_level_charger_in_column_16_of_the_dock() -> void:
	_spawn()
	var charger: Charger = _hub.get_charger()
	assert_not_null(charger, "Hay un cargador en el hub")
	assert_eq(charger.scene_file_path, "res://scenes/levels/charger.tscn", "El mismo objeto de los niveles")
	assert_eq(charger.get_charger_id(), &"cargador_hub")
	assert_eq(charger.position, Vector2(COL * T, _hub.get_floor_y() - T), "Celda de la columna 16 sobre el dock")
	var contact: Rect2 = _contact_rect(charger)
	assert_almost_eq(contact.end.y, _hub.get_floor_y(), 0.5, "Apoyado en el dock")
	assert_almost_eq(contact.get_center().x, (COL + 0.5) * T, 0.5, "Centrado en la columna")
	assert_eq(charger.amount, 50.0, "Reglas del catalogo: 50 de energia")
	assert_true(charger.reusable, "Reutilizable")
	assert_eq(charger.cooldown_s, 20.0, "20 s de enfriamiento")
	assert_eq(charger.get_level_id(), GameState.NO_LEVEL, "No pertenece a ningun nivel")
	var sprite := charger.get_node(^"Sprite") as EnergySprite
	assert_eq(sprite.sprite_frames.resource_path, HUB_FRAMES, "Variante con la paleta del hub")
	assert_eq(sprite.animation, &"charger_ready", "Listo al entrar")


func test_charger_does_not_overlap_stations_slots_folders_or_the_arrival() -> void:
	_spawn()
	var span: Rect2 = _touch_span(_hub.get_charger())
	for id: StringName in _hub.get_station_ids():
		var station: HubStation = _hub.get_station(id)
		var zone: Rect2 = station.get_prompt_zone()
		zone.position += station.global_position
		assert_false(_x_overlap(span, zone), "Fuera de la zona de %s" % id)
	var papelera: Papelera = _hub.get_papelera()
	var r: float = papelera.get_recover_radius()
	var trash := Rect2(papelera.get_center().x - r, 0.0, 2.0 * r, 1.0)
	assert_false(_x_overlap(span, trash), "Fuera del radio de la papelera")
	for id: StringName in _hub.get_dormant_ids():
		var slot: Node2D = _hub.get_dormant(id)
		var slot_rect := Rect2(slot.global_position.x, 0.0, T, 1.0)
		assert_false(_x_overlap(span, slot_rect), "No pisa el hueco de %s" % id)
	var spawn_x: float = _hub.get_spawn_position().x
	assert_false(span.has_point(Vector2(spawn_x, span.get_center().y)), "Lejos de la llegada P")
	# Carpetas y repisas: por encima, sin tocarse (su zona es de pie en la repisa).
	var contact: Rect2 = _contact_rect(_hub.get_charger())
	assert_lt(_hub.get_shelf_top_y() + 12.0, contact.position.y, "La repisa queda por encima")
	for id: StringName in _hub.get_folder_ids():
		var folder: FolderStation = _hub.get_folder(id)
		var zone: Rect2 = folder.get_prompt_zone()
		zone.position += folder.global_position
		assert_false(zone.intersects(contact), "Fuera de la zona de la carpeta %s" % id)


func test_recharges_50_up_to_the_max_and_cools_down_20_s() -> void:
	_spawn()
	var charger: Charger = _hub.get_charger()
	var isak: Isak = _hub.get_isak()
	var max_e: float = GameState.get_debug_energy_max()
	GameState.add_empty_power_bank()
	GameState.debug_energy = 20.0
	assert_eq(charger.try_use(isak), 50.0, "+50")
	assert_eq(GameState.debug_energy, 70.0)
	assert_false(charger.is_ready(), "Enfriandose")
	assert_eq(charger.get_cooldown_left(), 20.0)
	assert_eq(charger.try_use(isak), 0.0, "No repone mientras se enfria")
	charger.advance(19.9)
	assert_false(charger.is_ready())
	charger.advance(0.2)
	assert_true(charger.is_ready(), "Listo a los 20 s")
	GameState.debug_energy = max_e - 20.0
	assert_eq(charger.try_use(isak), 20.0, "Hasta el maximo, sin desbordar")
	assert_eq(GameState.debug_energy, max_e)
	assert_eq(GameState.power_bank_charge, 0.0, "Sin desborde a los power banks")
	charger.advance(20.0)
	assert_eq(charger.try_use(isak), 0.0, "Con la barra llena no se gasta")
	assert_true(charger.is_ready())


func test_isak_touching_it_recharges_like_in_the_levels() -> void:
	_spawn()
	var charger: Charger = _hub.get_charger()
	var isak: Isak = _hub.get_isak()
	await wait_physics_frames(4)
	GameState.debug_energy = 10.0
	isak.global_position = Vector2(_contact_rect(charger).get_center().x, _hub.get_floor_y())
	isak.velocity = Vector2.ZERO
	await wait_physics_frames(6)
	assert_eq(GameState.debug_energy, 60.0, "Al tocarlo repone 50")
	assert_false(charger.is_ready())
	var sprite := charger.get_node(^"Sprite") as EnergySprite
	assert_eq(sprite.animation, &"charger_cooling", "Arte de enfriamiento")


func test_using_it_does_not_save_or_mark_unsaved() -> void:
	_spawn()
	assert_true(GameState.save_game(), "Copia limpia")
	var before: Dictionary = SaveFile.read(PATH)
	assert_false(GameState.has_unsaved_changes())
	GameState.debug_energy = 0.0
	assert_eq(_hub.get_charger().try_use(_hub.get_isak()), 50.0)
	assert_false(GameState.has_unsaved_changes(), "No marca «sin guardar»")
	assert_eq(SaveFile.read(PATH), before, "No escribe el guardado")
	assert_false(GameState.is_pickup_collected(GameState.NO_LEVEL, &"cargador_hub"), "No se registra como recogido")
	assert_false(GameState.is_help_learned(&"charger"), "No cuenta como tipo aprendido")


func test_resets_when_entering_the_hub_again_and_energy_is_full_on_enter() -> void:
	_spawn()
	GameState.debug_energy = 0.0
	assert_eq(_hub.get_charger().try_use(_hub.get_isak()), 50.0)
	assert_false(_hub.get_charger().is_ready())
	_hub.free()
	GameState.debug_energy = 5.0
	_spawn()
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "La energia sigue llenandose al entrar")
	var charger: Charger = _hub.get_charger()
	assert_true(charger.is_ready(), "Nuevo en cada visita: sin enfriamiento")
	assert_eq(charger.get_cooldown_left(), 0.0)


func test_works_while_the_trash_has_content() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.attention_points = 9
	GameState.mark_level_completed(&"1-1")
	assert_true(GameState.save_game())
	GameState.apply_rollback()
	assert_true(GameState.has_trash_pending(), "Papelera con contenido")
	_spawn()
	var unsaved: bool = GameState.has_unsaved_changes()
	GameState.debug_energy = 10.0
	assert_eq(_hub.get_charger().try_use(_hub.get_isak()), 50.0, "Es energia, no una cosa guardada")
	assert_eq(GameState.debug_energy, 60.0)
	assert_true(GameState.has_trash_pending(), "La papelera no cambia")
	assert_eq(GameState.has_unsaved_changes(), unsaved, "Ni el estado de «sin guardar»")
