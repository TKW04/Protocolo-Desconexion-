## Capturas a 1:1 (1280x720) del hub REAL (scenes/hub/hub.tscn, abierto
## directamente; en el juego se llega al completar un nivel: la llegada tras
## el 1-1 la captura el bot, tools/play_level_bot.gd --shots) con el arte final. Usa
## su propio guardado (user://render_hub_save.json, se borra al terminar), nunca
## el del jugador. Antes de entrar simula haber completado el 1-1 con 9 puntos
## (cambios sin guardar), con Eco conocido y tres ayudas aprendidas; Notas y Calc
## aun no se conocen (primera entrada al hub).
##   01_llegada_vortice.png      Isak materializandose en P por el vortice; Notas y Calc apagadas
##   02_notas_apagada.png        llegada terminada: Eco empieza a presentar a Notas (aun apagada)
##   02b_eco_presenta_notas.png  linea de Eco escrita (atenuado, sin cobertura)
##   02c_notas_habla.png         Notas encendida habla con su nombre e icono
##   03_notas_prompt.png         Isak junto a Notas: tecla del pulso
##   04_notas_panel.png          panel de Notas (resumen; Guardar / Álbum / Apodo / Volver)
##   05_notas_confirmar.png      confirmacion «¿Guardar en Notas?»
##   06_copia_guardada.png       «Apuntado. Copia guardada», destello y el indicador apagado
##   06a_album_carpetas.png      album: vista de carpetas por mundo (Notificaciones: solo el
##                               nombre, miniatura y contador; los demas con candado y «???»)
##   06b_album_objetos.png       carpeta del Mundo 1 abierta, pestana Objetos: fichas
##                               aprendidas y siluetas «???»
##   06c_album_ficha.png         ficha abierta (dibujo x2, nombre y texto de Eco)
##   06d_album_enemigos.png      pestana Enemigos (Burbuja y punto rojo aprendidos; banner «???»)
##   06e_album_punto_rojo.png    ficha del punto rojo (1-2)
##   06f_album_piso_3_4.png      pestana Objetos con las fichas de los pisos 3 y 4 del 1-2
##                               (recordatorio, Posponer, pop-up translucido; la barra «???»)
##   06g_album_overlay.png       ficha del pop-up translucido
##   07a_calc_apagada.png        Isak junto a Calc apagada: sin tecla ni tienda
##   07_calc_prompt.png          Calc conocida (GameState.meet_ally, como --meet-ally=calc): tecla
##                               del pulso (simula 30 puntos para comprar)
##   08_calc_tienda.png          tienda de Calc por pistas (tanda M1): saldo, power banks, una fila por
##                               pista con su chip y 5 recuadros, detalle del siguiente nivel
##   09_calc_compra.png          «Nivel 2 instalado: Pulso amplio.» (25 puntos menos; 2 de 5;
##                               «Sin guardar» de nuevo)
##   10_calc_faltan_puntos.png   Sync Rate elegida: «Faltan 10 puntos.»
## (todos los estados de la tienda: tools/render_calc_shop.gd)
##   10a_cargador_listo.png      cargador del dock (columna 16) listo; Isak acercandose con la
##                               energia a 20 (simula haber disparado el laser)
##   10b_cargador_recarga.png    Isak tocandolo: +50 de energia (70) y empieza el enfriamiento
##   10c_cargador_enfriando.png  Isak se aparta: el cargador a mitad de los 20 s de enfriamiento
##   11_carpeta_prompt.png       Isak en la repisa de M1: tecla del pulso
##   12_panel_subniveles.png     panel de subniveles de M1 (1-1 completado, 1-2 sin desbloquear, 1-3 Proximamente)
##   13_carpeta_bloqueada.png    Isak en la repisa de M2: «Sin descargar»
##   14_confirmar_sin_guardar.png elegir el 1-1 con cambios sin guardar (la compra):
##                               «¿Seguro? Aún no has guardado.» (Entrar sin guardar / Volver)
##   15_entrar_vortice.png       tras «Entrar sin guardar»: Isak de espaldas absorbido por el vortice
##                               (el nivel no se carga: scene_switcher lo descarta)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_hub.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://hub"
const SAVE_PATH: String = "user://render_hub_save.json"
const TILE: float = 64.0
const WAIT_FRAMES: int = 60 * 20

var _hub: Node
var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"use_save_path", SAVE_PATH, true)
	state.set(&"current_level", &"1-1")
	for i: int in 9:
		state.call(&"capture_attention_point", &"1-1", StringName("punto_%d" % i), 1)
	state.call(&"mark_level_completed", &"1-1")
	state.call(&"meet_ally", &"eco")
	state.call(&"obtain_ability", &"pulse")  # el regalo de Eco (la pista del Pulso de la tienda lo pide)
	for id: StringName in [&"alert_bubble", &"receiver", &"attention_point", &"bridge", &"notification_badge",
			&"reminder_platform", &"snooze_button", &"overlay_popup"]:
		state.call(&"learn_help", id)
	_hub = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_hub)
	# 1. Llegada: el vortice cerrandose con Isak a medias.
	var vortex: Node = _hub.call(&"get_arrival_vortex")
	_check(vortex != null, "no hay vortice de llegada")
	_check(await _wait(func() -> bool:
		return is_instance_valid(vortex) and int(vortex.call(&"get_phase")) == 3 \
			and (vortex.get_node(^"Sprite") as AnimatedSprite2D).frame >= 1), "el vortice no se cierra")
	await _save_frozen(out_dir, "01_llegada_vortice.png")
	_check(await _wait(func() -> bool: return _hub.call(&"has_arrived")), "Isak no llega")
	var notas: Node = _hub.call(&"get_notas")
	var box: Node = _hub.call(&"get_text_box")
	_check(not notas.call(&"is_powered"), "Notas deberia estar apagada")
	await _save(out_dir, "02_notas_apagada.png")
	# 2b-2c. Presentacion de Notas (el arbol esta en pausa: capturas sin congelar).
	box.call(&"finish_typing")
	await _frames(4)
	await _save(out_dir, "02b_eco_presenta_notas.png")
	await _close_line(box)
	_check(notas.call(&"is_powered"), "Notas no se enciende")
	box.call(&"finish_typing")
	await _frames(4)
	await _save(out_dir, "02c_notas_habla.png")
	await _close_line(box)
	await _close_line(box)
	_check(state.call(&"has_met_ally", &"notas") and not paused, "la presentacion no termina")
	await _frames(10)
	# 3. Junto a Notas.
	var station: Node = notas
	var isak: Node2D = _hub.call(&"get_isak")
	var fake: RefCounted = (load("res://scripts/player/player_input.gd") as GDScript).new()
	isak.set(&"input", fake)
	fake.set(&"move_axis", -1.0)
	_check(await _wait(func() -> bool: return isak.global_position.x < 3.0 * TILE), "Isak no llega a la estacion")
	isak.global_position = Vector2(2.6 * TILE, isak.global_position.y)
	fake.set(&"move_axis", 0.0)
	await _frames(30)
	_check(station.call(&"is_key_hint_visible"), "no sale la tecla del pulso")
	await _save(out_dir, "03_notas_prompt.png")
	# 4. Pulso: panel abierto con Isak de espaldas.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool: return station.call(&"is_panel_open") and isak.call(&"is_facing_back")),
		"no se abre el panel")
	await _frames(20)
	await _save(out_dir, "04_notas_panel.png")
	var panel: Node = station.call(&"get_notas_panel")
	panel.call(&"select_option", &"save")
	panel.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "05_notas_confirmar.png")
	panel.call(&"select_option", &"yes")
	panel.call(&"confirm")
	_check(not state.call(&"has_unsaved_changes"), "no se guardo")
	await _frames(2)
	await _save_frozen(out_dir, "06_copia_guardada.png")
	# 6b-6d. Album.
	panel.call(&"select_option", &"album")
	panel.call(&"confirm")
	var album: Node = station.call(&"get_album")
	_check(album.call(&"is_open"), "no se abre el album")
	await _frames(4)
	_check(album.call(&"get_mode") == 0, "el album no abre en la vista de carpetas")
	await _save(out_dir, "06a_album_carpetas.png")
	_check(album.call(&"open_folder", 1), "no se abre la carpeta del Mundo 1")
	album.call(&"set_tab", "object")
	album.call(&"select_cell", 2)
	await _frames(4)
	await _save(out_dir, "06b_album_objetos.png")
	album.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "06c_album_ficha.png")
	album.call(&"cancel")
	album.call(&"set_tab", "enemy")
	await _frames(4)
	await _save(out_dir, "06d_album_enemigos.png")
	album.call(&"select_cell", 1)
	album.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "06e_album_punto_rojo.png")
	album.call(&"cancel")
	album.call(&"set_tab", "object")
	var objects: Array = (load("res://scripts/hub/notas_album.gd") as GDScript).call(&"album_ids", 1, "object")
	album.call(&"select_cell", objects.find(&"overlay_popup"))
	await _frames(4)
	await _save(out_dir, "06f_album_piso_3_4.png")
	album.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "06g_album_overlay.png")
	album.call(&"cancel")
	album.call(&"cancel")
	album.call(&"cancel")
	await _frames(2)
	panel.call(&"cancel")
	_check(await _wait(func() -> bool: return not isak.call(&"is_facing_back")), "no se cierra Notas")
	# 7a. Calc apagada: Isak a su izquierda, sin tecla del pulso.
	state.set(&"attention_points", 30)
	var calc: Node = _hub.call(&"get_calc")
	isak.global_position = Vector2(6.4 * TILE, isak.global_position.y)
	await _nudge(fake, 1.0)
	await _frames(30)
	_check(not calc.call(&"is_powered") and not calc.call(&"is_key_hint_visible"), "Calc deberia estar apagada")
	await _save(out_dir, "07a_calc_apagada.png")
	# 7. Calc conocida (el encuentro del 1-2 aun no existe).
	state.call(&"meet_ally", &"calc")
	await _frames(30)
	_check(calc.call(&"is_key_hint_visible"), "no sale la tecla del pulso junto a Calc")
	await _save(out_dir, "07_calc_prompt.png")
	# 8. Pulso: tienda de Calc.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool: return calc.call(&"is_panel_open") and isak.call(&"is_facing_back")),
		"no se abre la tienda de Calc")
	await _frames(20)
	await _save(out_dir, "08_calc_tienda.png")
	# 9. Comprar Pulso amplio (la primera).
	var shop: Node = calc.call(&"get_calc_panel")
	shop.call(&"select_option", &"pulso")
	shop.call(&"confirm")
	_check(state.call(&"is_upgrade_purchased", &"wide_pulse"), "no se compra Pulso amplio (Pulso 2)")
	_check(state.call(&"has_unsaved_changes"), "comprar no marca sin guardar")
	await _frames(4)
	await _save(out_dir, "09_calc_compra.png")
	shop.call(&"finish_buy_animation")
	# 10. Sin puntos para el Sync Rate 2 (15; quedan 5).
	shop.call(&"select_option", &"sync")
	shop.call(&"confirm")
	_check(not state.call(&"is_upgrade_purchased", &"sync:2"), "compra sin puntos")
	await _frames(4)
	await _save(out_dir, "10_calc_faltan_puntos.png")
	shop.call(&"cancel")
	_check(await _wait(func() -> bool: return not isak.call(&"is_facing_back")), "no se cierra la tienda")
	# 10a-10c. Cargador del dock (el mismo objeto charger de los niveles).
	var charger: Node2D = _hub.call(&"get_charger")
	_check(charger != null, "no hay cargador en el hub")
	state.set(&"debug_energy", 20.0)
	isak.global_position = Vector2(charger.position.x - 1.6 * TILE, isak.global_position.y)
	await _nudge(fake, 1.0)
	await _frames(20)
	_check(charger.call(&"is_ready"), "el cargador no esta listo")
	await _save(out_dir, "10a_cargador_listo.png")
	fake.set(&"move_axis", 1.0)
	_check(await _wait(func() -> bool: return not charger.call(&"is_ready")), "Isak no recarga en el cargador")
	fake.set(&"move_axis", 0.0)
	_check(is_equal_approx(float(state.get(&"debug_energy")), 70.0), "el cargador no repone 50")
	await _frames(12)
	await _save(out_dir, "10b_cargador_recarga.png")
	isak.global_position = Vector2(charger.position.x - 1.8 * TILE, isak.global_position.y)
	await _nudge(fake, 1.0)
	charger.call(&"advance", float(charger.get(&"cooldown_s")) * 0.5)
	await _frames(12)
	_check(not charger.call(&"is_ready"), "el cargador deberia seguir enfriandose")
	await _save(out_dir, "10c_cargador_enfriando.png")
	# 11. Carpeta M1: Isak de pie en su repisa.
	var folder: Node2D = _hub.call(&"get_folder", &"m1")
	isak.global_position = Vector2(folder.position.x + 96.0, float(_hub.call(&"get_shelf_top_y")))
	await _nudge(fake, -1.0)
	await _frames(30)
	_check(folder.call(&"is_key_hint_visible"), "no sale la tecla del pulso en la carpeta")
	await _save(out_dir, "11_carpeta_prompt.png")
	# 12. Pulso: panel de subniveles.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	# Con ventana el ritmo de cuadros varia: si el pulso no la deja abierta, se
	# abre directamente (la apertura por pulso ya la cubren las pruebas).
	if not await _wait(func() -> bool: return folder.call(&"is_panel_open")):
		await _wait(func() -> bool: return int(folder.call(&"get_state")) <= 1)
		folder.call(&"open", isak)
	_check(folder.call(&"is_panel_open"), "no se abre el panel de la carpeta")
	await _frames(20)
	await _save(out_dir, "12_panel_subniveles.png")
	var folder_panel: Node = folder.call(&"get_folder_panel")
	folder_panel.call(&"cancel")
	_check(await _wait(func() -> bool: return not isak.call(&"is_facing_back")), "no se cierra la carpeta")
	# 13. Carpeta bloqueada (M2).
	var locked: Node2D = _hub.call(&"get_folder", &"m2")
	isak.global_position = Vector2(locked.position.x + 32.0, float(_hub.call(&"get_shelf_top_y")))
	await _nudge(fake, 1.0)
	await _frames(30)
	_check(locked.call(&"is_locked_hint_visible"), "no sale «Sin descargar»")
	await _save(out_dir, "13_carpeta_bloqueada.png")
	# 14. Elegir el 1-1 con cambios sin guardar: confirmacion.
	_hub.set(&"scene_switcher", func(runner: Node) -> void: runner.free())
	isak.global_position = Vector2(folder.position.x + 96.0, float(_hub.call(&"get_shelf_top_y")))
	await _frames(30)
	folder.call(&"open", isak)
	folder_panel.call(&"select_option", &"1-1")
	folder_panel.call(&"confirm")
	_check(folder_panel.call(&"is_confirming_unsaved"), "no pide confirmar con cambios sin guardar")
	await _frames(4)
	await _save(out_dir, "14_confirmar_sin_guardar.png")
	# 15. Entrar sin guardar: vortice de salida (sin cargar el nivel).
	folder_panel.call(&"select_option", &"enter_unsaved")
	folder_panel.call(&"confirm")
	var departure: Node = _hub.call(&"get_departure_vortex")
	_check(departure != null, "no hay vortice de salida")
	_check(await _wait(func() -> bool:
		return is_instance_valid(departure) and int(departure.call(&"get_phase")) == 3), "el vortice de salida no se cierra")
	await _save_frozen(out_dir, "15_entrar_vortice.png")
	_check(await _wait(func() -> bool: return not _hub.is_inside_tree()), "no se pasa al nivel")
	print("render_hub: %s" % ("OK" if _ok else "FALLO"))
	if is_instance_valid(_hub):
		_hub.queue_free()
	await process_frame
	state.call(&"use_save_path", SAVE_PATH, true)
	quit(0 if _ok else 1)


## Cierra la linea importante del cuadro de texto como el jugador.
func _close_line(box: Node) -> void:
	var text: String = box.call(&"get_text")
	box.call(&"finish_typing")
	box.call(&"confirm")
	await _wait(func() -> bool: return box.call(&"get_text") != text)
	await _frames(2)


## Un paso de fisica moviendose hacia `axis`: corta la animacion de la terminal
## holografica (idle largo) y deja a Isak mirando a ese lado.
func _nudge(fake: RefCounted, axis: float) -> void:
	fake.set(&"move_axis", axis)
	await physics_frame
	await physics_frame
	fake.set(&"move_axis", 0.0)


func _wait(cond: Callable) -> bool:
	for i: int in WAIT_FRAMES:
		if cond.call():
			return true
		await process_frame
	return false


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_hub: " + why)


## Captura con el arbol en pausa (la fase actual no avanza mientras se guarda).
func _save_frozen(out_dir: String, file_name: String) -> void:
	paused = true
	await _save(out_dir, file_name)
	paused = false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_hub: %s (%s)" % [path, error_string(err)])
