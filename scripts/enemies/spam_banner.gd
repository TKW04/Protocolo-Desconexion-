## Banner de spam (Mundo 1; 1-2 piso 2). docs/mundo-1-notificaciones.md 6.2:
## "Barre un pasillo horizontalmente a intervalos fijos. Cronometrar el salto".
## Paso 5 de docs/propuesta-1-2.md §10. Valores y explicacion en
## data/enemies/spam_banner.json.
##
## El nodo esta en la celda E del nivel: la ENTRADA del pasillo (origen en sus
## pies, abajo-centro). El pasillo son corridor_tiles celdas de esa fila hacia
## `direction`. Ciclo de interval_s (tiempo del mundo, WorldTime: el Debug lo
## ralentiza x0,5):
## - rest: la ranura de la entrada, apagada.
## - warn: AVISO de anticipation_frames cuadros a anim_fps (0,75 s): la ranura
##   parpadea en rojo alerta con flechas y una linea discontinua marca el suelo
##   del pasillo. Inofensivo.
## - sweep: el banner sale de la entrada y recorre el pasillo a
##   sweep_speed_px_s hasta que su borde delantero llega al final, con estela.
##   Tocar su zona de dano quita contact_damage de Sync Rate (Isak.take_hit:
##   invulnerabilidad breve; empuja hacia donde va el banner).
## No es un cuerpo fisico: el laser lo atraviesa y el pulso no le afecta
## (indestructible, decision de esta implementacion; ver el JSON).
## Dash (1-3, paso 4 de docs/propuesta-1-3.md §7): Isak invulnerable durante el
## dash no recibe el golpe (take_hit lo ignora). Con knockback_to_entry (banner
## obligatorio del 1-3, §5.2) el golpe ademas devuelve a Isak a la entrada del
## pasillo por su lado (la celda siguiente al final del barrido, get_return_x):
## encajar golpes no sirve para cruzar.
class_name SpamBanner
extends Node2D

signal state_changed(previous: StringName, current: StringName)
signal hit_player(amount: float)

const STATE_REST: StringName = &"rest"
const STATE_WARN: StringName = &"warn"
const STATE_SWEEP: StringName = &"sweep"

const DEFAULT_DATA_PATH: String = "res://data/enemies/spam_banner.json"
## El mismo grupo que los demas enemigos: LevelRunner llama a reset_patrol.
const GROUP: StringName = &"enemy"
const LAYER_PLAYER: int = 2
const TILE: float = 64.0
## Margen vertical de la consulta que busca a Isak sobre el pasillo (px).
const QUERY_MARGIN_PX: float = 192.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

# Ajustes (data_path; los params del nivel los sobrescriben por nombre).
var corridor_tiles: int = 12
var direction: int = 1:
	set(value):
		direction = -1 if value < 0 else 1
var interval_s: float = 3.0
var sweep_speed_px_s: float = 640.0
## Adelanto del ciclo (s). Cambiarlo reinicia el ciclo.
var phase_s: float = 0.0:
	set(value):
		phase_s = maxf(value, 0.0)
		if _ready_ok:
			reset_patrol()
var contact_damage: float = 10.0
var banner_size: Vector2 = Vector2(128.0, 48.0)
var damage_size: Vector2 = Vector2(116.0, 40.0)
var damage_bottom_px: float = 4.0
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var warn_line: Dictionary = {}
## Banner obligatorio con el dash (1-3): el golpe devuelve a Isak a la entrada
## del pasillo (get_return_x) ademas del retroceso normal.
var knockback_to_entry: bool = false

## Isak al que dana. Si es null se busca en la capa player sobre el pasillo.
var target: Isak

var _state: StringName = &""
var _t: float = 0.0
var _ready_ok: bool = false
var _warn_time: float = 0.0
var _query: PhysicsShapeQueryParameters2D
var _query_shape: RectangleShape2D

@onready var _slot: AnimatedSprite2D = $Slot
@onready var _banner: AnimatedSprite2D = $Banner
@onready var _trail: AnimatedSprite2D = $Trail


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	_query_shape = RectangleShape2D.new()
	_query = PhysicsShapeQueryParameters2D.new()
	_query.shape = _query_shape
	_query.collision_mask = LAYER_PLAYER
	_query.collide_with_bodies = true
	_query.collide_with_areas = false
	_ready_ok = true
	reset_patrol()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	for s: AnimatedSprite2D in [_slot, _banner, _trail]:
		s.speed_scale = WorldTime.scale()
	_t += dt
	var interval: float = get_interval_s()
	while _t >= interval:
		_t -= interval
	_update_state()
	if _state == STATE_WARN:
		_warn_time += dt
		queue_redraw()
	if _state == STATE_SWEEP:
		var isak: Isak = _find_player()
		if isak != null:
			_check_hit(isak)


# --- Consultas ---

func get_state() -> StringName:
	return _state


## Ayuda de Eco: un banner nunca se destruye; mientras exista, ayuda.
func is_help_available() -> bool:
	return true


func is_warning() -> bool:
	return _state == STATE_WARN


func is_sweeping() -> bool:
	return _state == STATE_SWEEP


## En combate (PassiveRegen): avisando o barriendo su pasillo.
func is_combat_active() -> bool:
	return is_warning() or is_sweeping()


func is_dangerous() -> bool:
	return _state == STATE_SWEEP


func get_corridor_px() -> float:
	return float(corridor_tiles) * TILE


## Aviso: anticipation_frames cuadros a anim_fps (s de tiempo del mundo).
func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


## Lo que tarda el banner en recorrer el pasillo (s de tiempo del mundo).
func get_sweep_s() -> float:
	return maxf(get_corridor_px() - banner_size.x, 0.0) / sweep_speed_px_s


## Intervalo del ciclo: interval_s, o lo minimo para avisar y barrer.
func get_interval_s() -> float:
	return maxf(interval_s, get_warn_s() + get_sweep_s() + 0.01)


func get_rest_s() -> float:
	return get_interval_s() - get_warn_s() - get_sweep_s()


## Segundos (tiempo del mundo) desde que empezo el ciclo actual.
func get_cycle_time() -> float:
	return _t


## X local del borde de entrada del pasillo.
func get_entry_x() -> float:
	return -TILE * 0.5 * float(direction)


## Pasillo en coordenadas globales (una fila de alto).
func get_corridor_rect() -> Rect2:
	var a: float = global_position.x + get_entry_x()
	var b: float = a + float(direction) * get_corridor_px()
	return Rect2(Vector2(minf(a, b), global_position.y - TILE), Vector2(get_corridor_px(), TILE))


## Pies de la entrada del pasillo por el lado de Isak (knockback_to_entry):
## el centro de la celda siguiente al final del barrido (la E mas corridor_tiles
## celdas hacia direction), con los pies a la altura de la E.
func get_return_position() -> Vector2:
	return global_position + Vector2(float(direction) * get_corridor_px(), 0.0)


## X global del centro del banner (durante el barrido; si no, el del inicio).
func get_banner_center_x() -> float:
	var progress: float = 0.0
	if _state == STATE_SWEEP:
		progress = clampf((_t - get_rest_s() - get_warn_s()) * sweep_speed_px_s, 0.0,
			maxf(get_corridor_px() - banner_size.x, 0.0))
	return global_position.x + get_entry_x() + float(direction) * (banner_size.x * 0.5 + progress)


## Zona de dano en coordenadas globales (solo cuenta barriendo).
func get_damage_rect() -> Rect2:
	var cx: float = get_banner_center_x()
	var bottom: float = global_position.y - damage_bottom_px
	return Rect2(Vector2(cx - damage_size.x * 0.5, bottom - damage_size.y), damage_size)


# --- Acciones ---

## Vuelve al estado inicial del ciclo (reaparicion de Isak, LevelRunner).
func reset_patrol() -> void:
	if not _ready_ok:
		return
	_t = fmod(phase_s, get_interval_s())
	_state = &""
	_update_state()


# --- Interno ---

func _phase_for(t: float) -> StringName:
	var rest: float = get_rest_s()
	if t < rest:
		return STATE_REST
	if t < rest + get_warn_s():
		return STATE_WARN
	return STATE_SWEEP


func _update_state() -> void:
	var next: StringName = _phase_for(_t)
	if next != _state:
		var previous: StringName = _state
		_state = next
		_enter(next)
		state_changed.emit(previous, next)
	_place_sprites()


func _enter(state: StringName) -> void:
	# La ranura y la estela miran hacia donde va el banner; el banner no se
	# voltea (su texto se leeria al reves).
	var flip: bool = direction < 0
	_slot.flip_h = flip
	_trail.flip_h = flip
	match state:
		STATE_REST:
			_play(_slot, &"idle")
			_banner.visible = false
			_trail.visible = false
		STATE_WARN:
			_warn_time = 0.0
			_play(_slot, &"anticipate")
			_banner.visible = false
			_trail.visible = false
		STATE_SWEEP:
			_play(_slot, &"idle")
			_play(_banner, &"sweep")
			_play(_trail, &"trail")
			_banner.visible = true
			_trail.visible = true
	queue_redraw()


func _place_sprites() -> void:
	_slot.position = Vector2(get_entry_x(), -TILE * 0.5)
	var cx: float = get_banner_center_x() - global_position.x
	_banner.position = Vector2(cx, -TILE * 0.5)
	_trail.position = Vector2(cx - float(direction) * banner_size.x, -TILE * 0.5)
	# La estela no sale por detras de la entrada.
	_trail.visible = _state == STATE_SWEEP and absf(cx - get_entry_x()) > banner_size.x


func _play(sprite: AnimatedSprite2D, anim: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		sprite.set_frame_and_progress(0, 0.0)


func _draw() -> void:
	if _state != STATE_WARN or warn_line.is_empty():
		return
	var blink: float = maxf(float(warn_line.get("blink_s", 0.125)), 0.01)
	if fmod(_warn_time, blink * 2.0) >= blink:
		return
	var color := Color(String(warn_line.get("color", "#a3221c")))
	var dash: float = float(warn_line.get("dash_px", 16.0))
	var gap: float = float(warn_line.get("gap_px", 16.0))
	var thick: float = float(warn_line.get("thickness_px", 4.0))
	var y: float = float(warn_line.get("y_px", -4.0))
	var x: float = 0.0
	var length: float = get_corridor_px()
	while x < length:
		var w: float = minf(dash, length - x)
		var x0: float = get_entry_x() + float(direction) * x
		var left: float = x0 if direction > 0 else x0 - w
		draw_rect(Rect2(Vector2(left, y - thick * 0.5), Vector2(w, thick)), color)
		x += dash + gap


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = null
	if not is_inside_tree():
		return null
	var corridor: Rect2 = get_corridor_rect()
	_query_shape.size = corridor.size + Vector2(TILE * 2.0, QUERY_MARGIN_PX * 2.0)
	_query.transform = Transform2D(0.0, corridor.get_center())
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, 4):
		var isak := hit.get("collider") as Isak
		if isak != null:
			target = isak
			return isak
	return null


func _check_hit(isak: Isak) -> void:
	var feet: Vector2 = isak.global_position
	var hurt := Rect2(feet + Vector2(-isak.hitbox_size.x * 0.5, -isak.hitbox_size.y), isak.hitbox_size)
	if not hurt.intersects(get_damage_rect()):
		return
	if not isak.take_hit(float(direction)):
		return
	GameState.apply_sync_damage(contact_damage)
	if knockback_to_entry:
		# Vuelve a la entrada con el retroceso normal (HurtState) desde alli.
		isak.global_position = get_return_position()
	hit_player.emit(contact_damage)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("SpamBanner: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	corridor_tiles = int(d["corridor_tiles"])
	direction = int(d["direction"])
	interval_s = float(d["interval_s"])
	sweep_speed_px_s = float(d["sweep_speed_px_s"])
	phase_s = float(d.get("phase_s", 0.0))
	knockback_to_entry = bool(d.get("knockback_to_entry", false))
	contact_damage = float(d["contact_damage"])
	banner_size = Vector2(float(d["banner_size"][0]), float(d["banner_size"][1]))
	damage_size = Vector2(float(d["damage_size"][0]), float(d["damage_size"][1]))
	damage_bottom_px = float(d["damage_bottom_px"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	var line: Variant = d.get("warn_line", {})
	warn_line = line if line is Dictionary else {}
	var frames: SpriteFrames = load(String(d["sprites"]["frames_resource"])) as SpriteFrames
	if frames != null:
		for s: AnimatedSprite2D in [_slot, _banner, _trail]:
			s.sprite_frames = frames
	return true
