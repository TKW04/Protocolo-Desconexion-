## Captura del HUD en varios estados sobre la arena de pruebas, a 1:1 (1280x720).
## Apila la franja superior de cada estado y debajo un cuadro completo del
## estado de Sync Rate bajo, para juzgar la legibilidad a la resolucion base.
## Necesita ventana (no funciona con --headless: no hay imagen que leer).
## Uso: Godot --path . -s tools/render_hud_states.gd [-- salida.png]
## Por defecto escribe assets/sprites/ui/_hud_states_preview.png.
extends SceneTree

const ARENA: String = "res://scenes/levels/test_arena.tscn"
const DEFAULT_OUT: String = "res://assets/sprites/ui/_hud_states_preview.png"
## Alto de cada franja (barra de 32 px y algo de juego debajo).
const STRIP_HEIGHT: int = 56
const SEPARATOR: int = 4
const SEPARATOR_COLOR: Color = Color(1, 0, 1)
const SETTLE_FRAMES: int = 30
const STATE_FRAMES: int = 2
## [sync_rate, debug_energy, attention_points]
const STATES: Array[Array] = [
	[100.0, 100.0, 0],
	[50.0, 50.0, 3],
	[15.0, 40.0, 7],
	[60.0, 0.0, 0],
	[100.0, 100.0, 12],
]
## Indice del estado que se guarda tambien como cuadro completo.
const FULL_FRAME_STATE: int = 2


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	var arena: Node = (load(ARENA) as PackedScene).instantiate()
	root.add_child(arena)
	# Sin tipos Hud ni GameState: en un script de -s los autoloads no son
	# identificadores y tiparlo obligaria a compilar hud.gd antes de tiempo.
	var hud: Node = arena.get_node(^"Hud")
	var game_state: Node = root.get_node(^"GameState")
	for i: int in SETTLE_FRAMES:
		await process_frame
	var strips: Array[Image] = []
	var full: Image
	for i: int in STATES.size():
		var state: Array = STATES[i]
		game_state.set(&"sync_rate", state[0])
		game_state.set(&"debug_energy", state[1])
		game_state.set(&"attention_points", state[2])
		hud.call(&"finish_animations")
		for f: int in STATE_FRAMES:
			await process_frame
		var shot: Image = root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		strips.append(shot.get_region(Rect2i(0, 0, shot.get_width(), STRIP_HEIGHT)))
		if i == FULL_FRAME_STATE:
			full = shot
	var width: int = full.get_width()
	var height: int = strips.size() * (STRIP_HEIGHT + SEPARATOR) + full.get_height()
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(SEPARATOR_COLOR)
	var y: int = 0
	for strip: Image in strips:
		sheet.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i(0, y))
		y += STRIP_HEIGHT + SEPARATOR
	sheet.blit_rect(full, Rect2i(Vector2i.ZERO, full.get_size()), Vector2i(0, y))
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err: Error = sheet.save_png(out_path)
	print("render_hud_states: %d estados -> %s (%s)" % [STATES.size(), out_path, error_string(err)])
	quit(0 if err == OK else 1)
