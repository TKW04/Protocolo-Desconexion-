## Ajustes del jugador (docs/propuesta-hub-y-guardado.md §4.1 y preguntas 6 y 9;
## docs/propuesta-asistentes-y-vidas.md §3.4 y paso 13 de §10). No son progreso:
## - Se guardan AL INSTANTE al cambiarlos, en un ConfigFile aparte
##   (user://settings.cfg), nunca en save.json: no marcan «sin guardar», no los
##   toca el guardado manual de Notas ni un game over (rollback).
## - Ruta: ISAK_SETTINGS_PATH si esta definida; dentro de GUT,
##   user://test_settings.cfg, y con otro script (-s: bots, capturas),
##   user://tool_settings.cfg (estas dos se borran al arrancar, como los
##   guardados de pruebas). Solo el juego normal usa user://settings.cfg.
## - Hoy hay un ajuste: «Ayudas de Eco: Mostrar / Ocultar» (show_eco_help, por
##   defecto Mostrar). Oculto, no sale ninguna Q (HelpSystem) y por tanto no se
##   aprende nada sin pedirlo; lo ya aprendido sigue en el album de Notas y los
##   momentos de historia de Eco (encuentro, laser, Debug, game over) salen igual.
## Clase estatica (sin autoload): la carga la primera consulta o GameState al
## arrancar (use_path). Cambios: EventBus.settings_changed(key, value).
class_name GameSettings
extends RefCounted

const PATH_DEFAULT: String = "user://settings.cfg"
## Ruta de las pruebas GUT (nunca los ajustes reales del jugador).
const PATH_TESTS: String = "user://test_settings.cfg"
## Ruta de los scripts de herramientas (-s tools/*.gd).
const PATH_TOOLS: String = "user://tool_settings.cfg"
## Variable de entorno que fuerza otra ruta.
const PATH_ENV: String = "ISAK_SETTINGS_PATH"

const SECTION_HELP: String = "help"
## Mostrar las Q de la ayuda de Eco.
const KEY_SHOW_ECO_HELP: StringName = &"show_eco_help"
const SHOW_ECO_HELP_DEFAULT: bool = true

static var _path: String = ""
static var _loaded: bool = false
static var _show_eco_help: bool = SHOW_ECO_HELP_DEFAULT


## Ruta segun los argumentos de Godot y ISAK_SETTINGS_PATH (como el guardado).
static func resolve_path(args: PackedStringArray, env_path: String) -> String:
	if not env_path.is_empty():
		return env_path
	if GameState.is_running_tests(args):
		return PATH_TESTS
	if GameState.is_running_script(args):
		return PATH_TOOLS
	return PATH_DEFAULT


## Ruta de los ajustes (la resuelve la primera vez).
static func settings_path() -> String:
	_ensure_loaded()
	return _path


## Usa `path` y carga sus ajustes; con `fresh`, borra antes el archivo (rutas
## de pruebas y herramientas) y quedan los valores por defecto.
static func use_path(path: String, fresh: bool = false) -> void:
	_path = path
	_loaded = true
	if fresh and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	reload()


## Vuelve a leer los ajustes del disco (sin archivo: valores por defecto).
static func reload() -> void:
	_ensure_path()
	var config := ConfigFile.new()
	var loaded: bool = FileAccess.file_exists(_path) and config.load(_path) == OK
	var value: Variant = config.get_value(SECTION_HELP, String(KEY_SHOW_ECO_HELP), SHOW_ECO_HELP_DEFAULT) \
		if loaded else SHOW_ECO_HELP_DEFAULT
	_show_eco_help = value if value is bool else SHOW_ECO_HELP_DEFAULT


## Valores por defecto en memoria (no escribe). Para pruebas.
static func reset_defaults() -> void:
	_ensure_path()
	_show_eco_help = SHOW_ECO_HELP_DEFAULT


## Escribe todos los ajustes en su archivo. Falso si no se pudo.
static func save() -> bool:
	_ensure_path()
	var config := ConfigFile.new()
	config.set_value(SECTION_HELP, String(KEY_SHOW_ECO_HELP), _show_eco_help)
	var error: Error = config.save(_path)
	if error != OK:
		push_warning("GameSettings: no se pudieron guardar los ajustes en '%s' (%s)." % [_path, error_string(error)])
		return false
	return true


## Se muestran las Q de la ayuda de Eco.
static func is_eco_help_shown() -> bool:
	_ensure_loaded()
	return _show_eco_help


## Cambia «Ayudas de Eco» y lo guarda al instante. Devuelve verdadero si cambio.
static func set_eco_help_shown(value: bool) -> bool:
	_ensure_loaded()
	if value == _show_eco_help:
		return false
	_show_eco_help = value
	save()
	EventBus.settings_changed.emit(KEY_SHOW_ECO_HELP, value)
	return true


static func _ensure_path() -> void:
	if _path.is_empty():
		_path = resolve_path(OS.get_cmdline_args(), OS.get_environment(PATH_ENV))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	reload()
