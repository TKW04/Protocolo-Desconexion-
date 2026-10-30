# Arte del Mundo 5 con AutoSprite (paso 24 de `propuesta-mundo-5.md`)

Presupuesto de `propuesta-mundo-5.md` §6.2, autorizado por el usuario el 2026-10-29/30: **hasta 57 créditos** en total para El Vendedor (base 3 + poses `Offering`, `Turning` y `Processing` 9 + animaciones turbo `idle`, `turn`, `throw`, `processing`, `offer` y `defeat` 30 = 42) y las tres poses de combo de Isak (Embestida, Filo y Sismo, ~15). Con **parada tras el personaje base** para enseñárselo al usuario (regla de los Mundos 2-4). Flujo y lecciones de El Visto y el Troll (`plan-arte-mundo-4.md`).

## 1. Etapa 1: base de El Vendedor (2026-10-30)

### 1.1 Créditos

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| — | `get_account` | | 0 | **255** (no 249: la memoria se había quedado corta, como en el Mundo 2) |
| 1 | `create_character` (`pixelArt`, `isHumanoid: false`) | «El Vendedor» (`cmvv86bii00xgdt25nk8w7cxt`) | **3** | **252** (`get_account`) |

Sin reintentos. Esta vez el base **sí se cobró**.

### 1.2 Prompt

En inglés, describiendo solo lo que debe verse (lección de Alerta Mayor), vista frontal, «Only the machine, nothing else» (lección del Troll: sin rótulos ni figuras inventadas):

- `characterDescription`: «a giant vending machine with two jointed mechanical arms and a neon smile on its screen face; always faces the viewer; it offers products with its arms, turns around, throws surprise boxes from its tray and processes payments»
- `prompt`: «A giant vending machine seen straight from the front, tall wide box of dark charcoal-violet metal with a thick near-black outline and violet neon trim. Top half: a glowing screen face with a wide friendly magenta neon smile and two small neon eyes. Middle: a glass window with rows of small boxes with bright yellow price tags. Bottom: a dark output tray. Two jointed mechanical arms with grabber hands out of the sides, open in a welcoming gesture. Only the machine, nothing else. Clean 16-bit pixel art, flat colors, few shades, plain white background.»

### 1.3 Archivos

- `hojas/vendor/base.png` (el base tal cual: 1024 × 1024, opaco sobre blanco, 33 colores) y copia en `docs/capturas/arte-autosprite-2026-10-30/vendedor_base.png`.
- Hoja de contacto `docs/capturas/arte-autosprite-2026-10-30/vendedor_base_contacto.png`: el base sobre blanco, sobre `negro_fondo` y sobre `gris_escaparate` (fondo blanco quitado con un relleno desde el borde), y una reducción de prueba a `mundo5.gpl` sin rojos, ámbares ni el blanco del Debug, a 80 px de arte (rejilla 4, 320 px de alto) con la caja de 4 × 5 tiles (256 × 320) encima.

### 1.4 Qué cuadra y defectos vistos (a ojo)

- **Cuadra:** máquina expendedora de frente, alta, con pantalla-cara y **sonrisa de neón magenta** (lo más legible, también reducida), escaparate de productos con **etiquetas amarillas**, **bandeja de salida** abajo y **dos brazos mecánicos** articulados con pinzas que salen por los lados en gesto de ofrecer. `pixelArt` **no pintó un chibi** debajo (a diferencia de Alerta Mayor, Autoplay y la Curadora): no hace falta recortar personaje. Magenta y violeta: los neones de la paleta B. Sin rótulos ni texto inventados. El «Cancelar» no se ve (correcto: va en la espalda).
- **Halo blanco:** quedan píxeles blancos sueltos en el contorno (puntas de las pinzas, esquinas de arriba y de las patas) que sobre el negro se ven como puntos; hay que limpiarlos antes de subirlo.
- **Rim light cian/turquesa** a lo largo del lado derecho de la máquina y en los brazos: la regla 6 de §6.1 prohíbe cian en los neones (se confunde con el cian de Isak). Al reducir cae en `gris_etiqueta`, pero conviene quitarlo a mano en el base antes de las poses (como el halo de El Visto).
- **Contorno sobre fondo oscuro:** el cuerpo violeta muy oscuro y el contorno casi negro se funden con `negro_fondo` (la lección del Troll en el 4-1); se lee por el neón de la pantalla y los productos, pero la silueta de la caja y sobre todo los **brazos gris oscuro** se pierden reducidos. Habrá que aclarar el cuerpo un paso (`gris_escaparate`) o confiar en el borde violeta.
- **Colores de los productos:** cajas naranjas, rojo-rosadas y verde oliva (naranja y rojo prohibidos en carteles por la regla 4). Reducidos sin rojos/ámbares caen en amarillo, magenta y grises: aceptable, pero varios productos se vuelven manchas grises o amarillo sombra; las etiquetas amarillas, bien.
- **Proporción:** el cuerpo mide ~0,6:1 (unos 580 × 950 del base) y la caja del juego es de 4 × 5 tiles (0,8:1); con los brazos el dibujo entero es ~1,06:1. Para que la máquina llene la caja habría que estirar en x columnas lisas (lados del cuerpo y del escaparate), como el marco de la Curadora, o dejar el cuerpo algo más estrecho que la caja.
- **Detalles que se perderán en reposo:** a 80 px de arte los ojos de la pantalla quedan en 2 × 2 px y los iconos de los productos se borran (lección de El Visto: el check gris en reposo).

~~Pendiente: visto bueno del usuario al base~~ (aprobado; etapa 2, abajo).

## 2. Etapa 2: limpieza, poses, animaciones e integración (2026-10-30)

Autorizado por el usuario: hasta **39** créditos (3 poses = 9 + 6 animaciones turbo = 30), del tope de 57 del Mundo 5 (los ~15 de las poses de combo de Isak van aparte, en otra tarea).

### 2.1 Créditos

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| — | `get_account` | | 0 | **252** |
| — | `upload_character` (`isHumanoid: false`; la herramienta no admite `pixelArt`) | «El Vendedor (limpio)» (`cmvv9qhah00pzzfh0oumwbkj6`) | 0 | 252 |
| 1 | `generate_pose` | `Offering` (`cmvv9r26600rgzfh0z736ov49`): brazos hacia delante, palmas arriba, sonrisa más ancha | 3 | 249 |
| 2 | `generate_pose` | `Turning` (`cmvv9sr5001s7tad6ymkoa5cx`): girada hacia la derecha, cara y brazo derecho a la derecha | 3 | 246 |
| 3 | `generate_pose` | `Processing` (`cmvv9tyz201swtad66zwr8p00`): anillo de 8 puntos en la pantalla, brazos recogidos | 3 | 243 |
| — | `save_pose` (subida) | `Turning Left` (`cmvv9u2a100fs92j81a2f95eo`): `Turning` reflejada a mano, final del giro | 0 | 243 |
| 4 | `generate_spritesheet` turbo (una llamada, 6 × 5; `first_frame` con las poses, `raw_prompt`, 25 cuadros de 512) | `idle`, `turn`, `throw`, `processing`, `offer`, `defeat` | **30** | **213** (respuesta de la llamada) |
| | | **Esta etapa** | **39** (tope 39) | |

Sin reintentos: todo se aceptó a la primera. Total de El Vendedor: 3 + 39 = **42** (dentro del tope de 57 con los ~15 de Isak). El `get_account` final no respondió (dos tiempos de espera agotados); el saldo es el de la respuesta de la última llamada (213, sin contar lo que gaste en paralelo la tarea de Isak).

Jobs: poses `cf_29ce9e86-…` (Offering), `cf_5e1662b0-…` (Turning), `cf_467c6117-…` (Processing); hojas `wf_77641381-…` → `cmvv9xf7201uedt25mnjkaimx` (idle), `wf_21c7069c-…` → `cmvv9xmfo00gs92j85dzqw6yl` (turn), `wf_5d704ffc-…` → `cmvv9wnab00vyzfh03bb399qn` (throw), `wf_048b4bdc-…` → `cmvv9wel401s8dt25wg1xqbay` (processing), `wf_9f7f33c1-…` → `cmvv9xgw301umdt25j0kelplj` (offer), `wf_63483402-…` → `cmvv9wzei00gh92j85k3y16yc` (defeat). Esta vez el orden de las hojas coincidía con el del pedido; se identificaron mirándolas.

### 2.2 Limpieza del base y decisión de subirlo

- **Se sube el base limpio** (como El Visto «sin halo»): las poses y las hojas salen de la imagen subida, así que el halo, el cian y los naranjas/rojos se habrían copiado en cada cuadro. `tools/clean_vendor_base.py` (gratis, en la rejilla nativa de 128 × 128: el base es pixel art a rejilla 8): fondo y halo blancos fuera con un relleno desde el borde (y dos pasadas de grises claros pegados al fondo), el **rim light cian** pasa al violeta del borde, las cajas **naranjas** a violeta neón (el naranja suelto de las etiquetas a amarillo sombra), las **rojo-rosadas** a magenta sombra, la **oliva** a gris violeta y el marrón a violeta oscuro. Resultado en `hojas/vendor/base_upload.png` (copia `docs/capturas/arte-autosprite-2026-10-30/vendedor_base_limpio.png`).
- **No se aclara ni se estira el base**: el contraste y la proporción los da el importador (más abajo), para que la IA anime desde las proporciones que ella misma pintó.

### 2.3 Prompts

En inglés, describiendo solo lo que debe verse, con la vista fijada y «Only the machine on a plain white background, nothing else in the picture». `idle` (de `Turning` a `Turning`: zumba, se mece, el brazo derecho se balancea, parpadea; bucle), `turn` (de `Turning` a `Turning Left`: recoge los brazos, la sonrisa se apaga, gira en el sitio y la cara se enciende al otro lado), `throw` (de `Turning` a `Turning`: el brazo derecho lanza hacia arriba a la derecha), `processing` (de `Processing` a `Processing`: el anillo de puntos gira; bucle), `offer` (de `Offering` a `Offering`: los brazos ofrecen adelante y atrás, la sonrisa late; bucle) y `defeat` (desde el base: franjas de glitch, la sonrisa se vuelve un ceño, la pantalla se apaga, los brazos caen). Sin rótulos ni texto inventados en ninguna hoja.

### 2.4 Integración

- `python3 -I tools/import_boss_vendor.py` (147 PNG en `assets/sprites/bosses/vendor/`, con sus `.import`; `--check` en `tools/run_tests.sh`; prueba `tests/test_import_boss_vendor.py`, 5): en cada animación la celda de referencia da la **caja del cuerpo** (las columnas opacas en al menos el 70 % del alto; los brazos quedan fuera) y esa caja **llena la caja de 4 × 5 tiles** (64 × 80 de arte a rejilla 4 = 256 × 320; fit «box»: se estira en x de ~0,6:1 a 0,8:1, los brazos con ella), con 32 × 6 de margen para los brazos: lienzo de **512 × 368** en (−128, −24) de la caja (`Vendor.ART_BODY_OFFSET`). Paleta `mundo5.gpl` sin rojos, ámbares ni el blanco del Debug; píxeles sueltos fuera; **borde de la silueta en `violeta_neon`** (≥ 3:1 con `negro_fondo`, `negro_medio` y `gris_escaparate`, medido en la prueba): sin él el cuerpo `gris_escaparate` se fundía con las columnas del gran almacén. Aclarar antes de reducir se probó y se quitó: juntaba la pantalla y el cuerpo en el mismo gris con ruido.
- Celdas: `idle`, `processing` y `offer` 0-23 (bucles), `turn`, `throw` y `defeat` 0-24.
- **Cuándo** (`Vendor.get_art_frame()`, `ART_ANIMS`): `idle` por defecto **mirando a Isak** (las hojas de `idle`, `turn` y `throw` miran a la derecha; reflejadas cuando mira a la izquierda, `ART_FLIP`); en el **aviso del giro** (`turn.warn_frames`, 9 cuadros) los 8 primeros cuadros de `turn` (recoge los brazos y la sonrisa se apaga) por su progreso y en el **giro** (`turn.anim_s`) el resto (de lado, de espaldas, de frente al otro lado; `ART_TURN_WARN_CELLS`); `processing` con «Procesando devolución…» o Isak congelado («Procesando pago…»); `throw` una vez al lanzar cada tanda de cajas; `offer` 1 s al pagar una plataforma y mientras baja el cartel de la oferta de la fase 3; `defeat` desde el golpe final (empieza en el cuadro 6, ya con glitch) y el desarme en píxeles suelta su último cuadro. Sin los cuadros vuelve al provisional por código.
- **La espalda**: no hay arte de espaldas (la máquina siempre mira de frente); la espalda la sigue marcando el «Cancelar» (`WeakPoint`, por código), como antes. Plataformas con precio, brazo que barre, monedas, carteles, bandeja del frente, ranura y túnel abiertos siguen por código (`VendorFx`, encima del dibujo).
- **Sin cambios**: cajas de colisión, tiempos, giro de 1,2 / 0,9 s con su aviso de 9 cuadros, fases y datos (solo la nota de `data/bosses/vendor.json`).
- Pruebas: `test_final_art_follows_its_state` (`tests/test_vendor_boss.gd`, 17/17), `test_vendor_arena` 27/27, `test_vendor_help` 11/11, `test_boss_bar` 14/14, `test_vendor_bot` 7/7 (ideal en Caché **110,6 s**, sin golpes ni muertes, como antes), `tests/test_import_boss_vendor.py` 5/5, `tests/test_boss_data.py` 15/15 (sin `-I`: con `-I` el importador de Alerta Mayor no encuentra Pillow, ya pasaba), `tests/test_boss_validator.py` 74/74, `validate_ui_assets` 0 errores, `validate_level.py data/levels/5-boss.json` en verde.
- Capturas con el flujo real (`tools/render_level_5_x.gd -- --level 5-boss`): `docs/capturas/arte-autosprite-2026-10-30/juego_vendedor_*.png` (y las 17 en `assets/levels_preview/5-boss/`); hojas de contacto `vendedor_cuadros.png` (una de cada tres) y `vendedor_giro_cuadros.png` (los 25 de `turn`); poses `vendedor_pose_*.png`.

### 2.5 Calidad y defectos vistos

- La máquina se reconoce y es coherente entre animaciones: pantalla-cara con la sonrisa magenta, escaparate con etiquetas amarillas, bandeja y dos brazos; sin rojos, ámbares ni blanco del Debug; el borde violeta la separa del fondo; mira a Isak y el giro se lee (brazos que se recogen, pantalla que se apaga, vista de lado y de espaldas).
- **Pantalla con grano**: en `processing` y algunos cuadros de `idle` el negro de la pantalla queda moteado (`negro_medio` / `gris_escaparate`) aun quitando píxeles sueltos.
- **Brazos gruesos y grises** en `offer`; en reposo los brazos (`gris_escaparate`) se leen sobre todo por el borde violeta.
- **Etiquetas en amarillo sombra**: al reducir, las etiquetas de los productos quedan en `amarillo_sombra` (más apagadas que en el base) y los iconos de los productos se borran a 80 px de arte.
- **`defeat`**: las franjas de glitch eran cian en la hoja; reducidas caen en crema y gris (correcto por la regla 6, pero menos vivas).
- **El giro es rápido**: los 17 cuadros del giro caben en 0,25 s (`turn.anim_s`): la vista de espaldas dura 1-2 cuadros del juego. El aviso (8 cuadros en 0,75 s) sí se ve.
- **`throw`**: el brazo lanza un producto pequeño que la IA dibujó (una cajita amarilla); las cajas de verdad siguen saliendo por código, así que hay un instante con las dos.
- La ranura abierta (fase 3) y el túnel de la bandeja (fase 2) se dibujan como rectángulos oscuros encima del arte (por código, como antes).
- La captura `04_fase1_giro` cae en el reposo y no en el giro (temporización de la captura); el giro se ve en `vendedor_giro_cuadros.png`.
