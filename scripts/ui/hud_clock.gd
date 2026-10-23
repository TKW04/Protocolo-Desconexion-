## Reloj del HUD (C8 de docs/preguntas.md; decision 10 de
## docs/propuesta-mundo-2.md §9, aprobada el 2026-10-22; §2.3; paso 8 de su §8).
## Lleva la hora del celular en el hueco ClockSlot, a la izquierda de la barra de
## estado. Seccion clock de data/hud.json.
## - Se ve desde el Mundo `from_world` (2) en los niveles; oculto en el Mundo 1 y
##   en el hub (Hud.enable_hub_mode).
## - Arranca a start_minutes (17:04, un domingo por la tarde) con cada nivel (el HUD
##   es de la escena del nivel) y avanza minutes_per_s minutos por segundo real
##   (1/60: una velocidad que parece normal); se para con el juego en pausa.
## - SALTA skip_minutes (+1 h) de golpe cada vez que Isak «se descuida»: al tocar
##   el borde del scroll (EventBus.scroll_edge_hit) y en cada repeticion de una
##   seccion en bucle (EventBus.loop_wrapped). Destello flash_s en skip_color
##   (nombre de la paleta PROVISIONAL del Mundo 2) y un bote de bump_scale.
## SOLO VISUAL: no toca GameState ni el juego. Formato HH:MM (glifos de la fuente
## del HUD: cifras y «:»), da la vuelta a las 24 h. El sonido sfx_w2_clock_skip
## llega con los IDs del paso 20 (senal skipped).
class_name HudClock
extends Node

## La hora ha saltado (`text` = hora nueva, `skips` = saltos en este nivel).
signal skipped(text: String, skips: int)

const MINUTES_PER_DAY: float = 1440.0

var _label: Label
var _config: Dictionary = {}
var _hud_config: HudConfig
var _minutes: float = 0.0
var _skips: int = 0
var _world: int = GameState.FIRST_WORLD
var _hub: bool = false
var _flash_left: float = 0.0


## `label` = ClockSlot del HUD; `config` = seccion clock de data/hud.json.
func setup(label: Label, config: Dictionary, hud_config: HudConfig) -> void:
	_label = label
	_config = config
	_hud_config = hud_config
	_minutes = float(_config.get("start_minutes", 1024))
	_refresh()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.scroll_edge_hit.connect(_on_scroll_edge_hit)
	EventBus.loop_wrapped.connect(_on_loop_wrapped)


func _process(delta: float) -> void:
	advance(delta)


# --- Consultas ---

func is_shown() -> bool:
	return _hub == false and _world >= int(_config.get("from_world", 2))


func get_text() -> String:
	var total: int = posmod(floori(_minutes), int(MINUTES_PER_DAY))
	return "%02d:%02d" % [total / 60, total % 60]


func get_minutes() -> float:
	return _minutes


func get_skips() -> int:
	return _skips


func is_flashing() -> bool:
	return _flash_left > 0.0


# --- Acciones ---

## Avanza `dt` segundos reales (publico para las pruebas).
func advance(dt: float) -> void:
	_minutes += maxf(dt, 0.0) * float(_config.get("minutes_per_s", 1.0 / 60.0))
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - dt, 0.0)
	_refresh()


## Salta skip_minutes de golpe. Solo con el reloj a la vista (en el Mundo 1 no hay reloj).
func skip() -> void:
	if not is_shown():
		return
	_minutes += float(_config.get("skip_minutes", 60))
	_skips += 1
	_flash_left = float(_config.get("flash_s", 0.6))
	_refresh()
	skipped.emit(get_text(), _skips)


func set_hub_mode(hub: bool) -> void:
	_hub = hub
	_refresh()


# --- Interno ---

func _on_world_changed(world: int) -> void:
	_world = world
	_refresh()


func _on_scroll_edge_hit(_damaged: bool) -> void:
	skip()


func _on_loop_wrapped(_loop_id: StringName, _count: int) -> void:
	skip()


func _refresh() -> void:
	if _label == null:
		return
	_label.visible = is_shown()
	_label.text = get_text()
	var flash: float = 0.0
	var duration: float = maxf(float(_config.get("flash_s", 0.6)), 0.001)
	if _flash_left > 0.0:
		flash = _flash_left / duration
	var base: Color = _hud_config.color(&"text") if _hud_config != null else Color.WHITE
	var hot: Color = World2ObjectsConfig.color(String(_config.get("skip_color", "magenta")), base)
	var material := _label.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"target_color", base.lerp(hot, flash))
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2.ONE * lerpf(1.0, float(_config.get("bump_scale", 1.25)), flash)
