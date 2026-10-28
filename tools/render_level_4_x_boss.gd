## Capturas de la pelea con El Visto (arena 4-boss; paso 22 de
## docs/propuesta-mundo-4.md §8, 2026-10-28). Extiende el bot del jefe
## (tools/seen_bot.gd, perfil ideal en Caché): pelea real con el Isak real y el
## Input Map, y este nodo captura la primera vez que pasa cada momento:
##   01_intro                 linea antes de la pelea
##   02_fase1                 fase 1 «Ghosting» en marcha (barra «conversación»)
##   03_fase1_rastro          el rastro de El Visto con el Debug
##   04_fase1_ventana         ventana de la fase 1 (reaparece detras de Isak)
##   05_fase1_marca           marca «sin leer» en el check gris (Debug -> pulso)
##   06_fase2                 fase 2 «Grupo» (Trolls y Stickers, escudo)
##   07_fase2_escudo          pulso al escudo desde la burbuja fija (sin Agitar,
##                            retirado el 2026-10-28)
##   08_fase2_ventana         ventana de la fase 2 (El Visto en el suelo)
##   09_fase3_escribiendo     el «escribiendo…» gigante con dos puntos o mas
##   10_fase3_congelado       Isak congelado por el mensaje (ESCENIFICADO: en el
##                            primer «escribiendo…» de la fase 3 el bot no lo
##                            interrumpe; espera a que se acabe y sigue)
##   11_fase3_ventana         ventana tras interrumpir el «escribiendo…»
##   12_golpe_final           golpe final
##   13_desarme               desarme en pixeles
##   14_recompensa            recompensa (capa Caché del recuerdo)
##   15_hub_pieza_coral       hub con la pieza coral encendida
## Con --headless no hay imagen: modo de prueba (anota los nombres). Lo lanza
## tools/render_level_4_x.gd (uso alli).
extends "res://tools/seen_bot.gd"

var shots_dir: String = ""
var dry_run: bool = false
var dry_shots: Dictionary = {}
var _requested: Dictionary = {}
var _saved: Dictionary = {}
var _defeat_frame: int = -1
## Escenificacion de la congelacion: 0 sin empezar, 1 dejando pasar el mensaje, 2 hecha.
var _freeze_stage: int = 0
var _frozen_frames: int = 0
const FREEZE_HOLD_FRAMES: int = 40


func _ready() -> void:
	dry_run = DisplayServer.get_name() == "headless"
	if not shots_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shots_dir)
	EventBus.pulse_fired.connect(func(_a: Area2D) -> void:
		if _boss != null and is_instance_valid(_boss) and _boss.get_phase() == 2 and _boss.is_shield_up() \
				and _boss.get_stickers().is_empty() and _isak != null and _isak.global_position.y < 7.0 * _tile:
			_req("07_fase2_escudo", 3))
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
	super._physics_process(delta)
	if _done or not _active():
		return
	_watch()
	_flush()


## Politica: en el primer «escribiendo…» de la fase 3 se queda quieto (sin
## pulso) para que el mensaje salga y lo congele; congelado, la del bot (espera).
func _fight() -> void:
	if _active() and _freeze_stage < 2 and _boss.get_phase() == 3 and not _isak.is_frozen():
		var typing: StringName = _boss.get_typing_state()
		if _freeze_stage == 0 and typing == Seen.TYPING_ON:
			_freeze_stage = 1
			_note("render: deja pasar el primer mensaje de la fase 3 (captura de la congelacion)")
		if _freeze_stage == 1:
			if typing == Seen.TYPING_IDLE and _boss.get_attack_state() != Seen.ATTACK_TYPING:
				_freeze_stage = 2
			else:
				_debug_want = false
				return
	if _freeze_stage == 1 and _isak.is_frozen():
		_freeze_stage = 2
	# Congelado por el mensaje escenificado: FREEZE_HOLD_FRAMES quieto (la captura
	# 10 muestra a Isak congelado); despues, la politica del bot (sigue esperando).
	if _active() and _freeze_stage == 2 and _isak.is_frozen() and _frozen_frames < FREEZE_HOLD_FRAMES:
		_frozen_frames += 1
		_debug_want = false
		return
	super._fight()


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
			_req("12_golpe_final", 0)
		elif _frame - _defeat_frame == 60:
			_req("13_desarme", 0)
		return
	var phase: int = _boss.get_phase()
	var core: WeakPoint = _boss.get_core()
	match phase:
		1:
			if int(_phase_frames.get(1, 0)) == 150:
				_req("02_fase1", 0)
			if _boss.is_trail_visible() and DebugMode.is_active():
				_req("03_fase1_rastro", 6)
			if _boss.is_window_open():
				_req("04_fase1_ventana", 20)
				if core != null and core.is_marked():
					_req("05_fase1_marca", 3)
		2:
			if int(_phase_frames.get(2, 0)) == 240:
				_req("06_fase2", 0)
			if _boss.is_window_open():
				_req("08_fase2_ventana", 30)
		3:
			if _boss.get_typing_state() == Seen.TYPING_ON and _boss.get_dots() >= 2:
				_req("09_fase3_escribiendo", 0)
			if _isak != null and _isak.is_frozen():
				_req("10_fase3_congelado", 24)
			if _boss.is_window_open():
				_req("11_fase3_ventana", 20)


## Tras el golpe final: retiene la recompensa y el hub hasta tener sus capturas.
func _after_defeat() -> void:
	if not _active():
		super._after_defeat()
		return
	if _boss != null and is_instance_valid(_boss) and not _runner.is_in_hub():
		var defeat: BossDefeat = _boss.get_defeat()
		var reward: BossReward = defeat.get_reward() if defeat != null else null
		if reward != null and reward.can_close() and not _saved.has("14_recompensa"):
			_jump = false
			_axis = 0.0
			_req("14_recompensa", 20)
			return
	if _runner.is_in_hub():
		var hub: HubRoom = _runner.get_hub()
		if hub != null and hub.has_arrived() and not hub.is_piece_pending() and not hub.is_piece_lighting() \
				and not _saved.has("15_hub_pieza_coral"):
			_jump = false
			_axis = 0.0
			_req("15_hub_pieza_coral", 20)
			return
	super._after_defeat()
