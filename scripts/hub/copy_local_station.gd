## Estacion «copia local» del hub (docs/propuesta-hub-y-guardado.md §4; paso 6
## de §6.2): el unico sitio donde se guarda. Es un HubStation (pulso para
## abrir, Isak de espaldas) con el panel CopyLocalPanel. Al guardar, destello
## cian del monitor (save_flash_s de la seccion copy_local de data/hub.json).
## Arte PROVISIONAL: monitor con el icono de copia (HubProvisionalArt
## terminal/copy) hasta integrar assets/sprites/hub/local_copy/ (`frames`).
class_name CopyLocalStation
extends HubStation

var _copy: Dictionary = HubData.section("copy_local")


func get_copy_panel() -> CopyLocalPanel:
	return get_panel() as CopyLocalPanel


func _create_panel() -> HubPanel:
	var panel := CopyLocalPanel.new()
	panel.saved.connect(_on_saved)
	return panel


func _on_saved(ok: bool) -> void:
	if ok:
		flash(float(_copy.get("save_flash_s", 0.3)))
