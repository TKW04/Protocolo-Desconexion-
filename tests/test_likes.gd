# Likes del Mundo 3 (2026-10-26, paso 2 de docs/propuesta-mundo-3.md §8, §3.1 y
# §2.3): GameState.likes (0-30 por intento, NUNCA en save.json, vuelve al valor del
# punto de sincronizacion al morir), corazones (heart_pickup), publicacion
# (like_source, +5 con 8 s de enfriamiento), plataformas de likes (umbral, aviso de
# 9 cuadros a 12 fps, no se materializan con Isak dentro, invert), «Borrar
# publicaciones» (like_reset, pulso de espaldas -> 0), golpe -3 con corazones
# recuperables que parpadean 2 s (LikesSystem), HudLikes solo en el Mundo 3 con el
# aviso «Los likes no se guardan.» y la sala likes_test.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ROOM_SCENE: String = "res://scenes/levels/likes_test.tscn"
const PATH: String = "user://test_likes_save.json"
const TILE: float = 64.0
const LEVEL: StringName = &"likes_test"

var _root: Node2D
var _isak: Isak
var _saved_path: String
var _saved_world: int


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_world = GameState.current_world
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	GameState.clear_last_checkpoint(LEVEL)
	_root = Node2D.new()
	_root.name = "LikesTest"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_root.add_child(_isak)
	add_child(_root)
	_isak.set_physics_process(false)
	_isak.global_position = Vector2(2, 9) * TILE + Vector2(32, 64)
	await wait_process_frames(1)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	GameState.reset_progress()
	GameState.clear_last_checkpoint(LEVEL)
	GameState.current_world = _saved_world
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _platform(threshold: int, invert: bool = false, cell: Vector2i = Vector2i(10, 8)) -> LikePlatform:
	var node := (load("res://scenes/levels/like_platform.tscn") as PackedScene).instantiate() as LikePlatform
	node.threshold = threshold
	node.invert = invert
	node.position = Vector2(cell) * TILE
	node.set_physics_process(false)
	_root.add_child(node)
	return node


func _heart(cell: Vector2i = Vector2i(5, 9)) -> HeartPickup:
	var node := (load("res://scenes/levels/heart_pickup.tscn") as PackedScene).instantiate() as HeartPickup
	node.position = Vector2(cell) * TILE
	node.set_physics_process(false)
	_root.add_child(node)
	return node


func _pulse_at(global_point: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	_isak.add_child(area)
	area.global_position = global_point
	return area


# --- Contador ---

func test_counter_is_clamped_and_starts_at_zero_each_attempt() -> void:
	assert_eq(GameState.likes, 0)
	assert_eq(GameState.get_likes_max(), 30)
	GameState.add_likes(50)
	assert_eq(GameState.likes, 30)
	assert_eq(GameState.lose_likes(40), 30)
	assert_eq(GameState.likes, 0)
	GameState.set_likes(12)
	GameState.begin_attempt()
	assert_eq(GameState.likes, 0, "cada intento empieza en 0")


func test_likes_never_go_to_save_json() -> void:
	GameState.set_likes(17)
	var data: Dictionary = GameState.to_save_data()
	for key: Variant in data:
		assert_false(String(key).contains("like"), "save.json no lleva %s" % key)
	assert_true(GameState.save_game())
	var text: String = FileAccess.get_file_as_string(PATH)
	assert_false(text.is_empty())
	assert_false(text.contains("like"), "ningun like en save.json")


func test_death_restores_the_checkpoint_value() -> void:
	GameState.set_likes(7)
	GameState.set_last_checkpoint(LEVEL, &"sync_likes")
	assert_eq(GameState.get_likes_at_checkpoint(), 7)
	GameState.add_likes(5)
	# Caerse fuera del nivel no es morir: se conservan.
	EventBus.player_respawned.emit(Vector2.ZERO, false)
	assert_eq(GameState.likes, 12)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(GameState.likes, 7, "vuelve al valor del punto de sincronizacion")
	GameState.clear_last_checkpoint(LEVEL)
	GameState.reset_likes()
	GameState.add_likes(4)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(GameState.likes, 0, "sin punto de sincronizacion vuelve a 0")


# --- Corazones ---

func test_heart_adds_one_and_does_not_respawn_in_the_attempt() -> void:
	var heart := _heart()
	assert_true(heart.collect())
	assert_eq(GameState.likes, 1)
	assert_true(heart.is_taken())
	assert_false(heart.visible)
	assert_false(heart.collect())
	assert_eq(GameState.likes, 1)


func test_heart_is_collected_by_touch() -> void:
	var heart := _heart(Vector2i(2, 9))
	heart.set_physics_process(true)
	await wait_physics_frames(2)
	assert_true(heart.is_taken(), "Isak lo toca")
	assert_eq(GameState.likes, 1)


func test_hearts_taken_after_the_checkpoint_come_back_on_death() -> void:
	var before := _heart(Vector2i(4, 9))
	before.collect()
	GameState.set_last_checkpoint(LEVEL, &"sync_likes")
	var after := _heart(Vector2i(17, 9))
	after.collect()
	assert_eq(GameState.likes, 2)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(GameState.likes, 1)
	assert_true(before.is_taken(), "cogido antes del punto: no vuelve")
	assert_false(after.is_taken(), "cogido despues: vuelve")
	assert_true(after.visible)
	assert_true(after.collect())
	assert_eq(GameState.likes, 2)


# --- Golpe: -3 en corazones recuperables ---

func test_hit_drops_three_recoverable_blinking_hearts() -> void:
	var system := LikesSystem.attach(_root)
	await wait_process_frames(1)
	assert_eq(system.get_isak(), _isak)
	GameState.set_likes(5)
	_isak.hurt.emit()
	assert_eq(GameState.likes, 2, "un golpe quita 3")
	var dropped: Array[HeartPickup] = []
	for node: Node in get_tree().get_nodes_in_group(HeartPickup.GROUP):
		if (node as HeartPickup).is_dropped():
			dropped.append(node as HeartPickup)
	assert_eq(dropped.size(), 3)
	for heart: HeartPickup in dropped:
		heart.set_physics_process(false)
		assert_almost_eq(heart.get_life_left(), 2.0, 0.001)
	assert_false(dropped[0].collect(), "recien soltado aun no se recoge")
	dropped[0].advance(0.4)
	assert_true(dropped[0].collect())
	assert_eq(GameState.likes, 3)
	dropped[1].advance(1.9)
	assert_true(is_instance_valid(dropped[1]), "sigue parpadeando antes de 2 s")
	dropped[1].advance(0.2)
	await wait_process_frames(1)
	assert_false(is_instance_valid(dropped[1]), "a los 2 s desaparece")
	# Al reaparecer Isak los soltados desaparecen.
	EventBus.player_respawned.emit(Vector2.ZERO, false)
	await wait_process_frames(1)
	assert_false(is_instance_valid(dropped[2]))


func test_hit_without_likes_drops_nothing() -> void:
	var system := LikesSystem.attach(_root)
	await wait_process_frames(1)
	assert_eq(system.on_hit().size(), 0)
	GameState.set_likes(2)
	assert_eq(system.on_hit().size(), 2, "solo los que habia")
	assert_eq(GameState.likes, 0)


# --- Plataformas ---

func test_platform_is_solid_only_at_or_above_its_threshold() -> void:
	var platform := _platform(10)
	assert_false(platform.is_solid())
	assert_eq(platform.get_label_text(), "10")
	GameState.set_likes(9)
	platform.advance(0.016)
	assert_false(platform.is_solid())
	GameState.set_likes(10)
	platform.advance(0.016)
	assert_true(platform.is_solid())
	assert_false((platform.get_node("Shape") as CollisionShape2D).disabled)


func test_platform_warns_for_0_75_s_before_vanishing() -> void:
	var platform := _platform(10)
	GameState.set_likes(12)
	platform.advance(0.016)
	assert_true(platform.is_solid())
	assert_almost_eq(platform.get_warn_s(), 0.75, 0.0001, "9 cuadros a 12 fps")
	GameState.set_likes(9)
	assert_true(platform.is_warning(), "el aviso empieza al bajar del umbral")
	platform.advance(0.7)
	assert_true(platform.is_solid(), "sigue solida durante el aviso")
	platform.advance(0.1)
	assert_false(platform.is_solid(), "desaparece a los 0,75 s")
	assert_true((platform.get_node("Shape") as CollisionShape2D).disabled)


func test_platform_warning_is_cancelled_if_likes_come_back() -> void:
	var platform := _platform(10)
	GameState.set_likes(10)
	platform.advance(0.016)
	GameState.set_likes(7)
	platform.advance(0.5)
	GameState.set_likes(12)
	platform.advance(0.5)
	assert_true(platform.is_solid())
	assert_false(platform.is_warning())


func test_platform_does_not_materialize_with_isak_inside() -> void:
	var platform := _platform(5, false, Vector2i(2, 8))
	_isak.global_position = Vector2(2, 9) * TILE + Vector2(40, 30)
	GameState.set_likes(5)
	platform.advance(0.016)
	assert_false(platform.is_solid(), "Isak esta dentro de su caja")
	_isak.global_position = Vector2(6, 9) * TILE + Vector2(32, 64)
	platform.advance(0.016)
	assert_true(platform.is_solid())


func test_inverse_platform_and_like_reset() -> void:
	var platform := _platform(5, true)
	assert_true(platform.is_solid(), "inversa: solida con menos likes que el umbral")
	GameState.set_likes(5)
	assert_true(platform.is_warning())
	platform.advance(0.8)
	assert_false(platform.is_solid())
	var reset := (load("res://scenes/levels/like_reset.tscn") as PackedScene).instantiate() as LikeReset
	reset.position = Vector2(2, 9) * TILE
	_root.add_child(reset)
	var area := _pulse_at(_isak.global_position + Vector2(0, -56))
	assert_true(reset.receive_pulse(area), "el pulso alcanza el panel")
	assert_eq(GameState.likes, 0, "Borrar publicaciones pone el contador a 0")
	assert_true(_isak.is_facing_back(), "pulso de espaldas")
	assert_true(reset.is_posing())
	platform.advance(0.016)
	assert_true(platform.is_solid(), "la inversa vuelve")
	reset.advance(0.5)
	assert_false(_isak.is_facing_back())


# --- Publicacion ---

func test_like_source_gives_five_with_an_eight_second_cooldown() -> void:
	var source := (load("res://scenes/levels/like_source.tscn") as PackedScene).instantiate() as LikeSource
	source.position = Vector2(2, 8) * TILE
	_root.add_child(source)
	assert_eq(source.gain, 5)
	assert_almost_eq(source.cooldown_s, 8.0, 0.001)
	var far := _pulse_at(Vector2(20, 2) * TILE, 32.0)
	assert_false(source.receive_pulse(far), "el pulso no llega")
	var area := _pulse_at(source.get_hit_rect().get_center())
	assert_true(source.receive_pulse(area))
	assert_eq(GameState.likes, 5)
	assert_false(source.is_ready())
	assert_almost_eq(source.get_charge_ratio(), 0.0, 0.001, "anillo vacio")
	assert_false(source.like(), "se esta enfriando")
	source.advance(4.0)
	assert_almost_eq(source.get_charge_ratio(), 0.5, 0.001)
	source.advance(3.9)
	assert_false(source.like())
	source.advance(0.2)
	assert_true(source.like())
	assert_eq(GameState.likes, 10)
	GameState.set_likes(28)
	source.advance(8.0)
	source.like()
	assert_eq(GameState.likes, 30, "sin pasar del tope")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_true(source.is_ready(), "al reaparecer vuelve lista")


func test_like_source_cooldown_uses_world_time() -> void:
	var source := (load("res://scenes/levels/like_source.tscn") as PackedScene).instantiate() as LikeSource
	_root.add_child(source)
	source.like()
	GameState.world_time_scale = 0.5
	source._process(1.0)
	GameState.world_time_scale = GameState.WORLD_TIME_SCALE_NORMAL
	assert_almost_eq(source.get_cooldown_left(), 7.5, 0.001, "con el Debug el enfriamiento va mas lento")


# --- HUD ---

func test_hud_likes_only_in_world_3_and_notice_at_the_end() -> void:
	var row := HBoxContainer.new()
	_root.add_child(row)
	var hud := HudLikes.attach(row, HudConfig.shared())
	GameState.current_world = 2
	assert_false(hud.is_shown())
	assert_false(hud.visible)
	GameState.current_world = 3
	assert_true(hud.visible)
	GameState.set_likes(12)
	assert_eq(hud.get_text(), "12")
	assert_eq(row.get_child(row.get_child_count() - 1), hud, "a la derecha de los puntos (ultimo de la fila)")
	EventBus.level_completed.emit("likes_test")
	assert_eq(GameState.likes, 0, "se vacia al terminar el nivel")
	var notice := hud.get_notice()
	assert_not_null(notice)
	assert_eq(notice.get_lines(), PackedStringArray(["Los likes no se guardan."]))
	assert_gt(notice.layer, 50, "por encima del fundido de salida")
	notice.queue_free()
	hud.set_hub_mode(true)
	assert_false(hud.visible, "oculto en el hub")


# --- Sala de prueba ---

func test_likes_test_room() -> void:
	GameState.set_likes(9)
	var room := (load(ROOM_SCENE) as PackedScene).instantiate() as GeneratedLevel
	_root.add_child(room)
	await wait_process_frames(2)
	assert_eq(room.world, 3)
	assert_eq(GameState.likes, 0, "al entrar al nivel empieza en 0")
	assert_not_null(room.get_node_or_null("Likes") as LikesSystem)
	var objects: Node = room.get_node("Objects")
	var five := objects.get_node("likes_5") as LikePlatform
	var ten := objects.get_node("likes_10") as LikePlatform
	var inverse := objects.get_node("inversa_5") as LikePlatform
	assert_false(five.is_solid())
	assert_false(ten.is_solid())
	assert_true(inverse.is_solid())
	assert_false(inverse.is_warning(), "sin aviso al empezar")
	assert_eq(ten.threshold, 10)
	assert_true(inverse.invert)
	assert_not_null(objects.get_node("publicacion_1") as LikeSource)
	assert_not_null(objects.get_node("borrar_publicaciones") as LikeReset)
	var hud := room.get_node("Hud") as Hud
	assert_true(hud.get_likes().is_shown())
	room.queue_free()
