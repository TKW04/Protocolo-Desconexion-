# EventBus (autoload)
# Bus de eventos globales. Solo declara señales; no guarda estado ni contiene lógica.
# Los nodos que necesitan enterarse de cambios globales (HUD, efectos, etc.) se
# conectan aquí en lugar de referenciarse entre sí. GameState emite estas señales
# desde sus setters cuando cambia un valor.
extends Node

@warning_ignore("unused_signal")
signal sync_rate_changed(new_value: float, max_value: float)

@warning_ignore("unused_signal")
signal energy_changed(new_value: float, max_value: float)

@warning_ignore("unused_signal")
signal attention_points_changed(new_value: int)

@warning_ignore("unused_signal")
signal ability_unlock_changed(ability: StringName, unlocked: bool)
