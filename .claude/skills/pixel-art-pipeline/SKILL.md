---
name: pixel-art-pipeline
description: Reglas y flujo de trabajo para crear, validar y exportar sprites, tiles y efectos en pixel art de Isak Fix. Úsalo al generar o modificar cualquier asset gráfico.
---

# Pipeline de pixel art

## Tamaños

| Elemento | Tamaño |
|---|---|
| Isak e Isak Optimizado | canvas 128x128 (unos 96 px de altura visible, pies abajo-centro) |
| Tiles | 64x64 |
| Enemigos | entre 64x64 y 128x128 |
| Jefes | entre 256x256 y 512x512 |
| Efectos | múltiplos de 8 |

Resolución base del juego: 1280x720 (decisión del 2026-10-14; antes 640x360). No uses escalas que no sean enteras.

## Paletas

- Una paleta por mundo en `assets/palettes/<mundo>.gpl`, de unos 16 colores, más el color del Debug.
- Colores de Debug: Mundo 1 cian, 2 ámbar, 3 verde ácido, 4 coral, 5 blanco, 6 cambia por zona.
- No uses ningún color fuera de la paleta del mundo. Excepción: el arte de Isak (e Isak Optimizado) viene de hojas generadas con IA y pasa por `tools/import_sheet.py`, que no lo reduce a una paleta fija; no lo valides contra una `.gpl`.
- Los hex exactos aún no están decididos. Propón una paleta, muéstrala como imagen y espera aprobación antes de usarla.
- Rojo igual a daño y puntos débiles. En el Mundo 1 las alertas son rojo anaranjado y el punto débil es carmín puro y pulsante.

## Reglas de diseño

- Silueta primero: debe reconocerse en negro.
- Cada ataque enemigo se anticipa de 6 a 12 cuadros antes de dañar.
- Cada mundo tiene su familia de formas: burbujas redondas (1), tarjetas rectangulares (2), marcos y espejos (3), burbujas de texto (4), carteles y cajas (5).
- Copias optimizadas (Mundo 6): misma silueta que el enemigo original, paleta desaturada, sin animaciones secundarias.
- Isak (referencia: `../Ejemplo/Idle.png`, fuera del repo): chico de proporciones algo chibi, pelo castaño oscuro desordenado, sin lentes; chaqueta gris oscura tipo táctica con detalles cian luminosos en el cuello y un parche cian en el hombro; camiseta/chaleco negro con un logo claro en el pecho; mochila marrón; pantalón gris oscuro con bolsillos; botas grises con detalles naranja; celular en la mano. La luz de contorno de un píxel y el LED de Debug en la mochila del documento original no aparecen en la referencia: no los añadas ni los descartes sin preguntar. Ver `docs/07-estilo-visual.md` §15.4.
- Isak Optimizado: igual, más saturado y limpio, sin LED (si Isak llega a tenerlo) y sin rebote de mochila.

## Animaciones

Nombres de archivo: `<entidad>_<animacion>_<NN>.png`, por ejemplo `isak_walk_00.png`. Velocidad: unos 12 cuadros por segundo para personajes y 24 para efectos.

| Animación de Isak | Cuadros |
|---|---|
| Caminar y correr | 6 a 8 |
| Idle (terminal holográfica) | 8 a 12 |
| Pulso de datos | 4 a 6 |
| Salto | anticipación, subida, apogeo, caída y aplastamiento |
| Daño | glitch de píxeles |
| Muerte | pixelado progresivo y líneas de código que suben |

## Flujo de trabajo

1. Elige la vía: Aseprite (si está instalado, usa su modo de línea de comandos para exportar hojas de sprites y datos JSON), scripts de Python con Pillow que dibujen con índices de paleta, o **importar hojas generadas con IA** (solo Isak por ahora): el usuario genera la hoja siguiendo `docs/guia-sprites-ia.md` y `tools/import_sheet.py` la corta, quita fondo y sombra, escala con nearest a 96 px visibles, alinea los pies en un canvas de 128x128 y valida. Prueba primero con `--dry-run --preview <png>` y no escribas en `assets/` sin revisar la vista.
2. Genera el asset y una vista ampliada x8 con interpolación nearest. Mírala como imagen antes de dar nada por bueno.
3. Valida con un script: tamaño correcto, solo colores de la paleta, fondo transparente.
4. Exporta a `assets/sprites/<categoría>/`.
5. Guarda el script de generación en `tools/` para poder rehacer el asset.

## Límites que debes respetar

- Tiles, interfaz, efectos y enemigos geométricos se pueden generar de forma procedural con buena calidad.
- Isak, Isak Optimizado y los jefes complejos se entregan como borrador con sufijo `_placeholder`. Dilo explícitamente: el usuario decidirá si se rehacen a mano.
- Si un resultado no se ve bien en la vista ampliada, no lo entregues. Ajusta o pide dirección.
