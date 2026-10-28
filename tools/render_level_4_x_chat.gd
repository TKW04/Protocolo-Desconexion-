## Capturas de los niveles del chat (4-1, 4-2, 4-3; paso 22 de
## docs/propuesta-mundo-4.md §8, 2026-10-28). Extiende el bot del chat
## (tools/chat_bot.gd): el nivel se juega con el flujo real (scenes/main.tscn,
## LevelRunner, el camino del validador, la fisica real y el Input Map) y, ademas
## de las capturas del bot en que se apoya (01_llegada, 20_hub), este nodo mira
## cada cuadro lo que hay en la vista y captura la PRIMERA vez que pasa (solo las
## que tiene el nivel y su camino):
##   02_burbuja            Isak de pie sobre una burbuja de chat
##   03_linterna           la Linterna recien recogida
##   04_modo_oscuro        Isak dentro del Modo oscuro con la luz de la Linterna
##   05_escribiendo        una «escribiendo…» escribiendose (puntos)
##   06_visto              una zona «Visto» avisando o activa
##   07_visto_pulso        una zona «Visto» interrumpida por el pulso
##   08_troll              un Troll avisando o aturdido
##   09_autocorrector      un autocorrector con el cursor (antes de corregirse)
##   10_fantasma           un Fantasma visible
##   11_sticker            un Sticker inflandose o aturdido
##   12_papelera           la Papelera hablando (con el juego en pausa)
##   13_deshacer           el «¿Deshacer escritura?» a la vista
##   14_muro_texto         el muro de texto borrandose
##   (15_agitar, la onda de Agitar: retirada el 2026-10-28)
##   16_ola                la ola de «Visto» a la vista
##   17_disfrazado         un Troll disfrazado de burbuja a la vista
##   18_tinta              un escrito «en tinta» iluminado por la Linterna
##   19_salida             la salida en marcha (en el 4-3, «Responder más tarde»)
## Con --headless no hay imagen: modo de prueba (anota los nombres y el cuadro en
## que se habrian capturado). Lo lanza tools/render_level_4_x.gd (uso alli).
extends "res://tools/chat_bot.gd"

## Del bot en que se apoya solo quedan la llegada y el hub.
const BASE_SHOTS: PackedStringArray = ["01_llegada", "20_hub"]

var dry_run: bool = false
var dry_shots: Dictionary = {}
var _asked: Dictionary = {}
var _scan_level: Node
var _scan_nodes: Array[Node] = []
var _had_lamp: bool = false


func _ready() -> void:
	dry_run = DisplayServer.get_name() == "headless"
	super._ready()


func _shot(name: String, delay: int = 2) -> void:
	if BASE_SHOTS.has(name):
		_own_shot(name, delay)


## Una sola vez por nombre (la primera vez que pasa).
func _own_shot(name: String, delay: int = 2) -> void:
	if _asked.has(name):
		return
	_asked[name] = true
	if dry_run:
		dry_shots[name] = _frame + delay
		return
	super._shot(name, delay)


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
	if (_shots_dir.is_empty() and not dry_run) or not _play_started or _runner == null:
		return
	if _runner.is_in_hub() or _isak == null or not is_instance_valid(_isak) or not is_instance_valid(_level):
		return
	if get_tree().paused:
		_watch_paused()
		return
	_watch_shots()


## Con el juego en pausa solo interesa la Papelera hablando (historia del 4-2).
func _watch_paused() -> void:
	var box := _level.get_node_or_null(^"EcoTextBox") as EcoTextBox
	if box != null and box.is_showing() and box.get_speaker_text().to_lower().contains("papelera"):
		_own_shot("12_papelera", 40)


func _view_rect() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


func _watch_shots() -> void:
	if _level != _scan_level:
		_scan_level = _level
		_scan_nodes.clear()
		_had_lamp = GameState.has_met_ally(GameState.ALLY_LINTERNA)
		_collect(_level)
	if not _had_lamp and GameState.has_met_ally(GameState.ALLY_LINTERNA):
		_had_lamp = true
		_own_shot("03_linterna", 24)
	var view: Rect2 = _view_rect()
	var feet: Vector2 = _isak.global_position
	for node: Node in _scan_nodes:
		if not is_instance_valid(node):
			continue
		if node is AutocorrectBubble:
			var auto := node as AutocorrectBubble
			if view.encloses(auto.get_card_rect()) and auto.get_phase() == AutocorrectBubble.Phase.CURSOR \
					and not auto.is_corrected():
				_own_shot("09_autocorrector", 8)
		elif node is TypingBubble:
			var typing := node as TypingBubble
			if view.encloses(typing.get_card_rect()) and typing.is_typing() and typing.get_dots() >= 2:
				_own_shot("05_escribiendo", 0)
		elif node is ChatBubble:
			var bubble := node as ChatBubble
			if _isak.is_on_floor() and bubble.is_solid() and bubble.is_stepped_on() \
					and view.grow(-128.0).has_point(feet):
				_own_shot("02_burbuja", 12)
		elif node is DarkZone:
			var dark := node as DarkZone
			if dark.is_isak_inside() and dark.has_flashlight() and dark.is_hole_open() and _isak.is_on_floor() \
					and dark.get_zone_rect().grow(-64.0).has_point(feet):
				_own_shot("04_modo_oscuro", 8)
		elif node is InkOnly:
			var ink := node as InkOnly
			if ink.is_lit() and view.has_point(ink.get_center()):
				_own_shot("18_tinta", 10)
		elif node is SeenZone:
			var zone := node as SeenZone
			if view.encloses(zone.get_zone_rect()):
				if zone.is_interrupted():
					_own_shot("07_visto_pulso", 6)
				elif zone.is_active() or zone.get_state() == SeenZone.State.WARNING:
					_own_shot("06_visto", 2)
		elif node is SeenWave:
			var wave := node as SeenWave
			if not wave.is_off() and wave.get_front_x() > view.position.x + 64.0 and wave.get_front_x() < view.end.x:
				_own_shot("16_ola", 4)
		elif node is TrollMimic:
			var mimic := node as TrollMimic
			if mimic.is_disguised() and mimic.get_disguise() != null and view.encloses(mimic.get_disguise().get_card_rect()):
				_own_shot("17_disfrazado", 2)
		elif node is Troll:
			var troll := node as Troll
			if view.encloses(troll.get_body_rect()) and (troll.is_warning() or troll.is_stunned()):
				_own_shot("08_troll", 4)
		elif node is Ghost:
			var ghost := node as Ghost
			if ghost.is_visible_ghost() and view.encloses(ghost.get_body_rect()):
				_own_shot("10_fantasma", 4)
		elif node is Sticker:
			var sticker := node as Sticker
			if view.encloses(sticker.get_body_rect()) and (sticker.is_inflating() or sticker.is_stunned()):
				_own_shot("11_sticker", 4)
		elif node is UndoPrompt:
			var undo := node as UndoPrompt
			var panel := Rect2(undo.global_position + undo.get_panel_rect().position, undo.get_panel_rect().size)
			if view.encloses(panel) and feet.distance_to(panel.get_center()) < 400.0:
				_own_shot("13_deshacer", 10)
		elif node is TypedWall:
			var wall := node as TypedWall
			if view.encloses(wall.get_wall_rect()) and wall.is_erasing():
				_own_shot("14_muro_texto", 6)
		elif node is ExitTerminal:
			var state: int = (node as ExitTerminal).get_state()
			if state == ExitTerminal.State.BOOT or state == ExitTerminal.State.COUNTDOWN or state == ExitTerminal.State.TURN:
				_own_shot("19_salida", 30)


func _collect(node: Node) -> void:
	if node == null:
		return
	if node is ChatBubble or node is TypingBubble or node is AutocorrectBubble or node is DarkZone \
			or node is InkOnly or node is SeenZone or node is SeenWave or node is Troll or node is TrollMimic \
			or node is Ghost or node is Sticker or node is UndoPrompt or node is TypedWall or node is ExitTerminal:
		_scan_nodes.append(node)
	for child: Node in node.get_children():
		_collect(child)
