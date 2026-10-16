## Encuentro con Eco (tipo `eco_encounter` de la lista `objects` del nivel;
## docs/propuesta-asistentes-y-vidas.md §7.1, paso 6 de §10; textos en
## data/eco_encounter.json). Patron de EcoLine: zona invisible de width_tiles x
## height_tiles desde la esquina superior izquierda de la celda (x, y), sin
## colision con el mundo, que detecta a Isak (capa `player`, 2).
## - Si Eco aun no es conocido (GameState.has_met_ally("eco")), Eco flota en la
##   celda eco_offset_tiles de la zona (arte de Eco companero) y, al entrar
##   Isak, empieza la presentacion (momento de historia): el encuentro pausa el
##   arbol de principio a fin y pide al cuadro de Eco las lineas `intro` (todas
##   importantes), abre la entrada del apodo (NicknameEntry), dice `gift` (con
##   el apodo, {apodo}), da la habilidad `ability` (GameState.obtain_ability: el
##   pulso, obtenido para siempre) y su aviso de control (`notice`, formato de
##   AbilityNotices) y dice `outro`. Al cerrarse la ultima linea Eco queda
##   conocido (GameState.meet_ally: ayuda con Q y companero) y la esfera pasa a
##   ser el EcoCompanion del nivel (appear_at), que vuela hasta Isak.
## - Si Eco ya es conocido (rejugar, guardado migrado) no hay esfera ni
##   presentacion: la zona no hace nada.
## - Como EcoLine: si Isak entra mientras su llegada aun no se ve
##   (Isak.is_warp_hidden()), espera a Isak.warp_revealed.
## - Con EcoTextBox.pause_important en false (pruebas y herramientas) el
##   encuentro no pausa (las lineas se cierran solas); la entrada del apodo si
##   pausa hasta que se acepta (NicknameEntry).
## - La pausa se libera siempre al salir del arbol (reinicio del mapa).
## Tiempo real (PROCESS_MODE_ALWAYS): la esfera flota y habla con el juego en
## pausa.
class_name EcoEncounter
extends Area2D

enum Step { WAITING, INTRO, NICKNAME, GIFT, OUTRO, DONE }

const GROUP: StringName = &"eco_encounter"
const DATA_PATH: String = "res://data/eco_encounter.json"
const NICKNAME_SCENE: String = "res://scenes/ui/nickname_entry.tscn"
const ANIM_IDLE: StringName = &"idle"
const ANIM_TALK: StringName = &"talk"

## Empieza la presentacion.
signal started
## Cambia de paso (pruebas, capturas y bot).
signal step_changed(step: Step)
## Se abre la entrada del apodo.
signal nickname_entry_opened(entry: NicknameEntry)
## Se ha dado la habilidad (el pulso).
signal ability_granted(ability: StringName)
## Termina la presentacion: Eco ya es conocido.
signal finished

@export var object_id: StringName = &""
@export_range(1, 64) var width_tiles: int = 3
@export_range(1, 64) var height_tiles: int = 10
## Celda de Eco flotando, relativa a la celda (x, y) de la zona (tiles).
@export var eco_offset_tiles: Vector2 = Vector2(2, 7)

var _data: Dictionary = {}
var _step: Step = Step.WAITING
## Textos (con el apodo ya puesto) que faltan por cerrarse en el paso actual.
var _expected: Array[String] = []
## La primera linea esperada esta en pantalla.
var _expected_on_screen: bool = false
var _owns_pause: bool = false
var _entry: NicknameEntry
var _sprite: AnimatedSprite2D
var _time: float = 0.0
var _talking: bool = false
var _waiting_isak: Isak


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = load_data()
	_build_zone()
	if GameState.has_met_ally(GameState.ALLY_ECO):
		_step = Step.DONE
		set_deferred(&"monitoring", false)
		return
	_build_sprite()
	body_entered.connect(_on_body_entered)
	EventBus.eco_line_started.connect(_on_eco_line_started)
	EventBus.eco_line_finished.connect(_on_eco_line_finished)


func _exit_tree() -> void:
	_release_pause()
	for pair: Array in [[EventBus.eco_line_started, _on_eco_line_started],
			[EventBus.eco_line_finished, _on_eco_line_finished]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _process(delta: float) -> void:
	_time += delta
	if _sprite == null or not _sprite.visible:
		return
	var anim: StringName = ANIM_TALK if _talking else ANIM_IDLE
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
		_sprite.play(anim)
	var bob: float = sin(TAU * float(_data.get("bob_hz", 0.8)) * _time) * float(_data.get("bob_px", 4))
	_sprite.position = (get_eco_local_position() + Vector2(0.0, bob)).round()


# --- Consultas ---

func get_step() -> Step:
	return _step


## La presentacion esta en marcha (de la primera linea al cierre de la ultima).
func is_running() -> bool:
	return _step != Step.WAITING and _step != Step.DONE


func is_done() -> bool:
	return _step == Step.DONE


## Entrada del apodo abierta (null si no lo esta).
func get_nickname_entry() -> NicknameEntry:
	return _entry if _entry != null and is_instance_valid(_entry) else null


## Esfera de Eco flotando (null si Eco ya era conocido).
func get_eco_sprite() -> AnimatedSprite2D:
	return _sprite


## Eco flotando se ve.
func is_eco_visible() -> bool:
	return _sprite != null and _sprite.visible


## Centro de la celda de Eco en coordenadas locales (px).
func get_eco_local_position() -> Vector2:
	var t: float = World1ObjectsConfig.tile_size()
	return (eco_offset_tiles + Vector2(0.5, 0.5)) * t


## Zona de disparo en coordenadas locales (px).
func get_zone_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	return Rect2(Vector2.ZERO, Vector2(width_tiles * t, height_tiles * t))


## Textos del paso `key` de data/eco_encounter.json (intro, gift, outro).
func get_lines(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = _data.get(key, [])
	if raw is Array:
		for text: Variant in raw:
			out.append(String(text))
	return out


## Aviso de control de la habilidad que da Eco (p. ej. «Pulso: G / X (mando)»).
func get_notice_text() -> String:
	var notice: Variant = _data.get("notice", {})
	if not notice is Dictionary:
		return ""
	var format: Dictionary = AbilityNotices.load_data()
	format["abilities"] = {get_ability(): notice}
	return AbilityNotices.notice_text(get_ability(), format)


func get_ability() -> StringName:
	return StringName(String(_data.get("ability", GameState.ABILITY_PULSE)))


# --- Acciones ---

## Empieza la presentacion. Falso si ya empezo, termino o Eco ya es conocido.
func start() -> bool:
	if _step != Step.WAITING or GameState.has_met_ally(GameState.ALLY_ECO):
		return false
	set_deferred(&"monitoring", false)
	_hold_pause()
	started.emit()
	_say(Step.INTRO, get_lines("intro"))
	return true


# --- Interno ---

func _build_zone() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var zone: Rect2 = get_zone_rect()
	rect.size = zone.size
	shape.shape = rect
	shape.position = zone.get_center()
	add_child(shape)


func _build_sprite() -> void:
	var eco_data: Dictionary = EcoCompanion.load_data()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Eco"
	var frames_path: String = String(eco_data.get("frames", ""))
	if not frames_path.is_empty():
		_sprite.sprite_frames = load(frames_path) as SpriteFrames
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * maxi(1, int(eco_data.get("sprite_scale", 1)))
	# Mira hacia Isak, que llega por la izquierda.
	_sprite.flip_h = true
	_sprite.position = get_eco_local_position()
	add_child(_sprite)
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(ANIM_IDLE):
		_sprite.play(ANIM_IDLE)


func _set_step(step: Step) -> void:
	_step = step
	step_changed.emit(step)


## Pide al cuadro de Eco `texts` (importantes, en orden) y espera a que se cierren.
func _say(step: Step, texts: PackedStringArray) -> void:
	_set_step(step)
	_expected.clear()
	_expected_on_screen = false
	var duration: float = float(_data.get("duration_s", -1.0))
	for text: String in texts:
		if text.is_empty():
			continue
		_expected.append(GameState.apply_nickname(text))
		EventBus.eco_line_requested.emit(text, duration, true)
	if _expected.is_empty():
		_step_done.call_deferred()


func _on_eco_line_started(text: String) -> void:
	if not is_running():
		return
	_talking = true
	if not _expected.is_empty() and text == _expected[0]:
		_expected_on_screen = true


func _on_eco_line_finished() -> void:
	_talking = false
	if not is_running() or not _expected_on_screen:
		return
	_expected_on_screen = false
	_expected.pop_front()
	if _expected.is_empty():
		# Diferido: el cuadro emite eco_line_finished antes de empezar la
		# siguiente de su cola; una linea pedida aqui se pisaria con ella.
		_step_done.call_deferred()


func _step_done() -> void:
	if not is_inside_tree():
		return
	match _step:
		Step.INTRO:
			_open_nickname_entry()
		Step.GIFT:
			_grant()
		Step.OUTRO:
			_finish()


func _open_nickname_entry() -> void:
	if not is_inside_tree() or _step != Step.INTRO:
		return
	_set_step(Step.NICKNAME)
	_entry = (load(NICKNAME_SCENE) as PackedScene).instantiate() as NicknameEntry
	_entry.nickname_chosen.connect(_on_nickname_chosen, CONNECT_ONE_SHOT)
	add_child(_entry)
	nickname_entry_opened.emit(_entry)


func _on_nickname_chosen(_nickname: String) -> void:
	_entry = null
	# Tras cerrarse la entrada (libera la pausa si era suya) se vuelve a pausar.
	_say_gift.call_deferred()


func _say_gift() -> void:
	if not is_inside_tree():
		return
	_hold_pause()
	_say(Step.GIFT, get_lines("gift"))


## Da la habilidad y su aviso de control (antes de obtenerla se marca como
## visto: AbilityNotices no lo repite) y sigue con `outro`.
func _grant() -> void:
	var ability: StringName = get_ability()
	var notice: String = get_notice_text()
	GameState.mark_notice_seen(ability)
	GameState.obtain_ability(ability)
	ability_granted.emit(ability)
	var texts := PackedStringArray()
	if not notice.is_empty():
		texts.append(notice)
	texts.append_array(get_lines("outro"))
	_say(Step.OUTRO, texts)


func _finish() -> void:
	_set_step(Step.DONE)
	_talking = false
	GameState.meet_ally(GameState.ALLY_ECO)
	var from: Vector2 = _sprite.global_position if _sprite != null else global_position + get_eco_local_position()
	if _sprite != null:
		_sprite.visible = false
	for node: Node in get_tree().get_nodes_in_group(EcoCompanion.GROUP):
		var companion := node as EcoCompanion
		if companion != null and companion.get_isak() != null and is_instance_valid(companion.get_isak()):
			companion.appear_at(from)
			break
	_release_pause()
	finished.emit()


func _hold_pause() -> void:
	if _owns_pause or not EcoTextBox.pause_important or not is_inside_tree() or get_tree().paused:
		return
	get_tree().paused = true
	_owns_pause = true


func _release_pause() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	if is_inside_tree():
		get_tree().paused = false


func _on_body_entered(body: Node2D) -> void:
	var isak := body as Isak
	if isak == null or _step != Step.WAITING:
		return
	if isak.is_warp_hidden():
		_wait_for_reveal(isak)
		return
	start()


func _wait_for_reveal(isak: Isak) -> void:
	if _waiting_isak == isak:
		return
	_waiting_isak = isak
	isak.warp_revealed.connect(_on_isak_revealed, CONNECT_ONE_SHOT)


func _on_isak_revealed() -> void:
	var isak: Isak = _waiting_isak
	_waiting_isak = null
	if is_instance_valid(isak) and monitoring and overlaps_body(isak):
		start()
