## Capturas de los niveles del feed (2-1, 2-2, 2-3; paso 22 de
## docs/propuesta-mundo-2.md §8, 2026-10-23). Extiende el bot del feed
## (tools/feed_bot.gd): el nivel se juega con el flujo real (scenes/main.tscn,
## LevelRunner, el camino del validador, la fisica real y el Input Map) y, ademas
## de las capturas de los bots en que se apoya (01_llegada, 02_reproductor,
## 03_primer_dash, 04_golpe_al_suelo, 15_reproductor_2_2, 19_cuenta, 20_hub),
## este nodo mira cada cuadro lo que hay en la vista y captura la primera vez
## que pasa (solo las que tiene el nivel):
##   02a_scroll         el scroll en marcha (3 s despues de arrancar)
##   05_video_aviso     video en autoplay entero a la vista con la miniatura del clip
##   06_video_clip      el clip del video (ola, rayo o cuenta)
##   07_bucle           Isak en la banda del bucle «Solo uno más»
##   08_fragil          una tarjeta fragil contando bajo Isak
##   09_clones          «Un video más»: dos clones o mas en su zona
##   10_comentarista    Comentarista con el bocadillo avisando o escupiendo
##   11_historia        Isak junto a una Historia
##   12_inversion       la inversion del scroll (borde de arriba que dana)
##   13_muro            muro «Cargando más…» con algun golpe
##   14_muro_roto       el muro roto
##   19_cuenta_final    la tarjeta final contando (sustituye a la 19_cuenta del bot)
## Con --headless no hay imagen: modo de prueba (anota los nombres y el cuadro en
## que se habrian capturado). Lo lanza tools/render_level_2_x.gd (uso alli).
extends "res://tools/feed_bot.gd"

## Sin ventana: solo se anotan las capturas (nombre -> cuadro).
var dry_run: bool = false
var dry_shots: Dictionary = {}
var _scan_level: Node
var _scan_nodes: Array[Node] = []
var _moving_frames: int = 0


func _ready() -> void:
	dry_run = DisplayServer.get_name() == "headless"
	super._ready()


func _shot(name: String, delay: int = 2) -> void:
	if name == "19_cuenta":
		return  # la del bot salia ya fundida; la hace _watch_shots (19_cuenta_final)
	if dry_run:
		if not dry_shots.has(name):
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
	if _runner.is_in_hub() or get_tree().paused or _isak == null or not is_instance_valid(_isak):
		return
	_watch_shots()


func _watch_shots() -> void:
	var cam: ScrollCamera = _isak.get_scroll_camera()
	if cam == null:
		return
	if _level != _scan_level:
		_scan_level = _level
		_scan_nodes.clear()
		_collect(_level)
	var view := Rect2(Vector2(cam.get_center().x - 640.0, cam.get_top()), Vector2(1280.0, cam.get_bottom() - cam.get_top()))
	if cam.is_reversing():
		_shot("12_inversion", 45)
	elif not cam.is_parked():
		_moving_frames += 1
		if _moving_frames == 180:
			_shot("02a_scroll", 0)
	var feet: Vector2 = _isak.global_position
	for node: Node in _scan_nodes:
		if not is_instance_valid(node):
			continue
		if node is AutoplayVideo:
			var video := node as AutoplayVideo
			if view.encloses(video.get_card_rect()):
				if video.is_warning():
					_shot("05_video_aviso", 4)
				elif video.is_attacking():
					_shot("06_video_clip", 8)
		elif node is LoopSection:
			var loop := node as LoopSection
			var top: float = loop.get_band_top_px()
			if feet.y > top and feet.y <= top + loop.get_period_rows() * TILE + 1.0:
				_shot("07_bucle", 20)
		elif node is FragileCard:
			if (node as FragileCard).is_counting():
				_shot("08_fragil", 12)
		elif node is CloneZone:
			if (node as CloneZone).get_clone_count() >= 2:
				_shot("09_clones", 2)
		elif node is Commenter:
			var commenter := node as Commenter
			if view.encloses(commenter.get_body_rect()) \
					and (commenter.is_warning() or not commenter.get_shots().is_empty()):
				_shot("10_comentarista", 4)
		elif node is StoryCard:
			var card := node as Node2D
			if view.has_point(card.global_position) and card.global_position.distance_to(feet) < 3.0 * TILE:
				_shot("11_historia", 10)
		elif node is ExitTerminal:
			if (node as ExitTerminal).get_state() == ExitTerminal.State.COUNTDOWN:
				_shot("19_cuenta_final", 40)
		elif node is LoadingWall:
			var wall := node as LoadingWall
			if wall.is_broken():
				_shot("14_muro_roto", 6)
			elif wall.get_filled() >= 1:
				_shot("13_muro", 4)


func _collect(node: Node) -> void:
	if node == null:
		return
	if node is AutoplayVideo or node is LoopSection or node is FragileCard or node is CloneZone \
			or node is Commenter or node is StoryCard or node is LoadingWall or node is ExitTerminal:
		_scan_nodes.append(node)
	for child: Node in node.get_children():
		_collect(child)
