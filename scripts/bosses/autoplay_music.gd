## Marca de la musica del jefe Autoplay (paso 20 de docs/propuesta-mundo-2.md,
## 2026-10-23): mientras un AutoplayMusic esta en el arbol suena su bucle
## (ambience de data/audio.json: mus_boss2, la mezcla de los bucles del feed;
## provisional). Autoplay lo crea al empezar la pelea y lo quita en el golpe
## final (antes de la recompensa y mus_memory), como BossMusic en Alerta Mayor.
## No hereda de BossMusic: el ambiente se enlaza por clase y sonaria tambien
## mus_boss1. Sin logica.
class_name AutoplayMusic
extends Node
