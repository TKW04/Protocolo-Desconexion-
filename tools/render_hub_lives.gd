## Capturas de las vidas en el HUD del hub (2026-10-31): Isak entra al 1-1 con
## 5 vidas, pierde 2, completa el nivel y llega al hub con 3 (las perdidas se
## conservan); el HUD del hub las muestra junto al Modo Avion. Captura tambien
## con Isak en la repisa de M1 (Eco mas cerca del HUD) para ver que no lo tapa.
## Con ventana: $GODOT --fixed-fps 60 --path . -s tools/render_hub_lives.gd -- <carpeta>
## Guardado de herramientas propio (nunca user://save.json).
extends SceneTree

const SHOTS_SCRIPT: String = "res://tools/hub_lives_shots.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var shots: Node = Node.new()
	shots.set_script(load(SHOTS_SCRIPT))
	shots.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(shots)
