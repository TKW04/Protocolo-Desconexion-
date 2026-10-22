## Capturas a 1:1 (1280x720) del nivel 1-3 «No molestar» (scenes/levels/1-3.tscn;
## paso 12 de docs/propuesta-1-3.md §7, 2026-10-22) con el flujo real (scenes/main.tscn,
## --start-level 1-3), el HUD y Eco, y el progreso de quien acaba de completar el 1-2
## (pulso, laser y Debug; Eco, Notas y Calc conocidos; sin el dash):
##   01_ajustes.png              sala «Ajustes» al llegar: interruptor «No molestar» apagado
##   02_no_molestar_linea.png    pulso de espaldas al interruptor: linea de historia de Eco
##   03_aviso_deslizar.png       aviso de control «Deslizar: L / B (mando)»
##   04_ajustes_tinte.png        interruptor encendido y el nivel tenido (RoomTint)
##   05_banner_aviso.png         1a: banner obligatorio avisando en su ranura (pasillo de techo bajo)
##   06_banner_dash.png          1a: Isak se desliza a traves del barrido
##   07_banner_despues.png       1a: el banner ya detras de Isak
##   08_ritmo_lento.png          2a: foso con los grupos A/B alternos (compas de 3,2 s)
##   09_ritmo_rapido.png         2b: ola A -> B -> C con el compas rapido (2,0 s), Isak en la B
##   10_excepciones_debug.png    2c: Debug junto a la pared que parece terreno: glitch y disolucion
##   11_sala_excepciones.png     sala «Excepciones»: panel de favoritos y el mensaje de Mama
##   12_cortina_3a.png           3a: Burbuja bajo techo bajo y banner de la cortina
##   13_punto_rojo_dash.png      3b: dash a traves del lanzamiento de un punto rojo
##   14_tunel_4a.png             tunel 4a (2,0 s): onda de campana
##   15_tunel_4b.png             tunel 4b (1,6 s)
##   16_tunel_4c.png             tunel 4c (1,4 s), techo de 2 filas
##   17_secreto_c.png            secreto C: repisa con el power bank vacio a la salida del tunel
##   18_pantalla_bloqueo.png     cierre: terminal «Deslizar para desbloquear»
## Necesita ventana (no funciona con --headless): renderiza en su propio viewport (no hace
## falta permiso de grabacion de pantalla). Guardado y ajustes de herramientas.
## Uso: Godot --path . -s tools/render_level_1_3.gd [-- carpeta_salida]
## La logica va en tools/render_level_1_3_node.gd (los scripts -s no pueden nombrar
## autoloads ni clases que los usen al compilar).
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var node: Node = Node.new()
	node.set_script(load("res://tools/render_level_1_3_node.gd"))
	node.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(node)
