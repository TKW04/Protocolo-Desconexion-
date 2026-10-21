## Humo de la arena de Alerta Mayor (pasos 5-8 de docs/propuesta-jefe-alerta-mayor.md, 2026-10-21): carga
## el flujo real con -- --start-level=1-boss (LevelRunner), cierra la intro y deja correr la pelea con Isak
## quieto (Sync siempre lleno) y un jugador minimo (no es el bot del paso 14): aturde las Burbujas, cierra
## el escudo y golpea el nucleo solo con la ventana abierta, hasta el golpe final. Emite finished(0) si
## llega en menos de 8 x --phase-s segundos; anota los golpes por fase.
## Logica de tools/smoke_boss_arena.gd (lanzador).
## --full (paso 13, 2026-10-21): flujo completo desde el HUB con el 1-3 completado: abre la carpeta del
## Mundo 1, entra a «Jefe: Alerta Mayor» (confirmando «Entrar sin guardar»), cierra la intro, pelea con la
## barra del jefe en el HUD, vence, cierra la recompensa y la linea de derrota y vuelve al hub: comprueba
## 1-boss completado, la capa boss_w1_l1 sin guardar, el Mundo 2 desbloqueado y la pieza cian encendida.
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
var _full: bool = false
## El jefe ya se busco (tras liberarse, `_boss == null` vuelve a ser verdadero en GDScript).
var _hooked: bool = false
var _entered: bool = false
var _bar_seen: bool = false
var _defeated_at: float = -1.0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--phase-s")
	if i >= 0 and i + 1 < args.size():
		_phase_s = float(args[i + 1])
	GameState.use_save_path("user://tool_save.json", true)
	GameState.reset_progress()
	GameSettings.use_path("user://tool_settings.cfg")
	EcoTextBox.pause_important = false
	_full = args.has("--full")
	print("smoke_boss_arena: modo %s" % ("completo desde el hub" if _full else "arena"))
	# Sigue con el arbol en pausa (congelacion y recompensa del golpe final).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	if _full:
		GameState.meet_ally(GameState.ALLY_ECO)
		GameState.meet_ally(GameState.ALLY_NOTAS)
		for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
				GameState.ABILITY_DASH]:
			GameState.obtained_abilities[ability] = true
			GameState.seen_notices[ability] = true
		for id: StringName in [&"1-1", &"1-2", &"1-3"]:
			GameState.mark_level_completed(id)
		GameState.unlock_level(&"1-boss")
		_main.start_level_id = "hub"
	else:
		_main.start_level_id = "1-boss"
	add_child(_main)
	EventBus.player_died.connect(func() -> void: _deaths += 1)
	if not _full:
		_hook_boss()


func _hook_boss() -> void:
	_hooked = true
	_boss = _main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.final_blow.connect(func() -> void: _done = true)


func _physics_process(delta: float) -> void:
	_t += delta
	if _full and _full_flow(delta):
		return
	if not _intro_closed and _t > 6.0:
		# La intro la dice Eco por el jefe en el cuadro del nivel (paso 12): se cierra a mano.
		var box := _main.get_level().get_node_or_null(^"EcoTextBox") as EcoTextBox
		if box != null and box.is_showing():
			box.finish_typing()
			box.advance(30.0)
		_intro_closed = _boss.is_fighting()
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
	if _done and _full:
		return
	if _done:
		print("smoke_boss_arena: golpe final a los %.1f s (fase %d, %d muertes; golpes en ventana por fase %s)"
			% [_t, _boss.get_phase(), _deaths, _windows])
		finished.emit(0)
		set_physics_process(false)
	elif _t > _phase_s * 8.0:
		print("smoke_boss_arena: sin golpe final a los %.1f s (fase %d)" % [_t, _boss.get_phase()])
		finished.emit(1)
		set_physics_process(false)


## Flujo completo (--full). Verdadero si este cuadro ya lo gestiono el flujo (hub o final).
func _full_flow(_delta: float) -> bool:
	if not _entered:
		if not _main.is_in_hub() and _main.get_level() != null and _main.get_level_id() == "1-boss":
			_entered = true
			return true
		var hub: HubRoom = _main.get_hub()
		if hub == null or not is_instance_valid(hub) or not hub.has_arrived() or hub.get_departure_vortex() != null \
				or not hub.get_entering_level().is_empty():
			return true
		var folder: FolderStation = hub.get_folder(&"m1")
		if folder.get_folder_panel() == null or not folder.get_folder_panel().is_open():
			folder.open(hub.get_isak())
			return true
		var panel: FolderPanel = folder.get_folder_panel()
		panel.skip_input_delay()
		if panel.is_confirming_unsaved():
			panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED)
		else:
			panel.select_option(&"1-boss")
		panel.confirm()
		return true
	if not _hooked:
		if _main.is_in_hub() or _main.get_level() == null or _main.get_level_id() != "1-boss":
			return true
		_hook_boss()
		_t = 0.0
		return true
	if is_instance_valid(_boss) and _boss.is_fighting():
		var hud := _main.get_level().get_node_or_null(^"Hud") as Hud
		if hud != null and hud.get_boss_bar().visible:
			_bar_seen = true
	if not _done:
		return false
	if _defeated_at < 0.0:
		_defeated_at = _t
		print("smoke_boss_arena: golpe final a los %.1f s (golpes en ventana por fase %s)" % [_t, _windows])
	var defeat: BossDefeat = _boss.get_defeat() if is_instance_valid(_boss) else null
	if defeat != null:
		var reward: BossReward = defeat.get_reward()
		if reward != null and reward.can_close():
			reward.confirm()
		var box := _main.get_level().get_node_or_null(^"EcoTextBox") as EcoTextBox if _main.get_level() != null else null
		if box != null and box.is_showing():
			box.finish_typing()
			box.advance(30.0)
	if _main.is_in_hub():
		var hub: HubRoom = _main.get_hub()
		if hub.has_arrived() and not hub.is_piece_pending() and not hub.is_piece_lighting():
			var ok: bool = _bar_seen and GameState.is_level_completed(&"1-boss") \
					and GameState.has_memory(&"boss_w1_l1") and GameState.has_unsaved_changes() \
					and HubWorlds.is_world_unlocked(HubWorlds.world(&"m2")) and hub.get_background_state() == &"on"
			print("smoke_boss_arena: --full de vuelta en el hub a los %.1f s: barra %s, 1-boss %s, recuerdo %s, Mundo 2 %s, pieza %s"
				% [_t, _bar_seen, GameState.is_level_completed(&"1-boss"), GameState.has_memory(&"boss_w1_l1"),
				HubWorlds.is_world_unlocked(HubWorlds.world(&"m2")), hub.get_background_state()])
			finished.emit(0 if ok else 1)
			set_physics_process(false)
		elif _t - _defeated_at > 60.0:
			print("smoke_boss_arena: --full sin terminar la llegada al hub")
			finished.emit(1)
			set_physics_process(false)
		return true
	if _t - _defeated_at > 30.0 and not _main.is_in_hub():
		print("smoke_boss_arena: --full sin volver al hub (etapa %s)" % (defeat.get_stage() if defeat != null else -1))
		finished.emit(1)
		set_physics_process(false)
	return true
