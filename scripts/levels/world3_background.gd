## Fondo de la galeria del Mundo 3 (scenes/levels/world3_background.tscn, de
## tools/gen_world3_background.py): el mismo World1Background con su JSON y una
## clase propia para el audio (paso 19 de docs/propuesta-mundo-3.md, 2026-10-27):
## el ambiente amb_w3_gallery de data/audio.json se enlaza por esta clase y, fuera
## de las arenas de jefe (sin nodos del grupo «boss»), crea un GalleryMusic hijo
## para la musica del nivel mus_w3_level (en la arena manda mus_boss3, y tras el
## golpe final no vuelve la del nivel).
class_name World3Background
extends World1Background

var _music: GalleryMusic


func _ready() -> void:
	super._ready()
	_add_music.call_deferred()


## Musica del nivel (null en las arenas de jefe).
func get_music() -> GalleryMusic:
	return _music if _music != null and is_instance_valid(_music) else null


func _add_music() -> void:
	if not is_inside_tree() or not get_tree().get_nodes_in_group(BossBase.GROUP).is_empty():
		return
	_music = GalleryMusic.new()
	_music.name = "GalleryMusic"
	add_child(_music)
