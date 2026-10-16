## Capturas a 1:1 (1280x720) de la sala de prueba del acertijo «Correo
## certificado» (scenes/levels/correo_test.tscn, pasos 3 y 9 de
## docs/propuesta-1-2.md §10, 2026-10-16), jugando con el Isak real (acciones
## del Input Map):
##   1_lector.png             Isak en el suelo de la sala ante el lector (reposo)
##   2_cable_energizado.png   tras el disparo: cable cian que se vacia (~2 s)
##   3_cable_aviso.png        el cable en el aviso de los ultimos 1,5 s
##   4_receptor_sin_corriente.png  pulso fuera de tiempo: chispa gris
##   5_receptor_activado.png  pulso con corriente: receptor activado, puente saliendo
##   6_puente_extendido.png   Isak al final del puente ante el anuncio
##   7_anuncio_roto.png       el laser rompe el anuncio (a media ruptura)
##   8_popup_cerrado.png      pulso al boton: pop-up cerrado, se ve el chip
##   9_chip_debug.png         el chip del Debug de cerca
##   10_historia_debug.png    linea de historia de Eco al recogerlo (instalacion)
##   11_aviso_debug.png       aviso de control del Debug
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_correo_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/correo_test.tscn"
const DEFAULT_OUT: String = "user://correo_test"
const SETTLE_FRAMES: int = 40
const T: float = 64.0

var _out: String
var _level: Node
var _isak: Node2D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	var game_state: Node = root.get_node(^"GameState")
	game_state.call(&"reset_progress")
	# El aviso del laser (la sala lo da) ya visto: aqui solo interesa el del Debug.
	game_state.call(&"mark_notice_seen", &"laser")
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	var notices: Node = (load("res://scripts/ui/ability_notices.gd") as GDScript).new()
	root.add_child(notices)
	notices.call(&"begin_level")
	_isak = _level.get_node(^"Isak")
	var reader: Node = _level.get_node(^"Objects/lector_1")
	await _place(4.0, 10)
	await _save("1_lector.png")
	await _act(&"laser", 50)
	for i: int in 60:
		await physics_frame
	await _save("2_cable_energizado.png")
	while not bool(reader.call(&"is_warning")):
		await physics_frame
	for i: int in 3:
		await physics_frame
	await _save("3_cable_aviso.png")
	while bool(reader.call(&"is_powered")):
		await physics_frame
	await _place(7.0, 6)
	await _act(&"pulse", 4)
	await _save("4_receptor_sin_corriente.png")
	for i: int in 30:
		await physics_frame
	await _place(4.0, 10)
	await _act(&"laser", 50)
	await _place(7.0, 6)
	await _act(&"pulse", 8)
	await _save("5_receptor_activado.png")
	for i: int in 60:
		await physics_frame
	await _place(13.0, 6)
	await _save("6_puente_extendido.png")
	var ad: Node = _level.get_node(^"Objects/anuncio_buzon")
	await _act(&"laser", 0)
	for i: int in 60:
		if bool(ad.call(&"is_broken")):
			break
		await physics_frame
	for i: int in 5:
		await physics_frame
	await _save("7_anuncio_roto.png")
	for i: int in 40:
		await physics_frame
	await _place(14.0, 6)
	await _act(&"pulse", 60)
	await _save("8_popup_cerrado.png")
	await _place(17.0, 6)
	await _save("9_chip_debug.png")
	_isak.global_position.x = 19.5 * T
	for i: int in 4:
		await process_frame
	var box: Node = _level.get_node(^"EcoTextBox")
	box.call(&"confirm")  # completa el texto (la instalacion sigue en tiempo real)
	await _save("10_historia_debug.png")
	for i: int in 400:
		if String(box.call(&"get_text")).begins_with("Debug"):
			break
		box.call(&"confirm")
		for j: int in 4:
			await process_frame
	for i: int in 90:
		await process_frame
	await _save("11_aviso_debug.png")
	quit(0)


func _place(col: float, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.set(&"velocity", Vector2.ZERO)
	if _isak.has_method(&"snap_camera"):
		_isak.call(&"snap_camera")
	for i: int in SETTLE_FRAMES:
		await physics_frame


## Pulsa `action` un cuadro y espera `frames` cuadros de fisica.
func _act(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	for i: int in frames:
		await physics_frame


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_correo_test: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
