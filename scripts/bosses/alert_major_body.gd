## Cuerpo dibujado de Alerta Mayor (arte final de AutoSprite, paso 16 de
## docs/propuesta-jefe-alerta-mayor.md; plan en docs/plan-arte-jefe-alerta-mayor.md,
## 2026-10-22). Lo usan el jefe real (AlertMajor) y sus copias
## (AlertMajorClone): el jefe decide la animacion y el cuadro de todos a la vez,
## asi la copia es IDENTICA a la real (solo el nucleo con el Debug las distingue).
##
## Datos en `art` de data/bosses/alert_major.json: cada animacion (frames, fps,
## loop, foot_px) tiene sus cuadros en assets/sprites/bosses/alert_major_<anim>_NN.png
## (tools/import_boss_alert_major.py). foot_px: px bajo el centro del lienzo donde
## esta la planta del cuadro de referencia. El nodo esta en el CENTRO del cuerpo
## del jefe; la planta se coloca a `up_bottom_px` (arriba: hover, inflate) o a
## `down_bottom_px` (abajo: window, lunge_warn, lunge) bajo el centro. descend y
## ascend van con el factor de arriba y el juego los encoge / agranda
## (`down_scale`) y baja / sube su planta con la fraccion del movimiento.
## La estela del lanzamiento (banner_gris) se dibuja aqui, como en el provisional.
## Sin colision ni logica: todo lo decide quien lo usa.
class_name AlertMajorBody
extends Node2D

const CONFIG_PATH: String = "res://data/bosses/alert_major.json"
const UP_ANIMS: Array[StringName] = [&"hover", &"inflate"]
const TRANSITION_ANIMS: Array[StringName] = [&"descend", &"ascend"]

static var _art_cache: Dictionary = {}

var _sprite: Sprite2D
## Texturas ya cargadas por este cuerpo ("anim/NN" -> Texture2D).
var _textures: Dictionary = {}
var _anim: StringName = &""
var _frame: int = 0
var _trail_dir: float = 0.0
var _trail_y: float = 0.0


## Seccion `art` del JSON del jefe (en cache).
static func art_config() -> Dictionary:
	if _art_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_art_cache = (parsed as Dictionary).get("art", {})
	return _art_cache


## Datos de una animacion (frames, fps, loop, foot_px).
static func anim_config(anim: StringName) -> Dictionary:
	return ((art_config().get("anims", {}) as Dictionary).get(String(anim), {}) as Dictionary)


## Numero de cuadros de `anim` (art.anims.<anim>.frames).
static func frame_count(anim: StringName) -> int:
	return int(anim_config(anim).get("frames", 0))


## Ruta del cuadro `frame` de `anim`.
static func frame_path(anim: StringName, frame: int) -> String:
	return "%s%s_%s_%02d.png" % [String(art_config().get("dir", "res://assets/sprites/bosses/")),
		String(art_config().get("prefix", "alert_major")), anim, frame]


## Cuadro de `anim` a los `t` segundos del mundo (con bucle o quieto en el ultimo).
static func frame_at_time(anim: StringName, t: float) -> int:
	var n: int = frame_count(anim)
	if n <= 0:
		return 0
	var i: int = int(floor(maxf(t, 0.0) * float(anim_config(anim).get("fps", 12.0))))
	return posmod(i, n) if bool(anim_config(anim).get("loop", false)) else mini(i, n - 1)


## Cuadro de `anim` en la fraccion `f` (0-1) de un movimiento.
static func frame_at_fraction(anim: StringName, f: float) -> int:
	var n: int = frame_count(anim)
	return clampi(int(floor(clampf(f, 0.0, 1.0) * float(n))), 0, maxi(n - 1, 0))


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	add_child(_sprite)
	show_frame(&"hover" if _anim.is_empty() else _anim, _frame)


## Muestra el cuadro `frame` de `anim`. `f`: fraccion del movimiento (descend y
## ascend: tamano y planta). `flip`: mira a la izquierda (lanzamiento hacia la
## izquierda). `trail_dir`: estela del lanzamiento (+1 / -1 hacia donde va; 0 sin
## estela).
func show_frame(anim: StringName, frame: int, f: float = 0.0, flip: bool = false, trail_dir: float = 0.0) -> void:
	if _sprite == null:
		_anim = anim
		_frame = frame
		return
	var n: int = frame_count(anim)
	if n <= 0:
		return
	_anim = anim
	_frame = clampi(frame, 0, n - 1)
	var key: String = "%s/%d" % [anim, _frame]
	if not _textures.has(key):
		var path: String = frame_path(anim, _frame)
		_textures[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_sprite.texture = _textures[key]
	_sprite.flip_h = flip
	var art: Dictionary = art_config()
	var up_bottom: float = float(art.get("up_bottom_px", 110.0))
	var down_bottom: float = float(art.get("down_bottom_px", 64.0))
	var k: float = float(art.get("down_scale", 0.675))
	var foot: float = float(anim_config(anim).get("foot_px", up_bottom))
	var s: float = 1.0
	var bottom: float = up_bottom if anim in UP_ANIMS else down_bottom
	if anim == &"descend":
		s = lerpf(1.0, k, f)
		bottom = lerpf(up_bottom, down_bottom, f)
	elif anim == &"ascend":
		s = lerpf(k, 1.0, f)
		bottom = lerpf(down_bottom, up_bottom, f)
	_sprite.scale = Vector2(s, s)
	_sprite.position = Vector2(0.0, bottom - foot * s)
	var new_trail: float = signf(trail_dir)
	var trail_y: float = float(art.get("trail_y_px", -14.0))
	if new_trail != _trail_dir or trail_y != _trail_y:
		_trail_dir = new_trail
		_trail_y = trail_y
		queue_redraw()


func get_anim() -> StringName:
	return _anim


func get_frame() -> int:
	return _frame


## Textura que se ve ahora (desarme en pixeles: PixelBurst).
func get_texture() -> Texture2D:
	return _sprite.texture if _sprite != null else null


## Centro global de la textura dibujada y su escala (PixelBurst).
func get_texture_center() -> Vector2:
	return _sprite.global_position if _sprite != null else global_position


func get_draw_scale() -> float:
	return _sprite.scale.x if _sprite != null else 1.0


func _draw() -> void:
	if _trail_dir == 0.0:
		return
	var art: Dictionary = art_config()
	var color := Color.html(String(art.get("trail_color", "#aeb8d2")))
	var lines: Array = art.get("trail_lines", [[-10, 56], [0, 80], [10, 64]])
	var start: float = float(art.get("trail_start_px", 24.0))
	for line: Variant in lines:
		var l: Array = line
		var y: float = _trail_y + float(l[0])
		var x0: float = -_trail_dir * start
		draw_rect(Rect2(minf(x0, x0 - _trail_dir * float(l[1])), y - 2.0, float(l[1]), 4.0), color)
