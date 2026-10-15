## Pinchos (tipo `^` del level-builder): Area de dano que coloca
## tools/build_level.py sobre cada tramo horizontal de pinchos del grid (el tile
## del TileSet no tiene colision). Al tocar a Isak le quita `damage` de Sync Rate
## con su golpe normal (retroceso e invulnerabilidad de 1 s); si sigue dentro,
## vuelve a danar cuando acaba la invulnerabilidad. Valores en data/hazards.json.
class_name SpikeHazard
extends Area2D

const DATA_PATH: String = "res://data/hazards.json"
const GROUP: StringName = &"hazard"

## Dano en puntos de Sync Rate (negativo = el de data/hazards.json).
@export var damage: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	if damage < 0.0:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if data is Dictionary:
			damage = float((data as Dictionary).get("spikes", {}).get("damage", 0.0))
		else:
			push_error("SpikeHazard: no se pudo leer %s" % DATA_PATH)
			damage = 0.0


func _physics_process(_delta: float) -> void:
	for body: Node2D in get_overlapping_bodies():
		if body is Isak:
			hit(body as Isak)


## Golpea a Isak (si no es invulnerable). Devuelve verdadero si le ha danado.
func hit(isak: Isak) -> bool:
	if not isak.take_hit(-isak.facing):
		return false
	GameState.apply_sync_damage(damage)
	return true
