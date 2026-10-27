## Bot de la galeria (Mundo 3 «La Vitrina»; paso 11 de docs/propuesta-mundo-3.md
## §8 y §7.3, 2026-10-26): carga la escena principal (scenes/main.tscn,
## LevelRunner) en el nivel real (--level 3-1|3-2|3-3; 3-1 por defecto; tambien
## las salas *_test del Mundo 3) y sigue el camino que exporta
## tools/validate_level.py (formato isak-path/1) con la fisica real y las acciones
## del Input Map, nunca Q ni Esc. Extiende el bot del 1-3 (tools/dnd_bot.gd, que
## extiende tools/tower_bot.gd: andar con frenada predictiva, saltos, pulso,
## laser, Debug, dash aereo y en el suelo, wait_beat, lineas importantes,
## replanificacion). Anade los pasos del Mundo 3:
## - `heart`: el corazon se coge al pasar (el tramo anterior no frena por el); si
##   aun no esta cogido, anda hasta su centro. Los que no se cogen se anotan (el
##   umbral que no llegue fallara en el salto siguiente).
## - `pinch` / `unpinch`: toque de `gesture_pinch` en el sitio (comprimirse / pedir
##   el tamano; si la vuelta queda pedida por falta de sitio, espera a que vuelva).
## - `like_reset`: pulso de espaldas a «Borrar publicaciones» (hecho con el
##   contador a 0).
## - pulso a una publicacion (`like_source`): espera a que este lista (anillo) y
##   pulsa; hecho cuando suben los likes o empieza su enfriamiento.
## - pulso a un enemigo del Mundo 3 (`like_thief`, `influencer_bot`): en la x del
##   camino, mirando hacia el, espera a tenerlo al alcance y pulsa; hecho
##   aturdido o derrotado. La defensa de cada cuadro aturde ademas al Ladron que
##   persigue y al Influencer que carga si se ponen al alcance.
## - `wait_hunter`: quieto hasta que el espejo cazador mira hacia `target.facing`.
## - `wait_reflection`: quieto hasta que la puerta de marco esta abierta.
## - `ground_pound`: mantiene `move_down` en `shot.x` hasta que sale el golpe.
## - el «Recortar» (`crop_tool`, pulso de espaldas): hecho encendido (da Pellizcar).
## Comprobaciones (§7.3): completa el nivel y vuelve al hub con el en
## completed_levels; 0 muertes; 0 robos del Ladron; anota golpes, likes al pisar
## cada plataforma de likes frente a su umbral, corazones, energia minima frente
## al camino y la duracion de juego. Progreso de partida: Autoplay vencido (pulso,
## laser, Debug, dash y golpe al suelo; Eco, Notas y Calc conocidos, Mundos 1 y 2
## completados) y los niveles anteriores del Mundo 3 completados; Pellizcar solo
## desde el 3-3 (el 3-2 lo da «Recortar»).
## El 3-2 «Sin filtro» (paso 12, 2026-10-27) se recorre con los mismos pasos, sin
## cambios en el bot: «Recortar» de espaldas (Pellizcar), 4 marcos pequenos con pinch
## / unpinch, el Debug en los tres filtros, el Ladron aturdido antes de la ♥10 y
## dashes; comprueba ademas que Pellizcar queda obtenido.
## El 3-3 «Espejo, espejito» (paso 13, 2026-10-27) es el primer camino real con `wait_hunter`, pulsos
## reflejados por el espejo cazador hacia un receptor de pulso (el camino nombra su puente: hecho al
## extenderse), `wait_reflection` ante las puertas de marco y un pulso al Reflejo falso (de espaldas, sin
## tocar al cazador): `wait_hunter` espera como mucho sus segundos (el plan la parte con el pulso al reflejo)
## y el pulso al cazador espera a que acabe la pose del anterior para girarse. Comprueba ademas que el 3-3
## desbloquea la fila del jefe (3-boss).
## Lo lanza tools/play_gallery_bot.gd (uso y argumentos alli).
extends "res://tools/dnd_bot.gd"

const GALLERY_LEVELS: PackedStringArray = ["3-1", "3-2", "3-3"]
const A_PINCH: StringName = &"gesture_pinch"
const A_DOWN: StringName = &"move_down"
## Espera maxima (s) a que un enemigo del camino se ponga al alcance del pulso.
const ENEMY_PULSE_WAIT_S: float = 4.0
## Holgura (s) sobre los segundos del camino en las esperas del cazador y del reflejo.
const WAIT_SLACK_S: float = 3.0
## Enemigos del Mundo 3 que el camino aturde con el pulso (el Reflejo falso desde el 3-3, paso 13).
const ENEMY_KINDS: PackedStringArray = ["like_thief", "influencer_bot", "false_reflection"]

var _gallery_level: String = "3-1"
var _thefts: int = 0
var _stolen: int = 0
var _thief_watch: Dictionary = {}
var _heart_watch: Dictionary = {}
## Corazones del nivel cogidos (senal collected; tambien los que no estan en el camino).
var _hearts_taken: int = 0
var _hearts: int = 0
var _hearts_missed: PackedStringArray = []
## Plataformas de likes pisadas: id -> {threshold, invert, likes} (likes al pisarla la primera vez).
var _platform_likes: Dictionary = {}
var _platform_order: PackedStringArray = []
var _pinches: int = 0
var _unpinches: int = 0
var _pounds: int = 0
var _resets: int = 0
var _posts: int = 0
var _enemy_pulses: int = 0
var _hunter_waits: int = 0
var _reflection_waits: int = 0
var _likes_peak: int = 0
var _source_before: int = -1


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--level")
	if at >= 0 and at + 1 < args.size():
		_gallery_level = args[at + 1]
	super._ready()


func _run(path_file: String) -> void:
	var problem: String = _level_problem()
	if not problem.is_empty():
		_fail(problem)
		print("%s: FALLO" % _bot_label())
		for line: String in _log:
			print("  " + line)
		finished.emit(1)
		return
	await super._run(path_file)


## Motivo por el que el bot no recorre `_gallery_level` ("" = lo recorre): un
## nivel del Mundo 3 (3-1, 3-2, 3-3) o una sala *_test con world 3.
func _level_problem() -> String:
	var file: String = "res://data/levels/%s.json" % _gallery_level
	if not GALLERY_LEVELS.has(_gallery_level) and not _gallery_level.ends_with("_test"):
		return "nivel desconocido: %s (usa --level 3-1|3-2|3-3 o una sala *_test del Mundo 3)" % _gallery_level
	if not FileAccess.file_exists(file):
		return "el %s aun no existe (data/levels/%s.json)" % [_gallery_level, _gallery_level]
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not data is Dictionary or int((data as Dictionary).get("world", 0)) != 3:
		return "el %s no es un nivel del Mundo 3" % _gallery_level
	return ""


func _is_test_room() -> bool:
	return not GALLERY_LEVELS.has(_gallery_level)


func _level_id() -> String:
	return _gallery_level


func _bot_label() -> String:
	return "play_gallery_bot (%s)" % _gallery_level


func _export_args(path_file: String) -> PackedStringArray:
	return [ProjectSettings.globalize_path("res://tools/validate_level.py"), "--export-path", path_file,
		ProjectSettings.globalize_path("res://data/levels/%s.json" % _gallery_level)]


func _path_cache_file() -> String:
	return "user://gallery_bot_path_%s.json" % _gallery_level


## Un jugador que acaba de vencer a Autoplay (y, para el 3-2 y el 3-3, de
## completar los niveles anteriores del Mundo 3): pulso, laser, Debug, dash y
## golpe al suelo; Eco, Notas y Calc conocidos; Pellizcar solo para el 3-3.
func _setup_progress() -> void:
	GameState.reset_progress()
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	var abilities: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
		GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND]
	if _gallery_level == "3-3":
		abilities.append(GameState.ABILITY_COMPRESS)
	for ability: StringName in abilities:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	for level: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss"]:
		GameState.mark_level_completed(level)
	for level: String in GALLERY_LEVELS:
		GameState.unlock_level(StringName(level))
		if level == _gallery_level:
			break
		GameState.mark_level_completed(StringName(level))
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()


func _check_level_loaded() -> bool:
	if _isak == null or _level == null:
		return _fail("el %s no carga" % _gallery_level)
	if _isak.camera_mode == Isak.CAMERA_AUTOSCROLL:
		return _fail("el %s no deberia tener scroll forzado" % _gallery_level)
	if _gallery_level in ["3-1", "3-2"] and GameState.is_ability_obtained(GameState.ABILITY_COMPRESS):
		return _fail("el bot empieza el %s con Pellizcar ya obtenido" % _gallery_level)
	if GameState.likes != 0:
		return _fail("el %s empieza con %d likes" % [_gallery_level, GameState.likes])
	return true


func _check_completed() -> bool:
	if not _is_test_room() and not GameState.is_level_completed(StringName(_gallery_level)):
		return _fail("el %s no queda completado" % _gallery_level)
	var path_hearts: int = 0
	for s: Variant in _steps:
		if s is Dictionary and String((s as Dictionary).get("action", "")) == "heart":
			path_hearts += 1
	var parts: PackedStringArray = []
	var min_margin: int = 1 << 30
	for id: String in _platform_order:
		var p: Dictionary = _platform_likes[id]
		var margin: int = (int(p["threshold"]) - 1 - int(p["likes"])) if bool(p["invert"]) \
			else (int(p["likes"]) - int(p["threshold"]))
		min_margin = mini(min_margin, margin)
		parts.append("%s %d%s%d" % [id, int(p["likes"]), " < " if bool(p["invert"]) else "/", int(p["threshold"])])
	_note("GALERIA: muertes %d, golpes %d, robos %d (%d likes), corazones cogidos %d (pasos del camino %d, cogidos al pasar %d)%s, publicaciones %d, resets %d, pellizcos %d / vueltas %d, golpes al suelo %d, pulsos a enemigos %d, esperas del cazador %d y del reflejo %d, dashes %d, likes maximos %d; likes al pisar: %s; margen minimo %s" % [
		_deaths, _hits, _thefts, _stolen, _hearts_taken, path_hearts, _hearts,
		" sin coger: %s" % ", ".join(_hearts_missed) if not _hearts_missed.is_empty() else "", _posts, _resets,
		_pinches, _unpinches, _pounds, _enemy_pulses, _hunter_waits, _reflection_waits, _dashes, _likes_peak,
		", ".join(parts) if not parts.is_empty() else "-", str(min_margin) if not parts.is_empty() else "-"])
	if _deaths > 0:
		return _fail("Isak muere %d vez/veces" % _deaths)
	if _thefts > 0:
		return _fail("el Ladron roba %d vez/veces (el camino lo aturde antes)" % _thefts)
	if _gallery_level == "3-2" and not GameState.is_ability_obtained(GameState.ABILITY_COMPRESS):
		return _fail("Pellizcar no queda obtenido tras el 3-2")
	if _gallery_level == "3-3":
		if not GameState.is_level_unlocked(&"3-boss"):
			return _fail("el 3-3 no desbloquea la fila «Jefe: La Curadora»")
		_note("fila del jefe: 3-boss desbloqueado %s (sin jugar hasta el paso 17)" % GameState.is_level_unlocked(&"3-boss"))
	return true


## Hub tras un nivel de la galeria: llegada por el vortice, sin escenas (Calc conocida).
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
	_note("hub: llegada tras el %s (%s completado %s; likes %d)" % [_gallery_level, _gallery_level,
		GameState.is_level_completed(StringName(_gallery_level)), GameState.likes])
	await _wait_frames(6)
	return true


# --- Servicios de cada cuadro ---

func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(_level) or _runner == null or _runner.is_in_hub():
		return
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is HeartPickup and not _heart_watch.has(node):
			_heart_watch[node] = true
			(node as HeartPickup).collected.connect(func(_amount: int) -> void: _hearts_taken += 1)
	for node: Node in _level.get_node(^"Enemies").get_children():
		if node is LikeThief and not _thief_watch.has(node):
			_thief_watch[node] = true
			var label: String = node.name
			(node as LikeThief).stole.connect(func(amount: int, carried: int) -> void:
				_thefts += 1
				_stolen += amount
				_note("ROBO: %s se lleva %d like(s) (lleva %d; %s)" % [label, amount, carried, _where()]))


func _tick(guard: bool = true) -> void:
	await super._tick(guard)
	if not _play_started or _runner == null or _runner.is_in_hub() or not is_instance_valid(_level) or _isak == null:
		return
	_likes_peak = maxi(_likes_peak, GameState.likes)
	if not _isak.is_on_floor():
		return
	var feet: Vector2 = _isak.global_position + Vector2(0.0, 1.0)
	for node: Node in _level.get_node(^"Objects").get_children():
		if not node is LikePlatform or _platform_likes.has(String(node.name)):
			continue
		var platform := node as LikePlatform
		if platform.is_solid() and platform.get_card_rect().grow(2.0).has_point(feet):
			_platform_likes[String(node.name)] = {"threshold": platform.threshold, "invert": platform.invert,
				"likes": GameState.likes}
			_platform_order.append(String(node.name))
			if _verbose:
				_note("pisa %s (umbral %d%s) con %d like(s)" % [node.name, platform.threshold,
					", inversa" if platform.invert else "", GameState.likes])


## Defensa: el Ladron que persigue y el Influencer que carga, al alcance del
## pulso -> pulso (como el jugador). Si no, la defensa de siempre.
func _guard() -> void:
	if _guard_lock == 0 and _has_control() and _can_pulse_now() and is_instance_valid(_level):
		for node: Node in _level.get_node(^"Enemies").get_children():
			# El Ladron no quita Sync (is_dangerous es falso): amenaza mientras avisa o persigue.
			var threat: bool = (node is LikeThief and (node as LikeThief).is_combat_active()) \
				or (node is InfluencerBot and (node as InfluencerBot).is_charging())
			if not threat:
				continue
			var rect: Rect2 = node.call(&"get_body_rect")
			if _in_pulse_range(rect, 0.9, _isak.facing):
				_tap(A_PULSE)
				_guard_lock = 4
				_guard_pulses += 1
				_note("defensa: pulso a %s %s (%s)" % [node.name, String(node.call(&"get_state")), _where()])
				return
	super._guard()


# --- Pasos ---

## Un corazon del camino no frena el tramo anterior (se coge al pasar).
func _continues(index: int, dir: float) -> bool:
	if index < _steps.size() and String(_steps[index].get("action", "")) == "heart":
		return _continues(index + 1, dir)
	return super._continues(index, dir)


func _do_extra_step(s: Dictionary, action: String) -> bool:
	match action:
		"heart":
			return await _heart_step(s)
		"pinch":
			return await _pinch_step(s, true)
		"unpinch":
			return await _pinch_step(s, false)
		"like_reset":
			return await _pulse_step(s)
		"wait_hunter":
			return await _wait_hunter(s)
		"wait_reflection":
			return await _wait_reflection(s)
		"ground_pound":
			return await _pound_step(s)
	return await super._do_extra_step(s, action)


## Paso `heart`: cogido al pasar; si no, anda hasta su centro y lo espera un poco.
func _heart_step(s: Dictionary) -> bool:
	var id: String = String(s.get("target", {}).get("id", ""))
	var heart := _object(id) as HeartPickup
	if heart == null or heart.is_taken():
		_hearts += 1
		return true
	var at: Vector2 = _px(s["at"])
	await _walk_to(heart.get_center().x, at.y)
	if await _wait_until(func() -> bool: return heart.is_taken(), 0.3):
		_hearts += 1
		return true
	_hearts_missed.append(id)
	_note("paso %d: el corazon %s no se coge (centro %s; %s; likes %d)" % [_step_index, id, heart.get_center(), _where(),
		GameState.likes])
	return true


## Pasos `pinch` / `unpinch`: toque de gesture_pinch en la celda del camino.
func _pinch_step(s: Dictionary, on: bool) -> bool:
	var at: Vector2 = _px(s["at"])
	if absf(_isak.global_position.x - at.x) > TILE * 0.5 or absf(_isak.global_position.y - at.y) >= ROW_TOL:
		if not await _walk_to(at.x, at.y):
			return false
	_set_axis(0.0)
	var done := func() -> bool: return _isak.is_compressed() == on
	if not done.call() and not (not on and _isak.is_uncompress_pending()):
		await _wait_until(func() -> bool: return _has_control() and (not on or _isak.compress_denial() == &""), 1.5)
		_tap(A_PINCH)
	var ok: bool = await _wait_until(done, float(s.get("squash_s", 0.15)) + (0.3 if on else 1.5))
	if ok:
		if on:
			_pinches += 1
			if _pinches == 1:
				_shot("05_pellizcar", 12)
		else:
			_unpinches += 1
	if _verbose or not ok:
		_note("paso %d: %s %s (%s; caja %s%s)" % [_step_index, "pellizca" if on else "pide el tamano",
			"hecho" if ok else "SIN EFECTO", _where(), _isak.get_hitbox_size(),
			"; %s" % String(_isak.compress_denial()) if on and not ok else ""])
	return ok


func _pulse_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	var node: Node = _object(String(target.get("id", "")))
	if kind in ENEMY_KINDS:
		return await _enemy_pulse_step(s, node)
	if target.has("via_hunter"):
		return await _hunter_pulse_step(s, node)
	if kind == "like_source" and node != null:
		var source := node as LikeSource
		if not source.is_ready():
			await _wait_until(func() -> bool: return source.is_ready(), source.get_cooldown_left() + 1.0)
		_source_before = GameState.likes
	var before: int = GameState.likes
	var ok: bool = await super._pulse_step(s)
	if not ok:
		return false
	match kind:
		"like_source":
			_posts += 1
			_note("publicacion %s: likes %d -> %d (camino %d; %s)" % [target.get("id", "?"), before, GameState.likes,
				int(target.get("likes_after", -1)), _where()])
		"like_reset":
			_resets += 1
			_note("«Borrar publicaciones» %s con el pulso de espaldas: likes %d -> %d (%s)" % [target.get("id", "?"),
				before, GameState.likes, _where()])
			_shot("06_reset")
		"crop_tool":
			_note("«Recortar» %s con el pulso de espaldas: Pellizcar obtenido %s (%s)" % [target.get("id", "?"),
				GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), _where()])
			_shot("02_recortar")
	return true


func _pulse_done(kind: String, node: Node, s: Dictionary) -> bool:
	if node == null:
		return true
	# Receptor de pulso sin id (el haz del cazador del 3-3): el camino nombra su puente; hecho al empezar a extenderse.
	if node is PulseBridge:
		return (node as PulseBridge).get_state() != PulseBridge.State.RETRACTED
	match kind:
		"like_source":
			return GameState.likes > _source_before or not (node as LikeSource).is_ready()
		"like_reset":
			return GameState.likes == 0 and not (node as LikeReset).is_posing()
		"crop_tool":
			return bool(node.call(&"is_on"))
		"like_thief", "influencer_bot":
			return bool(node.call(&"is_stunned")) or bool(node.call(&"is_defeated"))
		"false_reflection":
			return (node as FalseReflection).is_stunned()
	return super._pulse_done(kind, node, s)


## Laser del camino. Con espejos (Mundo 3) el punto de disparo importa: el rayo
## rebota en el punto real del cristal y un espejo de la celda de Isak queda
## detras del celular si se dispara desde mas alla (reflejo_test: espejo y Isak en
## la columna 4). Se dispara desde la x del camino (`x_px`), no desde cualquier
## punto de la celda como en el bot del 1-2.
func _laser_step(s: Dictionary) -> bool:
	if s.has("x_px") and s.has("at") and _level_has_mirrors():
		var at: Vector2 = _px(s["at"])
		if not await _walk_to(float(s["x_px"]), at.y):
			return false
	return await super._laser_step(s)


func _level_has_mirrors() -> bool:
	if not is_instance_valid(_level):
		return false
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is Mirror or node is HunterMirror:
			return true
	return false


## Pulso a un enemigo del Mundo 3: en la x del camino, mirando hacia el, espera a
## tenerlo al alcance (ENEMY_PULSE_WAIT_S) y pulsa; hecho aturdido o derrotado.
func _enemy_pulse_step(s: Dictionary, node: Node) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	if _pulse_done(kind, node, s):
		_note("%s %s ya aturdido o derrotado al llegar (defensa; %s)" % [kind, target.get("id", "?"), _where()])
		return true
	var at: Vector2 = _px(s["at"])
	var facing: float = float(s.get("facing", 1))
	# Ya en la celda del camino y con el enemigo delante: no se recoloca (volver atras gira a Isak de espaldas
	# al Ladron que se acerca y le da tiempo a robar; 3-1, paso 49).
	var body: Rect2 = _body_rect(node)
	var in_cell: bool = absf(_isak.global_position.x - at.x) <= TILE * 0.5 and absf(_isak.global_position.y - at.y) < ROW_TOL \
		and signf(body.get_center().x - _isak.global_position.x) == signf(facing)
	if not in_cell and not await _walk_to(float(s.get("x_px", at.x)), at.y):
		return false
	_set_axis(0.0)
	for attempt: int in 3:
		if _pulse_done(kind, node, s):
			break
		await _face(facing)
		var reach: bool = await _wait_until(func() -> bool:
			return _pulse_done(kind, node, s) or (_has_control() and _can_pulse_now()
				and _in_pulse_range(_body_rect(node), 0.9, _isak.facing)), ENEMY_PULSE_WAIT_S)
		if _pulse_done(kind, node, s):
			break
		if not reach:
			_note("paso %d: %s no se pone al alcance del pulso (%s; %s)" % [_step_index, node.name,
				String(node.call(&"get_state")), _where()])
			continue
		_tap(A_PULSE)
		await _wait_until(func() -> bool: return _pulse_done(kind, node, s), 0.5)
	var ok: bool = _pulse_done(kind, node, s)
	if ok:
		_enemy_pulses += 1
	_note("pulso a %s %s: %s (%s; likes %d)" % [kind, node.name, String(node.call(&"get_state")) if ok else "SIN EFECTO",
		_where(), GameState.likes])
	return ok


## Caja del enemigo para el alcance del pulso (el Reflejo falso la da con get_body_rect_now).
func _body_rect(node: Node) -> Rect2:
	if node is FalseReflection:
		return (node as FalseReflection).get_body_rect_now()
	return node.call(&"get_body_rect")


## Pulso reflejado por un espejo cazador hacia un receptor (`target.via_hunter`):
## con Isak a su alcance el cazador gira hacia el cada 0,6 s, asi que el bot llega
## a la x del camino sin frenar y pulsa en cuanto el cazador mira hacia
## `via_hunter.facing` (el camino supone llegar y pulsar a la vez). Si falla, se
## aleja hasta que el cazador vuelve a su reposo y lo intenta otra vez.
func _hunter_pulse_step(s: Dictionary, node: Node) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	var via: Dictionary = target.get("via_hunter", {})
	var mirror := _object(String(via.get("id", ""))) as HunterMirror
	var want: String = String(via.get("facing", ""))
	var at: Vector2 = _px(s["at"])
	var x: float = float(s.get("x_px", at.x))
	var facing: float = float(s.get("facing", 1))
	for attempt: int in 3:
		if _pulse_done(kind, node, s):
			break
		# Ya en la celda con el cazador al alcance mirando hacia el: no se recoloca (examen del 3-3: Isak acaba de
		# aturdir de espaldas al Reflejo falso y volver a la x del camino lo dejaria al borde del alcance).
		var placed: bool = mirror != null and absf(_isak.global_position.x - at.x) <= TILE * 0.5 \
			and absf(_isak.global_position.y - at.y) < ROW_TOL and _in_pulse_range(mirror.get_hit_rect(), 0.9, facing)
		if placed:
			_set_axis(0.0)
		elif (x - _isak.global_position.x) * facing > 4.0 and absf(_isak.global_position.y - at.y) < ROW_TOL:
			if not await _walk_through(x, at.y, facing):
				return false
		elif not await _walk_to(x, at.y):
			return false
		# Tras otro pulso (el del Reflejo falso, de espaldas) Isak sigue en la pose y no se gira: se espera a que
		# pueda pulsar antes de darse la vuelta hacia el cazador.
		await _wait_can_pulse()
		if signf(_isak.facing) != signf(facing):
			await _face(facing)
		await _wait_until(func() -> bool:
			return _has_control() and _can_pulse_now() and (mirror == null or mirror.get_facing_name() == want),
			float(via.get("wait_s", 0.0)) + 1.0)
		if signf(_isak.facing) != signf(facing):
			await _face(facing)
		var seen: String = mirror.get_facing_name() if mirror != null else "?"
		_tap(A_PULSE)
		_set_axis(0.0)
		await _wait_until(func() -> bool: return _pulse_done(kind, node, s), 0.8)
		if _pulse_done(kind, node, s):
			_note("pulso reflejado por %s (mira al %s) a %s (%s)" % [via.get("id", "?"), seen, target.get("id", "?"), _where()])
			return true
		_note("paso %d: el pulso reflejado por %s (mira al %s, camino %s) no activa %s (%s; congelado %s, haz hasta %s, Isak mira %+d, puede pulsar %s)" % [_step_index,
			via.get("id", "?"), seen, want, target.get("id", "?"), _where(), mirror.is_frozen() if mirror != null else false,
			mirror.get_beam_end() if mirror != null else Vector2.ZERO, int(_isak.facing), _can_pulse_now()])
		if mirror != null and attempt < 2:
			await _settle()
			await _walk_to(x - facing * (mirror.get_track_radius_px() + TILE), at.y)
			await _wait_until(func() -> bool: return mirror.get_facing_name() == mirror.get_rest_facing_name(), 3.0)
	return _pulse_done(kind, node, s)


## Paso `wait_hunter`: quieto hasta que el espejo cazador mira hacia `target.facing`, como mucho los segundos
## del camino: el plan puede partir la espera con un pulso al Reflejo falso que se acerca (examen del 3-3,
## paso 13), y el pulso al cazador ya espera por su cuenta a la orientacion buena.
func _wait_hunter(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if absf(_isak.global_position.x - at.x) > TILE * 0.5 or absf(_isak.global_position.y - at.y) >= ROW_TOL:
		if not await _walk_to(at.x, at.y):
			return false
	_set_axis(0.0)
	var target: Dictionary = s.get("target", {})
	var mirror := _object(String(target.get("id", ""))) as HunterMirror
	var want: String = String(target.get("facing", ""))
	var turned: bool = await _wait_until(func() -> bool: return mirror == null or mirror.get_facing_name() == want,
		float(s.get("seconds", 0.0)))
	_hunter_waits += 1
	if _verbose:
		_note("espera del cazador %s: mira al %s (camino %s, %.2f s)%s" % [target.get("id", "?"),
			mirror.get_facing_name() if mirror != null else "?", want, float(s.get("seconds", 0.0)),
			"" if turned else " (aun girando)"])
	return true


## Paso `wait_reflection`: quieto hasta que la puerta de marco esta abierta.
func _wait_reflection(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(at.x, at.y):
		return false
	var target: Dictionary = s.get("target", {})
	var door := _object(String(target.get("id", ""))) as FrameDoor
	var ok: bool = await _wait_until(func() -> bool: return door == null or door.is_open(),
		float(s.get("seconds", 0.0)) + WAIT_SLACK_S)
	_reflection_waits += 1
	if _verbose or not ok:
		_note("espera del reflejo: puerta %s %s (camino %.2f s; %s)" % [target.get("id", "?"),
			"abierta" if ok else "SIN ABRIR", float(s.get("seconds", 0.0)), _where()])
	return ok


## Paso `ground_pound`: en `shot.x` mantiene move_down hasta que sale el golpe (en
## el aire, desde la cima de un salto en el sitio) y espera al final de la pose.
func _pound_step(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	var x: float = float(s.get("shot", {}).get("x", s.get("x_px", at.x)))
	if not await _walk_to(x, at.y):
		return false
	await _wait_until(func() -> bool: return _has_control() and _isak.get_ground_pound_cooldown_left() <= 0.0, 2.0)
	if bool(s.get("air", false)):
		await _press_jump()
		await _wait_until(func() -> bool: return not _isak.is_on_floor() and _isak.velocity.y >= 0.0, 1.0)
		_release_jump()
	Input.action_press(A_DOWN)
	var started: bool = await _wait_until(func() -> bool: return _isak.is_ground_pounding(),
		float(s.get("hold_s", 0.35)) + 1.0)
	Input.action_release(A_DOWN)
	if not started:
		_note("paso %d: el golpe al suelo no sale (%s; %s)" % [_step_index, String(_isak.ground_pound_denial()), _where()])
		return false
	_pounds += 1
	await _wait_until(func() -> bool: return not _isak.is_ground_pounding() and _has_control() and _isak.is_on_floor(), 3.0)
	return true


func _release_all() -> void:
	super._release_all()
	for action: StringName in [A_PINCH, A_DOWN, A_DASH]:
		Input.action_release(action)
