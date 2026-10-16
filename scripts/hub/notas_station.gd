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
## Arte: assets/sprites/hub/notas_frames.tres (powered_off / off / prompt /
## active), dado como `frames` en data/hub.json; sin el, el monitor provisional.
class_name NotasStation
extends HubStation

const NICKNAME_SCENE: String = "res://scenes/ui/nickname_entry.tscn"

var _notas: Dictionary = HubData.section("notas")
var _album: NotasAlbum
var _nickname_entry: NicknameEntry


func get_notas_panel() -> NotasPanel:
	return get_panel() as NotasPanel


func get_album() -> NotasAlbum:
	return _album


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
