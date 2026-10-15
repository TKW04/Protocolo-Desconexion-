## Punto de sincronizacion (tipo `C` del level-builder), version minima del
## paso 15: solo marca su id y la posicion de reaparicion (pies de Isak, abajo
## en el centro de la celda C). Activarlo, reponer el Sync Rate y reaparecer
## aqui (V2) es el paso 16.
class_name Checkpoint
extends Marker2D

const GROUP: StringName = &"checkpoint"

## Id de la lista `checkpoints` del nivel.
@export var checkpoint_id: StringName = &""


func _ready() -> void:
	add_to_group(GROUP)


## Posicion de reaparicion (pies de Isak) en coordenadas globales.
func get_spawn_position() -> Vector2:
	return global_position
