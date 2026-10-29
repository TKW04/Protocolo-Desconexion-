## «Prueba gratis» (tipo `free_trial_box` del catalogo del Mundo 5; 2026-10-29, paso 6
## de docs/propuesta-mundo-5.md §8, §3.7, §4.2 y §4.2.2; inicio «Paquete completo» del
## 5-2). Ajustes en la seccion free_trial_box de data/world5_objects.json.
##
## Es el interruptor «No molestar» del 1-3 (DndSwitch) con otro aspecto, como el
## reproductor del Mundo 2: caja de regalo grande con lazo y el cartel del sistema
## «Prueba gratis: todo lo que necesitas, ya elegido para ti.» en la pared del FONDO.
## Un PULSO DE ESPALDAS que alcanza su hit_rect la abre y da para siempre la
## Combinacion (GameState.ABILITY_COMBO con obtain_ability: se guarda, va a la Papelera
## en un game over y se pierde en un rollback sin guardar). Dentro no hay nada nuevo:
## los tres gestos de Isak (Deslizar, Mantener, Pellizcar) que se juntan por pares
## (merge_s, dibujado por codigo; corre tambien con el juego en pausa). Momento de
## historia (pausa de principio a fin, lineas importantes en orden):
## 1. Eco: «Todo tiene un precio.» (doc);
## 2. Isak, interlocutor nuevo `isak` (speakers de data/eco_text_box.json, estilo
##    propio `isak`): «Esto no lo compré. Es mío.» (doc);
## 3. el aviso de control de la Combinacion (AbilityNotices, al obtenerla);
## 4. Eco, no importante y ya sin pausa: «Una prueba gratis siempre acaba, {apodo}.»
##    (propuesto).
## La escena sale una vez por partida guardada (seen_notices `notice_id`, combo_5_2, sin
## subir la version del guardado); la Combinacion se da siempre que no se tenga. Con la
## Combinacion ya obtenida (rejugar, rollback guardado) arranca abierta e inerte; tras
## un rollback sin ella vuelve a estar cerrada (regla unless_ability de DndSwitch).
## El origen es la esquina superior izquierda de la celda donde Isak se pone de pie.
class_name FreeTrialBox
extends DndSwitch

const SPEAKER_ISAK: StringName = &"isak"

## Ha dicho una linea de la escena (`speaker`: "" Eco, isak).
signal line_said(text: String, speaker: StringName, important: bool)

## Segundos (reales) desde que se abrio: los gestos que se juntan (-1 = cerrada).
var _merge_time: float = -1.0


func _init() -> void:
	_config = World5ObjectsConfig.section("free_trial_box")
	ability = GameState.ABILITY_COMBO


func _ready() -> void:
	super._ready()
	# Los gestos se juntan tambien con el arbol en pausa (las lineas importantes).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_inert():
		_merge_time = INF


func _process(delta: float) -> void:
	if _merge_time >= 0.0 and _merge_time < INF:
		_merge_time += delta
		queue_redraw()
	if not get_tree().paused:
		advance(WorldTime.scaled_delta(delta))
		queue_redraw()


# --- Consultas ---

func get_notice_id() -> StringName:
	return StringName(String(_config.get("notice_id", "combo_5_2")))


## Lineas de la escena en orden: [{text, speaker, important}] (sin el aviso, que lo
## pone AbilityNotices entre la de Isak y la ultima de Eco).
func get_scene_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in ["line_eco", "line_isak"]:
		var text: String = String(_config.get(key, ""))
		if not text.is_empty():
			out.append({"text": text, "speaker": SPEAKER_ISAK if key == "line_isak" else &"", "important": true})
	return out


func get_after_line() -> String:
	return String(_config.get("line_after", ""))


## Fraccion (0-1) de los gestos que se juntan; 1 = juntos (o inerte).
func get_merge_progress() -> float:
	if _merge_time < 0.0:
		return 0.0
	return clampf(_merge_time / maxf(float(_config.get("merge_s", 1.2)), 0.001), 0.0, 1.0)


func get_box_rect() -> Rect2:
	var r: Array = _config.get("box_rect", [-32, -56, 128, 120])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


# --- Acciones ---

## La abre: escena (si no se ha visto), la Combinacion y el aviso. Falso si ya estaba abierta.
func switch_on() -> bool:
	if _on:
		return false
	_on = true
	_hit_time = 0.0
	_merge_time = 0.0
	var first: bool = not GameState.is_ability_obtained(ability)
	var scene: bool = not GameState.is_notice_seen(get_notice_id())
	if scene:
		GameState.mark_notice_seen(get_notice_id())
		for line: Dictionary in get_scene_lines():
			_say(String(line["text"]), StringName(line["speaker"]), true)
	GameState.obtain_ability(ability)
	if scene:
		var after: String = get_after_line()
		if not after.is_empty():
			_say(after, &"", false)
	switched_on.emit(object_id, first)
	queue_redraw()
	return true


# --- Interno ---

## Sin hoja de sprites: un AnimatedSprite2D vacio (DndSwitch lo espera) y _draw.
func _build() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Panel"
	_sprite.visible = false
	add_child(_sprite)


## Cuadro de texto del nivel (hijo EcoTextBox de la raiz); sin cuadro, por EventBus
## como una linea de Eco (las de Isak tambien: en las pruebas sin cuadro).
func _say(text: String, speaker: StringName, important: bool) -> void:
	text = GameState.apply_nickname(text)
	line_said.emit(text, speaker, important)
	var duration: float = float(_config.get("duration_s", -1.0))
	var box: Node = _text_box()
	if box != null:
		box.call(&"show_line", text, duration, important, speaker)
	else:
		EventBus.eco_line_requested.emit(text, duration, important)


func _text_box() -> Node:
	var node: Node = get_parent()
	while node != null:
		var box: Node = node.get_node_or_null(^"EcoTextBox")
		if box != null:
			return box
		node = node.get_parent()
	return null


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_config.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var box := Rect2(get_box_rect().position - global_position, get_box_rect().size)
	var ink: Color = _c("ink", "negro_medio")
	var font: Font = ThemeDB.fallback_font
	# Cartel del sistema encima de la caja.
	var sign_rect := Rect2(Vector2(box.position.x - 40.0, box.position.y - 40.0), Vector2(box.size.x + 80.0, 30.0))
	draw_rect(sign_rect, _c("sign", "crema_cartel"))
	draw_rect(sign_rect, ink, false, 2.0)
	draw_string(font, Vector2(sign_rect.position.x, sign_rect.position.y + 12.0),
		String(_config.get("text_title", "PRUEBA GRATIS")), HORIZONTAL_ALIGNMENT_CENTER, sign_rect.size.x, 11, ink)
	draw_string(font, Vector2(sign_rect.position.x, sign_rect.end.y - 5.0),
		String(_config.get("text_sign", "Prueba gratis: todo lo que necesitas, ya elegido para ti.")),
		HORIZONTAL_ALIGNMENT_CENTER, sign_rect.size.x, 8, ink)
	var paper: Color = _c("paper", "magenta_sombra")
	var ribbon: Color = _c("ribbon", "amarillo_rebajas")
	if not is_on():
		draw_rect(box, paper)
		draw_rect(Rect2(Vector2(box.get_center().x - 6.0, box.position.y), Vector2(12.0, box.size.y)), ribbon)
		draw_rect(Rect2(Vector2(box.position.x, box.get_center().y - 6.0), Vector2(box.size.x, 12.0)), ribbon)
		draw_circle(box.position + Vector2(box.size.x * 0.5 - 12.0, -4.0), 9.0, ribbon)
		draw_circle(box.position + Vector2(box.size.x * 0.5 + 12.0, -4.0), 9.0, ribbon)
		draw_rect(box, ink, false, 2.0)
		if _hit_time >= 0.0 and _hit_time < 0.25:
			draw_rect(box.grow(4.0 + 16.0 * _hit_time), Color(ribbon, 1.0 - _hit_time * 4.0), false, 3.0)
		return
	# Abierta: caja vacia (tapa a un lado) y los tres gestos que se juntan por pares.
	var open_box := Rect2(Vector2(box.position.x, box.get_center().y), Vector2(box.size.x, box.size.y * 0.5))
	draw_rect(open_box, paper)
	draw_rect(open_box, ink, false, 2.0)
	draw_rect(Rect2(Vector2(box.end.x - 6.0, box.get_center().y - 30.0), Vector2(box.size.x * 0.4, 10.0)).abs(), ribbon)
	var k: float = get_merge_progress()
	var center := Vector2(box.get_center().x, box.position.y + 12.0)
	var spread: float = 40.0 * (1.0 - k)
	var points: Array[Vector2] = [center + Vector2(-spread - 6.0, 0.0), center + Vector2(0.0, -spread * 0.6 - 4.0),
		center + Vector2(spread + 6.0, 0.0)]
	var glow: Color = _c("glow", "debug_blanco")
	if k > 0.5:
		# Por pares: lineas entre los tres (las tres combinaciones).
		var a: float = (k - 0.5) * 2.0
		for i: int in 3:
			draw_line(points[i], points[(i + 1) % 3], Color(glow, a), 2.0)
	_draw_gesture(points[0], &"swipe", glow, ink)
	_draw_gesture(points[1], &"hold", glow, ink)
	_draw_gesture(points[2], &"pinch", glow, ink)


## Icono de un gesto (Deslizar = flecha, Mantener = flecha abajo, Pellizcar = dos flechas que se juntan).
func _draw_gesture(c: Vector2, kind: StringName, col: Color, ink: Color) -> void:
	draw_circle(c, 11.0, ink)
	draw_circle(c, 10.0, col)
	match kind:
		&"swipe":
			draw_line(c + Vector2(-6.0, 0.0), c + Vector2(6.0, 0.0), ink, 2.0)
			draw_line(c + Vector2(6.0, 0.0), c + Vector2(2.0, -4.0), ink, 2.0)
			draw_line(c + Vector2(6.0, 0.0), c + Vector2(2.0, 4.0), ink, 2.0)
		&"hold":
			draw_line(c + Vector2(0.0, -6.0), c + Vector2(0.0, 6.0), ink, 2.0)
			draw_line(c + Vector2(0.0, 6.0), c + Vector2(-4.0, 2.0), ink, 2.0)
			draw_line(c + Vector2(0.0, 6.0), c + Vector2(4.0, 2.0), ink, 2.0)
		_:
			draw_line(c + Vector2(-7.0, -5.0), c + Vector2(-2.0, 0.0), ink, 2.0)
			draw_line(c + Vector2(7.0, 5.0), c + Vector2(2.0, 0.0), ink, 2.0)
