## Capturas de la pelea con Autoplay (arena 2-boss; paso 22 de
## docs/propuesta-mundo-2.md §8, 2026-10-23). Extiende el bot del jefe
## (tools/autoplay_bot.gd, perfil ideal en Caché): pelea real con el Isak real y
## el Input Map, y este nodo captura la primera vez que pasa cada momento:
##   01_intro                linea de Eco antes de la pelea
##   02_fase1                fase 1 «Clips» en marcha
##   03_fase1_pausa          Debug -> golpe al suelo sobre el cabezal: pausa
##   04_fase2                fase 2 «Siguiente video en 5»
##   05_fase2_cuenta         la «Cuenta atrás» disparando
##   06_fase2_pausa          pausa en la fase 2
##   07_fase3                fase 3 «x2»
##   08_fase3_pausa          pausa en la fase 3
##   09_golpe_final          golpe final
##   10_desarme              desarme en pixeles
##   11_recompensa           recompensa (capa Caché del recuerdo)
##   12_hub_pieza_ambar      hub con la pieza ambar encendida
##   13_mundo3_proximamente  carpeta del Mundo 3 abierta: «Próximamente»
## Con --headless no hay imagen: modo de prueba (anota los nombres). Lo lanza
## tools/render_level_2_x.gd (uso alli).
extends "res://tools/autoplay_bot.gd"

var shots_dir: String = ""
var dry_run: bool = false
var dry_shots: Dictionary = {}
var _requested: Dictionary = {}
var _saved: Dictionary = {}
var _defeat_frame: int = -1
var _hub_frame: int = -1


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
			_req("09_golpe_final", 0)
		elif _frame - _defeat_frame == 60:
			_req("10_desarme", 0)
		return
	var phase: int = _boss.get_phase()
	var names: Dictionary = {1: ["02_fase1", "03_fase1_pausa"], 2: ["04_fase2", "06_fase2_pausa"],
		3: ["07_fase3", "08_fase3_pausa"]}
	if not names.has(phase):
		return
	if int(_phase_frames.get(phase, 0)) == 150:
		_req(names[phase][0], 0)
	if _boss.is_paused():
		_req(names[phase][1], 20)
	if phase == 2 and _boss.get_clip() == Autoplay.CLIP_COUNTDOWN and not _boss.get_shots().is_empty():
		_req("05_fase2_cuenta", 4)


## Tras el golpe final: retiene la recompensa y el hub hasta tener sus capturas.
func _after_defeat() -> void:
	if not _active():
		super._after_defeat()
		return
	if _boss != null and is_instance_valid(_boss) and not _runner.is_in_hub():
		var defeat: BossDefeat = _boss.get_defeat()
		var reward: BossReward = defeat.get_reward() if defeat != null else null
		if reward != null and reward.can_close() and not _saved.has("11_recompensa"):
			_jump = false
			_axis = 0.0
			_req("11_recompensa", 20)
			return
	if _runner.is_in_hub():
		var hub: HubRoom = _runner.get_hub()
		if hub != null and hub.has_arrived() and not hub.is_piece_pending() and not hub.is_piece_lighting() \
				and not _saved.has("13_mundo3_proximamente"):
			_jump = false
			_axis = 0.0
			if not _saved.has("12_hub_pieza_ambar"):
				_req("12_hub_pieza_ambar", 20)
				return
			if _hub_frame < 0:
				_hub_frame = _frame
				var m3: FolderStation = hub.get_folder(&"m3")
				var isak: Isak = hub.get_isak()
				isak.global_position = Vector2(m3.position.x + 96.0, hub.get_shelf_top_y())
				isak.velocity = Vector2.ZERO
			elif _frame - _hub_frame == 36:
				hub.get_folder(&"m3").open(hub.get_isak())
			elif _frame - _hub_frame >= 84:
				_req("13_mundo3_proximamente", 0)
			return
	super._after_defeat()
