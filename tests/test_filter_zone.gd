# Filtros del Mundo 3 (filter_zone; 2026-10-26, paso 3 de docs/propuesta-mundo-3.md
# §8, §3.2 y decision 5 de §9: el filtro engana, no mata) en la sala generada
# scenes/levels/filtro_test.tscn con el Isak real: sin Debug los peligros ocultos
# no se ven (capa rosada encima, pinchos fuera de Tiles), con el Debug si (capa al
# 10 %, pinchos en rojo, suelo falso desvanecido); el pincho oculto quita 10 y
# empuja hacia la entrada; el suelo falso no tiene colision (Isak cae al foso de
# 2 tiles); el filtro movil se desliza ida y vuelta con aviso de 9 cuadros en la
# cinta y no mueve los peligros; la vineta tiembla a <= 3 tiles de un peligro oculto.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/filtro_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _fixed: FilterZone
var _moving: FilterZone


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.debug_energy = GameState.get_debug_energy_max()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_fixed = _level.get_node(^"Objects/filtro_orejitas") as FilterZone
	_moving = _level.get_node(^"Objects/filtro_movil") as FilterZone
	_fixed.set_physics_process(false)
	_moving.set_physics_process(false)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()


func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


func _full_debug() -> void:
	DebugMode.step(DT, true)
	for i: int in 180:
		DebugMode.step(DT, true)
		if DebugMode.get_intensity() >= 1.0:
			break
	assert_true(DebugMode.is_active(), "El Debug se enciende en la sala")


func _main_tiles() -> TileMapLayer:
	return _level.get_node(^"Tiles") as TileMapLayer


func test_without_debug_hazards_are_hidden_and_with_debug_they_show() -> void:
	assert_not_null(_fixed)
	_fixed.advance(0.0)
	assert_eq(_fixed.get_label_text(), "Filtro: Orejitas · Brillo +40", "Cartel por instancia")
	var spikes: Array[Vector2i] = _fixed.get_hidden_spike_cells()
	assert_eq(spikes.size(), 1, "El pincho del filtro fijo es hidden_by_filter")
	for cell: Vector2i in spikes:
		assert_eq(_main_tiles().get_cell_source_id(cell), -1, "El pincho oculto no se dibuja en Tiles")
		assert_true(_fixed.covers_cell(cell), "La capa lo tapa")
		assert_false(_fixed.is_cell_revealed(cell), "Sin Debug no se ve")
	assert_false(_fixed.get_hidden_spikes().visible, "La capa de datos de los pinchos no se dibuja sola")
	assert_almost_eq(_fixed.get_layer_alpha(), 0.6, 0.001, "Capa rosada sin Debug")
	assert_eq(_fixed.get_spike_tint(), Color.WHITE)
	assert_almost_eq(_fixed.get_fake_floor_alpha(), 1.0, 0.001, "El suelo falso parece suelo")
	assert_true(_fixed.get_cover().visible)
	_full_debug()
	_fixed.advance(0.0)
	assert_almost_eq(_fixed.get_layer_alpha(), 0.1, 0.001, "Con el Debug la capa baja al 10 %")
	for cell: Vector2i in spikes:
		assert_true(_fixed.is_cell_revealed(cell), "Con el Debug se ve el pincho")
	var red: Color = World3ObjectsConfig.color("alerta")
	assert_true(_fixed.get_spike_tint().is_equal_approx(red), "Pinchos en rojo con el Debug")
	assert_almost_eq(_fixed.get_fake_floor_alpha(), 0.3, 0.001, "Suelo falso desvanecido (contorno discontinuo)")
	DebugMode.reset()
	_fixed.advance(0.0)
	assert_false(_fixed.is_cell_revealed(spikes[0]), "Sin Debug vuelve a esconderlos")


func test_hidden_spike_takes_ten_and_pushes_to_the_entry() -> void:
	var hazard := _level.get_node(^"Hazards/Spikes_11_9") as SpikeHazard
	assert_not_null(hazard)
	assert_true(hazard.hidden_by_filter)
	assert_almost_eq(hazard.damage, 10.0, 0.001)
	await _stand(10, 9)
	# Mira a la izquierda (como si volviera): el empuje sigue yendo a la entrada (izquierda).
	_isak.facing = -1.0
	var before: float = GameState.sync_rate
	assert_true(hazard.hit(_isak), "El pincho oculto golpea")
	assert_almost_eq(GameState.sync_rate, before - 10.0, 0.001, "Quita 10")
	_sim.step(1)
	assert_lt(_isak.velocity.x, 0.0, "Empuja hacia la entrada del filtro (izquierda)")
	assert_false(_isak.is_dead(), "El filtro engana, no mata")


func test_fake_floor_has_no_collision() -> void:
	var cover: TileMapLayer = _fixed.get_cover()
	assert_false(cover.collision_enabled, "Suelo falso sin colision")
	assert_ne(cover.get_cell_source_id(Vector2i(16, 10)), -1, "Se dibuja terreno donde hay foso")
	assert_eq(_main_tiles().get_cell_source_id(Vector2i(16, 10)), -1, "El grid real tiene el foso")
	_isak.global_position = Vector2(17.0 * TILE, 10.0 * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	assert_true(_isak.is_on_floor())
	assert_almost_eq(_isak.global_position.y, 12.0 * TILE, 1.0, "Cae al fondo del foso (2 tiles)")


func test_moving_filter_slides_with_warning_and_hazards_stay() -> void:
	assert_true(_moving.is_moving_filter())
	assert_eq(_moving.get_position_count(), 3)
	var hazard := _level.get_node(^"Hazards/Spikes_33_9") as Area2D
	var hazard_pos: Vector2 = hazard.global_position
	var spike := Vector2i(33, 9)
	var start: Rect2 = _moving.get_current_rect()
	assert_eq(start.position, Vector2(27, 5) * TILE)
	assert_false(_moving.covers_cell(spike), "En el primer sitio el pincho 33 queda al descubierto")
	assert_true(_moving.is_cell_revealed(spike))
	watch_signals(_moving)
	var warn_s: float = _moving.get_warn_s()
	assert_almost_eq(warn_s, 9.0 / 12.0, 0.001, "Aviso de 9 cuadros a 12 fps")
	# Hasta justo antes del aviso: quieto y sin parpadeo.
	var hold: float = 4.0 - 0.5
	_moving.advance(hold - warn_s - 0.05)
	assert_false(_moving.is_warning())
	assert_eq(_moving.get_current_rect(), start)
	_moving.advance(0.1)
	assert_true(_moving.is_warning(), "Avisa antes de moverse")
	assert_signal_emitted(_moving, "slide_warning_started")
	assert_true(_moving.is_tape_blink_on(), "La cinta del borde parpadea (primer cuadro encendido)")
	_moving.advance(1.0 / 12.0)
	assert_false(_moving.is_tape_blink_on(), "Segundo cuadro apagado")
	assert_eq(_moving.get_current_rect(), start, "Durante el aviso no se mueve")
	_moving.advance(warn_s)
	assert_true(_moving.is_sliding(), "Se desliza tras el aviso")
	_moving.advance(0.6)
	assert_false(_moving.is_sliding())
	assert_eq(_moving.get_position_index(), 1)
	assert_eq(_moving.get_current_rect().position, Vector2(32, 5) * TILE, "Segundo sitio")
	assert_true(_moving.covers_cell(spike), "Ahora tapa el pincho 33")
	assert_false(_moving.is_cell_revealed(spike))
	assert_eq(hazard.global_position, hazard_pos, "Los peligros no se mueven")
	assert_eq(hazard.get_parent().name, &"Hazards", "El Area no es hija del filtro")
	# Tercer sitio y vuelta (ida y vuelta: 0, 1, 2, 1, 0).
	_moving.advance(4.0)
	assert_eq(_moving.get_position_index(), 2)
	_moving.advance(4.0)
	assert_eq(_moving.get_position_index(), 1, "Vuelve por el mismo camino")
	_moving.advance(4.0)
	assert_eq(_moving.get_position_index(), 0)
	assert_eq(hazard.global_position, hazard_pos)


func test_moving_filter_runs_in_world_time() -> void:
	_moving.set_physics_process(true)
	GameState.world_time_scale = 0.5
	await wait_physics_frames(60)
	var slowed: float = _moving._cycle_time
	GameState.world_time_scale = 1.0
	assert_almost_eq(slowed, 0.5, 0.05, "Un segundo real a x0,5 = medio segundo del filtro")


func test_vignette_trembles_near_a_hidden_hazard() -> void:
	watch_signals(_fixed)
	await _stand(3, 9)
	_fixed.advance(0.0)
	assert_false(_fixed.is_trembling(), "Lejos (8 tiles) no tiembla")
	assert_eq(_fixed.get_tremble_offset(), Vector2.ZERO)
	await _stand(8, 9)
	_fixed.advance(0.02)
	assert_true(_fixed.is_trembling(), "A <= 3 tiles de los pinchos ocultos tiembla")
	assert_signal_emitted_with_parameters(_fixed, "hazard_near_changed", [true])
	assert_gt(_fixed.get_hazard_proximity(), 0.0)
	assert_ne(_fixed.get_tremble_offset(), Vector2.ZERO, "La vineta se desplaza")
	# Un pincho al descubierto (filtro movil lejos) no hace temblar.
	await _stand(36, 9)
	_moving.advance(0.0)
	assert_false(_moving.covers_cell(Vector2i(33, 9)))
	assert_false(_moving.covers_cell(Vector2i(38, 9)))
	assert_false(_moving.is_trembling(), "Lo que se ve no es un peligro oculto")
