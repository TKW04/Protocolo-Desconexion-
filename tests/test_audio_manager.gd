# AudioManager (2026-10-20; docs/lista-sonidos.md, «Integracion del sistema de
# audio»): catalogo data/audio.json valido y coherente con el codigo (buses,
# senales de EventBus, clases y senales de los nodos), bus inexistente (suena
# por Master), archivo ausente (se ignora en silencio), ajustes de sonido
# guardados al instante y aplicados al AudioServer, senales de ritmo
# desactivables, conexiones por senales (EventBus, nodos, ambiente) y blips del
# cuadro de texto por acceso (Cache / Kernel / Raiz).
extends GutTest

const ECO_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")

var _settings_path: String
var _lap: int
var _nodes: Array[Node] = []


func before_each() -> void:
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	_lap = GameState.lap
	AudioManager.load_catalog(AudioManager.DATA_PATH)
	AudioManager.history.clear()


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	get_tree().paused = false
	GameState.lap = _lap
	AudioManager.load_catalog(AudioManager.DATA_PATH)
	GameSettings.use_path(_settings_path, true)


func _bus_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for i: int in AudioServer.bus_count:
		out.append(String(AudioServer.get_bus_name(i)))
	return out


func _global_classes() -> Dictionary:
	var out: Dictionary = {}
	for info: Dictionary in ProjectSettings.get_global_class_list():
		out[String(info["class"])] = String(info["path"])
	return out


func _script_has_signal(script: Script, signal_name: String) -> bool:
	var current: Script = script
	while current != null:
		for info: Dictionary in current.get_script_signal_list():
			if String(info["name"]) == signal_name:
				return true
		current = current.get_base_script()
	return false


func _add(node: Node) -> Node:
	_nodes.append(node)
	add_child(node)
	return node


func _catalog_with(sounds: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = AudioManager.get_catalog().duplicate(true)
	data["sounds"] = sounds
	data["event_bus"] = []
	data["nodes"] = []
	data["ambience"] = []
	data.merge(extra, true)
	return data


# --- Catalogo ---

func test_buses_from_default_layout() -> void:
	var buses: PackedStringArray = _bus_names()
	for bus: StringName in GameSettings.AUDIO_BUSES:
		assert_true(buses.has(String(bus)), "Bus %s en default_bus_layout.tres" % bus)
	assert_eq(Array(AudioManager.get_catalog()["buses"]), Array(GameSettings.AUDIO_BUSES).map(func(b: StringName) -> String: return String(b)),
		"data/audio.json y GameSettings listan los mismos seis buses")


func test_catalog_is_valid() -> void:
	var errors: PackedStringArray = AudioManager.validate_catalog(AudioManager.get_catalog(), _bus_names())
	assert_eq(errors, PackedStringArray(), "Sin errores en data/audio.json")


func test_catalog_hooks_match_the_code() -> void:
	var data: Dictionary = AudioManager.get_catalog()
	for item: Dictionary in data["event_bus"]:
		assert_true(EventBus.has_signal(StringName(String(item["signal"]))), "EventBus.%s existe" % item["signal"])
	var classes: Dictionary = _global_classes()
	for item: Dictionary in data["nodes"]:
		var name: String = String(item["class"])
		assert_true(classes.has(name), "Clase %s" % name)
		if classes.has(name):
			assert_true(_script_has_signal(load(classes[name]) as Script, String(item["signal"])),
				"%s.%s existe" % [name, item["signal"]])
	for item: Dictionary in data["ambience"]:
		assert_true(classes.has(String(item["class"])), "Clase %s" % item["class"])
	assert_true(classes.has(String(data["steps"]["class"])))
	for speaker: Variant in data["text_blips"]["speakers"]:
		for lap: int in [GameState.LAP_EASY, GameState.LAP_NORMAL, GameState.LAP_HARD]:
			var id: StringName = AudioManager.blip_id_for(StringName(String(speaker)), lap)
			assert_true(AudioManager.has_entry(id), "Blip %s de '%s'" % [id, speaker])


func test_placeholder_sounds_exist() -> void:
	for id: StringName in [&"sfx_isak_jump", &"sfx_isak_land", &"sfx_isak_step", &"sfx_isak_pulse", &"sfx_isak_dash",
			&"sfx_isak_hurt", &"sfx_attention_point", &"sfx_memory_pickup", &"sfx_dnd_switch", &"sfx_metronome_tick",
			&"sfx_alarm_bell_wave", &"vox_eco_blip_cache", &"vox_eco_blip_kernel", &"vox_eco_blip_raiz", &"ui_confirm",
			&"ui_back", &"amb_hub"]:
		assert_true(AudioManager.has_stream(id), "%s tiene archivo provisional" % id)
	assert_eq(AudioManager.resolve_paths(&"sfx_isak_step").size(), 4, "Cuatro variantes de pasos")


func test_eco_blip_changes_with_access_and_ui_never_names_laps() -> void:
	var blips: Array = []
	for lap: int in [GameState.LAP_EASY, GameState.LAP_NORMAL, GameState.LAP_HARD]:
		blips.append(AudioManager.blip_id_for(&"", lap))
	assert_eq(blips, [&"vox_eco_blip_cache", &"vox_eco_blip_kernel", &"vox_eco_blip_raiz"])
	assert_eq(AudioManager.blip_id_for(&"calc"), &"vox_calc_blip")
	for id: Variant in AudioManager.get_catalog()["sounds"]:
		for word: String in ["vuelta", "easy", "normal", "hard"]:
			assert_false(String(id).to_lower().contains(word), "%s no nombra la vuelta" % id)


# --- Bus inexistente y archivo ausente ---

func test_missing_bus_plays_through_master() -> void:
	var data: Dictionary = _catalog_with({"sfx_raro": {"bus": "NoExiste", "files": ["sfx_isak_jump"]}})
	assert_false(AudioManager.validate_catalog(data, _bus_names()).is_empty(), "El validador lo detecta")
	AudioManager.set_catalog(data)
	assert_eq(AudioManager.bus_for(&"sfx_raro"), &"Master")
	assert_true(AudioManager.play(&"sfx_raro"), "Suena igual, por Master")
	assert_eq(AudioManager.history.back(), &"sfx_raro")


func test_missing_file_is_ignored_silently() -> void:
	AudioManager.set_catalog(_catalog_with({
		"sfx_sin_archivo": {"bus": "World", "files": ["no_existe_este_sonido"]},
		"sfx_sin_files": {"bus": "World"},
		"sfx_extension": {"bus": "World", "files": ["sfx_isak_jump.ogg"]},
	}))
	assert_false(AudioManager.has_stream(&"sfx_sin_archivo"))
	assert_false(AudioManager.play(&"sfx_sin_archivo"), "Sin archivo no suena (ni da error)")
	assert_false(AudioManager.play(&"sfx_sin_files"), "Sin files busca <id>.ogg/.wav: tampoco existe")
	assert_false(AudioManager.play(&"sfx_extension"), "Extension explicita que no existe")
	assert_false(AudioManager.play(&"no_esta_en_el_catalogo"))
	assert_true(AudioManager.history.is_empty())


func test_real_catalog_entries_without_files_are_silent() -> void:
	assert_true(AudioManager.has_entry(&"sfx_isak_death"))
	assert_false(AudioManager.has_stream(&"sfx_isak_death"), "Hueco para el sonido definitivo")
	EventBus.player_died.emit()
	assert_false(AudioManager.history.has(&"sfx_isak_death"))


func test_extension_fallback_finds_the_wav() -> void:
	AudioManager.set_catalog(_catalog_with({"sfx_isak_jump": {"bus": "World"}}))
	assert_eq(AudioManager.resolve_paths(&"sfx_isak_jump"), PackedStringArray(["res://assets/audio/sfx_isak_jump.wav"]),
		"Sin files: el ID, con la primera extension que exista")


func test_cooldown_and_variants() -> void:
	AudioManager.set_catalog(_catalog_with({
		"sfx_a": {"bus": "World", "files": ["sfx_isak_jump"], "cooldown_s": 10.0},
		"sfx_v": {"bus": "World", "files": ["sfx_isak_step_1", "sfx_isak_step_2"]},
	}))
	assert_true(AudioManager.play(&"sfx_a"))
	assert_false(AudioManager.play(&"sfx_a"), "En enfriamiento")
	assert_true(AudioManager.play(&"sfx_v"))
	assert_true(AudioManager.play(&"sfx_v"))
	assert_eq(AudioManager.playing_count(&"sfx_v"), 2, "Dos voces a la vez")


# --- Ajustes ---

func test_volume_defaults_and_persistence() -> void:
	for bus: StringName in GameSettings.AUDIO_BUSES:
		assert_almost_eq(GameSettings.get_volume(bus), 1.0, 0.001, "%s al 100 %% por defecto" % bus)
	assert_true(GameSettings.set_volume(&"Music", 0.5))
	assert_false(GameSettings.set_volume(&"Music", 0.5), "Sin cambio no hace nada")
	assert_false(GameSettings.set_volume(&"NoExiste", 0.5))
	var index: int = AudioServer.get_bus_index(&"Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01, "Aplicado al AudioServer")
	var config := ConfigFile.new()
	assert_eq(config.load(GameSettings.settings_path()), OK, "Guardado al instante")
	assert_almost_eq(float(config.get_value(GameSettings.SECTION_AUDIO, "volume_music")), 0.5, 0.001)
	GameSettings.reset_defaults()
	assert_almost_eq(GameSettings.get_volume(&"Music"), 1.0, 0.001)
	GameSettings.load_from_disk()
	assert_almost_eq(GameSettings.get_volume(&"Music"), 0.5, 0.001, "Se carga al reiniciar")
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01)


func test_volume_is_clamped_snapped_and_zero_mutes() -> void:
	GameSettings.set_volume(&"World", 1.7)
	assert_almost_eq(GameSettings.get_volume(&"World"), 1.0, 0.001)
	GameSettings.set_volume(&"World", 0.43)
	assert_almost_eq(GameSettings.get_volume(&"World"), 0.4, 0.001, "Al paso de 0,1")
	GameSettings.set_volume(&"World", -1.0)
	assert_almost_eq(GameSettings.get_volume(&"World"), 0.0, 0.001)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"World")), "0 silencia el bus")
	GameSettings.set_volume(&"World", 0.2)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"World")))


func test_bad_volume_values_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value(GameSettings.SECTION_AUDIO, "volume_ui", "fuerte")
	config.set_value(GameSettings.SECTION_AUDIO, "volume_voice", 0.3)
	config.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_almost_eq(GameSettings.get_volume(&"UI"), 1.0, 0.001, "Valor raro: por defecto")
	assert_almost_eq(GameSettings.get_volume(&"Voice"), 0.3, 0.001, "Los demas se conservan")


func test_rhythm_cues_on_by_default_and_can_be_turned_off() -> void:
	assert_true(GameSettings.are_rhythm_cues_enabled(), "Activadas por defecto (decision 2026-10-20)")
	assert_true(bool(AudioManager.get_entry(&"sfx_metronome_tick").get("cue", false)))
	assert_true(bool(AudioManager.get_entry(&"sfx_blink_warn").get("cue", false)))
	assert_true(AudioManager.play(&"sfx_metronome_tick"))
	assert_true(GameSettings.set_rhythm_cues_enabled(false))
	AudioManager.load_catalog(AudioManager.DATA_PATH)
	assert_false(AudioManager.play(&"sfx_metronome_tick"), "Desactivadas: sin tic")
	assert_true(AudioManager.play(&"sfx_isak_jump"), "Los demas sonidos siguen")
	GameSettings.reset_defaults()
	GameSettings.load_from_disk()
	assert_false(GameSettings.are_rhythm_cues_enabled(), "Guardado en settings.cfg")


# --- Conexiones ---

func test_event_bus_signal_plays_its_sound() -> void:
	EventBus.pulse_fired.emit(null)
	assert_eq(AudioManager.history.back(), &"sfx_isak_pulse")
	EventBus.dash_started.emit(1.0)
	assert_eq(AudioManager.history.back(), &"sfx_isak_dash")


func test_node_signals_with_filter() -> void:
	var menu := _add(PauseMenu.new()) as PauseMenu
	assert_true(menu.request_open())
	AudioManager.history.clear()
	menu.move_selection(1)
	assert_eq(AudioManager.history.back(), &"ui_move")
	AudioManager.load_catalog(AudioManager.DATA_PATH)  # sin el enfriamiento del ui_confirm de abrir
	menu.activate(PauseMenu.Option.SETTINGS)
	assert_eq(AudioManager.history.back(), &"ui_confirm")
	menu.go_back()
	assert_true(AudioManager.history.has(&"ui_back"))
	menu.close()


func test_rhythm_zone_tick_is_a_cue() -> void:
	var zone := RhythmZone.new()
	_add(zone)
	zone.beat.emit(1)
	assert_eq(AudioManager.history.back(), &"sfx_metronome_tick", "El metronomo suena (tic propio)")
	GameSettings.set_rhythm_cues_enabled(false)
	AudioManager.history.clear()
	AudioManager.load_catalog(AudioManager.DATA_PATH)
	zone.beat.emit(2)
	assert_true(AudioManager.history.is_empty(), "Sin senales de ritmo, solo visual")


func test_ambience_loops_while_its_node_is_in_the_tree() -> void:
	AudioManager.set_catalog(_catalog_with({"amb_hub": {"bus": "Ambience", "loop": true}},
		{"ambience": [{"class": "PauseMenu", "sound": "amb_hub"}]}))
	var menu := _add(PauseMenu.new())
	assert_eq(AudioManager.loop_count(), 1, "Suena el ambiente")
	assert_eq(AudioManager.history.back(), &"amb_hub")
	remove_child(menu)
	assert_eq(AudioManager.loop_count(), 0, "Se para al salir del arbol")
	add_child(menu)
	assert_eq(AudioManager.loop_count(), 1, "Vuelve al volver")


func test_text_blips_follow_speaker_and_access() -> void:
	var box := ECO_SCENE.instantiate() as EcoTextBox
	_add(box)
	GameState.lap = GameState.LAP_EASY
	box.show_line("Hola, soy Eco.")
	box.advance(0.2)
	AudioManager.poll_text_blips()
	assert_eq(AudioManager.history.back(), &"vox_eco_blip_cache", "Eco en Cache")
	box.free()
	GameState.lap = GameState.LAP_HARD
	var other := ECO_SCENE.instantiate() as EcoTextBox
	_add(other)
	other.show_line("Otra linea distinta.")
	other.advance(0.2)
	AudioManager.history.clear()
	AudioManager.load_catalog(AudioManager.DATA_PATH)
	AudioManager.poll_text_blips()
	assert_eq(AudioManager.history.back(), &"vox_eco_blip_raiz", "Eco en Raiz")
