## Instalador del acertijo «Actualizacion del sistema» (2026-10-27, paso 3 de
## docs/propuesta-hub-mundos-4-6.md §2.2; lo monta HubUpdatePuzzle). Estacion
## HubStation de 2 x 3 tiles con una placa encima «Verificaciones n/3» (texto
## PROVISIONAL de data/hub_update.json, texts).
## - Pulso con menos de 3/3: se abre el panel con el progreso y lo que falta.
## - Pulso con 3/3: se abre el panel «listo» y se PIDE la instalacion una vez
##   (install_requested + is_install_requested). NO instala: la secuencia de
##   §3.1 y GameState.install_hub_upgrade son del paso 5, que consume esta senal.
## - Inerte (Papelera llena, §2.5): el panel solo dice «Recupera tus archivos de
##   la papelera» y no pide nada.
## Arte PROVISIONAL (HubProvisionalArt terminal escalado) hasta el paso 7.
class_name HubInstaller
extends HubStation

## Se ha pedido instalar `upgrade_id` (pulso con 3/3). Una vez por visita.
signal install_requested(upgrade_id: StringName)

var upgrade_id: StringName = &""
## Ids de las verificaciones en orden y sus nombres (texto de interfaz).
var check_ids: Array[StringName] = []
var check_names: Dictionary = {}
## Textos de data/hub_update.json (texts).
var texts: Dictionary = {}

var _done: Array[StringName] = []
var _inert: bool = false
var _install_requested: bool = false
var _plate: Node2D


func _ready() -> void:
	visual_kind = &"terminal"
	super._ready()
	var font: Font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_plate = PulsePrompt.make_plate(self, "Progress", get_progress_text(), font, int(_config.get("font_size", 12)),
		int(_config.get("font_scale", 2)), "#" + HubData.color("fondo_profundo").to_html(false),
		"#" + HubData.color("acento_cian").to_html(false), float(_config.get("label_padding_px", 3)), get_size().x,
		-float(_config.get("label_gap_px", 44)))


# --- Consultas ---

func get_done_count() -> int:
	return _done.size()


func get_total() -> int:
	return check_ids.size()


func get_missing() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in check_ids:
		if not _done.has(id):
			out.append(id)
	return out


func is_ready_to_install() -> bool:
	return not check_ids.is_empty() and get_missing().is_empty()


func is_install_requested() -> bool:
	return _install_requested


func is_inert() -> bool:
	return _inert


## «Verificaciones n/3» (o el aviso de la papelera si esta inerte).
func get_progress_text() -> String:
	if _inert:
		return String(texts.get("trash", "Recupera tus archivos de la papelera"))
	return String(texts.get("progress", "Verificaciones {n}/{total}")) \
		.replace("{n}", str(get_done_count())).replace("{total}", str(get_total()))


## Texto de la placa encima del instalador (pruebas).
func get_plate_text() -> String:
	var label := _plate.get_node_or_null(^"Text") as Label if _plate != null else null
	return label.text if label != null else ""


# --- Acciones ---

## Marca las verificaciones hechas (las da HubUpdatePuzzle).
func set_done(done: Array[StringName]) -> void:
	_done = done.duplicate()
	_refresh_texts()


func set_inert(value: bool) -> void:
	_inert = value
	_refresh_texts()


func _create_panel() -> HubPanel:
	var panel := HubPanel.new()
	panel.ready.connect(func() -> void:
		panel.set_options([{"id": &"back", "text": panel._text("option_back", "Volver")}])
		panel.option_chosen.connect(func(_i: int, _id: StringName) -> void: close()))
	return panel


func _on_opened() -> void:
	_refresh_panel()
	if _inert or not is_ready_to_install() or _install_requested:
		return
	_install_requested = true
	install_requested.emit(upgrade_id)


func _refresh_texts() -> void:
	if _plate != null:
		var font: Font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
		PulsePrompt.set_plate_text(_plate, get_progress_text(), font, int(_config.get("font_size", 12)),
			float(_config.get("label_padding_px", 3)))
	if is_panel_open():
		_refresh_panel()


func _refresh_panel() -> void:
	var panel: HubPanel = get_panel()
	if panel == null:
		return
	panel.set_title(String(texts.get("title", "Actualización del sistema")))
	var lines: Array = []
	if _inert:
		lines.append({"text": String(texts.get("trash", "")), "color": "ambar"})
	else:
		lines.append({"text": get_progress_text(), "color": "texto_claro"})
		if is_ready_to_install():
			lines.append({"text": String(texts.get("ready", "")), "color": "acento_cian"})
		else:
			var names: PackedStringArray = []
			for id: StringName in get_missing():
				names.append(String(check_names.get(id, String(id))))
			lines.append({"text": String(texts.get("missing", "Falta: {names}")).replace("{names}",
				String(texts.get("names_separator", ", ")).join(names)), "color": "texto_tenue"})
	panel.set_lines(lines)
