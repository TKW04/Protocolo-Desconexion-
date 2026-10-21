## Humo de la arena de Alerta Mayor (pasos 5-8 de docs/propuesta-jefe-alerta-mayor.md, 2026-10-21): carga
## el flujo real con -- --start-level=1-boss (LevelRunner), cierra la intro y deja correr la pelea con Isak
## quieto (Sync siempre lleno) y un jugador minimo (no es el bot del paso 14): aturde las Burbujas, cierra
## el escudo y golpea el nucleo solo con la ventana abierta, hasta el golpe final. Emite finished(0) si
## llega en menos de 8 x --phase-s segundos; anota los golpes por fase.
## Logica de tools/smoke_boss_arena.gd (lanzador).
## Usa user://tool_save.json. No es el bot de jefe (paso 14).
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"

var _main: LevelRunner
var _boss: AlertMajor
var _t: float = 0.0
var _phase_s: float = 25.0
var _deaths: int = 0
var _intro_closed: bool = false
var _done: bool = false
var _hit_t: float = 0.0
## Golpes dados con la ventana abierta, por fase.
var _windows: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--phase-s")
	if i >= 0 and i + 1 < args.size():
		_phase_s = float(args[i + 1])
	GameState.use_save_path("user://tool_save.json", true)
	GameState.reset_progress()
	GameSettings.use_path("user://tool_settings.cfg")
	EcoTextBox.pause_important = false
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_main.start_level_id = "1-boss"
	add_child(_main)
	_boss = _main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	EventBus.player_died.connect(func() -> void: _deaths += 1)
	_boss.final_blow.connect(func() -> void: _done = true)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _intro_closed and _t > 6.0:
		_intro_closed = true
		EventBus.eco_line_finished.emit()
	if _boss.is_fighting():
		# Jugador minimo (sin bot): aturde las Burbujas de la fase 1, cierra el escudo de la fase 2 y,
		# con la ventana abierta, golpea el nucleo cada 0,5 s. Asi las ventanas salen del bucle real.
		if _boss.get_phase() == 1:
			for b: AlertBubble in _boss.get_bubbles():
				if not b.is_stunned() and b.is_on_floor():
					b.stun()
		var shield: OverlayPopup = _boss.get_shield()
		if _boss.get_phase() == 2 and shield != null and shield.is_open() and _boss.get_move() == AlertMajor.MOVE_DOWN:
			shield.close()
		if _boss.is_window_open():
			_hit_t += delta
			if _hit_t >= 0.5:
				_hit_t = 0.0
				_windows[_boss.get_phase()] = int(_windows.get(_boss.get_phase(), 0)) + 1
				_boss.take_core_hit(1)
		GameState.sync_rate = GameState.get_sync_rate_max()
	if _done:
		print("smoke_boss_arena: golpe final a los %.1f s (fase %d, %d muertes; golpes en ventana por fase %s)"
			% [_t, _boss.get_phase(), _deaths, _windows])
		finished.emit(0)
		set_physics_process(false)
	elif _t > _phase_s * 8.0:
		print("smoke_boss_arena: sin golpe final a los %.1f s (fase %d)" % [_t, _boss.get_phase()])
		finished.emit(1)
		set_physics_process(false)
