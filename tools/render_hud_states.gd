## Captura del HUD en varios estados a 1:1 (1280x720) sobre la escena de prueba
## del Mundo 1 (fondo de relojes, tileset y objetos), para juzgar la
## legibilidad a la resolucion base. Apila la franja superior de cada estado y
## debajo dos cuadros completos: Sync Rate bajo y Debug activo (tinte).
## Ademas escribe una vista ampliada x3 de la esquina derecha de cada franja.
## Estados: 100 %, 50 %, 15 % (alerta), rastro de dano, energia 0, 12 puntos,
## anillo de carga al 55 % (pulsacion larga real de la accion debug) y Debug
## activo.
## Necesita ventana (no funciona con --headless: no hay imagen que leer).
## Uso: Godot --path . -s tools/render_hud_states.gd [-- salida.png]
## Por defecto escribe assets/sprites/ui/_hud_states_preview.png y
## assets/sprites/ui/_hud_states_zoom_x3.png.
extends SceneTree

const WORLD1: String = "res://scenes/levels/world1_objects_test.tscn"
const HUD: String = "res://scenes/ui/hud.tscn"
const DEFAULT_OUT: String = "res://assets/sprites/ui/_hud_states_preview.png"
const ZOOM_SUFFIX: String = "_zoom_x3.png"
const ACTION_DEBUG: StringName = &"debug"
## Alto de cada franja (barra de 32 px y algo de juego debajo).
const STRIP_HEIGHT: int = 56
## Ancho de la esquina derecha que se amplia y factor de la ampliacion.
const ZOOM_WIDTH: int = 320
const ZOOM_HEIGHT: int = 40
const ZOOM: int = 3
const SEPARATOR: int = 4
const SEPARATOR_COLOR: Color = Color(1, 0, 1)
const SETTLE_FRAMES: int = 45
const STATE_FRAMES: int = 2
## Fraccion de la pulsacion larga que se captura (anillo de carga).
const CHARGE_FRACTION: float = 0.55
const PHYSICS_HZ: float = 60.0
## Cuadros tras activar el Debug antes de capturar (transicion completa).
const DEBUG_FRAMES: int = 30
## [nombre, sync_rate, debug_energy, attention_points, terminar animaciones]
const STATES: Array[Array] = [
	["100 %", 100.0, 100.0, 0, true],
	["50 %", 50.0, 50.0, 3, true],
	["15 % alerta", 15.0, 40.0, 7, true],
	["rastro de dano 100 -> 60", 60.0, 100.0, 7, false],
	["energia 0", 60.0, 0.0, 0, true],
	["12 puntos", 100.0, 100.0, 12, true],
]
## Indice del estado que se guarda tambien como cuadro completo.
const FULL_FRAME_STATE: int = 2


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	var level: Node = (load(WORLD1) as PackedScene).instantiate()
	root.add_child(level)
	# Sin tipos Hud ni GameState: en un script de -s los autoloads no son
	# identificadores y tiparlo obligaria a compilar hud.gd antes de tiempo.
	var hud: Node = (load(HUD) as PackedScene).instantiate()
	level.add_child(hud)
	var game_state: Node = root.get_node(^"GameState")
	for i: int in SETTLE_FRAMES:
		await physics_frame
	var strips: Array[Image] = []
	var fulls: Array[Image] = []
	for i: int in STATES.size():
		var state: Array = STATES[i]
		if not state[4]:
			# Rastro: parte de 100 y cae al valor del estado sin terminar la animacion.
			game_state.set(&"sync_rate", 100.0)
			hud.call(&"finish_animations")
			await process_frame
		game_state.set(&"sync_rate", state[1])
		game_state.set(&"debug_energy", state[2])
		game_state.set(&"attention_points", state[3])
		if state[4]:
			hud.call(&"finish_animations")
		var shot: Image = await _shot()
		strips.append(shot.get_region(Rect2i(0, 0, shot.get_width(), STRIP_HEIGHT)))
		if i == FULL_FRAME_STATE:
			fulls.append(shot)
		print("render_hud_states: %s" % state[0])
	# Anillo de carga al 55 %: pulsacion larga real (el Debug esta desbloqueado en la escena).
	game_state.set(&"sync_rate", 100.0)
	game_state.set(&"debug_energy", 100.0)
	hud.call(&"finish_animations")
	var hold_s: float = root.get_node(^"DebugMode").get(&"config").get(&"activation_hold_s")
	Input.action_press(ACTION_DEBUG)
	for i: int in roundi(hold_s * CHARGE_FRACTION * PHYSICS_HZ):
		await physics_frame
	var charge_shot: Image = await _shot()
	strips.append(charge_shot.get_region(Rect2i(0, 0, charge_shot.get_width(), STRIP_HEIGHT)))
	print("render_hud_states: anillo de carga %.2f" % hud.call(&"get_activation_progress"))
	# Termina la pulsacion: Debug activo (tinte y vineta por debajo del HUD).
	for i: int in roundi(hold_s * (1.0 - CHARGE_FRACTION) * PHYSICS_HZ) + DEBUG_FRAMES:
		await physics_frame
	Input.action_release(ACTION_DEBUG)
	var debug_shot: Image = await _shot()
	strips.append(debug_shot.get_region(Rect2i(0, 0, debug_shot.get_width(), STRIP_HEIGHT)))
	fulls.append(debug_shot)
	print("render_hud_states: Debug activo (%s)" % root.get_node(^"DebugMode").call(&"is_active"))
	_save_sheet(strips, fulls, out_path)
	_save_zoom(strips, out_path.get_basename() + ZOOM_SUFFIX)
	quit(0)


func _shot() -> Image:
	for f: int in STATE_FRAMES:
		await process_frame
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save_sheet(strips: Array[Image], fulls: Array[Image], out_path: String) -> void:
	var width: int = fulls[0].get_width()
	var height: int = strips.size() * (STRIP_HEIGHT + SEPARATOR)
	for full: Image in fulls:
		height += full.get_height() + SEPARATOR
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(SEPARATOR_COLOR)
	var y: int = 0
	for strip: Image in strips:
		sheet.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i(0, y))
		y += STRIP_HEIGHT + SEPARATOR
	for full: Image in fulls:
		sheet.blit_rect(full, Rect2i(Vector2i.ZERO, full.get_size()), Vector2i(0, y))
		y += full.get_height() + SEPARATOR
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err: Error = sheet.save_png(out_path)
	print("render_hud_states: %d franjas -> %s (%s)" % [strips.size(), out_path, error_string(err)])


func _save_zoom(strips: Array[Image], out_path: String) -> void:
	var sheet := Image.create_empty(ZOOM_WIDTH, strips.size() * (ZOOM_HEIGHT + SEPARATOR), false, Image.FORMAT_RGBA8)
	sheet.fill(SEPARATOR_COLOR)
	var y: int = 0
	for strip: Image in strips:
		var corner: Rect2i = Rect2i(strip.get_width() - ZOOM_WIDTH, 0, ZOOM_WIDTH, ZOOM_HEIGHT)
		sheet.blit_rect(strip, corner, Vector2i(0, y))
		y += ZOOM_HEIGHT + SEPARATOR
	sheet.resize(sheet.get_width() * ZOOM, sheet.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	var err: Error = sheet.save_png(out_path)
	print("render_hud_states: ampliacion x%d -> %s (%s)" % [ZOOM, out_path, error_string(err)])
