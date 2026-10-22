## Historia (tipo `story_card` del catalogo del Mundo 2; 2026-10-22, paso 4 de
## docs/propuesta-mundo-2.md §8, §3.4): plataforma efimera con un contador muy
## rapido. Reutiliza la plataforma que parpadea del Mundo 1 (BlinkPlatform:
## encendida una parte del ciclo, aviso de warn_frames cuadros a anim_fps antes de
## apagarse, no se materializa con Isak dentro, tiempo del mundo).
## - Con `rhythm` sigue un metronomo del nivel (rhythm_zone / alarm_tunnel); sin
##   el, su propio reloj: ciclo de cycle_s con on_s encendida (por defecto 3,2 y
##   1,6 s), desplazado `offset` (fraccion del ciclo).
## - Encendida: aparece con un fundido (fade_s), la barra de progreso de las
##   historias (4 segmentos) se vacia; los ultimos cuadros parpadea. Apagada:
##   contorno punteado sin colision (Isak cae sin dano).
## Aspecto PROVISIONAL por codigo (seccion story_card de data/world2_objects.json,
## paleta provisional del Mundo 2). El origen del nodo es la esquina superior
## izquierda de su primera celda.
class_name StoryCard
extends BlinkPlatform

const STORY_GROUP: StringName = &"story_card"

## Ciclo propio (s de tiempo del mundo) y parte encendida (s), sin `rhythm`.
@export var cycle_s: float = 3.2
@export var on_s: float = 1.6

var _w2: Dictionary = World2ObjectsConfig.section("story_card")
var _own_clock: RhythmZone
var _on_time: float = 0.0


func _ready() -> void:
	_config = _w2
	add_to_group(STORY_GROUP)
	if rhythm_id == &"":
		_own_clock = RhythmZone.new()
		_own_clock.name = "Clock"
		_own_clock.object_id = StringName("%s_clock" % String(object_id if object_id != &"" else name))
		_own_clock.tempo_steps_s = [maxf(cycle_s, 0.05)]
		_own_clock.cycles_per_step = 1
		_own_clock.loop = true
		_own_clock.start_mode = RhythmZone.START_ALWAYS
		_own_clock.visible = false
		add_child(_own_clock)
		_rhythm = _own_clock
		on_fraction = clampf(on_s / maxf(cycle_s, 0.05), 0.05, 0.95)
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_on_time = _on_time + WorldTime.scaled_delta(delta) if _solid else 0.0


func get_rhythm() -> RhythmZone:
	if _own_clock != null and is_instance_valid(_own_clock):
		return _own_clock
	return super.get_rhythm()


## Reloj propio (null si sigue un metronomo del nivel).
func get_own_clock() -> RhythmZone:
	return _own_clock


func get_card_size() -> Vector2:
	return Vector2(width_tiles * World2ObjectsConfig.tile_size(), float(_w2.get("card_height_px", 32)))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, get_card_size())
	if not _solid:
		var edge: Color = World2ObjectsConfig.color("magenta_sombra")
		var x: float = 0.0
		while x < rect.size.x:
			draw_rect(Rect2(x, 0.0, 6.0, 2.0), edge)
			draw_rect(Rect2(x, rect.size.y - 2.0, 6.0, 2.0), edge)
			x += 12.0
		return
	var fade: float = clampf(_on_time / maxf(float(_w2.get("fade_s", 0.25)), 0.01), 0.35, 1.0)
	var warn_off: bool = is_warning() and int(floor(get_time_to_off() * float(_w2.get("anim_fps", 12.0)))) % 2 == 1
	var alpha: float = fade * (0.45 if warn_off else 1.0)
	FeedCardDraw.card(self, rect, alpha, one_way, "magenta_sombra")
	draw_rect(Rect2(rect.position + Vector2(4.0, 0.0), Vector2(rect.size.x - 8.0, 2.0)),
			Color(World2ObjectsConfig.color("magenta"), alpha))
	FeedCardDraw.segments(self, rect, get_lit_segments(), SEG_COUNT, warn_off)
