# Arte del Mundo 2 con AutoSprite (paso 23 de `propuesta-mundo-2.md`)

Plan y presupuesto aprobados en `propuesta-mundo-2.md` §6.2 (Autoplay, Comentarista y golpe al suelo: 68-71 créditos, 136-142 con reintentos; tope de dos reintentos por pieza). Este documento registra lo ejecutado, lo gastado y las lecciones. El flujo es el de Alerta Mayor (`plan-arte-jefe-alerta-mayor.md` §7).

## 1. Autoplay (2026-10-23)

### 1.1 Créditos

Saldo según la memoria del proyecto tras Alerta Mayor: **442**. Antes de las poses AutoSprite seguía diciendo **442** (la primera pose dejó 439), así que el base no aparece descontado: o no se cobró o hubo +3 sin explicar (como los +13 de Alerta Mayor, `plan-arte-jefe-alerta-mayor.md` §7.1).

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| 1 | `create_character` (`pixelArt`) | Base «Autoplay» (`cmvl3qbvq000eo8o6iemizt6s`) | 3 (previsto) | 442 (según AutoSprite) |
| — | `upload_character` (pantalla recortada, ver 1.2) | «Autoplay (pantalla)» (`cmvlcfz6a00d714foge4840ff`) | 0 | 442 |
| 2 | `generate_pose` | `Playing` | 3 | 439 |
| 3 | `generate_pose` | `Loading` | 3 | 436 |
| 4 | `generate_pose` | `Paused` | 3 | 433 |
| 5 | `generate_spritesheet` turbo (una llamada, 6 animaciones × 5) | `idle`, `clip_cast`, `countdown`, `paused`, `x2`, `defeat` | 30 | **403** (`get_account` al final) |
| | | **Esta fase** | **39** (tope 39 + 39 de reintentos) | |

Sin reintentos: todas las piezas se aceptaron a la primera. Autoplay completo: 42 previstos (3 + 9 + 30), igual que §6.2.

### 1.2 Desvíos y decisiones

- **Base:** `pixelArt` volvió a pintar un chico chibi (sudadera) debajo de la pantalla. La pantalla era la del diseño (marco violeta y magenta, pantalla índigo, dos ojos-botón con play y barra de progreso), así que **no se reintentó**: se recortó solo la pantalla (x 80-943, y 80-559 del base de 1024), se pasó a su rejilla nativa (8 px → 108 × 60 píxeles de arte) y se **estiró a 2:1** (120 × 60) duplicando 12 columnas lisas en los tres huecos entre el marco y los ojos (los ojos siguen redondos), para encajar en la caja `screen` de 8 × 4 tiles (512 × 256). Se redujo a `mundo2.gpl` sin `alerta`, `alerta_sombra` ni los ámbar: el **magenta rosado cae en `magenta` / `magenta_sombra`**, nunca en el rojo de daño. Se reescaló ×6 en un lienzo blanco de 1024 (720 × 360, ~70 %) y se subió gratis con `upload_character`. Original, recorte nativo y lienzo subido en `hojas/autoplay/base*.png`; poses en `hojas/autoplay/pose_*.png`.
- **Poses** (3 créditos cada una, `generate_pose` sobre la pantalla subida): `Playing` (marco con brillo neón, barra a medias en magenta), `Loading` (ruedas de carga de puntos en los ojos, barra vacía), `Paused` (ojos grises con dos barras, marco violeta apagado). Las tres mantienen tamaño y posición.
- **Animaciones** (`custom`, `raw_prompt`, turbo `first_frame`, `frameSize` 1024, `removeBg` `default`, sin sonido): `idle` (base → base, bucle: el marco late), `clip_cast` (base → `Playing`: se encoge, toma aire y se enciende), `countdown` (`Loading` → `Loading`, bucle: las ruedas giran), `paused` (`Paused` → `Paused`, bucle: tiembla con líneas de glitch), `x2` (`Playing` → `Playing`, bucle: vibra y parpadea en avance rápido), `defeat` (desde `Playing`: glitch, los ojos se encogen, la imagen se recoge en una línea y se apaga).
- **Hojas guardadas** en `hojas/autoplay/<anim>/spritesheet.png` **reducidas a cuadros de 512** (caja media con alfa premultiplicado) y cuantizadas a 256 colores (3,2 MB en total frente a ~13 MB de las de 1024). El importador trabaja sobre esas copias; la pantalla mide ~360 px en ellas, casi tres veces la rejilla final.
- **Rejilla final de 4 px:** cada cuadro se reduce a 144 × 80 píxeles de arte (la pantalla, 128 × 64, con 8 de margen para el temblor y el glitch), pasa a la paleta y se amplía ×4 sin filtro (lienzo 576 × 320, pantalla 512 × 256). La referencia de cada animación es su primera celda (la pose de partida); todas sus celdas usan la misma transformación, así que el movimiento se conserva.
- **Contador «99+»:** con el marco más grueso se mueve dentro de la pantalla (36, 30 px desde la esquina de la caja; antes 20, 18).

### 1.3 Integración

- **Cuadros:** `python3 -I tools/import_boss_autoplay.py` (117 PNG en `assets/sprites/bosses/autoplay_<anim>_NN.png`; `--check` comprueba que están al día, en la paleta y con esquinas transparentes).

| Animación | Celdas | Cuadros | Cómo avanza (tiempo del mundo) | Cuándo |
|---|---|---|---|---|
| `idle` | 0-23 | 24 | 12 fps en bucle | fuera de la pelea, huecos y ventana de las fases 1 |
| `clip_cast` | 0, 2, 3, 5, 7, 9, 11, 13 | 8 | 12 fps, se queda encendida | durante un clip (ola, rayos, barrido, cuenta atrás tras disparar) |
| `countdown` | 0-23 | 24 | 12 fps en bucle | se ve la cuenta («Siguiente video en N» o el «3-2-1») |
| `paused` | 0-23 | 24 | 12 fps en bucle | en pausa |
| `x2` | 0-23 | 24 | 12 fps en bucle | fase 3 (salvo pausa y cuenta) |
| `defeat` | 0, 2, …, 24 | 13 | 12 fps, se queda apagada | golpe final; el desarme en píxeles toma el cuadro actual |

- **Código:** `scripts/bosses/autoplay.gd` (`ART_ANIMS`, `get_art_anim()`, `_art_texture()`): el `Sprite2D` de la pantalla cambia de cuadro en `_refresh_screen` y se coloca 32 px por encima y a la izquierda de la caja. Si faltan los cuadros, vuelve a los `_placeholder`. **Tiempos, cajas, daño y textos sin cambios.**
- **Siguen por script** (`tools/gen_boss_autoplay.py`, con `_placeholder`): el **pie** (`stand`), el cabezal, las tarjetas de la cinta, las fichas del álbum y las tres pantallas provisionales (respaldo y origen de la ficha `autoplay` del álbum en `tools/gen_album_cards.py`, que no se ha tocado). Las miniaturas de los clips (`ScreenFx`) y los textos de la pantalla siguen dibujados por código encima del arte.
- **Resultados:** `test_autoplay.gd` 34/34, `test_autoplay_help.gd` 7/7, `test_boss_bar.gd` 8/8, `test_autoplay_bot.gd` 7/7; bot ideal en Caché 105,4 s, 0 golpes, 0 muertes, energía mínima 39 (idéntico a antes del arte).
- **Capturas** (con ventana, flujo real): `$GODOT --fixed-fps 60 --path . -s tools/render_level_2_x.gd -- --level 2-boss --out <carpeta>`.

### 1.4 Calidad y defectos vistos

- La pantalla se reconoce y es coherente entre animaciones; la paleta B se respeta (sin rojos ni ámbar en el cuerpo).
- El brillo neón de `Playing` / `x2` y los resplandores de `idle` dejan anillos lavanda alrededor de los ojos al reducir la paleta (se leen como halo; aceptable).
- El cuadro 2 de `clip_cast` (encogerse) baja la pantalla unos 30 px durante 1-2 cuadros.
- La miniatura del clip (`ScreenFx`, abajo a la derecha) y la caja roja de la «Cuenta atrás» pisan el ojo derecho; el texto de la pantalla, la barra de progreso del arte. Es dibujo por código heredado del provisional: se puede recolocar sin tocar el arte.
- La barra del jefe del HUD tapa el borde superior de la pantalla (ya pasaba con el provisional).

### 1.5 Lecciones

- Igual que con Alerta Mayor: `pixelArt` añade un personaje; recortar y subir gratis evita reintentar el base.
- Estirar en la rejilla nativa duplicando columnas lisas cambia la proporción sin deformar los círculos.
- Pedir `frameSize` 1024 y guardar las hojas reducidas a 512 da margen de calidad sin cargar el repositorio.
- Pedir todas las animaciones en una sola llamada funciona; el orden de las hojas devueltas **no** sigue el del pedido: identificarlas mirándolas.

## 2. Pendiente (fases posteriores, con su propio visto bueno)

- **Comentarista** (base, una pose, `idle`, `spit`, `stunned`: 21 créditos, 42 con reintentos).
- **Golpe al suelo de Isak** (`ground_pound`: 5, +3 si hace falta una pose).
- Ficha del álbum `autoplay` con el arte final (cambiar el origen en `tools/gen_album_cards.py`) y `import_boss_autoplay.py --check` en `tools/run_tests.sh`.
