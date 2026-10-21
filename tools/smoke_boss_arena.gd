## Humo de la arena de Alerta Mayor (pasos 5-8 de docs/propuesta-jefe-alerta-mayor.md, 2026-10-21; logica en
## tools/smoke_boss_arena_node.gd): flujo real con --start-level=1-boss, intro cerrada, Isak quieto y un
## jugador minimo que aturde, cierra el escudo y golpea solo en las ventanas. Codigo 0 si llega al golpe final.
## Uso: $GODOT --headless --fixed-fps 60 --path . -s tools/smoke_boss_arena.gd [-- --phase-s 25] [--full]
## --full (paso 13): desde el hub con el 1-3 completado, entra a la arena, vence y vuelve al hub.
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var node: Node = Node.new()
	node.set_script(load("res://tools/smoke_boss_arena_node.gd"))
	node.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(node)
