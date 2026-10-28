## «¿Deshacer escritura?» (tipo `undo_prompt` del catalogo del Mundo 4; 2026-10-28,
## paso 8 de docs/propuesta-mundo-4.md §8, §3.7 y §4.2.2; nivel 4-2, sala «Mensajes
## borrados»). Ajustes en la seccion undo_prompt de data/world4_objects.json.
##
## Es el interruptor «No molestar» del 1-3 (DndSwitch) con otro aspecto, como la
## herramienta «Recortar» del 3-2 (CropTool): panel de sistema en la pared del
## FONDO («¿Deshacer escritura? Agita el dispositivo»); un PULSO que alcanza su zona
## (hit_rect) con Isak de espaldas pose_s lo usa y da para siempre la habilidad
## `ability` (shockwave, gesto Agitar) con GameState.obtain_ability: se guarda, va a
## la Papelera en un game over y se pierde en un rollback sin guardar. La primera vez
## Eco dice su frase del mundo (story_line, linea importante; «No necesitas a nadie
## más.», del doc) y despues sale el aviso «Agitar: U / LB (mando)» (AbilityNotices).
## Un solo uso: con el gesto ya obtenido arranca deshecho e inerte, sin linea, aviso
## ni Q. Sin tinte del nivel. Su senal switched_on (heredada) es la del sonido
## sfx_w4_undo (paso 20).
## El origen es la esquina superior izquierda de la celda donde Isak se pone de pie.
## Aspecto PROVISIONAL por codigo (paleta provisional del Mundo 4): ventana de sistema
## con el texto y un celular que se sacude; usado, «Escritura deshecha».
class_name UndoPrompt
extends DndSwitch

const ANIM_OFF: StringName = &"undo_prompt_off"
const ANIM_HIT: StringName = &"undo_prompt_hit"
const ANIM_ON: StringName = &"undo_prompt_on"


func _init() -> void:
	_config = World4ObjectsConfig.section("undo_prompt")
	ability = GameState.ABILITY_SHOCKWAVE


func advance(dt: float) -> void:
	super.advance(dt)
	queue_redraw()


## Estado visible (sin SpriteFrames: lo dibuja _draw): listo, golpeado o usado.
func get_animation() -> StringName:
	if _hit_time >= 0.0 and _hit_time < float(_config.get("hit_s", 0.25)):
		return ANIM_HIT
	return ANIM_ON if is_on() else ANIM_OFF


func get_panel_rect() -> Rect2:
	var r: Array = _config.get("panel_rect", [-48, -72, 160, 88])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


# --- Interno ---

## Sin hoja de sprites: un AnimatedSprite2D vacio (DndSwitch lo espera) y _draw.
func _build() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.visible = false
	add_child(_sprite)


func _col(key: String, fallback: String) -> Color:
	return World4ObjectsConfig.color(String(_config.get(key, fallback)))


func _draw() -> void:
	var panel: Rect2 = get_panel_rect()
	var font: Font = ThemeDB.fallback_font
	# Ventana de sistema: marco marino con barra de titulo.
	draw_rect(panel, _col("frame", "marino_luz"))
	var inner := panel.grow(-3.0)
	draw_rect(inner, _col("screen", "marino_fondo"))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 12.0)), _col("title_bar", "marino_medio"))
	var anim: StringName = get_animation()
	var text: Color = _col("text", "blanco_pantalla")
	if anim == ANIM_ON:
		draw_string(font, Vector2(inner.position.x, inner.get_center().y + 4.0),
			String(_config.get("done_label", "Escritura deshecha")), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 11,
			_col("muted", "gris_claro"))
		return
	draw_string(font, Vector2(inner.position.x, inner.position.y + 26.0),
		String(_config.get("title", "¿Deshacer escritura?")), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 11, text)
	draw_string(font, Vector2(inner.position.x, inner.position.y + 40.0),
		String(_config.get("subtitle", "Agita el dispositivo")), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 9,
		_col("muted", "gris_claro"))
	# Celular que se sacude (forma, ademas del texto).
	var c: Vector2 = LaserReceiver._vec(_config.get("phone_center_px", [32, -22]))
	var shake: float = sin(_time * TAU * float(_config.get("shake_hz", 3.0))) * 2.0
	var phone := Rect2(c + Vector2(-6.0 + shake, -10.0), Vector2(12.0, 20.0))
	draw_rect(phone, _col("phone", "crema"))
	draw_rect(phone.grow(-2.0), _col("screen", "marino_fondo"))
	for side: float in [-1.0, 1.0]:
		var x: float = c.x + side * 11.0 + shake
		draw_line(Vector2(x, c.y - 5.0), Vector2(x + side * 3.0, c.y), text, 1.0)
		draw_line(Vector2(x + side * 3.0, c.y), Vector2(x, c.y + 5.0), text, 1.0)
	if anim == ANIM_HIT:
		var k: float = clampf(_hit_time / maxf(float(_config.get("hit_s", 0.25)), 0.001), 0.0, 1.0)
		draw_arc(c, 16.0 + 12.0 * k, 0.0, TAU, 24, Color(_col("flash", "blanco_pantalla"), 1.0 - k), 3.0)
