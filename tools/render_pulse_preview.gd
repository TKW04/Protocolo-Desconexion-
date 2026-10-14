## Vista ampliada x8 de la onda del pulso sobre el cuadro de pulso de Isak,
## con la opacidad de cada cuadro. Lee radio y duracion de data/isak_abilities.json.
## Uso: Godot --headless --path . -s tools/render_pulse_preview.gd [-- salida.png]
## Por defecto escribe assets/sprites/effects/_pulse_wave_preview_x8.png.
extends SceneTree

const SCALE: int = 8
const COLUMNS: int = 4
const MARGIN: int = 8
const ISAK_FRAME: String = "res://assets/sprites/isak/isak_pulse_02_placeholder.png"
const DEFAULT_OUT: String = "res://assets/sprites/effects/_pulse_wave_preview_x8.png"
## Fondo oscuro neutro (outline de isak.gpl).
const BACKGROUND: Color = Color8(22, 20, 28)
## Origen del celular respecto a los pies (igual que Isak.pulse_effect_origin).
const PHONE: Vector2i = Vector2i(26, -70)


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	var abilities: PlayerAbilities = PlayerAbilities.load_from_file()
	if abilities == null:
		quit(1)
		return
	var radius: float = abilities.pulse_radius_px
	var count: int = PulseEffect.frame_count_for(abilities.pulse_duration_s)
	var images: Array[Image] = PulseEffect.build_images(radius, count)
	var isak := Image.load_from_file(ProjectSettings.globalize_path(ISAK_FRAME))
	isak.convert(Image.FORMAT_RGBA8)
	var side: int = PulseEffect.canvas_size_for(radius)
	# celda: lienzo del efecto con el centro en el celular y a Isak debajo
	var cell: int = side + MARGIN * 2
	var rows: int = ceili(float(count) / COLUMNS)
	var sheet := Image.create_empty(cell * COLUMNS, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	for i: int in count:
		var origin := Vector2i((i % COLUMNS) * cell + MARGIN, (i / COLUMNS) * cell + MARGIN)
		var center: Vector2i = origin + Vector2i(side >> 1, side >> 1)
		# Isak: los pies estan abajo y centrados en el canvas (128x128 -> (64, 128))
		var feet: Vector2i = center - PHONE
		var feet_in_sprite := Vector2i(isak.get_width() >> 1, isak.get_height())
		sheet.blend_rect(isak, Rect2i(Vector2i.ZERO, isak.get_size()), feet - feet_in_sprite)
		var fx: Image = images[i].duplicate()
		var alpha: float = PulseEffect.frame_alpha(i, count)
		for y: int in side:
			for x: int in side:
				var c: Color = fx.get_pixel(x, y)
				if c.a > 0.0:
					c.a = alpha
					fx.set_pixel(x, y, c)
		sheet.blend_rect(fx, Rect2i(0, 0, side, side), origin)
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err: Error = sheet.save_png(out_path)
	print("render_pulse_preview: %d cuadros, lienzo %dx%d, radio %d -> %s (%s)" % [
		count, side, side, roundi(radius), out_path, error_string(err)])
	quit(0 if err == OK else 1)
