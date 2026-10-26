## Banco de pruebas del movimiento de Isak (tiles de 64 px, suelo en y = 640,
## resolucion 1280x720): plataforma baja (96 px libres debajo, encima a 2
## tiles), escalones de 1, 2 y
## 2,5 tiles, hueco de 2 tiles (caminando), hueco de 3 tiles (corriendo),
## plataforma de una via y pared. Caer por un hueco devuelve a Isak al inicio.
## Pulso (G), dash (L / B, gesto Deslizar; 2026-10-19), golpe al suelo y
## Pellizcar (I / RB; 2026-10-26) desbloqueados.
## Solo para jugar y ajustar valores; no es un nivel del juego.
extends Node2D

## Ayudas de depuracion en pantalla (estado, velocidad, tipo del ultimo salto
## y carteles de medidas). Solo para esta escena de pruebas; no es el HUD.
const DEBUG_OVERLAY: bool = true
## Teclas de depuracion del HUD (acciones hud_debug_* del Input Map: F1-F4).
## Solo en esta escena; ponlo a false para desactivarlas.
const DEBUG_HUD_KEYS: bool = true
## Cambios que aplican las teclas de depuracion del HUD.
const DEBUG_SYNC_STEP: float = 10.0
const DEBUG_ENERGY_STEP: float = 20.0
const DEBUG_ATTENTION_STEP: int = 1
## Posicion de la ayuda en pantalla: debajo de la barra del HUD.
const DEBUG_LABEL_POSITION: Vector2 = Vector2(16.0, 48.0)

const JUMP_NORMAL: String = "normal"
const JUMP_COYOTE: String = "coyote"
const JUMP_BUFFER: String = "buffer"

## Desbloquea el pulso al cargar esta escena (en tiempo de ejecucion; el valor
## por defecto de GameState sigue bloqueado).
@export var unlock_pulse: bool = true
## Desbloquea el dash (gesto Deslizar: L / B; 2026-10-19) al cargar esta escena,
## igual que el pulso (solo en tiempo de ejecucion).
@export var unlock_dash: bool = true
## Desbloquea el golpe al suelo (gesto Mantener presionado: mantener S / flecha
## abajo / abajo del mando; 2026-10-22) al cargar esta escena.
@export var unlock_ground_pound: bool = true
## Desbloquea Pellizcar (gesto Pellizcar: I / RB; 2026-10-26) al cargar esta escena.
@export var unlock_compress: bool = true
## Si Isak cae por debajo de esta Y vuelve al punto de inicio.
@export var fall_limit_y: float = 960.0

var _spawn_position: Vector2
var _last_jump: String = "-"
var _debug_label: Label

@onready var _isak: Isak = $Isak
@onready var _debug_signs: Node2D = $DebugSigns


func _ready() -> void:
	_spawn_position = _isak.global_position
	if unlock_pulse:
		GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	if unlock_dash:
		GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	if unlock_ground_pound:
		GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	if unlock_compress:
		GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, true)
	_debug_signs.visible = DEBUG_OVERLAY
	if DEBUG_OVERLAY:
		_setup_debug_overlay()


## Teclas de depuracion del HUD: F1 -10 % Sync Rate (dano de prueba),
## F2 +10 % Sync Rate, F3 -20 de energia, F4 +1 punto de atencion (+10 energia).
func _unhandled_input(event: InputEvent) -> void:
	if not DEBUG_HUD_KEYS:
		return
	if event.is_action_pressed(&"hud_debug_sync_down"):
		apply_test_damage(DEBUG_SYNC_STEP)
	elif event.is_action_pressed(&"hud_debug_sync_up"):
		GameState.sync_rate += DEBUG_SYNC_STEP
	elif event.is_action_pressed(&"hud_debug_energy_down"):
		GameState.debug_energy -= DEBUG_ENERGY_STEP
	elif event.is_action_pressed(&"hud_debug_attention_add"):
		GameState.add_attention_points(DEBUG_ATTENTION_STEP)
	else:
		return
	get_viewport().set_input_as_handled()


## Dano de prueba: quita Sync Rate y reproduce el golpe de Isak (retroceso).
## El dano real (enemigos, i-frames que bloquean el dano) llega en el paso 9.
func apply_test_damage(amount: float) -> void:
	_isak.take_hit()
	GameState.apply_sync_damage(amount)


func _physics_process(_delta: float) -> void:
	if _isak.global_position.y > fall_limit_y:
		_isak.global_position = _spawn_position
		_isak.velocity = Vector2.ZERO


func _process(_delta: float) -> void:
	if _debug_label == null:
		return
	_debug_label.text = "estado: %s\nvel: (%.0f, %.0f) px/s\nsuelo: %s\nultimo salto: %s" % [
		_isak.get_state_name(), _isak.velocity.x, _isak.velocity.y,
		"si" if _isak.is_on_floor() else "no", _last_jump]


## Clasifica un salto sin tocar la logica de Isak: se llama justo al entrar en
## Jump, dentro de Isak.step(), tras leer la entrada de este paso.
## - coyote: viene de Fall y ya no pisa suelo.
## - buffer: el salto se pulso en un paso anterior (no en este).
static func classify_jump(previous: StringName, on_floor: bool, pressed_this_step: bool) -> String:
	if previous == PlayerState.FALL and not on_floor:
		return JUMP_COYOTE
	if not pressed_this_step:
		return JUMP_BUFFER
	return JUMP_NORMAL


func get_last_jump() -> String:
	return _last_jump


func _setup_debug_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugOverlay"
	layer.layer = 100
	_debug_label = Label.new()
	_debug_label.position = DEBUG_LABEL_POSITION
	_debug_label.add_theme_font_size_override("font_size", 16)
	_debug_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.6))
	layer.add_child(_debug_label)
	add_child(layer)
	_isak.state_changed.connect(_on_isak_state_changed)


func _on_isak_state_changed(previous: StringName, current: StringName) -> void:
	if current != PlayerState.JUMP:
		return
	_last_jump = classify_jump(previous, _isak.is_on_floor(), _isak.input.jump_pressed)
