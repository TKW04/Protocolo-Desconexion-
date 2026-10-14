## Capturas a 1:1 (1280x720) de scenes/levels/alert_bubble_test.tscn:
##   1_patrulla.png        Isak se acerca a la Burbuja que patrulla
##   2_pulso_aturde.png    justo despues del pulso (J): onda y Burbuja aturdida
##   3_isak_encima.png     Isak de pie sobre la Burbuja aturdida (plataforma)
##   4_anticipacion.png    el aviso de fin de aturdimiento (cuadro con brillo)
##   5_pop.png             Isak cae sobre la Burbuja aturdida: revienta y rebota
##   6_debug.png           Debug activo (mundo x0,5) con la Burbuja patrullando
## Necesita ventana (no funciona con --headless). Se puede lanzar con
## --write-movie para guardar tambien todos los cuadros.
## Uso: Godot --path . -s tools/render_alert_bubble.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/alert_bubble_test.tscn"
const DEFAULT_OUT: String = "user://alert_bubble"
const SETTLE_FRAMES: int = 30
## Distancia horizontal de Isak a la Burbuja al disparar el pulso (px).
const PULSE_DISTANCE: float = 110.0
const HOLD_DEBUG_FRAMES: int = 70


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: CharacterBody2D = level.get_node(^"Isak")
	var bubble: CharacterBody2D = level.get_node(^"AlertBubble")
	await _frames(SETTLE_FRAMES)
	await _place(isak, Vector2(bubble.global_position.x - 240.0, 575.0))
	Input.action_press(&"move_right")
	for i: int in 120:
		await physics_frame
		if bubble.global_position.x - isak.global_position.x <= PULSE_DISTANCE + 60.0:
			break
	await _save(out_dir, "1_patrulla.png")
	Input.action_release(&"move_right")
	await _place(isak, Vector2(bubble.global_position.x - PULSE_DISTANCE, 575.0))
	isak.set(&"facing", 1.0)
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	await _frames(5)
	print("render_alert_bubble: estado tras el pulso = %s" % bubble.call(&"get_state"))
	await _save(out_dir, "2_pulso_aturde.png")
	await _frames(20)
	await _place(isak, Vector2(bubble.global_position.x, float(bubble.call(&"get_platform_top_y")) - 2.0))
	await _frames(10)
	print("render_alert_bubble: Isak en el suelo = %s, y = %.0f, canto = %.0f" % [isak.is_on_floor(), isak.global_position.y, float(bubble.call(&"get_platform_top_y"))])
	await _save(out_dir, "3_isak_encima.png")
	for i: int in 400:
		await physics_frame
		if bubble.call(&"get_state") == &"anticipate" and (bubble.get_node(^"AnimatedSprite2D") as AnimatedSprite2D).frame >= 6:
			break
	await _save(out_dir, "4_anticipacion.png")
	await _place(isak, Vector2(bubble.global_position.x - 300.0, 575.0))
	await _frames(70)
	await _place(isak, Vector2(bubble.global_position.x - PULSE_DISTANCE, 575.0))
	isak.set(&"facing", 1.0)
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	await _frames(20)
	await _place(isak, Vector2(bubble.global_position.x, float(bubble.call(&"get_platform_top_y")) - 160.0))
	for i: int in 120:
		await physics_frame
		if bubble.call(&"get_state") == &"popped":
			break
	await _frames(2)
	print("render_alert_bubble: estado = %s, vy de Isak = %.0f" % [bubble.call(&"get_state"), isak.velocity.y])
	await _save(out_dir, "5_pop.png")
	await _frames(240)
	var next: Node = level.get_children().filter(func(n: Node) -> bool: return n.has_method(&"get_platform_top_y")).back()
	await _place(isak, Vector2((next as Node2D).global_position.x - 300.0, 575.0))
	Input.action_press(&"debug")
	await _frames(HOLD_DEBUG_FRAMES)
	Input.action_release(&"debug")
	await _frames(30)
	print("render_alert_bubble: escala del mundo = %.2f" % float(root.get_node(^"GameState").get(&"world_time_scale")))
	await _save(out_dir, "6_debug.png")
	quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _place(isak: CharacterBody2D, pos: Vector2) -> void:
	isak.global_position = pos
	isak.velocity = Vector2.ZERO
	await physics_frame


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_alert_bubble: %s (%s)" % [path, error_string(err)])
