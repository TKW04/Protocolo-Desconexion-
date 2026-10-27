# Pruebas de conjunto del Mundo 3 (paso 20 de docs/propuesta-mundo-3.md §8, 2026-10-27) en
# las escenas reales del 3-1, el 3-2 y el 3-3 con el Isak real:
# - perder likes nunca bloquea (§3.1): con el contador a 0 (golpes, Ladron, «Borrar
#   publicaciones») cada plataforma de likes normal se apaga y, con la publicacion mas
#   cercana antes de ella (reutilizable, con su enfriamiento de 8 s), se vuelve a llegar a su
#   umbral y la plataforma se materializa; que esa publicacion se alcance sin likes lo
#   comprueba el modelo (tests/test_world3_negatives.py);
# - el filtro no mata (§3.2): cada pincho oculto de los filtros del 3-2 y del 3-3 quita 10,
#   empuja hacia la entrada del filtro y Isak sigue vivo; cada suelo falso deja caer a Isak
#   como mucho 3 tiles hasta el fondo del foso.
# Los otros negativos de conjunto: quieto pierde (tests/test_curator_bot.gd), sin Debug no hay
# marca (tests/test_curator.gd), salidas del validador de los Mundos 1-2 identicas (§8.1, paso 20).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: Node2D
var _sim: IsakSim
var _isak: Isak


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()


func _open(level_id: String) -> void:
	_level = (load("res://scenes/levels/%s.tscn" % level_id) as PackedScene).instantiate() as Node2D
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)


func _of_class(root: Node, script_class: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_class(script_class) or (n.get_script() != null and (n.get_script() as Script).get_global_name() == script_class):
			out.append(n)
		stack.append_array(n.get_children())
	return out


## Con el contador a 0, la plataforma se apaga; con la publicacion de antes (y su enfriamiento)
## vuelve a encenderse.
func _assert_likes_recoverable(level_id: String) -> void:
	await _open(level_id)
	var sources: Array[Node] = _of_class(_level, "LikeSource")
	assert_gt(sources.size(), 0, "%s: tiene publicaciones" % level_id)
	var checked: int = 0
	for node: Node in _of_class(_level, "LikePlatform"):
		var platform := node as LikePlatform
		if platform.invert:
			continue
		platform.set_physics_process(false)
		var best: LikeSource = null
		for s: Node in sources:
			var src := s as LikeSource
			if src.global_position.x <= platform.global_position.x + TILE and (best == null
					or src.global_position.x > best.global_position.x):
				best = src
		assert_not_null(best, "%s: %s con una publicacion antes" % [level_id, platform.object_id])
		if best == null:
			continue
		best.set_physics_process(false)
		GameState.set_likes(0)
		platform.snap()
		assert_false(platform.is_solid(), "%s: %s apagada sin likes" % [level_id, platform.object_id])
		var uses: int = 0
		while not platform.meets_threshold() and uses < 10:
			assert_true(best.like(), "%s: la publicacion da likes" % level_id)
			assert_false(best.like(), "%s: enfriandose no da mas" % level_id)
			best.advance(best.cooldown_s)
			uses += 1
		assert_true(platform.meets_threshold(), "%s: %s vuelve a su umbral (♥%d) con %d usos de %s" %
			[level_id, platform.object_id, platform.threshold, uses, best.object_id])
		platform.advance(DT)
		assert_true(platform.is_solid(), "%s: %s se materializa otra vez" % [level_id, platform.object_id])
		checked += 1
	assert_gt(checked, 0, "%s: plataformas de likes comprobadas" % level_id)


func test_losing_likes_never_blocks_the_3_1() -> void:
	await _assert_likes_recoverable("3-1")


func test_losing_likes_never_blocks_the_3_2() -> void:
	await _assert_likes_recoverable("3-2")


func test_losing_likes_never_blocks_the_3_3() -> void:
	await _assert_likes_recoverable("3-3")


func _stand(pos: Vector2) -> void:
	_isak.global_position = pos
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	# Unos pasos antes de asentarse: is_on_floor() del sitio anterior seguiria en verdadero.
	_sim.step(3)
	_sim.settle()
	await wait_physics_frames(2)


## Cada pincho oculto: -10, empuje hacia la entrada, vivo.
func _assert_filter_spikes_do_not_kill(level_id: String) -> void:
	await _open(level_id)
	var filters: Array[Node] = _of_class(_level, "FilterZone")
	assert_gt(filters.size(), 0, "%s: tiene filtros" % level_id)
	for f: Node in filters:
		(f as FilterZone).set_physics_process(false)
	var hazards: int = 0
	for node: Node in _level.get_node(^"Hazards").get_children():
		var hazard := node as SpikeHazard
		if hazard == null or not hazard.hidden_by_filter:
			continue
		hazards += 1
		var entry: float = hazard.knockback_direction
		assert_ne(entry, 0.0, "%s: %s empuja hacia un lado" % [level_id, hazard.name])
		var zone: FilterZone = null
		for f: Node in filters:
			var fz := f as FilterZone
			if fz.get_union_rect().grow(1.0).has_point(hazard.global_position):
				zone = fz
		assert_not_null(zone, "%s: %s esta bajo un filtro" % [level_id, hazard.name])
		if zone != null:
			assert_eq(entry, zone.get_entry_direction(), "%s: %s empuja hacia la entrada de %s" %
				[level_id, hazard.name, zone.object_id])
		# Isak de pie junto al pincho, del lado de la entrada, con el Sync Rate lleno.
		var shape := hazard.get_child(0) as CollisionShape2D
		var half: float = (shape.shape as RectangleShape2D).size.x * 0.5
		var side_x: float = hazard.global_position.x + entry * (half + TILE * 0.5)
		await _stand(Vector2(side_x, hazard.global_position.y - TILE))
		GameState.sync_rate = GameState.get_sync_rate_max()
		_isak.facing = -entry
		var before: float = GameState.sync_rate
		assert_true(hazard.hit(_isak), "%s: %s golpea" % [level_id, hazard.name])
		assert_almost_eq(GameState.sync_rate, before - 10.0, 0.001, "%s: %s quita 10" % [level_id, hazard.name])
		_sim.step(1)
		assert_gt(_isak.velocity.x * entry, 0.0, "%s: %s empuja hacia la entrada" % [level_id, hazard.name])
		assert_false(_isak.is_dead(), "%s: el filtro engaña, no mata" % level_id)
		_sim.step(_sim.steps_for(1.5))
		assert_false(_isak.is_dead(), "%s: tras el empuje sigue vivo" % level_id)
	assert_gt(hazards, 0, "%s: tiene pinchos ocultos" % level_id)


func test_filter_spikes_do_not_kill_in_the_3_2() -> void:
	await _assert_filter_spikes_do_not_kill("3-2")


func test_filter_spikes_do_not_kill_in_the_3_3() -> void:
	await _assert_filter_spikes_do_not_kill("3-3")


## Suelo falso del 3-2: sin colision; Isak cae como mucho 3 tiles y queda de pie en el foso.
func test_fake_floors_of_the_3_2_drop_at_most_three_tiles() -> void:
	await _open("3-2")
	var floors: int = 0
	for f: Node in _of_class(_level, "FilterZone"):
		var zone := f as FilterZone
		zone.set_physics_process(false)
		for cell: Vector2i in zone.get_fake_floor_cells():
			floors += 1
			# Isak con los pies sobre la cara de arriba del suelo falso.
			await _stand(Vector2((cell.x + 0.5) * TILE, cell.y * TILE))
			assert_true(_isak.is_on_floor(), "Suelo falso %s: acaba de pie" % cell)
			var drop_tiles: float = (_isak.global_position.y - cell.y * TILE) / TILE
			assert_gt(drop_tiles, 0.5, "Suelo falso %s: sin colision (cae)" % cell)
			assert_lte(drop_tiles, 3.01, "Suelo falso %s: cae <= 3 tiles" % cell)
			assert_false(_isak.is_dead(), "Suelo falso %s: no mata" % cell)
	assert_gt(floors, 0, "El 3-2 tiene suelo falso")
