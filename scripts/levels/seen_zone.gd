## Zona «Visto» (tipo `seen_zone` del catalogo del Mundo 4; 2026-10-28, paso 2 de
## docs/propuesta-mundo-4.md §8, §3.5, patrones 19 y 22 de §3.8): rectangulo de
## width_tiles x height_tiles (1-4 x 1-3) desde su celda, en el suelo o en el aire,
## marcado con un DOBLE CHECK en su borde (lado `icon` del nivel, propiedad icon_side: left o right, a media altura,
## a caballo del borde para pulsarlo desde fuera). Sin colision; ROJO NUNCA: no hace
## dano. Estados:
##   - WAITING: en espera (checks en contorno gris); no congela.
##   - WARNING: aviso de warn_frames cuadros a anim_fps antes de activarse (los checks
##     se rellenan de uno en uno); no congela.
##   - ACTIVE: checks rellenos en verde_apagado; con el cuerpo de Isak dentro, lo
##     congela freeze_s (Isak.freeze, fuente FREEZE_SOURCE_ZONE: respeta la
##     inmunidad de 0,5 s tras descongelarse).
##   - INTERRUPTED: el pulso al doble check (PulseReceiver.pulse_reaches sobre
##     get_icon_rect) la interrumpe interrupt_s (4 s): checks tachados, no congela.
##     La cuenta del ciclo se para mientras dura; si al volver toca estar activa, el
##     aviso sale en los ultimos warn_frames de la interrupcion.
## Siempre activa (sin on_s) o con ciclo: on_s activa y off_s en espera (el aviso
## ocupa el final de off_s), desfasado `phase_s`. Todo en tiempo del mundo (el Debug
## la ralentiza). Vuelve a su estado inicial al reaparecer Isak. Aspecto PROVISIONAL
## por codigo (seccion seen_zone de data/world4_objects.json, paleta provisional).
## El origen es la esquina superior izquierda de su celda.
class_name SeenZone
extends Node2D

const GROUP: StringName = &"seen_zone"

enum State { WAITING, WARNING, ACTIVE, INTERRUPTED }

## Cambia de estado (sonidos y accesibilidad, paso 20).
signal state_changed(state: State)
## Ha congelado a Isak.
signal froze_isak(isak: Isak)
## El pulso la ha interrumpido.
signal interrupted

@export var object_id: StringName = &""
@export var width_tiles: int = 2
@export var height_tiles: int = 1
## Lado del doble check: &"left" o &"right".
@export var icon_side: StringName = &"left"
## Segundos de congelacion (tiempo del mundo).
@export var freeze_s: float = 1.5
## Ciclo: on_s activa y off_s en espera; on_s <= 0 = siempre activa.
@export var on_s: float = 0.0
@export var off_s: float = 0.0
## Desfase del ciclo (s).
@export var phase_s: float = 0.0
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true
## Isak al que congela (si es null se busca con LevelLookup).
var isak: Isak

var _cfg: Dictionary = World4ObjectsConfig.section("seen_zone")
var _cycle_t: float = 0.0
var _interrupt_left: float = 0.0
var _state: State = State.ACTIVE
var _anim_t: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.pulse_fired.connect(receive_pulse)
	EventBus.player_respawned.connect(_on_player_respawned)
	reset()
	_check_dark.call_deferred()


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Vuelve al estado inicial (al reaparecer Isak).
func reset() -> void:
	_cycle_t = maxf(phase_s, 0.0)
	_interrupt_left = 0.0
	_anim_t = 0.0
	_set_state(_cycle_state())
	queue_redraw()


## Avanza `dt` segundos de tiempo del mundo y congela a Isak si toca. Publico para las pruebas.
func advance(dt: float) -> void:
	_anim_t += dt
	if _interrupt_left > 0.0:
		_interrupt_left = maxf(_interrupt_left - dt, 0.0)
	elif has_cycle():
		_cycle_t = fmod(_cycle_t + dt, get_period())
	_set_state(_current_state())
	if _state == State.ACTIVE:
		_try_freeze()
	queue_redraw()


# --- Consultas ---

func get_state() -> State:
	return _state


func is_active() -> bool:
	return _state == State.ACTIVE


func is_interrupted() -> bool:
	return _state == State.INTERRUPTED


## Interrumpida y en el aviso de volver activa (los checks tachados se rellenan).
func is_rearming() -> bool:
	return _state == State.INTERRUPTED and _interrupt_left <= get_warn_s() and _cycle_state() != State.WAITING


func get_interrupt_left() -> float:
	return _interrupt_left


func has_cycle() -> bool:
	return on_s > 0.0 and off_s > 0.0


func get_period() -> float:
	return on_s + off_s if has_cycle() else 0.0


func get_interrupt_s() -> float:
	return float(_cfg.get("interrupt_s", 4.0))


## Aviso antes de activarse: warn_frames cuadros a anim_fps (9 a 12 fps = 0,75 s).
func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 0.01)


## Zona que congela (global).
func get_zone_rect() -> Rect2:
	var t: float = World4ObjectsConfig.tile_size()
	return Rect2(global_position, Vector2(float(width_tiles) * t, float(height_tiles) * t))


## Zona de golpe del doble check (global): a caballo del borde `icon`, a media altura.
func get_icon_rect() -> Rect2:
	var size_arr: Array = _cfg.get("icon_size_px", [36, 28])
	var size := Vector2(float(size_arr[0]), float(size_arr[1]))
	var zone: Rect2 = get_zone_rect()
	var edge_x: float = zone.position.x if icon_side == &"left" else zone.end.x
	return Rect2(Vector2(edge_x - size.x * 0.5, zone.get_center().y - size.y * 0.5), size)


## Ayuda de Eco: siempre explica (no se destruye).
func is_help_available() -> bool:
	return true


## Pulso de Isak (EventBus.pulse_fired): si alcanza el doble check, la interrumpe
## interrupt_s. Devuelve verdadero si la ha interrumpido ahora.
func receive_pulse(area: Area2D) -> bool:
	if _state == State.INTERRUPTED:
		return false
	if not PulseReceiver.pulse_reaches(area, get_icon_rect()):
		return false
	interrupt()
	return true


## Interrumpe la zona (sin pulso: pruebas).
func interrupt() -> void:
	_interrupt_left = get_interrupt_s()
	_set_state(State.INTERRUPTED)
	interrupted.emit()
	queue_redraw()


# --- Interno ---

func _current_state() -> State:
	if _interrupt_left > 0.0:
		return State.INTERRUPTED
	return _cycle_state()


## Estado del ciclo (sin la interrupcion) en _cycle_t.
func _cycle_state() -> State:
	if not has_cycle():
		return State.ACTIVE
	if _cycle_t < on_s:
		return State.ACTIVE
	if _cycle_t >= get_period() - get_warn_s():
		return State.WARNING
	return State.WAITING


func _set_state(state: State) -> void:
	if state == _state:
		return
	_state = state
	state_changed.emit(state)


func _try_freeze() -> void:
	if isak == null or not is_instance_valid(isak) or not isak.is_inside_tree():
		isak = LevelLookup.find_isak(self)
	if isak == null or isak.is_dead() or isak.is_frozen():
		return
	if not LevelLookup.isak_body_rect(isak).intersects(get_zone_rect()):
		return
	# Al liberarse, el golpe (2026-10-28) lo empuja fuera de la zona, desde su centro.
	var away: float = signf(isak.global_position.x - get_zone_rect().get_center().x)
	if isak.freeze(freeze_s, Isak.FREEZE_SOURCE_ZONE, away):
		froze_isak.emit(isak)


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


## En una zona «Modo oscuro» (paso 4) los checks se ven siempre: por encima del velo.
func _check_dark() -> void:
	if is_inside_tree() and DarkZone.covering(get_tree(), get_zone_rect().get_center()) != null:
		z_as_relative = false
		z_index = DarkZone.veil_z() + 1


## Checks rellenos: 0, 1 o 2 (aviso: de uno en uno).
func _checks_filled() -> int:
	match _state:
		State.ACTIVE:
			return 2
		State.WARNING:
			var into: float = get_warn_s() - (get_period() - _cycle_t)
			return 1 if into < get_warn_s() * 0.5 else 2
		State.INTERRUPTED:
			if is_rearming():
				return 1 if _interrupt_left > get_warn_s() * 0.5 else 2
			return 0
	return 0


func _draw() -> void:
	var t: float = World4ObjectsConfig.tile_size()
	var size := Vector2(float(width_tiles) * t, float(height_tiles) * t)
	var green: Color = World4ObjectsConfig.color("verde_apagado", Color("#7d9a80"))
	var gray: Color = World4ObjectsConfig.color("gris_claro", Color("#a9aebb"))
	var dark: Color = World4ObjectsConfig.color("chat_noche", Color("#0f1422"))
	var fill_alpha: float = float(_cfg.get("active_fill_alpha", 0.22))
	var line: float = float(_cfg.get("outline_px", 2.0))
	if _state == State.ACTIVE:
		draw_rect(Rect2(Vector2.ZERO, size), Color(green, fill_alpha))
		draw_rect(Rect2(Vector2.ZERO, size), green, false, line)
	else:
		# Contorno discontinuo gris (en espera, aviso o interrumpida).
		var dash: float = float(_cfg.get("dash_px", 8.0))
		var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
		for i: int in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(gray, 0.6), line, dash)
	# Doble check en el borde (con fondo oscuro para leerse sobre cualquier cosa).
	var icon_rect: Rect2 = get_icon_rect()
	icon_rect.position -= global_position
	draw_rect(icon_rect, Color(dark, 0.85))
	var filled: int = _checks_filled()
	var s: float = icon_rect.size.y * 0.6
	var c: Vector2 = icon_rect.get_center()
	for k: int in 2:
		var dx: float = (-0.3 + 0.6 * float(k)) * s
		var a := c + Vector2(dx - s * 0.5, 0.0)
		var b := c + Vector2(dx - s * 0.15, s * 0.35)
		var e := c + Vector2(dx + s * 0.5, -s * 0.4)
		var color: Color = green if k < filled else gray
		var width: float = 3.0 if k < filled else 1.5
		draw_polyline(PackedVector2Array([a, b, e]), color, width)
	if _state == State.INTERRUPTED:
		draw_line(icon_rect.position + Vector2(2.0, icon_rect.size.y - 2.0),
			icon_rect.end - Vector2(2.0, icon_rect.size.y - 2.0), gray, 2.0)
