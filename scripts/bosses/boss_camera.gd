## Encuadre de la arena de un jefe (2026-10-22, defecto de las capturas de Alerta
## Mayor: la arena de 24 tiles, 1536 px, no cabe en los 1280 px de la pantalla y
## con Isak a un lado el jefe o sus copias quedaban cortados).
##
## Mueve en horizontal la Camera2D de Isak (su posicion local, sin cambiar la
## escala ni el suavizado propio de la camara, que hace de suavizado corto) para
## centrarla entre Isak y lo que el jefe pide encuadrar
## (BossBase.get_camera_focus_xs: el cuerpo y, en la fase 3, las copias): el
## centro va a isak_weight entre Isak (1) y el centro de esos puntos (0), sin
## dejar a Isak a menos de isak_margin_px del borde de la pantalla. Los limites
## de la camara (la arena) siguen mandando. La vertical no cambia.
## Datos: seccion camera de data/bosses/<id>.json (follow, isak_weight,
## isak_margin_px). Solo encuadre: la pelea, el bot y el validador no lo usan.
class_name BossCamera
extends Node

var boss: BossBase
var _isak: Isak
var _base_y: float = NAN


static func attach(owner_boss: BossBase) -> BossCamera:
	var cam := BossCamera.new()
	cam.name = "BossCamera"
	cam.boss = owner_boss
	owner_boss.add_child(cam)
	return cam


func _process(_delta: float) -> void:
	apply()


## Desplazamiento horizontal (px, local a Isak) que toca ahora; 0 sin Isak.
func get_offset_x() -> float:
	if boss == null or not is_instance_valid(boss):
		return 0.0
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(boss)
	if _isak == null:
		return 0.0
	var xs: PackedFloat32Array = boss.get_camera_focus_xs()
	if xs.is_empty():
		return 0.0
	var lo: float = xs[0]
	var hi: float = xs[0]
	for x: float in xs:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	var cfg: Dictionary = boss.get_config().get("camera", {})
	var w: float = clampf(float(cfg.get("isak_weight", 0.5)), 0.0, 1.0)
	var isak_x: float = _isak.global_position.x
	var center: float = lerpf((lo + hi) * 0.5, isak_x, w)
	var half: float = _view_width() * 0.5 - float(cfg.get("isak_margin_px", 192))
	if half > 0.0:
		center = clampf(center, isak_x - half, isak_x + half)
	return center - isak_x


## Aplica el desplazamiento a la Camera2D de Isak (la de torre no se toca).
func apply() -> void:
	if _isak != null and is_instance_valid(_isak) and _isak.get_tower_camera() != null:
		return
	var dx: float = get_offset_x()
	if _isak == null or not is_instance_valid(_isak):
		return
	var cam: Camera2D = _isak.get_camera()
	if cam == null:
		return
	cam.position.x = roundf(dx)


func _view_width() -> float:
	var vp: Viewport = get_viewport()
	var cam: Camera2D = _isak.get_camera() if _isak != null else null
	var zoom: float = cam.zoom.x if cam != null and cam.zoom.x > 0.0 else 1.0
	return (vp.get_visible_rect().size.x if vp != null else 1280.0) / zoom
