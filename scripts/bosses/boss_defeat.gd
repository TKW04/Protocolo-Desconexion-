## Secuencia tras el golpe final de un jefe (paso 10 de
## docs/propuesta-jefe-alerta-mayor.md §2.8 y §3.3, 2026-10-21). SIN ROLLBACK
## (decision 1): no toca la vuelta ni el guardado mas alla de lo de cualquier
## final de nivel. La crea el jefe (BossDefeat.begin) como hija del nivel:
## 1. FREEZE: congelacion breve (freeze_s reales): pausa el arbol si no lo
##    estaba (solo quien pausa quita la pausa; este nodo procesa siempre).
## 2. DISARM: el jefe se desarma en pixeles (BossDefeatTarget.play_disarm, que
##    crea un PixelBurst) durante disarm_s del mundo.
## 3. REWARD: BossReward.grant (capa del acceso y las inferiores que falten, SIN
##    GUARDAR) y el panel de la recompensa con la linea del sistema del jefe;
##    en una revancha (nada nuevo) no sale el panel.
## 4. LINE: la linea de derrota del jefe (importante: pausa) y se espera a que
##    se cierre (el jefe la dice: say_line / line_done).
## 5. EXIT: con Isak en el suelo (o tras exit_wait_max_s), vortice de salida
##    (WarpVortex.depart) y, al terminar, EventBus.level_completed(<nivel>):
##    LevelRunner apunta el nivel en completed_levels y vuelve al hub.
## Valores en la seccion defeat de data/bosses/<id>.json. advance(dt) para las
## pruebas (auto_process falso).
class_name BossDefeat
extends Node

enum Stage { FREEZE, DISARM, REWARD, LINE, EXIT, DONE }

## Pruebas: falso = la congelacion no pausa el arbol.
static var freeze_tree: bool = true

signal stage_changed(stage: Stage)
## Isak se fue por el vortice y se emitio level_completed.
signal finished(level_id: String)

var auto_process: bool = true
## El jefe (AlertMajor u otro BossBase con play_disarm / say_line).
var boss: BossBase
var level_id: String = ""

var _cfg: Dictionary = {}
var _stage: Stage = Stage.FREEZE
var _t: float = 0.0
var _paused_by_me: bool = false
var _reward: BossReward
var _granted: Array[StringName] = []
var _line_done: bool = false
var _vortex: WarpVortex


## Empieza la secuencia de `boss_node` bajo `level` (nodo del nivel).
static func begin(boss_node: BossBase, level: Node, id: String) -> BossDefeat:
	var seq := BossDefeat.new()
	seq.name = "BossDefeat"
	seq.boss = boss_node
	seq.level_id = id
	level.add_child(seq)
	return seq


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(PauseMenu.BLOCKER_GROUP)
	_cfg = boss.get_config().get("defeat", {}) if boss != null else {}
	_enter(Stage.FREEZE)


func _exit_tree() -> void:
	_release_pause()


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)


# --- Consultas ---

func get_stage() -> Stage:
	return _stage


func get_reward() -> BossReward:
	return _reward if _reward != null and is_instance_valid(_reward) else null


## Capas del recuerdo obtenidas al vencer (vacia en una revancha).
func get_granted() -> Array[StringName]:
	return _granted


func is_done() -> bool:
	return _stage == Stage.DONE


func blocks_pause_menu() -> bool:
	return _stage != Stage.DONE


# --- Avance ---

## Avanza `dt` segundos reales (la congelacion y las esperas; el desarme lleva
## su propio tiempo del mundo).
func advance(dt: float) -> void:
	_t += dt
	match _stage:
		Stage.FREEZE:
			if _t >= float(_cfg.get("freeze_s", 0.3)):
				_release_pause()
				_enter(Stage.DISARM)
		Stage.DISARM:
			if get_tree().paused:
				return
			if _t >= float(_cfg.get("disarm_s", 1.6)):
				_enter(Stage.REWARD)
		Stage.REWARD:
			if get_reward() == null:
				_enter(Stage.LINE)
		Stage.LINE:
			if _line_done:
				_enter(Stage.EXIT)
		Stage.EXIT:
			if _vortex == null:
				var isak: Isak = LevelLookup.find_isak(self)
				if isak == null:
					_finish()
				elif isak.is_on_floor() or _t >= float(_cfg.get("exit_wait_max_s", 2.0)):
					_vortex = WarpVortex.depart(isak, isak.get_parent())
					_vortex.finished.connect(_finish)


func _enter(stage: Stage) -> void:
	_stage = stage
	_t = 0.0
	match stage:
		Stage.FREEZE:
			if freeze_tree and is_inside_tree() and not get_tree().paused:
				get_tree().paused = true
				_paused_by_me = true
		Stage.DISARM:
			if boss != null and boss.has_method(&"play_disarm"):
				boss.call(&"play_disarm")
		Stage.REWARD:
			var world: int = int(_cfg.get("memory_world", boss.get_config().get("world", 1) if boss != null else 1))
			var lap: int = GameState.lap if boss == null or boss.lap_override <= 0 else boss.lap_override
			_granted = BossReward.grant(world, lap)
			if not _granted.is_empty():
				var line: String = String((boss.get_config().get("texts", {}) as Dictionary).get("final_system", "")) \
						if boss != null else ""
				_reward = BossReward.show_for(BossReward.layer_id(world, lap), get_parent(), line)
		Stage.LINE:
			_line_done = true
			if boss != null and boss.has_method(&"say_line"):
				var text: String = String((boss.get_config().get("texts", {}) as Dictionary).get("defeat", ""))
				if not text.is_empty():
					_line_done = false
					boss.call(&"say_line", text, true, func() -> void: _line_done = true)
	stage_changed.emit(stage)


func _finish() -> void:
	if _stage == Stage.DONE:
		return
	_stage = Stage.DONE
	stage_changed.emit(_stage)
	finished.emit(level_id)
	if not level_id.is_empty():
		EventBus.level_completed.emit(level_id)


func _release_pause() -> void:
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
	_paused_by_me = false
