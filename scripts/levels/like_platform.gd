## Plataforma de likes (tipo `like_platform` del catalogo del Mundo 3; 2026-10-26,
## paso 2 de docs/propuesta-mundo-3.md §8, §3.1).
## - SOLIDA (capa world) de width_tiles x 1 con card_height_px arriba de su celda
##   si GameState.likes >= threshold; con `invert`, solo si likes < threshold
##   (plataformas inversas de los secretos, con «Borrar publicaciones»).
## - Muestra su umbral siempre (corazon y cifra encima; la inversa, el corazon
##   tachado). Apagada: contorno discontinuo sin colision (Isak cae sin dano).
## - Si deja de cumplirse, PARPADEA warn_frames cuadros a anim_fps (9 a 12 fps:
##   0,75 s de tiempo del mundo; regla de 6-12 cuadros) y despues desaparece; si
##   vuelve a cumplirse durante el aviso, se queda solida.
## - No se materializa con Isak dentro de su caja (espera a que salga).
## - Al reaparecer Isak (y al empezar) se pone en su estado sin aviso.
## Aspecto PROVISIONAL por codigo (seccion like_platform de
## data/world3_objects.json, paleta provisional). El origen del nodo es la esquina
## superior izquierda de su primera celda.
class_name LikePlatform
extends StaticBody2D

const GROUP: StringName = &"like_platform"
const LAYER_WORLD: int = 1

signal switched_on
signal switched_off
signal warning_started

@export var object_id: StringName = &""
## Likes que pide (level_params: 5-25).
@export var threshold: int = 5
## Inversa: solida solo con menos likes que el umbral.
@export var invert: bool = false
@export_range(1, 4) var width_tiles: int = 2
## De una via (como las '-'); false = solida.
@export var one_way: bool = false

var _cfg: Dictionary = World3ObjectsConfig.section("like_platform")
var _solid: bool = false
## Segundos (tiempo del mundo) que le quedan al aviso; < 0 = sin aviso.
var _warn_left: float = -1.0
var _shape: CollisionShape2D
var _isak: Isak
var _font: Font


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	var size: Vector2 = get_card_size()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	_shape.one_way_collision = one_way
	add_child(_shape)
	var font_path: String = String(_cfg.get("label_font", ""))
	if not font_path.is_empty() and ResourceLoader.exists(font_path):
		_font = load(font_path) as Font
	EventBus.likes_changed.connect(_on_likes_changed)
	EventBus.player_respawned.connect(_on_player_respawned)
	snap()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func is_solid() -> bool:
	return _solid


## El contador cumple su condicion (likes >= umbral, o < con invert).
func meets_threshold(likes: int = GameState.likes) -> bool:
	return (likes < threshold) if invert else (likes >= threshold)


func is_warning() -> bool:
	return _warn_left >= 0.0


## Segundos (tiempo del mundo) que le quedan al aviso (0 sin aviso).
func get_warn_left() -> float:
	return maxf(_warn_left, 0.0)


## Aviso: warn_frames cuadros a anim_fps (0,75 s de tiempo del mundo).
func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)


## Cuadro de aviso apagado (un cuadro de cada dos a anim_fps).
func is_warn_frame_dim() -> bool:
	if not is_warning():
		return false
	var fps: float = maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)
	return int(floor((get_warn_s() - _warn_left) * fps)) % 2 == 1


## Texto del umbral («10»; el corazon se dibuja aparte).
func get_label_text() -> String:
	return str(threshold)


func get_card_size() -> Vector2:
	return Vector2(width_tiles * World3ObjectsConfig.tile_size(), float(_cfg.get("card_height_px", 32)))


func get_card_rect() -> Rect2:
	return Rect2(global_position, get_card_size())


## Ayuda de Eco: siempre (no se destruye).
func is_help_available() -> bool:
	return true


# --- Acciones ---

## Avanza `dt` segundos de tiempo del mundo (publico para las pruebas).
func advance(dt: float) -> void:
	var wants: bool = meets_threshold()
	if _solid:
		if wants:
			_warn_left = -1.0
		elif _warn_left < 0.0:
			_start_warning()
		else:
			_warn_left -= maxf(dt, 0.0)
			if _warn_left <= 0.0:
				_warn_left = -1.0
				_set_solid(false)
	elif wants and not _isak_overlaps():
		_set_solid(true)
	queue_redraw()


## Estado segun el contador ya, sin aviso (al empezar y al reaparecer Isak); con
## Isak dentro de su caja no se materializa (lo hara advance al salir).
func snap() -> void:
	_warn_left = -1.0
	var wants: bool = meets_threshold()
	if wants and _isak_overlaps():
		wants = false
	if wants != _solid or _shape.disabled == _solid:
		_set_solid(wants)
	queue_redraw()


# --- Interno ---

func _start_warning() -> void:
	_warn_left = get_warn_s()
	warning_started.emit()


func _on_likes_changed(_likes: int, _likes_max: int) -> void:
	# El aviso empieza en el mismo instante en que el contador baja del umbral.
	if _solid and not meets_threshold() and _warn_left < 0.0:
		_start_warning()
	elif _solid and meets_threshold():
		_warn_left = -1.0
	queue_redraw()


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	snap()


func _set_solid(on: bool) -> void:
	_solid = on
	if _shape != null:
		_shape.disabled = not on
	if on:
		switched_on.emit()
	else:
		switched_off.emit()


func _isak_overlaps() -> bool:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	if _isak == null:
		return false
	return LevelLookup.isak_body_rect(_isak).intersects(get_card_rect())


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, get_card_size())
	if _solid:
		var alpha: float = 0.35 if is_warn_frame_dim() else 1.0
		draw_rect(rect, Color(_c("fill", "rosa_pastel"), alpha))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), Color(_c("edge", "blanco_brillante"), alpha))
		draw_rect(Rect2(Vector2(0.0, rect.size.y - 4.0), Vector2(rect.size.x, 4.0)), Color(_c("shade", "rosa_sombra"), alpha))
		draw_rect(rect, Color(_c("frame", "dorado"), alpha), false, 2.0)
	else:
		var edge: Color = _c("off_edge", "rosa_sombra")
		var dash: float = float(_cfg.get("dash_px", 6))
		var step: float = dash + float(_cfg.get("gap_px", 6))
		var x: float = 0.0
		while x < rect.size.x:
			var w: float = minf(dash, rect.size.x - x)
			draw_rect(Rect2(x, 0.0, w, 2.0), edge)
			draw_rect(Rect2(x, rect.size.y - 2.0, w, 2.0), edge)
			x += step
		var y: float = 0.0
		while y < rect.size.y:
			var h: float = minf(dash, rect.size.y - y)
			draw_rect(Rect2(0.0, y, 2.0, h), edge)
			draw_rect(Rect2(rect.size.x - 2.0, y, 2.0, h), edge)
			y += step
	_draw_label()


## Umbral siempre visible: corazon y cifra encima de la plataforma.
func _draw_label() -> void:
	var offset: Array = _cfg.get("label_offset_px", [4, -4])
	var base := Vector2(float(offset[0]), float(offset[1]))
	var r: float = float(_cfg.get("label_heart_px", 5))
	var text: String = get_label_text()
	var size_px: int = 12
	var text_w: float = 0.0
	if _font != null:
		size_px = _font.get_fixed_size() if _font is FontFile and _font.get_fixed_size() > 0 else 12
		text_w = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var box := Rect2(base + Vector2(-2.0, -r * 2.0 - 4.0), Vector2(r * 2.0 + 6.0 + text_w, r * 2.0 + 4.0))
	draw_rect(box, Color(_c("label_back", "galeria_noche"), 0.8))
	var heart_c := base + Vector2(r + 1.0, -r - 2.0)
	HeartPickup.draw_heart(self, heart_c, r, _c("heart", "corazon_rosa"))
	if invert:
		draw_line(heart_c + Vector2(-r - 1.0, r), heart_c + Vector2(r + 1.0, -r - 1.0), _c("label", "blanco_brillante"), 1.5)
	if _font != null:
		var baseline := Vector2(base.x + r * 2.0 + 4.0, base.y - 2.0 - (r * 2.0 - _font.get_ascent(size_px)) * 0.5 - 1.0)
		draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, _c("label", "blanco_brillante"))
