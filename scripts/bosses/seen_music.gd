## Marca de la musica del jefe El Visto (paso 20 de docs/propuesta-mundo-4.md,
## 2026-10-28): mientras un SeenMusic esta en el arbol suena su bucle (ambience
## de data/audio.json: mus_boss4; provisional). Seen lo crea al empezar cada fase
## y lo quita en el golpe final (antes de la recompensa y mus_memory), como
## CuratorMusic. No hereda de las otras marcas de musica: el ambiente se enlaza
## por clase y sonaria tambien la suya. Sin logica.
class_name SeenMusic
extends Node
