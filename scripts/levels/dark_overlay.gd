## Capa por encima del velo del Modo oscuro (DarkZone) para lo que siempre se ve
## (2026-10-28, paso 5 de docs/propuesta-mundo-4.md §8 y regla de legibilidad de
## §3.6): la crea un objeto o enemigo del Mundo 4 que esta dentro de una zona
## oscura (DarkOverlay.attach) y llama cada cuadro a host.draw_dark_overlay(capa)
## para dibujar ahi, en coordenadas locales del host, su contorno rojo o su aviso.
## Fuera de lo oscuro no se crea (el dibujo normal no cambia).
class_name DarkOverlay
extends Node2D

const METHOD: StringName = &"draw_dark_overlay"

## Nodo que dibuja en la capa (debe tener draw_dark_overlay(canvas)).
var host: Node


## Crea la capa como hija de `host` si `point` (global) esta bajo el velo de una
## DarkZone; si no, null.
static func attach(host_node: Node2D, point: Vector2) -> DarkOverlay:
	if host_node == null or not host_node.is_inside_tree():
		return null
	if DarkZone.covering(host_node.get_tree(), point) == null:
		return null
	var layer := DarkOverlay.new()
	layer.name = "DarkOverlay"
	layer.host = host_node
	layer.z_as_relative = false
	layer.z_index = DarkZone.veil_z() + 1
	host_node.add_child(layer)
	return layer


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if host != null and is_instance_valid(host) and host.has_method(METHOD):
		host.call(METHOD, self)
