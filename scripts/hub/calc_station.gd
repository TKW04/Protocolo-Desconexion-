## Calc dormida en el dock del hub (docs/propuesta-hub-y-guardado.md §3.2; paso
## 8 de §6.2; docs/05-hub.md §13.3): antes de vencer a Alerta Mayor esta
## dormida, no habla ni tiene voz, pero su teclado vende las mejoras. Es un
## HubStation (pulso para abrir, Isak de espaldas) con el panel de tienda
## CalcPanel. Valores en la seccion calc de data/hub.json.
## Arte: SpriteFrames `frames` (calc_frames.tres) con la animacion `animation`
## (sleep) siempre en marcha; la estacion ocupa 1x2 tiles y el arte (64x96) se
## apoya en el suelo sin escalarse. Al abrir, destello cian como las demas
## estaciones. Despertarla (animacion awake y dialogos) llega tras Alerta Mayor.
class_name CalcStation
extends HubStation

var _calc: Dictionary = HubData.section("calc")


func get_calc_panel() -> CalcPanel:
	return get_panel() as CalcPanel


## Animacion del arte (sleep mientras esta dormida).
func get_calc_animation() -> StringName:
	var sprite := get_visual() as AnimatedSprite2D
	return sprite.animation if sprite != null else &""


func _create_panel() -> HubPanel:
	return CalcPanel.new()


## Arte de Calc sin escalar, con los pies en el suelo (borde inferior de la
## estacion). Sin frames, el provisional.
func _build_visual(size: Vector2) -> Node2D:
	if frames.is_empty() or not ResourceLoader.exists(frames):
		return super._build_visual(size)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load(frames) as SpriteFrames
	sprite.centered = false
	var anim := StringName(String(_calc.get("animation", "sleep")))
	if sprite.sprite_frames.has_animation(anim):
		var tex: Texture2D = sprite.sprite_frames.get_frame_texture(anim, 0)
		sprite.position = Vector2(floorf((size.x - tex.get_width()) * 0.5), size.y - tex.get_height())
		sprite.play(anim)
	return sprite


## Calc no cambia de animacion con el prompt: sigue dormida.
func _show_visual_state(_value: StringName) -> void:
	var sprite := get_visual() as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim := StringName(String(_calc.get("animation", "sleep")))
	if sprite.sprite_frames.has_animation(anim) and (sprite.animation != anim or not sprite.is_playing()):
		sprite.play(anim)
