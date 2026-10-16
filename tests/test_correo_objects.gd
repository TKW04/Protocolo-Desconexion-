# Objetos del acertijo «Correo certificado» del 1-2 (pasos 3 de
# docs/propuesta-1-2.md §10; 2026-10-16): lector laser (laser_receiver: corriente
# con temporizador en tiempo del mundo, aviso y reinicio solo), receptor
# enlazado (relay_receiver: solo con corriente; fuera de tiempo, chispa gris y
# nada), su puente (pulse_bridge, enlace por id), el cable (se vacia hacia el
# receptor) y el anuncio (ad_cover: el laser lo rompe; hasta entonces el pulso
# no cierra el pop-up). Con las escenas reales del catalogo.
extends GutTest

const TILE: float = 64.0

var _root: Node2D


func before_each() -> void:
	DebugMode.reset()
	GameState.reset_progress()
	_root = Node2D.new()
	_root.name = "CorreoObjects"
	add_child(_root)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	DebugMode.reset()
	GameState.reset_progress()


func _scene(type: String) -> Node2D:
	var path: String = String(World1ObjectsConfig.type_entry(type).get("scene", ""))
	return (load(path) as PackedScene).instantiate() as Node2D


func _fake_pulse(center: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	_root.add_child(area)
	return area


## Lector en (14, 10), receptor en (8, 6) y puente desde (9, 7), como la sala de prueba.
func _puzzle() -> Dictionary:
	var reader := _scene("laser_receiver") as LaserReceiver
	reader.object_id = &"lector_1"
	reader.target_id = &"relay_1"
	reader.cable_cells = [Vector2(14, 8), Vector2(9, 8), Vector2(9, 6)]
	reader.position = Vector2(14, 10) * TILE
	var relay := _scene("relay_receiver") as RelayReceiver
	relay.object_id = &"relay_1"
	relay.target_id = &"puente_1"
	relay.position = Vector2(8, 6) * TILE
	var bridge := _scene("bridge_inactive") as PulseBridge
	bridge.object_id = &"puente_1"
	bridge.length_tiles = 6
	bridge.position = Vector2(9, 7) * TILE
	_root.add_child(reader)
	_root.add_child(relay)
	_root.add_child(bridge)
	await wait_process_frames(2)
	return {"reader": reader, "relay": relay, "bridge": bridge}


func _pulse_relay(relay: RelayReceiver) -> bool:
	var area := _fake_pulse(relay.get_hit_rect().get_center() - Vector2(60.0, 0.0))
	var before: bool = relay.is_active()
	EventBus.pulse_fired.emit(area)
	area.free()
	return relay.is_active() and not before


# --- Lector laser ---

func test_reader_is_a_laser_target_and_the_pulse_does_nothing() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	assert_true(reader.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE))
	assert_true(bool(reader.collision_layer & LaserProjectile.LAYER_WORLD), "El rayo del laser lo encuentra")
	assert_eq(LaserProjectile.find_laser_target(reader), reader)
	EventBus.pulse_fired.emit(_fake_pulse(reader.get_hit_rect().get_center()))
	assert_false(reader.is_powered(), "El pulso no le hace nada")


func test_hit_rect_covers_the_phone_height_from_its_floor_only() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	var phone_floor_y: float = 11.0 * TILE - 56.0
	var phone_ledge_y: float = 7.0 * TILE - 56.0
	var r: Rect2 = reader.get_hit_rect()
	assert_true(phone_floor_y > r.position.y and phone_floor_y < r.end.y, "Desde el suelo de la sala, si")
	assert_false(phone_ledge_y > r.position.y and phone_ledge_y < r.end.y, "Desde la repisa alta (4 tiles), no")


func test_laser_hit_powers_for_the_window_and_then_resets_by_itself() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	var relay: RelayReceiver = p.relay
	watch_signals(reader)
	reader.on_laser_hit(1.0, null)
	assert_true(reader.is_powered())
	assert_true(relay.is_powered(), "El receptor enlazado recibe corriente")
	assert_almost_eq(reader.get_power_left(), 6.0, 0.001, "Ventana de 6 s (dificultad 2)")
	reader.advance(4.4)
	assert_false(reader.is_warning(), "Aun no avisa")
	reader.advance(0.2)
	assert_true(reader.is_warning(), "Los ultimos 1,5 s: aviso")
	reader.advance(1.5)
	assert_false(reader.is_powered(), "Vencida la ventana se apaga")
	assert_false(relay.is_powered())
	assert_eq(reader.get_state(), LaserReceiver.State.READY, "Vuelve a estar listo: se repite sin castigo")
	assert_signal_emitted(reader, "power_lost")
	reader.on_laser_hit(1.0, null)
	assert_true(reader.is_powered(), "Se puede repetir")


func test_second_hit_refills_the_window() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	reader.on_laser_hit(1.0, null)
	reader.advance(5.0)
	reader.on_laser_hit(1.0, null)
	assert_almost_eq(reader.get_power_left(), 6.0, 0.001)
	assert_eq(reader.get_hit_count(), 2)


func test_window_runs_in_world_time_debug_halves_it() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	reader.on_laser_hit(1.0, null)
	GameState.world_time_scale = 0.5
	reader.advance(WorldTime.scaled_delta(6.0))
	assert_true(reader.is_powered(), "Con el mundo a x0,5, 6 s reales gastan 3 s de ventana")
	assert_almost_eq(reader.get_power_left(), 3.0, 0.01)
	GameState.world_time_scale = 1.0


func test_pause_stops_the_window() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	reader.on_laser_hit(1.0, null)
	get_tree().paused = true
	await wait_process_frames(10)
	get_tree().paused = false
	assert_almost_eq(reader.get_power_left(), 6.0, 0.05, "En pausa la ventana no corre")


# --- Receptor enlazado y puente ---

func test_relay_only_activates_with_power_and_extends_the_bridge() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	var relay: RelayReceiver = p.relay
	var bridge: PulseBridge = p.bridge
	assert_eq(relay.get_readers(), [reader] as Array[LaserReceiver], "Enlazado por id")
	watch_signals(relay)
	assert_false(_pulse_relay(relay), "Sin corriente el pulso no hace nada")
	assert_signal_emitted(relay, "rejected")
	assert_true(relay.is_sparking(), "Chispa gris")
	assert_eq(bridge.get_state(), PulseBridge.State.RETRACTED)
	assert_true(HelpCatalog.is_help_live(relay), "Sigue ayudando")
	reader.on_laser_hit(1.0, null)
	assert_true(_pulse_relay(relay), "Con corriente se activa")
	assert_signal_emitted_with_parameters(relay, "activated", [&"puente_1"])
	assert_eq(bridge.get_state(), PulseBridge.State.EXTENDING, "El puente se extiende")
	for i: int in 60:
		bridge.advance(0.1)
	assert_true(bridge.is_extended())
	assert_true(reader.is_done(), "El lector queda hecho")
	reader.advance(10.0)
	assert_true(reader.is_done(), "Ya no se apaga")
	assert_true(relay.is_active(), "Permanente")
	assert_true(bridge.is_extended(), "Permanente")


func test_pulse_after_the_window_does_nothing() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	var relay: RelayReceiver = p.relay
	reader.on_laser_hit(1.0, null)
	reader.advance(6.1)
	assert_false(_pulse_relay(relay), "Fuera de tiempo: nada")
	assert_eq(relay.get_rejection_count(), 1)
	assert_eq((p.bridge as PulseBridge).get_state(), PulseBridge.State.RETRACTED)


func test_relay_pulse_out_of_range_is_ignored() -> void:
	var p: Dictionary = await _puzzle()
	var relay: RelayReceiver = p.relay
	(p.reader as LaserReceiver).on_laser_hit(1.0, null)
	EventBus.pulse_fired.emit(_fake_pulse(relay.get_hit_rect().get_center() + Vector2(400.0, 0.0)))
	assert_false(relay.is_active())
	assert_eq(relay.get_rejection_count(), 0, "Lejos ni siquiera rebota")


# --- Cable ---

func test_cable_goes_from_the_reader_to_the_relay_and_drains() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	var relay: RelayReceiver = p.relay
	var cable: LaserCable = reader.get_cable()
	var pts: PackedVector2Array = cable.get_global_points()
	assert_eq(pts[0], reader.get_cable_port(), "Sale del lector")
	assert_eq(pts[pts.size() - 1], relay.get_cable_port(), "Llega al receptor")
	for i: int in range(1, pts.size()):
		assert_true(is_equal_approx(pts[i].x, pts[i - 1].x) or is_equal_approx(pts[i].y, pts[i - 1].y),
			"Tramos rectos (horizontal o vertical)")
	assert_eq(cable.get_lit_length(), 0.0, "Apagado sin corriente")
	reader.on_laser_hit(1.0, null)
	assert_almost_eq(cable.get_lit_length(), cable.get_length(), 0.01, "Recien disparado, todo encendido")
	reader.advance(3.0)
	assert_almost_eq(cable.get_lit_length(), cable.get_length() * 0.5, 0.5, "A media ventana, medio cable")
	reader.advance(2.0)
	var dims: int = 0
	for i: int in 30:
		reader.advance(1.0 / 60.0)
		if cable.is_blink_dim():
			dims += 1
	assert_gt(dims, 0, "Parpadea en el aviso")
	assert_lt(dims, 30)
	reader.advance(2.0)
	assert_eq(cable.get_lit_length(), 0.0, "Vacio al vencer")


# --- Anuncio sobre el pop-up ---

func _popup_with_ad() -> Dictionary:
	var popup := _scene("popup_blocker") as PopupBlocker
	popup.object_id = &"popup_1"
	popup.text = "Tu buzón está lleno. Compra más espacio"
	popup.position = Vector2(15, 3) * TILE
	var ad := _scene("ad_cover") as AdCover
	ad.object_id = &"anuncio_1"
	ad.target_id = &"popup_1"
	ad.text = "Saltar anuncio en 5…"
	ad.position = Vector2(15, 6) * TILE
	_root.add_child(popup)
	_root.add_child(ad)
	await wait_process_frames(2)
	return {"popup": popup, "ad": ad}


func test_ad_sits_over_the_close_button() -> void:
	var p: Dictionary = await _popup_with_ad()
	var popup: PopupBlocker = p.popup
	var ad: AdCover = p.ad
	assert_eq(ad.get_popup(), popup)
	assert_true(ad.get_rect().encloses(popup.get_button_rect()), "Tapa el boton entero")
	assert_true(popup.is_button_covered())
	assert_true(ad.get_text().begins_with("Saltar anuncio"))
	var phone_y: float = 7.0 * TILE - 56.0
	assert_true(phone_y > ad.get_rect().position.y and phone_y < ad.get_rect().end.y,
		"A la altura del celular desde el final del puente")


func test_pulse_bounces_off_the_ad_and_does_not_close_the_popup() -> void:
	var p: Dictionary = await _popup_with_ad()
	var popup: PopupBlocker = p.popup
	var ad: AdCover = p.ad
	watch_signals(ad)
	var area := _fake_pulse(popup.get_button_rect().get_center() - Vector2(40.0, 0.0))
	EventBus.pulse_fired.emit(area)
	assert_true(popup.is_open(), "Con el anuncio encima, el pulso no cierra")
	assert_signal_emitted(ad, "pulse_bounced")
	assert_eq(ad.get_bounce_count(), 1)


func test_laser_breaks_the_ad_and_then_the_pulse_closes_the_popup() -> void:
	var p: Dictionary = await _popup_with_ad()
	var popup: PopupBlocker = p.popup
	var ad: AdCover = p.ad
	assert_true(ad.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE))
	watch_signals(ad)
	ad.on_laser_hit(1.0, null)
	assert_signal_emitted(ad, "broken")
	assert_true(ad.is_broken())
	assert_false(popup.is_button_covered(), "Boton libre")
	assert_false(ad.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE), "Roto ya no para el laser")
	for i: int in 20:
		ad.advance(0.05)
	assert_eq(ad.get_state(), AdCover.State.BROKEN)
	assert_signal_emitted(ad, "gone")
	ad.on_laser_hit(1.0, null)
	assert_eq(ad.get_state(), AdCover.State.BROKEN, "Roto, queda roto")
	var area := _fake_pulse(popup.get_button_rect().get_center() - Vector2(40.0, 0.0))
	EventBus.pulse_fired.emit(area)
	assert_false(popup.is_open(), "Ahora el pulso cierra el pop-up")


func test_real_laser_projectile_hits_reader_and_ad() -> void:
	var p: Dictionary = await _puzzle()
	var reader: LaserReceiver = p.reader
	var shot := LaserProjectile.new()
	shot.auto_process = false
	shot.position = Vector2(4.5 * TILE, 11.0 * TILE - 56.0)
	_root.add_child(shot)
	await wait_physics_frames(1)
	for i: int in 120:
		if shot.is_finished():
			break
		shot.step(1.0 / 60.0)
	assert_eq(shot.get_hit_target(), reader, "El proyectil choca con el lector")
	assert_true(reader.is_powered())
	var q: Dictionary = await _popup_with_ad()
	var shot2 := LaserProjectile.new()
	shot2.auto_process = false
	shot2.position = Vector2(8.5 * TILE, 7.0 * TILE - 56.0)
	_root.add_child(shot2)
	await wait_physics_frames(1)
	for i: int in 120:
		if shot2.is_finished():
			break
		shot2.step(1.0 / 60.0)
	assert_eq(shot2.get_hit_target(), q.ad, "Desde la altura del puente, el anuncio")
	assert_true((q.ad as AdCover).is_broken())


func test_catalog_help_ids_and_album() -> void:
	for pair: Array in [["laser_receiver", &"laser_receiver"], ["relay_receiver", &"relay_receiver"],
			["ad_cover", &"ad_cover"]]:
		assert_eq(StringName(String(World1ObjectsConfig.type_entry(pair[0]).get("help_id", ""))), pair[1])
	var objects: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_OBJECT)
	for id: StringName in [&"laser_receiver", &"relay_receiver", &"ad_cover", &"debug_chip"]:
		assert_true(objects.has(id), "%s en la carpeta del Mundo 1 (Objetos)" % id)
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id), "Ficha de %s" % id)
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s_silhouette.png" % id))
		var text: String = HelpCatalog.shared().text(id)
		for banned: String in ["Vuelta", "Easy", "Normal", "Hard"]:
			assert_false(text.contains(banned), "%s: sin %s" % [id, banned])
