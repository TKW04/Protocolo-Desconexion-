## Tunel de alarmas (tipo `alarm_tunnel` del catalogo del Mundo 1; Tramo 4
## «Alarmas» del 1-3, docs/propuesta-1-3.md §3.5 y §5.5; paso 6 de §7).
##
## Un metronomo (RhythmZone) cuyo compas NO lo marca el tiempo sino la
## POSICION: `stages` = [{x_from, x_to, cycle_s}] (columnas absolutas); manda
## el tramo de la columna mas avanzada que ha pisado Isak dentro de la zona (no
## retrocede: volver atras no lo hace mas lento). Sin bucle. Antes de entrar,
## el primer tramo. Las campanas (alarm_bell) y los banners con `rhythm` lo
## siguen. Tiempo del mundo; al reaparecer Isak vuelve al principio.
class_name AlarmTunnel
extends RhythmZone

## Tramos por posicion: [{x_from, x_to, cycle_s}].
@export var stages: Array = []

var _max_col: int = -1


# --- Consultas ---

func get_cycle_s() -> float:
	var stage: Dictionary = get_stage()
	if stage.is_empty():
		return super.get_cycle_s()
	return maxf(float(stage.get("cycle_s", 1.0)), 0.05)


## Indice del tramo que manda ahora (el de la columna mas avanzada).
func get_step_index() -> int:
	var index: int = 0
	for i: int in stages.size():
		var s: Dictionary = stages[i]
		if _max_col >= int(s.get("x_from", 0)):
			index = i
	return index


func get_stage() -> Dictionary:
	if stages.is_empty():
		return {}
	return stages[get_step_index()]


## Columna mas avanzada que ha pisado Isak dentro de la zona (-1: aun no).
func get_max_column() -> int:
	return _max_col


# --- Interno ---

func _update_progress() -> void:
	var isak: Isak = _find_isak()
	if isak == null or isak.is_dead():
		return
	var feet: Vector2 = isak.global_position - Vector2(0.0, 1.0)
	if not get_zone_rect().has_point(feet):
		return
	var t: float = World1ObjectsConfig.tile_size()
	var parent_origin: Vector2 = global_position - position
	var col: int = floori((feet.x - parent_origin.x) / t)
	if col > _max_col:
		_max_col = col
		_check_tempo()


func _reset_progress() -> void:
	_max_col = -1
