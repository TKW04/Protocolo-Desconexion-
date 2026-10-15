## Vida de un enemigo (decision del usuario 2026-10-15). Interfaz comun para
## todos los enemigos y, en el futuro, los jefes: cada tipo define su `health`
## en su JSON (data/enemies/<tipo>.json; no hay valor estandar) y el nivel
## puede sobrescribirla por instancia con params.health (GeneratedLevel).
## Quien recibe dano (p. ej. el laser, on_laser_hit) llama a take_damage(); el
## enemigo decide que hacer al llegar a 0 (morir y soltar sus `drops`).
class_name EnemyHealth
extends RefCounted

## Ha recibido `amount` de dano y le queda `health_left`.
signal damaged(amount: float, health_left: float)
## La vida ha llegado a 0 (una sola vez hasta reset()).
signal depleted

var max_health: float = 1.0
var health: float = 1.0


func _init(max_value: float = 1.0) -> void:
	reset(max_value)


## Vida llena con un nuevo maximo (> 0).
func reset(max_value: float) -> void:
	max_health = maxf(max_value, 0.0)
	health = max_health


func is_depleted() -> bool:
	return health <= 0.0


## Resta `amount` (> 0). Verdadero si este golpe la deja a 0. Sin efecto si
## ya estaba a 0.
func take_damage(amount: float) -> bool:
	if amount <= 0.0 or is_depleted():
		return false
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, health)
	if is_depleted():
		depleted.emit()
		return true
	return false


## Recargas que suelta un enemigo al morir: seccion `drops` de su JSON
## ({"debug_energy": 25, "sync_rate": 10}; claves "_..." ignoradas). Ver
## RechargePickup.spawn_drops.
static func parse_drops(raw: Variant) -> Dictionary:
	var drops: Dictionary = {}
	if raw is Dictionary:
		for key: Variant in raw:
			var value: Variant = raw[key]
			if not String(key).begins_with("_") and (value is float or value is int):
				drops[String(key)] = float(value)
	return drops
