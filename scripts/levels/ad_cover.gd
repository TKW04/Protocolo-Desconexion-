## Anuncio sobre el boton de cerrar de un pop-up (tipo `ad_cover` del catalogo
## del Mundo 1; patron 4 «Quitar la proteccion y cerrar» de
## docs/propuesta-1-2.md §0.5 y acertijo «Correo certificado», §4; paso 3 de
## §10). «Saltar anuncio en 5…» (falso: no se salta).
## - Se coloca solo encima del boton de su pop-up (PopupBlocker u OverlayPopup con
##   object_id == target_id; su x, y del nivel es la celda del boton) y lo tapa: mientras
##   este entero, el pulso no cierra el pop-up (PopupBlocker.add_cover) y si el
##   pulso alcanza el anuncio sale una chispa gris (rebota).
## - Objetivo del laser (capa world, grupo laser_activatable): un impacto lo
##   rompe (animacion corta ad_cover_break, tiempo del mundo), deja de chocar
##   con el laser y libera el boton. Roto, queda roto (permanente).
## Sin colision con Isak.
class_name AdCover
extends Area2D

enum State { INTACT, BREAKING, BROKEN }

const GROUP: StringName = &"ad_cover"
const LAYER_WORLD: int = 1

## El laser lo ha alcanzado: empieza a romperse (el boton ya queda libre).
signal broken
## Animacion de ruptura terminada: ya no se ve.
signal gone
## El pulso lo ha alcanzado entero: rebota (chispa gris).
signal pulse_bounced

@export var object_id: StringName = &""
## Id del pop-up cuyo boton tapa (params.target).
@export var target_id: StringName = &""
@export_multiline var text: String = ""

var _config: Dictionary = World1ObjectsConfig.section("ad_cover")
var _state: State = State.INTACT
var _break_time: float = 0.0
var _sprite: EnergySprite
var _spark: EnergySprite
var _spark_time: float = -1.0
var _shape: CollisionShape2D
var _label: Label
var _popup: PopupBlocker
var _bounces: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	monitoring = false
	var size: Vector2 = get_size_px()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	add_child(_shape)
	var frames: String = String(_config.get("frames", ""))
	_sprite = EnergySprite.attach(self, &"ad_cover_intact", size * 0.5, false, frames)
	_build_text()
	_spark = EnergySprite.attach(self, &"gray_spark", size * 0.5, false, frames)
	_spark.name = "Spark"
	_spark.visible = false
	EventBus.pulse_fired.connect(receive_pulse)
	EventBus.laser_fired.connect(_on_laser_fired)
	_link_popup.call_deferred()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	match _state:
		State.INTACT:
			_sprite.advance(dt)
		State.BREAKING:
			_break_time += dt
			var fps: float = _sprite.sprite_frames.get_animation_speed(&"ad_cover_break")
			var count: int = _sprite.sprite_frames.get_frame_count(&"ad_cover_break")
			var f: int = floori(_break_time * fps)
			if f >= count:
				_state = State.BROKEN
				_sprite.visible = false
				gone.emit()
			else:
				_sprite.frame = f
	if _spark_time >= 0.0:
		_spark_time += dt
		var f2: int = floori(_spark_time * _spark.sprite_frames.get_animation_speed(&"gray_spark"))
		if f2 >= _spark.sprite_frames.get_frame_count(&"gray_spark"):
			_spark_time = -1.0
			_spark.visible = false
		else:
			_spark.frame = f2


# --- Consultas ---

func get_state() -> State:
	return _state


## Entero: tapa el boton.
func is_intact() -> bool:
	return _state == State.INTACT


func is_broken() -> bool:
	return _state != State.INTACT


func get_bounce_count() -> int:
	return _bounces


func get_popup() -> PopupBlocker:
	return _popup


func get_size_px() -> Vector2:
	return LaserReceiver._vec(_config.get("size_px", [96, 48]))


func get_rect() -> Rect2:
	return Rect2(global_position, get_size_px())


func get_text() -> String:
	return _label.text if _label != null else ""


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; roto, no.
func is_help_available() -> bool:
	return _state == State.INTACT


# --- Acciones ---

## Impacto del laser: se rompe (una vez).
func on_laser_hit(_damage: float, _source: Node) -> void:
	break_ad()


func break_ad() -> void:
	if _state != State.INTACT:
		return
	_state = State.BREAKING
	_break_time = 0.0
	_sprite.show_state(&"ad_cover_break")
	_sprite.frame = 0
	_label.visible = false
	_shape.set_deferred(&"disabled", true)
	remove_from_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	broken.emit()


## Pulso de Isak: si alcanza el anuncio entero, rebota (chispa gris).
## Verdadero si ha rebotado.
func receive_pulse(area: Area2D) -> bool:
	if _state != State.INTACT or not PulseReceiver.pulse_reaches(area, get_rect()):
		return false
	_bounces += 1
	_spark_time = 0.0
	_spark.visible = true
	_spark.frame = 0
	pulse_bounced.emit()
	return true


## Se pone encima del boton de su pop-up (centrado) y se lo apunta. El pop-up
## puede ser un PopupBlocker o, desde el 2026-10-16 (paso 7), un OverlayPopup
## translucido: entonces se dibuja por encima de su ventana.
func _link_popup() -> void:
	if target_id == &"" or not is_inside_tree():
		return
	for group: StringName in [PopupBlocker.GROUP, OverlayPopup.GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if StringName(String(node.get(&"object_id"))) != target_id:
				continue
			if node is PopupBlocker:
				_popup = node as PopupBlocker
			elif node is OverlayPopup:
				z_index = (node as OverlayPopup).get_z() + 1
				z_as_relative = false
			node.call(&"add_cover", self)
			var button: Rect2 = node.call(&"get_button_rect")
			global_position = (button.get_center() - get_size_px() * 0.5).round()
			return
	push_warning("AdCover %s: no hay pop-up con id '%s'" % [object_id, target_id])


func _build_text() -> void:
	var font := load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var font_size: int = int(_config.get("font_size", 12))
	var r: Array = _config.get("text_rect_px", [4, 13, 88, 32])
	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_font_override(&"font", font)
	_label.add_theme_font_size_override(&"font_size", font_size)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_constant_override(&"line_spacing", 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(float(r[0]), float(r[1]))
	_label.size = Vector2(float(r[2]), float(r[3]))
	_label.text = "\n".join(EcoTextBox.wrap_text(text, font, font_size, float(r[2])))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(String(_config.get("key_swap_shader", "res://assets/shaders/hud_key_swap.gdshader"))) as Shader
	material.set_shader_parameter(&"key_color", Color.html(String(_config.get("key_color", "#f2f4f8"))))
	material.set_shader_parameter(&"target_color", Color.html(String(_config.get("text_color", "#0b0e1a"))))
	_label.material = material
	add_child(_label)


## Isak dispara pegado al objetivo (el celular ya esta dentro de el o de la
## pared de detras): el rayo no lo veria, asi que el proyectil choca ya.
func _on_laser_fired(projectile: Node2D) -> void:
	if _state == State.INTACT and is_inside_tree() and projectile is LaserProjectile \
			and LaserProjectile.muzzle_crosses(projectile, get_rect()):
		(projectile as LaserProjectile).strike(self)
