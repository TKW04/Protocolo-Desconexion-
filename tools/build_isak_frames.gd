## Genera scenes/player/isak_frames.tres (SpriteFrames) desde los PNG de Isak.
## Cada animacion cuenta sus cuadros (isak_<anim>_00.png, 01, ...) hasta el
## primero que falte. Los PNG salen de las hojas de hojas/ con
## tools/import_sheet.py (mapeo de celdas en docs/guia-sprites-ia.md, al final).
## Requiere que los PNG esten importados antes (Godot --headless --import).
## Todos los cuadros deben medir FRAME_SIZE (canvas de Isak a 1280x720) con los
## pies en la ultima fila y centrados; isak.tscn coloca el AnimatedSprite2D
## (centrado) en (0, -FRAME_SIZE.y / 2) para que los pies queden en el origen.
## Uso: Godot --headless --path . -s tools/build_isak_frames.gd
extends SceneTree

const SPRITE_DIR: String = "res://assets/sprites/isak/"
const OUTPUT_PATH: String = "res://scenes/player/isak_frames.tres"
const FILE_PATTERN: String = "isak_%s_%02d.png"
## Tamano esperado de cada cuadro (px).
const FRAME_SIZE: Vector2i = Vector2i(128, 128)

## Unico sitio donde se fijan las animaciones: nombre -> [fps, bucle, ping-pong].
## ping-pong: tras el ultimo cuadro repite los intermedios al reves (sin
## archivos extra), para bucles cuyo final no empalma con el principio.
##
## idle (25 cuadros, 8 fps = 3,1 s): dos respiraciones por vuelta (el pecho y la
##   cabeza suben 1 px). A 12 fps cada respiracion duraba ~1 s y el salto de 1 px
##   parecia un temblor; a 8 fps dura ~1,5 s. Los cuadros se importan con
##   --stabilize (ruido temporal del arte de IA quitado).
## walk (8 cuadros = celdas 11,2,4,22 + 23,16,17,9 de la hoja: 2 pasos de 4
##   cuadros, todos con el celular; --align ground, pies en la fila base).
##   Antes: las 25 celdas a 24 fps = ~5,7 pasos/s (mas cadencia que correr) y en
##   desorden: celdas repetidas (0=1=10, 4=12, 6=15...), saltos de pose, el
##   celular ausente en 0, 1 y 10 y el torso saltando hasta 3 px entre cuadros
##   (la IA dibuja el suelo 4-5 px mas abajo en un paso que en el otro). De cada
##   pose se eligio la variante con menos salto del torso: 0-1 px por cuadro
##   salvo 2 px al volver al cuadro 0. WALK_FPS 14: 3,5 pasos/s, vuelta 0,57 s
##   (correr: 4,7 pasos/s). El pie apoyado retrocede ~7 px por cuadro (~29 px
##   por paso) = ~100 px/s frente a walk_speed 220: patina (zancada corta del
##   arte; sin patinar harian falta ~30 fps, que parece correr, o walk_speed ~100).
const WALK_FPS: float = 14.0
## run (6 cuadros = celdas 21,16,17 + 18,19,20 de la hoja: 2 pasos de 3 cuadros,
##   contacto -> paso por debajo -> despegue). Medido en los cuadros de 128 px:
##   el pie apoyado retrocede 13+26 y 20+29 px por cuadro (media 22 px). A
##   RUN_FPS 14: pie a ~309 px/s frente a run_speed 360 (patina -14 %), 4,7
##   pasos/s, vuelta 0,43 s. Alternativa B: RUN_FPS 10 -> 3,3 pasos/s, patina
##   -39 %. Sin patinaje harian falta ~16 fps (5,3 pasos/s): la zancada del arte
##   (~50 px por apoyo) es corta para 360 px/s. Antes: 25 cuadros a 20 fps =
##   6,4 pasos/s; se descartaron las celdas con doble apoyo (3, 6, 9, 23: tercer
##   pie y cuerpo 4-5 px mas bajo), las duplicadas (12 = 0, 24 = 7) y las de
##   pie apoyado quieto o que avanza (0-1-24, 10-15, 22).
const RUN_FPS: float = 14.0
## jump_rise / jump_apex / jump_fall: no se reproducen en el tiempo; Isak elige
##   el cuadro por la velocidad vertical (Isak.update_air_animation).
## jump_land (5 cuadros a 24 fps = 0,21 s): solo visual al aterrizar en Idle.
## pulse (8 cuadros a 24 fps = 0,333 s = pulse_duration_s): el cuadro 0 ya es el
##   celular al frente, cuando nace la onda.
## hurt (7 cuadros a 24 fps = 0,29 s, dentro de hurt_duration_s = 0,3 s).
## death (19 cuadros a 12 fps = 1,58 s): una vez y se queda en el ultimo.
## terminal_*: 6 fps; intro 4 cuadros (0,67 s), bucle 12 cuadros en ping-pong
##   (22 pasos, 3,7 s), salida 4 cuadros (0,67 s). Solo se usa un instante de
##   cada 4 de la hoja: los 4 de cada bloque de 256 px estan a distinta fase
##   de sub-pixel y al alternarlos (antes, 1 de cada 2 a 12 fps) Isak temblaba
##   2 px a 6 Hz. Mismo ritmo que antes, sin temblor.
## back_idle (2026-10-15): pose estatica de espaldas, un solo cuadro
##   (isak_back_idle_00.png, de AutoSprite via tools/import_isak_back_idle.py).
##   Isak.face_back()/face_side() entran y salen de ella (terminal de salida;
##   pensada tambien para el hub).
## dash (2026-10-20, paso 8 de docs/propuesta-1-3.md): pose PROVISIONAL del gesto
##   Deslizar, 3 cuadros a 15 fps (0,2 s = duracion del dash) sin bucle: los
##   cuadros 01-03 de correr inclinados hacia delante por cizalla de pixeles
##   (tools/gen_world1_dnd.py, sin colores nuevos) hasta que llegue la hoja.
const ANIMATIONS: Dictionary[String, Array] = {
	"idle": [8.0, true, false],
	"walk": [WALK_FPS, true, false],
	"run": [RUN_FPS, true, false],
	"jump_rise": [12.0, false, false],
	"jump_apex": [12.0, false, false],
	"jump_fall": [12.0, false, false],
	"jump_land": [24.0, false, false],
	"pulse": [24.0, false, false],
	"hurt": [24.0, false, false],
	"death": [12.0, false, false],
	"terminal_intro": [6.0, false, false],
	"terminal_loop": [6.0, true, true],
	"terminal_outro": [6.0, false, false],
	"back_idle": [1.0, true, false],
	"dash": [15.0, false, false],
}

## Animaciones hechas con cuadros de otra (sin PNG propios):
## nombre -> [animacion de origen, indices de sus cuadros en orden, fps, bucle].
## laser (2026-10-15): pose del laser. Son los cuadros del pulso en que Isak
##   sube el celular (la vuelta del pulso, 6 -> 5, al reves) hasta el brazo
##   extendido (0); no incluye la vuelta a la pose de reposo. La onda del pulso
##   no esta en estos cuadros (la dibuja PulseEffect). No se reproduce en el
##   tiempo: Isak elige el cuadro segun la anticipacion del laser y mantiene el
##   ultimo mientras dura la pose (Isak.laser_pose_hold_s).
const DERIVED: Dictionary[String, Array] = {
	"laser": ["pulse", [6, 5, 0], 24.0, false],
}


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var ok: bool = true
	for anim: String in ANIMATIONS:
		var textures: Array[Texture2D] = _load_sequence(anim)
		if textures.is_empty():
			ok = false
			continue
		var spec: Array = ANIMATIONS[anim]
		if spec[2] and textures.size() > 2:
			var back: Array[Texture2D] = textures.slice(1, textures.size() - 1)
			back.reverse()
			textures.append_array(back)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[0])
		frames.set_animation_loop(anim, spec[1])
		for texture: Texture2D in textures:
			frames.add_frame(anim, texture)
	for anim: String in DERIVED:
		var spec: Array = DERIVED[anim]
		var source: Array[Texture2D] = _load_sequence(spec[0])
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[2])
		frames.set_animation_loop(anim, spec[3])
		for index: int in spec[1]:
			if index >= source.size():
				push_error("build_isak_frames: '%s' no tiene el cuadro %d (para '%s')." % [spec[0], index, anim])
				ok = false
				break
			frames.add_frame(anim, source[index])
	if not ok:
		quit(1)
		return
	var err: Error = ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("build_isak_frames: no se pudo guardar '%s' (%s)." % [OUTPUT_PATH, error_string(err)])
		quit(1)
		return
	print("build_isak_frames: guardado %s (%d animaciones)" % [OUTPUT_PATH, ANIMATIONS.size() + DERIVED.size()])
	quit(0)


func _load_sequence(anim: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var index: int = 0
	while true:
		var path: String = SPRITE_DIR + FILE_PATTERN % [anim, index]
		if not ResourceLoader.exists(path):
			break
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_error("build_isak_frames: no se pudo cargar '%s' (falta importar?)." % path)
			textures.clear()
			break
		if Vector2i(texture.get_size()) != FRAME_SIZE:
			push_error("build_isak_frames: '%s' mide %s y se esperaba %s." % [path, Vector2i(texture.get_size()), FRAME_SIZE])
			textures.clear()
			break
		textures.append(texture)
		index += 1
	if textures.is_empty():
		push_error("build_isak_frames: no hay cuadros para '%s'." % anim)
	return textures
