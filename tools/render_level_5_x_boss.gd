## Capturas de la pelea con El Vendedor (arena 5-boss; paso 22 de
## docs/propuesta-mundo-5.md §8, 2026-10-29). Extiende el bot del jefe
## (tools/vendor_bot.gd, perfil ideal en Caché): pelea real con el Isak real y el
## Input Map, y este nodo captura la primera vez que pasa cada momento:
##   01_intro                 linea antes de la pelea (Eco por El Vendedor)
##   02_isak_contesta         Isak contesta la intro («No vengo a comprar nada.»)
##   03_fase1                 fase 1 «Plataformas con precio» en marcha (barra «ticket»)
##   04_fase1_giro            la maquina avisando de que se gira hacia Isak
##   05_fase1_barrido         el brazo barriendo un estante
##   06_fase1_ventana         ventana de la fase 1 (Isak detras, la espalda a la vista)
##   07_fase1_marca           marca «Cancelar» en la espalda (Debug -> pulso)
##   08_fase2                 fase 2 «Sorpresa» (cajas lanzadas)
##   09_fase2_devolucion      la bandeja abierta mientras procesa una devolucion
##   10_fase2_ventana         ventana de la fase 2
##   11_fase3                 fase 3 «Oferta por tiempo limitado» (tiron y cuenta)
##   12_fase3_filo            Filo por la ranura de la fase 3
##   13_fase3_ventana         ventana de la fase 3
##   14_golpe_final           golpe final
##   15_desarme               desarme en pixeles
##   16_recompensa            recompensa (capa Caché del recuerdo)
##   17_hub_fondo_completo    hub, pagina 1, con la quinta pieza (blanca) y el fondo completo
## Con --headless no hay imagen: modo de prueba (anota los nombres). Lo lanza
## tools/render_level_5_x.gd (uso alli).
extends "res://tools/vendor_bot.gd"

var shots_dir: String = ""
var dry_run: bool = false
var dry_shots: Dictionary = {}
var _requested: Dictionary = {}
var _saved: Dictionary = {}
var _defeat_frame: int = -1
var _hub_walk_frames: int = 0


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
	_saved[name] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))


func _physics_process(delta: float) -> void:
	if _active() and not _done:
		_watch()
	super._physics_process(delta)
	if _done or not _active():
		return
	_flush()


func _watch() -> void:
	if _runner == null or _runner.is_in_hub() or _boss == null or not is_instance_valid(_boss):
		return
	if not _boss.is_fighting() and not _defeated:
		var box := _level.get_node_or_null(^"EcoTextBox") as EcoTextBox if is_instance_valid(_level) else null
		# Con el texto entero a la vista (la primera pulsacion del bot lo completa).
		if box != null and box.is_showing() and box.get_visible_text() == box.get_text():
			if box.get_speaker_id() == Vendor.SPEAKER_ISAK:
				_req("02_isak_contesta", 1)
			else:
				_req("01_intro", 1)
		return
	if _defeated:
		if _defeat_frame < 0:
			_defeat_frame = _frame
		if _frame - _defeat_frame == 12:
			_req("14_golpe_final", 0)
		elif _frame - _defeat_frame == 60:
			_req("15_desarme", 0)
		return
	var phase: int = _boss.get_phase()
	var core: WeakPoint = _boss.get_core()
	match phase:
		1:
			if int(_phase_frames.get(1, 0)) == 150:
				_req("03_fase1", 0)
			if _boss.get_turn_stage() == Vendor.TURN_WARN:
				_req("04_fase1_giro", 2)
			if _boss.is_sweeping():
				_req("05_fase1_barrido", 4)
			if _boss.is_window_open():
				_req("06_fase1_ventana", 12)
				if core != null and core.is_marked():
					_req("07_fase1_marca", 3)
		2:
			if int(_phase_frames.get(2, 0)) == 180:
				_req("08_fase2", 0)
			if _boss.is_refunding() and _boss.is_tray_open():
				_req("09_fase2_devolucion", 6)
			if _boss.is_window_open():
				_req("10_fase2_ventana", 12)
		3:
			if int(_phase_frames.get(3, 0)) == 150:
				_req("11_fase3", 0)
			if _isak != null and _isak.get_state_name() == PlayerState.COMBO_EDGE:
				_req("12_fase3_filo", 2)
			if _boss.is_window_open():
				_req("13_fase3_ventana", 12)


## Tras el golpe final: retiene la recompensa y el hub hasta tener sus capturas.
func _after_defeat() -> void:
	if not _active():
		super._after_defeat()
		return
	if _boss != null and is_instance_valid(_boss) and not _runner.is_in_hub():
		var defeat: BossDefeat = _boss.get_defeat()
		var reward: BossReward = defeat.get_reward() if defeat != null else null
		if reward != null and reward.can_close() and not _saved.has("16_recompensa"):
			_jump = false
			_axis = 0.0
			_req("16_recompensa", 20)
			return
	if _runner.is_in_hub():
		var hub: HubRoom = _runner.get_hub()
		if hub != null and hub.has_arrived() and not hub.is_piece_pending() and not hub.is_piece_lighting() \
				and not _saved.has("17_hub_fondo_completo"):
			_jump = false
			# Las piezas del fondo estan en la pagina 1: Isak anda a la izquierda hasta ella (tras cerrar la
			# linea de Calc, que pausa el hub mientras se lee).
			var box := hub.get_node_or_null(^"EcoTextBox") as EcoTextBox
			if box != null and box.is_showing():
				_axis = 0.0
				return
			var hub_isak: Isak = hub.get_isak()
			if hub_isak != null and (hub_isak.global_position.x > hub.get_page_width_px() - 160.0
					or hub.is_page_sliding()):
				_axis = -1.0
				_hub_walk_frames = 0
				return
			_axis = 0.0
			_hub_walk_frames += 1
			if _hub_walk_frames >= 30:
				_req("17_hub_fondo_completo", 1)
			return
	super._after_defeat()
