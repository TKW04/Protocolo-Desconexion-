## Capturas de los niveles de la tienda (5-1, 5-2, 5-3; paso 22 de
## docs/propuesta-mundo-5.md §8, 2026-10-29). Extiende el bot de la tienda
## (tools/mall_bot.gd, perfil frugal salvo --profile comprador): el nivel se juega
## con el flujo real (scenes/main.tscn, LevelRunner, el camino del validador, la
## fisica real y el Input Map) y, ademas de las capturas del bot en que se apoya
## (01_llegada, 20_hub), este nodo mira cada cuadro lo que hay en la vista y captura
## la PRIMERA vez que pasa (solo las que tiene el nivel y su camino):
##   02_oferta             una Oferta tirando de Isak (su zona a la vista)
##   03_oferta_pulso       una Oferta aturdida por el pulso
##   04_tienda             un objeto de la tienda cerca de Isak
##   05_compra             una compra o un pago (solo el comprador)
##   06_atajo              un atajo con precio cerca de Isak
##   07_atajo_debug        la trampa de un atajo revelada por el Debug
##   08_devoluciones       el mostrador de Devoluciones cerca de Isak
##   09_caja               una caja sorpresa cerrada cerca de Isak
##   10_caja_debug         una caja sorpresa con su contenido revelado por el Debug
##   11_caja_abierta       una caja sorpresa recien abierta
##   12_suscripcion        una Suscripcion persiguiendo o enganchada
##   13_suscripcion_pulso  una Suscripcion aturdida (cancelada)
##   14_cuenta             una cuenta regresiva avisando de que se pliega
##   15_terminos           Terminos y condiciones cerrado cerca de Isak
##   16_terminos_rechazo   Terminos y condiciones abierto con «rechazar» (laser o Filo)
##   17_prueba_gratis      la «Prueba gratis» cerca de Isak
##   18_isak_habla         Isak hablando en su cuadro (con el juego en pausa)
##   19_embestida          una Embestida al aterrizar (su onda)
##   21_filo               un Filo en marcha
##   22_sismo              un Sismo al aterrizar (su onda)
##   23_persiana           una persiana rota
##   24_ranura             Isak comprimido junto a una ranura de precios
##   25_estanterias        una estanteria de saldos tumbada
##   26_deseos             una lista de deseos tirando de Isak
##   27_tachon             el tachon de la lista de deseos con su texto
##   28_calc               la caja registradora de Calc saludando
##   29_salida             la salida en marcha
## Con --headless no hay imagen: modo de prueba (anota los nombres y el cuadro en
## que se habrian capturado). Lo lanza tools/render_level_5_x.gd (uso alli).
extends "res://tools/mall_bot.gd"

## Del bot en que se apoya solo quedan la llegada y el hub.
const BASE_SHOTS: PackedStringArray = ["01_llegada", "20_hub"]
const NEAR_PX: float = 420.0

var dry_run: bool = false
var dry_shots: Dictionary = {}
var _asked: Dictionary = {}
var _scan_level: Node
var _scan_nodes: Array[Node] = []
var _due: Dictionary = {}


func _ready() -> void:
	dry_run = DisplayServer.get_name() == "headless"
	EventBus.combo_landed.connect(func(kind: StringName, _rect: Rect2, _source: Node2D) -> void:
		if kind == Isak.COMBO_RAM:
			_own_shot("19_embestida", 3)
		elif kind == Isak.COMBO_QUAKE:
			_own_shot("22_sismo", 3))
	EventBus.attention_spent.connect(func(_amount: int, _reason: StringName) -> void:
		_own_shot("05_compra", 8))
	super._ready()


func _shot(name: String, delay: int = 2) -> void:
	if BASE_SHOTS.has(name):
		_own_shot(name, delay)


## Una sola vez por nombre (la primera vez que pasa).
func _own_shot(name: String, delay: int = 2) -> void:
	if _asked.has(name):
		return
	if not dry_run and _shots_dir.is_empty():
		return
	_asked[name] = true
	if dry_run:
		dry_shots[name] = _frame + delay
		return
	_due[name] = _frame + delay


## Escribe las capturas que tocan SIN esperar en el bucle del bot (el _shot de la base espera un
## frame_post_draw dentro de _tick y el bot pierde un cuadro de control: en el 5-1 y en la Embestida
## del 5-2 se salia del camino). Se engancha al siguiente frame_post_draw y sigue.
func _flush_due() -> void:
	for name: String in _due.keys():
		if _frame < int(_due[name]):
			continue
		_due.erase(name)
		var file: String = _shots_dir.path_join(name + ".png")
		RenderingServer.frame_post_draw.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(file), CONNECT_ONE_SHOT)


## Capturas escritas o anotadas (para el informe del lanzador).
func taken_shots() -> PackedStringArray:
	var names: PackedStringArray = []
	if dry_run:
		for name: String in dry_shots:
			names.append(name)
	elif not _shots_dir.is_empty():
		for file: String in DirAccess.get_files_at(_shots_dir):
			if file.ends_with(".png"):
				names.append(file.get_basename())
	names.sort()
	return names


func _tick(guard: bool = true) -> void:
	await super._tick(guard)
	if not _shots_dir.is_empty() and not _due.is_empty():
		_flush_due()
	if (_shots_dir.is_empty() and not dry_run) or not _play_started or _runner == null:
		return
	if _runner.is_in_hub() or _isak == null or not is_instance_valid(_isak) or not is_instance_valid(_level):
		return
	if get_tree().paused:
		_watch_paused()
		return
	_watch_shots()


## Con el juego en pausa solo interesa Isak hablando (escena de la «Prueba gratis»).
func _watch_paused() -> void:
	var box := _level.get_node_or_null(^"EcoTextBox") as EcoTextBox
	if box != null and box.is_showing() and box.get_speaker_id() == &"isak" and box.get_visible_text() == box.get_text():
		_own_shot("18_isak_habla", 1)


func _view_rect() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


func _near(rect: Rect2, view: Rect2, feet: Vector2) -> bool:
	return view.encloses(rect) and feet.distance_to(rect.get_center()) < NEAR_PX


func _watch_shots() -> void:
	if _level != _scan_level:
		_scan_level = _level
		_scan_nodes.clear()
		_collect(_level)
	var view: Rect2 = _view_rect()
	var feet: Vector2 = _isak.global_position
	if _isak.get_state_name() == PlayerState.COMBO_EDGE:
		_own_shot("21_filo", 2)
	for node: Node in _scan_nodes:
		if not is_instance_valid(node):
			continue
		if node is OfferSign:
			var offer := node as OfferSign
			if view.encloses(offer.get_body_rect()):
				if offer.is_stunned():
					_own_shot("03_oferta_pulso", 4)
				elif offer.is_pulling_isak():
					_own_shot("02_oferta", 6)
		elif node is CalcRegister:
			var register := node as CalcRegister
			if register.has_greeted() and view.encloses(register.get_screen_rect()):
				_own_shot("28_calc", 6)
		elif node is ShortcutDoor:
			var door := node as ShortcutDoor
			if _near(door.get_door_rect(), view, feet):
				_own_shot("06_atajo", 4)
				if door.has_trap() and door.is_trap_revealed() and DebugMode.is_active():
					_own_shot("07_atajo_debug", 4)
		elif node is ShopItem:
			var item := node as ShopItem
			if view.grow(-96.0).has_point(item.global_position) and feet.distance_to(item.global_position) < NEAR_PX:
				_own_shot("04_tienda", 4)
		elif node is RefundDesk:
			var desk := node as RefundDesk
			if view.grow(-96.0).has_point(desk.global_position) and feet.distance_to(desk.global_position) < NEAR_PX:
				_own_shot("08_devoluciones", 4)
		elif node is SurpriseBox:
			var box := node as SurpriseBox
			if not view.encloses(box.get_body_rect()):
				continue
			if box.is_revealed() and DebugMode.is_active() and box.is_closed():
				_own_shot("10_caja_debug", 4)
			elif box.is_opened():
				_own_shot("11_caja_abierta", 4)
			elif box.is_closed() and feet.distance_to(box.get_body_rect().get_center()) < NEAR_PX:
				_own_shot("09_caja", 4)
		elif node is Subscription:
			var sub := node as Subscription
			if view.encloses(sub.get_body_rect()):
				if sub.is_stunned():
					_own_shot("13_suscripcion_pulso", 4)
				elif sub.is_chasing() or sub.is_attached():
					_own_shot("12_suscripcion", 4)
		elif node is CountdownPlatform:
			var cd := node as CountdownPlatform
			if cd.is_warning() and view.encloses(cd.get_card_rect()):
				_own_shot("14_cuenta", 2)
		elif node is TermsGate:
			var terms := node as TermsGate
			if _near(terms.get_door_rect(), view, feet):
				if not terms.is_open():
					_own_shot("15_terminos", 4)
				elif terms.get_opened_by() != TermsGate.HOW_ACCEPT:
					_own_shot("16_terminos_rechazo", 6)
		elif node is FreeTrialBox:
			var trial := node as FreeTrialBox
			if _near(trial.get_box_rect(), view, feet):
				_own_shot("17_prueba_gratis", 4)
		elif node is Shutter:
			var shutter := node as Shutter
			if shutter.is_broken() and view.encloses(shutter.get_shutter_rect()):
				_own_shot("23_persiana", 8)
		elif node is PriceRail:
			var rail := node as PriceRail
			if _isak.is_compressed() and _near(rail.get_rail_rect(), view, feet):
				_own_shot("24_ranura", 2)
		elif node is ClearanceShelf:
			var shelf := node as ClearanceShelf
			if shelf.is_down() and view.encloses(shelf.get_shelf_rect()):
				_own_shot("25_estanterias", 4)
		elif node is WishlistPlatform:
			var wish := node as WishlistPlatform
			if wish.is_pulling() and view.encloses(wish.get_card_rect()):
				_own_shot("26_deseos", 6)
		elif node is WishStrike:
			var strike := node as WishStrike
			if strike.is_text_shown() and view.grow(-64.0).has_point((strike as Node2D).global_position):
				_own_shot("27_tachon", 6)
		elif node is ExitTerminal:
			var state: int = (node as ExitTerminal).get_state()
			if state == ExitTerminal.State.BOOT or state == ExitTerminal.State.COUNTDOWN or state == ExitTerminal.State.TURN:
				_own_shot("29_salida", 30)


func _collect(node: Node) -> void:
	if node == null:
		return
	if node is OfferSign or node is ShopItem or node is ShortcutDoor or node is RefundDesk or node is SurpriseBox \
			or node is Subscription or node is CountdownPlatform or node is TermsGate or node is FreeTrialBox \
			or node is Shutter or node is PriceRail or node is ClearanceShelf or node is WishlistPlatform \
			or node is WishStrike or node is ExitTerminal:
		_scan_nodes.append(node)
	for child: Node in node.get_children():
		_collect(child)
