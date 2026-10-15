## Flujo de juego del vertical slice (paso 16). Raiz de scenes/main.tscn (la
## escena principal del proyecto). Valores en data/flow.json.
##
## - Carga el nivel actual (GameState.current_level o default_level) como hijo
##   instanciando scenes/levels/<id>.tscn (escena generada: no se toca) y deja
##   el estado de Isak como al empezar: Sync Rate y energia segun start_state
##   (porcentaje del maximo efectivo, que las mejoras pueden subir), sin ultimo
##   punto de sincronizacion y Debug apagado. Los puntos de atencion NO se
##   reinician: son el total acumulado y persistente (decision 2026-10-14); los
##   ya capturados en el nivel no reaparecen (AttentionPoint).
##   Las habilidades las aplica el propio nivel (abilities_available).
## - Muerte (Isak.died, al llegar el Sync Rate a 0): espera a que acabe la
##   animacion death y death_pause_s, funde a negro, reaparece en el ultimo
##   punto de sincronizacion del nivel (o en P) con el Sync Rate al 100 % (V2),
##   respawn_invulnerability_s de invulnerabilidad y el Debug apagado, y vuelve
##   a abrir el fundido. Los objetos del nivel conservan su estado (PROPUESTA:
##   cero castigo); la Burbuja viva vuelve a su sitio patrullando.
## - Red de seguridad: si Isak cae por debajo del nivel (fall_limit_margin_px)
##   reaparece igual, quitando fall_sync_penalty (PROPUESTA 0).
## - Final: EventBus.level_completed -> registra el nivel como completado y
##   desbloquea sus `unlocks` (GameState), funde y muestra la pantalla
##   provisional del hub con los puntos recogidos; su restart_requested
##   reinicia el nivel desde cero.
## - Teclas de prueba (dev_keys de data/flow.json): restart_level (R / Select)
##   reinicia el mapa actual desde el inicio como start_level (el guardado se
##   conserva). Vale jugando, en el hub y durante la animacion de muerte (la
##   sustituye); se ignora durante un fundido. Mantener debug_wipe_save (F9)
##   wipe_hold_s borra el guardado (GameState.save_path) y reinicia el mapa;
##   solo en builds de depuracion, con un aviso en pantalla mientras se mantiene.
## El fundido es un CanvasLayer propio (transition_layer) sobre el HUD.
## Todo avanza con advance(delta) (tiempo real); las pruebas pueden desactivar
## auto_advance y llamarlo a mano.
class_name LevelRunner
extends Node

enum Phase { PLAYING, DYING, FADE_OUT, FADE_IN }

const DATA_PATH: String = "res://data/flow.json"

## Cambia de fase (para pruebas y depuracion).
signal phase_changed(phase: Phase)
## Nivel cargado y listo (tras el reinicio de estado).
signal level_started(level_id: String)
## Isak ha reaparecido (`after_death`: por muerte; si no, por caida).
signal respawned(position: Vector2, after_death: bool)
## Se muestra la pantalla provisional del hub.
signal hub_shown(level_id: String, attention_points: int)
## Se ha reiniciado el mapa con la tecla restart_level o tras borrar el guardado.
signal level_restarted(level_id: String)
## Se ha borrado el guardado con debug_wipe_save.
signal save_wiped(path: String)

## Si es false, _process no avanza el flujo (las pruebas llaman a advance()).
@export var auto_advance: bool = true
## Nivel a cargar al entrar; vacio = GameState.current_level o default_level.
@export var start_level_id: String = ""
## Si es false, mantener debug_wipe_save no hace nada (fuera de builds de
## depuracion siempre es false).
@export var wipe_enabled: bool = OS.is_debug_build()

var _data: Dictionary = {}
var _phase: Phase = Phase.PLAYING
var _timer: float = 0.0
var _alpha: float = 0.0
var _after_fade: Callable = Callable()
var _level: GeneratedLevel
var _level_id: String = ""
var _isak: Isak
var _spawn_position: Vector2 = Vector2.ZERO
var _hub: HubPlaceholder
var _holder: Node
var _transition: CanvasLayer
var _fade: ColorRect
var _deaths: int = 0
var _falls: int = 0
var _restarts: int = 0
var _wipe_held_s: float = 0.0
## Tras borrar, hay que soltar la tecla antes de poder borrar otra vez.
var _wipe_latched: bool = false
var _prompt_layer: CanvasLayer
var _prompt_label: Label
var _prompt_bar: ColorRect


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_build_transition()
	_build_wipe_prompt()
	EventBus.level_completed.connect(_on_level_completed)
	var id: String = start_level_id
	if id.is_empty():
		id = String(GameState.current_level)
	if id.is_empty():
		id = String(_data.get("default_level", "1-1"))
	start_level(id)
	_set_alpha(1.0)
	_set_phase(Phase.FADE_IN)


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)
	if wipe_enabled:
		update_wipe_hold(delta, Input.is_action_pressed(_dev_action("wipe_action", "debug_wipe_save")))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(_dev_action("restart_action", "restart_level"), false):
		if request_restart():
			get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	check_fall()


# --- Consultas ---

func get_phase() -> Phase:
	return _phase


func get_level() -> GeneratedLevel:
	return _level


func get_level_id() -> String:
	return _level_id


func get_isak() -> Isak:
	return _isak


func get_hub() -> HubPlaceholder:
	return _hub


func is_in_hub() -> bool:
	return _hub != null


## Opacidad del fundido (0 = transparente, 1 = negro).
func get_fade_alpha() -> float:
	return _alpha


func get_transition_layer() -> CanvasLayer:
	return _transition


## Posicion de P (donde aparece Isak al empezar el nivel).
func get_start_position() -> Vector2:
	return _spawn_position


func get_death_count() -> int:
	return _deaths


func get_fall_count() -> int:
	return _falls


## Reinicios hechos con restart_level o tras borrar el guardado.
func get_restart_count() -> int:
	return _restarts


## Segundos que lleva mantenida debug_wipe_save (0 si no).
func get_wipe_hold_s() -> float:
	return _wipe_held_s


## Segundos que hay que mantener debug_wipe_save para borrar el guardado.
func get_wipe_hold_required_s() -> float:
	return float(_dev_keys().get("wipe_hold_s", 2.0))


## Aviso "Mantén F9: borrar guardado" (null si wipe_enabled era false al entrar).
func get_wipe_prompt() -> Label:
	return _prompt_label


## Donde reapareceria Isak ahora: el ultimo punto de sincronizacion o P.
func get_respawn_position() -> Vector2:
	var checkpoint: Checkpoint = _find_checkpoint(GameState.get_last_checkpoint(StringName(_level_id)))
	return checkpoint.get_spawn_position() if checkpoint != null else _spawn_position


## Y global por debajo de la cual salta la red de seguridad.
func get_fall_limit_y() -> float:
	if _level == null:
		return INF
	return float(_level.get_size_px().y) + float(_data.get("fall_limit_margin_px", 64.0))


## Segundos desde la muerte hasta el fundido (animacion death + pausa).
func get_death_wait_s() -> float:
	var anim_s: float = _isak.get_animation_length(Isak.ANIM_DEATH) if _isak != null else 0.0
	return anim_s + float(_data.get("death_pause_s", 0.5))


# --- Acciones ---

## Carga `level_id` desde cero (quita el nivel o el hub anterior) y reinicia el
## estado de Isak. No funde: lo hace quien llama. Falso si no existe la escena.
func start_level(level_id: String) -> bool:
	var path: String = String(_data.get("level_scene_pattern", "res://scenes/levels/%s.tscn")) % level_id
	if not ResourceLoader.exists(path):
		push_error("LevelRunner: no existe la escena del nivel '%s' (%s)" % [level_id, path])
		return false
	_clear_hub()
	_clear_level()
	_reset_player_state(level_id)
	_level = (load(path) as PackedScene).instantiate() as GeneratedLevel
	_level_id = level_id
	_holder.add_child(_level)
	_isak = _level.get_isak()
	_spawn_position = _isak.global_position
	_isak.died.connect(_on_isak_died)
	_deaths = 0
	_falls = 0
	level_started.emit(level_id)
	return true


## Reinicia el mapa actual desde el inicio (funde a negro y llama a
## start_level). El guardado se conserva. Falso si no se acepta ahora: sin
## nivel o durante un fundido. Durante la animacion de muerte sustituye a la
## reaparicion.
func request_restart() -> bool:
	if _level_id.is_empty() or _phase == Phase.FADE_OUT or _phase == Phase.FADE_IN:
		return false
	_fade_out_then(_restart_now)
	return true


## Borra el guardado actual (GameState.save_path y sus restos) y el progreso en
## memoria, y reinicia el mapa desde el inicio. Funciona en cualquier fase: si
## habia un fundido en curso, al acabar se reinicia en vez de lo pendiente.
## Solo con wipe_enabled (builds de depuracion). Verdadero si borro.
func wipe_save_and_restart() -> bool:
	if not wipe_enabled:
		return false
	var path: String = GameState.save_path
	SaveFile.delete(path)
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	save_wiped.emit(path)
	if not _level_id.is_empty():
		_fade_out_then(_restart_now)
	return true


## Lleva la cuenta de debug_wipe_save mantenida (`held`) y borra al llegar a
## wipe_hold_s. Hay que soltarla para volver a empezar. Verdadero si borro.
func update_wipe_hold(delta: float, held: bool) -> bool:
	if not wipe_enabled or not held:
		_wipe_held_s = 0.0
		_wipe_latched = false
		_update_wipe_prompt()
		return false
	if _wipe_latched:
		return false
	_wipe_held_s += maxf(delta, 0.0)
	var wiped: bool = false
	if _wipe_held_s >= get_wipe_hold_required_s():
		_wipe_held_s = 0.0
		_wipe_latched = true
		wiped = wipe_save_and_restart()
	_update_wipe_prompt()
	return wiped


## Avanza el flujo `delta` segundos reales.
func advance(delta: float) -> void:
	match _phase:
		Phase.DYING:
			_timer -= delta
			if _timer <= 0.0:
				_fade_out_then(_respawn.bind(true))
		Phase.FADE_OUT:
			_set_alpha(_alpha + _rate("fade_out_s", delta))
			if _alpha >= 1.0:
				var action: Callable = _after_fade
				_after_fade = Callable()
				_set_phase(Phase.FADE_IN)
				if action.is_valid():
					action.call()
		Phase.FADE_IN:
			_set_alpha(_alpha - _rate("fade_in_s", delta))
			if _alpha <= 0.0:
				_set_phase(Phase.PLAYING)


## Red de seguridad: Isak por debajo del nivel -> reaparece. Verdadero si salta.
func check_fall() -> bool:
	if _phase != Phase.PLAYING or _hub != null or _isak == null or not is_instance_valid(_isak):
		return false
	if _isak.is_dead() or _isak.global_position.y <= get_fall_limit_y():
		return false
	_falls += 1
	_fade_out_then(_respawn.bind(false))
	return true


# --- Interno ---

func _reset_player_state(level_id: String) -> void:
	var start: Dictionary = _data.get("start_state", {})
	DebugMode.reset()
	Engine.time_scale = 1.0
	GameState.world_time_scale = GameState.WORLD_TIME_SCALE_NORMAL
	var sync_percent: float = float(start.get("sync_rate", GameState.SYNC_RATE_MAX))
	var energy_percent: float = float(start.get("debug_energy", GameState.DEBUG_ENERGY_MAX))
	GameState.sync_rate = GameState.get_sync_rate_max() * sync_percent / GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max() * energy_percent / GameState.DEBUG_ENERGY_MAX
	GameState.clear_last_checkpoint(StringName(level_id))


func _respawn(after_death: bool) -> void:
	if _isak == null or not is_instance_valid(_isak):
		return
	var at: Vector2 = get_respawn_position()
	DebugMode.reset()
	Engine.time_scale = 1.0
	if after_death:
		GameState.sync_rate = GameState.get_sync_rate_max()
	else:
		GameState.apply_sync_damage(float(_data.get("fall_sync_penalty", 0.0)))
	_isak.respawn(at, float(_data.get("respawn_invulnerability_s", 1.0)))
	for enemy: Node in get_tree().get_nodes_in_group(AlertBubble.GROUP):
		if _level.is_ancestor_of(enemy) and enemy.has_method(&"reset_patrol"):
			enemy.call(&"reset_patrol")
	respawned.emit(at, after_death)
	EventBus.player_respawned.emit(at, after_death)


func _show_hub(level_id: String, attention_points: int) -> void:
	_clear_level()
	_hub = (load(String(_data["hub_scene"])) as PackedScene).instantiate() as HubPlaceholder
	_holder.add_child(_hub)
	_hub.show_result(level_id, attention_points)
	_hub.restart_requested.connect(_on_restart_requested)
	hub_shown.emit(level_id, attention_points)


func _record_completion(level_id: String) -> void:
	GameState.mark_level_completed(StringName(level_id))
	var path: String = String(_data.get("level_data_pattern", "res://data/levels/%s.json")) % level_id
	if not FileAccess.file_exists(path):
		return
	var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not level is Dictionary:
		return
	for unlock: Variant in level.get("unlocks", []):
		if unlock is Dictionary and String(unlock.get("type", "")) == "level":
			GameState.unlock_level(StringName(String(unlock.get("id", ""))))


func _restart_now() -> void:
	if start_level(_level_id):
		_restarts += 1
		level_restarted.emit(_level_id)


func _dev_keys() -> Dictionary:
	return _data.get("dev_keys", {})


func _dev_action(key: String, fallback: String) -> StringName:
	return StringName(String(_dev_keys().get(key, fallback)))


func _build_wipe_prompt() -> void:
	if not wipe_enabled:
		return
	var cfg: Dictionary = _dev_keys()
	var scale: float = float(cfg.get("prompt_scale", 2))
	var color: Color = Color.html(String(cfg.get("prompt_color", "#ffffff")))
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "DevPrompt"
	_prompt_layer.layer = int(cfg.get("prompt_layer", int(_data.get("transition_layer", 50)) + 1))
	add_child(_prompt_layer)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position.y = float(cfg.get("prompt_top_px", 24))
	box.scale = Vector2(scale, scale)
	_prompt_layer.add_child(box)
	_prompt_label = Label.new()
	_prompt_label.name = "WipePrompt"
	_prompt_label.text = String(cfg.get("wipe_prompt", "Mantén F9: borrar guardado"))
	var font_path: String = String(cfg.get("prompt_font", ""))
	if not font_path.is_empty() and ResourceLoader.exists(font_path):
		_prompt_label.add_theme_font_override(&"font", load(font_path) as Font)
	_prompt_label.add_theme_font_size_override(&"font_size", int(cfg.get("prompt_font_size", 12)))
	_prompt_label.add_theme_color_override(&"font_color", color)
	box.add_child(_prompt_label)
	_prompt_bar = ColorRect.new()
	_prompt_bar.name = "WipeBar"
	_prompt_bar.color = color
	_prompt_bar.custom_minimum_size = Vector2(0.0, 2.0)
	_prompt_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_prompt_bar)
	# Centrado horizontal: el ancho escalado del texto.
	var width: float = _prompt_label.get_minimum_size().x
	box.position.x = -floorf(width * scale * 0.5)
	_prompt_layer.visible = false


func _update_wipe_prompt() -> void:
	if _prompt_layer == null:
		return
	var showing: bool = _wipe_held_s > 0.0
	_prompt_layer.visible = showing
	if showing:
		var ratio: float = clampf(_wipe_held_s / maxf(get_wipe_hold_required_s(), 0.001), 0.0, 1.0)
		_prompt_bar.custom_minimum_size.x = floorf(_prompt_label.get_minimum_size().x * ratio)


func _fade_out_then(action: Callable) -> void:
	_after_fade = action
	_set_phase(Phase.FADE_OUT)


func _rate(key: String, delta: float) -> float:
	var seconds: float = float(_data.get(key, 0.3))
	return 1.0 if seconds <= 0.0 else delta / seconds


func _set_phase(phase: Phase) -> void:
	if _phase == phase:
		return
	_phase = phase
	phase_changed.emit(phase)


func _set_alpha(alpha: float) -> void:
	_alpha = clampf(alpha, 0.0, 1.0)
	_fade.color.a = _alpha
	_fade.visible = _alpha > 0.0


func _clear_level() -> void:
	if _level != null and is_instance_valid(_level):
		_holder.remove_child(_level)
		_level.queue_free()
	_level = null
	_isak = null


func _clear_hub() -> void:
	if _hub != null and is_instance_valid(_hub):
		_holder.remove_child(_hub)
		_hub.queue_free()
	_hub = null


func _find_checkpoint(id: StringName) -> Checkpoint:
	if id == &"" or _level == null:
		return null
	for node: Node in get_tree().get_nodes_in_group(Checkpoint.GROUP):
		var checkpoint := node as Checkpoint
		if checkpoint != null and checkpoint.checkpoint_id == id and _level.is_ancestor_of(checkpoint):
			return checkpoint
	return null


func _build_transition() -> void:
	_holder = Node.new()
	_holder.name = "Holder"
	add_child(_holder)
	_transition = CanvasLayer.new()
	_transition.name = "Transition"
	_transition.layer = int(_data.get("transition_layer", 50))
	add_child(_transition)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color.html(String(_data.get("fade_color", "#0b0e1a")))
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition.add_child(_fade)
	_set_alpha(0.0)


func _on_isak_died() -> void:
	_deaths += 1
	_after_fade = Callable()
	_timer = get_death_wait_s()
	_set_phase(Phase.DYING)


func _on_level_completed(level_id: String) -> void:
	if _level == null or _hub != null or level_id != _level_id:
		return
	_record_completion(level_id)
	_fade_out_then(_show_hub.bind(level_id, GameState.attention_points))


func _on_restart_requested(level_id: String) -> void:
	if _phase != Phase.PLAYING:
		return
	_fade_out_then(start_level.bind(level_id))
