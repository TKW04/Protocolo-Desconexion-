## Herramienta «Recortar» (tipo `crop_tool` del catalogo del Mundo 3; 2026-10-26,
## paso 7 de docs/propuesta-mundo-3.md §8, §3.6; nivel 3-2). Ajustes en la seccion
## crop_tool de data/world3_objects.json.
##
## Es el interruptor «No molestar» del 1-3 (DndSwitch) con otro aspecto, como el
## reproductor del 2-2 (PausePlayer): monitor con unas tijeras de recorte en la
## pared del FONDO; un PULSO que alcanza su zona (hit_rect) con Isak de espaldas
## pose_s la usa y da para siempre la habilidad `ability` (compress, gesto
## Pellizcar) con GameState.obtain_ability: se guarda, va a la Papelera en un game
## over y se pierde en un rollback sin guardar. La primera vez Eco dice su frase
## del mundo (story_line, linea importante; «Te queda mejor así.», decidida) y
## despues sale el aviso «Pellizcar: I / RB (mando)» (AbilityNotices). Un solo uso:
## con el gesto ya obtenido arranca recortada e inerte, sin linea, aviso ni Q. Sin
## tinte del nivel (no hay room_tint). Su senal switched_on (heredada) es la del
## sonido sfx_w3_crop_tool.
## El origen es la esquina superior izquierda de la celda donde Isak se pone de pie.
## Aspecto PROVISIONAL por codigo (paleta provisional del Mundo 3): foto con el
## rectangulo de recorte discontinuo y las tijeras; usada, la foto queda recortada
## (mas pequena) con el rotulo «Recortado».
class_name CropTool
extends DndSwitch

const ANIM_OFF: StringName = &"crop_tool_off"
const ANIM_HIT: StringName = &"crop_tool_hit"
const ANIM_ON: StringName = &"crop_tool_on"


func _init() -> void:
	_config = World3ObjectsConfig.section("crop_tool")
	ability = GameState.ABILITY_COMPRESS


func advance(dt: float) -> void:
	super.advance(dt)
	queue_redraw()


## Estado visible (sin SpriteFrames: lo dibuja _draw): lista, golpeada o usada.
func get_animation() -> StringName:
	if _hit_time >= 0.0 and _hit_time < float(_config.get("hit_s", 0.25)):
		return ANIM_HIT
	return ANIM_ON if is_on() else ANIM_OFF


func get_panel_rect() -> Rect2:
	var r: Array = _config.get("panel_rect", [-32, -72, 128, 88])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


# --- Interno ---

## Sin hoja de sprites: un AnimatedSprite2D vacio (DndSwitch lo espera) y _draw.
func _build() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.visible = false
	add_child(_sprite)


func _col(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_config.get(key, fallback)))


func _draw() -> void:
	var panel: Rect2 = get_panel_rect()
	# Monitor: marco dorado con luz arriba y sombra abajo.
	draw_rect(panel, _col("frame_shadow", "marco_sombra"))
	draw_rect(Rect2(panel.position, panel.size - Vector2(0.0, 3.0)), _col("frame", "dorado"))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2.0)), _col("frame_light", "dorado_luz"))
	var inset: float = float(_config.get("screen_inset_px", 6))
	var screen := Rect2(panel.position + Vector2(inset, inset), panel.size - Vector2(inset, inset) * 2.0)
	draw_rect(screen, _col("screen", "galeria_noche"))
	var anim: StringName = get_animation()
	var photo := Rect2(screen.position + Vector2(8.0, 8.0), screen.size - Vector2(16.0, 16.0))
	if anim == ANIM_ON:
		# Recortada: la foto queda mas pequena, centrada, con el rotulo.
		var small := Rect2(photo.get_center() - photo.size * 0.25 + Vector2(0.0, 6.0), photo.size * 0.5)
		draw_rect(small, _col("photo", "rosa_pastel"))
		draw_rect(Rect2(small.position.x, small.end.y - 6.0, small.size.x, 6.0), _col("photo_shade", "rosa_sombra"))
		draw_string(ThemeDB.fallback_font, Vector2(screen.position.x, screen.position.y + 12.0),
			String(_config.get("done_label", "Recortado")), HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, 10,
			_col("text", "blanco_brillante"))
		return
	draw_rect(photo, _col("photo", "rosa_pastel"))
	draw_rect(Rect2(photo.position.x, photo.end.y - 8.0, photo.size.x, 8.0), _col("photo_shade", "rosa_sombra"))
	_draw_dashed_rect(photo.grow(-6.0), _col("crop_line", "blanco_brillante"))
	_draw_scissors(LaserReceiver._vec(_config.get("scissors_center_px", [32, -30])), _col("scissors", "gris_perla"))
	if anim == ANIM_HIT:
		var c: Vector2 = LaserReceiver._vec(_config.get("scissors_center_px", [32, -30]))
		var k: float = clampf(_hit_time / maxf(float(_config.get("hit_s", 0.25)), 0.001), 0.0, 1.0)
		draw_arc(c, 16.0 + 12.0 * k, 0.0, TAU, 24, Color(_col("flash", "blanco_brillante"), 1.0 - k), 3.0)


func _draw_dashed_rect(r: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		draw_dashed_line(a, b, color, 1.0, 4.0)


## Tijeras abiertas: dos hojas cruzadas y dos aros.
func _draw_scissors(c: Vector2, color: Color) -> void:
	draw_line(c + Vector2(-10, -10), c + Vector2(6, 4), color, 2.0)
	draw_line(c + Vector2(10, -10), c + Vector2(-6, 4), color, 2.0)
	draw_arc(c + Vector2(-8, 8), 4.0, 0.0, TAU, 12, color, 2.0)
	draw_arc(c + Vector2(8, 8), 4.0, 0.0, TAU, 12, color, 2.0)
