## Zona de clones de «Un video mas» (tipo `clone_zone` del catalogo del Mundo 2;
## paso 7 de docs/propuesta-mundo-2.md §8, §3.4 y patron 12 «Limpiar y seguir»
## de §3.6). Ajustes en la seccion clone_zone de data/world2_objects.json.
##
## - `zone` = [columna, fila, ancho, alto] en celdas. Con los pies de Isak dentro,
##   cada spawn_s (tiempo del mundo) nace un clon (VideoClone) en el borde de la
##   zona mas lejano a Isak, a ras del suelo de la zona (fila de abajo), tras un
##   AVISO de warn_frames cuadros a anim_fps (un marco de video que se enciende,
##   como las oleadas de la barra del 99 %). Tope: max_clones (vivos + avisando);
##   con el tope lleno el reloj vuelve a cero. Al salir de la zona el reloj
##   vuelve a cero (el aviso en curso termina y su clon nace).
## - El GOLPE AL SUELO con la onda dentro de la zona (EventBus.ground_pound_landed)
##   elimina a TODOS sus clones a la vez, cancela el aviso y pone el reloj a cero.
## - Los clones patrullan dentro de las columnas de la zona; sin drops.
## - Al reaparecer Isak (o al repetir un bucle: reset) se quitan todos.
## El origen del nodo es la esquina superior izquierda de su celda (la del
## objeto; la zona va por `zone`). Aspecto PROVISIONAL por codigo.
class_name CloneZone
extends Node2D

## Ha empezado el aviso de un clon (en `spawn_point`, pies globales).
signal spawn_warned(spawn_point: Vector2)
signal clone_spawned(clone: VideoClone)
## Un golpe al suelo ha limpiado la zona (`count` clones eliminados).
signal cleared(count: int)

const CLONE_SCENE: PackedScene = preload("res://scenes/enemies/video_clone.tscn")

@export var object_id: StringName = &""
@export var zone: Array = [0, 0, 1, 1]
@export var spawn_s: float = 1.5
@export var max_clones: int = 6

var _cfg: Dictionary = World2ObjectsConfig.section("clone_zone")
## Isak (si es null se busca en el nivel).
var target: Isak

var _clones: Array[VideoClone] = []
var _inside_t: float = 0.0
## Segundos que quedan del aviso en curso (< 0 = sin aviso).
var _warn_left: float = -1.0
var _warn_point: Vector2 = Vector2.ZERO
var _spawned: int = 0
var _time: float = 0.0


func _ready() -> void:
	z_index = int(_cfg.get("z_index", -1))
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas (no
## avanza los clones: tienen su propio _physics_process).
func step(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	_prune()
	if _warn_left >= 0.0:
		_warn_left -= dt
		if _warn_left <= 0.0:
			_warn_left = -1.0
			_spawn_clone(_warn_point)
	if is_player_inside():
		_inside_t += dt
		if _inside_t >= spawn_s:
			_inside_t -= spawn_s
			if get_pending_count() >= max_clones:
				_inside_t = 0.0
			else:
				_start_warning()
	else:
		_inside_t = 0.0
	queue_redraw()


# --- Consultas ---

## Zona en coordenadas globales.
func get_zone_rect() -> Rect2:
	var t: float = World2ObjectsConfig.tile_size()
	if zone.size() < 4:
		return Rect2()
	return Rect2(float(zone[0]) * t, float(zone[1]) * t, float(zone[2]) * t, float(zone[3]) * t)


## Los pies de Isak dentro de la zona.
func is_player_inside() -> bool:
	var isak: Isak = _find_player()
	if isak == null:
		return false
	return get_zone_rect().has_point(isak.global_position - Vector2(0.0, 1.0))


func get_clones() -> Array[VideoClone]:
	_prune()
	return _clones.duplicate()


func get_clone_count() -> int:
	return get_clones().size()


## Clones vivos mas el que esta avisando.
func get_pending_count() -> int:
	return get_clone_count() + (1 if is_warning() else 0)


func is_warning() -> bool:
	return _warn_left >= 0.0


func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 0.001)


func get_inside_time() -> float:
	return _inside_t


func get_spawned_total() -> int:
	return _spawned


## Ayuda de Eco: la zona no tiene Q propia (la llevan sus clones).
func is_help_available() -> bool:
	return false


# --- Acciones ---

## Elimina a todos los clones (golpe al suelo) y cancela el aviso. Devuelve cuantos.
func clear_clones() -> int:
	var n: int = 0
	for clone: VideoClone in get_clones():
		if not clone.is_popped():
			clone.pop()
			n += 1
	_warn_left = -1.0
	_inside_t = 0.0
	return n


## Estado inicial (reaparicion de Isak, bucle): sin clones, sin aviso, reloj a cero.
func reset() -> void:
	for clone: VideoClone in _clones:
		if is_instance_valid(clone):
			clone.queue_free()
	_clones.clear()
	_warn_left = -1.0
	_inside_t = 0.0
	queue_redraw()


# --- Interno ---

func _start_warning() -> void:
	var rect: Rect2 = get_zone_rect()
	var t: float = World2ObjectsConfig.tile_size()
	var left := Vector2(rect.position.x + t * 0.5, rect.end.y)
	var right := Vector2(rect.end.x - t * 0.5, rect.end.y)
	var isak: Isak = _find_player()
	var x: float = isak.global_position.x if isak != null else rect.get_center().x
	_warn_point = left if absf(x - left.x) >= absf(x - right.x) else right
	_warn_left = get_warn_s()
	spawn_warned.emit(_warn_point)


func _spawn_clone(at: Vector2) -> void:
	var clone := CLONE_SCENE.instantiate() as VideoClone
	var rect: Rect2 = get_zone_rect()
	var t: float = World2ObjectsConfig.tile_size()
	clone.start_direction = 1.0 if at.x < rect.get_center().x else -1.0
	# La zona se dibuja detras; sus clones, al nivel de los demas enemigos.
	clone.z_index = -z_index
	add_child(clone)
	clone.global_position = at
	clone.patrol_min_x = rect.position.x + t * 0.5
	clone.patrol_max_x = rect.end.x - t * 0.5
	clone.target = _find_player()
	HelpCatalog.tag(clone, StringName(String(_cfg.get("clone_help_id", "video_clone"))))
	_clones.append(clone)
	_spawned += 1
	clone_spawned.emit(clone)


func _prune() -> void:
	var alive: Array[VideoClone] = []
	for clone: VideoClone in _clones:
		if is_instance_valid(clone) and not clone.is_queued_for_deletion() and not clone.is_popped():
			alive.append(clone)
	_clones = alive


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


func _on_ground_pound_landed(rect: Rect2, _source: Node2D) -> void:
	if not rect.intersects(get_zone_rect()):
		return
	var n: int = clear_clones()
	cleared.emit(n)


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 2) ---

func _draw() -> void:
	var rect := Rect2(get_zone_rect().position - global_position, get_zone_rect().size)
	# Borde discreto de la zona (marcas de esquina en el tono del feed).
	var edge := Color(World2ObjectsConfig.color("feed_resplandor"), 0.6)
	var k: float = 12.0
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		var sx: float = 1.0 if corner.x <= rect.position.x else -1.0
		var sy: float = 1.0 if corner.y <= rect.position.y else -1.0
		draw_line(corner, corner + Vector2(k * sx, 0.0), edge, 2.0)
		draw_line(corner, corner + Vector2(0.0, k * sy), edge, 2.0)
	if not is_warning():
		return
	# Aviso: marco de video que se enciende donde nacera el clon.
	var p: Vector2 = _warn_point - global_position
	var fps: float = float(_cfg.get("anim_fps", 12.0))
	var lit: float = clampf(1.0 - _warn_left / maxf(get_warn_s(), 0.001), 0.0, 1.0)
	var frame := Rect2(p + Vector2(-28.0, -48.0), Vector2(56.0, 48.0))
	var red: Color = World2ObjectsConfig.color("alerta")
	draw_rect(frame, Color(World2ObjectsConfig.color("feed_noche"), 0.4 + 0.5 * lit))
	if int(floor(_time * fps)) % 2 == 0 or lit > 0.66:
		draw_rect(frame, red, false, 3.0)
	draw_rect(Rect2(frame.position + Vector2(6.0, frame.size.y - 8.0), Vector2((frame.size.x - 12.0) * lit, 3.0)),
		World2ObjectsConfig.color("magenta"))
