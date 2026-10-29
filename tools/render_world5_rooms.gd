## Capturas de contraste de las salas de prueba del Mundo 5 (paso 9 de docs/propuesta-mundo-5.md §8 y §6.1,
## 2026-10-29): en cada sala (ofertas_test, tienda_test, cajas_test, rebajas_test, combos_test, deseos_test), con el
## Isak real y Eco (la esfera de siempre) siguiendole, dos sitios (la llegada y tras andar a la derecha):
##   <sala>_<n>.png        la captura (1280x720)
##   <sala>_<n>_fondo.png  la misma vista sin Isak ni Eco (lo que hay detras de ellos)
##   <sala>_<n>.json       las cajas de Isak y de Eco en pantalla (x0, y0, x1, y1)
## y una con el Debug activo (<sala>_debug.png, solo para mirarla). tools/measure_world5_contrast.py mide sobre
## las de fondo el cian de Isak y la esfera de Eco frente a lo que tienen detras (>= 3:1).
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_world5_rooms.gd [-- carpeta_salida]
extends SceneTree

const ROOMS: PackedStringArray = ["ofertas_test", "tienda_test", "cajas_test", "rebajas_test", "combos_test",
	"deseos_test"]
const DEFAULT_OUT: String = "user://world5_rooms"
const SETTLE_FRAMES: int = 40
## Caja de Isak respecto a sus pies (96 px visibles en un lienzo de 128, pies abajo-centro).
const ISAK_BOX: Rect2 = Rect2(-32.0, -100.0, 64.0, 100.0)
## Medio lado de la caja de Eco (32 px de arte a x2).
const ECO_HALF: float = 32.0

var _out: String
var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	var state: Node = root.get_node(^"GameState")
	state.call(&"reset_progress")
	state.call(&"meet_ally", &"eco")
	for notice: StringName in [&"debug", &"laser", &"dash", &"combo", &"ground_pound", &"compress"]:
		state.call(&"mark_notice_seen", notice)
	for room: String in ROOMS:
		await _room(room)
	quit(0 if _ok else 1)


func _room(room: String) -> void:
	var level: Node = (load("res://scenes/levels/%s.tscn" % room) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	# Sin nombres de clase (el script de -s compila antes de los autoloads): el script de Eco por ruta.
	var eco: Node2D = (load("res://scripts/levels/eco_companion.gd") as GDScript).call(&"attach", isak, level)
	await _frames(SETTLE_FRAMES)
	await _shot(room, 1, isak, eco)
	Input.action_press(&"move_right")
	await _frames(45)
	Input.action_release(&"move_right")
	await _frames(SETTLE_FRAMES)
	await _shot(room, 2, isak, eco)
	Input.action_press(&"debug")
	await _frames(40)
	await _save("%s_debug.png" % room)
	Input.action_release(&"debug")
	await _frames(10)
	level.queue_free()
	await _frames(5)


func _shot(room: String, n: int, isak: Node2D, eco: Node2D) -> void:
	var xf: Transform2D = isak.get_global_transform_with_canvas()
	var feet: Vector2 = xf.origin
	var ib: Rect2 = Rect2(feet + ISAK_BOX.position, ISAK_BOX.size)
	var ec: Vector2 = eco.get_global_transform_with_canvas().origin
	var eb: Rect2 = Rect2(ec - Vector2(ECO_HALF, ECO_HALF), Vector2(2.0, 2.0) * ECO_HALF)
	if not eco.visible:
		_ok = false
		push_error("render_world5_rooms: Eco no se ve en %s" % room)
	await _save("%s_%d.png" % [room, n])
	# Eco se muestra solo cada cuadro: se para su proceso mientras se captura el fondo.
	var mode: Node.ProcessMode = eco.process_mode
	eco.process_mode = Node.PROCESS_MODE_DISABLED
	isak.visible = false
	eco.visible = false
	await _save("%s_%d_fondo.png" % [room, n])
	isak.visible = true
	eco.visible = true
	eco.process_mode = mode
	var boxes: Dictionary = {"isak": [ib.position.x, ib.position.y, ib.end.x, ib.end.y],
		"eco": [eb.position.x, eb.position.y, eb.end.x, eb.end.y]}
	var fh := FileAccess.open(_out.path_join("%s_%d.json" % [room, n]), FileAccess.WRITE)
	fh.store_string(JSON.stringify(boxes))
	fh.close()


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(_out.path_join(file_name))
	if err != OK:
		_ok = false
	print("render_world5_rooms: %s (%s)" % [file_name, error_string(err)])
