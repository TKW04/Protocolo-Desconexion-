## Campana de alarma (Mundo 1; Tramo 4 «Alarmas» del 1-3, docs/propuesta-1-3.md
## §3.5 y §5.5; paso 6 de §7). Valores en data/enemies/alarm_bell.json.
##
## El nodo esta en la celda E del nivel, colgada del techo (origen en los pies
## de la celda, abajo-centro; la campana se dibuja arriba de la celda). Con
## cada ciclo de su metronomo `rhythm` (RhythmZone / AlarmTunnel), desplazado
## `offset` (fraccion del ciclo), o de su propio interval_s si no tiene:
## - warn: AVISO de anticipation_frames cuadros a anim_fps (9 a 12: 0,75 s): la
##   campana tiembla y una linea discontinua roja marca la columna en el suelo.
## - wave: ONDA vertical de un tile de ancho desde la campana hasta el suelo
##   (wave_tiles celdas) durante wave_s; tocarla quita contact_damage de Sync
##   Rate (Isak.take_hit: invulnerabilidad breve) y empuja hacia push_direction.
## - rest: quieta.
## Familia del banner: indestructible y no es un cuerpo (el laser la atraviesa,
## el pulso no le afecta); el dash la atraviesa (invulnerable). Tiempo del
## mundo (el Debug la ralentiza). Al reaparecer vuelve a su estado inicial (su
## metronomo tambien). Arte por script (paso 8, 2026-10-20): tools/gen_world1_dnd.py.
class_name AlarmBell
extends Node2D

signal state_changed(previous: StringName, current: StringName)
signal hit_player(amount: float)

const STATE_REST: StringName = &"rest"
const STATE_WARN: StringName = &"warn"
const STATE_WAVE: StringName = &"wave"
const DEFAULT_DATA_PATH: String = "res://data/enemies/alarm_bell.json"
## El mismo grupo que los demas enemigos: LevelRunner llama a reset_patrol.
const GROUP: StringName = &"enemy"
const TILE: float = 64.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

# Ajustes (data_path; los params del nivel los sobrescriben por nombre).
## Id del metronomo que sigue ("" = su propio interval_s).
var rhythm: String = ""
## Desplazamiento en el ciclo del metronomo (fraccion 0-1).
var offset: float = 0.0
var interval_s: float = 2.0
var phase_s: float = 0.0
var wave_tiles: int = 3
var wave_s: float = 0.4
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var contact_damage: float = 10.0
var push_direction: int = -1
var damage_width_px: float = 48.0
## Carpeta de los cuadros (tools/gen_world1_dnd.py).
var sprite_dir: String = "res://assets/sprites/enemies/alarm_bell/"

## Isak al que dana (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _t: float = 0.0
var _ready_ok: bool = false
var _rhythm_node: RhythmZone
var _waves: int = 0


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	# La onda repite su textura en vertical (draw_texture_rect con tile).
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ready_ok = true
	reset_patrol()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	if get_rhythm() == null:
		_t = fposmod(_t + WorldTime.scaled_delta(delta), get_cycle_s())
	_update_state()
	if _state == STATE_WAVE:
		var isak: Isak = _find_player()
		if isak != null:
			_check_hit(isak)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_warning() -> bool:
	return _state == STATE_WARN


func is_wave() -> bool:
	return _state == STATE_WAVE


func is_dangerous() -> bool:
	return _state == STATE_WAVE


## En combate (PassiveRegen): avisando o con la onda.
func is_combat_active() -> bool:
	return is_warning() or is_wave()


## Ayuda de Eco (cuando la tenga, paso 8): nunca se destruye.
func is_help_available() -> bool:
	return true


func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


func get_rhythm() -> RhythmZone:
	if rhythm == "":
		return null
	if _rhythm_node == null or not is_instance_valid(_rhythm_node):
		_rhythm_node = RhythmZone.find(self, StringName(rhythm))
	return _rhythm_node


## Ciclo actual (s de tiempo del mundo): el del metronomo o interval_s.
func get_cycle_s() -> float:
	var r: RhythmZone = get_rhythm()
	if r != null:
		return r.get_cycle_s()
	return maxf(interval_s, get_warn_s() + wave_s + 0.01)


## Segundos (tiempo del mundo) dentro de su propio ciclo (con su desfase).
func get_cycle_time() -> float:
	var r: RhythmZone = get_rhythm()
	if r != null:
		return fposmod(r.get_beat_phase() - offset, 1.0) * r.get_cycle_s()
	return _t


## Ondas lanzadas desde el ultimo reinicio.
func get_wave_count() -> int:
	return _waves


## Onda en coordenadas globales: un tile de ancho (zona de dano damage_width_px)
## desde lo alto de la celda de la campana hasta el suelo.
func get_wave_rect() -> Rect2:
	var top: float = global_position.y - TILE
	return Rect2(Vector2(global_position.x - damage_width_px * 0.5, top),
		Vector2(damage_width_px, float(wave_tiles) * TILE))


# --- Acciones ---

## Vuelve al estado inicial (reaparicion de Isak, LevelRunner).
func reset_patrol() -> void:
	if not _ready_ok:
		return
	_t = fmod(phase_s, get_cycle_s())
	_state = &""
	_waves = 0
	_update_state()


# --- Interno ---

func _phase_for(t: float) -> StringName:
	if t < get_warn_s():
		return STATE_WARN
	if t < get_warn_s() + wave_s:
		return STATE_WAVE
	return STATE_REST


func _update_state() -> void:
	var r: RhythmZone = get_rhythm()
	var next: StringName = STATE_REST
	if r == null or r.is_started():
		next = _phase_for(get_cycle_time())
	if next != _state:
		var previous: StringName = _state
		_state = next
		if next == STATE_WAVE:
			_waves += 1
		state_changed.emit(previous, next)


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


func _check_hit(isak: Isak) -> void:
	if not LevelLookup.isak_body_rect(isak).intersects(get_wave_rect()):
		return
	if not isak.take_hit(float(push_direction)):
		return
	GameState.apply_sync_damage(contact_damage)
	hit_player.emit(contact_damage)


## Cuadro de la campana del estado actual (tools/gen_world1_dnd.py):
## rest, warn_00/01 (tiembla, alterna a anim_fps) o ring_00/01 (suena).
func get_bell_frame() -> String:
	var f: int = int(floor(get_cycle_time() * anim_fps)) % 2
	if _state == STATE_WARN:
		return "alarm_bell_warn_%02d" % f
	if _state == STATE_WAVE:
		return "alarm_bell_ring_%02d" % f
	return "alarm_bell_rest_00"


func _tex(name: String) -> Texture2D:
	return load(sprite_dir + name + ".png") as Texture2D


func _draw() -> void:
	var top: float = -TILE
	var bell: Texture2D = _tex(get_bell_frame())
	if bell != null:
		draw_texture(bell, Vector2(-TILE * 0.5, top))
	if _state == STATE_WARN:
		# Linea discontinua roja en el suelo de su columna (parpadea).
		var line: Texture2D = _tex("alarm_warn_line_00")
		if line != null and int(floor(get_cycle_time() * anim_fps / 1.5)) % 2 == 0:
			var floor_y: float = top + float(wave_tiles) * TILE - line.get_size().y
			draw_texture(line, Vector2(-TILE * 0.5, floor_y))
	elif _state == STATE_WAVE:
		# Onda: textura de 48x64 repetida en vertical; las flechas bajan.
		var f: int = int(floor(get_cycle_time() * anim_fps)) % 2
		var wave: Texture2D = _tex("alarm_wave_%02d" % f)
		if wave != null:
			var h: float = float(wave_tiles) * TILE - 36.0
			var w: float = damage_width_px
			draw_texture_rect(wave, Rect2(Vector2(-w * 0.5, top + 36.0), Vector2(w, h)), true)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("AlarmBell: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	rhythm = String(d.get("rhythm", ""))
	offset = float(d.get("offset", 0.0))
	interval_s = float(d["interval_s"])
	phase_s = float(d.get("phase_s", 0.0))
	wave_tiles = int(d["wave_tiles"])
	wave_s = float(d["wave_s"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	contact_damage = float(d["contact_damage"])
	push_direction = int(d.get("push_direction", -1))
	damage_width_px = float(d.get("damage_width_px", 48.0))
	sprite_dir = String(d.get("sprite_dir", sprite_dir))
	return true
