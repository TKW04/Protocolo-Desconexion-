## Bot de los niveles del feed (Mundo 2 «El Feed»; paso 12 de
## docs/propuesta-mundo-2.md §8 y §7.3, 2026-10-23): carga la escena principal
## (scenes/main.tscn, LevelRunner) en el nivel real (--level 2-1|2-2|2-3; 2-1 por
## defecto) y sigue el camino que exporta tools/validate_level.py (formato
## isak-path/1) con la fisica real y las acciones del Input Map, nunca Q ni Esc.
## Extiende el bot del 1-3 (tools/dnd_bot.gd, que extiende tools/tower_bot.gd: la
## camara vertical, andar con frenada predictiva, saltos, pulso, laser, Debug,
## dash aereo y en el suelo, lineas importantes, replanificacion). Anade:
## - `wait_scroll`: quieto en su celda hasta que el techo de carga del scroll
##   (ScrollCamera.ceiling_y) deja pasar el movimiento siguiente, con el mismo
##   criterio que el plan (la cabeza puede subir por encima de los pies de
##   salida y de llegada; SCROLL_HEAD_MARGIN_PX). Asi el bot sale de cada espera
##   en el instante del scroll, no del reloj del camino. La espera «antes del
##   Debug» (las de despues van con el mundo lento) sigue ademas el tiempo
##   absoluto del camino: sus segundos desde el instante en que el camino la
##   empieza, trasladado al reloj del bot por el desfase medido en la ultima
##   espera por el techo.
## - `wait_phase` con `clip_cycle_s` (videos en autoplay y Comentaristas): sale
##   cuando el clip del primero llega a su segundo del ciclo; si el paso
##   siguiente es un `wait_scroll`, lo junta (exige el techo y la fase del clip
##   desplazada por esos segundos) para que el cruce empiece en la fase del camino.
## - `ground_pound`: anda a `shot.x`, espera el enfriamiento (`cooldown_before_s`)
##   y mantiene `move_down` hasta que sale el golpe (en el aire, salta en el sitio
##   y lo mantiene desde la cima); lo suelta entre golpes; comprueba `breaks`.
## - `wait` final de la terminal con cuenta (`countdown_s`): quieto hasta que la
##   cuenta termina y el vortice se lleva a Isak.
## - 2-2 (paso 13, 2026-10-23): el pulso de espaldas al reproductor (`pause_player`,
##   hecho cuando queda pausado: da el golpe al suelo) y el compas de las Historias
##   (`wait_beat` con `rhythm` «_historia_<id>»: el reloj propio de la StoryCard,
##   que corre desde que empieza el nivel; solo cuenta la fase dentro del ciclo).
## Comprobaciones (§7.3): completa el nivel y vuelve al hub con el en
## completed_levels; 0 contactos con el borde del scroll; 0 muertes; 0
## repeticiones de un bucle; anota golpes, energia minima frente al camino y la
## duracion de juego. Progreso de partida: Alerta Mayor vencido (pulso, laser,
## Debug y dash; Eco, Notas y Calc conocidos) y los niveles anteriores del Mundo
## 2 completados; el golpe al suelo solo desde el 2-3 (el 2-2 lo da el reproductor).
## Lo lanza tools/play_feed_bot.gd (uso y argumentos alli).
extends "res://tools/dnd_bot.gd"

const FEED_LEVELS: PackedStringArray = ["2-1", "2-2", "2-3"]
const A_DOWN: StringName = &"move_down"
## Holgura de la cabeza bajo el techo de carga (px; SCROLL_HEAD_MARGIN_PX de tools/level_plan.py).
const SCROLL_HEAD_MARGIN_PX: float = 8.0
## Holgura extra del bot (px) sobre la del plan: con el techo justo el arco queda
## cortado a pocos px por encima de la llegada y no da tiempo a pasar por el lado de
## una tarjeta solida (2-1, paso 111); unos 0,5 s mas de espera con el scroll a
## 0,7 tiles/s, sin riesgo (margen minimo del camino 6,3 tiles).
const SCROLL_EXTRA_PX: float = 24.0
## Espera maxima de mas por el techo (s) sobre los segundos del camino.
const SCROLL_WAIT_SLACK_S: float = 8.0
## Borde del scroll (tiles bajo los pies) con el que el bot deja de esperar a un
## video que aun no ha entrado en la vista (ver _wait_phase).
const IDLE_EDGE_TILES: float = 3.5
## Lo que el bot se acerca a la tarjeta en un golpe al suelo (px; ver _pound_step).
const POUND_NUDGE_PX: float = 12.0
## Sonda de la subida (px): avance lateral y subida que se prueban con test_move.
const HEAD_PROBE_PX: Vector2 = Vector2(12.0, 40.0)

var _feed_level: String = "2-1"
var _edge_hits: int = 0
var _loop_wraps: int = 0
var _edge_connected: Isak
var _world_clock: float = 0.0
## Desfase (s) reloj del mundo del bot - t_world del camino, medido al salir de
## cada espera por el techo; NAN hasta la primera.
var _path_offset: float = NAN
var _scroll_waits: int = 0
var _scroll_late: int = 0
var _pounds: int = 0
var _clone_pulses: int = 0
var _skip_index: int = -1
var _jumping: bool = false
var _head_waits: Dictionary = {}
var _memory_before: Dictionary = {}
## Inversiones del scroll vistas (2-3, paso 14): estado del cuadro anterior y cuantas.
var _reversing_now: bool = false
var _reverses: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--level")
	if at >= 0 and at + 1 < args.size():
		_feed_level = args[at + 1]
	EventBus.loop_wrapped.connect(func(loop_id: StringName, count: int) -> void:
		_loop_wraps += 1
		_note("el bucle %s se repite (%d)" % [loop_id, count]))
	super._ready()


func _run(path_file: String) -> void:
	if not FEED_LEVELS.has(_feed_level):
		_fail("nivel desconocido: %s (usa --level 2-1|2-2|2-3)" % _feed_level)
		print("%s: FALLO" % _bot_label())
		for line: String in _log:
			print("  " + line)
		finished.emit(1)
		return
	if not FileAccess.file_exists("res://data/levels/%s.json" % _feed_level):
		_fail("el %s aun no existe (data/levels/%s.json)" % [_feed_level, _feed_level])
		print("%s: FALLO" % _bot_label())
		for line: String in _log:
			print("  " + line)
		finished.emit(1)
		return
	await super._run(path_file)


func _level_id() -> String:
	return _feed_level


func _bot_label() -> String:
	return "play_feed_bot (%s)" % _feed_level


func _export_args(path_file: String) -> PackedStringArray:
	return [ProjectSettings.globalize_path("res://tools/validate_level.py"), "--export-path", path_file,
		ProjectSettings.globalize_path("res://data/levels/%s.json" % _feed_level)]


func _path_cache_file() -> String:
	return "user://feed_bot_path_%s.json" % _feed_level


## Un jugador que acaba de vencer a Alerta Mayor (y, para el 2-2 y el 2-3, de
## completar los niveles anteriores del Mundo 2): pulso, laser, Debug y dash; Eco,
## Notas y Calc conocidos; el golpe al suelo solo para el 2-3.
func _setup_progress() -> void:
	GameState.reset_progress()
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	var abilities: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
		GameState.ABILITY_DASH]
	if _feed_level == "2-3":
		abilities.append(GameState.ABILITY_GROUND_POUND)
	for ability: StringName in abilities:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	for level: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss"]:
		GameState.mark_level_completed(level)
	for level: String in FEED_LEVELS:
		GameState.unlock_level(StringName(level))
		if level == _feed_level:
			break
		GameState.mark_level_completed(StringName(level))
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()
	_memory_before = GameState.memories.duplicate()


func _check_level_loaded() -> bool:
	if _isak == null or _level == null:
		return _fail("el %s no carga" % _feed_level)
	if _isak.camera_mode != Isak.CAMERA_AUTOSCROLL or _isak.get_scroll_camera() == null:
		return _fail("el %s no carga con el scroll forzado" % _feed_level)
	if _feed_level != "2-3" and GameState.is_ability_obtained(GameState.ABILITY_GROUND_POUND):
		return _fail("el bot empieza el %s con el golpe al suelo ya obtenido" % _feed_level)
	return true


func _check_completed() -> bool:
	if not GameState.is_level_completed(StringName(_feed_level)):
		return _fail("el %s no queda completado" % _feed_level)
	var memory: String = "msg_%s" % _feed_level.replace("-", "_")
	var in_path: bool = false
	for s: Variant in _steps:
		if s is Dictionary and String((s as Dictionary).get("target", {}).get("id", "")).contains(memory):
			in_path = true
	_note("FEED: contactos con el borde %d, muertes %d, repeticiones de bucle %d, golpes %d, golpes al suelo %d, pulsos a clones %d, esperas del scroll %d (%d ya pasadas al llegar), dashes %d; %s %s" % [
		_edge_hits, _deaths, _loop_wraps, _hits, _pounds, _clone_pulses, _scroll_waits, _scroll_late, _dashes, memory,
		"recogido" if GameState.has_memory(StringName(memory)) and not _memory_before.has(StringName(memory))
			else ("sin recoger (el camino no pasa por su secreto)" if not in_path else "SIN RECOGER")])
	if _edge_hits > 0:
		return _fail("Isak toca el borde del scroll %d vez/veces" % _edge_hits)
	if _deaths > 0:
		return _fail("Isak muere %d vez/veces" % _deaths)
	if _loop_wraps > 0:
		return _fail("un bucle se repite %d vez/veces (el camino lo resuelve a la primera)" % _loop_wraps)
	if _feed_level == "2-2" and not GameState.is_ability_obtained(GameState.ABILITY_GROUND_POUND):
		return _fail("el golpe al suelo no queda obtenido tras el 2-2")
	return true


## Hub tras un nivel del feed: llegada por el vortice, sin escenas (Calc conocida).
func _hub() -> bool:
	var hub: HubRoom = _runner.get_hub()
	var limit: int = _frame + 60 * 10
	while _frame < limit and not hub.has_arrived():
		await _tick()
	if not hub.has_arrived():
		return _fail("Isak no llega al hub por el vortice")
	_shot("20_hub")
	var intro: CalcIntro = hub.get_calc_intro()
	if intro != null and (intro.is_running() or intro.is_done()):
		return _fail("con Calc ya conocida no deberia haber escena de Calc")
	_note("hub: llegada tras el %s (%s completado %s)" % [_feed_level, _feed_level,
		GameState.is_level_completed(StringName(_feed_level))])
	await _wait_frames(6)
	return true


func _refresh() -> void:
	super._refresh()
	if _isak != null and _edge_connected != _isak and _isak.has_signal(&"scroll_edge_hit"):
		_edge_connected = _isak
		_isak.scroll_edge_hit.connect(func(damaged: bool) -> void:
			_edge_hits += 1
			_note("CONTACTO con el borde del scroll (%s; dano %s; Sync %.0f)" % [_where(), damaged, GameState.sync_rate]))


func _tick(guard: bool = true) -> void:
	await super._tick(guard)
	if _play_started and _runner != null and not get_tree().paused and not _runner.is_in_hub():
		_world_clock += WorldTime.scaled_delta(1.0 / 60.0)
		var camera: ScrollCamera = _isak.get_scroll_camera() if _isak != null else null
		if camera != null and camera.is_reversing() != _reversing_now:
			_reversing_now = camera.is_reversing()
			if _reversing_now:
				_reverses += 1
			_note("inversion del scroll %s (%s; borde de arriba a %.1f tiles de la cabeza)" % [
				"empieza" if _reversing_now else "termina", _where(),
				(_isak.global_position.y - _isak.hitbox_size.y - camera.get_top()) / TILE])


## Saltos bajo una tarjeta solida (frágil o Historia, capa world): subiendo, la
## direccion espera a que la cabeza pase por el lado de la tarjeta (si no, choca
## con su parte de abajo y cae a la fila de salida). El camino supone la subida
## sin roce; en el 2-1, el salto de la fila 32 a la frágil de la fila 31.
func _jump(s: Dictionary, action: String) -> bool:
	# 2-3 (paso 14): un golpe al suelo DE PIE sobre la frágil que solo rompe el golpe la rompe e Isak sigue
	# cayendo; la caída del camino (`fall` desde la frágil) ya está hecha: basta con estar de pie en la fila de
	# llegada (y, si hace falta, andar hasta su celda).
	if action == "fall" and _isak.is_on_floor() and absf(_isak.global_position.y - _px(s["to"]).y) < 4.0 \
			and absf(_px(s["from"]).y - _px(s["to"]).y) > 4.0:
		if _verbose:
			_note("paso %d: la caída ya la hizo el golpe al suelo (%s)" % [_step_index, _where()])
		return await _walk_to(_px(s["to"]).x, _px(s["to"]).y)
	_jumping = true
	var ok: bool = await super._jump(s, action)
	_jumping = false
	return ok


## Despegue (bot del 1-3: TAKEOFF_PAUSE_FRAMES cuadros andando antes de saltar):
## si delante y arriba hay una tarjeta solida, esos cuadros frena en vez de
## seguir (seguir metia la cabeza bajo la frágil del paso 111 del 2-1).
func _press_jump() -> void:
	var dir: float = signf(_axis)
	if _jumping and dir != 0.0 and _isak.is_on_floor() \
			and _isak.test_move(_isak.global_transform, Vector2(dir * HEAD_PROBE_PX.x * 2.0, -HEAD_PROBE_PX.y * 1.5)):
		super._set_axis(0.0)
	await super._press_jump()


func _set_axis(a: float) -> void:
	if _jumping and a != 0.0 and _isak != null and not _isak.is_on_floor() and _isak.velocity.y < 0.0 \
			and _isak.test_move(_isak.global_transform, Vector2(signf(a) * HEAD_PROBE_PX.x, -HEAD_PROBE_PX.y)) \
			and not _isak.test_move(_isak.global_transform, Vector2(0.0, -HEAD_PROBE_PX.y)):
		if not _head_waits.has(_step_index):
			_head_waits[_step_index] = true
			if _verbose:
				_note("paso %d: subiendo sin direccion hasta pasar la tarjeta de encima (%s)" % [_step_index, _where()])
		a = 0.0
	super._set_axis(a)


func _do_extra_step(s: Dictionary, action: String) -> bool:
	match action:
		"wait_scroll":
			if _step_index == _skip_index:
				return true
			return await _wait_scroll(s)
		"ground_pound":
			return await _pound_step(s)
	return await super._do_extra_step(s, action)


# --- Scroll ---

## Primer movimiento (con from/to) desde el paso `index`; `debug` = hay un
## debug_on antes. {} si no hay.
func _next_move(index: int) -> Dictionary:
	var debug: bool = false
	for j: int in range(index, _steps.size()):
		var n: Dictionary = _steps[j]
		var action: String = String(n.get("action", ""))
		if action == "debug_on":
			debug = true
		if n.has("from") and n.has("to"):
			return {"step": n, "index": j, "debug": debug}
		if action == "goal":
			break
	return {}


## Techo que deja pasar el movimiento `move` (y de la cabeza mas alta): el
## criterio del plan con la holgura del bot.
func _ceiling_needed(move: Dictionary) -> float:
	var n: Dictionary = move.get("step", {})
	if n.is_empty():
		return INF
	var feet: float = minf(_px(n["from"]).y, _px(n["to"]).y)
	return feet - _isak.hitbox_size.y - SCROLL_HEAD_MARGIN_PX - SCROLL_EXTRA_PX


## Como _ceiling_needed, pero si el movimiento aterriza en una tarjeta con cuenta
## (frágil o recordatorio) tambien los siguientes hasta salir de ellas: de pie
## encima no se puede esperar (el plan pone la espera antes de subir).
func _ceiling_needed_chain(move: Dictionary) -> float:
	var need: float = _ceiling_needed(move)
	var guard: int = 8
	while not move.is_empty() and guard > 0 and _on_timed_card(_px(move["step"]["to"])):
		move = _next_move(int(move["index"]) + 1)
		need = minf(need, _ceiling_needed(move))
		guard -= 1
	return need


## Los pies en `feet` estan sobre una tarjeta con cuenta (ReminderPlatform: el
## recordatorio y la tarjeta frágil).
func _on_timed_card(feet: Vector2) -> bool:
	if not is_instance_valid(_level):
		return false
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is ReminderPlatform and (node as ReminderPlatform).get_card_rect().grow(2.0).has_point(feet + Vector2(0.0, 1.0)):
			return true
	return false


func _ceiling_ok(need: float) -> bool:
	var camera: ScrollCamera = _isak.get_scroll_camera() if _isak != null else null
	return camera == null or camera.ceiling_y() <= need


## Paso `wait_scroll`: quieto en `at` hasta que el techo de carga deja pasar el
## movimiento siguiente (y, antes del Debug, hasta el instante del camino).
func _wait_scroll(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	# Ya en su celda (llega de un salto) no se recoloca: el scroll no espera.
	if absf(_isak.global_position.y - at.y) >= ROW_TOL or absf(_isak.global_position.x - at.x) > TILE * 0.5:
		if not await _walk_to(at.x, at.y):
			return false
	_set_axis(0.0)
	var move: Dictionary = _next_move(_step_index + 1)
	var need: float = _ceiling_needed_chain(move)
	if String(s.get("reason", "")).contains("antes del tramo con tiempo"):
		# 2-3 (paso 14): la espera de antes de un tramo con Historias es la que deja pasar TODO el tramo (dentro
		# no se puede esperar al techo); el compas lo sincroniza despues su wait_beat.
		var j: int = _step_index + 1
		while j < _steps.size() and String(_steps[j].get("action", "")) not in ["wait_scroll", "goal"]:
			if _steps[j].has("from") and _steps[j].has("to"):
				need = minf(need, _ceiling_needed({"step": _steps[j], "index": j}))
			j += 1
	var seconds: float = float(s.get("seconds", 0.0))
	var path_end: float = float(s.get("t_world", 0.0)) + seconds
	var timed: bool = bool(move.get("debug", false)) and not is_nan(_path_offset)
	var start_clock: float = _world_clock
	var arrived_ok: bool = _ceiling_ok(need) and (not timed or _world_clock >= path_end + _path_offset)
	var ok: bool = await _wait_until(func() -> bool:
		return _ceiling_ok(need) and (not timed or _world_clock >= path_end + _path_offset), seconds + SCROLL_WAIT_SLACK_S)
	_scroll_waits += 1
	if arrived_ok:
		_scroll_late += 1
	if not timed:
		_path_offset = _world_clock - path_end
	if _verbose or not ok:
		var camera: ScrollCamera = _isak.get_scroll_camera()
		_note("espera del scroll %d (%s): %.2f s (camino %.2f s)%s; techo %.0f, necesita %.0f; desfase %+.2f s" % [
			_step_index, String(s.get("reason", "")), _world_clock - start_clock, seconds,
			" ya pasada al llegar" if arrived_ok else "", camera.ceiling_y() if camera != null else NAN, need,
			_path_offset if not is_nan(_path_offset) else 0.0])
	if not ok:
		_note("paso %d: el techo de carga no deja pasar el movimiento siguiente" % _step_index)
	return ok


## wait_phase de los videos en autoplay y los Comentaristas (clip_cycle_s) o de
## los banners (banner_cycle_s, como el bot del 1-3). Si el paso siguiente es un
## wait_scroll, se junta con el (techo y fase desplazada por sus segundos).
func _wait_phase(s: Dictionary) -> bool:
	var clips: Dictionary = s.get("clip_cycle_s", {})
	if clips.is_empty():
		return await super._wait_phase(s)
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(at.x, at.y):
		return false
	var period: float = float(s.get("period_s", 2.5))
	var shift: float = 0.0
	var need: float = INF
	if _step_index + 1 < _steps.size() and String(_steps[_step_index + 1].get("action", "")) == "wait_scroll":
		var scroll: Dictionary = _steps[_step_index + 1]
		shift = float(scroll.get("seconds", 0.0))
		need = _ceiling_needed_chain(_next_move(_step_index + 2))
		_skip_index = _step_index + 1
	var ref: Node = null
	var ref_t: float = 0.0
	for id: String in clips:
		ref = _object(id)
		if ref != null:
			ref_t = fposmod(float(clips[id]) + shift, period)
			break
	if ref == null:
		await _wait_s(float(s.get("seconds", 0.0)) + shift)
		return true
	var started: int = _frame
	var idle: Array[bool] = [false]
	var ok: bool = await _wait_until(func() -> bool:
		if not _ceiling_ok(need):
			return false
		var t: float = _clip_time(ref)
		if t < 0.0:
			# 2-2 (paso 13): con el scroll forzado el video puede no entrar entero en la vista hasta que el borde
			# esta cerca (el plan centra la camara en Isak). Se espera a que empiece su clip, pero si el borde
			# llega a IDLE_EDGE_TILES de los pies se sigue (parado no ataca; al entrar avisa 0,75 s).
			var camera: ScrollCamera = _isak.get_scroll_camera()
			if camera != null and (camera.get_bottom() - _isak.global_position.y) / TILE < IDLE_EDGE_TILES:
				idle[0] = true
				return true
			return false
		var r: float = fposmod(ref_t - t, period)
		if r > period - LATE_TOL_S:
			r -= period
		return r <= 0.0, period * 4.0 + shift + 4.0)
	var phases: PackedStringArray = []
	for id: String in clips:
		var node: Node = _object(id)
		if node != null:
			phases.append("%s %.2f (camino %.2f)" % [id, _clip_time(node), fposmod(float(clips[id]) + shift, period)])
	if idle[0]:
		_note("paso %d: %s aun fuera de la vista (parado): sigue sin esperar su fase" % [_step_index, ref.name])
	elif _verbose or not ok:
		_note("fase de los clips en el paso %d tras %.2f s%s: %s" % [_step_index, (_frame - started) / 60.0,
			" (junta la espera del scroll de %.2f s)" % shift if shift > 0.0 else "", ", ".join(phases)])
	if not ok:
		_note("paso %d: no se encuentra la fase de los clips" % _step_index)
	return ok


## Segundos dentro del ciclo de un video en autoplay (-1 si esta parado o fuera
## de la vista) o de un Comentarista.
func _clip_time(node: Node) -> float:
	if node is AutoplayVideo:
		var video := node as AutoplayVideo
		if video.is_broken() or video.is_stunned() or video.get_state() == AutoplayVideo.STATE_IDLE:
			return -1.0
		return video.get_clip_time()
	if node.has_method(&"get_cycle_time"):
		return float(node.call(&"get_cycle_time"))
	var t: Variant = node.get(&"_cycle_t")
	return float(t) if t != null and float(t) >= 0.0 else -1.0


# --- Reproductor e Historias (2-2) ---

## Reproductor con el boton de pausa (PausePlayer hereda de DndSwitch): hecho
## cuando esta pausado.
func _pulse_done(kind: String, node: Node, s: Dictionary) -> bool:
	if kind == "pause_player":
		return node == null or bool(node.call(&"is_on"))
	return super._pulse_done(kind, node, s)


func _pulse_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var ok: bool = await super._pulse_step(s)
	if ok and String(target.get("type", "")) == "pause_player":
		_note("reproductor %s pausado con el pulso de espaldas: golpe al suelo obtenido %s (%s)" % [
			target.get("id", "?"), GameState.is_ability_obtained(GameState.ABILITY_GROUND_POUND), _where()])
		_shot("02_reproductor")
	return ok


## Compas de una Historia (el plan la modela con un metronomo «_historia_<id>»
## que arranca con el nivel): su reloj propio. El ciclo del camino se cambia por
## el actual (o el siguiente si su fase ya paso), porque el bot no va al segundo
## del camino (las esperas del scroll lo desplazan).
func _wait_beat(s: Dictionary) -> bool:
	var rid: String = String(s.get("rhythm", ""))
	if not rid.begins_with("_historia_"):
		return await super._wait_beat(s)
	var card := _object(rid.trim_prefix("_historia_")) as StoryCard
	var zone: RhythmZone = card.get_own_clock() if card != null else null
	if zone == null or not zone.is_started():
		return await _wait_beat_on(s, zone)
	var copy: Dictionary = s.duplicate(true)
	var beat: Dictionary = copy.get("beat", {})
	var cycle: int = zone.get_cycle_count()
	if float(beat.get("cycle_time_s", 0.0)) < zone.get_cycle_time() - LATE_TOL_S:
		cycle += 1
	beat["cycle"] = cycle
	copy["beat"] = beat
	return await _wait_beat_on(copy, zone)


## Defensa del enjambre (2-2): un clon de «Un video más» peligroso que se
## acerca por la fila de Isak al alcance del pulso -> pulso (lo aturde 3 s, como
## haria un jugador que espera una Historia). Si no, la defensa de siempre.
func _guard() -> void:
	if _has_control() and _can_pulse_now() and is_instance_valid(_level) and _guard_lock == 0:
		for zone: Node in _level.get_node(^"Objects").get_children():
			if not zone is CloneZone:
				continue
			for clone: Node in zone.get_children():
				if not clone is VideoClone or not (clone as VideoClone).is_dangerous():
					continue
				var rect: Rect2 = (clone as VideoClone).get_body_rect()
				if absf(rect.get_center().y - (_isak.global_position.y - 32.0)) > TILE:
					continue
				var toward: float = signf(rect.get_center().x - _isak.global_position.x)
				if _in_pulse_range(rect, 0.9, _isak.facing):
					_tap(A_PULSE)
					# Un toque cada pocos cuadros (pulsar en cuadros seguidos no cuenta como just_pressed).
					_guard_lock = 4
					_clone_pulses += 1
					if _clone_pulses == 1 or _verbose:
						_note("defensa: pulso al clon %s (%s)" % [clone.name, _where()])
					return
				if _axis == 0.0 and toward != 0.0 and toward != signf(_isak.facing) and _in_pulse_range(rect, 0.9, toward):
					_tap(A_RIGHT if toward > 0.0 else A_LEFT)
					_guard_lock = 3
					return
	super._guard()


# --- Golpe al suelo ---

## Paso `ground_pound`: en `shot.x` de la celda `at`, mantiene move_down hasta
## que sale el golpe (en el aire, desde la cima de un salto en el sitio), lo
## suelta y espera al final de la pose. Comprueba lo que rompe (`breaks`).
func _pound_step(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	var x: float = float(s.get("shot", {}).get("x", at.x))
	if s.has("x_px") and not s.has("shot"):
		# 2-2 (paso 13): el plan elige la x de la celda mas cercana a su centro desde la que la onda alcanza
		# la tarjeta, a veces por pocos px; el bot se acerca POUND_NUDGE_PX mas hacia ella (sin salir de la celda).
		x = clampf(float(s["x_px"]) + signf(float(s.get("facing", 0))) * POUND_NUDGE_PX, at.x - TILE * 0.5 + 6.0,
			at.x + TILE * 0.5 - 6.0)
	if DebugMode.is_active() and not bool(s.get("debug", false)):
		await _debug_off()
	elif bool(s.get("debug", false)) and not DebugMode.is_active():
		await _debug_on(s)
	if not await _walk_to(x, at.y):
		return false
	var wait_cd: int = 120
	while wait_cd > 0 and (not _has_control() or _isak.get_ground_pound_cooldown_left() > 0.0):
		await _tick()
		wait_cd -= 1
	if bool(s.get("air", false)):
		await _press_jump()
		var rise: int = 60
		while rise > 0 and (_isak.is_on_floor() or _isak.velocity.y < 0.0):
			await _tick()
			rise -= 1
		_release_jump()
	Input.action_press(A_DOWN)
	var started: bool = await _wait_until(func() -> bool: return _isak.is_ground_pounding(),
		float(s.get("hold_s", 0.35)) + 1.0)
	Input.action_release(A_DOWN)
	if not started:
		_note("paso %d: el golpe al suelo no sale (%s; %s)" % [_step_index, String(_isak.ground_pound_denial()), _where()])
		return false
	_pounds += 1
	if _pounds == 1:
		_shot("04_golpe_al_suelo", 12)
	await _wait_until(func() -> bool: return not _isak.is_ground_pounding() and _has_control() and _isak.is_on_floor(), 3.0)
	var broken: PackedStringArray = []
	var intact: PackedStringArray = []
	for id: Variant in s.get("breaks", []):
		var node: Node = _object(String(id))
		if node == null:
			continue
		var done: bool = (node.has_method(&"is_broken") and node.call(&"is_broken")) \
			or (node.has_method(&"is_solid") and not node.call(&"is_solid"))
		(broken if done else intact).append(String(id))
	_note("golpe al suelo %d%s en %s%s%s" % [_pounds,
		" (%d de %d)" % [int(s.get("count", 1)), int(s.get("of", 1))] if s.has("of") else "", _where(),
		"; rompe %s" % ", ".join(broken) if not broken.is_empty() else "",
		"; limpia %s" % ", ".join(PackedStringArray(s.get("clears", []))) if s.has("clears") else ""])
	if not intact.is_empty():
		_note("paso %d: el golpe no rompe %s" % [_step_index, ", ".join(intact)])
		return false
	return true


# --- Terminal con cuenta ---

func _wait_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	if String(target.get("type", "")) != "exit_terminal":
		return await super._wait_step(s)
	var terminal := _object(String(target.get("id", ""))) as ExitTerminal
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(at.x, at.y):
		return false
	if terminal == null:
		await _wait_s(float(s.get("seconds", 0.0)))
		return true
	var counting: bool = await _wait_until(func() -> bool: return terminal.get_state() >= ExitTerminal.State.COUNTDOWN, 1.5)
	if counting:
		_shot("19_cuenta", 30)
	var ok: bool = await _wait_until(func() -> bool: return terminal.get_state() >= ExitTerminal.State.BOOT,
		float(s.get("seconds", 3.0)) + 2.0)
	if ok:
		_terminal_frames = _play_frames
	_note("terminal %s: cuenta %s y %s (%s)" % [target.get("id", "?"), "empezada" if counting else "SIN EMPEZAR",
		"terminada" if ok else "SIN TERMINAR", _where()])
	return ok
