## Marca de la musica del jefe El Vendedor (paso 20 de docs/propuesta-mundo-5.md,
## 2026-10-29): mientras un VendorMusic esta en el arbol suena su bucle (ambience
## de data/audio.json: mus_boss5; provisional). Vendor lo crea al empezar cada fase
## y lo quita en el golpe final (antes de la recompensa y mus_memory), como
## SeenMusic. No hereda de las otras marcas de musica: el ambiente se enlaza por
## clase y sonaria tambien la suya. Sin logica.
class_name VendorMusic
extends Node
