## Fondo del centro comercial del Mundo 5 (scenes/levels/world5_background.tscn, de
## tools/gen_world5_background.py; paso 9 de docs/propuesta-mundo-5.md, 2026-10-29): el
## mismo World1Background con su JSON y una clase propia, como World3Background y
## World4Background, para que el audio del Mundo 5 se enlace por ella: el ambiente
## amb_w5_mall de data/audio.json por esta clase y, fuera de las arenas de jefe (sin
## nodos del grupo «boss»), un MallMusic hijo para la musica del nivel mus_w5_level
## (paso 20; en la arena manda mus_boss5).
class_name World5Background
extends World1Background

var _music: MallMusic


func _ready() -> void:
	super._ready()
	_add_music.call_deferred()


## Musica del nivel (null en las arenas de jefe).
func get_music() -> MallMusic:
	return _music if _music != null and is_instance_valid(_music) else null


func _add_music() -> void:
	if not is_inside_tree() or not get_tree().get_nodes_in_group(BossBase.GROUP).is_empty():
		return
	_music = MallMusic.new()
	_music.name = "MallMusic"
	add_child(_music)
