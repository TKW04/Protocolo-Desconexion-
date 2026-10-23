## Autoplay, jefe del Mundo 2 «El Feed» (docs/propuesta-mundo-2.md §5; pasos
## 15-16 de §8, 2026-10-23). Un BossBase con tres fases; datos en
## data/bosses/autoplay.json (arena, clips, phase1-3, laps, texts).
##
## - Cuerpo: una pantalla de 8 x 4 tiles con dos ojos-boton de play y su pie
##   hasta el suelo (no solidos). Debajo, la barra de reproduccion (las '-' del
##   nivel) por la que se desliza el CABEZAL: un WeakPoint en modo golpe al
##   suelo. Sin el Debug es un circulo gris mas; con el Debug ACTIVO, un golpe al
##   suelo que cae en su caja PAUSA al jefe (la marca de BossBase, Caché 4 s) y,
##   mientras dura, cada laser a la pantalla es un golpe (damage_rects). Sin
##   pausa, el laser a la pantalla saca chispa gris.
## - Pausa (is_paused): se congelan el clip en curso (olas, rayos, proyectiles),
##   la ventana, la cuenta de la fase 2 y el cabezal; la cinta de tarjetas
##   sigue. Al caducar, si habia ventana se cierra y empieza el clip siguiente.
## - Fases: clips (ola, rayos, barrido alto; en la 2 y la 3 tambien la cuenta
##   atras con 3 proyectiles) y, tras clips_per_cycle clips, la ventana
##   «A continuación…». Fase 2: la ventana es «Siguiente video en N»; si llega a
##   0 sin pausa el jefe recupera un golpe (heal_hits) y suelta una tanda de
##   clips seguidos. Fase 3: todo a x2 salvo los avisos (9 cuadros del mundo).
## - Cinta: dos columnas de tarjetas que suben y reaparecen abajo
##   (MovingPlatform con vuelta, de una via).
## - Llegada, intro, reaparicion por fase, golpe final y secuencia de derrota
##   como Alerta Mayor (BossBase). Sin rollback.
## Arte: la pantalla es arte final de AutoSprite (paso 23, 2026-10-23;
## tools/import_boss_autoplay.py, autoplay_<anim>_NN.png, ART_ANIMS); si faltan
## esos cuadros, vuelve a los *_placeholder.png. El pie, el cabezal y las
## tarjetas siguen por script (tools/gen_boss_autoplay.py, *_placeholder.png);
## textos de la pantalla y miniaturas por codigo. Tiempo del mundo (advance).
class_name Autoplay
extends BossBase

## Empieza un clip (wave, rays, sweep_high, countdown_shots) o la ventana (window).
signal attack_started(attack: StringName)
## La pausa empieza (true) o termina (false).
signal pause_changed(paused: bool)
## Cambia el numero de la cuenta de la fase 2 (5, 4, ... 1) o del «3-2-1».
signal countdown_tick(value: int)
## La cuenta de la fase 2 llego a 0 sin pausa: el jefe recupero golpes.
signal countdown_expired(healed: int)
## Golpe final (contador a 0): la pantalla se apaga.
signal final_blow
signal disarmed

## Ayudas de Eco con Q (paso 20 de docs/propuesta-mundo-2.md; data/help.json): por
## defecto de help_id (la seccion help de data/bosses/autoplay.json manda).
const HELP_SCREEN: StringName = &"autoplay"
const HELP_PLAYHEAD: StringName = &"autoplay_playhead"
const HELP_PAUSE: StringName = &"autoplay_pause_button"
const HELP_CARD: StringName = &"autoplay_card"
const HELP_COUNTDOWN: StringName = &"autoplay_countdown"
const HELP_CLIP: StringName = &"autoplay_clip"
const HELP_FAN: StringName = &"autoplay_fan"

const WEAK_POINT_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const BANNER_SCENE: PackedScene = preload("res://scenes/enemies/spam_banner.tscn")
const BELL_SCENE: PackedScene = preload("res://scenes/enemies/alarm_bell.tscn")

const CLIP_WAVE: StringName = &"wave"
const CLIP_RAYS: StringName = &"rays"
const CLIP_SWEEP_HIGH: StringName = &"sweep_high"
const CLIP_COUNTDOWN: StringName = &"countdown_shots"
const ATTACK_WINDOW: StringName = &"window"
const ATTACK_PAUSED: StringName = &"paused"
const ATTACK_GAP: StringName = &"gap"

const ART_SCREEN: String = "autoplay_screen_placeholder.png"
const ART_SCREEN_PAUSED: String = "autoplay_screen_paused_placeholder.png"
const ART_SCREEN_OFF: String = "autoplay_screen_off_placeholder.png"
const ART_STAND: String = "autoplay_stand_placeholder.png"
const ART_PLAYHEAD: String = "autoplay_playhead_placeholder.png"
const ART_CARD: String = "autoplay_card_placeholder.png"
## Arte final de la pantalla (tools/import_boss_autoplay.py): anim -> [cuadros,
## fps, bucle]. Sin bucle se queda en el ultimo cuadro (clip_cast: brillando
## mientras dura el clip; defeat: apagada). Lienzo de 576 x 320 con la pantalla
## de 512 x 256 a ART_MARGIN_PX del borde.
const ART_ANIMS: Dictionary = {
	"idle": [24, 12.0, true],
	"clip_cast": [8, 12.0, false],
	"countdown": [24, 12.0, true],
	"paused": [24, 12.0, true],
	"x2": [24, 12.0, true],
	"defeat": [13, 12.0, false],
}
const ART_MARGIN_PX: float = 32.0

## Id del objeto en el nivel (params.id).
@export var object_id: StringName = &""
## Con Isak llegando por el vortice, espera a que termine y dice la intro.
@export var intro_on_arrival: bool = true

var _arena: Dictionary = {}
var _clips_cfg: Dictionary = {}
var _texts: Dictionary = {}
var _lap: Dictionary = {}
var _tile: float = 64.0
var _intro_state: int = 0
var _defeat_seq: BossDefeat
var _core: WeakPoint
var _attacks: Node2D
var _screen: Sprite2D
var _stand: Sprite2D
var _playhead_sprite: Sprite2D
var _fx: ScreenFx
var _label: Label
var _screen_label: Label
var _textures: Dictionary = {}
## Arte final de la pantalla cargado (si no, los *_placeholder) y su animacion.
var _art_final: bool = false
var _art_anim: String = ""
var _art_t: float = 0.0
var _cards: Array[MovingPlatform] = []
var _banners: Dictionary = {}
var _bells: Array[AlarmBell] = []
var _shots: Array[NotificationShot] = []
var _burst: PixelBurst
var _music: AutoplayMusic
## Marca de la ayuda de la cuenta (sobre el texto de la pantalla).
var _countdown_help: CountdownHelp
var _off: bool = false
var _rng := RandomNumberGenerator.new()
# Linea de tiempo de la fase.
var _clip: StringName = &""
var _clip_t: float = 0.0
var _clip_index: int = 0
var _clips_left: int = 0
var _gap_left: float = 0.0
var _wave_dir: int = 1
var _sweep_dir: int = 1
var _rays_fired: int = 0
var _ray_cols: Array[int] = []
var _shots_fired: bool = false
var _last_count: int = -1
# Cabezal (x global del centro) y su slot de la ventana.
var _playhead_x: float = 0.0
var _slot: String = ""
var _playhead_dir: float = 1.0
# Fase 2: la ventana de esta vez se pauso (la cuenta se para y no cura).
var _countdown_stopped: bool = false
var _pause_impacts: int = 0
var _ray_volley: int = 0
var _ray_volley_t: float = 0.0


func _ready() -> void:
	if boss_id.is_empty():
		boss_id = &"autoplay"
	super._ready()
	var cfg: Dictionary = get_config()
	_arena = cfg.get("arena", {})
	_clips_cfg = cfg.get("clips", {})
	_texts = cfg.get("texts", {})
	_tile = float(World1ObjectsConfig.tile_size())
	_lap = _lap_entry()
	_build()
	_playhead_x = _slot_x("center")
	_place_playhead()
	_apply_lap_settings.call_deferred()


func _physics_process(delta: float) -> void:
	if _intro_state == 0 and intro_on_arrival and not is_fighting() and not is_defeated():
		_poll_arrival()
	super._physics_process(delta)


## La pausa congela la linea de tiempo del jefe (ventana incluida); la cinta
## sigue siempre (tambien antes de la pelea).
func advance(dt: float) -> void:
	_art_t += dt
	if not is_fighting() or is_paused():
		_advance_conveyor(dt)
		_refresh_screen()
		return
	super.advance(dt)


# --- Consultas (HUD, bot y pruebas) ---

func get_core() -> WeakPoint:
	return _core


## En pausa: el cabezal esta marcado (golpe al suelo con el Debug).
func is_paused() -> bool:
	return _core != null and _core.is_marked()


## Clip en curso (CLIP_*), ATTACK_WINDOW, ATTACK_GAP o ATTACK_PAUSED.
func get_attack_state() -> StringName:
	if not is_fighting():
		return ATTACK_NONE
	if is_paused():
		return ATTACK_PAUSED
	return _clip if _clip != &"" else ATTACK_NONE


func get_clip() -> StringName:
	return _clip


## Multiplicador de la fase (x2 en la 3).
func get_speed_scale() -> float:
	return float(phase_data(get_phase()).get("speed_scale", 1.0)) if get_phase() > 0 else 1.0


## Cuenta de la fase 2 que se ve (0 fuera de su ventana).
func get_countdown() -> int:
	if get_phase() != 2 or not is_window_open():
		return 0
	return ceili(get_window_time_left() - 0.0001)


func is_countdown_stopped() -> bool:
	return _countdown_stopped


## X global del centro del cabezal.
func get_playhead_x() -> float:
	return _playhead_x


## Centro global del cabezal (sobre la barra).
func get_playhead_position() -> Vector2:
	return _core.global_position if _core != null else Vector2.ZERO


## X global del centro de un slot de la barra (left, center, right).
func get_slot_x(slot: String) -> float:
	return _slot_x(slot)


func get_slot() -> String:
	return _slot


## Superficie global de la barra (y) y sus extremos.
func get_bar_surface_y() -> float:
	return _to_global(Vector2(0.0, float((_arena.get("bar", {}) as Dictionary).get("surface_row", 6)) * _tile)).y


## Rectangulo global de la pantalla.
func get_screen_rect() -> Rect2:
	return _cells_rect(_arena.get("screen", [6, 1, 8, 4]))


## Rectangulos globales donde el laser da a la pantalla.
func get_damage_rects() -> Array[Rect2]:
	return _core.get_damage_rects() if _core != null else []


func get_banners() -> Dictionary:
	return _banners


func get_bells() -> Array[AlarmBell]:
	return _bells


func get_shots() -> Array[NotificationShot]:
	var out: Array[NotificationShot] = []
	for shot: NotificationShot in _shots:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion() and not shot.is_done():
			out.append(shot)
	return out


func get_conveyor_cards() -> Array[MovingPlatform]:
	return _cards


func get_attacks_root() -> Node2D:
	return _attacks


func get_screen_text() -> String:
	return _screen_label.text if _screen_label != null else ""


func get_counter_text() -> String:
	return _label.text if _label != null else ""


func is_screen_off() -> bool:
	return _off


## Valor de la vuelta actual (laps.<n>.<key>).
func lap_value(key: String, fallback: Variant) -> Variant:
	return _lap.get(key, fallback)


## help_id de la pieza `key` (screen, playhead, pause, card, countdown, clip, fan):
## seccion help de data/bosses/autoplay.json.
func help_id(key: String) -> StringName:
	var defaults: Dictionary = {"screen": HELP_SCREEN, "playhead": HELP_PLAYHEAD, "pause": HELP_PAUSE,
		"card": HELP_CARD, "countdown": HELP_COUNTDOWN, "clip": HELP_CLIP, "fan": HELP_FAN}
	return StringName(String((get_config().get("help", {}) as Dictionary).get(key, defaults.get(key, ""))))


## La cuenta se ve en la pantalla: la de la fase 2 («Siguiente video en N», sin
## pausa) o el «3-2-1» del clip de la «Cuenta atras» antes del abanico.
func is_countdown_showing() -> bool:
	if not is_fighting() or is_paused() or _off:
		return false
	if get_phase() == 2 and is_window_open():
		return true
	return _clip == CLIP_COUNTDOWN and not _shots_fired


func get_music() -> AutoplayMusic:
	return _music if _music != null and is_instance_valid(_music) else null


## Datos de una fase (phase1, phase2, phase3).
func phase_data(phase_index: int) -> Dictionary:
	return get_config().get("phase%d" % phase_index, {})


## Aviso de `frames` cuadros a anim_fps (s del mundo).
func frames_s(frames: Variant) -> float:
	return float(frames) / maxf(float(_arena.get("anim_fps", 12.0)), 1.0)


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
	_start_music()
	_clear_attacks()
	_apply_lap_settings()
	BossBase.apply_phase_nodes(_level_root(), phase_index)
	_core.set_enabled(true)
	var p: Dictionary = phase_data(phase_index)
	_rng.seed = int(p.get("seed", 0))
	_slot = ""
	_clip_index = 0
	_wave_dir = 1
	_sweep_dir = 1
	_countdown_stopped = false
	_clip = ATTACK_GAP
	_gap_left = float(p.get("first_delay_s", 1.0))
	_clips_left = int(p.get("clips_per_cycle", 1))
	for card: MovingPlatform in _cards:
		card.speed_scale = get_speed_scale()
	if phase_index > 1:
		var line: String = String((_texts.get("phase_lines", {}) as Dictionary).get(str(phase_index), ""))
		if not line.is_empty():
			say_line(line, false, Callable(), &"phase")
	_update_label()
	_refresh_screen()


func _on_phase_restarted(phase_index: int) -> void:
	for charger: Charger in _chargers():
		charger.make_ready()
	_on_phase_started(phase_index)


func _on_advance(dt: float) -> void:
	_advance_conveyor(dt)
	if not is_fighting():
		_refresh_screen()
		return
	var scale_x: float = get_speed_scale()
	_step_attacks(dt, scale_x)
	if is_window_open():
		_advance_window_playhead(dt)
		_tick_countdown()
	elif _clip == ATTACK_GAP:
		_gap_left -= dt
		_advance_clip_playhead(dt, scale_x)
		if _gap_left <= 0.0:
			_next_clip_or_window()
	elif _clip != &"":
		_advance_clip_playhead(dt, scale_x)
		_advance_clip(dt, scale_x)
	_refresh_screen()


func _on_window_opened(_duration_s: float) -> void:
	_clip = ATTACK_WINDOW
	_countdown_stopped = false
	_last_count = -1
	var p: Dictionary = phase_data(get_phase())
	if bool(p.get("seek", false)):
		var slots: Array = p.get("seek_slots", ["left", "center", "right"])
		var options: Array = slots.filter(func(s: Variant) -> bool: return String(s) != _slot)
		if options.is_empty():
			options = slots
		_slot = String(options[_rng.randi_range(0, options.size() - 1)])
	else:
		_slot = String(p.get("window_slot", "center"))
	_playhead_x = _slot_x(_slot)
	_playhead_dir = 1.0
	_place_playhead()
	attack_started.emit(ATTACK_WINDOW)


func _on_window_closed() -> void:
	var p: Dictionary = phase_data(get_phase())
	var clips: int = int(p.get("clips_per_cycle", 1))
	if get_phase() == 2 and not _countdown_stopped:
		var gained: int = heal_hits(int(p.get("heal_hits", 1)))
		_update_label()
		countdown_expired.emit(gained)
		var heal_line: String = String(_texts.get("heal_line", ""))
		if gained > 0 and not heal_line.is_empty():
			say_line(heal_line, false, Callable(), &"heal")
		clips = int(p.get("punish_clips", clips))
	_clips_left = clips
	_gap_left = 0.0
	_clip = ATTACK_GAP


func _on_core_hit(_remaining_hits: int) -> void:
	_update_label()


func _on_defeated() -> void:
	_stop_music()
	_clear_attacks()
	_clip = &""
	_core.set_enabled(false)
	_off = true
	_update_label()
	_refresh_screen()
	final_blow.emit()
	if defeat_sequence:
		_begin_defeat.call_deferred()


## Secuencia de derrota (paso 10 de Alerta Mayor): BossDefeat bajo el nivel.
func _begin_defeat() -> void:
	if _defeat_seq != null or not is_inside_tree():
		return
	var root: Node = _level_root()
	var id: String = (root as GeneratedLevel).level_id if root is GeneratedLevel else ""
	if id.is_empty():
		id = String(GameState.current_level)
	_defeat_seq = BossDefeat.begin(self, root, id)


## Secuencia de derrota en curso (null antes del golpe final o sin ella).
func get_defeat() -> BossDefeat:
	return _defeat_seq if _defeat_seq != null and is_instance_valid(_defeat_seq) else null




## Desarme en pixeles (BossDefeat, fase DISARM): la pantalla apagada se suelta.
func play_disarm() -> PixelBurst:
	var tex: Texture2D = _screen.texture if _screen != null else null
	var at: Vector2 = get_screen_rect().get_center()
	var cfg: Dictionary = (get_config().get("defeat", {}) as Dictionary).get("pixels", {})
	_screen.visible = false
	_stand.visible = false
	_playhead_sprite.visible = false
	_screen_label.visible = false
	_label.visible = false
	_core.set_enabled(false)
	var root: Node = _level_root()
	_burst = PixelBurst.spawn(tex, at, 1.0, root if root != null else self, cfg)
	disarmed.emit()
	return _burst


func get_pixel_burst() -> PixelBurst:
	return _burst if _burst != null and is_instance_valid(_burst) else null


# --- Musica (mus_boss2 mientras dura la pelea: AutoplayMusic, ambience de audio) ---

func _start_music() -> void:
	if _music == null or not is_instance_valid(_music):
		_music = AutoplayMusic.new()
		_music.name = "AutoplayMusic"
		add_child(_music)


func _stop_music() -> void:
	if _music != null and is_instance_valid(_music):
		_music.queue_free()
	_music = null


# --- Linea de tiempo de los clips ---

func _next_clip_or_window() -> void:
	if _clips_left <= 0:
		var duration: float = float(phase_data(get_phase()).get("window_s", 5.0))
		if get_phase() == 2:
			duration = float(lap_value("countdown_s", 5.0))
		open_window(duration)
		return
	var order: Array = phase_data(get_phase()).get("clips", [CLIP_WAVE])
	var kind := StringName(String(order[_clip_index % order.size()]))
	_clip_index += 1
	_clips_left -= 1
	start_clip(kind)


## Empieza el clip `kind` ya (pruebas y bot: tambien fuera de su turno).
func start_clip(kind: StringName) -> void:
	_clip = kind
	_clip_t = 0.0
	_last_count = -1
	var scale_x: float = get_speed_scale()
	var damage: float = float(_clips_cfg.get("contact_damage", 10.0))
	match kind:
		CLIP_WAVE:
			_trigger_banner("floor", _wave_dir, float((_clips_cfg.get("wave", {}) as Dictionary).get("speed_px_s", 640.0)) * scale_x, damage)
			_wave_dir = -_wave_dir
		CLIP_SWEEP_HIGH:
			_trigger_banner("bar", _sweep_dir, float((_clips_cfg.get("sweep_high", {}) as Dictionary).get("speed_px_s", 640.0)) * scale_x, damage)
			_sweep_dir = -_sweep_dir
		CLIP_RAYS:
			_rays_fired = 0
			_ray_cols.clear()
			_ray_volley = 0
			_ray_volley_t = 0.0
		CLIP_COUNTDOWN:
			_shots_fired = false
	attack_started.emit(kind)


func _advance_clip(dt: float, scale_x: float) -> void:
	_clip_t += dt
	var done: bool = false
	match _clip:
		CLIP_WAVE:
			done = not (_banners["floor"] as SpamBanner).is_busy()
		CLIP_SWEEP_HIGH:
			done = not (_banners["bar"] as SpamBanner).is_busy()
		CLIP_RAYS:
			var rays: Dictionary = _clips_cfg.get("rays", {})
			var count: int = mini(int(rays.get("count", 3)), _bells.size())
			var spacing: float = float(rays.get("spacing_s", 0.5)) / maxf(scale_x, 0.01)
			var local_t: float = _clip_t - _ray_volley_t
			while _rays_fired < count and local_t >= float(_rays_fired) * spacing - 0.0001:
				_fire_ray(_bells[_rays_fired], rays)
				_rays_fired += 1
			var idle: bool = _rays_fired >= count and _bells.all(func(b: AlarmBell) -> bool: return not b.is_busy())
			if idle and _ray_volley + 1 < get_ray_volleys():
				# Tanda siguiente (Raiz, fase 3: §5.8): otra vez en la columna de
				# Isak, tras un respiro de volley_gap_s (tambien a x2).
				_ray_volley += 1
				_rays_fired = 0
				_ray_cols.clear()
				_ray_volley_t = _clip_t + float(rays.get("volley_gap_s", 0.5)) / maxf(scale_x, 0.01)
				idle = false
			done = idle
		CLIP_COUNTDOWN:
			var shots: Dictionary = _clips_cfg.get("shots", {})
			var warn: float = frames_s(shots.get("warn_frames", 9))
			if not _shots_fired:
				var n: int = clampi(3 - floori(_clip_t / maxf(warn / 3.0, 0.001)), 1, 3)
				if n != _last_count:
					_last_count = n
					countdown_tick.emit(n)
				if _clip_t >= warn - 0.0001:
					_fire_fan(shots, scale_x)
					_shots_fired = true
			done = _shots_fired and get_shots().is_empty()
	if done:
		_untag_clips()
		_clip = ATTACK_GAP
		_gap_left = float(phase_data(get_phase()).get("clip_gap_s", 0.5)) / maxf(scale_x, 0.01)


func _tick_countdown() -> void:
	if get_phase() != 2:
		return
	var n: int = get_countdown()
	if n != _last_count and n > 0:
		_last_count = n
		countdown_tick.emit(n)


func _trigger_banner(lane: String, dir: int, speed: float, damage: float) -> void:
	var banner := _banners.get(lane) as SpamBanner
	if banner == null:
		return
	var l: Dictionary = (_arena.get("lanes", {}) as Dictionary).get(lane, {})
	var from_col: int = int(l.get("from_col", 1))
	var to_col: int = int(l.get("to_col", 18))
	banner.direction = dir
	banner.corridor_tiles = to_col - from_col + 1
	banner.sweep_speed_px_s = speed
	banner.contact_damage = damage
	var entry: int = from_col if dir > 0 else to_col
	banner.global_position = _to_global(Vector2((float(entry) + 0.5) * _tile, float(l.get("surface_row", 10)) * _tile))
	banner.target = find_isak()
	banner.reset_patrol()
	banner.trigger()
	HelpCatalog.tag(banner, help_id("clip"))


func _fire_ray(bell: AlarmBell, rays: Dictionary) -> void:
	var floor_lane: Dictionary = (_arena.get("lanes", {}) as Dictionary).get("floor", {})
	var lo: int = int(floor_lane.get("from_col", 1))
	var hi: int = int(floor_lane.get("to_col", 18))
	var col: int = roundi(float(lo + hi) * 0.5)
	var isak: Isak = find_isak()
	if isak != null:
		col = int(floor(_from_global(isak.global_position).x / _tile))
	col = _free_ray_col(clampi(col, lo, hi), lo, hi)
	_ray_cols.append(col)
	var top_row: int = 1
	var surface: int = int(floor_lane.get("surface_row", 10))
	bell.wave_tiles = surface - top_row
	bell.wave_s = float(rays.get("wave_s", 0.4))
	bell.anticipation_frames = int(rays.get("anticipation_frames", 9))
	bell.anim_fps = float(_arena.get("anim_fps", 12.0))
	bell.contact_damage = float(_clips_cfg.get("contact_damage", 10.0))
	# La onda de la campana empieza un tile por encima de sus pies.
	bell.global_position = _to_global(Vector2((float(col) + 0.5) * _tile, float(top_row + 1) * _tile))
	bell.target = isak
	bell.reset_patrol()
	bell.trigger()
	HelpCatalog.tag(bell, help_id("clip"))


## La columna `col` si no ha caido ya un rayo en ella en esta tanda; si no, la
## libre mas cercana.
func _free_ray_col(col: int, lo: int, hi: int) -> int:
	for d: int in range(0, hi - lo + 1):
		for c: int in [col - d, col + d]:
			if c >= lo and c <= hi and not _ray_cols.has(c):
				return c
	return col


func _fire_fan(shots: Dictionary, scale_x: float) -> void:
	var screen: Rect2 = get_screen_rect()
	var origin := Vector2(screen.get_center().x, screen.end.y)
	var isak: Isak = find_isak()
	var aim: Vector2 = Vector2.DOWN
	if isak != null:
		aim = (isak.global_position + Vector2(0.0, -48.0) - origin).normalized()
	var count: int = int(shots.get("count", 3))
	var spread: float = deg_to_rad(float(shots.get("spread_deg", 14.0)))
	var size: Array = shots.get("size_px", [64, 32])
	for i: int in count:
		var offset: float = (float(i) - float(count - 1) * 0.5) * spread
		var heading: Vector2 = aim.rotated(offset)
		var shot := NotificationShot.new()
		shot.direction = 1 if heading.x >= 0.0 else -1
		shot.heading = heading
		shot.speed_px_s = float(shots.get("speed_px_s", 480.0)) * scale_x
		shot.size_px = Vector2(float(size[0]), float(size[1]))
		shot.contact_damage = float(_clips_cfg.get("contact_damage", 10.0))
		shot.travel_px = minf(float(shots.get("travel_px", 1100.0)), _travel_to_terrain(origin, heading))
		shot.target = isak
		shot.auto_process = false
		HelpCatalog.tag(shot, help_id("fan"))
		_attacks.add_child(shot)
		shot.global_position = origin
		_shots.append(shot)


## Distancia (px) desde `origin` (global) en la direccion `heading` hasta el
## terreno macizo de la arena (muros, techo y suelo: el interior es el carril del
## suelo hasta la fila 1). Los proyectiles de la «Cuenta atras» atraviesan la
## barra A PROPOSITO (es de una via, como para los rayos; si la pararan, la barra
## taparia casi todo el abanico, que sale del pie de la pantalla justo encima)
## y se apagan al llegar al terreno macizo (2026-10-23, paso 17).
func _travel_to_terrain(origin: Vector2, heading: Vector2) -> float:
	var floor_lane: Dictionary = (_arena.get("lanes", {}) as Dictionary).get("floor", {})
	var lo: Vector2 = _to_global(Vector2(float(floor_lane.get("from_col", 1)) * _tile, _tile))
	var hi: Vector2 = _to_global(Vector2(float(int(floor_lane.get("to_col", 18)) + 1) * _tile,
			float(floor_lane.get("surface_row", 10)) * _tile))
	var h: Vector2 = heading.normalized()
	var best: float = INF
	if h.x > 0.0001:
		best = minf(best, (hi.x - origin.x) / h.x)
	elif h.x < -0.0001:
		best = minf(best, (lo.x - origin.x) / h.x)
	if h.y > 0.0001:
		best = minf(best, (hi.y - origin.y) / h.y)
	elif h.y < -0.0001:
		best = minf(best, (lo.y - origin.y) / h.y)
	return maxf(best, 0.0)


## Avanza las olas, los rayos y los proyectiles `dt` s del mundo (no procesan
## solos: la pausa los congela). Los banners y las campanas escalan su delta
## real con WorldTime: se les pasa el real equivalente.
func _step_attacks(dt: float, _scale_x: float) -> void:
	var real: float = dt / maxf(WorldTime.scale(), 0.001)
	for banner: Variant in _banners.values():
		(banner as SpamBanner).step(real)
	for bell: AlarmBell in _bells:
		bell.step(real)
	for shot: NotificationShot in get_shots():
		shot.step(dt)
	_shots = get_shots()


## Las olas, barridos y rayos solo llevan su ayuda (autoplay_clip) mientras
## avisan o barren: en reposo no estan en ningun sitio que mirar.
func _untag_clips() -> void:
	for banner: Variant in _banners.values():
		HelpCatalog.tag(banner as Node, &"")
	for bell: AlarmBell in _bells:
		HelpCatalog.tag(bell, &"")


func _clear_attacks() -> void:
	_untag_clips()
	for banner: Variant in _banners.values():
		(banner as SpamBanner).reset_patrol()
	for bell: AlarmBell in _bells:
		bell.reset_patrol()
	for shot: NotificationShot in _shots:
		if is_instance_valid(shot):
			shot.queue_free()
	_shots.clear()
	_clip = &""
	_clip_t = 0.0


# --- Cabezal ---

func _slot_x(slot: String) -> float:
	var slots: Dictionary = _arena.get("slots", {})
	return _to_global(Vector2(float(slots.get(slot, 9.5)) * _tile, 0.0)).x


func _playhead_range() -> Vector2:
	var a: float = _to_global(Vector2(float(_arena.get("playhead_from_x", 5.5)) * _tile, 0.0)).x
	var b: float = _to_global(Vector2(float(_arena.get("playhead_to_x", 14.5)) * _tile, 0.0)).x
	return Vector2(a, b)


## Durante los clips el cabezal avanza con la reproduccion y vuelve al principio.
func _advance_clip_playhead(dt: float, scale_x: float) -> void:
	var r: Vector2 = _playhead_range()
	var speed: float = float(_arena.get("playhead_clip_speed_tiles_s", 1.5)) * _tile * scale_x
	_playhead_x += speed * dt
	if _playhead_x > r.y:
		_playhead_x = r.x + fmod(_playhead_x - r.y, maxf(r.y - r.x, 1.0))
	_place_playhead()


## En la ventana: quieto (Caché) o avanzando ida y vuelta (Kernel y Raíz).
func _advance_window_playhead(dt: float) -> void:
	var speed: float = float(lap_value("playhead_window_speed_tiles_s", 0.0)) * _tile * get_speed_scale()
	if speed <= 0.0:
		return
	var r: Vector2 = _playhead_range()
	_playhead_x += _playhead_dir * speed * dt
	if _playhead_x > r.y:
		_playhead_x = r.y
		_playhead_dir = -1.0
	elif _playhead_x < r.x:
		_playhead_x = r.x
		_playhead_dir = 1.0
	_place_playhead()


func _place_playhead() -> void:
	if _core == null:
		return
	var at := Vector2(_playhead_x, get_bar_surface_y() - float(_arena.get("playhead_lift_px", 20.0)))
	_core.global_position = at
	_playhead_sprite.global_position = at


# --- Cinta de tarjetas ---

func _advance_conveyor(dt: float) -> void:
	for card: MovingPlatform in _cards:
		card.advance(dt)


# --- Construccion y dibujo ---

func _build() -> void:
	_screen = Sprite2D.new()
	_screen.name = "Screen"
	_screen.top_level = true
	_screen.centered = false
	_screen.z_index = -1
	_art_final = _texture(_art_file("idle", 0)) != null
	_screen.texture = _texture(_art_file("idle", 0)) if _art_final else _texture(ART_SCREEN)
	add_child(_screen)
	HelpCatalog.tag(_screen, help_id("screen"))
	var margin: float = ART_MARGIN_PX if _art_final else 0.0
	_screen.global_position = get_screen_rect().position - Vector2(margin, margin)
	_stand = Sprite2D.new()
	_stand.name = "Stand"
	_stand.top_level = true
	_stand.centered = false
	_stand.z_index = -2
	_stand.texture = _texture(ART_STAND)
	add_child(_stand)
	var stand_rect: Rect2 = _cells_rect(_arena.get("stand", [9, 5, 2, 5]))
	_stand.global_position = stand_rect.position
	_playhead_sprite = Sprite2D.new()
	_playhead_sprite.name = "Playhead"
	_playhead_sprite.top_level = true
	_playhead_sprite.texture = _texture(ART_PLAYHEAD)
	add_child(_playhead_sprite)
	HelpCatalog.tag(_playhead_sprite, help_id("playhead"))
	var font := load(String(_arena.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_label = _make_label("Counter", font)
	# Con el arte final el marco es mas grueso: el contador va dentro de la pantalla.
	_label.global_position = get_screen_rect().position + (Vector2(36.0, 30.0) if _art_final else Vector2(20.0, 18.0))
	_screen_label = _make_label("ScreenText", font)
	_screen_label.size = Vector2(get_screen_rect().size.x * 0.5, 24.0)
	_screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_label.global_position = Vector2(get_screen_rect().position.x, get_screen_rect().end.y - 80.0)
	_countdown_help = CountdownHelp.new()
	_countdown_help.name = "CountdownHelp"
	_countdown_help.top_level = true
	_countdown_help.available = is_countdown_showing
	add_child(_countdown_help)
	_countdown_help.global_position = _screen_label.global_position + Vector2(_screen_label.size.x, 24.0)
	HelpCatalog.tag(_countdown_help, help_id("countdown"))
	_fx = ScreenFx.new()
	_fx.name = "ScreenFx"
	_fx.top_level = true
	_fx.boss = self
	add_child(_fx)
	_core = WEAK_POINT_SCENE.instantiate() as WeakPoint
	_core.name = "Playhead_Core"
	_core.top_level = true
	_core.mark_trigger = WeakPoint.TRIGGER_GROUND_POUND
	add_child(_core)
	# Solo con ayuda mientras se ve (revelado por el Debug o en pausa): oculto no
	# delata que el cabezal es el boton (WeakPoint.is_help_available).
	HelpCatalog.tag(_core, help_id("pause"))
	var box: Array = _arena.get("playhead_box_px", [-32, -44, 64, 76])
	_core.set_pound_box(Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3])))
	for cells: Variant in _arena.get("damage_rects", []):
		_core.add_damage_rect(_cells_rect(cells))
	set_weak_point(_core)
	_core.marked.connect(_on_marked)
	_core.mark_expired.connect(_on_pause_expired)
	_core.set_enabled(false)
	_attacks = Node2D.new()
	_attacks.name = "Attacks"
	_attacks.top_level = true
	_attacks.z_index = 40
	add_child(_attacks)
	for lane: String in ["floor", "bar"]:
		var banner := BANNER_SCENE.instantiate() as SpamBanner
		banner.name = "Banner_%s" % lane
		banner.manual = true
		_attacks.add_child(banner)
		banner.set_physics_process(false)
		banner.interval_s = 0.0
		banner.reset_patrol()
		_banners[lane] = banner
	var rays: int = int((_clips_cfg.get("rays", {}) as Dictionary).get("count", 3))
	for i: int in rays:
		var bell := BELL_SCENE.instantiate() as AlarmBell
		bell.name = "Ray_%d" % i
		bell.manual = true
		bell.draw_bell = false
		_attacks.add_child(bell)
		bell.set_physics_process(false)
		_bells.append(bell)
	_build_conveyor()


func _make_label(node_name: String, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.top_level = true
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color.html(String(_arena.get("label_color", "#f2f2fa"))))
	label.scale = Vector2(2.0, 2.0)
	add_child(label)
	return label


func _build_conveyor() -> void:
	var conv: Dictionary = _arena.get("conveyor", {})
	var bottom: float = float(conv.get("bottom_row", 10)) * _tile
	var top: float = float(conv.get("top_row", 3)) * _tile
	var height: float = float(conv.get("card_height_px", 24))
	var length: float = bottom - top
	var per_column: int = maxi(int(conv.get("cards", 2)), 1)
	var tex: Texture2D = _texture(ART_CARD)
	var host := Node2D.new()
	host.name = "Conveyor"
	host.top_level = true
	add_child(host)
	for cols: Variant in conv.get("columns", []):
		var a: int = int((cols as Array)[0])
		var b: int = int((cols as Array)[1])
		var width: float = float(b - a + 1) * _tile
		for i: int in per_column:
			var card := MovingPlatform.new()
			card.name = "Card_%d_%d" % [a, i]
			card.size = Vector2(width, height)
			card.travel = Vector2(0.0, -length)
			card.speed_px_s = float(conv.get("speed_tiles_s", 0.5)) * _tile
			card.wrap = true
			card.one_way = true
			card.texture = tex
			# Origen: la superficie de abajo (el centro va height/2 por debajo de la superficie).
			card.position = _to_global(Vector2(float(a) * _tile + width * 0.5, bottom + height * 0.5))
			host.add_child(card)
			card.set_physics_process(false)
			card.set_cycle_px(length * (0.25 + float(i) / float(per_column)))
			HelpCatalog.tag(card, help_id("card"))
			_cards.append(card)


func _texture(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		var path: String = String(_arena.get("art_dir", "res://assets/sprites/bosses/")) + file_name
		_textures[file_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[file_name]


func _refresh_screen() -> void:
	if _screen == null:
		return
	if _art_final:
		_screen.texture = _art_texture()
	if _off:
		if not _art_final:
			_screen.texture = _texture(ART_SCREEN_OFF)
		_screen_label.text = ""
		_fx.queue_redraw()
		return
	if not _art_final:
		_screen.texture = _texture(ART_SCREEN_PAUSED if is_paused() else ART_SCREEN)
	var text: String = ""
	if is_fighting():
		if is_paused():
			text = String(_texts.get("screen_paused", "En pausa"))
		elif _clip == ATTACK_WINDOW:
			if get_phase() == 2:
				text = String(_texts.get("screen_countdown", "Siguiente video en %d")) % get_countdown()
			else:
				text = String(_texts.get("screen_next", "A continuación…"))
		elif _clip == CLIP_COUNTDOWN and not _shots_fired:
			text = str(maxi(_last_count, 1))
		elif get_phase() == 3:
			text = String(_texts.get("screen_x2", "x2"))
	_screen_label.text = text
	_fx.queue_redraw()


## Animacion del arte final que toca ahora (ART_ANIMS).
func get_art_anim() -> String:
	if _off:
		return "defeat"
	if not is_fighting():
		return "idle"
	if is_paused():
		return "paused"
	if is_countdown_showing():
		return "countdown"
	if get_phase() == 3:
		return "x2"
	if _clip in [CLIP_WAVE, CLIP_RAYS, CLIP_SWEEP_HIGH, CLIP_COUNTDOWN]:
		return "clip_cast"
	return "idle"


func _art_file(anim: String, frame: int) -> String:
	return "autoplay_%s_%02d.png" % [anim, frame]


## Cuadro del arte final: cambia de animacion si toca (empieza en el cuadro 0) y
## avanza con el tiempo del mundo que acumula advance.
func _art_texture() -> Texture2D:
	var anim: String = get_art_anim()
	if anim != _art_anim:
		_art_anim = anim
		_art_t = 0.0
	var spec: Array = ART_ANIMS[anim]
	var count: int = int(spec[0])
	var frame: int = int(floor(_art_t * float(spec[1])))
	frame = posmod(frame, count) if bool(spec[2]) else mini(frame, count - 1)
	var tex: Texture2D = _texture(_art_file(anim, frame))
	return tex if tex != null else _texture(_art_file("idle", 0))


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


func _on_marked(_duration_s: float, refreshed: bool) -> void:
	if get_phase() == 2 and is_window_open():
		_countdown_stopped = true
	if not refreshed:
		_pause_impacts = 0
		pause_changed.emit(true)
	_refresh_screen()


## Impactos de laser que da cada pausa (laps.<n>.pause_hits; 0 = sin tope, hasta
## que caduque). Cada impacto cuenta su dano (2 con el Laser 4).
func get_pause_hits() -> int:
	return maxi(int(lap_value("pause_hits", 0)), 0)


## Tandas de rayos por clip en la fase actual (laps.<n>.ray_volleys por fase;
## 1 por defecto; Raiz, fase 3: 2, §5.8).
func get_ray_volleys() -> int:
	var list: Variant = lap_value("ray_volleys", [])
	var p: int = get_phase() - 1
	if list is Array and p >= 0 and p < (list as Array).size():
		return maxi(int((list as Array)[p]), 1)
	return 1


## Impactos que lleva la pausa en curso (0 sin pausa).
func get_pause_impacts() -> int:
	return _pause_impacts if is_paused() else 0


## Golpe en pausa (BossBase lo cuenta): al llegar a pause_hits impactos la pausa
## se acaba ya (el video sigue: la ventana se cierra o el clip continua), como si
## hubiera caducado. Duracion de la pelea: §8.1, pasos 19-20 y ajuste de duracion.
func _on_weak_point_hit(damage: int, source: Node) -> void:
	var was_paused: bool = is_paused()
	super._on_weak_point_hit(damage, source)
	if not was_paused or not is_paused() or not is_fighting():
		return
	_pause_impacts += 1
	var cap: int = get_pause_hits()
	if cap > 0 and _pause_impacts >= cap:
		_core.clear_mark()
		_on_pause_expired()


## La pausa caduca: si habia ventana se cierra (clip siguiente); si no, el clip sigue.
func _on_pause_expired() -> void:
	pause_changed.emit(false)
	if is_fighting() and is_window_open():
		close_window()
	_refresh_screen()


func _lap_entry() -> Dictionary:
	var lap: int = lap_override if lap_override > 0 else GameState.lap
	var laps: Dictionary = get_config().get("laps", {})
	return laps.get(str(lap), laps.get("1", {}))


func _apply_lap_settings() -> void:
	apply_charger_cooldown(float(lap_value("charger_cooldown_s", -1.0)))


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


## Miniatura del clip en la pantalla (arte provisional por codigo): ola, rayos,
## barrido o la cifra de la cuenta; en pausa, el fotograma congelado.
class ScreenFx extends Node2D:
	var boss: Autoplay

	func _draw() -> void:
		if boss == null or not boss.is_fighting() or boss.is_screen_off():
			return
		var cfg: Dictionary = boss.get_config().get("arena", {})
		var thumb := Color.html(String(cfg.get("thumb_color", "#ff5cfa")))
		var warn := Color.html(String(cfg.get("warn_color", "#ff4a2a")))
		var r: Rect2 = boss.get_screen_rect()
		var box := Rect2(r.position + Vector2(r.size.x * 0.5 + 24.0, r.size.y - 96.0), Vector2(r.size.x * 0.5 - 48.0, 56.0))
		match boss.get_clip():
			Autoplay.CLIP_WAVE:
				var pts := PackedVector2Array()
				for i: int in 17:
					var f: float = float(i) / 16.0
					pts.append(box.position + Vector2(f * box.size.x, box.size.y * (0.5 + 0.35 * sin(f * TAU * 1.5))))
				draw_polyline(pts, thumb, 4.0)
			Autoplay.CLIP_RAYS:
				for i: int in 3:
					draw_rect(Rect2(box.position + Vector2(box.size.x * (0.2 + 0.3 * float(i)), 0.0), Vector2(8.0, box.size.y)), thumb)
			Autoplay.CLIP_SWEEP_HIGH:
				draw_rect(Rect2(box.position + Vector2(0.0, box.size.y * 0.4), Vector2(box.size.x, 10.0)), thumb)
			Autoplay.CLIP_COUNTDOWN:
				draw_rect(Rect2(box.position, box.size), Color(warn, 0.35))
		if boss.is_paused():
			draw_rect(Rect2(r.position + Vector2(12.0, 12.0), r.size - Vector2(24.0, 24.0)), Color(0.0, 0.0, 0.0, 0.25))


## Marca de la ayuda «Siguiente video en N» (autoplay_countdown): un punto sobre
## el texto de la pantalla que solo ayuda mientras la cuenta se ve.
## `available` dice si se ve (Autoplay.is_countdown_showing; las pruebas ponen otra).
class CountdownHelp extends Node2D:
	var available: Callable

	func is_help_available() -> bool:
		return available.is_valid() and bool(available.call())
