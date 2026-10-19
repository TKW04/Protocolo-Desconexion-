## Estacion Notas del hub (antes «copia local»; docs/propuesta-hub-y-guardado.md
## §4 y docs/propuesta-asistentes-y-vidas.md §2.2, pasos 8 y 9 de §10): el unico
## sitio donde se guarda y el album de fichas. Es un HubStation (pulso para
## abrir, Isak de espaldas) con el panel NotasPanel (Guardar / Álbum / Apodo /
## Volver). Al guardar, destello cian del monitor (save_flash_s de la seccion
## notas de data/hub.json).
## - Álbum: oculta el panel y abre NotasAlbum; al cerrarlo vuelve el panel.
## - Apodo: oculta el panel y abre la entrada del apodo (NicknameEntry, pausa el
##   juego); al elegir vuelve el panel.
## - Apagada (set_powered(false)) hasta que Eco la presenta la primera vez que
##   Isak entra al hub (NotasIntro; GameState.allies_met "notas").
## - Recuerdo nuevo (2026-10-19, paso 3 de docs/propuesta-recuerdos.md §3): con
##   algun recuerdo obtenido sin leer (GameState.has_unread_memories) y la
##   estacion encendida, una placa «!» (unread_badge de la seccion notas) arriba
##   a la derecha del monitor; se quita al leerlo en el album (pestana Recuerdos).
## Arte: assets/sprites/hub/notas_frames.tres (powered_off / off / prompt /
## active), dado como `frames` en data/hub.json; sin el, el monitor provisional.
class_name NotasStation
extends HubStation

const NICKNAME_SCENE: String = "res://scenes/ui/nickname_entry.tscn"

var _notas: Dictionary = HubData.section("notas")
var _album: NotasAlbum
var _nickname_entry: NicknameEntry
var _unread_badge: Node2D


func get_notas_panel() -> NotasPanel:
	return get_panel() as NotasPanel


func get_album() -> NotasAlbum:
	return _album


## La placa de recuerdo nuevo se ve (hay algo sin leer y la estacion esta encendida).
func is_unread_badge_visible() -> bool:
	return _unread_badge != null and _unread_badge.visible


func is_album_open() -> bool:
	return _album != null and _album.is_open()


## Entrada del apodo abierta desde Notas (null si no lo esta).
func get_nickname_entry() -> NicknameEntry:
	return _nickname_entry if _nickname_entry != null and is_instance_valid(_nickname_entry) else null


## Abre el album (oculta el panel). Falso si la estacion no esta abierta.
func open_album() -> bool:
	if get_state() != State.OPEN or is_album_open():
		return false
	get_panel().close()
	_album.open()
	return true


## Abre la entrada del apodo (oculta el panel). Falso si no esta abierta.
func open_nickname_entry() -> bool:
	if get_state() != State.OPEN or get_nickname_entry() != null:
		return false
	get_panel().close()
	_nickname_entry = (load(NICKNAME_SCENE) as PackedScene).instantiate() as NicknameEntry
	_nickname_entry.closed.connect(_on_nickname_closed, CONNECT_ONE_SHOT)
	add_child(_nickname_entry)
	return true


## Cierra tambien el album o la entrada del apodo si estaban abiertos.
func close(immediate: bool = false) -> bool:
	if is_album_open():
		_album.close()
	return super.close(immediate)


func _ready() -> void:
	super._ready()
	_album = NotasAlbum.new()
	_album.name = "Album"
	add_child(_album)
	_album.close_requested.connect(_on_album_closed)
	_build_unread_badge()
	EventBus.memory_obtained.connect(_on_memory_changed)
	EventBus.memory_read.connect(_on_memory_changed)


func advance(delta: float) -> void:
	super.advance(delta)
	_refresh_unread_badge()


func set_powered(value: bool) -> void:
	super.set_powered(value)
	_refresh_unread_badge()


func _create_panel() -> HubPanel:
	var panel := NotasPanel.new()
	panel.saved.connect(_on_saved)
	panel.album_requested.connect(open_album)
	panel.nickname_requested.connect(open_nickname_entry)
	return panel


func _on_saved(ok: bool) -> void:
	if ok:
		flash(float(_notas.get("save_flash_s", 0.3)))


func _on_album_closed() -> void:
	_album.close()
	_reopen_panel(NotasPanel.OPTION_ALBUM)


func _on_nickname_closed() -> void:
	_nickname_entry = null
	_reopen_panel.call_deferred(NotasPanel.OPTION_NICKNAME)


func _reopen_panel(option: StringName) -> void:
	if get_state() != State.OPEN:
		return
	get_panel().open()
	get_panel().select_option(option)


func _on_memory_changed(_id: StringName) -> void:
	_refresh_unread_badge()


func _refresh_unread_badge() -> void:
	if _unread_badge != null:
		_unread_badge.visible = is_powered() and GameState.has_unread_memories()


## Placa «!» arriba a la derecha del monitor (PulsePrompt.make_plate, como la tecla).
func _build_unread_badge() -> void:
	var cfg: Dictionary = _notas.get("unread_badge", {})
	var station: Dictionary = HubData.section("station")
	var font: Font = load(String(station.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var scale_factor: int = maxi(1, int(station.get("font_scale", 2)))
	var top: float = prompt_top_px if prompt_top_px >= 0.0 else float(station.get("top_px", 30)) * get_size().y / 128.0
	_unread_badge = PulsePrompt.make_plate(self, "UnreadBadge", String(cfg.get("text", "!")), font,
		int(station.get("font_size", 12)), scale_factor,
		"#" + HubData.color(String(cfg.get("plate_color", "fondo_profundo"))).to_html(false),
		"#" + HubData.color(String(cfg.get("border_color", "ambar"))).to_html(false),
		float(cfg.get("padding_px", 2)), get_size().x, 0.0)
	var plate := _unread_badge.get_child(1) as ColorRect
	var plate_size: Vector2 = plate.size * float(scale_factor)
	_unread_badge.position = Vector2(get_size().x - plate_size.x, top + float(cfg.get("top_px", 6)))
	_refresh_unread_badge()
