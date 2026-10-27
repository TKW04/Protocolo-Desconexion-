# Arte del Mundo 3 con AutoSprite (paso 23 de `propuesta-mundo-3.md`)

Plan y presupuesto aprobados por el usuario el 2026-10-27 («continúa con el arte final»): `propuesta-mundo-3.md` §6.2, **68-71 créditos** en una pasada (hasta ~142 con reintentos), con **parada tras cada personaje base** para enseñarlo antes de seguir. El flujo y las lecciones son los de Autoplay y el Comentarista (`plan-arte-mundo-2.md`) y Alerta Mayor (`plan-arte-jefe-alerta-mayor.md` §7).

## 1. Bases (paso 23a, 2026-10-27)

### 1.1 Créditos

Saldo al empezar (`get_account`): **380**, el que da §6.2. Tope de esta pasada: 12 créditos (2 bases y hasta 2 reintentos de base); sin poses ni animaciones.

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| 1 | `create_character` (`pixelArt`, `isHumanoid: false`) | Base «La Curadora» (`cmvqtdvrk0015ac1uejr87glv`) | 3 (previsto) | 377 (previsto) |
| 2 | `create_character` (`pixelArt`, `isHumanoid: false`) | Base «Influencer bot» (`cmvqte8i800i58mjne5h1yzu3`) | 3 (previsto) | **374** (previsto) |
| | | **Esta pasada** | **6** (tope 12) | |

Sin reintentos. El saldo final no se ha vuelto a consultar (la herramienta pide un solo `get_account` por sesión): en Autoplay y el Comentarista el base no apareció descontado, así que la próxima pasada empieza con `get_account` y se anota aquí si da 374 o 380.

### 1.2 Prompts

En inglés, describiendo solo lo que debe aparecer, con los hex de la paleta B (`assets/palettes/mundo3.gpl`) y las siluetas de los provisionales (`tools/gen_boss_curator.py`, `tools/gen_world3_enemies.py`).

**La Curadora** (`characterDescription`: «a giant floating gold picture frame boss with a camera for a head on its top edge and a filtered pink portrait inside»):

> A huge ornate picture frame floating in the air, seen from the front, wide landscape shape twice as wide as tall. Thick muted antique gold frame (#b0a064) with pale gold bevel (#d6c896), dark bronze shade (#54442a) and round corner rosettes. Inside, a soft pastel pink portrait (#f8d6e8) of a smooth doll-like face with a perfect sweet smile. On the middle of the top edge sits a boxy dark plum camera (#181020) as its head, with one big round pearl-grey lens and a small white flash. Clean 16-bit pixel art, flat colors, few shades, centered on a plain white background.

**Influencer bot** (`characterDescription`: «a small pink creature with a camera head that poses on a white pedestal and fires a camera flash»):

> A small cute creature posing on top of a tall pedestal, seen from the front. Round soft pastel pink body (#f8d6e8) with dusty rose shading (#a8809a), two short arms raised in a showy pose. Its head is a boxy dark plum camera (#181020) with one round pearl-grey lens (#c4b8cc) and a tiny white flash on top. The pedestal is a bright white column (#fcf8fc) with pearl-grey shade and muted antique gold bands (#b0a064) at top and bottom. Clean 16-bit pixel art, flat colors, few shades, centered on a plain white background.

### 1.3 Resultado y valoración

Copias en `docs/capturas/arte-autosprite-2026-10-27/`: `curadora_base.png`, `curadora_base_recorte.png` e `influencer_base.png` (1024 × 1024, 32-33 colores).

- **La Curadora:** el marco y la cámara son los del diseño: marco dorado grueso con bisel y cuatro rosetas, retrato rosa pastel con una cara sonriente y la cámara morada oscura con lente gris perla y flash blanco en el centro del lado de arriba (como la lente en (256, 24) del provisional). **Defectos:** `pixelArt` volvió a pintar un cuerpo chibi debajo (casaca morada con botones dorados, piernas y zapatos), como con Alerta Mayor y Autoplay; el marco sale a ~1,77:1 (816 × 460 sin la cámara) y no a 2:1; el dorado es más cálido y saturado que el `dorado` apagado de la paleta (se corrige al reducir, como el magenta de Autoplay); la cara es más «chibi mona» que «muñeca perfecta» y los mofletes son salmón (al reducir deben caer en `corazon_rosa`, nunca en `alerta`). **No se reintenta:** se recorta solo el marco con la cámara (x 104-919, y 64-647 del base; `curadora_base_recorte.png`, 816 × 584) como en Autoplay. Falta, antes de las poses: pasarlo a su rejilla nativa, estirar a 2:1 duplicando columnas lisas del retrato y del marco (las rosetas y la lente siguen redondas), reducir a `mundo3.gpl` sin `alerta`, `alerta_sombra` ni los ámbar y subirlo gratis con `upload_character` como «La Curadora (marco)».
- **Influencer bot:** fiel al provisional y a la ficha: criatura rosa pastel con sombra malva, brazos en alto posando, cabeza-cámara oscura con lente gris perla y flash blanco encima, sobre una columna blanca con anillos dorados. Silueta clara y legible a 64 × 128 (pedestal ~mitad inferior, criatura arriba). **Defectos menores:** la cámara es casi negra (cae bien en `galeria_noche`, pero hay que comprobar que no se funda con el contorno a 64 px); el dorado de los anillos, también más saturado que el de la paleta; la proporción del dibujo (~1:2,6) es algo más alta que la caja de 1 × 2 tiles, así que al importar la criatura se encoge un poco o el pedestal se acorta. Sin cuerpo añadido: no hace falta recorte ni `upload_character`.

## 2. Plan del resto (aprobado el 2026-10-27; ejecutado: §3)

Precios de §6.2: pose 3, animación turbo 5, `upload_character` y `regenerate_*` 0.

| Pieza | Qué | Créditos | Con un reintento |
|---|---|---|---|
| Curadora | Recorte + estirado + paleta + `upload_character` | 0 | 0 |
| Curadora | Poses `Shooting` (lente baja con el flash cargado), `Turned` (de espaldas: tablero de madera y alambre) y `Posing` (retrato con el filtro más fuerte) | 9 | 18 |
| Curadora | Animaciones turbo `idle`, `flash`, `frame_down`, `turn`, `x_reflection` y `defeat` (una llamada, `custom`, `raw_prompt`, `first_frame`, `frameSize` 1024, vista de frente) | 30 | 60 |
| Influencer bot | Una pose (`Flash`: brazos juntos y flash encendido) | 3 | 6 |
| Influencer bot | Animaciones turbo `idle`, `flash_charge` y `stunned` (una llamada) | 15 | 30 |
| Isak | Pose `compress` (comprimirse, andar comprimido y volver; `generate_spritesheet` turbo sobre «Isak», +3 si hace falta una pose) | 5-8 | 10-16 |
| **Total que queda** | | **62-65** | 124-130 |

Con los 6 de las bases, el total del Mundo 3 queda en los 68-71 de §6.2 (saldo final previsto ~309-312). Después: importadores (`tools/import_boss_curator.py`, `tools/reduce_palette.py`) que encajen el arte sin cambiar tiempos ni cajas (los bots deben dar los mismos resultados).

## 3. Poses, animaciones e integración (paso 23b-d, 2026-10-27)

El usuario aprobó las bases con sus defectos («podemos vivir con esos defectos») y el resto en una pasada: 62-65 créditos, tope duro 80 (un reintento por pieza como mucho).

### 3.1 Créditos

Saldo al empezar: **377** (la primera pose dejó 374: de los dos bases del 23a solo aparece cobrado uno, como en Autoplay y el Comentarista).

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| — | `upload_character` (marco recortado y estirado, ver 3.2) | «La Curadora (marco)» (`cmvqtoosd00evpcnr83nvys09`) | 0 | 377 |
| 1 | `generate_pose` | Curadora `Shooting` (lente baja, flash cargado) | 3 | 374 |
| 2 | `generate_pose` | Curadora `Turned` (tablero de madera, travesaños y alambre) | 3 | 371 |
| 3 | `generate_pose` | Curadora `Posing` (filtro fuerte, destellos) | 3 | 368 |
| 4 | `generate_pose` | Influencer `Flash` (brazos juntos, flash encendido) | 3 | 365 |
| 5 | `generate_spritesheet` turbo (`custom`, modo `reference`, 512) | Isak `compress` | 5 | 360 |
| 6 | `generate_spritesheet` turbo (una llamada, 6 × 5; `first_frame`, `raw_prompt`, 1024) | Curadora `idle`, `flash`, `frame_down`, `turn`, `x_reflection`, `defeat` | 30 | 330 |
| 7 | `generate_spritesheet` turbo (una llamada, 3 × 5; `first_frame`, `raw_prompt`, 512) | Influencer `idle`, `flash_charge`, `stunned` | 15 | **315** (`get_account` al final) |
| | | **Esta pasada** | **62** (tope 80) | |

Sin reintentos: todo se aceptó a la primera. Total del Mundo 3: 62 + los 3 del base cobrado = 65 (dentro de los 68-71 de `propuesta-mundo-3.md` §6.2).

### 3.2 Desvíos y decisiones

- **Marco subido:** el recorte (`curadora_base_recorte.png`, rejilla de 8 px → 102 × 73 píxeles de arte) se estiró a **128 × 73** duplicando 13 columnas lisas a cada lado (entre las rosetas y la cara: x 14-31 y 70-86; la cara, la cámara y las rosetas siguen redondas), se redujo a `mundo3.gpl` sin rojos, ámbares ni Debug (mofletes → `corazon_rosa`) y se subió ×6 en un lienzo blanco de 1024. El marco sin la cámara queda a ~2,2:1 y la caja de 2:1 incluye la parte baja de la cámara. Copias: `hojas/curator/base_frame_native.png`, `base_frame_upload.png` y `docs/capturas/arte-autosprite-2026-10-27/curadora_marco_subido.png`.
- **Animaciones** (de la base a la base salvo lo dicho): `idle` (flota, la lente brilla y parpadea; bucle), `flash` (base → `Shooting`: la lente baja y el flash carga), `frame_down` (enfoca y mira abajo; bucle), `turn` (base → `Turned`: gira sobre su eje hasta enseñar el tablero), `x_reflection` (`Posing` → `Posing`: guiños y destellos; bucle) y `defeat` (desde la base: glitch de colores, grietas, la lente se rompe y se apaga en gris). Influencer: `idle` (posa y saluda; bucle), `flash_charge` (base → `Flash`) y `stunned` (se tambalea con la cabeza torcida; bucle). Como siempre, el orden de las hojas devueltas no seguía el del pedido: se identificaron mirándolas.
- **Hojas guardadas** reducidas (alfa premultiplicado, 256 colores): Curadora a cuadros de 512 (`hojas/curator/<anim>/spritesheet.png`), Influencer a 256 (`hojas/influencer/<anim>/`), Isak a 256 (`hojas/compress_right/spritesheet.png`); poses en `hojas/<pj>/pose_*.png`.

### 3.3 Integración

- **Curadora:** `python3 -I tools/import_boss_curator.py` (102 PNG `assets/sprites/bosses/curator_<anim>_NN.png`; `--check` en `tools/run_tests.sh`). La caja de la celda 0 de cada animación → 128 × 73 píxeles de arte con 8 de margen, rejilla de 4 px: lienzo de 576 × 356 colocado 32 px a la izquierda y 72 px por encima de la caja `frame` (`Curator.ART_MARGIN_PX`, `ART_TOP_PX`): la lente cae en `lens_px` (256, 24) y el borde de abajo del marco en el de la caja. Celdas: `idle` 0-5 y 11-23 (19; sin el destello de la lente de las 6-10, que se confundiría con el aviso del flash), `flash` 0, 3, …, 24 (9, uno por cuadro del aviso), `frame_down` y `x_reflection` 0-23, `turn` y `defeat` 0, 2, …, 24 (13). Todo a 12 fps del mundo.
- **Cuándo** (`Curator.get_art_frame()`): `defeat` desde el golpe final (se queda apagada; el desarme en píxeles toma el cuadro actual); `turn` al empezar la fase 2 (de espaldas, su último cuadro) y al revés al empezar la 3; `flash` durante el aviso; `frame_down` en las ventanas de las fases 1 y 3; `x_reflection` en la fase 3; `idle` en el resto. Sin los cuadros vuelve a los `_placeholder` (que siguen siendo los biombos, las fichas del álbum y la ficha de `tests/test_help_inert.gd`).
- **Influencer:** `python3 -I tools/import_influencer_bot.py` (57 PNG `assets/sprites/enemies/world3/influencer_bot_<anim>_NN.png`; `--check` en la suite): misma paleta, alto de 64 píxeles de arte (128 px) con la misma escala en x, pies abajo, rejilla de 2 px, lienzo de 96 × 160 en (-48, -144) del origen (`InfluencerBot.ART_OFFSET`). `idle` en reposo y enfriando, `flash_charge` por el progreso del aviso, `stunned` aturdido, `idle` 0 gris al 50 % derrotado; de frente, sin reflejar. Aro, cuenta y bocadillo siguen por código. `art_placeholder: false` en `data/enemies/influencer_bot.json`.
- **Isak:** `compress_idle` (celdas 5-8, 8 fps) y `compress_walk` (9-21, 12 fps) con `tools/import_sheet.py` a escala 0,38 (~52 px visibles; comandos en `docs/guia-sprites-ia.md`), en `tools/build_isak_frames.gd` → `scenes/player/isak_frames.tres`. `Isak.play_animation` / `update_air_animation` las sustituyen desde la mitad del aplastado (`COMPRESS_ART_MAP`); la pose provisional por escala queda de respaldo.
- **Tiempos, cajas, daño, textos y `data/bosses/curator.json` sin cambios.** Pruebas nuevas: `test_final_art_follows_its_state` (`tests/test_curator.gd`), `test_influencer_art_follows_its_state` (`tests/test_world3_enemies.gd`); `test_provisional_squash_pose` de `tests/test_compress.gd` pasa a `test_pose_uses_the_autosprite_frames_without_scaling`.
- **Resultados:** `test_curator` 12/12, `test_curator_arena` 17/17, `test_curator_bot` 7/7, `test_curator_help` 8/8, `test_gallery_bot` 6/6, `test_world3_enemies` 20/20, `test_compress` 17/17, `test_ground_pound` 19/19, `test_isak_animations` 19/19, `test_crop_tool` 9/9, `test_help_inert` 76/76. Bot ideal de la Curadora: 106,9 / 149,2 / 139,1 s (Caché / Kernel / Raíz), 0 golpes, energía mínima 83 / 81 / 84: idéntico a antes del arte.

### 3.4 Calidad y defectos vistos

- El marco, la cara y la cámara se reconocen y son coherentes entre animaciones; la paleta B se respeta (sin rojos ni ámbar; mofletes en `corazon_rosa`). El giro de la fase 2 y la derrota (grietas, gris) se leen muy bien.
- **La barra del jefe del HUD tapa la cámara** casi entera mientras la Curadora está arriba (ya tapaba la lente del provisional; ahora la cámara sobresale 40 px por encima de la caja para que la lente siga en `lens_px`): la bajada de la lente y la carga del `flash` apenas se ven salvo en las ventanas, cuando baja. El aro y la cuenta del flash (código) siguen igual. Arreglarlo pide mover la barra o la caja (no se ha tocado).
- El contador «99+» del marco cae sobre la roseta de arriba a la izquierda.
- `defeat`: el glitch de la IA tenía arcoíris (cian, verde, amarillo) que la paleta convierte en dorados y gris perla: se lee como ruido, no como glitch de colores.
- `x_reflection` parte de `Posing` (dorado más brillante): al pasar de `idle` a la fase 3 el marco cambia de tono de golpe (el giro al revés lo disimula).
- Influencer: más pequeño que el provisional (la criatura y el pedestal ocupan ~50 × 128 px); la cámara casi negra cae en `galeria_noche`, como el contorno, y se separa del cuerpo solo por la lente gris perla. La lente del arte queda ~6 px por encima de `lens_height_px` (96).
- Isak comprimido: la IA no llegó a «media altura» (agachado, ~78 % de alto), así que se importó a escala 0,38: se ve agachado **y algo más pequeño** que Isak (~52 px), más estrecho que la caja de 40 px de alto solo por 12 px arriba.
- Capturas en `docs/capturas/arte-autosprite-2026-10-27/` (`juego_*` con el flujo real de `tools/render_level_3_x.gd`; hojas de contacto `curadora_cuadros.png`, `influencer_cuadros.png`, `isak_compress_cuadros.png`).
