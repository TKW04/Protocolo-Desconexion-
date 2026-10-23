## Muro «Cargando mas…» (tipo `loading_wall` del catalogo del Mundo 2; paso 7 de
## docs/propuesta-mundo-2.md §8, §3.4 y patron 12 de §3.6; nivel 2-3).
## Ajustes en la seccion loading_wall de data/world2_objects.json.
##
## Pared solida de 1 x height_tiles (3) sobre el suelo con un circulo de carga de
## pounds_needed (3) segmentos. El pulso y el laser rebotan (chispa gris; el
## disparo se consume). Cada GOLPE AL SUELO cuya onda lo alcanza
## (EventBus.ground_pound_landed: a 1,5 tiles o menos) rellena un segmento; con
## todos, se rompe PARA SIEMPRE (sin colision; no vuelve al reaparecer). Al
## reaparecer Isak sin haberlo roto, los segmentos vuelven a cero (estado
## inicial). El origen del nodo es la esquina superior izquierda de su celda de
## arriba. Aspecto PROVISIONAL por codigo (FeedCardDraw, paleta provisional).
class_name LoadingWall
extends StaticBody2D

## Un golpe ha rellenado un segmento (`filled` de `needed`).
signal segment_filled(filled: int, needed: int)
signal broken
## El pulso o el laser han rebotado (chispa gris).
signal deflected

const LAYER_WORLD: int = 1

@export var object_id: StringName = &""
@export var height_tiles: int = 3
@export var pounds_needed: int = 3

var _cfg: Dictionary = World2ObjectsConfig.section("loading_wall")
var _filled: int = 0
var _broken: bool = false
var _deflect_left: float = 0.0
var _flash_left: float = 0.0
var _break_left: float = 0.0
var _time: float = 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = get_wall_size()
	_shape.shape = rect
	_shape.position = get_wall_size() * 0.5
	add_child(_shape)
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)
	EventBus.pulse_fired.connect(_on_pulse_fired)
	EventBus.player_respawned.connect(_on_player_respawned)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos del mundo (solo efectos visuales). Publico para las pruebas.
func advance(dt: float) -> void:
	_time += dt
	_deflect_left = maxf(_deflect_left - dt, 0.0)
	_flash_left = maxf(_flash_left - dt, 0.0)
	_break_left = maxf(_break_left - dt, 0.0)
	queue_redraw()


# --- Consultas ---

func get_wall_size() -> Vector2:
	var t: float = World2ObjectsConfig.tile_size()
	return Vector2(t, t * float(height_tiles))


func get_wall_rect() -> Rect2:
	return Rect2(global_position, get_wall_size())


func get_filled() -> int:
	return _filled


func is_broken() -> bool:
	return _broken


func is_solid() -> bool:
	return not _broken


## Ayuda de Eco: mientras no este roto.
func is_help_available() -> bool:
	return not _broken


# --- Acciones ---

## Un golpe que alcanza el muro: rellena un segmento; con todos, se rompe.
## Verdadero si contaba (no estaba roto).
func register_pound() -> bool:
	if _broken:
		return false
	_filled = mini(_filled + 1, pounds_needed)
	_flash_left = float(_cfg.get("flash_s", 0.2))
	segment_filled.emit(_filled, pounds_needed)
	if _filled >= pounds_needed:
		_break()
	queue_redraw()
	return true


## Interfaz del laser: rebota (chispa gris; el disparo se consume).
func on_laser_hit(_damage: float, _source: Node) -> void:
	if _broken:
		return
	_deflect()


## Estado inicial (reaparicion de Isak, bucle): segmentos a cero; roto sigue roto.
func reset() -> void:
	if not _broken:
		_filled = 0
	queue_redraw()


# --- Interno ---

func _break() -> void:
	_broken = true
	_break_left = float(_cfg.get("break_s", 0.3))
	collision_layer = 0
	_shape.set_deferred(&"disabled", true)
	broken.emit()


func _deflect() -> void:
	_deflect_left = float(_cfg.get("deflect_s", 0.25))
	deflected.emit()
	queue_redraw()


func _on_ground_pound_landed(rect: Rect2, _source: Node2D) -> void:
	if rect.intersects(get_wall_rect()):
		register_pound()


func _on_pulse_fired(area: Area2D) -> void:
	if not _broken and PulseReceiver.pulse_reaches(area, get_wall_rect()):
		_deflect()


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 2) ---

func _draw() -> void:
	var size: Vector2 = get_wall_size()
	var rect := Rect2(Vector2.ZERO, size)
	if _broken:
		if _break_left <= 0.0:
			return
		var k: float = _break_left / maxf(float(_cfg.get("break_s", 0.3)), 0.001)
		FeedCardDraw.card(self, rect.grow(4.0 * (1.0 - k)), k)
		return
	FeedCardDraw.card(self, rect, 1.0)
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var radius: float = float(_cfg.get("ring_radius_px", 20.0))
	var on: Color = World2ObjectsConfig.color("blanco" if _flash_left <= 0.0 else "magenta")
	var off: Color = World2ObjectsConfig.color("tarjeta_sombra")
	var gap: float = 0.25
	var span: float = TAU / float(maxi(pounds_needed, 1))
	# El circulo de carga gira despacio (cargando…); los segmentos llenos, en blanco.
	var spin: float = _time * float(_cfg.get("spin_rad_s", 1.5))
	for i: int in pounds_needed:
		var a0: float = -PI * 0.5 + float(i) * span + gap * 0.5
		draw_arc(c, radius, a0, a0 + span - gap, 12, on if i < _filled else off, 5.0)
	draw_arc(c, radius - 9.0, spin, spin + 1.2, 8, World2ObjectsConfig.color("gris"), 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y - 14.0), String(_cfg.get("label", "Cargando…")),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, World2ObjectsConfig.color("gris"))
	if _deflect_left > 0.0:
		var grey: Color = World2ObjectsConfig.color("gris")
		for a: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(14.0, 0.0).rotated(deg_to_rad(a))
			draw_line(c - d, c + d, grey, 2.0)
