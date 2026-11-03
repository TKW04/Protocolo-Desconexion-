## Capturas a 1:1 (1280x720) de los avisos de habilidad en el cuadro de Eco
## (2026-11-03): cada aviso con teclado y con mando (solo la tecla o solo el
## boton, resaltados en su cajita) y su mini animacion (AbilityDemo) en el
## momento en que la demo pulsa la tecla. Sala ajustes_test con el flujo real
## (scenes/main.tscn) como fondo y guardado de herramientas
## (user://tool_save.json). Necesita ventana (no funciona con --headless).
## Salida: <carpeta>/<nn>_<aviso>_<teclado|mando>.png
## Uso: Godot --fixed-fps 60 --path . -s tools/render_ability_notice_box.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const NOTICES_SCRIPT: String = "res://scripts/ui/ability_notices.gd"
const BINDINGS_SCRIPT: String = "res://scripts/autoload/control_bindings.gd"
const ENCOUNTER_SCRIPT: String = "res://scripts/levels/eco_encounter.gd"
const DEFAULT_OUT: String = "user://ability_notice_box"
## Paso del reloj de la demo al buscar el momento en que pulsa la tecla.
const STEP_S: float = 1.0 / 60.0

var _main: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var notices: GDScript = load(NOTICES_SCRIPT)
	var bindings: GDScript = load(BINDINGS_SCRIPT)
	var data: Dictionary = notices.call(&"load_data")
	var pulse_format: Dictionary = data.duplicate(true)
	pulse_format["abilities"] = {"pulse": (load(ENCOUNTER_SCRIPT) as GDScript).call(&"load_data")["notice"]}
	var items: Array = [
		["pulso", notices.call(&"notice_template", &"pulse", pulse_format)],
		["laser", notices.call(&"notice_template", &"laser", data)],
		["debug", notices.call(&"notice_template", &"debug", data)],
		["deslizar", notices.call(&"notice_template", &"dash", data)],
		["golpe_suelo", notices.call(&"notice_template", &"ground_pound", data)],
		["comprimir", notices.call(&"notice_template", &"compress", data)],
		["ocultarte", notices.call(&"notice_template", &"hide", data)],
	]
	var combo: PackedStringArray = notices.call(&"explain_templates", &"combo", data)
	for i: int in 3:
		items.append(["combo_" + ["embestida", "filo", "sismo"][i], combo[i]])
	_main = (load(SCENE) as PackedScene).instantiate()
	_main.set(&"start_level_id", "ajustes_test")
	root.add_child(_main)
	var isak: Node2D = _main.call(&"get_isak")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and not isak.call(&"is_warping") and int(_main.call(&"get_phase")) == 0:
			break
	await create_timer(2.0).timeout
	var box: Node = _main.call(&"get_level").get_node_or_null(^"EcoTextBox")
	if box == null:
		push_error("render_ability_notice_box: sin EcoTextBox")
		quit(1)
		return
	box.set_process(false)
	var n: int = 0
	var ok: bool = true
	for item: Array in items:
		for device: int in [0, 1]:
			bindings.call(&"set_last_device", device)
			n += 1
			ok = await _shot(box, String(item[1]), out_dir, "%02d_%s_%s.png" % [n, item[0],
				"teclado" if device == 0 else "mando"]) and ok
	bindings.call(&"set_last_device", 0)
	print("render_ability_notice_box: %d capturas en %s (ok=%s)" % [n, out_dir, ok])
	quit(0 if ok else 1)


## Muestra `template` como linea importante, la escribe entera, avanza la demo
## hasta que pulsa la tecla (cajita encendida) y guarda la captura.
func _shot(box: Node, template: String, out_dir: String, file: String) -> bool:
	box.call(&"show_line", template, -1.0, true)
	box.call(&"finish_typing")
	var lit: bool = false
	for i: int in 240:
		box.call(&"advance", STEP_S)
		for cap: Dictionary in box.call(&"get_key_highlights"):
			lit = lit or bool(cap["lit"])
		if lit:
			break
	box.call(&"advance", 0.08)
	# Cuadros ya dibujados (no la textura de un cuadro anterior).
	for i: int in 4:
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var saved: bool = image.save_png(out_dir.path_join(file)) == OK
	box.call(&"confirm")
	box.call(&"advance", 1.0)
	await process_frame
	return saved and lit
