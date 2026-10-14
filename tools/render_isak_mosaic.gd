## Mosaico de revision de las animaciones de Isak (scenes/player/isak_frames.tres):
## una fila por animacion con todos sus cuadros, la linea base (pies, magenta),
## justo debajo de la ultima fila; el centro (cian), una linea a 96 px de altura (amarilla) y, en el pulso, la
## onda de PulseEffect en pulse_effect_origin con su opacidad de cada cuadro.
## La primera celda de cada fila es idle 00 como referencia de tamano.
## Uso: Godot --headless --path . -s tools/render_isak_mosaic.gd -- salida.png [anim,anim,...]
extends SceneTree

const FRAMES_PATH: String = "res://scenes/player/isak_frames.tres"
## Origen del celular respecto a los pies (igual que Isak.pulse_effect_origin;
## Isak no se puede cargar aqui porque usa autoloads).
const PHONE: Vector2i = Vector2i(36, -56)
const SCALE: int = 2
const MAX_COLUMNS: int = 13
const CELL: int = 128
const GAP: int = 4
const BACKGROUND: Color = Color8(30, 30, 38)
const CELL_BG: Color = Color8(70, 72, 84)
const REF_BG: Color = Color8(50, 52, 60)
const VISIBLE_HEIGHT: int = 96


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("render_isak_mosaic: falta la ruta de salida")
		quit(1)
		return
	var frames: SpriteFrames = load(FRAMES_PATH) as SpriteFrames
	var anims: PackedStringArray = frames.get_animation_names()
	if args.size() > 1:
		anims = args[1].split(",")
	var origin: Vector2i = PHONE
	var abilities: PlayerAbilities = PlayerAbilities.load_from_file()
	var wave_count: int = PulseEffect.frame_count_for(abilities.pulse_duration_s)
	var waves: Array[Image] = PulseEffect.build_images(abilities.pulse_radius_px, wave_count)
	var rows: int = 0
	for anim: String in anims:
		rows += ceili(float(frames.get_frame_count(anim)) / (MAX_COLUMNS - 1))
	var width: int = MAX_COLUMNS * (CELL + GAP) + GAP
	var sheet := Image.create_empty(width, rows * (CELL + GAP) + GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	var ref: Image = _frame(frames, &"idle", 0)
	var row: int = 0
	for anim: String in anims:
		var count: int = frames.get_frame_count(anim)
		for i: int in count:
			var col: int = 1 + i % (MAX_COLUMNS - 1)
			if i % (MAX_COLUMNS - 1) == 0:
				if i > 0:
					row += 1
				_cell(sheet, Vector2i(GAP, GAP + row * (CELL + GAP)), ref, REF_BG)
			var pos := Vector2i(GAP + col * (CELL + GAP), GAP + row * (CELL + GAP))
			_cell(sheet, pos, _frame(frames, anim, i), CELL_BG)
			if anim == "pulse" and i < wave_count:
				var fx: Image = waves[i].duplicate()
				var alpha: float = PulseEffect.frame_alpha(i, wave_count)
				for y: int in fx.get_height():
					for x: int in fx.get_width():
						var c: Color = fx.get_pixel(x, y)
						if c.a > 0.0:
							c.a = alpha
							fx.set_pixel(x, y, c)
				var center: Vector2i = pos + Vector2i(CELL / 2, CELL) + origin
				var dst: Vector2i = center - fx.get_size() / 2
				# recorta la onda a la celda para no tapar a las vecinas
				var src := Rect2i(Vector2i.ZERO, fx.get_size())
				var clip := Rect2i(pos, Vector2i(CELL, CELL))
				var inter: Rect2i = Rect2i(dst, fx.get_size()).intersection(clip)
				sheet.blend_rect(fx, Rect2i(inter.position - dst, inter.size), inter.position)
				# cruz roja en pulse_effect_origin
				for d: int in range(-3, 4):
					sheet.set_pixelv(center + Vector2i(d, 0), Color.RED)
					sheet.set_pixelv(center + Vector2i(0, d), Color.RED)
		row += 1
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var err: Error = sheet.save_png(args[0])
	print("render_isak_mosaic: %d animaciones -> %s (%s)" % [anims.size(), args[0], error_string(err)])
	quit(0 if err == OK else 1)


func _frame(frames: SpriteFrames, anim: StringName, i: int) -> Image:
	var image: Image = frames.get_frame_texture(anim, i).get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _cell(sheet: Image, pos: Vector2i, image: Image, bg: Color) -> void:
	sheet.fill_rect(Rect2i(pos, Vector2i(CELL, CELL)), bg)
	for y: int in CELL:
		sheet.set_pixelv(pos + Vector2i(CELL / 2, y), Color8(0, 160, 180))
	for x: int in CELL:
		sheet.set_pixelv(pos + Vector2i(x, CELL - VISIBLE_HEIGHT), Color8(150, 140, 40))
	sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), pos)
	for x: int in CELL:
		sheet.set_pixelv(pos + Vector2i(x, CELL), Color8(230, 0, 160))
