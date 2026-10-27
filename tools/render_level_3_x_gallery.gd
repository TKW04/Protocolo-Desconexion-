## Capturas de los niveles de la galeria (3-1, 3-2, 3-3; paso 21 de
## docs/propuesta-mundo-3.md §8, 2026-10-27). Extiende el bot de la galeria
## (tools/gallery_bot.gd): el nivel se juega con el flujo real (scenes/main.tscn,
## LevelRunner, el camino del validador, la fisica real y el Input Map) y, ademas
## de las capturas del bot en que se apoya (01_llegada, 20_hub), este nodo mira
## cada cuadro lo que hay en la vista y captura la primera vez que pasa (solo las
## que tiene el nivel y el camino):
##   02_plataforma_likes   Isak sobre una plataforma de likes encendida
##   03_publicacion        una publicacion recien pulsada (enfriamiento)
##   04_influencer_flash   un Influencer cargando el flash
##   05_ladron             un Ladron de likes avisando, persiguiendo o aturdido
##   06_recortar           «Recortar» encendido: Pellizcar obtenido
##   07_pellizcar          Isak comprimido
##   08_marco_pequeno      Isak comprimido dentro de un marco pequeno
##   09_filtro             Isak dentro de un filtro sin el Debug
##   10_filtro_debug       Isak dentro de un filtro con el Debug (lo de debajo)
##   11_espejo_laser       un espejo devolviendo el laser
##   12_pared_espejo       pared de espejo con Isak reflejado
##   13_cazador_haz        el espejo cazador congelado con su haz
##   14_reflejo_falso      un Reflejo falso activo a la vista
##   15_puerta_marco       una puerta de marco abierta
##   19_salida             la terminal de salida en marcha
## Con --headless no hay imagen: modo de prueba (anota los nombres y el cuadro en
## que se habrian capturado). Lo lanza tools/render_level_3_x.gd (uso alli).
extends "res://tools/gallery_bot.gd"

var dry_run: bool = false
var dry_shots: Dictionary = {}
var _scan_level: Node
var _scan_nodes: Array[Node] = []
var _had_compress: bool = false


func _ready() -> void:
	dry_run = DisplayServer.get_name() == "headless"
	super._ready()


## Del bot en que se apoya solo quedan la llegada y el hub (sus demas capturas
## repetirian las de aqui con otros nombres).
const BASE_SHOTS: PackedStringArray = ["01_llegada", "20_hub"]


func _shot(name: String, delay: int = 2) -> void:
	_own_shot(name, delay, true)


func _own_shot(name: String, delay: int = 2, from_base: bool = false) -> void:
	if from_base and not BASE_SHOTS.has(name):
		return
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
	if _runner.is_in_hub() or get_tree().paused or _isak == null or not is_instance_valid(_isak) \
			or not is_instance_valid(_level):
		return
	_watch_shots()


func _view_rect() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


func _watch_shots() -> void:
	if _level != _scan_level:
		_scan_level = _level
		_scan_nodes.clear()
		_had_compress = GameState.is_ability_obtained(GameState.ABILITY_COMPRESS)
		_collect(_level)
	var view: Rect2 = _view_rect()
	var feet: Vector2 = _isak.global_position
	var compressed: bool = _isak.is_compressed()
	if not _had_compress and GameState.is_ability_obtained(GameState.ABILITY_COMPRESS):
		_had_compress = true
		_own_shot("06_recortar", 30)
	if compressed and _isak.is_on_floor():
		_own_shot("07_pellizcar", 0)
	for node: Node in _scan_nodes:
		if not is_instance_valid(node):
			continue
		if node is LikePlatform:
			var plat := node as LikePlatform
			if _isak.is_on_floor() and plat.is_solid() and plat.get_card_rect().grow(2.0).has_point(feet + Vector2(0, 1)):
				_own_shot("02_plataforma_likes", 10)
		elif node is LikeSource:
			var src := node as LikeSource
			if view.has_point(src.global_position) and src.get_cooldown_left() > 0.0:
				_own_shot("03_publicacion", 6)
		elif node is InfluencerBot:
			var bot := node as InfluencerBot
			if view.encloses(bot.get_body_rect()) and bot.is_charging():
				_own_shot("04_influencer_flash", 18)
		elif node is LikeThief:
			var thief := node as LikeThief
			if view.encloses(thief.get_body_rect()) and (thief.is_noticing() or thief.is_chasing() or thief.is_stunned()):
				_own_shot("05_ladron", 6)
		elif node is SmallFrame:
			if compressed and _frame_hole(node as SmallFrame).grow(16.0).has_point(feet + Vector2(0, -4)):
				_own_shot("08_marco_pequeno", 0)
		elif node is FilterZone:
			var zone := node as FilterZone
			if zone.get_current_rect().has_point(feet + Vector2(0, -32)):
				if DebugMode.is_active() and zone.get_reveal_intensity() >= 0.9:
					_own_shot("10_filtro_debug", 0)
				elif not DebugMode.is_active() and zone.get_reveal_intensity() <= 0.0:
					_own_shot("09_filtro", 6)
		elif node is Mirror:
			var mirror := node as Mirror
			if view.has_point(mirror.get_center()) and mirror.is_flashing():
				_own_shot("11_espejo_laser", 1)
		elif node is MirrorWall:
			var wall := node as MirrorWall
			if view.encloses(wall.get_frame_rect()) and wall.is_isak_reflected():
				_own_shot("12_pared_espejo", 30)
		elif node is HunterMirror:
			var hunter := node as HunterMirror
			if view.has_point(hunter.get_center()) and hunter.is_beam_visible():
				_own_shot("13_cazador_haz", 1)
		elif node is FalseReflection:
			var refl := node as FalseReflection
			if refl.is_active() and view.encloses(refl.get_body_rect_now()):
				_own_shot("14_reflejo_falso", 20)
		elif node is FrameDoor:
			var door := node as FrameDoor
			if view.encloses(door.get_rect()) and door.is_open():
				_own_shot("15_puerta_marco", 4)
		elif node is ExitTerminal:
			var state: int = (node as ExitTerminal).get_state()
			if state == ExitTerminal.State.BOOT or state == ExitTerminal.State.COUNTDOWN or state == ExitTerminal.State.TURN:
				_own_shot("19_salida", 10)


## Hueco del marco pequeno en coordenadas del mundo (get_hole_rect es local).
func _frame_hole(frame: SmallFrame) -> Rect2:
	var r: Rect2 = frame.get_hole_rect()
	return Rect2(frame.global_position + r.position, r.size)


func _collect(node: Node) -> void:
	if node == null:
		return
	if node is LikePlatform or node is LikeSource or node is InfluencerBot or node is LikeThief \
			or node is SmallFrame or node is FilterZone or node is Mirror or node is MirrorWall \
			or node is HunterMirror or node is FalseReflection or node is FrameDoor or node is ExitTerminal:
		_scan_nodes.append(node)
	for child: Node in node.get_children():
		_collect(child)
