## Detecta el ultimo dispositivo usado (2026-10-30, peticion del usuario tras el
## 5-2: «¿se puede hacer que detecte el control o el teclado?»). Autoload: mira
## cada entrada sin consumirla y se la pasa a ControlBindings.note_input
## (teclado o raton frente a mando; tambien la familia del mando por su nombre),
## que emite EventBus.input_device_changed si cambia. Lo usan Ajustes >
## Controles (filas, titulo y ayuda en vivo) y los textos con teclas
## ({key:<accion>} de los avisos, {tecla:<accion>} de las ayudas Q). Procesa
## siempre (tambien con el arbol en pausa: el menu de pausa).
extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	ControlBindings.note_input(event)
