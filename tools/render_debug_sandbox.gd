## Captura de scenes/levels/debug_sandbox.tscn a 1:1 (1280x720) para juzgar la
## legibilidad del Debug Mode: arriba sin Debug, en medio con Debug (tinte,
## vineta, contorno de las plataformas ocultas, HUD sin tenir) y abajo con el
## contorno de alto contraste. Isak se coloca sobre la segunda plataforma
## oculta para que el camino quede a la vista.
## Necesita ventana (no funciona con --headless: no hay imagen que leer).
## Uso: Godot --path . -s tools/render_debug_sandbox.gd [-- salida.png]
extends SceneTree

const SANDBOX: String = "res://scenes/levels/debug_sandbox.tscn"
const DEFAULT_OUT: String = "user://debug_sandbox_preview.png"
const ACTION_DEBUG: StringName = &"debug"
const SEPARATOR: int = 4
const SEPARATOR_COLOR: Color = Color(1, 0, 1)
const SETTLE_FRAMES: int = 45
## Cuadros con el Debug mantenido antes de capturar (transicion completa).
const DEBUG_FRAMES: int = 30
## Isak sobre Hidden2 (superficie en y = 384) mirando a la derecha.
const ISAK_SHOT_POSITION: Vector2 = Vector2(704, 384)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	var sandbox: Node = (load(SANDBOX) as PackedScene).instantiate()
	root.add_child(sandbox)
	# Sin tipos de autoload: en un script de -s no son identificadores.
	var game_state: Node = root.get_node(^"GameState")
	var isak: Node2D = sandbox.get_node(^"Isak")
	for i: int in SETTLE_FRAMES:
		await physics_frame
	var shots: Array[Image] = []
	shots.append(await _shot())
	Input.action_press(ACTION_DEBUG)
	for i: int in DEBUG_FRAMES:
		await physics_frame
	# Con el Debug activo la plataforma oculta es solida: Isak se queda encima.
	isak.global_position = ISAK_SHOT_POSITION
	isak.set(&"velocity", Vector2.ZERO)
	for i: int in DEBUG_FRAMES:
		await physics_frame
	shots.append(await _shot())
	game_state.set(&"debug_high_contrast_outline", true)
	shots.append(await _shot())
	Input.action_release(ACTION_DEBUG)
	var width: int = shots[0].get_width()
	var height: int = shots.size() * shots[0].get_height() + (shots.size() - 1) * SEPARATOR
	var sheet: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(SEPARATOR_COLOR)
	var y: int = 0
	for shot: Image in shots:
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(0, y))
		y += shot.get_height() + SEPARATOR
	var err: Error = sheet.save_png(out_path)
	print("render_debug_sandbox: %s (%s)" % [out_path, error_string(err)])
	quit(0 if err == OK else 1)


func _shot() -> Image:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image
