## El Visto, jefe del Mundo 4 «El Chat» (docs/propuesta-mundo-4.md §5; pasos
## 15-16 de §8, 2026-10-28). Un BossBase con tres fases; datos en
## data/bosses/seen.json (arena, ghost_dash, falling_bubbles, seen_zones,
## seen_sweep, phase1-3, laps, texts). Arena data/levels/4-boss.json «Chat
## vacio» (20 x 11, camara fija).
##
## - Cuerpo: doble check gigante de 6 x 3 tiles con aura fantasmal (no solido).
##   El punto debil (WeakPoint, el check gris «sin leer») solo esta activo en las
##   VENTANAS y cada ventana da un golpe: Debug (revela) -> pulso con el Debug
##   ACTIVO (marca laps.<n>.mark_duration_s) -> laser (un golpe, sin Debug;
##   laps.<n>.mark_hits = 1: la marca termina) -> la ventana se cierra. Nada mas
##   hace dano.
## - Fase 1 «Ghosting»: se esfuma y reaparece behind_tiles detras de Isak a su
##   altura (con el Debug se ve el rastro); la reaparicion ES la ventana
##   (phase1.window_s) y despues embiste. Entre medias, burbujas que caen y zonas
##   «Visto» en el suelo (congelan; un pulso las apaga). Raíz: delante una de cada
##   front_every; Kernel: una silueta falsa (decoys) sin punto debil.
## - Fase 2 «Grupo»: escudo de shield_layers capas; invoca tandas de Stickers por
##   el suelo y los Trolls de la arena (objetos con active_in_phase [2]) disparan
##   desde las burbujas fijas. El escudo solo cede a un PULSO que lo alcanza (desde
##   el borde interior de una burbuja fija; desde el suelo no llega) con la arena
##   limpia (sin Stickers vivos que ese mismo pulso no desinfle); una capa por
##   pulso (Kernel: dos). Con la ultima capa, cae al suelo phase2.window_s
##   (ventana). Agitar se retiro el 2026-10-28 (prueba del usuario). Una zona
##   «Visto» barre una burbuja fija cada seen_sweep.interval_s.
## - Fase 3 «Escribiendo…»: la burbuja «escribiendo…» gigante se llena de puntos
##   (uno cada laps.<n>.dot_interval_s); un pulso que la alcanza antes del ultimo
##   la deja en silencio y El Visto queda aturdido phase3.window_s a la altura de
##   las burbujas fijas (ventana, del lado de Isak). Si llega el ultimo punto, el
##   mensaje congela a Isak message_freeze_s (se espera; nada ataca). Dos Fantasmas
##   pequenos reaparecen por la espalda (vuelven si se derrotan).
## - Isak congelado (por cualquier causa): El Visto no ataca y sus esbirros se
##   quedan quietos («te esta mirando»).
## - Llegada, intro, reaparicion por fase (energia >= 50), golpe final y secuencia
##   de derrota como la Curadora (BossBase, BossDefeat). Sin rollback.
## Arte final del doble check con AutoSprite (paso 24, etapa 2, 2026-10-28;
## tools/import_boss_seen.py, seen_<anim>_NN.png y seen_small_<anim>_NN.png,
## ART_ANIMS; docs/plan-arte-mundo-4.md): cuerpo y silueta de la fase 1. Si
## faltan los cuadros vuelve al PROVISIONAL por codigo (el doble check en una
## ImageTexture hecha aqui). Aura, escudo, rastro, burbujas, zonas,
## «escribiendo…» y mensaje siguen por codigo (SeenFx). Tiempo del mundo
## (advance; las pruebas lo llaman a mano con auto_process falso).
class_name Seen
extends BossBase

## Empieza un ataque (ghost_dash, falling_bubbles, seen_zones, seen_sweep,
## typing, message) o la ventana (window).
signal attack_started(attack: StringName)
## Reaparece en `at` (pies, global) tras esfumarse (fase 1).
signal reappeared(at: Vector2)
## Un pulso alcanzo el escudo con la arena limpia; quedan `layers_left` capas.
signal shield_hit(layers_left: int)
## Un pulso alcanzo el escudo con Stickers vivos: no cede (rebota).
signal shield_blocked
## El escudo estalla y El Visto cae al suelo (ventana).
signal shield_broken
## Un pulso dejo en silencio el «escribiendo…» (fase 3).
signal typing_interrupted
## El ultimo punto: el mensaje sale (`frozen`: congelo a Isak).
signal message_sent(frozen: bool)
## Sale un punto del «escribiendo…» gigante (`dots`: los que hay ya; paso 20:
## sfx_boss4_typing, senal de ritmo).
signal dot_added(dots: int)
## Golpe final (contador a 0).
signal final_blow
signal disarmed

const WEAK_POINT_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const STICKER_SCENE: PackedScene = preload("res://scenes/enemies/sticker.tscn")
const GHOST_SCENE: PackedScene = preload("res://scenes/enemies/ghost.tscn")

const ATTACK_GHOST_DASH: StringName = &"ghost_dash"
const ATTACK_FALLING_BUBBLES: StringName = &"falling_bubbles"
const ATTACK_SEEN_ZONES: StringName = &"seen_zones"
const ATTACK_SEEN_SWEEP: StringName = &"seen_sweep"
const ATTACK_TYPING: StringName = &"typing"
const ATTACK_MESSAGE: StringName = &"message"
const ATTACK_WINDOW: StringName = &"window"
const ATTACK_GAP: StringName = &"gap"

## Etapas de «se esfuma y embiste» (fase 1).
const DASH_NONE: StringName = &"none"
const DASH_VANISH: StringName = &"vanish"
const DASH_HIDDEN: StringName = &"hidden"
const DASH_WARN: StringName = &"warn"
const DASH_READY: StringName = &"ready"
const DASH_CHARGE: StringName = &"charge"
const DASH_RETURN: StringName = &"return"

## Estados del «escribiendo…» gigante (fase 3).
const TYPING_IDLE: StringName = &"idle"
const TYPING_ON: StringName = &"typing"
const TYPING_SILENT: StringName = &"silent"
const TYPING_SENT: StringName = &"sent"

## Estados de una zona «Visto» del jefe.
const ZONE_WARN: StringName = &"warn"
const ZONE_ACTIVE: StringName = &"active"
const ZONE_OFF: StringName = &"off"

## Ayudas de Eco con Q (paso 20 de docs/propuesta-mundo-4.md, §5.10; data/help.json):
## por defecto de help_id (la seccion help de data/bosses/seen.json manda).
const HELP_BOSS: StringName = &"seen_boss"
const HELP_SHIELD: StringName = &"seen_shield"
const HELP_TYPING: StringName = &"seen_typing"

## Arte final (tools/import_boss_seen.py): anim -> [cuadros, fps, bucle]. Las
## que no van en bucle siguen el progreso de su estado (vanish: vanish_s;
## reappear: return_s en el cuerpo y el aviso en la silueta) o, defeat, 12 fps
## desde el golpe final (se queda en el ultimo). Cuerpo: idle por defecto;
## fase 1 vanish / reappear (oculto entre medias); fase 2 shield con el escudo
## levantado y stunned en el suelo; fase 3 typing mientras se llenan los
## puntos y stunned aturdido; defeat desde el golpe final. Silueta (fase 1):
## reappear en el aviso (y su ultimo cuadro en la ventana), charge al embestir
## (reflejada hacia la izquierda).
const ART_ANIMS: Dictionary = {
	"idle": [24, 12.0, true],
	"vanish": [23, 12.0, false],
	"reappear": [25, 12.0, false],
	"charge": [8, 16.0, true],
	"shield": [24, 12.0, true],
	"typing": [24, 12.0, true],
	"stunned": [24, 12.0, true],
	"defeat": [25, 12.0, false],
}
const ART_SMALL: Array[String] = ["reappear", "charge"]
## Cuadro de defeat con el que se queda al golpe final (ya agrietado); el
## desarme en pixeles toma el ultimo (gris y roto).
const ART_DEFEAT_FROM: int = 8
## El lienzo del cuerpo (336 x 256) va ART_BODY_OFFSET de la esquina de la caja
## (arena.body): el check gris cae en ART_CHECK_PX de la caja (perch_core_px
## centrado, 2 px a la izquierda por la rejilla de 4). El de la silueta (112 x 86),
## ART_SILHOUETTE_OFFSET del punto debil (su check gris, encima). Los fija
## tools/import_boss_seen.py (BODY_OFFSET_PX, SILHOUETTE_OFFSET_PX).
const ART_BODY_OFFSET: Vector2 = Vector2(24.0, -48.0)
const ART_CHECK_PX: Vector2 = Vector2(190.0, 160.0)
const ART_SILHOUETTE_OFFSET: Vector2 = Vector2(-56.0, -70.0)
const ART_DIR: String = "res://assets/sprites/bosses/"

const SIDE_LEFT: String = "left"
const SIDE_RIGHT: String = "right"
const ARENA_COLS: int = 20
const ARENA_ROWS: int = 11

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
var _body_sprite: Sprite2D
var _body_tex: Texture2D
var _sil_sprite: Sprite2D
var _decoy_sprite: Sprite2D
var _textures: Dictionary = {}
var _art_on: bool = false
var _art_key: String = ""
var _art_since: float = 0.0
var _fx: SeenFx
var _burst: PixelBurst
var _off: bool = false
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
# Linea de tiempo de los ataques.
var _attack: StringName = &""
var _attack_t: float = 0.0
var _attack_index: int = 0
var _gap_left: float = 0.0
# Fase 1: se esfuma y embiste.
var _dash: StringName = DASH_NONE
var _dash_t: float = 0.0
var _dash_count: int = 0
var _vanish_from: Vector2 = Vector2.ZERO
var _appear_at: Vector2 = Vector2.ZERO
var _decoy_at: Vector2 = Vector2.INF
var _charge_dir: float = 1.0
var _charge_x: float = 0.0
var _charge_hit: bool = false
var _window_hit: bool = false
# Fase 1: burbujas que caen y zonas «Visto» (rectangulos globales).
var _bubble_cols: Array[int] = []
var _bubble_hit: Array[bool] = []
var _zones: Array[Rect2] = []
var _zone_off: Array[bool] = []
# Fase 2: escudo, Stickers y barrido de una burbuja fija.
var _shield_up: bool = false
var _shield_layers_left: int = 0
var _drop: float = 0.0
var _sticker_wait: float = 0.0
var _stickers: Array[Sticker] = []
var _sweep_wait: float = 0.0
var _sweep_t: float = -1.0
var _sweep_side: String = SIDE_LEFT
var _sweep_count: int = 0
# Fase 3: «escribiendo…», mensaje y Fantasmas.
var _typing: StringName = TYPING_IDLE
var _typing_t: float = 0.0
var _typing_wait: float = 0.0
var _dots: int = 0
var _message_t: float = -1.0
var _stun_side: String = SIDE_LEFT
var _lower: float = 0.0
var _ghosts: Array[Ghost] = []
var _ghost_wait: Array[float] = []
# Esbirros quietos mientras Isak esta congelado.
var _paused_minions: Array[Node] = []
# Ayudas Q del cuerpo, del escudo y del «escribiendo…», y musica de la pelea (paso 20).
var _body_help: HelpMarker
var _shield_help: HelpMarker
var _typing_help: HelpMarker
var _music: SeenMusic


func _ready() -> void:
	if boss_id.is_empty():
		boss_id = &"seen"
	super._ready()
	var cfg: Dictionary = get_config()
	_arena = cfg.get("arena", {})
	_texts = cfg.get("texts", {})
	_tile = float(World4ObjectsConfig.tile_size())
	_lap = _lap_entry()
	_build()
	# Despues de _build: el WeakPoint (hijo) recibe el pulso antes que el jefe, asi
	# el pulso que deja en silencio el «escribiendo…» no marca a la vez.
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_apply_lap_settings.call_deferred()


func _physics_process(delta: float) -> void:
	if _intro_state == 0 and intro_on_arrival and not is_fighting() and not is_defeated():
		_poll_arrival()
	super._physics_process(delta)


func advance(dt: float) -> void:
	_time += dt
	_art_since += dt
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
	return _attack if _attack != &"" else ATTACK_NONE


## Valor de la vuelta actual (laps.<n>.<key>).
func lap_value(key: String, fallback: Variant) -> Variant:
	return _lap.get(key, fallback)


## Datos de una seccion (phase1-3, ghost_dash, falling_bubbles…).
func section(key: String) -> Dictionary:
	return get_config().get(key, {})


func phase_data(phase_index: int) -> Dictionary:
	return section("phase%d" % phase_index)


## Aviso de `frames` cuadros a anim_fps (s del mundo).
func frames_s(frames: Variant) -> float:
	return float(frames) / maxf(float(_arena.get("anim_fps", 12.0)), 1.0)


## Rectangulo global del cuerpo en reposo (arriba, sin caer ni bajar).
func get_perch_rect() -> Rect2:
	return _cells_rect(_arena.get("body", [7, 1, 6, 3]))


## Rectangulo global del cuerpo ahora (cae al suelo en la fase 2, baja aturdido en la 3).
func get_body_rect() -> Rect2:
	var rect: Rect2 = get_perch_rect()
	var floor_y: float = _to_global(Vector2(0.0, float(int(_arena.get("floor_row", 9)) + 1) * _tile)).y
	var fall: float = (floor_y - rect.end.y) * _drop
	var low: float = float(_arena.get("lowered_rows", 2)) * _tile * _lower
	return Rect2(rect.position + Vector2(0.0, fall + low), rect.size)


## Rectangulo global del escudo (el cuerpo en reposo con su margen).
func get_shield_rect() -> Rect2:
	return get_perch_rect().grow(float(_arena.get("shield_margin_px", 24.0)))


func is_shield_up() -> bool:
	return is_fighting() and get_phase() == 2 and _shield_up and not is_window_open()


func get_shield_layers_left() -> int:
	return _shield_layers_left if is_shield_up() else 0


## Etapa de «se esfuma y embiste» (DASH_*).
func get_dash_stage() -> StringName:
	return _dash if is_fighting() and get_phase() == 1 else DASH_NONE


## Pies (global) donde reaparece (o reaparecera) en la fase 1.
func get_appear_point() -> Vector2:
	return _appear_at


## Pies de la silueta falsa (Kernel); Vector2.INF sin ella.
func get_decoy_point() -> Vector2:
	if get_dash_stage() in [DASH_WARN, DASH_READY]:
		return _decoy_at
	return Vector2.INF


## Donde se esfumo (origen del rastro).
func get_vanish_point() -> Vector2:
	return _vanish_from


## Rectangulo global de la silueta real (fase 1; Rect2() si no se ve).
func get_silhouette_rect() -> Rect2:
	if get_dash_stage() not in [DASH_WARN, DASH_READY, DASH_CHARGE]:
		return Rect2()
	return _silhouette_at(Vector2(_charge_x if _dash == DASH_CHARGE else _appear_at.x, _appear_at.y))


## Se ve el rastro (Debug revelando mientras esta oculto o avisando).
func is_trail_visible() -> bool:
	return DebugMode.is_revealing() and get_dash_stage() in [DASH_HIDDEN, DASH_WARN]


## Columnas de las burbujas que caen (y su rectangulo ahora; Rect2() en el aviso).
func get_falling_columns() -> Array[int]:
	return _bubble_cols.duplicate() if _attack == ATTACK_FALLING_BUBBLES else []


func is_bubble_falling() -> bool:
	if _attack != ATTACK_FALLING_BUBBLES:
		return false
	return _attack_t >= frames_s(section("falling_bubbles").get("warn_frames", 9)) - 0.0001


## Rectangulo global de la burbuja que cae en la columna `col` ahora.
func get_falling_rect(col: int) -> Rect2:
	var fb: Dictionary = section("falling_bubbles")
	var warn: float = frames_s(fb.get("warn_frames", 9))
	var f: float = clampf((_attack_t - warn) / maxf(float(fb.get("fall_s", 0.5)), 0.001), 0.0, 1.0)
	var floor_row: int = int(_arena.get("floor_row", 9))
	var row: float = lerpf(1.0, float(floor_row), f)
	var w: int = maxi(int(fb.get("width_tiles", 1)), 1)
	var pos: Vector2 = _to_global(Vector2(float(col) * _tile, row * _tile))
	return Rect2(pos, Vector2(float(w) * _tile, _tile))


## Zonas «Visto» del jefe ahora (fase 1: suelo; fase 2: el barrido de una burbuja).
func get_zone_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _attack == ATTACK_SEEN_ZONES:
		for i: int in _zones.size():
			if not _zone_off[i]:
				out.append(_zones[i])
	if get_phase() == 2 and _sweep_t >= 0.0:
		out.append(get_sweep_rect())
	return out


## Estado de las zonas «Visto» (ZONE_*).
func get_zone_state() -> StringName:
	if _attack == ATTACK_SEEN_ZONES:
		return ZONE_ACTIVE if _attack_t >= frames_s(section("seen_zones").get("warn_frames", 9)) - 0.0001 else ZONE_WARN
	if get_phase() == 2 and _sweep_t >= 0.0:
		return ZONE_ACTIVE if _sweep_t >= frames_s(section("seen_sweep").get("warn_frames", 9)) - 0.0001 else ZONE_WARN
	return ZONE_OFF


## Zona del barrido de la fase 2: la fila de encima de la burbuja fija `_sweep_side`.
func get_sweep_rect() -> Rect2:
	var b: Array = (_arena.get("fixed_bubbles", {}) as Dictionary).get(_sweep_side, [3, 6, 4])
	return _cells_rect([int(b[0]), int(b[1]) - 1, int(b[2]), 1])


func get_sweep_side() -> String:
	return _sweep_side


## Stickers vivos que ha invocado (sin los derrotados ni los que ya explotaron:
## el confeti no cuenta para el escudo ni para el tope de la tanda; paso 19).
func get_stickers() -> Array[Sticker]:
	var out: Array[Sticker] = []
	for s: Sticker in _stickers:
		if is_instance_valid(s) and not s.is_defeated() and not s.is_exploded():
			out.append(s)
	return out


## Fantasmas pequenos de la fase 3 que siguen en pie.
func get_ghosts() -> Array[Ghost]:
	var out: Array[Ghost] = []
	for g: Ghost in _ghosts:
		if is_instance_valid(g) and not g.is_defeated():
			out.append(g)
	return out


## Rectangulo global del «escribiendo…» gigante bajado.
func get_typing_rect() -> Rect2:
	return _cells_rect(_arena.get("typing_rect", [7, 6, 6, 2]))


func get_typing_state() -> StringName:
	return _typing if is_fighting() and get_phase() == 3 else TYPING_IDLE


func get_dots() -> int:
	return _dots if get_typing_state() in [TYPING_ON, TYPING_SENT] else 0


func get_dots_total() -> int:
	return maxi(int(phase_data(3).get("dots", 3)), 1)


## Segundos del mundo que faltan para el siguiente punto (0 sin escribir).
func get_next_dot_left() -> float:
	if get_typing_state() != TYPING_ON:
		return 0.0
	return maxf(float(lap_value("dot_interval_s", 1.5)) - _typing_t, 0.0)


## El mensaje gigante esta cruzando la arena.
func is_message_crossing() -> bool:
	return get_phase() == 3 and _message_t >= 0.0 \
		and _message_t < float(phase_data(3).get("message_cross_s", 0.6))


func get_message_t() -> float:
	return _message_t


## Lado del aturdimiento de la fase 3 (el de Isak al interrumpir).
func get_stun_side() -> String:
	return _stun_side


func get_lowered() -> float:
	return _lower


func get_drop() -> float:
	return _drop


func is_screen_off() -> bool:
	return _off


## El cuerpo se ve con el arte final (cuadros de tools/import_boss_seen.py).
func has_final_art() -> bool:
	return _art_on


## [animacion, cuadro] del arte final del cuerpo que toca ahora (ART_ANIMS);
## ["", -1] si el cuerpo no se ve (fase 1, oculto).
func get_art_frame() -> Array:
	var key: String = "idle"
	var gd: Dictionary = section("ghost_dash")
	var stage: StringName = get_dash_stage()
	if _off:
		key = "defeat"
	elif stage == DASH_VANISH:
		return ["vanish", _art_progress("vanish", _dash_t / maxf(float(gd.get("vanish_s", 0.5)), 0.01))]
	elif stage in [DASH_HIDDEN, DASH_WARN, DASH_READY, DASH_CHARGE]:
		return ["", -1]
	elif stage == DASH_RETURN:
		return ["reappear", _art_progress("reappear", _dash_t / maxf(float(gd.get("return_s", 0.6)), 0.01))]
	elif is_fighting() and get_phase() == 2:
		if is_window_open() or _drop > 0.0:
			key = "stunned"
		elif is_shield_up():
			key = "shield"
	elif is_fighting() and get_phase() == 3:
		if is_window_open() or _lower > 0.0:
			key = "stunned"
		elif get_typing_state() == TYPING_ON:
			key = "typing"
	if key != _art_key:
		_art_key = key
		_art_since = 0.0
	var spec: Array = ART_ANIMS[key]
	if key == "defeat":
		# Empieza ya agrietado (ART_DEFEAT_FROM): la congelacion del golpe final
		# pausa el arbol y el desarme llega enseguida.
		return [key, clampi(ART_DEFEAT_FROM + floori(_art_since * float(spec[1])), 0, int(spec[0]) - 1)]
	return [key, posmod(floori(_time * float(spec[1])), int(spec[0]))]


## [animacion, cuadro] de la silueta de la fase 1 (["", -1] si no se ve).
func get_silhouette_art_frame() -> Array:
	match get_dash_stage():
		DASH_WARN:
			var warn: float = frames_s(section("ghost_dash").get("warn_frames", 9))
			return ["reappear", _art_progress("reappear", _dash_t / maxf(warn, 0.01))]
		DASH_READY:
			return ["reappear", int(ART_ANIMS["reappear"][0]) - 1]
		DASH_CHARGE:
			var spec: Array = ART_ANIMS["charge"]
			return ["charge", posmod(floori(_dash_t * float(spec[1])), int(spec[0]))]
	return ["", -1]


## Esquina de arriba a la izquierda del lienzo del cuerpo (global). En las
## ventanas de las fases 2 y 3 el dibujo se desliza (con la caida o la bajada)
## hasta que su check gris cae en el punto debil; la caja no cambia.
func get_art_position() -> Vector2:
	var base: Vector2 = get_body_rect().position
	var k: float = 0.0
	if is_fighting() and get_phase() == 2:
		k = _drop
	elif is_fighting() and get_phase() == 3:
		k = _lower
	var shift := Vector2.ZERO
	if k > 0.0:
		shift = (get_window_core_point(get_phase()) - (base + ART_CHECK_PX)) * k
	return (base + ART_BODY_OFFSET + shift).round()


## Rectangulo global del dibujo del cuerpo (lienzo del arte final o la caja).
func get_art_rect() -> Rect2:
	if _art_on and _body_sprite != null and _body_sprite.texture != null:
		return Rect2(_body_sprite.global_position, _body_sprite.texture.get_size())
	return get_body_rect()


func get_attacks_root() -> Node2D:
	return _attacks


func get_time() -> float:
	return _time


## Lado de la arena en el que esta `x` (global).
func side_of_x(x: float) -> String:
	return SIDE_LEFT if x < get_perch_rect().get_center().x else SIDE_RIGHT


## Punto debil en la ventana de la fase `phase_index` (global).
func get_window_core_point(phase_index: int) -> Vector2:
	match phase_index:
		1:
			return _appear_at + Vector2(0.0, -float(_arena.get("phone_dy_px", 58.0)))
		2:
			var f: Array = _arena.get("floor_core_px", [640, 582])
			return _to_global(Vector2(float(f[0]), float(f[1])))
		_:
			var at: Array = (_arena.get("stunned_core_px", {}) as Dictionary).get(_stun_side, [512, 326])
			return _to_global(Vector2(float(at[0]), float(at[1])))


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
	_core.set_enabled(false)
	_rng.seed = 4028 + phase_index
	var p: Dictionary = phase_data(phase_index)
	_attack_index = 0
	_attack = ATTACK_GAP
	_gap_left = float(p.get("first_delay_s", 1.0))
	_dash = DASH_NONE
	_dash_count = 0
	_drop = 0.0
	_lower = 0.0
	_shield_up = phase_index == 2
	_shield_layers_left = maxi(int(lap_value("shield_layers", 1)), 1) if phase_index == 2 else 0
	_sticker_wait = float(p.get("first_delay_s", 1.0))
	var sweep: Dictionary = section("seen_sweep")
	_sweep_wait = float(p.get("first_delay_s", 1.0)) + float(sweep.get("interval_s", 7.0)) * 0.5
	_sweep_t = -1.0
	_sweep_side = SIDE_LEFT
	_sweep_count = 0
	_typing = TYPING_IDLE
	_typing_wait = float(p.get("first_delay_s", 1.0))
	_typing_t = 0.0
	_dots = 0
	_message_t = -1.0
	if phase_index == 3:
		_spawn_ghosts()
	if phase_index > 1:
		var line: String = String((_texts.get("phase_lines", {}) as Dictionary).get(str(phase_index), ""))
		if not line.is_empty():
			# Fase 2 arriba (2026-10-28): abajo tapaba el check gris del suelo en la ventana.
			say_line(line, false, Callable(), &"phase", phase_index == 2)
	_refresh()


func _on_phase_restarted(phase_index: int) -> void:
	for charger: Charger in _chargers():
		charger.make_ready()
	_on_phase_started(phase_index)


func _on_advance(dt: float) -> void:
	var isak: Isak = find_isak()
	var frozen: bool = isak != null and isak.is_frozen()
	_set_minions_paused(frozen)
	if _message_t >= 0.0:
		_message_t += dt
	match get_phase():
		1:
			if not frozen:
				_advance_phase1(dt)
		2:
			_advance_phase2(dt, frozen)
		3:
			_advance_phase3(dt, frozen)
	if is_fighting() and not frozen:
		_check_hazards()
	_refresh()


func _on_window_opened(_duration_s: float) -> void:
	_window_hit = false
	_core.global_position = get_window_core_point(get_phase())
	_core.set_enabled(true)
	attack_started.emit(ATTACK_WINDOW)


func _on_window_closed() -> void:
	_core.set_enabled(false)
	match get_phase():
		1:
			if _dash == DASH_READY:
				if _window_hit:
					_begin_dash_stage(DASH_RETURN)
				else:
					_begin_charge()
		2:
			_shield_up = true
			_shield_layers_left = maxi(int(lap_value("shield_layers", 1)), 1)
		3:
			_typing = TYPING_IDLE
			_typing_wait = float(phase_data(3).get("typing_gap_s", 2.0))


## Un golpe por ventana: el golpe la cierra.
func _on_core_hit(_remaining_hits: int) -> void:
	_window_hit = true
	if is_window_open():
		close_window()


func _on_defeated() -> void:
	_stop_music()
	_clear_attacks()
	_attack = &""
	_core.set_enabled(false)
	_off = true
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


## Desarme en pixeles (BossDefeat): el doble check tachado se suelta.
func play_disarm() -> PixelBurst:
	var at: Vector2 = get_art_rect().get_center()
	var cfg: Dictionary = section("defeat").get("pixels", {})
	var last: Texture2D = _art_texture(["defeat", int(ART_ANIMS["defeat"][0]) - 1])
	var tex: Texture2D = last if _art_on and last != null else _body_tex
	_body_sprite.visible = false
	_core.set_enabled(false)
	var root: Node = _level_root()
	# Con el arte final, el desarme suelta el doble check gris y roto.
	_burst = PixelBurst.spawn(tex, at, 1.0, root if root != null else self, cfg)
	disarmed.emit()
	return _burst


func get_pixel_burst() -> PixelBurst:
	return _burst if _burst != null and is_instance_valid(_burst) else null


# --- Fase 1: se esfuma y embiste, burbujas que caen y zonas «Visto» ---

func _advance_phase1(dt: float) -> void:
	if _attack == ATTACK_GAP:
		_gap_left -= dt
		if _gap_left <= 0.0:
			_next_attack()
		return
	_attack_t += dt
	match _attack:
		ATTACK_GHOST_DASH:
			_advance_dash(dt)
		ATTACK_FALLING_BUBBLES:
			var fb: Dictionary = section("falling_bubbles")
			if _attack_t >= frames_s(fb.get("warn_frames", 9)) + float(fb.get("fall_s", 0.5)) - 0.0001:
				_end_attack()
		ATTACK_SEEN_ZONES:
			var sz: Dictionary = section("seen_zones")
			if _attack_t >= frames_s(sz.get("warn_frames", 9)) + float(sz.get("active_s", 3.0)) - 0.0001:
				_end_attack()
		_:
			_end_attack()


func _next_attack() -> void:
	var order: Array = phase_data(get_phase()).get("attacks", [ATTACK_GHOST_DASH])
	if order.is_empty():
		order = [ATTACK_GHOST_DASH]
	var kind := StringName(String(order[_attack_index % order.size()]))
	_attack_index += 1
	start_attack(kind)


## Empieza el ataque `kind` ya (pruebas y bot: tambien fuera de su turno).
func start_attack(kind: StringName) -> void:
	_attack = kind
	_attack_t = 0.0
	var isak: Isak = find_isak()
	var isak_col: int = _col_of(isak.global_position.x) if isak != null else 9
	match kind:
		ATTACK_GHOST_DASH:
			_vanish_from = get_perch_rect().get_center()
			_begin_dash_stage(DASH_VANISH)
		ATTACK_FALLING_BUBBLES:
			var fb: Dictionary = section("falling_bubbles")
			var spread: int = maxi(int(fb.get("spread_cols", 3)), 1)
			_bubble_cols.clear()
			_bubble_hit.clear()
			var candidates: Array[int] = [isak_col, isak_col - spread, isak_col + spread, isak_col - 2 * spread, isak_col + 2 * spread]
			for c: int in candidates:
				var col: int = clampi(c, 1, ARENA_COLS - 2)
				if not _bubble_cols.has(col) and _bubble_cols.size() < int(fb.get("count", 3)):
					_bubble_cols.append(col)
					_bubble_hit.append(false)
		ATTACK_SEEN_ZONES:
			var sz: Dictionary = section("seen_zones")
			var w: int = maxi(int(sz.get("width_tiles", 2)), 1)
			var floor_row: int = int(_arena.get("floor_row", 9))
			_zones.clear()
			_zone_off.clear()
			var top: int = ARENA_COLS - 1 - w
			var first: int = clampi(isak_col - (w - 1) / 2, 1, top)
			# La de Isak y su espejo; si se solapan, la segunda a w + 3 columnas.
			var cols: Array[int] = [first]
			for c: int in [ARENA_COLS - first - w, first + w + 3, first - w - 3]:
				if cols.size() >= int(sz.get("count", 2)):
					break
				if c >= 1 and c <= top and absi(c - first) > w:
					cols.append(c)
			for c: int in cols:
				_zones.append(_cells_rect([c, floor_row, w, 1]))
				_zone_off.append(false)
	attack_started.emit(kind)


func _end_attack() -> void:
	_attack = ATTACK_GAP
	_attack_t = 0.0
	_gap_left = float(phase_data(get_phase()).get("attack_gap_s", 1.5))
	_bubble_cols.clear()
	_bubble_hit.clear()
	_zones.clear()
	_zone_off.clear()
	_dash = DASH_NONE
	_decoy_at = Vector2.INF


func _begin_dash_stage(stage: StringName) -> void:
	_dash = stage
	_dash_t = 0.0
	if stage == DASH_WARN:
		_appear_at = compute_appear_point()
		_decoy_at = _compute_decoy_point()
		_dash_count += 1
		reappeared.emit(_appear_at)


func _advance_dash(dt: float) -> void:
	var gd: Dictionary = section("ghost_dash")
	_dash_t += dt
	match _dash:
		DASH_VANISH:
			if _dash_t >= float(gd.get("vanish_s", 0.5)) - 0.0001:
				_begin_dash_stage(DASH_HIDDEN)
		DASH_HIDDEN:
			_appear_at = compute_appear_point()
			if _dash_t >= float(gd.get("hidden_s", 1.0)) - 0.0001:
				_begin_dash_stage(DASH_WARN)
		DASH_WARN:
			if _dash_t >= frames_s(gd.get("warn_frames", 9)) - 0.0001:
				_dash = DASH_READY
				_dash_t = 0.0
				open_window(float(phase_data(1).get("window_s", 1.2)))
		DASH_READY:
			pass
		DASH_CHARGE:
			var speed: float = float(gd.get("charge_speed_px_s", 640.0))
			var length: float = float(gd.get("charge_tiles", 5.0)) * _tile
			var lo: float = _to_global(Vector2(_tile * 1.5, 0.0)).x
			var hi: float = _to_global(Vector2(_tile * (ARENA_COLS - 1.5), 0.0)).x
			_charge_x = clampf(_charge_x + _charge_dir * speed * dt, lo, hi)
			if absf(_charge_x - _appear_at.x) >= length - 0.5 or _charge_x <= lo or _charge_x >= hi \
					or _dash_t >= length / maxf(speed, 1.0) + 0.0001:
				_begin_dash_stage(DASH_RETURN)
		DASH_RETURN:
			if _dash_t >= float(gd.get("return_s", 0.6)) - 0.0001:
				_end_attack()


func _begin_charge() -> void:
	_dash = DASH_CHARGE
	_dash_t = 0.0
	_charge_x = _appear_at.x
	_charge_hit = false
	var isak: Isak = find_isak()
	var target_x: float = isak.global_position.x if isak != null else get_perch_rect().get_center().x
	_charge_dir = 1.0 if target_x >= _appear_at.x else -1.0
	_decoy_at = Vector2.INF


## Pies (global) de la reaparicion para el Isak de ahora: behind_tiles detras de
## donde mira (Raíz: delante una de cada front_every), a la altura de sus pies;
## si cae fuera de la arena, al otro lado. Sin Isak, en el centro del suelo.
func compute_appear_point() -> Vector2:
	var isak: Isak = find_isak()
	var floor_y: float = _to_global(Vector2(0.0, float(int(_arena.get("floor_row", 9)) + 1) * _tile)).y
	if isak == null:
		return Vector2(get_perch_rect().get_center().x, floor_y)
	var face: float = signf(isak.facing) if not is_zero_approx(isak.facing) else 1.0
	var every: int = int(lap_value("front_every", 0))
	# Numero de esta reaparicion (_dash_count sube al fijarla, en DASH_WARN).
	var count: int = _dash_count + 1
	var side: float = -face
	if every > 0 and count > 0 and count % every == 0:
		side = face
	var off: float = float(section("ghost_dash").get("behind_tiles", 2.0)) * _tile
	var feet: Vector2 = isak.global_position
	var at := Vector2(feet.x + side * off, feet.y)
	if not _inside_arena_x(at.x):
		at.x = feet.x - side * off
	return at


func _compute_decoy_point() -> Vector2:
	if int(lap_value("decoys", 0)) <= 0:
		return Vector2.INF
	var isak: Isak = find_isak()
	if isak == null:
		return Vector2.INF
	var other := Vector2(2.0 * isak.global_position.x - _appear_at.x, _appear_at.y)
	return other if _inside_arena_x(other.x) else Vector2.INF


func _inside_arena_x(x: float) -> bool:
	var half: float = float((_arena.get("silhouette_px", [96.0, 96.0]) as Array)[0]) * 0.5
	var lo: float = _to_global(Vector2(_tile, 0.0)).x + half
	var hi: float = _to_global(Vector2(_tile * (ARENA_COLS - 1), 0.0)).x - half
	return x >= lo and x <= hi


func _silhouette_at(feet: Vector2) -> Rect2:
	var size: Array = _arena.get("silhouette_px", [96.0, 96.0])
	var s := Vector2(float(size[0]), float(size[1]))
	var center: Vector2 = feet + Vector2(0.0, -float(_arena.get("phone_dy_px", 58.0)))
	return Rect2(center - s * 0.5, s)


# --- Fase 2: escudo, Stickers y barrido ---

func _advance_phase2(dt: float, frozen: bool) -> void:
	var fall_s: float = maxf(float(_arena.get("fall_s", 0.4)), 0.01)
	var rise_s: float = maxf(float(_arena.get("rise_s", 0.5)), 0.01)
	if is_window_open():
		_drop = move_toward(_drop, 1.0, dt / fall_s)
	else:
		_drop = move_toward(_drop, 0.0, dt / rise_s)
	if frozen:
		return
	var p: Dictionary = phase_data(2)
	if not is_window_open():
		_sticker_wait -= dt
		if _sticker_wait <= 0.0:
			_sticker_wait = float(p.get("sticker_interval_s", 6.0))
			_spawn_stickers()
	var sweep: Dictionary = section("seen_sweep")
	if _sweep_t >= 0.0:
		_sweep_t += dt
		if _sweep_t >= frames_s(sweep.get("warn_frames", 9)) + float(sweep.get("active_s", 2.0)) - 0.0001:
			_sweep_t = -1.0
			_sweep_side = SIDE_RIGHT if _sweep_side == SIDE_LEFT else SIDE_LEFT
			_sweep_wait = float(sweep.get("interval_s", 7.0))
	elif not is_window_open():
		_sweep_wait -= dt
		if _sweep_wait <= 0.0:
			var isak: Isak = find_isak()
			# La primera vez, la burbuja del lado de Isak; despues alternando.
			if _sweep_count == 0 and isak != null:
				_sweep_side = side_of_x(isak.global_position.x)
			_sweep_count += 1
			_sweep_t = 0.0
			attack_started.emit(ATTACK_SEEN_SWEEP)


func _spawn_stickers() -> void:
	var p: Dictionary = phase_data(2)
	var room: int = int(p.get("max_stickers", 3)) - get_stickers().size()
	var count: int = mini(int(p.get("stickers_per_batch", 3)), room)
	if count <= 0:
		return
	var cols: Array = _arena.get("sticker_cols", [4, 9, 15])
	var floor_row: int = int(_arena.get("floor_row", 9))
	var placed: int = 0
	for c: Variant in cols:
		if placed >= count:
			break
		var sticker := STICKER_SCENE.instantiate() as Sticker
		sticker.name = "SeenSticker%d" % _stickers.size()
		sticker.position = _attacks.to_local(_to_global(Vector2((float(c) + 0.5) * _tile, float(floor_row + 1) * _tile)))
		_attacks.add_child(sticker)
		_stickers.append(sticker)
		placed += 1
	attack_started.emit(&"stickers")


## Pulso al escudo (desde receive_pulse): con el escudo arriba y el pulso
## tocandolo, cede una capa si no quedan Stickers vivos que ese pulso no alcance
## (los que alcanza, el pulso los desinfla). Verdadero si rompio una capa.
func receive_shield_pulse(area: Area2D) -> bool:
	if not is_shield_up() or area == null or not PulseReceiver.pulse_reaches(area, get_shield_rect()):
		return false
	for s: Sticker in get_stickers():
		if not PulseReceiver.pulse_reaches(area, s.get_body_rect()):
			shield_blocked.emit()
			return false
	_shield_layers_left -= 1
	shield_hit.emit(_shield_layers_left)
	if _shield_layers_left <= 0:
		_shield_up = false
		shield_broken.emit()
		open_window(float(phase_data(2).get("window_s", 4.0)))
	return true


# --- Fase 3: «escribiendo…», mensaje y Fantasmas ---

func _advance_phase3(dt: float, frozen: bool) -> void:
	var lower_s: float = maxf(float(_arena.get("lower_s", 0.4)), 0.01)
	_lower = move_toward(_lower, 1.0 if is_window_open() else 0.0, dt / lower_s)
	if frozen:
		return
	_step_ghost_respawn(dt)
	match _typing:
		TYPING_IDLE:
			if not is_window_open():
				_typing_wait -= dt
				if _typing_wait <= 0.0:
					_typing = TYPING_ON
					_typing_t = 0.0
					_dots = 0
					_attack = ATTACK_TYPING
					attack_started.emit(ATTACK_TYPING)
		TYPING_ON:
			_typing_t += dt
			var every: float = maxf(float(lap_value("dot_interval_s", 1.5)), 0.05)
			if _typing_t >= every - 0.0001:
				_typing_t = 0.0
				_dots += 1
				dot_added.emit(_dots)
				if _dots >= get_dots_total():
					_send_message()
		TYPING_SENT:
			# Espera a que Isak se descongele (sin Agitar: la congelacion se espera) y al cruce del mensaje.
			if _message_t >= float(phase_data(3).get("message_cross_s", 0.6)):
				_typing = TYPING_IDLE
				_typing_wait = float(phase_data(3).get("typing_gap_s", 2.0))
				_attack = ATTACK_GAP


func _send_message() -> void:
	_typing = TYPING_SENT
	_attack = ATTACK_MESSAGE
	_message_t = 0.0
	var isak: Isak = find_isak()
	var frozen: bool = false
	if isak != null and not isak.is_dead():
		frozen = isak.freeze(float(phase_data(3).get("message_freeze_s", 2.5)), Isak.FREEZE_SOURCE_BOSS)
	attack_started.emit(ATTACK_MESSAGE)
	message_sent.emit(frozen)


## Pulso de Isak (EventBus.pulse_fired): apaga zonas «Visto», rompe una capa del
## escudo con la arena limpia y deja en silencio el «escribiendo…».
func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


## Verdadero si el pulso hizo algo (zona apagada, capa del escudo o «escribiendo…» interrumpido).
func receive_pulse(area: Area2D) -> bool:
	if not is_fighting() or area == null:
		return false
	var done: bool = false
	if _attack == ATTACK_SEEN_ZONES:
		for i: int in _zones.size():
			if not _zone_off[i] and PulseReceiver.pulse_reaches(area, _zones[i]):
				_zone_off[i] = true
				done = true
	if get_phase() == 2 and _sweep_t >= 0.0 and PulseReceiver.pulse_reaches(area, get_sweep_rect()):
		_sweep_t = -1.0
		_sweep_side = SIDE_RIGHT if _sweep_side == SIDE_LEFT else SIDE_LEFT
		_sweep_wait = float(section("seen_sweep").get("interval_s", 7.0))
		done = true
	if receive_shield_pulse(area):
		done = true
	if get_typing_state() == TYPING_ON and _dots < get_dots_total() \
			and PulseReceiver.pulse_reaches(area, get_typing_rect()):
		interrupt_typing()
		done = true
	return done


## El «escribiendo…» se queda en silencio: aturdido phase3.window_s del lado de Isak.
func interrupt_typing() -> void:
	if get_typing_state() != TYPING_ON:
		return
	_typing = TYPING_SILENT
	_dots = 0
	_attack = ATTACK_WINDOW
	var isak: Isak = find_isak()
	_stun_side = side_of_x(isak.global_position.x) if isak != null else SIDE_LEFT
	typing_interrupted.emit()
	open_window(float(phase_data(3).get("window_s", 3.0)))


func _spawn_ghosts() -> void:
	_ghosts.clear()
	_ghost_wait.clear()
	for i: int in (_arena.get("ghost_cells", []) as Array).size():
		_ghosts.append(null)
		_ghost_wait.append(0.0)
		_spawn_ghost(i)


func _spawn_ghost(index: int) -> void:
	var cells: Array = _arena.get("ghost_cells", [])
	if index >= cells.size():
		return
	var cell: Array = cells[index]
	var ghost := GHOST_SCENE.instantiate() as Ghost
	ghost.name = "SeenGhost%d" % index
	ghost.position = _attacks.to_local(_to_global(Vector2((float(cell[0]) + 0.5) * _tile, (float(cell[1]) + 1.0) * _tile)))
	_attacks.add_child(ghost)
	_ghosts[index] = ghost
	_ghost_wait[index] = -1.0


func _step_ghost_respawn(dt: float) -> void:
	for i: int in _ghosts.size():
		var g: Ghost = _ghosts[i]
		if g != null and is_instance_valid(g) and not g.is_defeated():
			continue
		if _ghost_wait[i] < 0.0:
			_ghost_wait[i] = float(phase_data(3).get("ghost_respawn_s", 5.0))
		_ghost_wait[i] -= dt
		if _ghost_wait[i] <= 0.0:
			if g != null and is_instance_valid(g):
				g.queue_free()
			_spawn_ghost(i)


# --- Peligros, esbirros y limpieza ---

## Embestida, burbujas que caen (dano) y zonas «Visto» (congelan).
func _check_hazards() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead():
		return
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	if get_dash_stage() == DASH_CHARGE and not _charge_hit and get_silhouette_rect().intersects(body):
		if _hurt(isak, float(section("ghost_dash").get("damage", 10.0)), _charge_dir):
			_charge_hit = true
	if is_bubble_falling():
		var dmg: float = float(section("falling_bubbles").get("damage", 10.0))
		for i: int in _bubble_cols.size():
			if not _bubble_hit[i] and get_falling_rect(_bubble_cols[i]).intersects(body):
				if _hurt(isak, dmg, signf(body.get_center().x - get_falling_rect(_bubble_cols[i]).get_center().x)):
					_bubble_hit[i] = true
	if get_zone_state() == ZONE_ACTIVE and not isak.is_frozen():
		var feet: Vector2 = isak.global_position + Vector2(0.0, -1.0)
		var freeze_s: float = float(section("seen_zones" if get_phase() == 1 else "seen_sweep").get("freeze_s", 1.5))
		for rect: Rect2 in get_zone_rects():
			if rect.has_point(feet):
				isak.freeze(freeze_s, Isak.FREEZE_SOURCE_ZONE)
				break


func _hurt(isak: Isak, damage: float, direction: float) -> bool:
	if not isak.take_hit(direction):
		return false
	GameState.apply_sync_damage(damage)
	return true


## Con Isak congelado, los Trolls de la arena y los Stickers y Fantasmas del jefe
## se quedan quietos (sin proceso); se reanudan al descongelarse.
func _set_minions_paused(paused: bool) -> void:
	if paused:
		for node: Node in _minions():
			if node.process_mode != Node.PROCESS_MODE_DISABLED and not _paused_minions.has(node):
				node.process_mode = Node.PROCESS_MODE_DISABLED
				_paused_minions.append(node)
		return
	for node: Node in _paused_minions:
		if not is_instance_valid(node):
			continue
		var phases: Array = node.get_meta(BossBase.PHASE_META, []) if node.has_meta(BossBase.PHASE_META) else []
		if phases.is_empty() or phases.has(get_phase()):
			node.process_mode = Node.PROCESS_MODE_INHERIT
	_paused_minions.clear()


func get_paused_minions() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in _paused_minions:
		if is_instance_valid(node):
			out.append(node)
	return out


## Trolls activos de la arena, Stickers y Fantasmas del jefe.
func _minions() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in BossBase.phase_nodes(_level_root()):
		if node is Troll and BossBase.is_phase_node_active(node):
			out.append(node)
	for s: Sticker in get_stickers():
		out.append(s)
	for g: Ghost in get_ghosts():
		out.append(g)
	return out


func _clear_attacks() -> void:
	_set_minions_paused(false)
	for s: Sticker in _stickers:
		if is_instance_valid(s):
			s.queue_free()
	_stickers.clear()
	for g: Ghost in _ghosts:
		if g != null and is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()
	_ghost_wait.clear()
	_bubble_cols.clear()
	_bubble_hit.clear()
	_zones.clear()
	_zone_off.clear()
	_attack = &""
	_attack_t = 0.0
	_dash = DASH_NONE
	_decoy_at = Vector2.INF
	_sweep_t = -1.0
	_typing = TYPING_IDLE
	_message_t = -1.0
	_shield_up = false


# --- Construccion y dibujo ---

func _build() -> void:
	_body_tex = _make_body_texture()
	_body_sprite = Sprite2D.new()
	_body_sprite.name = "Body"
	_body_sprite.top_level = true
	_body_sprite.centered = false
	_body_sprite.z_index = -1
	_body_sprite.texture = _body_tex
	add_child(_body_sprite)
	_sil_sprite = _make_silhouette_sprite("Silhouette")
	_decoy_sprite = _make_silhouette_sprite("DecoySilhouette")
	_core = WEAK_POINT_SCENE.instantiate() as WeakPoint
	_core.name = "UnreadCheck"
	_core.top_level = true
	add_child(_core)
	set_weak_point(_core)
	_core.set_enabled(false)
	_attacks = Node2D.new()
	_attacks.name = "Attacks"
	_attacks.top_level = true
	add_child(_attacks)
	_fx = SeenFx.new()
	_fx.name = "SeenFx"
	_fx.top_level = true
	_fx.z_index = 40
	_fx.boss = self
	add_child(_fx)
	_body_help = _make_help_marker("BodyHelp", is_body_help_available, help_id("boss"))
	_shield_help = _make_help_marker("ShieldHelp", is_shield_help_available, help_id("shield"))
	_typing_help = _make_help_marker("TypingHelp", is_typing_help_available, help_id("typing"))
	_refresh()


func _make_silhouette_sprite(node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.top_level = true
	sprite.centered = false
	sprite.z_index = 39
	sprite.visible = false
	add_child(sprite)
	return sprite


func _texture(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		var path: String = ART_DIR + file_name
		_textures[file_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[file_name]


func _art_texture(frame: Array, small: bool = false) -> Texture2D:
	if String(frame[0]).is_empty():
		return null
	return _texture("seen_%s%s_%02d.png" % ["small_" if small else "", frame[0], int(frame[1])])


func _art_progress(anim: String, f: float) -> int:
	var n: int = int(ART_ANIMS[anim][0])
	return clampi(floori(clampf(f, 0.0, 1.0) * float(n)), 0, n - 1)


## Pone el cuadro del cuerpo y de la silueta (arte final; si falta, el provisional).
func _refresh_art() -> void:
	var frame: Array = get_art_frame()
	var tex: Texture2D = _art_texture(frame) if frame[1] >= 0 else _art_texture(["idle", 0])
	_art_on = tex != null
	if _art_on:
		if frame[1] >= 0:
			_body_sprite.texture = tex
		_body_sprite.global_position = get_art_position()
	else:
		_body_sprite.texture = _body_tex
		_body_sprite.global_position = get_body_rect().position
	var sframe: Array = get_silhouette_art_frame()
	var stex: Texture2D = _art_texture(sframe, true) if _art_on else null
	_place_silhouette(_sil_sprite, stex, get_silhouette_rect())
	var decoy: Vector2 = get_decoy_point()
	var drect: Rect2 = _silhouette_at(decoy) if decoy != Vector2.INF and get_dash_stage() in [DASH_WARN, DASH_READY] else Rect2()
	_place_silhouette(_decoy_sprite, stex, drect)


func _place_silhouette(sprite: Sprite2D, tex: Texture2D, rect: Rect2) -> void:
	if sprite == null:
		return
	sprite.visible = tex != null and rect.has_area()
	if not sprite.visible:
		return
	sprite.texture = tex
	var flip: bool = get_dash_stage() == DASH_CHARGE and _charge_dir < 0.0
	sprite.flip_h = flip
	var off := ART_SILHOUETTE_OFFSET
	if flip:
		off.x = -off.x - tex.get_size().x
	sprite.global_position = (rect.get_center() + off).round()
	var fade: float = 1.0
	if get_dash_stage() == DASH_WARN:
		var gd: Dictionary = section("ghost_dash")
		fade = clampf(_dash_t / maxf(frames_s(gd.get("warn_frames", 9)), 0.01), 0.2, 1.0)
	sprite.modulate = Color(1, 1, 1, 0.8 * fade)


func _make_help_marker(node_name: String, available: Callable, id: StringName) -> HelpMarker:
	var marker := HelpMarker.new()
	marker.name = node_name
	marker.top_level = true
	marker.available = available
	add_child(marker)
	HelpCatalog.tag(marker, id)
	return marker


# --- Ayudas Q y musica (paso 20 de docs/propuesta-mundo-4.md) ---

## help_id de la pieza `key` (boss, shield, typing): seccion help de
## data/bosses/seen.json.
func help_id(key: String) -> StringName:
	var defaults: Dictionary = {"boss": HELP_BOSS, "shield": HELP_SHIELD, "typing": HELP_TYPING}
	return StringName(String((get_config().get("help", {}) as Dictionary).get(key, defaults.get(key, ""))))


## El cuerpo ayuda mientras se ve: el doble check o, en la fase 1, su silueta
## (oculto, sin silueta, no). Tras el golpe final, no.
func is_body_help_available() -> bool:
	if _off or is_defeated():
		return false
	if get_dash_stage() in [DASH_HIDDEN, DASH_WARN, DASH_READY, DASH_CHARGE]:
		return get_silhouette_rect().has_area()
	return true


## El escudo ayuda mientras esta levantado (fase 2, fuera de la ventana).
func is_shield_help_available() -> bool:
	return not _off and is_shield_up()


## El «escribiendo…» gigante ayuda mientras se llenan los puntos.
func is_typing_help_available() -> bool:
	return not _off and get_typing_state() == TYPING_ON


## Punto de la ayuda del cuerpo: la silueta si se ve, si no el cuerpo.
func get_body_help_point() -> Vector2:
	var sil: Rect2 = get_silhouette_rect()
	return sil.get_center() if sil.has_area() else get_body_rect().get_center()


## Musica de la pelea (mus_boss4 mientras exista; null fuera de ella).
func get_music() -> SeenMusic:
	return _music if _music != null and is_instance_valid(_music) else null


func _start_music() -> void:
	if _music == null or not is_instance_valid(_music):
		_music = SeenMusic.new()
		_music.name = "SeenMusic"
		add_child(_music)


func _stop_music() -> void:
	if _music != null and is_instance_valid(_music):
		_music.queue_free()
	_music = null


## Doble check de 6 x 3 tiles (PROVISIONAL por codigo, pixel art en bloques de 8
## px): dos checks blancos y, debajo, el check gris «sin leer» (el del WeakPoint).
func _make_body_texture() -> Texture2D:
	var rect: Rect2 = get_perch_rect()
	var w: int = maxi(int(rect.size.x), 8)
	var h: int = maxi(int(rect.size.y), 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var check: Color = _color("check_color", Color.WHITE)
	var unread: Color = _color("unread_color", Color.GRAY)
	var block: int = 8
	# Dos checks: brazo corto hacia abajo-derecha y brazo largo hacia arriba-derecha.
	for k: int in 2:
		var x0: int = 40 + k * 112
		_check_blocks(img, Vector2i(x0, 72), block, check)
	_check_blocks_small(img, Vector2i(160, 136), block, unread)
	return ImageTexture.create_from_image(img)


func _check_blocks(img: Image, origin: Vector2i, block: int, color: Color) -> void:
	for i: int in 5:
		_fill_block(img, origin + Vector2i(i * block, i * block), block * 2, color)
	for i: int in 12:
		_fill_block(img, origin + Vector2i((5 + i) * block, (4 - i) * block), block * 2, color)


func _check_blocks_small(img: Image, origin: Vector2i, block: int, color: Color) -> void:
	for i: int in 2:
		_fill_block(img, origin + Vector2i(i * block, i * block), block, color)
	for i: int in 5:
		_fill_block(img, origin + Vector2i((2 + i) * block, (1 - i) * block), block, color)


func _fill_block(img: Image, at: Vector2i, size: int, color: Color) -> void:
	var r := Rect2i(at, Vector2i(size, size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.has_area():
		img.fill_rect(r, color)


func _refresh() -> void:
	if _body_sprite == null:
		return
	_refresh_art()
	var alpha: float = 1.0
	match get_dash_stage():
		DASH_VANISH:
			# El arte final se deshace en humo el solo: el alfa baja menos.
			var f: float = clampf(_dash_t / maxf(float(section("ghost_dash").get("vanish_s", 0.5)), 0.01), 0.0, 1.0)
			alpha = 1.0 - (f * f if _art_on else f)
		DASH_HIDDEN, DASH_WARN, DASH_READY, DASH_CHARGE:
			alpha = 0.0
		DASH_RETURN:
			alpha = clampf(_dash_t / maxf(float(section("ghost_dash").get("return_s", 0.6)), 0.01), 0.0, 1.0)
	_body_sprite.modulate = Color(1, 1, 1, alpha * (0.85 + 0.15 * sin(_time * TAU * 0.5)))
	if _body_help != null:
		_body_help.global_position = get_body_help_point()
	if _shield_help != null:
		_shield_help.global_position = get_shield_rect().get_center()
	if _typing_help != null:
		_typing_help.global_position = get_typing_rect().get_center()
	if _fx != null:
		_fx.queue_redraw()


func _poll_arrival() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_warping() or isak.is_dead():
		return
	begin_intro()


func _on_intro_finished() -> void:
	_intro_state = 2
	start()


func _lap_entry() -> Dictionary:
	var lap: int = lap_override if lap_override > 0 else GameState.lap
	var laps: Dictionary = get_config().get("laps", {})
	return laps.get(str(lap), laps.get("1", {}))


func _apply_lap_settings() -> void:
	apply_charger_cooldown(float(lap_value("charger_cooldown_s", -1.0)))


func _col_of(x: float) -> int:
	return int(floor(_from_global(Vector2(x, 0.0)).x / _tile))


## Color de la arena: nombre de la paleta del Mundo 4 o «#rrggbb».
func _color(key: String, fallback: Color) -> Color:
	var value: String = String(_arena.get(key, ""))
	if value.is_empty():
		return fallback
	if value.begins_with("#"):
		return Color.html(value)
	return World4ObjectsConfig.color(value, fallback)


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


## Marca de una ayuda Q de una pieza del jefe sin nodo propio (el cuerpo, el
## escudo, el «escribiendo…»): un punto que solo ayuda mientras `available` diga
## que se ve (paso 20; como Curator.HelpMarker).
class HelpMarker extends Node2D:
	var available: Callable

	func is_help_available() -> bool:
		return available.is_valid() and bool(available.call())


## Efectos por codigo: aura, escudo, silueta (sin el arte final) y rastro (con
## el Debug), burbujas que caen, zonas «Visto», «escribiendo…» gigante y
## mensaje. Rojo = lo que dana. Con el arte final el aura es un halo eliptico
## translucido alrededor del dibujo (el base de AutoSprite traia un halo opaco
## que se quito) y la silueta la dibuja el sprite (aqui solo el contorno rojo
## de la embestida).
class SeenFx extends Node2D:
	var boss: Seen

	func _draw() -> void:
		if boss == null or not boss.is_fighting() or boss.is_screen_off():
			if boss != null and boss.is_screen_off() and boss._body_sprite != null and boss._body_sprite.visible \
					and not boss.has_final_art():
				# Golpe final (provisional): el doble check se tacha. El arte final se agrieta.
				var r: Rect2 = boss.get_body_rect()
				var red := boss._color("warn_color", Color.RED)
				draw_line(r.position + Vector2(16, 16), r.end - Vector2(16, 16), red, 8.0)
			return
		var warn := boss._color("warn_color", Color.RED)
		var aura := boss._color("aura_color", Color.GRAY)
		var check := boss._color("check_color", Color.WHITE)
		var cream := boss._color("shield_color", Color.WHEAT)
		var bubble := boss._color("bubble_color", Color.DARK_BLUE)
		var coral := boss._color("trail_color", Color.CORAL)
		var t: float = boss.get_time()
		var stage: StringName = boss.get_dash_stage()
		if stage in [Seen.DASH_NONE, Seen.DASH_VANISH, Seen.DASH_RETURN]:
			if boss.has_final_art():
				# El halo se esfuma y vuelve con el cuerpo (su alfa).
				_draw_aura(boss.get_art_rect(), Color(aura, aura.a * boss._body_sprite.modulate.a), t)
			else:
				var body: Rect2 = boss.get_body_rect()
				draw_rect(body.grow(6.0 + 3.0 * sin(t * TAU * 0.8)), Color(aura, 0.25), false, 6.0)
		if boss.is_shield_up():
			var sr: Rect2 = boss.get_shield_rect()
			var n: int = 14
			for i: int in n:
				var a: float = TAU * float(i) / float(n) + t * 0.6
				var p := sr.get_center() + Vector2(cos(a) * sr.size.x * 0.5, sin(a) * sr.size.y * 0.5)
				draw_rect(Rect2(p - Vector2(14, 9), Vector2(28, 18)), Color(cream, 0.85))
			if boss.get_shield_layers_left() > 1:
				draw_rect(sr.grow(10.0), Color(cream, 0.6), false, 3.0)
		if stage in [Seen.DASH_WARN, Seen.DASH_READY, Seen.DASH_CHARGE]:
			var sil: Rect2 = boss.get_silhouette_rect()
			var fade: float = 1.0
			if stage == Seen.DASH_WARN:
				var gd: Dictionary = boss.section("ghost_dash")
				fade = clampf(boss._dash_t / maxf(boss.frames_s(gd.get("warn_frames", 9)), 0.01), 0.2, 1.0)
			if not boss.has_final_art():
				draw_rect(sil, Color(aura, 0.45 * fade))
				draw_rect(sil, Color(check, 0.8 * fade), false, 3.0)
			var decoy: Vector2 = boss.get_decoy_point()
			if decoy != Vector2.INF and not boss.has_final_art():
				var dr: Rect2 = boss._silhouette_at(decoy)
				draw_rect(dr, Color(aura, 0.45 * fade))
				draw_rect(dr, Color(check, 0.8 * fade), false, 3.0)
			if stage == Seen.DASH_CHARGE:
				draw_rect(sil, Color(warn, 0.5), false, 4.0)
		if boss.is_trail_visible():
			var from: Vector2 = boss.get_vanish_point()
			var to: Vector2 = boss.get_appear_point() + Vector2(0.0, -float(boss._arena.get("phone_dy_px", 58.0)))
			var steps: int = maxi(int(from.distance_to(to) / 24.0), 1)
			for i: int in steps + 1:
				draw_circle(from.lerp(to, float(i) / float(steps)), 4.0, Color(coral, 0.9))
		for col: int in boss.get_falling_columns():
			var fr: Rect2 = boss.get_falling_rect(col)
			var floor_y: float = boss._to_global(Vector2(0.0, float(int(boss._arena.get("floor_row", 9)) + 1) * boss._tile)).y
			draw_rect(Rect2(fr.position.x + 8.0, floor_y - 8.0, fr.size.x - 16.0, 8.0), Color(0, 0, 0, 0.45))
			if boss.is_bubble_falling():
				draw_rect(fr.grow(-6.0), Color(check, 0.95))
				draw_rect(fr.grow(-6.0), Color(warn, 0.9), false, 3.0)
			else:
				var column := Rect2(fr.position.x, fr.position.y, fr.size.x, floor_y - fr.position.y)
				draw_rect(column, Color(warn, 0.9), false, 3.0)
		var zstate: StringName = boss.get_zone_state()
		if zstate != Seen.ZONE_OFF:
			for zr: Rect2 in boss.get_zone_rects():
				draw_rect(zr, Color(aura, 0.35 if zstate == Seen.ZONE_WARN else 0.6))
				draw_rect(zr, Color(coral if zstate == Seen.ZONE_ACTIVE else aura, 0.9), false, 3.0)
		if boss.get_phase() == 3:
			var state: StringName = boss.get_typing_state()
			if state != Seen.TYPING_IDLE:
				var tr: Rect2 = boss.get_typing_rect()
				draw_rect(tr.grow(-8.0), Color(bubble, 0.95))
				draw_rect(tr.grow(-8.0), Color(aura, 0.9), false, 3.0)
				var total: int = boss.get_dots_total()
				for i: int in total:
					var c := tr.get_center() + Vector2((float(i) - float(total - 1) * 0.5) * 48.0, 0.0)
					var lit: bool = i < boss.get_dots()
					draw_circle(c, 12.0, Color(check if lit else aura, 1.0 if lit else 0.35))
			if boss.is_message_crossing():
				var cross_s: float = float(boss.phase_data(3).get("message_cross_s", 0.6))
				var f: float = clampf(boss.get_message_t() / maxf(cross_s, 0.01), 0.0, 1.0)
				var w: float = 20.0 * boss._tile
				var x: float = boss._to_global(Vector2(-6.0 * boss._tile + f * (w + 6.0 * boss._tile), 0.0)).x
				var y: float = boss.get_typing_rect().position.y
				draw_rect(Rect2(x, y, 6.0 * boss._tile, 2.0 * boss._tile), Color(check, 0.9))

	## Halo eliptico translucido (dos anillos que laten) alrededor del dibujo.
	func _draw_aura(art: Rect2, aura: Color, t: float) -> void:
		# Lienzo de 336 x 256: el doble check ocupa ~280 x 208 en su centro.
		var center: Vector2 = art.get_center() + Vector2(0.0, -4.0)
		var radius: Vector2 = Vector2(art.size.x * 0.5 - 8.0, art.size.y * 0.5 - 20.0)
		var pulse: float = 3.0 * sin(t * TAU * 0.8)
		for ring: int in 2:
			var r: Vector2 = radius + Vector2.ONE * (pulse + 10.0 * float(ring))
			draw_set_transform(center, 0.0, Vector2(1.0, r.y / maxf(r.x, 1.0)))
			draw_arc(Vector2.ZERO, r.x, 0.0, TAU, 48, Color(aura, aura.a * (0.22 - 0.1 * float(ring))), 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
