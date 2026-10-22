## Capturas a 1:1 (1280x720) del arte final de Alerta Mayor en la arena real
## (paso 16 de docs/propuesta-jefe-alerta-mayor.md, 2026-10-22; AlertMajorBody):
##   01_hover.png       flotando (balanceo)
##   02_inflate.png     inflandose antes de escupir (contorno blanco)
##   03_descend.png     bajando (a mitad: se aplasta)
##   04_window.png      abajo, en la ventana (respira)
##   05_ascend.png      subiendo (a mitad: se estira)
##   06_split.png       fase 3: inflado antes de dividirse
##   07_clones_land.png fase 3: la real y las copias abajo (identicas)
##   07b_encuadre_centro.png fase 3 con Isak en medio: camara centrada entre Isak y las copias (2026-10-22)
##   08_launch_warn.png fase 3: aviso del lanzamiento (se encoge hacia atras)
##   09_lunge.png       fase 3: lanzamiento con la estela
##   10_disarm.png      golpe final: desarme en pixeles del cuadro actual
## Necesita ventana (no funciona con --headless): renderiza el juego en su propio
## viewport (no hace falta permiso de grabacion de pantalla). Guardado de herramientas.
## Uso: Godot --path . -s tools/render_boss_alert_major.gd [-- carpeta_salida]
## La logica va en tools/render_boss_alert_major_node.gd (los scripts -s no pueden
## nombrar autoloads ni clases que los usen al compilar).
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var node: Node = Node.new()
	node.set_script(load("res://tools/render_boss_alert_major_node.gd"))
	node.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(node)
