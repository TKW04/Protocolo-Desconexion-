## Genera el SpriteFrames de cada enemigo desde su data/enemies/<enemigo>.json
## (seccion "sprites": dir, prefix, frame_size, frames_resource y animations con
## frames, fps y loop). Los PNG salen de tools/gen_alert_bubble.py y deben estar
## importados antes (Godot --headless --import).
## Uso: Godot --headless --path . -s tools/build_enemy_frames.gd
extends SceneTree

const DATA_DIR: String = "res://data/enemies/"
const FILE_PATTERN: String = "%s_%s_%02d.png"


func _init() -> void:
	var ok: bool = true
	var count: int = 0
	for file: String in DirAccess.get_files_at(DATA_DIR):
		if not file.ends_with(".json"):
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + file))
		if not data.has("sprites"):
			continue
		ok = _build(data["sprites"]) and ok
		count += 1
	print("build_enemy_frames: %d enemigo(s)%s" % [count, "" if ok else " CON ERRORES"])
	quit(0 if ok else 1)


func _build(spr: Dictionary) -> bool:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var size := Vector2i(int(spr["frame_size"][0]), int(spr["frame_size"][1]))
	for anim: String in spr["animations"]:
		var spec: Dictionary = spr["animations"][anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(spec["fps"]))
		frames.set_animation_loop(anim, bool(spec["loop"]))
		for i: int in int(spec["frames"]):
			var path: String = String(spr["dir"]) + FILE_PATTERN % [spr["prefix"], anim, i]
			var texture: Texture2D = load(path) as Texture2D
			if texture == null or Vector2i(texture.get_size()) != size:
				push_error("build_enemy_frames: '%s' falta, no esta importado o no mide %s." % [path, size])
				return false
			frames.add_frame(anim, texture)
	var err: Error = ResourceSaver.save(frames, String(spr["frames_resource"]))
	if err != OK:
		push_error("build_enemy_frames: no se pudo guardar '%s'." % spr["frames_resource"])
		return false
	print("build_enemy_frames: guardado %s" % spr["frames_resource"])
	return true
