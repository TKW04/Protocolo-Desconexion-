## Bot del chat (Mundo 4 «El Chat»; paso 12 de docs/propuesta-mundo-4.md §8 y
## §7.3, 2026-10-28): carga la escena principal (scenes/main.tscn, LevelRunner)
## en el nivel real (--level 4-1; 4-1 por defecto; tambien las salas *_test del
## Mundo 4) y sigue el camino que exporta tools/validate_level.py (formato
## isak-path/1) con la fisica real y las acciones del Input Map, nunca Q ni Esc.
## Extiende el bot de la galeria (tools/gallery_bot.gd: likes inertes aqui,
## Pellizcar, pulsos a enemigos), que extiende el del 1-3 (tools/dnd_bot.gd: dash
## y Debug) y, por su base tools/tower_bot.gd, recorre tambien la torre del 4-1.
## Anade los pasos del Mundo 4:
## - `pulse_seen`: en la x del camino, mirando al doble check, pulsa; hecho cuando
##   la zona «Visto» queda interrumpida (4 s del mundo para cruzarla).
## - `wait_typing`: quieto en la celda de despegue hasta que la «escribiendo…»
##   es solida (como mucho lo que dice el camino + WAIT_SLACK_S).
## - `wait` del hueco de una zona «Visto» con ciclo (el camino espera el peor caso,
##   off_s + on_s): espera esos segundos y, si al terminar la zona esta activa o
##   avisando, hasta que se apague; asi el bot no tarda menos que el camino.
## - `wait_autocorrect`: quieto hasta que el autocorrector se corrige.
## - `wait_ghost` y el pulso al Fantasma: el validador lo dispara con su caja
##   ampliada por la patrulla (antes que el Fantasma real, que mira la distancia de
##   centro a centro), asi que el bot no espera a ciegas: si se ve y esta a tiro,
##   pulso; si patrulla cerca de la fila de Isak, se acerca andando hasta que se
##   esfuma; oculto, espera; al reaparecer (aviso), se gira y pulsa. Si patrulla
##   lejos o en otra banda, no se ha activado y el bot sigue (paso 13).
## - `shake` (Agitar, U / LB): el validador ya no lo genera (Agitar retirado el
##   2026-10-28); si llegara, el bot pulsa gesture_shake y lo da por hecho aunque no
##   salga la onda.
## - pulso a un enemigo del Mundo 4 (`troll`, `ghost`, `sticker`, `troll_mimic`):
##   el mismo paso que los del Mundo 3 (en la x del camino, mirando hacia el,
##   espera a tenerlo al alcance y pulsa; hecho aturdido o derrotado). La defensa
##   de cada cuadro pulsa ademas al Troll que avisa si se pone al alcance.
## - Sticker (2026-10-28, peligros ocultos del Modo oscuro: los acechadores): la
##   espera del camino a que llegue (`wait` con target sticker) termina en cuanto se
##   infla o ya esta al alcance (si el bot llega tarde, p. ej. tras el cargador, el
##   Sticker no explota mientras espera); si ya esta al alcance al empezar el pulso,
##   el bot se gira y pulsa sin volver a la x del camino; y la defensa pulsa al
##   Sticker que se infla delante.
## Comprobaciones (§7.3): completa el nivel y vuelve al hub con el en
## completed_levels; 0 muertes; 0 congelaciones (en el 4-1 no hay ninguna
## obligatoria); recoge la Linterna si el nivel la tiene; anota golpes, energia
## minima frente al camino y la duracion de juego frente al objetivo
## (target_duration_s): debe quedar entre el 40 y el 55 % (§4). Progreso de
## partida: La Curadora vencida, la actualizacion del hub instalada y todo el kit
## del Mundo 3 (pulso, laser, Debug, dash, golpe al suelo y Pellizcar; Eco, Notas y
## Calc conocidos; desde el 4-2 tambien la Linterna, que se recoge en el 4-1); sin
## Agitar (retirado el 2026-10-28) en ningun nivel: el bot falla si sale una onda.
## Lo lanza tools/play_chat_bot.gd (uso y argumentos alli).
extends "res://tools/gallery_bot.gd"

const CHAT_LEVELS: PackedStringArray = ["4-1", "4-2", "4-3"]
const A_SHAKE: StringName = &"gesture_shake"
const WORLD4_ENEMIES: PackedStringArray = ["troll", "troll_mimic", "ghost", "sticker"]
const UPGRADE_4_6: StringName = &"hub_update_4_6"
## Banda de la duracion de juego frente al objetivo (§4 de la propuesta).
const RATIO_MIN: float = 0.40
const RATIO_MAX: float = 0.55
## Fantasma: segundos como mucho por encuentro y tiles de mas que el bot se acerca a su alcance.
const GHOST_MAX_S: int = 8
const GHOST_APPROACH_TILES: float = 3.0
## Agitar contra un enemigo: px que el bot se acerca respecto a la x del camino.
const SHAKE_CLOSER_PX: float = 16.0

var _freezes: int = 0
var _freeze_watch: bool = false
var _seen_pulses: int = 0
var _typing_waits: int = 0
var _zone_waits: int = 0
var _zone_wait_s: float = 0.0
var _shakes: int = 0
## Ondas de Agitar que han salido (debe ser 0: Agitar esta retirado).
var _stray_shakes: int = 0
var _troll_pulses: int = 0
var _target_s: float = 0.0
var _has_lamp: bool = false


func _ready() -> void:
	_gallery_level = "4-1"
	super._ready()


func _level_problem() -> String:
	var file: String = "res://data/levels/%s.json" % _gallery_level
	if not CHAT_LEVELS.has(_gallery_level) and not _gallery_level.ends_with("_test"):
		return "nivel desconocido: %s (usa --level 4-1|4-2|4-3 o una sala *_test del Mundo 4)" % _gallery_level
	if not FileAccess.file_exists(file):
		return "el %s aun no existe (data/levels/%s.json)" % [_gallery_level, _gallery_level]
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not data is Dictionary or int((data as Dictionary).get("world", 0)) != 4:
		return "el %s no es un nivel del Mundo 4" % _gallery_level
	_target_s = float((data as Dictionary).get("target_duration_s", 0.0))
	return ""


func _is_test_room() -> bool:
	return not CHAT_LEVELS.has(_gallery_level)


func _bot_label() -> String:
	return "play_chat_bot (%s)" % _gallery_level


func _path_cache_file() -> String:
	return "user://chat_bot_path_%s.json" % _gallery_level


## Quien acaba de vencer a La Curadora e instalar la actualizacion del hub (y, para
## el 4-2 y el 4-3, de completar los niveles anteriores del Mundo 4).
func _setup_progress() -> void:
	GameState.reset_progress()
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	if _gallery_level in ["4-2", "4-3"]:
		GameState.meet_ally(GameState.ALLY_LINTERNA)
	var abilities: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
		GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS]
	for ability: StringName in abilities:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	for level: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss"]:
		GameState.unlock_level(level)
		GameState.mark_level_completed(level)
	GameState.install_hub_upgrade(UPGRADE_4_6)
	for level: String in CHAT_LEVELS:
		GameState.unlock_level(StringName(level))
		if level == _gallery_level:
			break
		GameState.mark_level_completed(StringName(level))
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()


func _check_level_loaded() -> bool:
	if _isak == null or _level == null:
		return _fail("el %s no carga" % _gallery_level)
	if _gallery_level == "4-1" and _isak.camera_mode != Isak.CAMERA_TOWER:
		return _fail("el 4-1 no carga con la camara de torre")
	if GameState.is_ability_obtained(GameState.ABILITY_SHOCKWAVE):
		return _fail("el bot empieza el %s con Agitar ya obtenido (retirado)" % _gallery_level)
	EventBus.shockwave_fired.connect(func(_c: Vector2, _r: float, _s: Node2D) -> void: _stray_shakes += 1)
	_has_lamp = _level_has(FlashlightPickup)
	return true


func _check_completed() -> bool:
	if not _is_test_room() and not GameState.is_level_completed(StringName(_gallery_level)):
		return _fail("el %s no queda completado" % _gallery_level)
	var game_s: float = (_terminal_frames if _terminal_frames >= 0 else _play_frames) / 60.0
	var ratio: float = game_s / _target_s if _target_s > 0.0 else 0.0
	var lamp: bool = _has_lamp
	_note("CHAT: muertes %d, golpes %d, congelaciones %d, pulsos al doble check %d, esperas de «escribiendo…» %d, esperas de zonas con ciclo %d (%.1f s), pulsos al Troll %d, Agitar %d, dashes %d; Linterna %s; duracion %.1f s de %d s del objetivo (%.0f %%)" % [
		_deaths, _hits, _freezes, _seen_pulses, _typing_waits, _zone_waits, _zone_wait_s, _troll_pulses, _shakes,
		_dashes, "conocida" if GameState.has_met_ally(GameState.ALLY_LINTERNA) else "sin conocer", game_s,
		int(_target_s), ratio * 100.0])
	if _deaths > 0:
		return _fail("Isak muere %d vez/veces" % _deaths)
	if _freezes > 0:
		return _fail("Isak se congela %d vez/veces (ninguna es obligatoria)" % _freezes)
	if _stray_shakes > 0:
		return _fail("sale %d onda(s) de Agitar (retirado el 2026-10-28)" % _stray_shakes)
	if lamp and not GameState.has_met_ally(GameState.ALLY_LINTERNA):
		return _fail("el bot no recoge la Linterna")
	if not _is_test_room() and _target_s > 0.0 and (ratio < RATIO_MIN or ratio > RATIO_MAX):
		return _fail("la duracion (%.1f s) queda fuera del %.0f-%.0f %% del objetivo (%d s)" % [game_s,
			RATIO_MIN * 100.0, RATIO_MAX * 100.0, int(_target_s)])
	return true


## Tolerancia frente a la duracion del camino: la de siempre mas las esperas que el camino cuenta por el peor caso
## y el bot acorta (paso 13): el hueco de cada zona «Visto» con ciclo (off_s + on_s; el bot sale al apagarse) y la
## espera de cada Fantasma (2,05 s; el bot lo pulsa en cuanto se pone a tiro).
func _duration_tolerance_s() -> float:
	var slack: float = 0.0
	for step: Dictionary in _path.get("steps", []):
		var action: String = String(step.get("action", ""))
		if action == "wait_ghost" or (action == "wait" and String(step.get("reason", "")).find("zona «Visto»") >= 0):
			slack += float(step.get("duration_s", step.get("seconds", 0.0)))
	return super._duration_tolerance_s() + slack


## Hub tras un nivel del chat: llegada por el vortice, sin escenas (Calc conocida); la carpeta M4 sigue abierta.
func _hub() -> bool:
	if not await super._hub():
		return false
	var m4: Dictionary = HubWorlds.world(&"m4")
	_note("hub: carpeta M4 %s; %s completado %s" % [String(HubWorlds.folder_state(m4)), _gallery_level,
		GameState.is_level_completed(StringName(_gallery_level))])
	return true


## Enemigos del nivel sin los proyectiles del Troll (TrollMessage cuelga de Enemies y no tiene get_state).
func _enemies() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in super._enemies():
		if not node is TrollMessage:
			out.append(node)
	return out


func _level_has(cls: Variant) -> bool:
	if not is_instance_valid(_level):
		return false
	for node: Node in _level.get_node(^"Objects").get_children():
		if is_instance_of(node, cls):
			return true
	return false


# --- Servicios de cada cuadro ---

func _refresh() -> void:
	super._refresh()
	if _freeze_watch or _isak == null:
		return
	_freeze_watch = true
	_isak.frozen_started.connect(func(seconds: float, source: StringName) -> void:
		_freezes += 1
		_note("CONGELADO %.1f s por %s (%s)" % [seconds, String(source), _where()]))


## Defensa: el Troll que avisa (va a escribir) al alcance del pulso -> pulso. Si
## no, la defensa de la galeria.
func _guard() -> void:
	if _guard_lock == 0 and _has_control() and _can_pulse_now() and is_instance_valid(_level):
		for node: Node in _level.get_node(^"Enemies").get_children():
			if node is Sticker and (node as Sticker).is_inflating() \
					and _in_pulse_range((node as Sticker).get_body_rect(), 0.9, _isak.facing):
				_tap(A_PULSE)
				_guard_lock = 4
				_guard_pulses += 1
				_note("defensa: pulso a %s que se infla (%s)" % [node.name, _where()])
				return
			if not node is Troll or not (node as Troll).is_warning():
				continue
			if _in_pulse_range((node as Troll).get_body_rect(), 0.9, _isak.facing):
				_tap(A_PULSE)
				_guard_lock = 4
				_guard_pulses += 1
				_note("defensa: pulso a %s que escribe (%s)" % [node.name, _where()])
				return
	super._guard()


# --- Pasos ---

func _do_extra_step(s: Dictionary, action: String) -> bool:
	match action:
		"pulse_seen":
			return await _pulse_seen_step(s)
		"wait_typing":
			return await _wait_typing(s)
		"wait_autocorrect":
			return await _wait_autocorrect(s)
		"wait_ghost":
			return await _ghost_step(s)
		"shake":
			return await _shake_step(s)
	return await super._do_extra_step(s, action)


func _pulse_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	if kind == "troll":
		var troll := _object(String(target.get("id", ""))) as Troll
		var done: bool = await _troll_pulse_step(s, troll)
		if done:
			_troll_pulses += 1
		return done
	if kind == "ghost":
		return await _ghost_step(s)
	if kind == "sticker":
		var sticker := _object(String(target.get("id", ""))) as Sticker
		if sticker != null and await _sticker_pulse_now(sticker):
			return true
	if kind in WORLD4_ENEMIES:
		return await _enemy_pulse_step(s, _object(String(target.get("id", ""))))
	return await super._pulse_step(s)


## Pulso al Troll: se planta a 0,7 radios de pulso de su cuerpo (la x del camino, la primera de la celda desde la
## que el validador ve que llega, deja al Troll en el borde del alcance) y pulsa en cuanto puede; si un mensaje lo
## empuja, vuelve a acercarse.
func _troll_pulse_step(s: Dictionary, troll: Troll) -> bool:
	if troll == null or troll.is_stunned() or troll.is_defeated():
		return true
	var at: Vector2 = _px(s["at"])
	var radius: float = _isak.abilities.pulse_radius_px
	var origin: float = absf(_isak.pulse_effect_origin.x)
	for attempt: int in 4:
		var rect: Rect2 = troll.get_body_rect()
		var dir: float = signf(rect.get_center().x - _isak.global_position.x)
		if dir == 0.0:
			dir = float(s.get("facing", 1))
		var x: float = rect.position.x - origin - radius * 0.7 if dir > 0.0 else rect.end.x + origin + radius * 0.7
		if absf(_isak.global_position.x - x) > 6.0 and not await _walk_to(x, at.y):
			return false
		_set_axis(0.0)
		await _face(dir)
		await _wait_can_pulse()
		if troll.is_stunned() or troll.is_defeated():
			break
		if _in_pulse_range(troll.get_body_rect(), 0.95, _isak.facing):
			_tap(A_PULSE)
			await _wait_until(func() -> bool: return troll.is_stunned() or troll.is_defeated(), 0.5)
			if troll.is_stunned() or troll.is_defeated():
				break
	var ok: bool = troll.is_stunned() or troll.is_defeated()
	if ok:
		_enemy_pulses += 1
	_note("pulso a troll %s: %s (%s)" % [troll.name, String(troll.get_state()) if ok else "SIN EFECTO", _where()])
	return ok


## Sticker ya al alcance del pulso (por cualquier lado): se gira y pulsa sin volver a la
## x del camino (si el dash lo dejo una celda mas alla, volver lo saca del alcance y
## el Sticker explota). Falso si no esta al alcance o no queda aturdido / derrotado.
func _sticker_pulse_now(sticker: Sticker) -> bool:
	if sticker.is_stunned() or sticker.is_defeated():
		return true
	var rect: Rect2 = sticker.get_body_rect()
	var dir: float = signf(rect.get_center().x - _isak.global_position.x)
	if dir == 0.0 or not _in_pulse_range(rect, 0.9, dir):
		return false
	_set_axis(0.0)
	await _face(dir)
	await _wait_can_pulse()
	if not _in_pulse_range(sticker.get_body_rect(), 0.9, _isak.facing):
		return false
	_tap(A_PULSE)
	await _wait_until(func() -> bool: return sticker.is_stunned() or sticker.is_defeated(), 0.5)
	var ok: bool = sticker.is_stunned() or sticker.is_defeated()
	if ok:
		_enemy_pulses += 1
		_note("pulso a sticker %s al alcance: %s (%s)" % [sticker.name, String(sticker.get_state()), _where()])
	return ok


## Fantasma (`wait_ghost` y el pulso que le sigue): ver la cabecera. Hecho aturdido, derrotado o sin activar.
func _ghost_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var ghost := _object(String(target.get("id", ""))) as Ghost
	if ghost == null:
		return _fail("paso %d: no hay Fantasma %s" % [_step_index, target.get("id", "?")])
	if ghost.is_stunned() or ghost.is_defeated():
		return true
	var start: int = _play_frames
	var frames: int = GHOST_MAX_S * 60
	var engaged: bool = false
	while frames > 0:
		if ghost.is_stunned() or ghost.is_defeated():
			break
		var rect: Rect2 = ghost.get_body_rect()
		var dx: float = rect.get_center().x - _isak.global_position.x
		var dir: float = signf(dx) if dx != 0.0 else float(_isak.facing)
		var state: StringName = ghost.get_state()
		if state != Ghost.STATE_PATROL:
			engaged = true
		if ghost.is_visible_ghost() and _has_control() and _can_pulse_now() and _in_pulse_range(rect, 0.9, dir):
			_set_axis(0.0)
			if signf(_isak.facing) != dir:
				await _face(dir)
			if _in_pulse_range(ghost.get_body_rect(), 0.95, _isak.facing):
				_tap(A_PULSE)
				await _wait_until(func() -> bool: return ghost.is_stunned() or ghost.is_defeated(), 0.4)
			continue
		if state == Ghost.STATE_PATROL:
			var dy: float = absf(rect.end.y - _isak.global_position.y)
			if dy > TILE * 1.5 or absf(dx) > (ghost.detect_tiles + GHOST_APPROACH_TILES) * TILE:
				_set_axis(0.0)
				_note("Fantasma %s sin activar (%s; a %+.0f px): sigue" % [ghost.name, _where(), dx])
				return true
			_set_axis(dir * 0.5)
		else:
			_set_axis(0.0)
			if (state == Ghost.STATE_WARN or state == Ghost.STATE_READY) and signf(_isak.facing) != dir:
				await _face(dir)
				continue
		await _tick()
		if not get_tree().paused:
			frames -= 1
	_set_axis(0.0)
	var ok: bool = ghost.is_stunned() or ghost.is_defeated()
	if ok:
		_enemy_pulses += 1
	_note("Fantasma %s: %s tras %.1f s (%s; %s)" % [ghost.name, String(ghost.get_state()) if ok else "SIN ATURDIR",
		(_play_frames - start) / 60.0, "se activo" if engaged else "sin activarse", _where()])
	return ok


func _pulse_done(kind: String, node: Node, s: Dictionary) -> bool:
	if node != null and kind in WORLD4_ENEMIES:
		return bool(node.call(&"is_stunned")) or bool(node.call(&"is_defeated"))
	return super._pulse_done(kind, node, s)


## Espera del camino: la de una zona «Visto» con ciclo (`reason`; el camino espera el peor caso, off_s + on_s)
## espera en el sitio a que la zona SE APAGUE (flanco de bajada: queda todo el hueco, off_s menos el aviso, para
## cruzarla); si ya estaba apagada, a que se encienda y se vuelva a apagar. Las demas esperas, las de siempre.
func _wait_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	if String(target.get("type", "")) == "sticker":
		var sticker := _object(String(target.get("id", ""))) as Sticker
		if sticker != null:
			_set_axis(0.0)
			await _wait_until(func() -> bool:
				return sticker.is_inflating() or sticker.is_stunned() or sticker.is_defeated() \
					or _in_pulse_range(sticker.get_body_rect(), 0.9, signf(sticker.get_body_rect().get_center().x - _isak.global_position.x)),
				float(s.get("seconds", 0.0)) + WAIT_SLACK_S)
			return true
	var zone := _zone_for_wait(s)
	if zone == null:
		return await super._wait_step(s)
	var at: Vector2 = _px(s["at"])
	if absf(_isak.global_position.x - at.x) > TILE * 0.5 or absf(_isak.global_position.y - at.y) >= ROW_TOL:
		if not await _walk_to(at.x, at.y):
			return false
	_set_axis(0.0)
	var start: int = _play_frames
	var off := func() -> bool:
		return zone.get_state() == SeenZone.State.WAITING or zone.get_state() == SeenZone.State.INTERRUPTED
	if off.call():
		await _wait_until(func() -> bool: return not off.call(), zone.get_period() + 1.0)
	var ok: bool = await _wait_until(off, zone.get_period() + 1.0)
	_zone_waits += 1
	_zone_wait_s += (_play_frames - start) / 60.0
	if _verbose or not ok:
		_note("espera de la zona «Visto» %s: %s tras %.1f s (camino %.1f s; %s)" % [zone.name,
			"apagada" if ok else "SIN APAGARSE", (_play_frames - start) / 60.0, float(s.get("seconds", 0.0)), _where()])
	return ok


func _zone_for_wait(s: Dictionary) -> SeenZone:
	var reason: String = String(s.get("reason", ""))
	var at: int = reason.find("zona «Visto» ")
	if at < 0:
		return null
	var id: String = reason.substr(at + "zona «Visto» ".length()).strip_edges()
	return _object(id) as SeenZone


## Paso `pulse_seen`: pulso al doble check de una zona «Visto» desde la x del camino.
func _pulse_seen_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var zone := _object(String(target.get("id", ""))) as SeenZone
	if zone == null:
		return _fail("paso %d: no hay zona «Visto» %s" % [_step_index, target.get("id", "?")])
	var at: Vector2 = _px(s["at"])
	var x: float = _outside_zone_x(zone, float(s.get("x_px", at.x)))
	var facing: float = signf(zone.get_icon_rect().get_center().x - x)
	if facing == 0.0:
		facing = float(s.get("facing", 1))
	if not await _walk_to(x, at.y):
		return false
	_set_axis(0.0)
	for attempt: int in 3:
		if zone.is_interrupted():
			break
		await _face(facing)
		await _wait_can_pulse()
		var reach: bool = _in_pulse_range(zone.get_icon_rect(), 1.0, _isak.facing)
		if not reach:
			await _face(-facing)
			reach = _in_pulse_range(zone.get_icon_rect(), 1.0, _isak.facing)
		_tap(A_PULSE)
		await _wait_until(func() -> bool: return zone.is_interrupted(), 0.5)
	var ok: bool = zone.is_interrupted()
	if ok:
		_seen_pulses += 1
		if _seen_pulses == 1:
			_shot("08_pulso_visto", 4)
	_note("pulso al doble check de %s: %s (%s)" % [zone.name, "interrumpida %.1f s" % zone.get_interrupt_left()
		if ok else "SIN EFECTO", _where()])
	return ok


## x de los pies desde la que se pulsa al doble check sin que el cuerpo toque la zona: la x del camino
## (tools/world4_model.py elige la primera de la celda que llega al check, que puede quedar pegada a la zona y
## congelar a Isak al pararse) apartada lo justo (media caja de Isak + 6 px) del lado por el que se llega.
func _outside_zone_x(zone: SeenZone, x: float) -> float:
	var r: Rect2 = zone.get_zone_rect()
	var half: float = _isak.get_hitbox_size().x * 0.5 + 6.0
	if x >= r.get_center().x:
		return maxf(x, r.end.x + half)
	return minf(x, r.position.x - half)


## Paso `wait_typing`: quieto en la celda de despegue hasta que la «escribiendo…» es solida.
func _wait_typing(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if absf(_isak.global_position.x - at.x) > TILE * 0.5 or absf(_isak.global_position.y - at.y) >= ROW_TOL:
		if not await _walk_to(at.x, at.y):
			return false
	_set_axis(0.0)
	var target: Dictionary = s.get("target", {})
	var typing := _object(String(target.get("id", ""))) as TypingBubble
	var ok: bool = await _wait_until(func() -> bool: return typing == null or typing.is_solid(),
		float(s.get("seconds", 0.0)) + WAIT_SLACK_S)
	_typing_waits += 1
	if _typing_waits == 1:
		_shot("05_escribiendo", 2)
	if _verbose or not ok:
		_note("«escribiendo…» %s: %s (camino %.2f s; %s)" % [target.get("id", "?"), "solida" if ok else "SIN APARECER",
			float(s.get("seconds", 0.0)), _where()])
	return ok


## Paso `wait_autocorrect`: quieto hasta que el autocorrector se corrige.
func _wait_autocorrect(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(at.x, at.y):
		return false
	_set_axis(0.0)
	var node := _object(String(s.get("target", {}).get("id", "")))
	var ok: bool = await _wait_until(func() -> bool:
		return node == null or not node.has_method(&"is_corrected") or bool(node.call(&"is_corrected")),
		float(s.get("seconds", 0.75)) + WAIT_SLACK_S)
	return ok


## Paso `shake`: Agitar en la x del camino (gesture_shake, en el suelo). Contra un enemigo (Troll, Sticker,
## Fantasma) el validador da la primera x desde la que la onda lo alcanza con el celular hacia cualquier lado
## (al borde del radio): el bot se acerca SHAKE_CLOSER_PX mas y se gira hacia el antes de agitar (paso 13).
func _shake_step(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	var x: float = float(s.get("shot", {}).get("x", s.get("x_px", at.x)))
	var target := _object(String(s.get("target", {}).get("id", "")))
	var dir: float = 0.0
	if target != null and String(s.get("target", {}).get("type", "")) in WORLD4_ENEMIES \
			and target.has_method(&"get_body_rect"):
		var rect: Rect2 = target.call(&"get_body_rect")
		dir = signf(rect.get_center().x - x)
		x += dir * SHAKE_CLOSER_PX
	if not await _walk_to(x, at.y):
		return false
	_set_axis(0.0)
	if dir != 0.0 and signf(_isak.facing) != dir:
		await _face(dir)
	await _wait_until(func() -> bool: return _has_control() and _isak.is_on_floor(), 2.0)
	var fired: Array[bool] = [false]
	var on_fire := func(_c: Vector2, _r: float, _src: Node) -> void: fired[0] = true
	EventBus.shockwave_fired.connect(on_fire)
	_tap(A_SHAKE)
	var ok: bool = await _wait_until(func() -> bool: return fired[0], 1.0)
	EventBus.shockwave_fired.disconnect(on_fire)
	if ok:
		_shakes += 1
	_note("Agitar %s (%s; energia %.0f)" % ["sale" if ok else "NO SALE", _where(), GameState.debug_energy])
	await _wait_until(func() -> bool: return _has_control() and _isak.get_state_name() != PlayerState.SHOCKWAVE, 1.5)
	return ok


func _release_all() -> void:
	super._release_all()
	Input.action_release(A_SHAKE)
