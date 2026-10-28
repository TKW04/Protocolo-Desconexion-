## «¿Deshacer escritura?» (tipo `undo_prompt` del catalogo del Mundo 4; 2026-10-28,
## paso 8 de docs/propuesta-mundo-4.md §8, §3.7 y §4.2.2; nivel 4-2, sala «Mensajes
## borrados»). Ajustes en la seccion undo_prompt de data/world4_objects.json.
##
## Es el interruptor «No molestar» del 1-3 (DndSwitch) con otro aspecto, como la
## herramienta «Recortar» del 3-2 (CropTool): panel de sistema en la pared del
## FONDO («¿Deshacer escritura? Toca para deshacer»); un PULSO que alcanza su zona
## (hit_rect) con Isak de espaldas pose_s lo usa y DESHACE LOS MUROS DE TEXTO del
## nivel (EventBus.writing_undone -> TypedWall.undo). Desde el 2026-10-28 (prueba del
## usuario: Agitar retirado) ya no da ninguna habilidad (ability vacia): vale para
## cada intento (vuelve a estar listo al reaparecer el nivel, como el muro). La
## primera vez por partida guardada (seen_notices `notice_id`) Eco dice su frase del
## mundo (story_line, linea importante; «No necesitas a nadie más.», del doc); sin
## aviso de control. Sin tinte del nivel. Su senal switched_on (heredada) es la del
## sonido sfx_w4_undo (paso 20).
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
	ability = &""


## Aviso de un solo uso de la linea de Eco (seen_notices).
func get_notice_id() -> StringName:
	return StringName("undo_" + (story_line if not story_line.is_empty() else String(object_id)))


## Lo usa: deshace los muros de texto y, la primera vez, Eco dice su linea.
func switch_on() -> bool:
	var first: bool = not story_line.is_empty() and not GameState.is_notice_seen(get_notice_id())
	if not super.switch_on():
		return false
	if first:
		GameState.mark_notice_seen(get_notice_id())
		var story: String = get_story_text()
		if not story.is_empty():
			EventBus.eco_line_requested.emit(story, float(_config.get("story_duration_s", 4.0)), true)
	EventBus.writing_undone.emit(object_id)
	return true


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
		String(_config.get("subtitle", "Toca para deshacer")), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 9,
		_col("muted", "gris_claro"))
	# Celular (forma, ademas del texto; shake_hz 0 desde que no hay Agitar: quieto).
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
