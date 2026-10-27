## Marca de la musica del jefe La Curadora (paso 19 de docs/propuesta-mundo-3.md,
## 2026-10-27): mientras un CuratorMusic esta en el arbol suena su bucle
## (ambience de data/audio.json: mus_boss3; provisional). Curator lo crea al
## empezar cada fase y lo quita en el golpe final (antes de la recompensa y
## mus_memory), como AutoplayMusic. No hereda de BossMusic ni de AutoplayMusic:
## el ambiente se enlaza por clase y sonaria tambien su musica. Sin logica.
class_name CuratorMusic
extends Node
