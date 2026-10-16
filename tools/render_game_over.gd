## Capturas a 1:1 (1280x720) de las vidas, el game over, la papelera y las
## carpetas bloqueadas (docs/propuesta-asistentes-y-vidas.md §5, pasos 11 y 12
## de §10). La logica va en tools/game_over_shots.gd (los scripts -s no pueden
## nombrar autoloads ni clases que los usen al compilar). Usa su propio
## guardado (user://render_game_over_save.json, se borra al terminar), nunca el
## del jugador.
##   01_hud_vidas.png             1-1 tras la primera llegada al hub: tres mini telefonos junto a la senal
##   02_vida_perdida.png          tras la primera muerte: un telefono se apaga (parpadeo)
##   02b_reaparicion.png          reaparece con dos vidas
##   03_game_over_eco.png         tercera muerte: hub, Eco cuenta el rollback (primer game over)
##   03b_game_over_papelera.png   ultima linea: lo guardado esta en la papelera
##   04_papelera_parpadea.png     la papelera parpadea y se mueve (columna 10)
##   05_carpeta_bloqueada.png     Isak en la repisa de M1: «Recupera tus archivos de la papelera»
##   05b_notas_no_guarda.png      Notas: «Primero recupera tus archivos de la papelera»
##   06_recuperando.png           Isak junto a la papelera: se vacia (todo recuperado de golpe)
##   07_tras_recuperar.png        papelera vacia; la carpeta vuelve a mostrar la tecla del pulso
##   08_nada_guardado.png         game over sin ninguna copia: «no había nada guardado»
##   08b_papelera_vacia.png       la papelera activada y vacia; carpetas abiertas
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_game_over.gd [-- carpeta_salida]
extends SceneTree

const SHOTS_SCRIPT: String = "res://tools/game_over_shots.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var shots: Node = Node.new()
	shots.set_script(load(SHOTS_SCRIPT))
	shots.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(shots)
