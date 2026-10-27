## Instalacion del upgrade del hub (2026-10-27, paso 5 de
## docs/propuesta-hub-mundos-4-6.md §3.1; seccion hub_update_install de
## data/hub.json). La crea HubRoom al recibir update_install_requested (pulso al
## instalador con 3/3). Momento de historia, con el juego en pausa de principio
## a fin (convencion de pausas anidadas: solo pausa si el arbol no lo estaba y
## solo quita la pausa que puso):
## 1. BAR: barra «Instalando… No apagues el dispositivo» que se llena en bar_s s
##    de tiempo real (los marcos de las verificaciones «mandan su color»: la
##    barra usa sus tres colores).
## 2. FLASH: destello de flash_s s. Al empezar, apply (HubRoom.apply_update_install)
##    instala el upgrade (GameState.install_hub_upgrade: solo marca «sin
##    guardar»), quita el acertijo, construye las carpetas M4 y M5 en la pagina 2
##    y abre la pagina 3 (M6).
## 3. NOTAS: linea importante de Notas (notas_line, PROPUESTA) en el cuadro del hub.
## 4. DONE: se quita la pausa y se suelta el control (finished); Notas recuerda
##    guardar (show_saved_reminder, no importante; paso 6).
## Arte PROVISIONAL por codigo (paso 7). advance(delta) permite avanzarla en pruebas.
class_name HubUpdateInstall
extends CanvasLayer

enum Step { WAITING, BAR, FLASH, NOTAS, DONE }

## Cambio de paso.
signal step_changed(step: Step)
## Termino la instalacion (control devuelto).
signal finished

## Upgrade que se instala.
var upgrade_id: StringName = &""
## Cuadro de texto del hub (linea de Notas).
var text_box: EcoTextBox
## Se llama al empezar el destello (HubRoom.apply_update_install).
var apply: Callable = Callable()
## Colores de las tres verificaciones (barra).
var colors: Array[Color] = [Color("#3dfff5"), Color("#ffa858"), Color("#a6ff2e")]

var _cfg: Dictionary = HubData.section("hub_update_install")
var _step: Step = Step.WAITING
var _time: float = 0.0
var _owns_pause: bool = false
var _art: _InstallArt


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	_art = _InstallArt.new()
	_art.name = "Art"
	_art.owner_install = self
	_art.visible = false
	add_child(_art)


func _exit_tree() -> void:
	_release_pause()


func _process(delta: float) -> void:
	if _step == Step.BAR or _step == Step.FLASH:
		advance(delta)


# --- Consultas ---

func get_step() -> Step:
	return _step


func is_running() -> bool:
	return _step != Step.WAITING and _step != Step.DONE


func is_done() -> bool:
	return _step == Step.DONE


## Llenado de la barra (0-1).
func get_bar_fill() -> float:
	if _step == Step.BAR:
		return clampf(_time / get_bar_s(), 0.0, 1.0)
	return 1.0 if _step != Step.WAITING else 0.0


func get_bar_s() -> float:
	return maxf(float(_cfg.get("bar_s", 3.0)), 0.01)


func get_flash_s() -> float:
	return maxf(float(_cfg.get("flash_s", 0.3)), 0.01)


func get_bar_text() -> String:
	return String(_cfg.get("bar_text", "Instalando…"))


func get_notas_line() -> String:
	return String(_cfg.get("notas_line", ""))


# --- Acciones ---

## Empieza la instalacion. Falso si ya empezo.
func start() -> bool:
	if _step != Step.WAITING:
		return false
	_hold_pause()
	_set_step(Step.BAR)
	return true


## Avanza `delta` s de tiempo real (lo llama _process; util en pruebas).
func advance(delta: float) -> void:
	match _step:
		Step.BAR:
			_time += delta
			if _time >= get_bar_s():
				_time = 0.0
				_set_step(Step.FLASH)
				if apply.is_valid():
					apply.call(upgrade_id)
		Step.FLASH:
			_time += delta
			if _time >= get_flash_s():
				_time = 0.0
				_start_notas()
	if _art != null:
		_art.queue_redraw()


# --- Interno ---

func _set_step(step: Step) -> void:
	_step = step
	if _art != null:
		_art.visible = step == Step.BAR or step == Step.FLASH
		_art.queue_redraw()
	step_changed.emit(step)


func _start_notas() -> void:
	var line: String = get_notas_line()
	if text_box == null or line.is_empty():
		_finish()
		return
	_set_step(Step.NOTAS)
	text_box.line_finished.connect(_on_line_finished, CONNECT_ONE_SHOT)
	text_box.show_line(line, -1.0, true, StringName(String(_cfg.get("notas_speaker", "notas"))))


func _on_line_finished(_speaker: StringName) -> void:
	_finish.call_deferred()


func _finish() -> void:
	if _step == Step.DONE:
		return
	_set_step(Step.DONE)
	_release_pause()
	show_saved_reminder()
	finished.emit()


## Recordatorio de Notas al soltar el control (2026-10-27, paso 6;
## hub_update_hints.saved_reminder de data/hub.json, PROPUESTA de §2.6): «¡Apuntado!
## Guárdalo para que no se pierda.», NO importante, una vez por partida guardada
## (seen_notices). Verdadero si salio.
func show_saved_reminder() -> bool:
	var cfg: Variant = HubData.section("hub_update_hints").get("saved_reminder", {})
	if not cfg is Dictionary or text_box == null:
		return false
	var notice := StringName(String((cfg as Dictionary).get("notice", "hub_update_saved_reminder")))
	var text: String = String((cfg as Dictionary).get("text", ""))
	if text.is_empty() or GameState.is_notice_seen(notice):
		return false
	GameState.mark_notice_seen(notice)
	text_box.show_line(text, float((cfg as Dictionary).get("duration_s", -1.0)), false,
		StringName(String((cfg as Dictionary).get("speaker", "notas"))))
	return true


func _hold_pause() -> void:
	if _owns_pause or not is_inside_tree() or get_tree().paused:
		return
	get_tree().paused = true
	_owns_pause = true


func _release_pause() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	if is_inside_tree():
		get_tree().paused = false


## Barra y destello PROVISIONALES por codigo (paso 7), centrados en pantalla.
class _InstallArt:
	extends Control
	var owner_install: HubUpdateInstall

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280.0, 720.0)

	func _draw() -> void:
		if owner_install == null:
			return
		var cfg: Dictionary = owner_install._cfg
		var s: Array = cfg.get("bar_size_px", [480, 24])
		var bar := Vector2(float(s[0]), float(s[1]))
		var panel := Rect2(Vector2(640.0, 360.0) - Vector2(bar.x + 48.0, bar.y + 96.0) * 0.5,
			Vector2(bar.x + 48.0, bar.y + 96.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(HubData.color("fondo_profundo"), 0.55))
		draw_rect(panel.grow(2.0), HubData.color("acento_cian"))
		draw_rect(panel, HubData.color("fondo_profundo"))
		var font: Font = load("res://assets/sprites/ui/text_font.fnt") as Font
		var text: String = owner_install.get_bar_text()
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 2.0
		draw_set_transform(Vector2(640.0 - text_w * 0.5, panel.position.y + 18.0), 0.0, Vector2(2.0, 2.0))
		draw_string(font, Vector2(0.0, 12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HubData.color("texto_claro"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bar_rect := Rect2(Vector2(640.0 - bar.x * 0.5, panel.end.y - bar.y - 24.0), bar)
		draw_rect(bar_rect.grow(2.0), HubData.color("borde"))
		draw_rect(bar_rect, HubData.color("base"))
		var fill: float = owner_install.get_bar_fill()
		var n: int = maxi(owner_install.colors.size(), 1)
		var seg: float = bar.x / float(n)
		for i: int in n:
			var x0: float = float(i) * seg
			var w: float = clampf(bar.x * fill - x0, 0.0, seg)
			if w > 0.0:
				draw_rect(Rect2(bar_rect.position + Vector2(x0, 0.0), Vector2(w, bar.y)), owner_install.colors[i])
		if owner_install.get_step() == HubUpdateInstall.Step.FLASH:
			var a: float = 1.0 - clampf(owner_install._time / owner_install.get_flash_s(), 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.85 * a))
