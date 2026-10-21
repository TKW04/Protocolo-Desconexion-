# Subidas del 1-2 con el Isak REAL (2026-10-17, ajuste tras probarlo el usuario:
# «en algunos tramos Isak choca con el techo»). Lee las subidas que lista
# tools/level_climbs.py (tests/fixtures/climbs_1-2.json: cada par de repisas
# que el validador une con un salto hacia arriba) y, en la escena generada
# scenes/levels/1-2.tscn (sin enemigos, con los puentes extendidos, los
# recordatorios quietos y las plataformas ocultas solidas solo en las subidas
# con Debug), ejecuta cada salto con la fisica real, paso a paso a 60 Hz:
#   - despegue: desde parado en la x de despegue del validador;
#   - atras: llegando andando o corriendo desde dos tiles atras (o lo que deje
#     la repisa) y saltando al pasar por esa x;
#   - coyote: saliendo andando del borde de la repisa y saltando 4 cuadros
#     despues (solo si la repisa termina en el borde de despegue);
# cada uno andando y corriendo, soltando la direccion al pasar por la x
# objetivo. Mide si aterriza en la repisa objetivo, si la cabeza toca un techo
# (is_on_ceiling al subir), la holgura vertical minima entre la cabeza y el
# solido de encima mientras sube (CEILING_MARGIN_PX, el mismo margen que
# validation.ceiling_margin_px del validador) y la horizontal con la esquina de
# una losa mientras el cuerpo esta a su altura (CORNER_MARGIN_PX).
# Obligatorio para cada subida: el despegue y la llegada desde atras con la
# velocidad del validador aterrizan con holgura, y ninguna variante que llega
# a la repisa objetivo toca el techo ni se queda sin holgura. Con la variable
# de entorno ISAK_CLIMBS_REPORT=<ruta.json> escribe todas las medidas.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: String = "res://scenes/levels/1-2.tscn"
const LEVEL_PATH: String = "res://data/levels/1-2.json"
const CLIMBS_PATH: String = "res://tests/fixtures/climbs_1-2.json"
## 1-3 «No molestar» (paso 10 de docs/propuesta-1-3.md, 2026-10-20): mismas medidas, con las plataformas
## que parpadean quietas y encendidas (solidas) y el metronomo parado.
const LEVEL_SCENE_1_3: String = "res://scenes/levels/1-3.tscn"
const LEVEL_PATH_1_3: String = "res://data/levels/1-3.json"
const CLIMBS_PATH_1_3: String = "res://tests/fixtures/climbs_1-3.json"
## Arena de Alerta Mayor (paso 5 de docs/propuesta-jefe-alerta-mayor.md, 2026-10-21): las subidas de 2
## tiles de las fases 1-2 (suelo -> laterales -> central), sin el jefe.
const LEVEL_SCENE_BOSS: String = "res://scenes/levels/1-boss.tscn"
const LEVEL_PATH_BOSS: String = "res://data/levels/1-boss.json"
const CLIMBS_PATH_BOSS: String = "res://tests/fixtures/climbs_1-boss.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
## Holgura vertical minima (px) entre la cabeza y el solido de encima al subir.
const CEILING_MARGIN_PX: float = 16.0
## Holgura horizontal minima (px) con la esquina de una losa a la altura del cuerpo.
const CORNER_MARGIN_PX: float = 8.0
## Distancia de la llegada desde atras (2 tiles).
const BACK_PX: float = 128.0
## Cuadros en el aire antes de saltar en la variante con coyote (coyote_time_s = 0,1 s = 6).
const COYOTE_FRAMES: int = 4
const MAX_FRAMES: int = 240
## Lo que sube Isak con un salto completo a 60 Hz (velocidad -960, gravedad 2400): 184 px.
const JUMP_RISE_PX: float = 184.0

var _grid: Array = []
var _level: GeneratedLevel
var _isak: Isak
var _sim: IsakSim
var _pulse_was: bool
var _hidden: Array[Node] = []
var _solids_debug: Array[Rect2] = []
var _solids_plain: Array[Rect2] = []


func _read_grid(level_path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(level_path))
	_grid = data["grid"]


func before_each() -> void:
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Escena ---

func _load(scene_path: String = LEVEL_SCENE, level_path: String = LEVEL_PATH) -> void:
	_read_grid(level_path)
	_level = (load(scene_path) as PackedScene).instantiate() as GeneratedLevel
	# Sin enemigos ni puertas que se abren por el camino (pop-up solido, barra del 99 %).
	for child: Node in _level.get_node(^"Enemies").get_children():
		child.free()
	for child: Node in _level.get_node(^"Objects").get_children():
		if child is PopupBlocker or child is UpdateBar or child is BossBase:
			child.free()
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	for child: Node in _level.get_node(^"Objects").get_children():
		if child is ReminderPlatform:
			child.set_physics_process(false)
		elif child is PulseBridge:
			child.set_physics_process(false)
			child.activate()
			for i: int in 200:
				child.advance(0.1)
		elif child is RhythmZone:
			child.set_process(false)
			child.set_physics_process(false)
		elif child is BlinkPlatform:
			child.set_physics_process(false)
			child.call(&"_set_solid", true)
	_hidden.clear()
	for child: Node in _level.get_node(^"HiddenPlatforms").get_children():
		_hidden.append(child)
	await wait_physics_frames(2)
	_set_hidden(false)
	_solids_plain = _collect_solids()
	_set_hidden(true)
	_solids_debug = _collect_solids()


func _set_hidden(solid: bool) -> void:
	for node: Node in _hidden:
		node.call(&"_update_solid", solid)


## Rectangulos solidos (no de una via) en px globales: tiles '#' y las formas activas de los
## objetos (recordatorios, puentes, plataformas ocultas).
func _collect_solids() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: int in _grid.size():
		var row: String = _grid[r]
		for c: int in row.length():
			if row[c] == "#":
				out.append(Rect2(c * T, r * T, T, T))
	for parent: NodePath in [^"Objects", ^"HiddenPlatforms"]:
		for body: Node in _level.get_node(parent).get_children():
			for shape_node: Node in body.find_children("*", "CollisionShape2D", true, false):
				var shape := shape_node as CollisionShape2D
				if shape.disabled or shape.one_way_collision or not (shape.shape is RectangleShape2D):
					continue
				if not (shape.get_parent() is StaticBody2D or shape.get_parent() is AnimatableBody2D):
					continue
				# Sin capa no choca (objetos de una fase del jefe aun inactivos, arena 1-boss).
				if (shape.get_parent() as CollisionObject2D).collision_layer == 0:
					continue
				var size: Vector2 = (shape.shape as RectangleShape2D).size
				out.append(Rect2(shape.global_position - size * 0.5, size))
	return out


func _solid_cell(c: int, r: int) -> bool:
	if r < 0 or r >= _grid.size() or c < 0 or c >= String(_grid[0]).length():
		return true
	return String(_grid[r])[c] == "#"


# --- Un salto ---

func _place(x: float, row: int) -> void:
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	_sim.input.clear_just_pressed()
	_isak.global_position = Vector2(x, (row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


## Ejecuta una variante y devuelve sus medidas.
func _jump(climb: Dictionary, variant: String, run: bool) -> Dictionary:
	var d: float = float(climb["direction"])
	var from_row: int = int(climb["from"]["row"])
	var ledge: Array = climb["from"]["ledge"]
	var lo: float = float(ledge[0]) * T + 16.0
	var hi: float = (float(ledge[1]) + 1.0) * T - 16.0
	var x0: float = float(climb["takeoff_x_px"])
	var to_ledge: Array = climb["to"]["ledge"]
	var xt: float = 0.0
	if climb["target_x_px"] != null:
		xt = float(climb["target_x_px"])
	else:
		# Sin x objetivo en el validador: el jugador suelta la direccion en cuanto la capsula entera
		# esta sobre la repisa objetivo (si ya lo esta, salta en vertical).
		var to_lo: float = float(to_ledge[0]) * T + 16.0
		var to_hi: float = (float(to_ledge[1]) + 1.0) * T - 16.0
		xt = clampf(x0, to_lo, to_hi)
	var vertical: bool = is_equal_approx(xt, x0)
	if vertical:
		# Salto en vertical: se llega hacia la repisa objetivo o, si esta justo encima, desde el lado
		# de la repisa de salida con mas sitio (por donde llega el jugador).
		var center: float = (float(to_ledge[0]) + float(to_ledge[1]) + 1.0) * 0.5 * T
		if absf(center - x0) > 1.0:
			d = signf(center - x0)
		else:
			d = -1.0 if (hi - x0) > (x0 - lo) else 1.0
	var start: float = x0
	var edge_x: float = (float(ledge[1]) + 1.0) * T if d > 0.0 else float(ledge[0]) * T
	if variant == "atras":
		# Solo si la repisa deja coger carrera dos tiles.
		start = x0 - d * BACK_PX
		if start < lo - 0.01 or start > hi + 0.01:
			return {}
	elif variant == "coyote":
		# Solo si la repisa acaba en el borde de despegue (fuera no hay apoyo).
		if absf(x0 - edge_x) > 16.5 + 0.01:
			return {}
		var beyond: int = int(ledge[1]) + 1 if d > 0.0 else int(ledge[0]) - 1
		if _solid_cell(beyond, from_row + 1) or String(_grid[from_row + 1])[beyond] == "-":
			return {}
		start = clampf(x0 - d * T, lo, hi)
	_place(start, from_row)
	if absf(_isak.global_position.x - start) > 1.0 or not _isak.is_on_floor():
		return {"error": "no se puede colocar en %.0f" % start}
	var takeoff_feet: float = _isak.global_position.y
	_sim.input.run_held = run
	var res: Dictionary = {"variant": variant, "run": run, "ceiling_hit": false, "v_clear": INF, "h_clear": INF,
			"landed": false, "air_frames": 0, "rise": 0.0}
	var jumped: bool = false
	var airborne: bool = false
	var air_frames_before_jump: int = 0
	var axis: float = 0.0 if (variant == "despegue" and vertical) else d
	var released: bool = false
	var solids: Array[Rect2] = _solids_debug if bool(climb["debug"]) else _solids_plain
	var head_takeoff: float = takeoff_feet - _isak.hitbox_size.y
	for frame: int in MAX_FRAMES:
		var x: float = _isak.global_position.x
		var press: bool = false
		if not jumped:
			if variant == "despegue":
				press = true
			elif variant == "atras":
				press = (x - x0) * d >= -0.01
			elif variant == "coyote":
				if not _isak.is_on_floor():
					air_frames_before_jump += 1
				press = air_frames_before_jump >= COYOTE_FRAMES
		if press:
			_sim.input.jump_pressed = true
			_sim.input.jump_held = true
			jumped = true
		if jumped and not released:
			if (x - xt) * d >= -0.01:
				axis = 0.0
				released = true
		_sim.input.move_axis = axis
		var vy_before: float = _isak.velocity.y
		_sim.step()
		_sim.input.jump_held = false
		var pos: Vector2 = _isak.global_position
		if jumped and not _isak.is_on_floor():
			airborne = true
			res["air_frames"] = int(res["air_frames"]) + 1
		if jumped and _isak.is_on_ceiling() and vy_before < 0.0:
			res["ceiling_hit"] = true
		if airborne:
			res["rise"] = maxf(float(res["rise"]), takeoff_feet - pos.y)
			_measure(res, pos, vy_before, solids, head_takeoff, climb)
		if airborne and _isak.is_on_floor():
			var row: int = roundi(pos.y / T) - 1
			res["land_row"] = row
			res["land_x"] = pos.x
			res["landed"] = row == int(climb["to"]["row"]) \
					and pos.x >= float(to_ledge[0]) * T - 16.0 and pos.x <= (float(to_ledge[1]) + 1.0) * T + 16.0
			break
		if jumped and not airborne and frame > 30:
			break
	if not jumped:
		return {}
	# Lo que le falta para tener la holgura: si choca, lo que no pudo subir (frente al salto completo
	# medido en la escena de prueba, JUMP_RISE_PX) mas el margen; si no choca, margen - holgura.
	var short: float = CEILING_MARGIN_PX - float(res["v_clear"])
	if bool(res["ceiling_hit"]):
		short = JUMP_RISE_PX - float(res["rise"]) + CEILING_MARGIN_PX
	res["falta_px"] = maxf(0.0, short)
	res["jumped"] = jumped
	res["end"] = _isak.global_position
	return res


## Holguras en este cuadro, con la capsula real (radio = mitad del ancho de la hitbox): vertical
## (al subir) entre el perfil redondo de la cabeza y todo solido que esta encima y se solapa en x;
## horizontal = distancia de la capsula a la esquina de una losa (solido que estaba por encima de la
## cabeza al despegar y no es una pared que baja hasta la repisa de salida).
func _measure(res: Dictionary, pos: Vector2, vy_before: float, solids: Array[Rect2],
		head_takeoff: float, climb: Dictionary) -> void:
	if vy_before >= 0.0:
		return
	var to_ledge: Array = climb["to"]["ledge"]
	var to_feet: float = (float(climb["to"]["row"]) + 1.0) * T
	var radius: float = _isak.hitbox_size.x * 0.5
	var top_c: float = pos.y - _isak.hitbox_size.y + radius
	var bottom_c: float = pos.y - radius
	for rect: Rect2 in solids:
		var dx: float = maxf(0.0, maxf(rect.position.x - pos.x, pos.x - rect.end.x))
		if dx < radius - 0.01 and rect.end.y <= top_c:
			var top: float = top_c - sqrt(radius * radius - dx * dx)
			res["v_clear"] = minf(float(res["v_clear"]), top - rect.end.y)
		# El apoyo de la repisa objetivo no es un techo: Isak pasa a su lado y se sube encima.
		var support: bool = absf(rect.position.y - to_feet) < 1.0 \
				and rect.end.x > float(to_ledge[0]) * T and rect.position.x < (float(to_ledge[1]) + 1.0) * T
		if rect.end.y <= head_takeoff + 0.01 and not support and not _is_wall(rect, head_takeoff):
			var dy: float = maxf(0.0, maxf(rect.position.y - bottom_c, top_c - rect.end.y))
			var dist: float = sqrt(dx * dx + dy * dy) - radius
			if dist < float(res["h_clear"]):
				res["h_clear"] = dist
				res["h_at"] = "%s@%s" % [str(rect.position / T), str(pos)]


## Un solido que sigue en vertical (columna de '#') hasta la altura de la cabeza al despegar es una
## pared, no la esquina de una losa.
func _is_wall(rect: Rect2, head_takeoff: float) -> bool:
	var c: int = floori((rect.position.x + 1.0) / T)
	var r: int = floori((rect.end.y - 1.0) / T) + 1
	if not _solid_cell(c, r - 1):
		return false
	while float(r) * T < head_takeoff + T:
		if not _solid_cell(c, r):
			return false
		r += 1
	return true


func _ok(res: Dictionary) -> bool:
	return bool(res.get("landed", false)) and not bool(res["ceiling_hit"]) \
			and float(res["v_clear"]) >= CEILING_MARGIN_PX and float(res["h_clear"]) >= CORNER_MARGIN_PX


func _fmt(res: Dictionary, required: bool) -> String:
	if res.has("error"):
		return String(res["error"])
	var v: String = "inf" if is_inf(float(res["v_clear"])) else "%.0f" % float(res["v_clear"])
	var h: String = "inf" if is_inf(float(res["h_clear"])) else "%.0f" % float(res["h_clear"])
	var out: String = "llega" if res["landed"] else "NO llega (fila %s)" % str(res.get("land_row", "?"))
	if res["ceiling_hit"]:
		out += " TECHO"
	out += " holgura v=%s h=%s" % [v, h]
	if float(res["falta_px"]) > 0.0:
		out += " (faltan %.0f px)" % float(res["falta_px"])
	if not _ok(res):
		out += " <FALLA>" if required else " (no obligatoria)"
	return out


func _json_safe(res: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in res:
		var value: Variant = res[k]
		if value is float and is_inf(value):
			value = null
		elif value is Vector2:
			value = [value.x, value.y]
		out[k] = value
	return out


# --- Prueba ---

func test_every_climb_of_1_2_lands_with_headroom_using_the_real_isak() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIMBS_PATH))
	var climbs: Array = fixture["climbs"]
	assert_gt(climbs.size(), 20, "Subidas del 1-2 en %s" % CLIMBS_PATH)
	await _load()
	await _measure_all(climbs)


## Las subidas del 1-3 (escalon de vuelta del foso del 2a, ola del 2b, escalera de repisas del 2c hasta la
## pared de «Excepciones», repisa del 3b, pilar del secreto C) con el Isak real.
func test_every_climb_of_1_3_lands_with_headroom_using_the_real_isak() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIMBS_PATH_1_3))
	var climbs: Array = fixture["climbs"]
	assert_gt(climbs.size(), 8, "Subidas del 1-3 en %s" % CLIMBS_PATH_1_3)
	await _load(LEVEL_SCENE_1_3, LEVEL_PATH_1_3)
	var blinks: int = 0
	for child: Node in _level.get_node(^"Objects").get_children():
		if child is BlinkPlatform:
			assert_true((child as BlinkPlatform).is_solid(), "%s encendida para medir" % child.name)
			blinks += 1
	assert_eq(blinks, 5, "Las cinco plataformas que parpadean del Tramo 2")
	await _measure_all(climbs)


## Arena de Alerta Mayor: suelo -> plataformas laterales (2 tiles) -> central (2 tiles), con el Isak real.
func test_every_climb_of_the_boss_arena_lands_with_headroom_using_the_real_isak() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIMBS_PATH_BOSS))
	var climbs: Array = fixture["climbs"]
	assert_eq(climbs.size(), 4, "Dos laterales desde el suelo y la central desde cada lateral")
	for climb: Dictionary in climbs:
		assert_eq(int(climb["rise_tiles"]), 2, "%s: subida de 2 tiles" % climb["id"])
	await _load(LEVEL_SCENE_BOSS, LEVEL_PATH_BOSS)
	await _measure_all(climbs)


func _measure_all(climbs: Array) -> void:
	var report: Array = []
	var failures: Array[String] = []
	for climb: Dictionary in climbs:
		_set_hidden(bool(climb["debug"]))
		var entry: Dictionary = {"id": climb["id"], "section": climb["section"], "speed": climb["speed"],
				"variants": {}}
		var lines: Array[String] = []
		for variant: String in ["despegue", "atras", "coyote"]:
			for run: bool in [false, true]:
				var res: Dictionary = _jump(climb, variant, run)
				var key: String = "%s_%s" % [variant, "corriendo" if run else "andando"]
				if res.is_empty():
					continue
				entry["variants"][key] = _json_safe(res)
				# Obligatorias: despegue y llegada desde atras con la velocidad del validador.
				var required: bool = variant != "coyote" and run == (String(climb["speed"]) == "run")
				lines.append("%s: %s" % [key, _fmt(res, required)])
				var landed: bool = bool(res.get("landed", false))
				var bad_head: bool = landed and (bool(res["ceiling_hit"]) or float(res["v_clear"]) < CEILING_MARGIN_PX)
				if res.has("error") or (required and not _ok(res)) or bad_head:
					failures.append("%s (%s) %s: %s" % [climb["id"], climb["section"], key, _fmt(res, required)])
		report.append(entry)
		gut.p("%s [%s, %s]\n    %s" % [climb["id"], climb["section"], climb["speed"], "\n    ".join(lines)])
	_set_hidden(false)
	var out_path: String = OS.get_environment("ISAK_CLIMBS_REPORT")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, " "))
			f.close()
	assert_eq(failures.size(), 0, "Subidas sin holgura con el Isak real:\n" + "\n".join(failures))



## Azotea del 1-2 con el acertijo de Calc (tanda H2 del paso 14, 2026-10-17): la salida del hueco a la
## azotea y las tres subidas del cuarto (suelo -> repisa baja -> media -> alta, la del panel oculto; filas
## de pie 9 -> 7 -> 5 -> 3) estan en el fixture y las mide con el Isak real la prueba de arriba, como las
## demas (16 px de holgura sobre la cabeza y 8 px con la esquina de una losa).
func test_rooftop_climbs_of_the_calc_room_are_measured() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIMBS_PATH))
	var roof: Array[String] = []
	var shaft: bool = false
	for climb: Dictionary in fixture["climbs"]:
		var pair: String = "%d->%d" % [int(climb["from"]["row"]), int(climb["to"]["row"])]
		if String(climb["section"]) == "Azotea":
			roof.append(pair)
		elif pair == "11->9":
			shaft = true
	for pair: String in ["9->7", "7->5", "5->3"]:
		assert_true(roof.has(pair), "Subida %s del cuarto de Calc en %s (%s)" % [pair, CLIMBS_PATH, roof])
	assert_true(shaft, "Salida del hueco de la izquierda a la azotea (fila 11 -> 9)")
