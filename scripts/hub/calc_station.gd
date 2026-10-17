## Calc en el dock del hub (docs/propuesta-hub-y-guardado.md §3.2; paso 8 de
## §6.2; docs/05-hub.md §13.3). APAGADA hasta conocerla (2026-10-16,
## docs/propuesta-asistentes-y-vidas.md §2.3, paso 10 de §10): mientras
## GameState no tenga "calc" en allies_met (requires_ally de data/hub.json;
## HubRoom la apaga con set_powered) muestra powered_off (Calc con la pantalla
## negra, sin animacion), sin prompt ni tienda.
## ENCUENTRO (2026-10-17, tanda H3 del paso 14 del 1-2): Calc se carga en la
## azotea del 1-2 y se teletransporta al hub; al llegar Isak, Calc ya esta en su
## estacion DESPIERTA (set_arrived: animacion awake aunque siga apagada, sin
## prompt ni tienda) y habla (CalcIntro, data/calc_intro.json). Al terminar,
## GameState.meet_ally("calc") la enciende (EventBus.ally_met -> HubRoom) y su
## teclado vende las mejoras (CalcPanel; la tienda no cambia). Conocida sigue
## despierta (`animation` de la seccion calc de data/hub.json: awake). Tambien
## la encienden el argumento de depuracion --meet-ally=calc y el helper de
## pruebas. Es un HubStation (pulso para abrir, Isak de espaldas) con el panel de
## tienda CalcPanel. Valores en la seccion calc de data/hub.json.
## Arte: SpriteFrames `frames` (calc_frames.tres) con la animacion `animation`
## siempre en marcha; la estacion ocupa 1x2 tiles y el arte (64x96) se apoya en
## el suelo sin escalarse. Al abrir, destello cian como las demas estaciones.
class_name CalcStation
extends HubStation

var _calc: Dictionary = HubData.section("calc")
## Calc ya llego al hub (encuentro pendiente): se ve despierta aunque este apagada.
var _arrived: bool = false


func get_calc_panel() -> CalcPanel:
	return get_panel() as CalcPanel


## Calc acaba de llegar al hub para su encuentro (CalcIntro): despierta aunque
## siga apagada (sin prompt ni tienda hasta meet_ally).
func set_arrived(value: bool) -> void:
	_arrived = value
	_apply_visuals()


func is_arrived() -> bool:
	return _arrived


## Animacion del arte (awake; powered_off apagada y sin llegar).
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
	var anim := StringName(String(_calc.get("animation", "awake")))
	if sprite.sprite_frames.has_animation(anim):
		var tex: Texture2D = sprite.sprite_frames.get_frame_texture(anim, 0)
		sprite.position = Vector2(floorf((size.x - tex.get_width()) * 0.5), size.y - tex.get_height())
		sprite.play(anim)
	return sprite


## Calc no cambia de animacion con el prompt: sigue igual (o apagada, salvo si
## ya llego para su encuentro).
func _show_visual_state(value: StringName) -> void:
	var sprite := get_visual() as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim := StringName(String(_calc.get("animation", "awake")))
	if value == VISUAL_POWERED_OFF and not _arrived and sprite.sprite_frames.has_animation(VISUAL_POWERED_OFF):
		anim = VISUAL_POWERED_OFF
	if sprite.sprite_frames.has_animation(anim) and (sprite.animation != anim or not sprite.is_playing()):
		sprite.play(anim)
