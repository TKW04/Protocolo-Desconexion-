## Fondo de los niveles del Mundo 4 (scenes/levels/world4_background.tscn, paso 20
## de docs/propuesta-mundo-4.md, 2026-10-28): el mismo World1Background con su
## JSON por defecto (el fondo no cambia: el arte del mundo llega mas tarde) y una
## clase propia para el audio, como World3Background: el ambiente amb_w4_chat_night
## de data/audio.json se enlaza por esta clase y, fuera de las arenas de jefe (sin
## nodos del grupo «boss»), crea un ChatMusic hijo para la musica del nivel
## mus_w4_level (en la arena manda mus_boss4). Si el nivel tiene ola de «Visto»
## (SeenWave), al apagarse para siempre (cierre del 4-3, §4.3) quita la musica: se
## queda el ambiente.
class_name World4Background
extends World1Background

var _music: ChatMusic


func _ready() -> void:
	super._ready()
	_add_music.call_deferred()


## Musica del nivel (null en las arenas de jefe y tras apagarse la ola).
func get_music() -> ChatMusic:
	return _music if _music != null and is_instance_valid(_music) else null


func _add_music() -> void:
	if not is_inside_tree() or not get_tree().get_nodes_in_group(BossBase.GROUP).is_empty():
		return
	_music = ChatMusic.new()
	_music.name = "ChatMusic"
	add_child(_music)
	var root: Node = get_parent()
	if root == null:
		return
	for node: Node in root.find_children("*", "", true, false):
		if node is SeenWave:
			(node as SeenWave).state_changed.connect(_on_wave_state_changed)


func _on_wave_state_changed(state: SeenWave.State) -> void:
	if state == SeenWave.State.OFF:
		_stop_music()


func _stop_music() -> void:
	if _music != null and is_instance_valid(_music):
		_music.queue_free()
	_music = null
