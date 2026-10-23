## Bot del 1-3 «No molestar» (paso 11 de docs/propuesta-1-3.md §7, 2026-10-20):
## carga la escena principal (scenes/main.tscn, LevelRunner) en el 1-3 real y
## sigue el camino que exporta tools/validate_level.py (formato isak-path/1) con
## la fisica real y las acciones del Input Map, como el bot vertical del 1-2, del
## que hereda todo (tools/tower_bot.gd: andar, saltar, pulso, laser, defensa,
## lineas importantes, wait_phase de los banners del reloj del nivel,
## replanificacion). Anade los pasos del 1-3:
## - `dash`: en el suelo (anda hasta el despegue y pulsa gesture_swipe) o aereo
##   (salto andando en el despegue y gesture_swipe `dash_after_s` despues, con la
##   direccion mantenida; despues sigue hasta aterrizar o frena en `target_x_px`).
## - `wait_beat`: quieto en su celda hasta que el metronomo (`rhythm_zone` o
##   `alarm_tunnel`) llegue al ciclo y a los segundos del ciclo del camino (si
##   llega tarde, el siguiente ciclo con esa fase).
## El interruptor «No molestar» se enciende con el pulso de espaldas del camino
## (da el dash; la linea de Eco y el aviso se cierran con ui_accept). Los
## pasillos de los banners se cruzan andando, como el camino (el validador ya
## modela la velocidad andando). Progreso de partida: el 1-2 completado (pulso,
## laser y Debug; Eco, Notas y Calc conocidos), sin el dash. Al final: terminal
## «Deslizar para desbloquear», vuelta al hub y el 1-3 en completed_levels.
## Lo lanza tools/play_dnd_bot.gd (uso y argumentos alli).
extends "res://tools/tower_bot.gd"

const DND_LEVEL_ID: String = "1-3"
const A_DASH: StringName = &"gesture_swipe"
## Sincronizacion con el camino. Tras una espera (wait_phase, wait_beat) el bot
## sale en la fase exacta del camino (compensar el arranque saliendo antes, que
## seria lo logico porque el camino supone velocidad instantanea, da MAS golpes
## medido en el 1-3: 5 con 0,06 s, 3 con 0,03 s, 1 sin adelanto); si llega tarde
## hasta LATE_TOL_S sale ya (no espera un ciclo entero dentro del pasillo de un
## banner o bajo una campana).
const LATE_TOL_S: float = 0.12
## Llegando andando a un wait_beat al que le faltan hasta MOVING_GO_S, sigue sin
## frenar (frenar y arrancar cuesta ~0,1 s).
const MOVING_GO_S: float = 0.1
## Cuadros que el bot espera en el despegue antes de saltar: el camino deja a
## Isak 0,06 s quieto en el despegue (level_plan.py, _samples) antes del arco.
const TAKEOFF_PAUSE_FRAMES: int = 4
## Esperas al compas del camino tan cortas que el bot no frena si llega en fase.
const SHORT_BEAT_S: float = 0.12

var _dashes: int = 0
var _dash_denials: PackedStringArray = []


## Despegue: como el camino, Isak llega al despegue y salta TAKEOFF_PAUSE_FRAMES
## cuadros despues (andando sigue con la direccion; de pie, quieto).
func _press_jump() -> void:
	for i: int in TAKEOFF_PAUSE_FRAMES:
		await _tick()
	await super._press_jump()


func _level_id() -> String:
	return DND_LEVEL_ID


func _bot_label() -> String:
	return "play_dnd_bot (1-3)"


func _export_args(path_file: String) -> PackedStringArray:
	return [ProjectSettings.globalize_path("res://tools/validate_level.py"), "--export-path", path_file,
		ProjectSettings.globalize_path("res://data/levels/%s.json" % DND_LEVEL_ID)]


func _path_cache_file() -> String:
	return "user://dnd_bot_path.json"


## Un jugador que acaba de completar el 1-2: pulso, laser y Debug; Eco, Notas y
## Calc conocidos; el 1-3 desbloqueado y sin el dash.
func _setup_progress() -> void:
	GameState.reset_progress()
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	for level: StringName in [&"1-1", &"1-2"]:
		GameState.mark_level_completed(level)
	GameState.unlock_level(&"1-2")
	GameState.unlock_level(&"1-3")
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()


func _check_level_loaded() -> bool:
	if _isak == null or _level == null:
		return _fail("el 1-3 no carga")
	if GameState.is_ability_obtained(GameState.ABILITY_DASH):
		return _fail("el bot empieza el 1-3 con el dash ya obtenido")
	return true


func _check_completed() -> bool:
	if not GameState.is_level_completed(&"1-3"):
		return _fail("el 1-3 no queda completado")
	if not GameState.is_ability_obtained(GameState.ABILITY_DASH):
		return _fail("el dash no queda obtenido")
	var path_dashes: int = int(_path.get("energy", {}).get("dashes", 0))
	_note("dashes %d (camino %d)%s" % [_dashes, path_dashes,
		"; denegados: %s" % ", ".join(_dash_denials) if not _dash_denials.is_empty() else ""])
	return true


## Hub tras el 1-3: llegada por el vortice, sin escenas (Calc ya conocida).
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
	_note("hub: llegada tras el 1-3 (1-3 completado %s)" % GameState.is_level_completed(&"1-3"))
	await _wait_frames(6)
	return true


## Los pasillos de los banners del 1-3 se cruzan andando, como el camino.
func _banner_chases(_from: Vector2, _to: Vector2) -> bool:
	return false


## Anda hasta `x` por la fila `feet_y` con frenada predictiva: direccion a fondo
## hasta la distancia de frenado (v^2 / 2 · ground_friction) y la friccion lo
## para alli. El camino supone velocidad instantanea; la aproximacion lenta del
## bot del 1-2 llegaba ~0,2 s tarde a cada parada y en el 1-3 los compases
## (wait_beat) y las ventanas de los banners no la admiten.
func _walk_to(x: float, feet_y: float, run: bool = false) -> bool:
	var budget: int = int(absf(x - _isak.global_position.x) / 220.0 * 60.0 * 2.0) + 120
	var used: int = 0
	_hold(A_RUN, run)
	while used < budget:
		if not _has_control():
			_set_axis(0.0)
			await _tick()
			if _isak.is_dead():
				return false
			continue
		var dx: float = x - _isak.global_position.x
		var vx: float = _isak.velocity.x
		if absf(dx) < WALK_TOL and absf(vx) < 30.0 and _isak.is_on_floor():
			break
		if _isak.is_on_floor() and absf(_isak.global_position.y - feet_y) > TILE * 0.75:
			_set_axis(0.0)
			_hold(A_RUN, false)
			return false
		var brake: float = vx * vx / (2.0 * _isak.physics.ground_friction)
		var axis: float
		if signf(vx) == signf(dx) and absf(vx) > 30.0:
			axis = 0.0 if absf(dx) <= brake + 1.0 else signf(dx)
		else:
			axis = signf(dx) * (1.0 if absf(dx) > 28.0 else (0.4 if absf(dx) > 8.0 else 0.15))
		_set_axis(axis)
		await _tick()
		used += 1
	_set_axis(0.0)
	_hold(A_RUN, false)
	await _settle()
	return absf(_isak.global_position.x - x) < WALK_TOL * 3.0 and absf(_isak.global_position.y - feet_y) < ROW_TOL


## Un dash aereo hacia `dir` despega andando: el tramo anterior no frena.
## Una espera al compas muy corta (SHORT_BEAT_S) no frena si el paso de despues sigue.
func _continues(index: int, dir: float) -> bool:
	if index < _steps.size() and String(_steps[index].get("action", "")) == "wait_beat" \
			and float(_steps[index].get("seconds", 0.0)) <= SHORT_BEAT_S:
		return _continues(index + 1, dir)
	if index < _steps.size() and String(_steps[index].get("action", "")) == "dash":
		var n: Dictionary = _steps[index]
		return float(n.get("dir", 0)) == dir and (float(n.get("takeoff_x_px", 0.0)) - _px(n["from"]).x) * dir >= -4.0
	return super._continues(index, dir)


func _do_extra_step(s: Dictionary, action: String) -> bool:
	match action:
		"dash":
			return await _dash_step(s)
		"wait_beat":
			return await _wait_beat(s)
	return await super._do_extra_step(s, action)


func _pulse_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var ok: bool = await super._pulse_step(s)
	if ok and String(target.get("type", "")) == "dnd_switch":
		_note("interruptor %s encendido con el pulso de espaldas: dash obtenido %s (%s)" % [target.get("id", "?"),
			GameState.is_ability_obtained(GameState.ABILITY_DASH), _where()])
		_shot("02_interruptor")
	return ok


# --- Dash ---

## Paso `dash` del camino. Aereo: salto andando al pasar por `takeoff_x_px` y
## gesture_swipe `dash_after_s` despues del despegue (direccion mantenida); tras
## el dash sigue hacia `dir` hasta aterrizar o, con `target_x_px`, frena alli.
## En el suelo: anda hasta el despegue y desliza. Verifica la fila de llegada.
func _dash_step(s: Dictionary) -> bool:
	var dir: float = float(s.get("dir", 1))
	var from: Vector2 = _px(s["from"])
	var to: Vector2 = _px(s["to"])
	var takeoff: float = float(s.get("takeoff_x_px", from.x))
	var air: bool = bool(s.get("air", false))
	var after_target: Variant = s.get("target_x_px", null)
	if DebugMode.is_active():
		await _debug_off()
	if not await _wait_dash_ready():
		_note("paso %d: el dash no esta listo (%s; energia %.0f)" % [_step_index, String(_isak.dash_denial()),
			GameState.debug_energy])
		return false
	# Carrerilla hasta el despegue (andando, como el camino).
	var moving: bool = _isak.velocity.x * dir > 150.0 and (takeoff - _isak.global_position.x) * dir > 0.0
	var back: float = takeoff - dir * 26.0
	if air and not moving and (_isak.global_position.x - back) * dir > 0.0 and _ground_at(back, from.y):
		if not await _walk_to(back, from.y):
			return false
	var limit: int = 240
	while limit > 0 and (takeoff - _isak.global_position.x) * dir > 2.0:
		if not _has_control():
			await _tick()
			continue
		if not _isak.is_on_floor() or absf(_isak.global_position.y - from.y) > ROW_TOL:
			_set_axis(0.0)
			return false
		_set_axis(dir)
		await _tick()
		limit -= 1
	var energy_before: float = GameState.debug_energy
	if air:
		await _press_jump()
		var frames: int = roundi(float(s.get("dash_after_s", 0.2)) * 60.0)
		var held: int = 0
		while held < frames:
			_set_axis(dir)
			if held >= 6 and Input.is_action_pressed(A_JUMP) and _isak.velocity.y >= 0.0:
				_release_jump()
			await _tick()
			if not get_tree().paused:
				held += 1
	_set_axis(dir)
	var cooling: int = 60
	while cooling > 0 and _isak.get_dash_cooldown_left() > 0.0:
		await _tick()
		cooling -= 1
	_tap(A_DASH)
	var started: bool = await _wait_until(func() -> bool: return _isak.is_dashing(), 0.1)
	_release_jump()
	if not started:
		var reason: String = String(_isak.dash_denial())
		_dash_denials.append("%d:%s" % [_step_index, reason])
		_note("paso %d: el dash no sale (%s; %s; energia %.0f)" % [_step_index, reason, _where(), GameState.debug_energy])
		_set_axis(0.0)
		return false
	_dashes += 1
	# Energia justo despues de cobrar el dash (Isak.begin_dash): la del aterrizaje puede incluir
	# recogidas del camino (en el 2-1, el punto de atencion de la fragil del medio da +10).
	var energy_dash: float = GameState.debug_energy
	if _dashes == 1:
		_shot("03_primer_dash", 4)
	# Durante el dash y tras el: direccion hasta aterrizar o frena en el objetivo.
	var budget: int = 60 * 3
	var left_floor: bool = not _isak.is_on_floor()
	while budget > 0:
		if not _has_control():
			await _tick()
			if _isak.is_dead():
				return false
			budget -= 1
			continue
		var dashing: bool = _isak.is_dashing()
		if not _isak.is_on_floor():
			left_floor = true
		elif not dashing and (left_floor or not air):
			break
		var axis: float = dir
		if not dashing and after_target != null:
			var vx: float = _isak.velocity.x
			var err: float = float(after_target) - (_isak.global_position.x + vx * absf(vx) / (2.0 * _isak.physics.air_acceleration))
			axis = clampf(err / 16.0, -1.0, 1.0) if absf(err) > 2.0 else 0.0
		elif not dashing and _isak.is_on_floor():
			axis = 0.0
		_set_axis(axis)
		await _tick()
		budget -= 1
	_set_axis(0.0)
	var ok: bool = _isak.is_on_floor() and absf(_isak.global_position.y - to.y) < ROW_TOL \
		and (_isak.global_position.x - (to.x - dir * TILE)) * dir > 0.0
	_note("dash %d (%s) de x=%.0f: llega a %s (energia %.0f -> %.0f al deslizar, %.0f al aterrizar; golpes %d)" % [
		_dashes, "aereo" if air else "suelo", takeoff, _where(), energy_before, energy_dash, GameState.debug_energy, _hits])
	if not ok:
		_note("paso %d (dash): aterriza en %s, se esperaba la celda %s" % [_step_index, _where(), str(s["to"].get("cell", "?"))])
	return ok


## Espera a que el dash pueda salir (enfriamiento, poses); denegaciones que no
## se arreglan esperando (habilidad, energia) cortan.
func _wait_dash_ready() -> bool:
	var limit: int = 90
	while limit > 0:
		if _has_control() and _isak.is_on_floor():
			var reason: StringName = _isak.dash_denial()
			# El enfriamiento se espera justo antes de pulsar gesture_swipe: esperarlo aqui, con la inercia del paso
			# anterior, pasaba el despegue y obligaba a volver atras (tunel del 1-3, 2026-10-20).
			if reason == &"" or reason == Isak.DASH_DENIED_COOLDOWN:
				return true
			if reason == Isak.DASH_DENIED_LOCKED or reason == Isak.DASH_DENIED_ENERGY:
				return false
		await _tick()
		limit -= 1
	return false


# --- Compas ---

## Paso `wait_beat`: el metronomo `rhythm` debe estar, al salir, en el ciclo
## `beat.cycle` a `beat.cycle_time_s` segundos. Si el bot llega andando y le
## falta poco (MOVING_GO_S) o llega algo tarde, sigue sin frenar; si no, frena y
## sale en la fase del camino. Mas de LATE_TOL_S tarde: el ciclo siguiente.
func _wait_beat(s: Dictionary) -> bool:
	return await _wait_beat_on(s, _object(String(s.get("rhythm", ""))) as RhythmZone)


## `_wait_beat` con el metronomo ya resuelto (el bot del feed le pasa el reloj
## propio de una Historia).
func _wait_beat_on(s: Dictionary, zone: RhythmZone) -> bool:
	var at: Vector2 = _px(s["at"])
	if zone == null:
		_note("paso %d: no hay metronomo %s; espera %.2f s" % [_step_index, s.get("rhythm", "?"), float(s.get("seconds", 0.0))])
		if not await _walk_to(at.x, at.y):
			return false
		await _wait_s(float(s.get("seconds", 0.0)))
		return true
	var beat: Dictionary = s.get("beat", {})
	var want_cycle: int = int(beat.get("cycle", 0))
	var want_t: float = float(beat.get("cycle_time_s", 0.0))
	var arrive: String = "ciclo %d a %.2f s" % [zone.get_cycle_count(), zone.get_cycle_time()]
	var moving: bool = absf(_isak.velocity.x) > 100.0 and absf(_isak.global_position.x - at.x) < TILE
	var remaining: float = _beat_remaining(zone, want_cycle, want_t)
	var late_cycles: int = 0
	var go: bool = moving and remaining <= MOVING_GO_S and remaining >= -LATE_TOL_S
	if not go:
		if moving:
			# Frena donde esta (volver a la celda costaria mas).
			_set_axis(0.0)
			await _settle()
		elif not await _walk_to(at.x, at.y):
			return false
		var limit: int = int((zone.get_cycle_s() * 3.0 + 2.0) * 60.0)
		while limit > 0:
			remaining = _beat_remaining(zone, want_cycle, want_t)
			if zone.is_started() and remaining < -LATE_TOL_S:
				want_cycle += 1
				late_cycles += 1
				continue
			if zone.is_started() and remaining <= 0.0:
				break
			await _tick()
			limit -= 1
		if limit <= 0:
			_note("paso %d: el metronomo %s no llega a la fase del camino" % [_step_index, zone.name])
			return false
	if _verbose or late_cycles > 0:
		_note("compas %s: llega en el %s; sale en el ciclo %d a %.2f s (camino: ciclo %d a %.2f s; %s%d ciclo(s) de espera de mas, ciclo de %.1f s)" % [
			zone.name, arrive, zone.get_cycle_count(), zone.get_cycle_time(), int(beat.get("cycle", 0)), want_t,
			"sin frenar; " if go else "", late_cycles, zone.get_cycle_s()])
	return true


## Segundos hasta el ciclo `cycle` a `t` s del metronomo (negativo: ya paso).
func _beat_remaining(zone: RhythmZone, cycle: int, t: float) -> float:
	if not zone.is_started():
		return INF
	return float(cycle - zone.get_cycle_count()) * zone.get_cycle_s() + t - zone.get_cycle_time()


## wait_phase de los banners del reloj del nivel: como el del bot del 1-2 (sale en
## el primer cuadro en o tras la fase del camino), pero si llega hasta LATE_TOL_S
## tarde sale ya en vez de esperar un ciclo entero.
func _wait_phase(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(at.x, at.y):
		return false
	var want: Dictionary = s.get("banner_cycle_s", {})
	var period: float = float(s.get("period_s", 3.0))
	var ref: SpamBanner = null
	var ref_t: float = 0.0
	for id: String in want:
		ref = _enemy(id) as SpamBanner
		if ref != null:
			ref_t = float(want[id])
			break
	if ref == null:
		await _wait_s(float(s.get("seconds", 0.0)))
		return true
	var ok: bool = await _wait_until(func() -> bool:
		var r: float = fposmod(ref_t - ref.get_cycle_time(), period)
		if r > period - LATE_TOL_S:
			r -= period
		return r <= 0.0, period * 2.0)
	if _verbose:
		_note("fase de %s: sale a %.2f s del ciclo (camino %.2f s)" % [ref.name, ref.get_cycle_time(), ref_t])
	if not ok:
		_note("paso %d: no se encuentra la fase de los banners" % _step_index)
	return ok

