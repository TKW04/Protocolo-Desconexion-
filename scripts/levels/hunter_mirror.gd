## Espejo cazador (tipo `hunter_mirror` del catalogo del Mundo 3; 2026-10-26, paso 6
## de docs/propuesta-mundo-3.md §8, §3.6, patron 16 de §3.5): objeto-enemigo de
## 1 x 1 en un pie, INDESTRUCTIBLE. Valores en la seccion hunter_mirror de
## data/world3_objects.json. Todo en TIEMPO DEL MUNDO (el Debug lo ralentiza).
##
## - Orientacion: una de 8 (FACINGS: e, ne, n, nw, w, sw, s, se; `facing` del nivel
##   es la de reposo). Con Isak a <= track_radius_px (centro a centro) su objetivo
##   es la direccion hacia Isak redondeada a 45 grados; sin el, vuelve a la de
##   reposo. Si no mira a su objetivo, cada turn_interval_s gira UN paso de 45
##   grados hacia el (por el lado mas corto); los ultimos warn_frames cuadros
##   (9 a 60 fps = 0,15 s) antes de cada giro BRILLA (turn_warned: sonido de
##   accesibilidad sfx_w3_hunter_turn, paso 19). Su retraso es lo que se aprovecha.
## - PULSO de Isak que lo alcanza (PulseReceiver.pulse_reaches contra su celda, el
##   radio del pulso: 96 px): lo CONGELA freeze_s (3 s) en su orientacion y el
##   pulso SALE REFLEJADO como un haz de beam_tiles (6) en esa direccion desde su
##   centro, cortado por el terreno: llama receive_pulse(area) de los receptores de
##   pulso (grupo pulse_receiver: receptor, receptor enlazado con corriente) y de
##   los enemigos (grupo enemy: los aturde) que toca, con un Area2D de circulos a lo
##   largo del haz (misma prueba que el pulso). Si toca a Isak, lo deja
##   isak_stun_s (0,5 s) aturdido SIN quitarle Sync (Isak.take_stun). No vuelve a
##   disparar el pulso a otros cazadores.
## - LASER: es un reflector (LaserProjectile.laser_reflection): el haz sale desde
##   su centro hacia donde mire, con el alcance que le quedaba; cuenta como rebote
##   (limite comun mirror.max_bounces). El haz reflejado puede alcanzar a Isak (el
##   rayo del laser no ve su capa: el cazador sigue los proyectiles que ha
##   desviado y, si su tramo cruza el cuerpo de Isak, le quita laser_damage (10;
##   take_hit + GameState.apply_sync_damage) y apaga el disparo).
## - Al reaparecer Isak vuelve a su orientacion de reposo, sin congelar.
## Area2D en la capa world y en el grupo laser_activatable (no es solido para
## Isak). Aspecto PROVISIONAL por codigo (paleta provisional). El origen es la
## esquina superior izquierda de su celda.
class_name HunterMirror
extends Area2D

const GROUP: StringName = &"hunter_mirror"
const LAYER_WORLD: int = 1
const FACINGS: PackedStringArray = ["e", "ne", "n", "nw", "w", "sw", "s", "se"]

## Brillo de aviso: en warn_s girara un paso hacia `next_facing`.
signal turn_warned(next_facing: String)
## Ha girado un paso (45 grados).
signal turned(facing_name: String)
## Un pulso lo ha congelado.
signal frozen
## Se ha descongelado.
signal thawed
## Ha disparado el haz del pulso reflejado (`from` y `to` globales).
signal beam_fired(from: Vector2, to: Vector2)
## El haz del pulso ha alcanzado a `target` (receptor o enemigo que respondio).
signal beam_hit(target: Node)
## El haz del pulso ha aturdido a Isak.
signal isak_stunned
## Un laser desviado por el ha alcanzado a Isak.
signal isak_hit(damage: float)
## Ha desviado un laser hacia `new_heading`.
signal bounced(at: Vector2, new_heading: Vector2)
## Igual que bounced, con el disparo (2026-10-27, paso 14 de
## docs/propuesta-mundo-3.md: La Curadora sigue el laser que el cazador manda a
## un espejo de esquina y lo entrega a su espalda).
signal laser_redirected(projectile: Node, at: Vector2, new_heading: Vector2)

@export var object_id: StringName = &""
## Orientacion de reposo (FACINGS).
@export var facing: String = "e"
## Radio de seguimiento en tiles (negativo = el de los datos).
@export var track_radius_tiles: float = -1.0
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true
## Isak al que sigue (si es null se busca con LevelLookup).
var isak: Isak

var _cfg: Dictionary = World3ObjectsConfig.section("hunter_mirror")
var _index: int = 0
var _rest_index: int = 0
var _turn_t: float = 0.0
var _warned: bool = false
var _freeze_left: float = 0.0
var _beam_left: float = 0.0
var _beam_from: Vector2 = Vector2.ZERO
var _beam_to: Vector2 = Vector2.ZERO
var _flash_left: float = 0.0
var _turns: int = 0
## Proyectiles desviados que se siguen: [{shot, last}].
var _tracked: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	monitoring = false
	set_rest_facing(facing)
	var r: Rect2 = get_local_hit_rect()
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	add_child(shape)
	EventBus.pulse_fired.connect(_on_pulse_fired)
	EventBus.player_respawned.connect(_on_player_respawned)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de TIEMPO DEL MUNDO. Publico para las pruebas.
func advance(dt: float) -> void:
	check_projectiles()
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - dt, 0.0)
	if _beam_left > 0.0:
		_beam_left = maxf(_beam_left - dt, 0.0)
	if _freeze_left > 0.0:
		_freeze_left -= dt
		if _freeze_left <= 0.0:
			_freeze_left = 0.0
			_turn_t = 0.0
			_warned = false
			thawed.emit()
		queue_redraw()
		return
	var target: int = get_target_index()
	if target == _index:
		_turn_t = 0.0
		_warned = false
	else:
		_turn_t += dt
		if not _warned and _turn_t >= get_turn_interval_s() - get_warn_s() - 0.0001:
			_warned = true
			turn_warned.emit(FACINGS[_step_toward(target)])
		if _turn_t >= get_turn_interval_s() - 0.0001:
			_index = _step_toward(target)
			_turn_t = 0.0
			_warned = false
			_turns += 1
			turned.emit(FACINGS[_index])
	queue_redraw()


# --- Consultas ---

## Direccion unitaria de la orientacion `index` (0 = e, sentido antihorario).
static func facing_vector(index: int) -> Vector2:
	var a: float = float(posmod(index, 8)) * PI * 0.25
	return Vector2(cos(a), -sin(a))


## Indice de la orientacion mas cercana a `v` (8 direcciones).
static func index_for_vector(v: Vector2) -> int:
	if v.is_zero_approx():
		return 0
	return posmod(roundi(atan2(-v.y, v.x) / (PI * 0.25)), 8)


static func facing_index(name: String) -> int:
	var i: int = FACINGS.find(name)
	return i if i >= 0 else 0


## Verdadero si el segmento `a`-`b` cruza `rect` (Liang-Barsky).
static func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var d: Vector2 = b - a
	var t0: float = 0.0
	var t1: float = 1.0
	var p: Array[float] = [-d.x, d.x, -d.y, d.y]
	var q: Array[float] = [a.x - rect.position.x, rect.end.x - a.x, a.y - rect.position.y, rect.end.y - a.y]
	for i: int in 4:
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return false
			continue
		var t: float = q[i] / p[i]
		if p[i] < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return false
	return true


func get_facing_name() -> String:
	return FACINGS[_index]


func get_facing_index() -> int:
	return _index


func get_facing_vector() -> Vector2:
	return facing_vector(_index)


func get_rest_facing_name() -> String:
	return FACINGS[_rest_index]


## Cambia la orientacion de reposo (y la actual): la usan el nivel y las pruebas.
func set_rest_facing(name: String) -> void:
	if not FACINGS.has(name):
		push_warning("HunterMirror %s: facing '%s' no valido; se usa 'e'" % [object_id, name])
		name = "e"
	facing = name
	_rest_index = facing_index(name)
	_index = _rest_index
	_turn_t = 0.0
	_warned = false
	queue_redraw()


func get_turn_interval_s() -> float:
	return float(_cfg.get("turn_interval_s", 0.6))


## Brillo antes de cada giro: warn_frames a anim_fps (9 a 60 fps = 0,15 s).
func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 60.0)), 1.0)


func get_freeze_s() -> float:
	return float(_cfg.get("freeze_s", 3.0))


func get_track_radius_px() -> float:
	var tiles: float = track_radius_tiles if track_radius_tiles >= 0.0 else float(_cfg.get("track_radius_tiles", 3.0))
	return tiles * World3ObjectsConfig.tile_size()


func get_beam_length_px() -> float:
	return float(_cfg.get("beam_tiles", 6)) * World3ObjectsConfig.tile_size()


func get_local_hit_rect() -> Rect2:
	var r: Array = _cfg.get("hit_rect", [0, 0, 64, 64])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func get_hit_rect() -> Rect2:
	var r: Rect2 = get_local_hit_rect()
	return Rect2(global_position + r.position, r.size)


func get_center() -> Vector2:
	return get_hit_rect().get_center()


func is_frozen() -> bool:
	return _freeze_left > 0.0


func get_freeze_left() -> float:
	return _freeze_left


## Brillando: girara en menos de warn_s.
func is_warning() -> bool:
	return _warned and not is_frozen()


func get_turn_count() -> int:
	return _turns


## Ultimo haz del pulso (global); is_beam_visible() mientras se dibuja.
func get_beam_segment() -> PackedVector2Array:
	return PackedVector2Array([_beam_from, _beam_to])


func is_beam_visible() -> bool:
	return _beam_left > 0.0


## Orientacion a la que quiere llegar: hacia Isak (en su radio) o la de reposo.
func get_target_index() -> int:
	var target_isak: Isak = _find_isak()
	if target_isak != null and not target_isak.is_dead():
		var to: Vector2 = LevelLookup.isak_body_rect(target_isak).get_center() - get_center()
		if to.length() <= get_track_radius_px():
			return index_for_vector(to)
	return _rest_index


## Ayuda de Eco: es indestructible, siempre ayuda (sin Q todavia).
func is_help_available() -> bool:
	return true


# --- Pulso ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si lo ha alcanzado (se congela
## y dispara el haz).
func receive_pulse(area: Area2D) -> bool:
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	freeze()
	fire_beam()
	return true


## Se congela freeze_s en la orientacion actual (otro pulso lo renueva).
func freeze() -> void:
	var was: bool = is_frozen()
	_freeze_left = get_freeze_s()
	_turn_t = 0.0
	_warned = false
	if not was:
		frozen.emit()
	queue_redraw()


## Fin del haz desde el centro en la orientacion actual: beam_tiles o el terreno.
func get_beam_end() -> Vector2:
	var from: Vector2 = get_center()
	var to: Vector2 = from + get_facing_vector() * get_beam_length_px()
	if not is_inside_tree():
		return to
	var params := PhysicsRayQueryParameters2D.create(from, to, LAYER_WORLD)
	params.collide_with_areas = false
	params.hit_from_inside = false
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)
	return to if hit.is_empty() else hit["position"]


## Dispara el pulso reflejado: lo que toca el haz responde como a un pulso.
## Devuelve los nodos que han respondido.
func fire_beam() -> Array[Node]:
	var hits: Array[Node] = []
	var from: Vector2 = get_center()
	var to: Vector2 = get_beam_end()
	_beam_from = from
	_beam_to = to
	_beam_left = float(_cfg.get("beam_show_s", 0.3))
	beam_fired.emit(from, to)
	var area := _beam_area(from, to)
	add_child(area)
	var targets: Array[Node] = []
	for group: StringName in [PulseReceiver.GROUP, &"enemy"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node == self or node is HunterMirror or targets.has(node) or not node.has_method(&"receive_pulse"):
				continue
			targets.append(node)
	for node: Node in targets:
		if is_instance_valid(node) and bool(node.call(&"receive_pulse", area)):
			hits.append(node)
			beam_hit.emit(node)
	remove_child(area)
	area.free()
	var target_isak: Isak = _find_isak()
	if target_isak != null and not target_isak.is_dead() \
			and segment_hits_rect(from, to, LevelLookup.isak_body_rect(target_isak).grow(get_beam_width_px() * 0.5)):
		if target_isak.take_stun(float(_cfg.get("isak_stun_s", 0.5)), signf(to.x - from.x)):
			isak_stunned.emit()
	queue_redraw()
	return hits


func get_beam_width_px() -> float:
	return float(_cfg.get("beam_width_px", 24))


## Area2D con circulos de beam_width_px a lo largo del haz (la prueba del pulso).
func _beam_area(from: Vector2, to: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = "ReflectedPulse"
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.top_level = true
	var radius: float = get_beam_width_px() * 0.5
	var length: float = from.distance_to(to)
	var count: int = maxi(1, ceili(length / maxf(radius, 1.0))) + 1
	for i: int in count:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		shape.position = from.lerp(to, float(i) / float(count - 1)) if count > 1 else from
		area.add_child(shape)
	return area


# --- Laser ---

## Reflector de LaserProjectile: el haz sale desde el centro hacia donde mira;
## {} si el disparo ya lleva mirror.max_bounces rebotes (lo para).
func laser_reflection(projectile: Node, _hit_position: Vector2) -> Dictionary:
	var bounces: int = 0
	if projectile != null and projectile.has_method(&"get_bounce_count"):
		bounces = int(projectile.call(&"get_bounce_count"))
	if bounces >= Mirror.max_bounces():
		return {}
	var at: Vector2 = get_center()
	var out: Vector2 = get_facing_vector()
	if projectile is LaserProjectile:
		(projectile as LaserProjectile).exclude_source = false
		track_projectile(projectile as LaserProjectile, at)
	_flash_left = float(_cfg.get("flash_s", 0.15))
	bounced.emit(at, out)
	laser_redirected.emit(projectile, at, out)
	EventBus.mirror_bounced.emit(self, at)
	queue_redraw()
	return {"heading": out, "position": at}


## Disparo con los rebotes agotados: lo para (indestructible).
func on_laser_hit(_damage: float, _source: Node) -> void:
	_flash_left = float(_cfg.get("flash_s", 0.15))
	queue_redraw()


## Sigue `shot` desde `from` para ver si alcanza a Isak.
func track_projectile(shot: LaserProjectile, from: Vector2) -> void:
	for t: Dictionary in _tracked:
		if t["shot"] == shot:
			t["last"] = from
			return
	_tracked.append({"shot": shot, "last": from})


## Comprueba los disparos desviados: si el tramo recorrido desde la ultima vez
## cruza a Isak, le quita laser_damage y apaga el disparo. Publico para las pruebas
## (advance() lo llama).
func check_projectiles() -> void:
	if _tracked.is_empty():
		return
	var target_isak: Isak = _find_isak()
	var keep: Array[Dictionary] = []
	for t: Dictionary in _tracked:
		var shot: LaserProjectile = t["shot"] as LaserProjectile
		if shot == null or not is_instance_valid(shot):
			continue
		var now: Vector2 = shot.global_position
		var last: Vector2 = t["last"]
		var hit: bool = target_isak != null and not target_isak.is_dead() \
			and segment_hits_rect(last, now, LevelLookup.isak_body_rect(target_isak))
		if hit:
			if target_isak.take_hit(signf(now.x - last.x)):
				var dmg: float = float(_cfg.get("laser_damage", 10.0))
				GameState.apply_sync_damage(dmg)
				isak_hit.emit(dmg)
			shot.strike(null)
			continue
		if shot.is_finished():
			continue
		t["last"] = now
		keep.append(t)
	_tracked = keep


# --- Interno ---

## Indice un paso de 45 grados hacia `target` por el lado mas corto (a 180, antihorario).
func _step_toward(target: int) -> int:
	var diff: int = posmod(target - _index, 8)
	if diff == 0:
		return _index
	return posmod(_index + (1 if diff <= 4 else -1), 8)


func _find_isak() -> Isak:
	if isak != null and is_instance_valid(isak) and isak.is_inside_tree():
		return isak
	isak = LevelLookup.find_isak(self)
	return isak


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


func _on_player_respawned(_position: Vector2, _after_death: bool) -> void:
	_index = _rest_index
	_freeze_left = 0.0
	_turn_t = 0.0
	_warned = false
	_beam_left = 0.0
	_tracked.clear()
	queue_redraw()


# --- Dibujo PROVISIONAL ---

func _draw() -> void:
	var cell: float = World3ObjectsConfig.tile_size()
	var c := Vector2(cell, cell) * 0.5
	var foot_w: float = float(_cfg.get("stand_width_px", 6))
	draw_rect(Rect2(c.x - foot_w * 0.5, c.y, foot_w, cell * 0.5), _c("stand", "marco_sombra"))
	draw_rect(Rect2(c.x - 14.0, cell - 4.0, 28.0, 4.0), _c("stand", "marco_sombra"))
	# Disco del cabezal y cristal perpendicular a la orientacion.
	var head_r: float = float(_cfg.get("head_radius_px", 18))
	var warn: bool = is_warning() and int(floor(_turn_t * 60.0 / 2.0)) % 2 == 0
	var ring: Color = _c("warn", "dorado_luz") if warn else _c("frame", "dorado")
	if is_frozen():
		ring = _c("frozen", "gris_perla")
	draw_circle(c, head_r + 3.0, _c("frame_shadow", "marco_sombra"))
	draw_circle(c, head_r, ring)
	var f: Vector2 = get_facing_vector()
	var along: Vector2 = f.orthogonal()
	var half: float = float(_cfg.get("glass_half_px", 20))
	var glass_c: Vector2 = c + f * 6.0
	draw_line(glass_c - along * half, glass_c + along * half, _c("glass", "gris_perla"), float(_cfg.get("glass_width_px", 6)))
	draw_line(glass_c - along * half + f * 2.0, glass_c + along * half + f * 2.0, _c("glass_light", "blanco_brillante"), 1.0)
	# Ojo: hacia donde mira.
	draw_circle(c + f * (head_r - 4.0), 3.0, _c("eye", "galeria_noche"))
	if warn:
		draw_arc(c, head_r + 8.0, 0.0, TAU, 24, Color(_c("warn", "dorado_luz"), 0.9), 2.0)
	if is_frozen():
		# Escarcha: cuatro trazos y la cuenta de lo que queda.
		var frost: Color = Color(_c("frozen_light", "blanco_brillante"), 0.85)
		for ang: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(head_r + 6.0, 0.0).rotated(deg_to_rad(ang))
			draw_line(c - d, c + d, frost, 1.0)
		var frac: float = _freeze_left / maxf(get_freeze_s(), 0.001)
		draw_arc(c, head_r + 10.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, frost, 2.0)
	if _flash_left > 0.0:
		var t: float = _flash_left / maxf(float(_cfg.get("flash_s", 0.15)), 0.001)
		draw_circle(c, 14.0 * (0.6 + 0.4 * t), Color(_c("flash", "blanco_brillante"), 0.85 * t))
	if _beam_left > 0.0:
		var a: float = _beam_left / maxf(float(_cfg.get("beam_show_s", 0.3)), 0.001)
		var from: Vector2 = _beam_from - global_position
		var to: Vector2 = _beam_to - global_position
		draw_line(from, to, Color(_c("beam_glow", "dorado_luz"), 0.5 * a), get_beam_width_px())
		draw_line(from, to, Color(_c("beam", "blanco_brillante"), a), get_beam_width_px() * 0.35)


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))
