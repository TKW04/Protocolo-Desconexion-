## Capturas a 1:1 (1280x720) de la escena generada del 1-1 ampliado (scenes/levels/1-1.tscn):
##   01_inicio.png            Isak tras caer desde P (Tramo 1)
##   01b_burbuja_t1a.png      la primera Burbuja (lenta) bajo la plataforma de una via del Tramo 1
##   01c_burbuja_t1b.png      la segunda Burbuja, antes del receptor del 2a
##   02_puente_retraido.png   Isak junto al receptor del 2a, puente sin activar
##   03_puente_activo.png     tras el pulso: puente extendido
##   04_meseta_2b.png         la meseta del 2b con el receptor y los dos puentes
##   05_secreto_a.png         la repisa alta del secreto A (1 punto)
##   05b_burbuja_2c.png       la Burbuja rapida del 2c
##   06_burbuja_techo.png     la Burbuja bajo el techo bajo (3a)
##   07_secreto_b_techo.png   encima del techo de 3a (secreto B) y el nicho del Pulso amplio (power bank)
##   08_checkpoint.png        el punto de sincronizacion a mitad del mapa
##   09_sala_laser.png        la sala del laser (3b) desde el escalon: receptor, puentes sin activar, pop-up
##   09b_sala_puentes.png     con los dos puentes extendidos, Isak en la repisa flotante junto al receptor 2
##   09c_tunel_laser.png      pop-up cerrado: Isak entrando al tunel con el objeto del laser
##   09d_laser_recogido.png   Isak recoge el laser (linea de Eco; el aviso del control solo sale con
##                            el flujo de juego: tools/render_ability_notices.gd)
##   10_cargador.png          el cargador 1 tras la sala del laser
##   10a_disparo_laser.png    Isak dispara el laser a la primera Burbuja del 3c
##   10_dos_burbujas.png      las dos Burbujas en abierto y la repisa entre ellas (3c)
##   10b_repisa_3c.png        Isak en la repisa del 3c (con el punto de la Burbuja escalon)
##   11_popup.png             Isak pegado al pop-up del 4a (boton a la altura del celular)
##   12_popup_escalon.png     el pop-up sobre el escalon (4b)
##   12b_burbuja_4b.png       la Burbuja en abierto del 4b
##   13_popup_puente.png      el pop-up al final del puente (4c)
##   14_secreto_c.png         la repisa del pop-up alto (secreto C)
##   15_cierre.png            el cargador 2 y la Burbuja con vida 3 del Cierre
##   15_puerta.png            la puerta "Marcar como leído"
##   16_final.png             el final del mapa con la pared con glitch
## Mueve a Isak teletransportandolo (no es una partida). Necesita ventana (no
## funciona con --headless); con --write-movie guarda tambien todos los cuadros.
## Uso: Godot --path . -s tools/render_level_1_1.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/1-1.tscn"
const DEFAULT_OUT: String = "user://level_1_1"
const SETTLE_FRAMES: int = 60
const TILE: float = 64.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Las lineas importantes de Eco pausarian el nivel esperando al jugador:
	# aqui se muestran y se cierran solas, como las normales.
	(load("res://scripts/ui/eco_text_box.gd") as GDScript).set(&"pause_important", false)
	# Partida que ya paso por el encuentro con Eco (2026-10-16): Eco conocido y
	# el pulso obtenido (el 1-1 empieza sin pulso; el encuentro se captura con
	# tools/render_eco_encounter.gd).
	var game_state: Node = root.get_node(^"GameState")
	game_state.call(&"meet_ally", &"eco")
	game_state.call(&"mark_notice_seen", &"pulse")
	game_state.call(&"obtain_ability", &"pulse")
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	for i: int in 90:
		await physics_frame
	await _save(out_dir, "01_inicio.png")
	for shot: Array in [["01b_burbuja_t1a.png", 27.0, 7], ["01c_burbuja_t1b.png", 47.0, 7]]:
		await _teleport(isak, float(shot[1]), int(shot[2]))
		await _save(out_dir, String(shot[0]))
	await _teleport(isak, 54.5, 9)
	await _save(out_dir, "02_puente_retraido.png")
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	for i: int in 50:
		await physics_frame
	var bridge: Node = level.get_node(^"Objects/puente_1")
	print("render_level_1_1: puente extendido=%s" % bridge.call(&"is_extended"))
	await _save(out_dir, "03_puente_activo.png")
	for shot: Array in [
			["04_meseta_2b.png", 73.0, 8], ["05_secreto_a.png", 99.0, 4], ["05b_burbuja_2c.png", 99.0, 9],
			["06_burbuja_techo.png", 126.0, 9], ["07_secreto_b_techo.png", 131.0, 4], ["08_checkpoint.png", 148.0, 9],
			["09_sala_laser.png", 156.0, 7]]:
		await _teleport(isak, float(shot[1]), int(shot[2]))
		await _save(out_dir, String(shot[0]))
	# Sala del laser: los dos receptores activados (puentes extendidos) y luego el pop-up cerrado.
	for receiver: String in ["receiver_153_9", "receiver_164_5"]:
		level.get_node(NodePath("Objects/" + receiver)).call(&"activate")
	await _teleport(isak, 163.5, 5)
	await _save(out_dir, "09b_sala_puentes.png")
	level.get_node(^"Objects/popup_laser").call(&"close")
	await _teleport(isak, 171.0, 5)
	await _save(out_dir, "09c_tunel_laser.png")
	await _teleport(isak, 173.0, 5, 20)
	await _save(out_dir, "09d_laser_recogido.png")
	print("render_level_1_1: laser obtenido=%s" % root.get_node(^"GameState").call(&"is_ability_unlocked", &"laser"))
	await _teleport(isak, 177.0, 9)
	await _save(out_dir, "10_cargador.png")
	Input.action_press(&"laser")
	await physics_frame
	Input.action_release(&"laser")
	for i: int in 10:
		await physics_frame
	await _save(out_dir, "10a_disparo_laser.png")
	for shot: Array in [
			["10_dos_burbujas.png", 186.0, 9], ["10b_repisa_3c.png", 186.0, 6], ["11_popup.png", 214.25, 9],
			["12_popup_escalon.png", 243.25, 8], ["12b_burbuja_4b.png", 226.0, 9], ["13_popup_puente.png", 251.0, 9],
			["14_secreto_c.png", 267.25, 5], ["15_cierre.png", 278.0, 9], ["15_puerta.png", 286.0, 9],
			["16_final.png", 296.0, 9]]:
		await _teleport(isak, float(shot[1]), int(shot[2]))
		await _save(out_dir, String(shot[0]))
	level.queue_free()
	await process_frame
	quit(0)


func _teleport(isak: Node2D, col: float, row: int, frames: int = SETTLE_FRAMES) -> void:
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE - 1.0)
	isak.set(&"velocity", Vector2.ZERO)
	isak.set(&"facing", 1.0)
	for i: int in frames:
		await physics_frame


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_level_1_1: %s (%s)" % [path, error_string(err)])
