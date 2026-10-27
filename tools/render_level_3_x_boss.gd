## Capturas de la pelea con La Curadora (arena 3-boss; paso 21 de
## docs/propuesta-mundo-3.md §8, 2026-10-27). Extiende el bot del jefe
## (tools/curator_bot.gd, perfil ideal en Caché): pelea real con el Isak real y
## el Input Map, y este nodo captura la primera vez que pasa cada momento:
##   01_intro                 linea de Eco antes de la pelea
##   02_fase1                 fase 1 «Sesión de fotos» en marcha
##   03_fase1_flash           aviso del flash (Isak tras el biombo)
##   04_fase1_ventana         ventana de la fase 1 (la Curadora baja a encuadrar)
##   05_fase1_marca           marca «sin filtro» en el núcleo (Debug -> pulso)
##   06_fase2                 fase 2 «De espaldas»
##   07_fase2_ventana         ventana de la fase 2 (espejo cazador y de esquina)
##   08_fase3                 fase 3 «Retrato perfecto» (Reflejo falso)
##   09_fase3_marco           marco que se cierra (Isak comprimido en el marco pequeño)
##   10_fase3_ventana         ventana tras el cierre
##   11_golpe_final           golpe final
##   12_desarme               desarme en píxeles
##   13_recompensa            recompensa (capa Caché del recuerdo)
##   14_hub_pieza_verde       hub con la pieza verde ácido encendida
## Con --headless no hay imagen: modo de prueba (anota los nombres). Lo lanza
## tools/render_level_3_x.gd (uso alli).
extends "res://tools/curator_bot.gd"

var shots_dir: String = ""
var dry_run: bool = false
var dry_shots: Dictionary = {}
var _requested: Dictionary = {}
var _saved: Dictionary = {}
var _defeat_frame: int = -1


func _ready() -> void:
	dry_run = DisplayServer.get_name() == "headless"
	if not shots_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shots_dir)
	super._ready()


func taken_shots() -> PackedStringArray:
	var names: PackedStringArray = []
	for name: String in (dry_shots if dry_run else _saved):
		names.append(name)
	names.sort()
	return names


func _active() -> bool:
	return dry_run or not shots_dir.is_empty()


func _req(name: String, delay: int = 2) -> void:
	if not _active() or _requested.has(name) or _saved.has(name):
		return
	if dry_run:
		dry_shots[name] = _frame + delay
		_saved[name] = true
		return
	_requested[name] = _frame + delay


func _flush() -> void:
	for name: String in _requested.keys():
		if _frame >= int(_requested[name]):
			_requested.erase(name)
			_save(name)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
	_saved[name] = true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _done or not _active():
		return
	_watch()
	_flush()


func _watch() -> void:
	if _runner == null or _runner.is_in_hub() or _boss == null or not is_instance_valid(_boss):
		return
	if not _boss.is_fighting() and not _defeated:
		var box := _level.get_node_or_null(^"EcoTextBox") as EcoTextBox if is_instance_valid(_level) else null
		if box != null and box.is_showing():
			_req("01_intro", 14)
		return
	if _defeated:
		if _defeat_frame < 0:
			_defeat_frame = _frame
		if _frame - _defeat_frame == 12:
			_req("11_golpe_final", 0)
		elif _frame - _defeat_frame == 60:
			_req("12_desarme", 0)
		return
	var phase: int = _boss.get_phase()
	var core: WeakPoint = _boss.get_core()
	match phase:
		1:
			if int(_phase_frames.get(1, 0)) == 150:
				_req("02_fase1", 0)
			if _boss.is_flash_warning():
				_req("03_fase1_flash", 4)
			if _boss.is_window_open():
				_req("04_fase1_ventana", 40)
				if core != null and core.is_marked():
					_req("05_fase1_marca", 3)
		2:
			if int(_phase_frames.get(2, 0)) == 150:
				_req("06_fase2", 0)
			if _boss.is_window_open():
				_req("07_fase2_ventana", 50)
		3:
			if int(_phase_frames.get(3, 0)) == 150:
				_req("08_fase3", 0)
			if _boss.get_frame_state() == Curator.FRAME_CLOSING and _isak != null and _isak.is_compressed():
				_req("09_fase3_marco", 4)
			if _boss.is_window_open():
				_req("10_fase3_ventana", 30)


## Tras el golpe final: retiene la recompensa y el hub hasta tener sus capturas.
func _after_defeat() -> void:
	if not _active():
		super._after_defeat()
		return
	if _boss != null and is_instance_valid(_boss) and not _runner.is_in_hub():
		var defeat: BossDefeat = _boss.get_defeat()
		var reward: BossReward = defeat.get_reward() if defeat != null else null
		if reward != null and reward.can_close() and not _saved.has("13_recompensa"):
			_jump = false
			_axis = 0.0
			_req("13_recompensa", 20)
			return
	if _runner.is_in_hub():
		var hub: HubRoom = _runner.get_hub()
		if hub != null and hub.has_arrived() and not hub.is_piece_pending() and not hub.is_piece_lighting() \
				and not _saved.has("14_hub_pieza_verde"):
			_jump = false
			_axis = 0.0
			_req("14_hub_pieza_verde", 20)
			return
	super._after_defeat()
