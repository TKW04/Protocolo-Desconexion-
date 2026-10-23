## Reproductor con el boton de pausa (tipo `pause_player` del catalogo del Mundo 2;
## 2026-10-22, paso 8 de docs/propuesta-mundo-2.md §8 y §3.4; nivel 2-2).
## Ajustes en la seccion pause_player de data/world2_objects.json.
##
## Es el interruptor «No molestar» del 1-3 (DndSwitch) con otro aspecto: panel de
## un reproductor de video en la pared del FONDO; un PULSO que alcanza su boton
## (hit_rect) con Isak de espaldas pose_s lo pausa y da para siempre la habilidad
## `ability` (el golpe al suelo, gesto Mantener presionado) con
## GameState.obtain_ability: se guarda, va a la Papelera en un game over y se
## pierde en un rollback sin guardar. La primera vez Eco dice su frase del mundo
## (story_line, linea importante; «Mira cuanto tiempo ahorramos juntos.», decidida
## en mundo-2 §7.5) y despues sale el aviso «Mantener presionado: …»
## (AbilityNotices). Un solo uso: con el gesto ya obtenido arranca pausado e
## inerte, sin linea, aviso ni Q. Sin tinte del nivel (no hay room_tint).
## El origen es la esquina superior izquierda de la celda donde Isak se pone de pie.
## Aspecto PROVISIONAL por codigo (FeedCardDraw, paleta provisional) hasta el arte
## del paso 10: tarjeta de video con la barra de progreso que avanza y el boton
## «||»; pausado, la barra se congela y sale «En pausa».
class_name PausePlayer
extends DndSwitch

const ANIM_OFF: StringName = &"pause_player_off"
const ANIM_HIT: StringName = &"pause_player_hit"
const ANIM_ON: StringName = &"pause_player_on"

## Fraccion de la barra de progreso al pausarse (se queda congelada).
var _paused_at: float = -1.0


func _init() -> void:
	_config = World2ObjectsConfig.section("pause_player")
	ability = GameState.ABILITY_GROUND_POUND


func advance(dt: float) -> void:
	super.advance(dt)
	queue_redraw()


func switch_on() -> bool:
	_paused_at = get_progress()
	return super.switch_on()


## Estado visible (sin SpriteFrames: lo dibuja _draw): apagado, golpeado o pausado.
func get_animation() -> StringName:
	if _hit_time >= 0.0 and _hit_time < float(_config.get("hit_s", 0.25)):
		return ANIM_HIT
	return ANIM_ON if is_on() else ANIM_OFF


## Fraccion de la barra de progreso del video (0-1); pausado no avanza.
func get_progress() -> float:
	if is_on():
		return _paused_at if _paused_at >= 0.0 else float(_config.get("paused_progress", 0.62))
	return fposmod(_time / maxf(float(_config.get("clip_s", 4.0)), 0.05), 1.0)


func get_panel_rect() -> Rect2:
	return _rect("panel_rect", [-32, -72, 128, 88])


# --- Interno ---

## Sin hoja de sprites: un AnimatedSprite2D vacio (DndSwitch lo espera) y _draw.
func _build() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.visible = false
	add_child(_sprite)


func _rect(key: String, fallback: Array) -> Rect2:
	var r: Array = _config.get(key, fallback)
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _draw() -> void:
	var panel: Rect2 = get_panel_rect()
	FeedCardDraw.card(self, panel, 1.0)
	var screen: Rect2 = Rect2(panel.position + Vector2(6.0, 8.0), panel.size - Vector2(12.0, 26.0))
	draw_rect(screen, World2ObjectsConfig.color("feed_fondo"))
	# Barra de progreso con el cabezal (magenta) bajo la pantalla.
	var bar := Rect2(screen.position.x, screen.end.y + 6.0, screen.size.x, 4.0)
	draw_rect(bar, World2ObjectsConfig.color("tarjeta_sombra"))
	var head_x: float = bar.position.x + bar.size.x * get_progress()
	draw_rect(Rect2(bar.position, Vector2(head_x - bar.position.x, bar.size.y)), World2ObjectsConfig.color("gris"))
	draw_rect(Rect2(head_x - 3.0, bar.position.y - 2.0, 6.0, bar.size.y + 4.0), World2ObjectsConfig.color("magenta"))
	var c: Vector2 = LaserReceiver._vec(_config.get("button_center_px", [32, -32]))
	var white: Color = World2ObjectsConfig.color("blanco")
	var anim: StringName = get_animation()
	if anim == ANIM_ON:
		# Pausado: triangulo de reproducir apagado y el rotulo.
		var grey: Color = World2ObjectsConfig.color("gris")
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -12), c + Vector2(-8, 12), c + Vector2(12, 0)]), grey)
		draw_string(ThemeDB.fallback_font, Vector2(screen.position.x, screen.position.y + 12.0),
			String(_config.get("paused_label", "En pausa")), HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, 10, white)
		return
	# Reproduciendo: el boton «||» que da el gesto.
	draw_rect(Rect2(c + Vector2(-10, -12), Vector2(7, 24)), white)
	draw_rect(Rect2(c + Vector2(3, -12), Vector2(7, 24)), white)
	if anim == ANIM_HIT:
		var k: float = clampf(_hit_time / maxf(float(_config.get("hit_s", 0.25)), 0.001), 0.0, 1.0)
		draw_arc(c, 18.0 + 10.0 * k, 0.0, TAU, 24, Color(World2ObjectsConfig.color("magenta"), 1.0 - k), 3.0)
