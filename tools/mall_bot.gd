## Bot de la tienda (Mundo 5 «La Tienda»; paso 11 de docs/propuesta-mundo-5.md §8 y
## §7.3, 2026-10-29): carga la escena principal (scenes/main.tscn, LevelRunner) en el
## nivel real (--level 5-1; 5-1 por defecto; tambien las salas *_test del Mundo 5) y
## sigue el camino que exporta tools/validate_level.py (formato isak-path/1) con la
## fisica real y las acciones del Input Map, nunca Q ni Esc. Extiende el bot del chat
## (tools/chat_bot.gd: bandas, Linterna, pulsos a enemigos), que extiende el de la
## galeria, el del 1-3 y el de la torre.
## Perfiles (--profile):
## - `frugal` (por defecto): el camino de tools/validate_level.py (no paga ni compra;
##   el camino largo). Comprueba que no gasta nada.
## - `comprador`: el camino de `validate_level.py --buy` (paga el atajo, compra en la
##   tienda, Devoluciones si el camino pasa). Comprueba que el saldo nunca baja de 0,
##   que lo gastado es lo del camino y que saldo final = inicial + ganado - gastado
##   + devuelto.
## Pasos nuevos del Mundo 5:
## - `resist_pull`: tramo andando contra (o a favor de) el tiron de una Oferta; se anda
##   como un tramo normal (la fuerza la pone TemptationField); no frena si el paso
##   siguiente sigue en la misma direccion.
## - `wait` con objetivo Suscripcion: quieto hasta que se engancha (o queda aturdida).
## - `cancel_subscription`: pulso con la Suscripcion enganchada (la suelta aturdida);
##   la del atajo con trampa (`trampa:<id>`) es la que suelta su puerta.
## - `laser` a una Suscripcion aturdida: dispara hasta derrotarla.
## - `buy` / `pay_door` / `refund`: pulso de espaldas a la tienda, al atajo o a
##   Devoluciones desde la x del camino; hecho cuando se cobra / abre / devuelve.
## - `wait_countdown` y saltos a una cuenta regresiva: antes de saltar a su tarjeta, el
##   bot espera a que la cuenta este desplegada con tiempo para cruzarla.
## Ademas, como un jugador: quieto dentro de la zona de una Oferta mantiene la direccion contraria lo justo para no
## derivar (_set_axis); despega antes los saltos y dashes aereos con el tiron a favor (_pulled_takeoff); pisa la tapa
## real de las cajas sorpresa (56 px, 8 por debajo de la fila del camino); vuelve al despegue de un dash en el suelo si
## la frenada del anterior lo paso; y, si un dash que baja se posa antes en una plataforma de una via, sigue hasta la
## fila del camino.
## Combinacion (5-2, paso 13; el 5-2 empieza sin ella y la obtiene en la «Prueba gratis», cerrando las lineas de la
## escena):
## - `combo_ram` (Embestida): salto vertical desde `ram.x0`, dash aereo a `ram.dash_after_s` y abajo mantenido para que
##   salga a los `ram.dash_frames` cuadros del dash. El camino sigue desde la celda de despegue: si Isak aterriza en
##   otra fila (`ram.land_px`), el bot salta los pasos hasta el primero que sale de su fila.
## - `combo_edge` (Filo): comprimido, salto (en el sitio o andando) desde `takeoff_x_px` y Deslizar a `dash_after_s`.
## - `combo_quake` (Sismo): comprimido en `quake.x_px`, salto en el sitio y abajo mantenido al subir.
## - `open_box`: caja sorpresa que tapa el camino (pulso de cara pegado a ella: desde la x del camino no llega).
## Comprueba que cada combo sale y rompe lo que el paso dice (`breaks`) y que hace tantos como el camino.
## 5-3 (paso 14; se entra con la Combinacion): `open_box` con el laser (las peligrosas, tras mirarlas con el Debug) se
## aparta LASER_GAP_PX de la caja (el validador dispara pegado a ella); el pulso y el laser, siempre de cara a la caja;
## `reject_terms` (laser a «rechazar» de Terminos y condiciones desde `x_px`); el comprador admite las congelaciones
## de la trampa «Verificando pago…» de los atajos que paga (tantas como pasos `pay_door` con trap processing).
## Comprobaciones (§7.3): completa el nivel y vuelve al hub con el en completed_levels;
## 0 muertes; 0 «Añadido al carrito»; 0 congelaciones; saldo nunca < 0; energia
## minima frente al camino; duracion frente al 40-55 % del objetivo (solo frugal; el
## comprador la anota). Progreso: El Visto vencido (Mundo 5 disponible) y el kit del
## Mundo 4 (pulso, laser, Debug, dash, golpe al suelo, Pellizcar; Eco, Notas, Calc y la
## Linterna), con 0 puntos de atencion al entrar (el validador cuenta el saldo desde 0).
## Lo lanza tools/play_mall_bot.gd (uso y argumentos alli).
extends "res://tools/chat_bot.gd"

const MALL_LEVELS: PackedStringArray = ["5-1", "5-2", "5-3"]
const PROFILES: PackedStringArray = ["frugal", "comprador"]
const TRAP_PREFIX: String = "trampa:"
## Segundos de cuenta regresiva que el bot quiere por delante al saltar a su tarjeta.
const COUNTDOWN_NEED_S: float = 2.6
## Distancia (px, centro a pies) desde la que el bot dispara a una Suscripcion aturdida.
const LASER_GAP_PX: float = 96.0

var _profile: String = "frugal"
var _balance_start: int = 0
var _balance_min: int = 1 << 30
var _gained: int = 0
var _lost: int = 0
var _spent: int = 0
var _spent_by: Dictionary = {}
var _refunded: int = 0
var _drained: int = 0
var _carts: int = 0
var _purchases: PackedStringArray = []
var _subs_cancelled: int = 0
var _subs_defeated: int = 0
var _countdown_waits: int = 0
var _last_balance: int = 0
## Congelaciones de la trampa «Verificando pago…» de un atajo pagado (5-3, comprador): las pide el camino.
var _processing_freezes: int = 0
var _terms_rejected: PackedStringArray = []
var _watched: Dictionary = {}
## Dano de la tentacion de las Ofertas (2026-10-30: cuesta Sync segun el descuento, nunca mata): golpes, Sync
## quitado y Sync minimo tras un golpe. Se anota; no falla (no mata y el camino no lo evita).
var _tempt_hits: int = 0
var _tempt_damage: float = 0.0
var _tempt_sync_min: float = 1.0e9


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--profile")
	if at >= 0 and at + 1 < args.size():
		_profile = args[at + 1]
		if _profile == "buyer":
			_profile = "comprador"
	super._ready()
	if args.find("--level") < 0:
		_gallery_level = "5-1"


func _level_problem() -> String:
	if not PROFILES.has(_profile):
		return "perfil desconocido: %s (usa --profile frugal|comprador)" % _profile
	var file: String = "res://data/levels/%s.json" % _gallery_level
	if not MALL_LEVELS.has(_gallery_level) and not _gallery_level.ends_with("_test"):
		return "nivel desconocido: %s (usa --level 5-1|5-2|5-3 o una sala *_test del Mundo 5)" % _gallery_level
	if not FileAccess.file_exists(file):
		return "el %s aun no existe (data/levels/%s.json)" % [_gallery_level, _gallery_level]
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not data is Dictionary or int((data as Dictionary).get("world", 0)) != 5:
		return "el %s no es un nivel del Mundo 5" % _gallery_level
	_target_s = float((data as Dictionary).get("target_duration_s", 0.0))
	return ""


func _is_test_room() -> bool:
	return not MALL_LEVELS.has(_gallery_level)


func _bot_label() -> String:
	return "play_mall_bot (%s, %s)" % [_gallery_level, _profile]


func _path_cache_file() -> String:
	return "user://mall_bot_path_%s_%s.json" % [_gallery_level, _profile]


func _export_args(path_file: String) -> PackedStringArray:
	var args: PackedStringArray = [ProjectSettings.globalize_path("res://tools/validate_level.py")]
	if _profile == "comprador":
		args.append("--buy")
	args.append_array(["--export-path", path_file,
		ProjectSettings.globalize_path("res://data/levels/%s.json" % _gallery_level)])
	return args


## Quien acaba de vencer a El Visto (y, para el 5-2 y el 5-3, de completar los niveles
## anteriores del Mundo 5), con 0 puntos de atencion.
func _setup_progress() -> void:
	GameState.reset_progress()
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC, GameState.ALLY_LINTERNA]:
		GameState.meet_ally(ally)
	var abilities: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
		GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS]
	for ability: StringName in abilities:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	for level: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1", &"4-2", &"4-3", &"4-boss"]:
		GameState.unlock_level(level)
		GameState.mark_level_completed(level)
	GameState.install_hub_upgrade(UPGRADE_4_6)
	for level: String in MALL_LEVELS:
		GameState.unlock_level(StringName(level))
		if level == _gallery_level:
			break
		GameState.mark_level_completed(StringName(level))
	# El 5-3 (paso 14) se entra con la Combinacion, que da la «Prueba gratis» del 5-2.
	if _gallery_level == "5-3":
		GameState.obtained_abilities[GameState.ABILITY_COMBO] = true
		GameState.seen_notices[GameState.ABILITY_COMBO] = true
		GameState.seen_notices[&"combo_5_2"] = true
		GameState.set_ability_unlocked(GameState.ABILITY_COMBO, true)
	GameState.attention_points = 0
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()


func _check_level_loaded() -> bool:
	if not super._check_level_loaded():
		return false
	if _gallery_level in ["5-1", "5-2"] and GameState.is_ability_obtained(GameState.ABILITY_COMBO):
		return _fail("el bot empieza el %s con la Combinacion ya obtenida" % _gallery_level)
	if _gallery_level == "5-3" and not GameState.is_ability_obtained(GameState.ABILITY_COMBO):
		return _fail("el bot empieza el 5-3 sin la Combinacion")
	_isak.frozen_started.connect(func(_seconds: float, source: StringName) -> void:
		if source == &"shortcut_processing":
			_processing_freezes += 1)
	_balance_start = GameState.attention_points
	_last_balance = _balance_start
	_balance_min = _balance_start
	EventBus.attention_points_changed.connect(func(value: int) -> void:
		if value > _last_balance:
			_gained += value - _last_balance
		else:
			_lost += _last_balance - value
		_last_balance = value
		_balance_min = mini(_balance_min, value))
	EventBus.attention_spent.connect(func(amount: int, reason: StringName) -> void:
		_spent += amount
		_spent_by[String(reason)] = int(_spent_by.get(String(reason), 0)) + amount
		_note("gasta %d punto(s) (%s; saldo %d; %s)" % [amount, String(reason), GameState.attention_points, _where()]))
	EventBus.attention_refunded.connect(func(amount: int) -> void:
		_refunded += amount
		_note("Devoluciones: +%d (saldo %d)" % [amount, GameState.attention_points]))
	return true


## Gasto que pide el camino exportado (pasos con `cost`).
func _path_spend() -> int:
	var total: int = 0
	for step: Dictionary in _steps:
		if String(step.get("action", "")) in ["buy", "pay_door"]:
			total += int(step.get("cost", 0))
	return total


func _check_completed() -> bool:
	if not _is_test_room() and not GameState.is_level_completed(StringName(_gallery_level)):
		return _fail("el %s no queda completado" % _gallery_level)
	var game_s: float = (_terminal_frames if _terminal_frames >= 0 else _play_frames) / 60.0
	var ratio: float = game_s / _target_s if _target_s > 0.0 else 0.0
	var balance: int = GameState.attention_points
	_note("TIENDA (%s): muertes %d, golpes %d, congelaciones %d, «Añadido al carrito» %d, compras [%s], gastado %d (%s; camino %d), devuelto %d, drenado %d, Suscripciones canceladas %d / derrotadas %d, tentacion %d golpe(s) / %.0f de Sync (Sync minimo %s), esperas de cuenta regresiva %d, «rechazar» [%s], dashes %d; saldo %d -> %d (minimo %d; ganado %d, perdido %d); duracion %.1f s de %d s del objetivo (%.0f %%)" % [
		_profile, _deaths, _hits, _freezes, _carts, ", ".join(_purchases), _spent, _spent_by, _path_spend(), _refunded,
		_drained, _subs_cancelled, _subs_defeated, _tempt_hits, _tempt_damage,
		("%.0f" % _tempt_sync_min) if _tempt_hits > 0 else "-", _countdown_waits, ", ".join(_terms_rejected), _dashes, _balance_start, balance, _balance_min,
		_gained, _lost, game_s, int(_target_s), ratio * 100.0])
	if _deaths > 0:
		return _fail("Isak muere %d vez/veces" % _deaths)
	var want_frozen: int = 0
	for step: Dictionary in _steps:
		if String(step.get("action", "")) == "pay_door" and String(step.get("trap", "")) == "processing":
			want_frozen += 1
	if _freezes != _processing_freezes or _processing_freezes != want_frozen:
		return _fail("Isak se congela %d vez/veces (%d de «Verificando pago…»; el camino pide %d)" % [_freezes,
			_processing_freezes, want_frozen])
	if _stray_shakes > 0:
		return _fail("sale %d onda(s) de Agitar (retirado el 2026-10-28)" % _stray_shakes)
	if _carts > 0:
		return _fail("%d «Añadido al carrito» (el camino no compra deseos)" % _carts)
	if _balance_min < 0:
		return _fail("el saldo baja de 0 (%d)" % _balance_min)
	if _drained > 0:
		return _fail("una Suscripcion drena %d punto(s) (el camino la cancela antes)" % _drained)
	if _profile == "frugal" and _spent > 0:
		return _fail("el frugal gasta %d punto(s)" % _spent)
	if _profile == "comprador":
		if _spent != _path_spend():
			return _fail("el comprador gasta %d y el camino pide %d" % [_spent, _path_spend()])
		if _spent == 0:
			return _fail("el comprador no gasta nada")
	if balance != _balance_start + _gained - _lost or _lost != _spent:
		return _fail("cuentas del saldo: %d != %d + %d - %d (gastado %d)" % [balance, _balance_start, _gained, _lost,
			_spent])
	var want: Dictionary = {"combo_ram": 0, "combo_edge": 0, "combo_quake": 0}
	for step: Dictionary in _steps:
		var kind: String = String(step.get("action", ""))
		if want.has(kind):
			want[kind] = int(want[kind]) + 1
	if int(want["combo_ram"]) + int(want["combo_edge"]) + int(want["combo_quake"]) > 0:
		_note("COMBOS: Combinacion %s; Embestidas %d (camino %d), Filos %d (camino %d), Sismos %d (camino %d); denegados [%s]; cajas abiertas [%s]" % [
			GameState.is_ability_obtained(GameState.ABILITY_COMBO), _rams, want["combo_ram"], _edges, want["combo_edge"],
			_quakes, want["combo_quake"], ", ".join(_combo_denials), ", ".join(_boxes_opened)])
		if not GameState.is_ability_obtained(GameState.ABILITY_COMBO):
			return _fail("el camino pide combos y la Combinacion no queda obtenida")
		if _rams != int(want["combo_ram"]) or _edges != int(want["combo_edge"]) or _quakes != int(want["combo_quake"]):
			return _fail("combos hechos distintos de los del camino")
	if not _is_test_room() and _target_s > 0.0 and _profile == "frugal" and (ratio < RATIO_MIN or ratio > RATIO_MAX):
		return _fail("la duracion (%.1f s) queda fuera del %.0f-%.0f %% del objetivo (%d s)" % [game_s,
			RATIO_MIN * 100.0, RATIO_MAX * 100.0, int(_target_s)])
	return true


## Hub tras un nivel de la tienda: llegada por el vortice; la carpeta M5 sigue abierta.
func _hub() -> bool:
	if not await super._hub():
		return false
	var m5: Dictionary = HubWorlds.world(&"m5")
	_note("hub: carpeta M5 %s; %s completado %s; saldo %d" % [String(HubWorlds.folder_state(m5)), _gallery_level,
		GameState.is_level_completed(StringName(_gallery_level)), GameState.attention_points])
	return true


# --- Servicios de cada cuadro ---

func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(_level) or _runner == null or _runner.is_in_hub():
		return
	for group: String in ["Objects", "Enemies"]:
		for node: Node in _level.get_node(NodePath(group)).get_children():
			if _watched.has(node):
				continue
			if node is WishlistPlatform:
				_watched[node] = true
				var label: String = node.name
				(node as WishlistPlatform).added_to_cart.connect(func(_s: Subscription) -> void:
					_carts += 1
					_note("«Añadido al carrito» en %s (%s)" % [label, _where()]))
			elif node is Subscription:
				_watched[node] = true
				_watch_subscription(node as Subscription)
			elif node is OfferSign:
				_watched[node] = true
				(node as OfferSign).temptation_hit.connect(func(amount: float) -> void:
					_tempt_hits += 1
					_tempt_damage += amount
					_tempt_sync_min = minf(_tempt_sync_min, GameState.sync_rate))


## Tiron de las Ofertas (TemptationField): quieto, Isak deriva hacia ellas (60 px/s con una), asi que el bot, como un
## jugador, mantiene la direccion contraria lo justo para no moverse. Todo eje parcial (|a| < 1: quieto, frenadas y
## aproximaciones de _walk_to) se corrige con el eje que da velocidad 0 con el tiron de ahora; el eje a fondo (andar
## un tramo) no se toca: el camino ya cuenta la velocidad con el tiron. Al girarse (_face) no se corrige.
var _pull_field: TemptationField
var _bias_on: bool = true


func _set_axis(a: float) -> void:
	var biased: float = a
	if _bias_on and absf(a) < 0.999:
		biased = clampf(a + _pull_bias(), -1.0, 1.0)
	super._set_axis(biased)
	_axis = a


## Eje que deja a Isak quieto con el tiron de ahora (0 sin tiron, en el aire o sin control).
func _pull_bias() -> float:
	if _isak == null or not is_instance_valid(_isak) or not _isak.is_on_floor() or not _isak.is_tempted():
		return 0.0
	if _pull_field == null:
		_pull_field = TemptationField.load_default()
	_pull_field.sample(get_tree(), LevelLookup.isak_body_rect(_isak).get_center())
	if not _pull_field.is_pulling():
		return 0.0
	var speed: float = _isak.physics.walk_speed
	var lo: float = -1.0
	var hi: float = 1.0
	for i: int in 24:
		var mid: float = (lo + hi) * 0.5
		if _pull_field.target_speed(mid, speed) > 0.0:
			hi = mid
		else:
			lo = mid
	return (lo + hi) * 0.5


func _face(facing: float) -> void:
	_bias_on = false
	await super._face(facing)
	_bias_on = true
	# Si mantener quieto a Isak no le gira (el tiron va hacia su espalda), lo mantiene; si no, deriva.
	var bias: float = _pull_bias()
	if bias != 0.0 and signf(bias) == signf(facing):
		_set_axis(0.0)


func _watch_subscription(sub: Subscription) -> void:
	var label: String = sub.name
	sub.drained.connect(func(amount: int, _total: int) -> void:
		_drained += amount
		_note("DRENA: %s se lleva %d punto(s) (%s)" % [label, amount, _where()]))
	sub.cancelled.connect(func() -> void: _subs_cancelled += 1)
	sub.defeated.connect(func() -> void: _subs_defeated += 1)


## Defensa: una Suscripcion enganchada a Isak -> pulso (la suelta). Si no, la del chat.
func _guard() -> void:
	if _guard_lock == 0 and _has_control() and _can_pulse_now() and is_instance_valid(_level):
		for node: Node in _subscriptions():
			var sub := node as Subscription
			if sub.is_attached() and sub.get_host() == _isak:
				_tap(A_PULSE)
				_guard_lock = 4
				_guard_pulses += 1
				_note("defensa: pulso a %s enganchada (%s)" % [sub.name, _where()])
				return
	super._guard()


func _subscriptions() -> Array[Node]:
	var out: Array[Node] = []
	for group: String in ["Enemies", "Objects"]:
		for node: Node in _level.get_node(NodePath(group)).get_children():
			if node is Subscription:
				out.append(node)
	return out


# --- Pasos ---

func _continues(index: int, dir: float) -> bool:
	if index < _steps.size() and String(_steps[index].get("action", "")) == "resist_pull":
		var n: Dictionary = _steps[index]
		return signf(_px(n["to"]).x - _px(n["from"]).x) == dir
	return super._continues(index, dir)


func _do_extra_step(s: Dictionary, action: String) -> bool:
	match action:
		"resist_pull":
			var dir: float = signf(_px(s["to"]).x - _px(s["from"]).x)
			if _continues(_step_index + 1, dir):
				return await _walk_through(_px(s["to"]).x, _px(s["to"]).y, dir)
			return await _walk_to(_px(s["to"]).x, _px(s["to"]).y)
		"cancel_subscription":
			return await _cancel_step(s)
		"buy", "pay_door", "refund":
			return await _pay_step(s, action)
		"wait_countdown":
			return await _wait_countdown(s)
		"open_box":
			return await _open_box_step(s)
		"combo_ram":
			return await _ram_step(s)
		"combo_edge":
			return await _edge_step(s)
		"combo_quake":
			return await _quake_step(s)
		"reject_terms":
			return await _reject_step(s)
	return await super._do_extra_step(s, action)


## Paso `reject_terms` (5-3, paso 14): «rechazar» de Terminos y condiciones con el laser desde lo alto del pilar de
## enfrente (`via` laser; el Filo que lo roza no lo usa ningun camino). Hecho cuando la puerta queda abierta sin
## Suscripcion.
func _reject_step(s: Dictionary) -> bool:
	var id: String = String(s.get("target", {}).get("id", ""))
	var gate := _object(id) as TermsGate
	if gate == null:
		return _fail("paso %d: no hay Terminos y condiciones %s" % [_step_index, id])
	if String(s.get("via", "laser")) != "laser":
		return _fail("paso %d: «rechazar» con %s (el bot solo lo hace con el laser)" % [_step_index, s.get("via", "?")])
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(float(s.get("x_px", at.x)), at.y):
		return false
	for attempt: int in 3:
		if gate.is_open():
			break
		await _face(float(s.get("facing", 1)))
		await _wait_until(func() -> bool:
			return _has_control() and _isak.can_start_laser() and _isak.get_laser_cooldown_left() <= 0.0 \
				and not _isak.is_laser_posing(), 1.0)
		_tap(A_LASER)
		await _wait_until(func() -> bool: return gate.is_open(), 0.8)
	var ok: bool = gate.is_open() and gate.get_subscription() == null
	if ok:
		_terms_rejected.append(id)
	_note("Terminos y condiciones %s: %s (%s; %s; energia %.0f)" % [id, "rechazados con el laser" if ok else "SIN ABRIR",
		String(gate.get_opened_by()), _where(), GameState.debug_energy])
	return ok


## Paso `open_box`: caja sorpresa que tapa el camino; pulso de cara (o laser, `with`)
## desde `x_px` mirando a `facing`. Hecho cuando la caja queda abierta o destruida.
var _boxes_opened: PackedStringArray = []
## Distancia (px) del centro de Isak al lado de la caja desde la que el bot la abre con el pulso.
const BOX_PULSE_GAP_PX: float = 40.0


func _open_box_step(s: Dictionary) -> bool:
	var id: String = String(s.get("target", {}).get("id", ""))
	var box := _object(id) as SurpriseBox
	if box == null:
		return _fail("paso %d: no hay caja sorpresa %s" % [_step_index, id])
	var done := func() -> bool: return box.is_opened() or box.is_destroyed()
	if done.call():
		return true
	var at: Vector2 = _px(s["at"])
	var laser: bool = String(s.get("with", "pulse")) == "laser"
	var x: float = float(s.get("x_px", at.x))
	var r: Rect2 = box.get_body_rect()
	# De cara a la caja (el pulso del validador la alcanza mirando a cualquier lado; el real, solo de cara: 5-3, la caja
	# de la B2 a la izquierda del camino).
	var f: float = signf(r.get_center().x - at.x)
	if f == 0.0:
		f = float(s.get("facing", 1))
	if not laser:
		# El pulso real no llega a la caja desde la x del camino (5-2, caja_puntos_t1: 128 px): se pega a ella.
		var near_x: float = r.position.x - BOX_PULSE_GAP_PX if f > 0.0 else r.end.x + BOX_PULSE_GAP_PX
		if (near_x - x) * f > 0.0:
			if _verbose:
				_note("paso %d: se acerca a la caja %s (%.0f -> %.0f)" % [_step_index, id, x, near_x])
			x = near_x
	else:
		# 5-3 (paso 14): el validador dispara pegado a la caja (desde mas lejos su rayo choca con la celda); en el juego,
		# pegado, el rayo sale ya dentro de ella: el bot se aparta LASER_GAP_PX y dispara de cara.
		var far_x: float = r.position.x - LASER_GAP_PX if f > 0.0 else r.end.x + LASER_GAP_PX
		if (x - far_x) * f > 0.0:
			if _verbose:
				_note("paso %d: se aparta de la caja %s para el laser (%.0f -> %.0f)" % [_step_index, id, x, far_x])
			x = far_x
	if not await _walk_to(x, at.y):
		return false
	for attempt: int in 3:
		if done.call():
			break
		await _face(f)
		if laser:
			await _wait_until(func() -> bool: return _has_control() and _isak.can_start_laser(), 1.0)
			_tap(A_LASER)
		else:
			await _wait_can_pulse()
			_tap(A_PULSE)
		await _wait_until(done, 0.6)
	var ok: bool = done.call()
	if ok:
		_boxes_opened.append("%s (%s)" % [id, String(s.get("content", "?"))])
	_note("caja %s abierta con %s: %s (%s; saldo %d)" % [id, "el laser" if laser else "el pulso",
		"hecho" if ok else "SIN EFECTO", _where(), GameState.attention_points])
	return ok


# --- Combinacion (5-2) ---

## Pasos que el bot salta tras una Embestida que deja a Isak en otra fila (el camino
## sigue desde la celda de despegue; Isak aterriza en `land_px`).
var _skip_until: int = -1
var _rams: int = 0
var _edges: int = 0
var _quakes: int = 0
var _combo_denials: PackedStringArray = []


## Cuadros que hay que mantener abajo para que salga un combo de abajo (combo.hold_s).
func _combo_hold_frames() -> int:
	return int(ceil(_isak.abilities.combo_hold_s * 60.0)) + 1


## Espera a que Isak este en el suelo, con control y sin poses (antes de un combo).
func _combo_ready() -> bool:
	if DebugMode.is_active():
		await _debug_off()
	var ready := func() -> bool:
		return _has_control() and _isak.is_on_floor() and not _isak.is_comboing() and _isak.can_jump() \
			and not _isak.is_laser_posing()
	return await _wait_until(ready, 2.0)


## Anota y comprueba los obstaculos que el paso dice romper (`breaks`).
func _check_breaks(s: Dictionary, label: String) -> bool:
	var missing: PackedStringArray = []
	for id: Variant in s.get("breaks", []):
		var node: Node = _object(String(id))
		if node is Shutter and not (node as Shutter).is_broken():
			missing.append(String(id))
		elif node is ClearanceShelf and not (node as ClearanceShelf).is_cleared():
			missing.append(String(id))
	if not missing.is_empty():
		_note("paso %d (%s): siguen en pie %s (%s; energia %.0f)" % [_step_index, label, ", ".join(missing), _where(),
			GameState.debug_energy])
		return false
	return true


## Paso `combo_ram` (Embestida): salto vertical desde `ram.x0`, dash aereo hacia
## `ram.dir` a `ram.dash_after_s` del despegue y abajo mantenido para que el combo
## salga a los `ram.dash_frames` cuadros del dash; cae en diagonal hasta el suelo.
## El camino sigue desde la celda de despegue: si Isak aterriza en otra fila, el bot
## reanuda en el primer paso que sale de su fila y se anda desde alli.
func _ram_step(s: Dictionary) -> bool:
	var ram: Dictionary = s.get("ram", {})
	var at: Vector2 = _px(s["at"])
	var dir: float = float(ram.get("dir", 1))
	if not await _walk_to(float(ram.get("x0", at.x)), at.y):
		return false
	if not await _combo_ready() or not await _wait_dash_ready():
		_note("paso %d: la Embestida no puede empezar (%s; %s)" % [_step_index, String(_isak.dash_denial()), _where()])
		return false
	await _press_jump()
	var frames: int = roundi(float(ram.get("dash_after_s", 0.2)) * 60.0)
	var held: int = 0
	while held < frames:
		_set_axis(0.0)
		if held >= 6 and Input.is_action_pressed(A_JUMP) and _isak.velocity.y >= 0.0:
			_release_jump()
		await _tick()
		if not get_tree().paused:
			held += 1
	_set_axis(dir)
	_tap(A_DASH)
	var started: bool = await _wait_until(func() -> bool: return _isak.is_dashing(), 0.1)
	_release_jump()
	if not started:
		_set_axis(0.0)
		_combo_denials.append("%d:dash %s" % [_step_index, String(_isak.dash_denial())])
		_note("paso %d: el dash de la Embestida no sale (%s; %s)" % [_step_index, String(_isak.dash_denial()), _where()])
		return false
	_dashes += 1
	var down_at: int = maxi(0, int(ram.get("dash_frames", 1)) - _combo_hold_frames())
	var count: int = 0
	while count < down_at and _isak.is_dashing():
		await _tick()
		count += 1
	_hold(A_DOWN, true)
	var rammed: bool = await _wait_until(func() -> bool: return _isak.is_comboing(), 0.4)
	if not rammed:
		_hold(A_DOWN, false)
		_set_axis(0.0)
		_combo_denials.append("%d:ram %s" % [_step_index, String(_isak.combo_denial(Isak.COMBO_RAM))])
		_note("paso %d: la Embestida no sale (%s; %s)" % [_step_index, String(_isak.combo_denial(Isak.COMBO_RAM)), _where()])
		return false
	_rams += 1
	await _wait_until(func() -> bool: return not _isak.is_comboing() and _isak.is_on_floor(), 3.0)
	_hold(A_DOWN, false)
	_set_axis(0.0)
	await _settle()
	var land: Array = ram.get("land_px", [at.x, at.y])
	_note("Embestida %d desde x=%.0f hacia %+.0f: aterriza en %s (camino %.0f, %.0f; energia %.0f)" % [_rams,
		float(ram.get("x0", at.x)), dir, _where(), float(land[0]), float(land[1]), GameState.debug_energy])
	if _isak.is_dead() or not _check_breaks(s, "Embestida"):
		return false
	_resume_after_landing()
	return true


## Tras un movimiento que deja a Isak fuera de la celda del camino: si esta en otra
## fila, salta hasta el primer paso que sale de su fila y se anda desde su x.
func _resume_after_landing() -> void:
	var pos: Vector2 = _isak.global_position
	for k: int in range(_step_index + 1, _steps.size()):
		var n: Dictionary = _steps[k]
		var origin: Vector2
		if n.has("from"):
			origin = _px(n["from"])
		elif n.has("at"):
			origin = _px(n["at"])
		else:
			continue
		if absf(origin.y - pos.y) < ROW_TOL and _walkable(pos.x, origin.x, pos.y):
			if k > _step_index + 1:
				_skip_until = k
				_note("tras la Embestida sigue en el paso %d (salta %d paso(s) del camino desde la celda de despegue)" % [
					k, k - _step_index - 1])
			return
	_note("tras la Embestida: ningun paso sale de la fila de %s" % _where())


func _do_step(s: Dictionary) -> bool:
	if _skip_until > _step_index:
		if _verbose:
			_note("paso %d (%s): saltado (Isak ya aterrizo mas adelante)" % [_step_index, _describe(s)])
		return true
	_skip_until = -1
	return await _mall_do_step(s)


## Paso `combo_edge` (Filo): comprimido, salto (en el sitio o andando, `jump`) desde
## `takeoff_x_px` y Deslizar a `dash_after_s` del despegue hacia `dir`; tras el tramo
## sigue comprimido hacia `dir` hasta aterrizar (o frena en `target_x_px`).
func _edge_step(s: Dictionary) -> bool:
	var dir: float = float(s.get("dir", 1))
	var from: Vector2 = _px(s["from"])
	var to: Vector2 = _px(s["to"])
	var takeoff: float = float(s.get("takeoff_x_px", from.x))
	var jump: Dictionary = s.get("jump", {})
	var standing: bool = jump.get("target_x_px", null) != null and absf(float(jump["target_x_px"]) - takeoff) < 8.0
	var after_target: Variant = s.get("target_x_px", null)
	if not _isak.is_compressed():
		return _fail("paso %d: el Filo pide estar comprimido" % _step_index)
	if not await _combo_ready():
		return false
	if standing:
		if not await _walk_to(takeoff, from.y):
			return false
	else:
		var back: float = takeoff - dir * 26.0
		if (_isak.global_position.x - back) * dir > 0.0 and _ground_at(back, from.y):
			if not await _walk_to(back, from.y):
				return false
		var limit: int = 240
		while limit > 0 and (takeoff - _isak.global_position.x) * dir > 2.0:
			if not _isak.is_on_floor() or absf(_isak.global_position.y - from.y) > ROW_TOL:
				_set_axis(0.0)
				return false
			_set_axis(dir)
			await _tick()
			limit -= 1
	await _press_jump()
	var frames: int = roundi(float(s.get("dash_after_s", 0.15)) * 60.0)
	var held: int = 0
	while held < frames:
		_set_axis(0.0 if standing else dir)
		await _tick()
		if not get_tree().paused:
			held += 1
	_set_axis(dir)
	_tap(A_DASH)
	var started: bool = await _wait_until(func() -> bool: return _isak.is_comboing(), 0.1)
	_release_jump()
	if not started:
		_set_axis(0.0)
		_combo_denials.append("%d:edge %s" % [_step_index, String(_isak.combo_denial(Isak.COMBO_EDGE))])
		_note("paso %d: el Filo no sale (%s; %s)" % [_step_index, String(_isak.combo_denial(Isak.COMBO_EDGE)), _where()])
		return false
	_edges += 1
	var budget: int = 60 * 3
	var left_floor: bool = not _isak.is_on_floor()
	while budget > 0:
		var edging: bool = _isak.is_comboing()
		if not _isak.is_on_floor():
			left_floor = true
		elif not edging and left_floor:
			break
		var axis: float = dir
		if not edging and after_target != null:
			var vx: float = _isak.velocity.x
			var err: float = float(after_target) - (_isak.global_position.x + vx * absf(vx) / (2.0 * _isak.physics.air_acceleration))
			axis = clampf(err / 16.0, -1.0, 1.0) if absf(err) > 2.0 else 0.0
		_set_axis(axis)
		await _tick()
		if _isak.is_dead():
			return false
		budget -= 1
	_set_axis(0.0)
	await _settle()
	var ok: bool = _isak.is_on_floor() and absf(_isak.global_position.y - to.y) < ROW_TOL and _isak.is_compressed()
	_note("Filo %d desde x=%.0f hacia %+.0f: llega a %s (camino celda %s; ranuras %s; energia %.0f)" % [_edges, takeoff,
		dir, _where(), str(s["to"].get("cell", "?")), str(s.get("rails", [])), GameState.debug_energy])
	return ok


## Paso `combo_quake` (Sismo): comprimido en `quake.x_px`, salto en el sitio y abajo
## mantenido al subir; cae en vertical y la onda recorre la planta.
func _quake_step(s: Dictionary) -> bool:
	var quake: Dictionary = s.get("quake", {})
	var at: Vector2 = _px(s["at"])
	if not _isak.is_compressed():
		return _fail("paso %d: el Sismo pide estar comprimido" % _step_index)
	if not await _walk_to(float(quake.get("x_px", at.x)), at.y):
		return false
	if not await _combo_ready():
		return false
	await _press_jump()
	var rise: int = 0
	while rise < 40 and (_isak.is_on_floor() or _isak.velocity.y < -120.0):
		_set_axis(0.0)
		await _tick()
		rise += 1
	_release_jump()
	_hold(A_DOWN, true)
	var started: bool = await _wait_until(func() -> bool: return _isak.is_comboing(), 0.4)
	if not started:
		_hold(A_DOWN, false)
		_combo_denials.append("%d:quake %s" % [_step_index, String(_isak.combo_denial(Isak.COMBO_QUAKE))])
		_note("paso %d: el Sismo no sale (%s; %s)" % [_step_index, String(_isak.combo_denial(Isak.COMBO_QUAKE)), _where()])
		return false
	_quakes += 1
	await _wait_until(func() -> bool: return not _isak.is_comboing() and _isak.is_on_floor(), 3.0)
	_hold(A_DOWN, false)
	await _settle()
	_note("Sismo %d en x=%.0f: %s (energia %.0f)" % [_quakes, float(quake.get("x_px", at.x)), _where(), GameState.debug_energy])
	return _check_breaks(s, "Sismo")


## Suscripcion del paso: la del nivel por id o la que suelta la puerta de `trampa:<id>`.
func _subscription_of(s: Dictionary) -> Subscription:
	var id: String = String(s.get("target", {}).get("id", ""))
	if id.begins_with(TRAP_PREFIX):
		var door := _object(id.substr(TRAP_PREFIX.length())) as ShortcutDoor
		return door.get_trap_spawn() as Subscription if door != null else null
	return _object(id) as Subscription


func _wait_step(s: Dictionary) -> bool:
	if String(s.get("target", {}).get("type", "")) != "subscription":
		return await super._wait_step(s)
	var sub := _subscription_of(s)
	_set_axis(0.0)
	var ok: bool = await _wait_until(func() -> bool:
		return sub == null or sub.is_attached() or sub.is_stunned() or sub.is_defeated(),
		float(s.get("seconds", 0.0)) + WAIT_SLACK_S)
	_note("Suscripcion %s: %s (camino %.1f s; %s)" % [s.get("target", {}).get("id", "?"),
		String(sub.get_state()) if sub != null else "sin nodo", float(s.get("seconds", 0.0)), _where()])
	return ok


## Paso `cancel_subscription`: pulso con la Suscripcion enganchada (o al alcance, aturdida).
func _cancel_step(s: Dictionary) -> bool:
	var sub := _subscription_of(s)
	if sub == null:
		# La de la trampa puede tardar unos cuadros en salir al cruzar la puerta.
		await _wait_until(func() -> bool: return _subscription_of(s) != null, 1.0)
		sub = _subscription_of(s)
	if sub == null:
		return _fail("paso %d: no hay Suscripcion %s" % [_step_index, s.get("target", {}).get("id", "?")])
	var done := func() -> bool: return sub.is_stunned() or sub.is_defeated() or sub.is_spent()
	_set_axis(0.0)
	if not sub.is_attached() and not done.call():
		await _wait_until(func() -> bool: return sub.is_attached() or done.call(), 3.0)
	for attempt: int in 3:
		if done.call():
			break
		await _wait_can_pulse()
		if not sub.is_attached():
			var dir: float = signf(sub.get_center().x - _isak.global_position.x)
			if dir != 0.0 and dir != signf(_isak.facing):
				await _face(dir)
		_tap(A_PULSE)
		await _wait_until(done, 0.5)
	var ok: bool = done.call()
	_note("Suscripcion %s cancelada con el pulso: %s (%s; saldo %d)" % [sub.name, String(sub.get_state())
		if ok else "SIN EFECTO", _where(), GameState.attention_points])
	return ok


## Laser a una Suscripcion aturdida: dispara hacia ella hasta derrotarla.
func _laser_step(s: Dictionary) -> bool:
	if String(s.get("target", {}).get("type", "")) != "subscription":
		return await super._laser_step(s)
	var sub := _subscription_of(s)
	if sub == null or sub.is_defeated():
		return true
	_set_axis(0.0)
	for attempt: int in 4:
		if sub.is_defeated():
			break
		# Cancelada, cae a la espalda de Isak (attach_offset, 20 px detras): pegada al celular el rayo sale ya pasado.
		# Se aparta LASER_GAP_PX por el lado del camino (o el otro si no hay suelo) y dispara de cara a ella.
		var dx: float = sub.get_center().x - _isak.global_position.x
		if absf(dx) < LASER_GAP_PX and sub.is_laser_vulnerable():
			var side: float = float(s.get("facing", 1))
			var x: float = sub.get_center().x + side * LASER_GAP_PX
			if not _ground_at(x, _isak.global_position.y):
				x = sub.get_center().x - side * LASER_GAP_PX
			await _walk_to(x, _isak.global_position.y)
		var dir: float = signf(sub.get_center().x - _isak.global_position.x)
		if dir == 0.0:
			dir = float(s.get("facing", 1))
		await _face(dir)
		await _wait_until(func() -> bool:
			return _has_control() and _isak.can_start_laser() and _isak.get_laser_cooldown_left() <= 0.0 \
				and not _isak.is_laser_posing(), 1.0)
		if _verbose:
			_note("laser %d a %s: estado %s, centro %s, cuerpo %s; Isak %s mira %+.0f, laser listo %s" % [attempt, sub.name,
				String(sub.get_state()), sub.get_center(), sub.get_body_rect(), _isak.global_position, _isak.facing,
				_isak.can_start_laser()])
		_tap(A_LASER)
		await _wait_until(func() -> bool: return sub.is_defeated(), 0.5)
		await _wait_until(func() -> bool: return not _isak.is_laser_posing(), 0.5)
	var ok: bool = sub.is_defeated()
	_note("laser a la Suscripcion %s: %s (%s; energia %.0f)" % [sub.name, "derrotada" if ok else "SIN DERROTAR",
		_where(), GameState.debug_energy])
	return ok


## Pasos `buy`, `pay_door` y `refund`: pulso de espaldas al objeto desde la x del camino.
func _pay_step(s: Dictionary, action: String) -> bool:
	var target: Dictionary = s.get("target", {})
	var id: String = String(target.get("id", ""))
	var node: PayPoint = _object(id) as PayPoint
	if node == null:
		return _fail("paso %d: no hay %s %s" % [_step_index, target.get("type", "?"), id])
	var done: Callable
	var before_spent: int = _spent
	var before_refunded: int = _refunded
	match action:
		"buy":
			done = func() -> bool: return _spent > before_spent
		"pay_door":
			done = func() -> bool: return (node as ShortcutDoor).is_open()
		_:
			done = func() -> bool: return _refunded > before_refunded or (node as RefundDesk).is_closed()
	var at: Vector2 = _px(s["at"])
	var facing: float = float(s.get("facing", 1))
	if not await _walk_to(float(s.get("x_px", at.x)), at.y):
		return false
	for attempt: int in 3:
		if done.call():
			break
		await _face(facing)
		await _wait_can_pulse()
		_tap(A_PULSE)
		await _wait_until(done, 0.6)
	var ok: bool = done.call()
	await _wait_side()
	if ok and action == "buy":
		_purchases.append("%s (%d)" % [id, int(s.get("cost", 0))])
	_note("%s %s con el pulso de espaldas: %s (%s; saldo %d, camino %s; energia %.0f)" % [action, id,
		"hecho" if ok else "SIN EFECTO", _where(), GameState.attention_points, str(s.get("balance_after", "-")),
		GameState.debug_energy])
	return ok


## Paso `wait_countdown`: en la celda del camino hasta que la cuenta de su objetivo
## este desplegada con tiempo para cruzarla.
func _wait_countdown(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if absf(_isak.global_position.x - at.x) > TILE * 0.5 or absf(_isak.global_position.y - at.y) >= ROW_TOL:
		if not await _walk_to(at.x, at.y):
			return false
	var cd := _object(String(s.get("target", {}).get("id", ""))) as CountdownPlatform
	return await _countdown_ready(cd, float(s.get("seconds", 0.0)) + 8.0)


func _countdown_ready(cd: CountdownPlatform, seconds: float) -> bool:
	if cd == null:
		return true
	_set_axis(0.0)
	var ready := func() -> bool:
		return cd.is_solid() and not cd.is_waiting() and cd.get_time_left() >= COUNTDOWN_NEED_S
	if ready.call():
		return true
	_countdown_waits += 1
	var start: int = _play_frames
	var ok: bool = await _wait_until(ready, seconds)
	_note("cuenta regresiva %s: %s tras %.1f s (quedan %.1f s; %s)" % [cd.name, "lista" if ok else "SIN DESPLEGAR",
		(_play_frames - start) / 60.0, cd.get_time_left(), _where()])
	return ok


## Cuenta regresiva bajo la celda de llegada (fila de los pies + 1), o null.
func _countdown_at(feet: Vector2) -> CountdownPlatform:
	if not is_instance_valid(_level):
		return null
	var probe := Vector2(feet.x, feet.y + 8.0)
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is CountdownPlatform and (node as CountdownPlatform).get_card_rect().grow(4.0).has_point(probe):
			return node as CountdownPlatform
	return null


## Salto a una cuenta regresiva: antes, la espera desplegada con tiempo. Con el tiron de
## una Oferta hacia donde se salta, despegue adelantado (ver _pulled_takeoff).
func _jump(s: Dictionary, action: String) -> bool:
	if s.has("to") and action != "fall":
		var cd := _countdown_at(_px(s["to"]))
		if cd != null and not await _countdown_ready(cd, cd.get_count_s() + cd.get_fold_s() + 2.0):
			return false
	return await super._jump(_pulled_takeoff(s, float(s.get("direction", 1))), action)


## Cajas sorpresa: el validador las trata como una celda solida (tapa a ras de la fila) y la caja real mide 56 x 56
## (la tapa queda 8 px por debajo). Un punto del camino encima de una caja cerrada lleva los pies a su tapa.
func _px(p: Dictionary) -> Vector2:
	var v: Vector2 = super._px(p)
	var top: float = _box_top_at(v)
	return Vector2(v.x, top) if not is_nan(top) else v


## Tapa (y global) de una caja sorpresa solida bajo `feet` (±12 px en vertical), o NAN.
func _box_top_at(feet: Vector2) -> float:
	if not is_instance_valid(_level):
		return NAN
	for node: Node in _level.get_node(^"Objects").get_children():
		var box := node as SurpriseBox
		if box == null or not box.is_solid():
			continue
		var r: Rect2 = box.get_body_rect()
		if feet.x >= r.position.x - TILE * 0.5 and feet.x <= r.end.x + TILE * 0.5 and absf(feet.y - r.position.y) <= 12.0:
			return r.position.y
	return NAN


## De pie en la tapa de una caja no es «sobre un enemigo aturdido».
func _off_grid() -> bool:
	if _isak != null and not is_nan(_box_top_at(_isak.global_position)):
		return false
	return super._off_grid()


## Tramo andando que acaba en el despegue de un salto o dash aereo con el tiron a
## favor: termina en el despegue adelantado (si no, llega a el lanzado y lo pasa).
func _mall_do_step(s: Dictionary) -> bool:
	if String(s.get("action", "")) == "walk" and _step_index + 1 < _steps.size():
		var n: Dictionary = _steps[_step_index + 1]
		var kind: String = String(n.get("action", ""))
		var dir: float = float(n.get("dir", n.get("direction", 0)))
		if (kind == "dash" and bool(n.get("air", false))) or kind in ["jump", "jump_run"]:
			var shifted: Dictionary = _pulled_takeoff(n, dir)
			var x: float = float(shifted.get("takeoff_x_px", 0.0))
			if shifted != n and (_px(s["to"]).x - x) * dir > 0.0:
				var out: Dictionary = s.duplicate(true)
				out["to"]["feet_px"] = [x, float(s["to"]["feet_px"][1])]
				return await super._do_step(out)
	return await super._do_step(s)


func _dash_step(s: Dictionary) -> bool:
	if bool(s.get("air", false)):
		s = _pulled_takeoff(s, float(s.get("dir", 1)))
	elif s.has("takeoff_x_px") and s.has("from"):
		# Dash en el suelo pasado ya el despegue (la frenada del dash anterior; en las tapas de 56 px de las cajas del
		# 5-1, salir 20 px tarde deja a Isak fuera de la caja siguiente): vuelve al despegue.
		var dir: float = float(s.get("dir", 1))
		var takeoff: float = float(s["takeoff_x_px"])
		if (_isak.global_position.x - takeoff) * dir > 4.0:
			await _walk_to(takeoff, _px(s["from"]).y)
	if await super._dash_step(s):
		return true
	# Cae a una fila mas baja y se posa antes en una plataforma de una via que asoma (5-1, Cierre del comprador: la
	# de la fila 10 en las columnas 251-252 a 8 px del arco del validador): sigue hacia `dir` hasta la fila del camino.
	var to: Vector2 = _px(s["to"])
	var d: float = float(s.get("dir", 1))
	if _isak.is_dead() or not _isak.is_on_floor() or to.y - _isak.global_position.y < TILE * 0.5 \
			or absf(to.x - _isak.global_position.x) > TILE * 1.5:
		return false
	var limit: int = 60
	while limit > 0 and not (_isak.is_on_floor() and absf(_isak.global_position.y - to.y) < ROW_TOL):
		_set_axis(d if (to.x - _isak.global_position.x) * d > 0.0 or _isak.is_on_floor() else 0.0)
		await _tick()
		limit -= 1
	_set_axis(0.0)
	var ok: bool = _isak.is_on_floor() and absf(_isak.global_position.y - to.y) < ROW_TOL
	_note("paso %d (dash): sigue hasta la fila del camino: %s (%s)" % [_step_index, "llega" if ok else "NO LLEGA", _where()])
	return ok


## Despegue con el tiron de una Oferta a favor: el camino supone llegar al despegue
## andando a 220 px/s y saltar TAKEOFF_PAUSE_FRAMES despues; acercandose a una Oferta
## Isak va a 220 x 1,15 + 60 = 313 px/s y en esos cuadros (y en el arranque del salto)
## recorre PULL_TAKEOFF_PX de mas. El bot despega ese tanto antes (5-1, carrito del
## Inicio: el pincho queda a 12 px del despegue del camino).
const PULL_TAKEOFF_PX: float = 24.0


func _pulled_takeoff(s: Dictionary, dir: float) -> Dictionary:
	if not s.has("takeoff_x_px") or not s.has("from") or dir == 0.0:
		return s
	var from: Vector2 = _px(s["from"])
	var point := Vector2(float(s["takeoff_x_px"]), from.y - _isak.get_hitbox_size().y * 0.5)
	var weight: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(TemptationField.GROUP):
		if node.has_method(TemptationField.PULL_METHOD):
			weight += float(node.call(TemptationField.PULL_METHOD, point))
	if signf(weight) != signf(dir):
		return s
	var out: Dictionary = s.duplicate()
	out["takeoff_x_px"] = float(s["takeoff_x_px"]) - dir * PULL_TAKEOFF_PX
	if _verbose:
		_note("paso %d: tiron a favor (peso %+.1f): despegue %.0f -> %.0f" % [_step_index, weight,
			float(s["takeoff_x_px"]), float(out["takeoff_x_px"])])
	return out
