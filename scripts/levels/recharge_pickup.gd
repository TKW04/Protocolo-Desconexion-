## Recarga que suelta un enemigo o jefe al ser eliminado (decision 2026-10-14):
## al tocarla Isak suma `amount` de energia de Debug (el sobrante con la barra
## llena carga el power bank, GameState.add_debug_energy) o de Sync Rate
## (GameState.heal_sync). Comportamiento en data/recharge_pickup.json; cuanto
## suelta cada enemigo, en su JSON (drops). Aspecto: sprite energy_drop_idle o
## sync_drop_idle segun `kind` (EnergySprite, docs/estilizacion-energia.md),
## centrado en el nodo; la flotacion la hace el codigo.
## Uso: RechargePickup.spawn_drops(padre, posicion_pies, drops).
class_name RechargePickup
extends Area2D

const DATA_PATH: String = "res://data/recharge_pickup.json"
const KIND_ENERGY: StringName = &"debug_energy"
const KIND_SYNC: StringName = &"sync_rate"
const KINDS: Array[StringName] = [KIND_ENERGY, KIND_SYNC]
const GROUP: StringName = &"recharge_pickup"
## Capa de Isak (scenes/player/isak.tscn, collision_layer 2).
const PLAYER_LAYER: int = 2

signal collected(kind: StringName, amount: float)

@export var kind: StringName = KIND_ENERGY
@export var amount: float = 0.0

static var _data: Dictionary = {}

var _age: float = 0.0
var _taken: bool = false
var _base_y: float = 0.0
var _sprite: EnergySprite


## Crea una recarga por cada tipo de `drops` ({"debug_energy": 25, ...}) con
## cantidad > 0, repartidas en horizontal alrededor de `feet` (coordenadas
## globales de los pies del enemigo), como hijas de `parent`.
static func spawn_drops(parent: Node, feet: Vector2, drops: Dictionary) -> Array[RechargePickup]:
	var out: Array[RechargePickup] = []
	if parent == null:
		return out
	var d: Dictionary = data()
	var kinds: Array[StringName] = []
	for k: StringName in KINDS:
		if float(drops.get(String(k), 0.0)) > 0.0:
			kinds.append(k)
	var spread: float = float(d.get("spread_px", 40.0))
	for i: int in kinds.size():
		var pickup := RechargePickup.new()
		pickup.kind = kinds[i]
		pickup.amount = float(drops[String(kinds[i])])
		pickup.name = "Recharge_%s" % kinds[i]
		HelpCatalog.tag(pickup, help_id_for(kinds[i]))
		var dx: float = (float(i) - (kinds.size() - 1) * 0.5) * spread
		parent.add_child(pickup)
		pickup.global_position = feet + Vector2(dx, float(d.get("spawn_offset_y_px", -42.0)))
		pickup._base_y = pickup.position.y
		out.append(pickup)
	return out


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("RechargePickup: no se pudo leer '%s'." % DATA_PATH)
	return _data


## Tipo de la ayuda con Q de una recarga de `kind` (kinds.<kind>.help_id de
## data/recharge_pickup.json; &"" si no tiene).
static func help_id_for(kind: StringName) -> StringName:
	var kinds: Variant = data().get("kinds", {})
	if not kinds is Dictionary or not (kinds as Dictionary).get(String(kind)) is Dictionary:
		return &""
	return StringName(String((kinds[String(kind)] as Dictionary).get("help_id", "")))


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(data().get("radius_px", 18.0))
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var anim: StringName = &"sync_drop_idle" if kind == KIND_SYNC else &"energy_drop_idle"
	_sprite = EnergySprite.attach(self, anim, Vector2.ZERO, true)
	if _base_y == 0.0:
		_base_y = position.y


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza la animacion `dt` segundos del mundo e intenta recoger si ya puede.
func advance(dt: float) -> void:
	if _taken:
		return
	_age += dt
	var d: Dictionary = data()
	var rise_s: float = float(d.get("rise_s", 0.25))
	var rise: float = float(d.get("rise_px", 24.0)) * (minf(_age / rise_s, 1.0) if rise_s > 0.0 else 1.0)
	var bob: float = sin(_age * TAU * float(d.get("bob_hz", 1.5))) * float(d.get("bob_px", 4.0))
	position.y = _base_y - rise + bob
	if is_armed():
		for body: Node2D in get_overlapping_bodies():
			if body is Isak:
				collect()
				return
	if _sprite != null:
		_sprite.advance(dt)


func is_armed() -> bool:
	return _age >= float(data().get("arm_delay_s", 0.3))


func is_taken() -> bool:
	return _taken


## Aplica la recarga (una sola vez) y se libera.
func collect() -> bool:
	if _taken:
		return false
	_taken = true
	match kind:
		KIND_ENERGY:
			GameState.add_debug_energy(amount)
		KIND_SYNC:
			GameState.heal_sync(amount)
	collected.emit(kind, amount)
	EventBus.recharge_collected.emit(kind, amount)
	queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is Isak and is_armed():
		collect()
