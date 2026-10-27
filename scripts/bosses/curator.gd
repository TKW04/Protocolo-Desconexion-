## La Curadora, jefe del Mundo 3 «La Vitrina» (docs/propuesta-mundo-3.md §5;
## pasos 14-15 de §8, 2026-10-27). Un BossBase con tres fases; datos en
## data/bosses/curator.json (arena, flash, floor_filter, crop, phase1-3, laps,
## texts). Arena data/levels/3-boss.json «Exposición» (20 x 11, camara fija).
##
## - Cuerpo: marco de foto de 8 x 4 tiles (no solido) con la camara-cabeza en el
##   centro de su lado de arriba. El punto debil (WeakPoint, la «pantalla rota»)
##   solo esta activo en las VENTANAS y cada ventana da un golpe: Debug (revela)
##   -> pulso con el Debug ACTIVO (marca laps.<n>.mark_duration_s) -> laser (un
##   golpe, sin Debug; laps.<n>.mark_hits = 1: la marca termina) -> la ventana se
##   cierra. Nada mas hace dano.
## - Fase 1 «Sesion de fotos»: sesiones de flash (aro y «3-2-1 ¡Sonríe!»: ciega
##   1,5 s si la linea de la lente llega a Isak; tapan los biombos, las
##   plataformas de likes y el terreno), filtro de suelo (pinchos ocultos que solo
##   enseña el Debug) y recorte (franja de 3 columnas). Tras cada sesion baja a
##   encuadrar 2 filas (ventana) con la lente a la altura de una plataforma de
##   likes y suelta 6 corazones.
## - Fase 2 «De espaldas»: el nucleo esta de espaldas (WeakPoint.set_via_only):
##   solo llegan el pulso y el laser que el ESPEJO CAZADOR (objeto de la arena,
##   activo en la fase 2) manda a un espejo de esquina. Flash reflejado (sale de
##   un espejo de esquina, alternando), recorte y dos Ladrones de likes (enemigos
##   de la arena activos en la fase 2). Cada 3 ataques posa 5 s (ventana).
## - Fase 3 «Retrato perfecto»: Reflejos falsos (FalseReflection del 3-3) con el
##   retraso de la vuelta y un filtro de pantalla completa que les da el mismo
##   aspecto que a Isak; con el Debug, Isak lleva su contorno cian y el reflejo
##   costuras rojas. Cada frame_interval_s un marco gigante se cierra sobre la
##   mitad de Isak (aviso 9 cuadros + 0,5 s): solo se salva comprimido en el marco
##   pequeno de ese lado; si no, -10 y empujon a la otra mitad. El reflejo que
##   pilla se borra y vuelve 2 s despues. Tras cada cierre baja a encuadrar 3 s.
## - Llegada, intro, reaparicion por fase (energia >= 50 y likes >= 10; tambien al
##   empezar cada fase), golpe final y secuencia de derrota como Autoplay
##   (BossBase, BossDefeat). Sin rollback.
## Arte PROVISIONAL por script (tools/gen_boss_curator.py, *_placeholder.png,
## paleta B del Mundo 3); avisos, filtros y textos por codigo. Tiempo del mundo
## (advance; las pruebas lo llaman a mano con auto_process falso).
class_name Curator
extends BossBase

## Empieza un ataque (flash, flash_reflected, floor_filter, crop), la ventana
## (window) o un marco que se cierra (closing_frame).
signal attack_started(attack: StringName)
## El flash se ha disparado (`blinded`: llego a Isak).
signal flashed(blinded: bool)
## Un marco se ha cerrado sobre la mitad `side` (`isak_safe`: comprimido en su
## marco pequeno o en la otra mitad).
signal frame_closed(side: String, isak_safe: bool)
## El cazador ha mandado el pulso o el laser a un espejo de esquina (`side`).
signal route_shown(side: String)
## Golpe final (contador a 0).
signal final_blow
signal disarmed

const WEAK_POINT_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const REFLECTION_SCENE: PackedScene = preload("res://scenes/enemies/false_reflection.tscn")

const ATTACK_FLASH: StringName = &"flash"
const ATTACK_FLASH_REFLECTED: StringName = &"flash_reflected"
const ATTACK_FLOOR_FILTER: StringName = &"floor_filter"
const ATTACK_CROP: StringName = &"crop"
const ATTACK_WINDOW: StringName = &"window"
const ATTACK_GAP: StringName = &"gap"
const ATTACK_CLOSING_FRAME: StringName = &"closing_frame"

const FRAME_IDLE: StringName = &"idle"
const FRAME_WARN: StringName = &"warn"
const FRAME_CLOSING: StringName = &"closing"

const SIDE_LEFT: String = "left"
const SIDE_RIGHT: String = "right"

const ART_FRAME: String = "curator_frame_placeholder.png"
const ART_FRAME_BACK: String = "curator_frame_back_placeholder.png"
const ART_FRAME_OFF: String = "curator_frame_off_placeholder.png"
const ART_BIOMBO: String = "curator_biombo_placeholder.png"

## Id del objeto en el nivel (params.id).
@export var object_id: StringName = &""
## Con Isak llegando por el vortice, espera a que termine y dice la intro.
@export var intro_on_arrival: bool = true

var _arena: Dictionary = {}
var _texts: Dictionary = {}
var _lap: Dictionary = {}
var _tile: float = 64.0
var _intro_state: int = 0
var _defeat_seq: BossDefeat
var _core: WeakPoint
var _attacks: Node2D
var _frame_sprite: Sprite2D
var _biombo_sprites: Array[Sprite2D] = []
var _fx: CuratorFx
var _label: Label
var _flash_label: Label
var _textures: Dictionary = {}
var _burst: PixelBurst
var _off: bool = false
var _rng := RandomNumberGenerator.new()
var _hunter: HunterMirror
# Linea de tiempo de las fases 1 y 2.
var _attack: StringName = &""
var _attack_t: float = 0.0
var _attack_index: int = 0
var _attacks_left: int = 0
var _gap_left: float = 0.0
var _flashes_left: int = 0
var _flash_source: Vector2 = Vector2.ZERO
var _reflected_side: String = SIDE_LEFT
var _filter_side: String = SIDE_LEFT
var _filter_rect: Rect2 = Rect2()
var _spike_rects: Array[Rect2] = []
var _crop_rect: Rect2 = Rect2()
var _window_side: String = SIDE_LEFT
var _lower: float = 0.0
var _hearts: Array[HeartPickup] = []
# Fase 3: marcos que se cierran y reflejos.
var _frame_state: StringName = FRAME_IDLE
var _frame_t: float = 0.0
var _frame_wait: float = 0.0
var _frame_side: String = SIDE_LEFT
var _reflections: Array[FalseReflection] = []
var _reflection_wait: Array[float] = []
# Camino del cazador (fase 2) que se dibuja un momento.
var _route: PackedVector2Array = PackedVector2Array()
var _route_left: float = 0.0


func _ready() -> void:
	if boss_id.is_empty():
		boss_id = &"curator"
	super._ready()
	var cfg: Dictionary = get_config()
	_arena = cfg.get("arena", {})
	_texts = cfg.get("texts", {})
	_tile = float(World3ObjectsConfig.tile_size())
	_lap = _lap_entry()
	_build()
	_apply_lap_settings.call_deferred()


func _physics_process(delta: float) -> void:
	if _intro_state == 0 and intro_on_arrival and not is_fighting() and not is_defeated():
		_poll_arrival()
	super._physics_process(delta)


func advance(dt: float) -> void:
	if not is_fighting():
		_refresh()
		return
	super.advance(dt)


# --- Consultas (HUD, bot y pruebas) ---

func get_core() -> WeakPoint:
	return _core


## Ataque en curso (ATTACK_*); ATTACK_NONE fuera de la pelea.
func get_attack_state() -> StringName:
	if not is_fighting():
		return ATTACK_NONE
	if is_window_open():
		return ATTACK_WINDOW
	if get_phase() == 3 and _frame_state != FRAME_IDLE:
		return ATTACK_CLOSING_FRAME
	return _attack if _attack != &"" else ATTACK_NONE


## Valor de la vuelta actual (laps.<n>.<key>).
func lap_value(key: String, fallback: Variant) -> Variant:
	return _lap.get(key, fallback)


## Datos de una fase (phase1, phase2, phase3).
func phase_data(phase_index: int) -> Dictionary:
	return get_config().get("phase%d" % phase_index, {})


## Aviso de `frames` cuadros a anim_fps (s del mundo).
func frames_s(frames: Variant) -> float:
	return float(frames) / maxf(float(_arena.get("anim_fps", 12.0)), 1.0)


## Rectangulo global del marco en reposo (sin bajar).
func get_frame_rect() -> Rect2:
	return _cells_rect(_arena.get("frame", [6, 1, 8, 4]))


## Px que ha bajado el marco ahora (0 arriba; lowered_rows tiles abajo del todo).
func get_lowered_offset() -> float:
	return _lower * float(_arena.get("lowered_rows", 2)) * _tile


## Centro global de la camara-cabeza (con el marco bajado si toca).
func get_lens_point() -> Vector2:
	var off: Array = _arena.get("lens_px", [256, 24])
	return get_frame_rect().position + Vector2(float(off[0]), float(off[1]) + get_lowered_offset())


## Centro global del espejo de esquina `side`.
func get_corner_center(side: String) -> Vector2:
	var cell: Array = (_arena.get("corner_mirrors", {}) as Dictionary).get(side, [1, 1])
	return _to_global(Vector2((float(cell[0]) + 0.5) * _tile, (float(cell[1]) + 0.5) * _tile))


## Lado de la lente en la ventana en curso (o la ultima).
func get_window_side() -> String:
	return _window_side


## Mitad del suelo y de la arena (filas 1 hasta el suelo) de `side`.
func get_half_rect(side: String) -> Rect2:
	var cols: Array = (_arena.get("halves", {}) as Dictionary).get(side, [1, 9])
	var floor_row: int = int(_arena.get("floor_row", 9))
	return _cells_rect([int(cols[0]), 1, int(cols[1]) - int(cols[0]) + 1, floor_row])


## Hueco del marco pequeno de `side` (global).
func get_small_frame_rect(side: String) -> Rect2:
	return _cells_rect((_arena.get("small_frames", {}) as Dictionary).get(side, [1, 9, 2, 1]))


## Lado de la arena en el que esta `x` (global).
func side_of_x(x: float) -> String:
	var mid: float = get_frame_rect().get_center().x
	return SIDE_LEFT if x < mid else SIDE_RIGHT


func get_filter_side() -> String:
	return _filter_side


## Rectangulo global del filtro de suelo en curso (Rect2() sin filtro).
func get_filter_rect() -> Rect2:
	return _filter_rect if _attack == ATTACK_FLOOR_FILTER else Rect2()


## Pinchos ocultos del filtro en curso (globales).
func get_spike_rects() -> Array[Rect2]:
	return _spike_rects.duplicate() if _attack == ATTACK_FLOOR_FILTER else []


## Los pinchos del filtro danan ahora (el filtro ya entro).
func is_spikes_active() -> bool:
	return is_fighting() and _attack == ATTACK_FLOOR_FILTER \
		and _attack_t >= frames_s((get_config().get("floor_filter", {}) as Dictionary).get("enter_frames", 9)) - 0.0001


## Franja del recorte en curso (Rect2() sin recorte).
func get_crop_rect() -> Rect2:
	return _crop_rect if _attack == ATTACK_CROP else Rect2()


## El recorte corta ahora (tras su aviso).
func is_crop_cutting() -> bool:
	if not is_fighting() or _attack != ATTACK_CROP:
		return false
	var crop: Dictionary = get_config().get("crop", {})
	var warn: float = frames_s(crop.get("warn_frames", 9))
	return _attack_t >= warn - 0.0001 and _attack_t < warn + float(crop.get("cut_s", 0.4))


## El aro del flash esta avisando (antes de disparar).
func is_flash_warning() -> bool:
	return is_fighting() and (_attack == ATTACK_FLASH or _attack == ATTACK_FLASH_REFLECTED) and _flashes_left > 0


func get_flash_source() -> Vector2:
	return _flash_source


func get_frame_state() -> StringName:
	return _frame_state


func get_frame_side() -> String:
	return _frame_side


## Rectangulo del marco que se cierra (la mitad), Rect2() en reposo.
func get_closing_rect() -> Rect2:
	return get_half_rect(_frame_side) if _frame_state != FRAME_IDLE else Rect2()


## Segundos del mundo del ciclo del marco (desde el aviso).
func get_frame_t() -> float:
	return _frame_t


func get_reflections() -> Array[FalseReflection]:
	var out: Array[FalseReflection] = []
	for r: FalseReflection in _reflections:
		if is_instance_valid(r):
			out.append(r)
	return out


## Corazones que ha soltado y siguen sin coger.
func get_hearts() -> Array[HeartPickup]:
	var out: Array[HeartPickup] = []
	for h: HeartPickup in _hearts:
		if is_instance_valid(h) and not h.is_taken():
			out.append(h)
	return out


func get_hunter() -> HunterMirror:
	if _hunter == null or not is_instance_valid(_hunter):
		_hunter = _find_hunter()
	return _hunter


## Camino que se dibuja (cazador -> espejo de esquina -> espalda); vacio si no.
func get_route() -> PackedVector2Array:
	return _route if _route_left > 0.0 else PackedVector2Array()


## Lado del espejo de esquina al que mira el cazador ("" si a ninguno).
func get_hunter_corner() -> String:
	var hunter: HunterMirror = get_hunter()
	if hunter == null:
		return ""
	return _corner_for_index(hunter.get_facing_index())


func get_counter_text() -> String:
	return _label.text if _label != null else ""


func get_flash_text() -> String:
	return _flash_label.text if _flash_label != null and _flash_label.visible else ""


func is_screen_off() -> bool:
	return _off


func get_attacks_root() -> Node2D:
	return _attacks


## Rectangulos que tapan el flash (biombos y plataformas de likes), globales.
func get_cover_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for cells: Variant in _arena.get("biombos", []):
		out.append(_cells_rect(cells))
	for node: Node in _level_nodes():
		if node is LikePlatform:
			out.append((node as LikePlatform).get_card_rect())
	return out


## La linea de `source` (global) al centro del cuerpo de Isak no cruza terreno
## ni nada que tape (biombos, plataformas de likes): el flash le llega.
func can_flash_reach(source: Vector2) -> bool:
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead():
		return false
	var target: Vector2 = LevelLookup.isak_body_rect(isak).get_center()
	var covers: Array[Rect2] = get_cover_rects()
	var tiles: TileMapLayer = _tiles()
	var length: float = source.distance_to(target)
	var steps: int = maxi(ceili(length / 8.0), 1)
	for i: int in range(1, steps):
		var p: Vector2 = source.lerp(target, float(i) / float(steps))
		for rect: Rect2 in covers:
			if rect.has_point(p):
				return false
		if tiles != null:
			var cell: Vector2i = tiles.local_to_map(tiles.to_local(p))
			if tiles.get_cell_source_id(cell) >= 0:
				return false
	return true


# --- Pelea ---

## Empieza la intro ya (sin esperar a la llegada).
func begin_intro() -> void:
	if _intro_state != 0:
		return
	var text: String = String(_texts.get("intro", ""))
	if text.is_empty():
		_intro_state = 2
		start()
		return
	_intro_state = 1
	say_line(text, true, _on_intro_finished, &"intro")


func _on_phase_started(phase_index: int) -> void:
	_clear_attacks()
	_apply_lap_settings()
	BossBase.apply_phase_nodes(_level_root(), phase_index)
	_connect_hunter()
	_core.set_via_only(phase_index == 2)
	_core.set_enabled(false)
	_ensure_min_likes()
	_rng.seed = 3027 + phase_index
	_lower = 0.0
	var p: Dictionary = phase_data(phase_index)
	_attack_index = 0
	_attacks_left = (p.get("attacks", []) as Array).size()
	_attack = ATTACK_GAP
	_gap_left = float(p.get("first_delay_s", 1.0))
	_reflected_side = SIDE_LEFT
	_frame_state = FRAME_IDLE
	_frame_t = 0.0
	_frame_wait = float(p.get("first_delay_s", 1.0))
	if phase_index == 3:
		_start_reflections()
	if phase_index > 1:
		var line: String = String((_texts.get("phase_lines", {}) as Dictionary).get(str(phase_index), ""))
		if not line.is_empty():
			say_line(line, false, Callable(), &"phase")
	_update_label()
	_refresh()


func _on_phase_restarted(phase_index: int) -> void:
	for charger: Charger in _chargers():
		charger.make_ready()
	_on_phase_started(phase_index)


func _on_advance(dt: float) -> void:
	if _route_left > 0.0:
		_route_left = maxf(_route_left - dt, 0.0)
	var target: float = 1.0 if is_window_open() and get_phase() != 2 else 0.0
	var lower_s: float = maxf(float(_arena.get("lower_s", 0.3)), 0.01)
	_lower = move_toward(_lower, target, dt / lower_s)
	_step_reflections(dt)
	if get_phase() == 3:
		_advance_frames(dt)
	elif not is_window_open():
		if _attack == ATTACK_GAP:
			_gap_left -= dt
			if _gap_left <= 0.0:
				_next_attack_or_window()
		elif _attack != &"" and _attack != ATTACK_WINDOW:
			_advance_attack(dt)
	if is_fighting():
		_check_hazards()
	_refresh()


func _on_window_opened(_duration_s: float) -> void:
	_attack = ATTACK_WINDOW
	var phase_index: int = get_phase()
	var p: Dictionary = phase_data(phase_index)
	if phase_index == 2:
		var back: Array = _arena.get("back_core_px", [640, 88])
		_core.global_position = _to_global(Vector2(float(back[0]), float(back[1])))
	else:
		_window_side = _choose_window_side()
		var at: Array = (_arena.get("window_core_px", {}) as Dictionary).get(_window_side, [448, 326])
		_core.global_position = _to_global(Vector2(float(at[0]), float(at[1])))
	_core.set_enabled(true)
	_drop_hearts(int(p.get("window_hearts", 0)), phase_index == 3)
	attack_started.emit(ATTACK_WINDOW)


func _on_window_closed() -> void:
	_core.set_enabled(false)
	if get_phase() == 3:
		_attack = &""
		return
	_attack = ATTACK_GAP
	_attacks_left = (phase_data(get_phase()).get("attacks", []) as Array).size()
	_gap_left = float(phase_data(get_phase()).get("attack_gap_s", 0.5))


## Un golpe por ventana: el golpe la cierra (y la Curadora vuelve a subir).
func _on_core_hit(_remaining_hits: int) -> void:
	_update_label()
	if is_window_open():
		close_window()


func _on_defeated() -> void:
	_clear_attacks()
	_attack = &""
	_core.set_enabled(false)
	_off = true
	_update_label()
	_refresh()
	final_blow.emit()
	if defeat_sequence:
		_begin_defeat.call_deferred()


func _begin_defeat() -> void:
	if _defeat_seq != null or not is_inside_tree():
		return
	var root: Node = _level_root()
	var id: String = (root as GeneratedLevel).level_id if root is GeneratedLevel else ""
	if id.is_empty():
		id = String(GameState.current_level)
	_defeat_seq = BossDefeat.begin(self, root, id)


func get_defeat() -> BossDefeat:
	return _defeat_seq if _defeat_seq != null and is_instance_valid(_defeat_seq) else null


## Desarme en pixeles (BossDefeat): el marco con la pantalla rota se suelta.
func play_disarm() -> PixelBurst:
	var tex: Texture2D = _frame_sprite.texture if _frame_sprite != null else null
	var at: Vector2 = get_frame_rect().get_center()
	var cfg: Dictionary = (get_config().get("defeat", {}) as Dictionary).get("pixels", {})
	_frame_sprite.visible = false
	_label.visible = false
	_core.set_enabled(false)
	var root: Node = _level_root()
	_burst = PixelBurst.spawn(tex, at, 1.0, root if root != null else self, cfg)
	disarmed.emit()
	return _burst


func get_pixel_burst() -> PixelBurst:
	return _burst if _burst != null and is_instance_valid(_burst) else null


# --- Fases 1 y 2: sesiones de ataques ---

func _next_attack_or_window() -> void:
	if _attacks_left <= 0:
		var duration: float = float(phase_data(get_phase()).get("window_s", 5.0))
		if get_phase() == 1:
			duration = float(lap_value("phase1_window_s", 5.0))
		open_window(duration)
		return
	var order: Array = phase_data(get_phase()).get("attacks", [ATTACK_FLASH])
	var kind := StringName(String(order[_attack_index % order.size()]))
	_attack_index += 1
	_attacks_left -= 1
	start_attack(kind)


## Empieza el ataque `kind` ya (pruebas y bot: tambien fuera de su turno).
func start_attack(kind: StringName) -> void:
	_attack = kind
	_attack_t = 0.0
	var isak: Isak = find_isak()
	var isak_x: float = isak.global_position.x if isak != null else get_frame_rect().get_center().x
	match kind:
		ATTACK_FLASH:
			_flashes_left = maxi(int(lap_value("flashes_per_session", 1)), 1)
			_flash_source = get_lens_point()
		ATTACK_FLASH_REFLECTED:
			_flashes_left = 1
			_flash_source = get_corner_center(_reflected_side)
			_reflected_side = SIDE_RIGHT if _reflected_side == SIDE_LEFT else SIDE_LEFT
		ATTACK_FLOOR_FILTER:
			_setup_floor_filter(side_of_x(isak_x))
		ATTACK_CROP:
			var crop: Dictionary = get_config().get("crop", {})
			var width: int = maxi(int(crop.get("strip_cols", 3)), 1)
			var lanes: Dictionary = (_arena.get("lanes", {}) as Dictionary).get("floor", {})
			var lo: int = int(lanes.get("from_col", 1))
			var hi: int = int(lanes.get("to_col", 18))
			var col: int = int(floor(_from_global(Vector2(isak_x, 0.0)).x / _tile))
			var first: int = clampi(col - (width - 1) / 2, lo, hi - width + 1)
			var floor_row: int = int(_arena.get("floor_row", 9))
			_crop_rect = _cells_rect([first, 1, width, floor_row])
	attack_started.emit(kind)


func _advance_attack(dt: float) -> void:
	_attack_t += dt
	var done: bool = false
	match _attack:
		ATTACK_FLASH, ATTACK_FLASH_REFLECTED:
			var warn: float = frames_s((get_config().get("flash", {}) as Dictionary).get("warn_frames", 9))
			if _attack_t >= warn - 0.0001:
				_fire_flash()
				_flashes_left -= 1
				if _flashes_left > 0:
					_attack_t = 0.0
				else:
					done = true
		ATTACK_FLOOR_FILTER:
			var ff: Dictionary = get_config().get("floor_filter", {})
			done = _attack_t >= frames_s(ff.get("enter_frames", 9)) + float(ff.get("active_s", 4.0)) - 0.0001
		ATTACK_CROP:
			var crop: Dictionary = get_config().get("crop", {})
			done = _attack_t >= frames_s(crop.get("warn_frames", 9)) + float(crop.get("cut_s", 0.4)) - 0.0001
		_:
			done = true
	if done:
		_attack = ATTACK_GAP
		_gap_left = float(phase_data(get_phase()).get("attack_gap_s", 0.5))
		_spike_rects.clear()
		_filter_rect = Rect2()
		_crop_rect = Rect2()


func _fire_flash() -> void:
	var blinded: bool = can_flash_reach(_flash_source)
	if blinded:
		var flash: Dictionary = get_config().get("flash", {})
		var peak: float = float(flash.get("veil_alpha_reduced", 0.4)) if GameSettings.is_low_sync_reduced() \
			else float(flash.get("veil_alpha", 0.7))
		FlashVeil.for_node(self).blind(peak, float(flash.get("veil_hold_s", 1.0)), float(flash.get("veil_fade_s", 0.5)),
			_color("flash_color", Color.WHITE), World3ObjectsConfig.color("alerta_sombra"),
			float(flash.get("outline_px", 3.0)), int(flash.get("veil_z_index", 50)))
	flashed.emit(blinded)


func _setup_floor_filter(isak_side: String) -> void:
	var ff: Dictionary = get_config().get("floor_filter", {})
	var rows: Array = _arena.get("floor_filter_rows", [7, 9])
	var row0: int = int(rows[0])
	var row1: int = int(rows[1])
	var floor_row: int = int(_arena.get("floor_row", 9))
	var spikes: Dictionary = ff.get("spikes", {})
	var height: float = float(ff.get("spike_height_px", 24))
	_spike_rects.clear()
	var cols: Array = []
	if String(lap_value("floor_filter", "half")) == "all_but_strip":
		# Raíz: todo el suelo salvo una franja (alrededor de Isak al empezar).
		_filter_side = "all"
		var lanes: Dictionary = (_arena.get("lanes", {}) as Dictionary).get("floor", {})
		var lo: int = int(lanes.get("from_col", 1))
		var hi: int = int(lanes.get("to_col", 18))
		_filter_rect = _cells_rect([lo, row0, hi - lo + 1, row1 - row0 + 1])
		cols = spikes.get("all", [])
	else:
		_filter_side = isak_side
		var half: Array = (_arena.get("halves", {}) as Dictionary).get(isak_side, [1, 9])
		_filter_rect = _cells_rect([int(half[0]), row0, int(half[1]) - int(half[0]) + 1, row1 - row0 + 1])
		cols = spikes.get(isak_side, [])
	for c: Variant in cols:
		var cell: Rect2 = _cells_rect([int(c), floor_row, 1, 1])
		_spike_rects.append(Rect2(cell.position.x, cell.end.y - height, cell.size.x, height))


## Pinchos del filtro, recorte: dano al tocar a Isak (-damage con su golpe normal).
func _check_hazards() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead():
		return
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	if is_spikes_active():
		var dmg: float = float((get_config().get("floor_filter", {}) as Dictionary).get("damage", 10.0))
		for rect: Rect2 in _spike_rects:
			if rect.intersects(body):
				_hurt(isak, dmg, signf(body.get_center().x - rect.get_center().x))
				break
	if is_crop_cutting() and _crop_rect.intersects(body):
		var cdmg: float = float((get_config().get("crop", {}) as Dictionary).get("damage", 10.0))
		_hurt(isak, cdmg, signf(body.get_center().x - _crop_rect.get_center().x))


func _hurt(isak: Isak, damage: float, direction: float) -> bool:
	if not isak.take_hit(direction):
		return false
	GameState.apply_sync_damage(damage)
	return true


func _choose_window_side() -> String:
	if String(lap_value("window_side", "near")) == "random":
		return SIDE_LEFT if _rng.randi_range(0, 1) == 0 else SIDE_RIGHT
	var isak: Isak = find_isak()
	return side_of_x(isak.global_position.x) if isak != null else SIDE_LEFT


## Corazones de la ventana (heart_cols, a la altura de los pies). `near_only`:
## solo los `count` del lado de la ventana (fase 3).
func _drop_hearts(count: int, near_only: bool) -> void:
	_free_hearts()
	if count <= 0:
		return
	var cols: Array = _arena.get("heart_cols", [])
	if near_only:
		var mid: float = get_frame_rect().get_center().x
		cols = cols.filter(func(c: Variant) -> bool:
			var x: float = _to_global(Vector2((float(c) + 0.5) * _tile, 0.0)).x
			return (x < mid) == (_window_side == SIDE_LEFT))
	var row: int = int(_arena.get("hearts_row", 9))
	for i: int in mini(count, cols.size()):
		var heart := HeartPickup.new()
		heart.name = "CuratorHeart%d" % i
		heart.value = 1
		_attacks.add_child(heart)
		heart.global_position = _to_global(Vector2(float(cols[i]) * _tile, float(row) * _tile))
		_hearts.append(heart)


func _free_hearts() -> void:
	for h: HeartPickup in _hearts:
		if is_instance_valid(h):
			h.queue_free()
	_hearts.clear()


func _ensure_min_likes() -> void:
	var min_likes: int = int(get_config().get("respawn_min_likes", 0))
	if GameState.likes < min_likes:
		GameState.set_likes(min_likes)


# --- Fase 2: el espejo cazador ---

func _find_hunter() -> HunterMirror:
	var wanted: String = String(_arena.get("hunter", ""))
	for node: Node in _level_nodes():
		if node is HunterMirror and (wanted.is_empty() or String((node as HunterMirror).object_id) == wanted):
			return node as HunterMirror
	return null


func _connect_hunter() -> void:
	var hunter: HunterMirror = get_hunter()
	if hunter == null:
		return
	if not hunter.beam_fired.is_connected(_on_hunter_beam):
		hunter.beam_fired.connect(_on_hunter_beam)
	if not hunter.laser_redirected.is_connected(_on_hunter_laser):
		hunter.laser_redirected.connect(_on_hunter_laser)


## Lado del espejo de esquina al que apunta la orientacion `index` del cazador.
func _corner_for_index(index: int) -> String:
	var hunter: HunterMirror = get_hunter()
	if hunter == null:
		return ""
	for side: String in [SIDE_LEFT, SIDE_RIGHT]:
		if HunterMirror.index_for_vector(get_corner_center(side) - hunter.get_center()) == posmod(index, 8):
			return side
	return ""


## El pulso reflejado por el cazador (fase 2): mirando a un espejo de esquina,
## sube a el y llega a la espalda (marca con el Debug activo); mirando al marco
## da en su frente (chispa gris).
func _on_hunter_beam(from: Vector2, to: Vector2) -> void:
	if not is_fighting() or get_phase() != 2:
		return
	var side: String = get_hunter_corner()
	if not side.is_empty():
		_show_route(side)
		_core.receive_via_pulse(get_hunter())
		return
	var frame: Rect2 = get_frame_rect()
	if HunterMirror.segment_hits_rect(from, to, frame):
		_core.show_deflect(Vector2(clampf(from.x, frame.position.x, frame.end.x), frame.end.y), get_hunter())


## El laser que el cazador manda a un espejo de esquina llega a la espalda: es el
## golpe si esta marcada (el disparo se apaga en el camino).
func _on_hunter_laser(projectile: Node, _at: Vector2, heading: Vector2) -> void:
	if not is_fighting() or get_phase() != 2:
		return
	var side: String = _corner_for_index(HunterMirror.index_for_vector(heading))
	if side.is_empty():
		return
	_show_route(side)
	_absorb_shot.call_deferred(projectile)
	var damage: float = 1.0
	var shooter: Node = null
	if projectile is LaserProjectile:
		damage = (projectile as LaserProjectile).damage
		shooter = (projectile as LaserProjectile).source
	_core.receive_via_laser(damage, shooter)


func _absorb_shot(projectile: Node) -> void:
	if projectile is LaserProjectile and is_instance_valid(projectile):
		(projectile as LaserProjectile).strike(null)


func _show_route(side: String) -> void:
	var hunter: HunterMirror = get_hunter()
	if hunter == null:
		return
	var back: Array = _arena.get("back_core_px", [640, 88])
	_route = PackedVector2Array([hunter.get_center(), get_corner_center(side),
		_to_global(Vector2(float(back[0]), float(back[1])))])
	_route_left = 0.4
	route_shown.emit(side)


# --- Fase 3: marcos que se cierran y Reflejos falsos ---

func _advance_frames(dt: float) -> void:
	var p: Dictionary = phase_data(3)
	var warn: float = frames_s(p.get("frame_warn_frames", 9))
	var close_s: float = float(p.get("frame_close_s", 0.5))
	_frame_t += dt
	match _frame_state:
		FRAME_IDLE:
			if not is_window_open() and _frame_t >= _frame_wait - 0.0001:
				var isak: Isak = find_isak()
				_frame_side = side_of_x(isak.global_position.x) if isak != null else SIDE_LEFT
				_frame_state = FRAME_WARN
				_frame_t = 0.0
				_frame_wait = float(lap_value("frame_interval_s", 6.0))
				attack_started.emit(ATTACK_CLOSING_FRAME)
		FRAME_WARN:
			if _frame_t >= warn - 0.0001:
				_frame_state = FRAME_CLOSING
		FRAME_CLOSING:
			if _frame_t >= warn + close_s - 0.0001:
				_frame_state = FRAME_IDLE
				_close_frame()
				if is_fighting() and get_phase() == 3:
					open_window(float(p.get("window_s", 3.0)))


## El marco se cierra sobre la mitad _frame_side: Isak se salva comprimido en el
## marco pequeno de ese lado (o fuera de la mitad); si no, golpe y empujon a la
## otra mitad. Los reflejos de la mitad se borran y vuelven despues.
func _close_frame() -> void:
	var half: Rect2 = get_half_rect(_frame_side)
	var safe: bool = true
	var isak: Isak = find_isak()
	if isak != null and not isak.is_dead():
		var body: Rect2 = LevelLookup.isak_body_rect(isak)
		if half.has_point(body.get_center()):
			safe = isak.is_compressed() and get_small_frame_rect(_frame_side).grow(2.0).encloses(body)
			if not safe:
				var push: int = int((_arena.get("push_col", {}) as Dictionary).get(_frame_side, 10))
				var dir: float = 1.0 if _frame_side == SIDE_LEFT else -1.0
				_hurt(isak, float(phase_data(3).get("frame_damage", 10.0)), dir)
				isak.global_position = _to_global(Vector2((float(push) + 0.5) * _tile,
					float(int(_arena.get("floor_row", 9)) + 1) * _tile))
				isak.velocity = Vector2.ZERO
	var respawn: float = float(phase_data(3).get("reflection_respawn_s", 2.0))
	for i: int in _reflections.size():
		var r: FalseReflection = _reflections[i]
		if is_instance_valid(r) and r.is_present() and half.has_point(r.get_body_rect_now().get_center()):
			r.vanish()
			_reflection_wait[i] = respawn
	frame_closed.emit(_frame_side, safe)


func _start_reflections() -> void:
	var delays: Array = lap_value("reflection_delays_s", [0.5])
	var emerge_s: float = float(phase_data(3).get("reflection_emerge_s", 1.0))
	for i: int in delays.size():
		var r := REFLECTION_SCENE.instantiate() as FalseReflection
		r.name = "Reflection_%d" % i
		r.auto_process = false
		# Sin pared: solo sale cuando la Curadora lo dice (emerge).
		r.axis_x = -1.0e6
		_attacks.add_child(r)
		r.delay_s = float(delays[i])
		_reflections.append(r)
		_reflection_wait.append(emerge_s)


## Avanza los reflejos (su paso es en tiempo real: lo escalan ellos) y los saca
## cuando toca; con el filtro del retrato tienen el mismo aspecto que Isak.
func _step_reflections(dt: float) -> void:
	if _reflections.is_empty():
		return
	var real: float = dt / maxf(WorldTime.scale(), 0.001)
	for i: int in _reflections.size():
		var r: FalseReflection = _reflections[i]
		if not is_instance_valid(r):
			continue
		r.step(real)
		if _reflection_wait[i] >= 0.0:
			_reflection_wait[i] -= dt
			if _reflection_wait[i] <= 0.0:
				_reflection_wait[i] = -1.0
				r.emerge()
		var mat: ShaderMaterial = r.get_shader_material()
		if mat != null:
			mat.set_shader_parameter(&"saturation", 1.0)
			mat.set_shader_parameter(&"tint", Color.WHITE)


func _free_reflections() -> void:
	for r: FalseReflection in _reflections:
		if is_instance_valid(r):
			r.queue_free()
	_reflections.clear()
	_reflection_wait.clear()


func _clear_attacks() -> void:
	_free_hearts()
	_free_reflections()
	_spike_rects.clear()
	_filter_rect = Rect2()
	_crop_rect = Rect2()
	_flashes_left = 0
	_attack = &""
	_attack_t = 0.0
	_frame_state = FRAME_IDLE
	_route_left = 0.0
	var veil: FlashVeil = FlashVeil.find(self)
	if veil != null:
		veil.clear()


# --- Construccion y dibujo ---

func _build() -> void:
	_frame_sprite = Sprite2D.new()
	_frame_sprite.name = "Frame"
	_frame_sprite.top_level = true
	_frame_sprite.centered = false
	_frame_sprite.z_index = -1
	_frame_sprite.texture = _texture(ART_FRAME)
	add_child(_frame_sprite)
	for cells: Variant in _arena.get("biombos", []):
		var biombo := Sprite2D.new()
		biombo.name = "Biombo%d" % _biombo_sprites.size()
		biombo.top_level = true
		biombo.centered = false
		biombo.z_index = 5
		biombo.texture = _texture(ART_BIOMBO)
		add_child(biombo)
		biombo.global_position = _cells_rect(cells).position
		_biombo_sprites.append(biombo)
	var font := load(String(_arena.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_label = _make_label("Counter", font)
	_flash_label = _make_label("FlashText", font)
	_flash_label.visible = false
	_core = WEAK_POINT_SCENE.instantiate() as WeakPoint
	_core.name = "BrokenScreen"
	_core.top_level = true
	add_child(_core)
	set_weak_point(_core)
	_core.set_enabled(false)
	_attacks = Node2D.new()
	_attacks.name = "Attacks"
	_attacks.top_level = true
	add_child(_attacks)
	_fx = CuratorFx.new()
	_fx.name = "CuratorFx"
	_fx.top_level = true
	_fx.z_index = 40
	_fx.boss = self
	add_child(_fx)
	_place_frame()


func _make_label(node_name: String, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.top_level = true
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", _color("label_color", Color.WHITE))
	label.scale = Vector2(2.0, 2.0)
	label.z_index = 41
	add_child(label)
	return label


func _texture(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		var path: String = String(_arena.get("art_dir", "res://assets/sprites/bosses/")) + file_name
		_textures[file_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[file_name]


func _place_frame() -> void:
	var rect: Rect2 = get_frame_rect()
	_frame_sprite.global_position = rect.position + Vector2(0.0, get_lowered_offset())
	_label.global_position = _frame_sprite.global_position + Vector2(24.0, 20.0)


func _refresh() -> void:
	if _frame_sprite == null:
		return
	if _off:
		_frame_sprite.texture = _texture(ART_FRAME_OFF)
	elif get_phase() == 2 and is_fighting():
		_frame_sprite.texture = _texture(ART_FRAME_BACK)
	else:
		_frame_sprite.texture = _texture(ART_FRAME)
	_place_frame()
	var text: String = ""
	if is_flash_warning():
		var flash: Dictionary = get_config().get("flash", {})
		var texts: Array = flash.get("texts", ["3", "2", "1", "¡Sonríe!"])
		var warn: float = frames_s(flash.get("warn_frames", 9))
		var i: int = clampi(floori(_attack_t / maxf(warn / float(texts.size()), 0.001)), 0, texts.size() - 1)
		text = String(texts[i])
	_flash_label.text = text
	_flash_label.visible = not text.is_empty()
	if _flash_label.visible:
		_flash_label.global_position = _flash_source + Vector2(-24.0, 36.0)
	_fx.queue_redraw()


func _update_label() -> void:
	if _label != null:
		_label.text = get_counter_label()


func _poll_arrival() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_warping() or isak.is_dead():
		return
	begin_intro()


func _on_intro_finished() -> void:
	_intro_state = 2
	start()
	_ensure_min_likes()


func _lap_entry() -> Dictionary:
	var lap: int = lap_override if lap_override > 0 else GameState.lap
	var laps: Dictionary = get_config().get("laps", {})
	return laps.get(str(lap), laps.get("1", {}))


func _apply_lap_settings() -> void:
	apply_charger_cooldown(float(lap_value("charger_cooldown_s", -1.0)))


## Nodos del nivel (todos los descendientes de la raiz).
func _level_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var root: Node = _level_root()
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out


func _tiles() -> TileMapLayer:
	var root: Node = _level_root()
	return root.get_node_or_null(^"Tiles") as TileMapLayer if root != null else null


## Color de la arena: nombre de la paleta del Mundo 3 o «#rrggbb».
func _color(key: String, fallback: Color) -> Color:
	var value: String = String(_arena.get(key, ""))
	if value.is_empty():
		return fallback
	if value.begins_with("#"):
		return Color.html(value)
	return World3ObjectsConfig.color(value, fallback)


func _to_global(p: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_global(p) if parent != null else p


func _from_global(p: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(p) if parent != null else p


## [col, fila, ancho, alto] en celdas -> Rect2 global.
func _cells_rect(cells: Variant) -> Rect2:
	var c: Array = cells
	var pos: Vector2 = _to_global(Vector2(float(c[0]) * _tile, float(c[1]) * _tile))
	return Rect2(pos, Vector2(float(c[2]) * _tile, float(c[3]) * _tile))


## Efectos por codigo (PROVISIONALES): aro del flash, filtro de suelo y sus
## pinchos (solo con el Debug), recorte, marco que se cierra, camino del cazador,
## filtro del retrato y, con el Debug, el contorno cian de Isak y las costuras
## rojas de los reflejos. Rojo = lo que dana.
class CuratorFx extends Node2D:
	var boss: Curator

	func _draw() -> void:
		if boss == null or not boss.is_fighting() or boss.is_screen_off():
			return
		var warn := boss._color("warn_color", Color.RED)
		var pink := boss._color("filter_color", Color.PINK)
		var gold := boss._color("route_color", Color.GOLD)
		var debug_a: float = DebugMode.get_intensity()
		if boss.is_flash_warning():
			var src: Vector2 = boss.get_flash_source()
			draw_arc(src, 26.0, 0.0, TAU, 24, Color(gold, 0.9), 4.0)
			draw_arc(src, 18.0, 0.0, TAU, 24, Color(warn, 0.8), 2.0)
		var filter: Rect2 = boss.get_filter_rect()
		if filter.has_area():
			var ff: Dictionary = boss.get_config().get("floor_filter", {})
			var enter: float = boss.frames_s(ff.get("enter_frames", 9))
			var grow: float = clampf(boss._attack_t / maxf(enter, 0.001), 0.0, 1.0)
			var r := filter
			if boss.get_filter_side() == Curator.SIDE_RIGHT:
				r = Rect2(filter.end.x - filter.size.x * grow, filter.position.y, filter.size.x * grow, filter.size.y)
			else:
				r = Rect2(filter.position, Vector2(filter.size.x * grow, filter.size.y))
			var alpha: float = float(ff.get("alpha", 0.6)) * (1.0 - 0.85 * debug_a)
			draw_rect(r, Color(pink, alpha))
			if debug_a > 0.0 and boss.is_spikes_active():
				for spike: Rect2 in boss.get_spike_rects():
					var pts := PackedVector2Array()
					var n: int = 4
					for i: int in n:
						var x0: float = spike.position.x + spike.size.x * float(i) / float(n)
						var x1: float = spike.position.x + spike.size.x * float(i + 1) / float(n)
						pts = PackedVector2Array([Vector2(x0, spike.end.y), Vector2((x0 + x1) * 0.5, spike.position.y), Vector2(x1, spike.end.y)])
						draw_colored_polygon(pts, Color(warn, debug_a))
		var crop: Rect2 = boss.get_crop_rect()
		if crop.has_area():
			if boss.is_crop_cutting():
				draw_rect(crop, Color(warn, 0.45))
			else:
				draw_rect(crop, Color(warn, 0.9), false, 4.0)
		var closing: Rect2 = boss.get_closing_rect()
		if closing.has_area():
			var p3: Dictionary = boss.phase_data(3)
			var w: float = boss.frames_s(p3.get("frame_warn_frames", 9))
			var c: float = float(p3.get("frame_close_s", 0.5))
			var f: float = clampf((boss.get_frame_t() - w) / maxf(c, 0.001), 0.0, 1.0)
			var thick: float = 8.0 + f * minf(closing.size.x, closing.size.y) * 0.5
			draw_rect(closing.grow(-thick * 0.5), Color(warn, 0.9), false, thick)
		var route: PackedVector2Array = boss.get_route()
		if route.size() >= 2:
			draw_polyline(route, Color(gold, 0.85), 6.0)
		if boss.get_phase() == 3:
			var p3b: Dictionary = boss.phase_data(3)
			var vp: Rect2 = Rect2(boss._to_global(Vector2.ZERO), Vector2(20.0, 11.0) * boss._tile)
			draw_rect(vp, Color(pink, float(p3b.get("portrait_filter_alpha", 0.22))))
			if debug_a > 0.0:
				var isak: Isak = boss.find_isak()
				if isak != null:
					var body: Rect2 = LevelLookup.isak_body_rect(isak).grow(4.0)
					draw_rect(body, Color(boss._color("isak_outline_color", Color.CYAN), debug_a), false, 3.0)
				for r2: FalseReflection in boss.get_reflections():
					if r2.is_present():
						var b: Rect2 = r2.get_body_rect_now()
						var seam := Color(boss._color("seam_color", Color.RED), debug_a)
						draw_rect(b, seam, false, 2.0)
						draw_line(Vector2(b.position.x, b.get_center().y), Vector2(b.end.x, b.get_center().y), seam, 2.0)
						draw_line(Vector2(b.get_center().x, b.position.y), Vector2(b.get_center().x, b.end.y), seam, 2.0)
