# Plan y presupuesto: arte final de Alerta Mayor con AutoSprite (paso 16)

> **PENDIENTE DE APROBACIÓN DEL USUARIO.** Este documento es solo un plan. No se ha generado nada ni se ha gastado ningún crédito. Para prepararlo solo se usaron consultas de lectura de AutoSprite (`get_account`, `list_characters`, `list_jobs` y `list_assets`) y las descripciones de las herramientas. No se llama a ninguna herramienta que cueste créditos hasta que el usuario apruebe la lista y el total de la §3.

Fecha: 2026-10-21. Diseño de referencia: `docs/propuesta-jefe-alerta-mayor.md` (§2.1, §2.2, §4.1 y §6.3, punto 3, sobre el «peso»). Reglas del arte: `.claude/skills/pixel-art-pipeline/SKILL.md`, `docs/guia-sprites-ia.md` y `assets/palettes/mundo1.gpl`.

---

## 1. Inventario del arte provisional actual

Todo está en `assets/sprites/bosses/`. Lo generan dos scripts: `tools/gen_boss_alert_major.py` (Alerta Mayor) y `tools/gen_boss_dummy_placeholder.py` (el «saco» de la sala `boss_test`). Los dos usan solo colores de `mundo1.gpl` y no llevan carmín, salvo la ficha del núcleo. Tienen fondo transparente (alfa 0 o 255) y un modo `--check` que comprueba `tests/test_boss_data.py` en `tools/run_tests.sh`.

### 1.1 Alerta Mayor (`tools/gen_boss_alert_major.py`)

El cuerpo se dibuja a `draw_scale` 2 (`data/bosses/alert_major.json`, `arena.draw_scale`). En pantalla mide `body_up_px` 256 × 256 (4 × 4 tiles) arriba y `body_down_px` 128 × 128 (2 × 2 tiles) abajo. El contador («99+», «66», «33») **lo escribe el juego encima** con la fuente de textos (`font_size` 12, etiqueta a ×2), así que el arte no lleva cifras.

| Archivo | Tamaño (px) | Estado o uso | Quién lo carga |
|---|---|---|---|
| `alert_major_rest_placeholder.png` | 128 × 128 (×2 = 256) | Reposo: inflado, flotando. Una pose fija que se desplaza entre las columnas 4 y 19. | `alert_major.gd` (`ART_REST`) |
| `alert_major_inflate_placeholder.png` | 128 × 128 | Inflándose: aviso antes de escupir (fase 1) y de dividirse (fase 3), con contorno blanco. | `ART_INFLATE` |
| `alert_major_down_placeholder.png` | 64 × 64 (×2 = 128) | Desinflado y abajo: la ventana en que se puede dañar (el jefe está «aturdido»). | `ART_DOWN` |
| `alert_major_clone_placeholder.png` | 64 × 64 | Copia de la fase 3. **Igual que el desinflado a propósito**: solo el Debug distingue la real por su núcleo. | `alert_major_clone.gd` |
| `alert_major_lunge_placeholder.png` | 64 × 64 | Copia lanzándose: estirada, con tres rayas grises de estela. Una sola imagen. | `alert_major_clone.gd` |
| `alert_major_pop_placeholder.png` | 64 × 64 | «Pop» de una copia descartada. | `alert_major_clone.gd` |
| `notification_shot_placeholder.png` | 64 × 32 | Notificación de la ráfaga (fase 2). | `notification_shot.gd` |
| `alert_major_shield_placeholder.png` | 32 × 32 | Icono del pop-up escudo (candado). | `alert_major.gd` (`ART_SHIELD`) |
| `boss_bar_icon_placeholder.png` | 16 × 16 | Icono de la barra del jefe en el HUD. | `boss_bar.gd` / `data/hud.json` |
| `boss_bar_frame_placeholder.png` | 16 × 16 | Marco nine-patch (4 px) de la barra. | `data/hud.json` |
| `boss_reward_panel_placeholder.png` | 16 × 16 | Marco nine-patch del panel de recompensa. | `boss_reward.gd` / `data/boss_reward.json` |
| `alert_major_core_card_placeholder.png` | 64 × 64 | Ficha del álbum del núcleo marcado. **Única con carmín.** | `tools/gen_album_cards.py` |
| `eco_boss_icon_placeholder.png` | 16 × 16 | Eco hablando por el jefe (icono con interferencia). | `data/eco_text_box.json` |

Varias cosas no tienen arte propio:

- **El desarme en píxeles.** `PixelBurst` toma la textura actual del cuerpo y la suelta en píxeles.
- **El núcleo.** `WeakPoint` lo dibuja aparte en carmín con su halo de marca, y los estados de la marca (revelado, marcado, aviso, caducada) son efecto de código.
- **El golpeado.** Es el impacto en el núcleo (`sfx_weak_point_hit`): no hay pose del cuerpo.
- **El escupir.** Es la pose `inflate` seguida de `rest`.

Los cambios de pose son **de golpe**: `alert_major.gd` cambia `_body.texture` entre `rest`, `inflate` y `down`. El movimiento lo hace el código: la bajada dura 0,4 s con `out_cubic` y la subida 0,45 s con `in_out_cubic` (§6.3).

### 1.2 Saco de prueba (`tools/gen_boss_dummy_placeholder.py`)

`boss_dummy_up_placeholder.png` y `boss_dummy_down_placeholder.png` miden 64 × 64 (a ×2) y llevan el «99+» dibujado. Solo los usa la sala `boss_test` (`boss_dummy.gd`). **No hace falta arte final**: se quedan como están.

### 1.3 Qué falta para el «peso» (§6.3, punto 3)

- **Anticipación y aplastamiento** al bajar y al aterrizar: el paso de `rest` a `down` hoy no tiene cuadros intermedios.
- **Estiramiento al subir**: el paso de `down` a `rest`.
- **Balanceo leve al flotar**: hoy el reposo es una imagen fija.
- **Inflarse con cuadros**: la anticipación de escupir y de dividirse.
- **Lanzamiento de las copias** con estiramiento y estela: hoy es una imagen `lunge`.
- **Fondo de pantalla de bloqueo con relojes.** Ya existe y es decorado del Mundo 1 (`tools/gen_world1_objects.py`: `mundo1_bg_cielo.png` con relojes grandes y `mundo1_bg_fondo_medio.png` con relojes y avisos). La arena no tiene un fondo propio.

---

## 2. Qué se genera con AutoSprite y qué sigue por script

### 2.1 Reparto

| Pieza | Vía | Motivo |
|---|---|---|
| **Cuerpo del jefe** (reposo, flotar, inflarse, bajar y aplastarse, subir y estirarse, ventana abajo) | **AutoSprite**: un personaje con poses y animaciones | Es la pieza grande (256 px en pantalla) y la que necesita cuadros de animación con peso. Ahí la IA aporta más que el script. |
| **Copias** (fase 3) | **AutoSprite, la misma hoja**: los cuadros de «ventana abajo» sin cambios | El diseño exige que la copia sea **idéntica** al desinflado; solo el núcleo con el Debug la distingue. No cuesta nada extra. |
| **Lanzamiento de las copias** (`lunge`) | **AutoSprite** (animación) + **estela por script** | El estiramiento sale en la animación. La estela se dibuja en `banner_gris` por código, como hoy, porque la guía pide efectos fuera de la hoja (§6 de `guia-sprites-ia.md`). |
| Pop de la copia, desarme en píxeles | Script / `PixelBurst` | Son efectos. `PixelBurst` usará el cuadro final. |
| Núcleo y estados de la marca | Código (`WeakPoint`) | El carmín solo vive ahí. El cuerpo no debe llevarlo. |
| Notificación-proyectil, icono del escudo, barra del jefe, marco de la recompensa, icono de Eco filtrado, ficha del núcleo | Script (`gen_boss_alert_major.py`) | Son interfaz y formas geométricas planas a 16-64 px, donde el script da buena calidad (skill, «Límites»). En el mejor caso la IA ahorraría poco. |
| Fondo de pantalla de bloqueo con relojes | Script (`gen_world1_objects.py`) | Ya existe. Si se quiere un fondo propio de la arena, se hace por script con la misma paleta. |
| Saco `boss_test` | Script (se queda) | Es solo para pruebas. |

### 2.2 Estilo, tamaño y paleta

- **Silueta y familia de formas:** la del Mundo 1, burbujas redondas. Un badge redondo que se reconozca en negro.
- **Concepto**, según `propuesta-jefe-alerta-mayor.md` §2.1: «un enorme badge rojo con el número 99+». Tono **sobrio y cálido**: sin cara agresiva, sin dientes y sin rojos por toda la pantalla. La insistencia se transmite con el ritmo.
- **Colores** (de `mundo1.gpl`): cuerpo `alerta` #FF4A2A, sombra `alerta_sombra` #A3221C, contorno `noche_profunda` #0B0E1A, brillo y campana `banner_blanco` #F2F4F8 y detalles `banner_gris` #AEB8D2. **Sin `carmin` ni `carmin_brillo`**: el carmín es solo del núcleo.
- **Hueco para el contador:** una pastilla blanca **en blanco**, sin texto. El juego escribe «99+» / «66» / «33» encima, y la IA no rotula bien cifras que además cambian.
- **Tamaño:** el skill pide para los jefes un lienzo de 256 a 512 px. Propuesta: AutoSprite a `frameSize` 256. Al importar, lienzo de **256 × 256 para los estados de arriba** y **128 × 128 para los de abajo y las copias**, dibujados a **×1** (`draw_scale` 1,0 en lugar de 2,0). Así el jefe tiene la misma densidad de píxeles que Isak, que se dibuja a ×1 con 96 px visibles, y los tamaños en pantalla no cambian (256 y 128).
- **Precedente:** el dash de Isak fue una animación `custom` turbo de 5 × 5 cuadros a 256 px por 5 créditos sobre el personaje «Isak», importada con `tools/import_sheet.py --cells` (`guia-sprites-ia.md`, «Cómo quedaron integradas las hojas»). Las poses cuestan 3 créditos (`generate_pose`) y la pose de espaldas costó 3.

### 2.3 Discrepancia con el encargo (a confirmar)

El encargo describe al jefe como «una pantalla de bloqueo de móvil con insignia "99+" como núcleo». El documento aprobado dice otra cosa:

- El jefe es **el badge**.
- La **pantalla de bloqueo es la arena**.
- El **núcleo es carmín** y solo se ve con el Debug.

Este plan sigue el documento aprobado. Si el usuario prefiere un cuerpo de «móvil con pantalla de bloqueo» con el badge encima, cambia el prompt base (§2.4, paso 1) pero no el presupuesto. Que la insignia sea el núcleo chocaría con «carmín solo en el núcleo» y con que el núcleo no se vea sin el Debug.

### 2.4 Llamadas y parámetros por pieza

Los prompts van en inglés porque AutoSprite trabaja mejor así. Siguen el consejo de la herramienta: **describir solo lo que debe aparecer**, porque nombrar lo que no se quiere tiende a hacerlo aparecer. Todas las animaciones son `custom` con `raw_prompt: true` (el jefe se ve **de frente**, y el envoltorio por defecto lo pondría de lado mirando a la derecha). Además se fijan el primer y el último cuadro con poses.

**Paso 1. Personaje base: `create_character`**

```json
{"name": "Alerta Mayor", "pixelArt": true, "isHumanoid": false,
 "characterDescription": "a large round floating notification badge with a bell icon; it bobs, inflates, deflates and squashes like a soft balloon",
 "prompt": "A large round notification badge floating in the air, seen from the front. A glossy flat disc of warm orange-red with a darker brick-red shade along the bottom edge and a thick very dark navy outline. A small white shine on the upper left. A blank white rounded pill label across the upper half. A simple white bell icon in the lower half. Calm, sober, friendly look. Clean 16-bit pixel art, flat colors, few shades, centered on a plain white background."}
```

- `pixelArt: true` (3 créditos, siempre `pro`) ajusta el resultado a una rejilla de píxeles y a 32 colores. Facilita la reducción a `mundo1.gpl`, y la vista frontal de ese modo es justo la que queremos.
- Alternativa al mismo precio: `quality: "pro"` sin `pixelArt`, que da más detalle y peor paleta.
- **Alternativa gratis:** `upload_character` con un base dibujado por script a 512 px (0 créditos). Ahorra 3 créditos, pero pierde lo que aporta la IA en el base.

**Paso 2. Margen para estirar y aplastar: `pad_character` con `character_size: 70`.** Cuesta 1 crédito. El lanzamiento y el estiramiento salen del cuadro si el badge lo llena. Para conservar el margen hay que animar en modo «primer cuadro», que se cumple al pasar `first_frame_pose_id`.

**Paso 3. Poses: `generate_pose`, 3 créditos cada una.** Sirven de cuadro inicial y final de las animaciones y garantizan la consistencia.

| Pose (`name`) | `prompt` |
|---|---|
| `Inflated` | "The same badge swollen bigger and rounder, stretched slightly taller, outline turned bright white, bell icon tilted upward, seen from the front." |
| `Deflated` | "The same badge deflated and squashed: half its height, wider than tall, resting on the ground, bell icon drooping, blank label still visible, seen from the front." |
| `Lunge` | "The same deflated badge stretched into a long horizontal oval, leaning toward the RIGHT side of the picture as if dashing forward." |
| *(opcional)* `Dazed` | "The same deflated badge tilted to one side, bell icon upside down, sleepy and dizzy." |

**Paso 4. Animaciones: `generate_spritesheet` en una sola llamada con varias animaciones.** Parámetros: `videoTier: "turbo"` (5 créditos por animación, clip de 2 s), `turboMode: "first_frame"`, `spritesheet: {"frameCount": 25, "frameSize": 256}`, `removeBg: "default"` y `withSound` desactivado. El sonido no se pide: los sonidos los hace un amigo del usuario.

| Animación (`name`) | Primer / último cuadro | `loop` | `prompt` | Uso en el juego |
|---|---|---|---|---|
| `hover` | base / base | sí | "The round badge floats in place, bobbing gently up and down and swaying a little from side to side, seen from the front. Smooth seamless loop." | Reposo y vuelo (balanceo). |
| `inflate` | base / `Inflated` | no | "The round badge squashes down a little as if taking a breath, then swells up bigger and rounder while its outline turns white, ending in the swollen pose, seen from the front." | Aviso de escupir (fase 1) y de dividirse (fase 3): 7 cuadros del mundo. |
| `descend` | base / `Deflated` | no | "The round badge drops straight down, stretching taller while falling, hits the ground and squashes flat, wobbles once and settles into the deflated pose, seen from the front." | Bajar y aterrizar (anticipación + aplastamiento). |
| `ascend` | `Deflated` / base | no | "The deflated badge crouches lower, then springs straight up stretching tall and thin, refills into a full round shape and settles floating, seen from the front." | Subir (estiramiento). |
| `window` | `Deflated` / `Deflated` | sí | "The deflated badge rests on the ground, slowly breathing in and out with a slight wobble, seen from the front. Smooth seamless loop." | Ventana abajo y copias (las mismas). |
| `lunge` | `Deflated` / `Lunge` | no | "The deflated badge squashes back toward the LEFT side of the picture, then launches toward the RIGHT side of the picture, stretching into a long oval as it moves." | Lanzamiento de las copias (la estela, por script). |

- Con `first_frame_pose_id` el primer cuadro no se genera, así que **no se cobra el +3** de `first_frame_quality` (no se usa).
- `last_frame_pose_id` en turbo es gratis.
- De los 25 cuadros de cada hoja se eligen los buenos con `--cells`, como se hizo con Isak. Los juegos de cuadros se reparten así: `hover` unos 12 a 12 fps, `inflate` 7, `descend` y `ascend` 5-6 (0,4-0,45 s), `window` 8-12 y `lunge` 4-6.
- Rehacer hojas de vídeos ya generados es **gratis** (`regenerate_spritesheet` / `regenerate_single_spritesheet`): sirve para otro `frameSize`, otro número de cuadros o `removeBg: "none"`.

---

## 3. Presupuesto

### 3.1 Saldo y costes comprobados

- **Saldo actual: 471 créditos** (`get_account`, 2026-10-21). La memoria del proyecto decía 465, tras la pose `dash` del 2026-10-20. `list_jobs` no muestra ningún trabajo posterior al del dash (`wf_9d16bea3…`, 2026-10-20 14:40), así que la diferencia de +6 no la explica un gasto. Puede ser una recarga o un redondeo de la memoria. **Conviene que el usuario lo confirme.**
- Costes tomados de las descripciones de las herramientas:

| Herramienta | Coste |
|---|---|
| `create_character` | turbo 1, pro 3, `pixelArt` 3 |
| `pad_character` | 1 (0 si es 100) |
| `generate_pose` | 3 |
| `generate_spritesheet` turbo | 5 por animación, +3 si `first_frame_quality: "pro"` sin pose |
| `generate_spritesheet` pro | 10 por animación |
| `generate_spritesheet` max | 35 por animación |
| `regenerate_spritesheet` / `regenerate_single_spritesheet` | 0 |
| `upload_character` | 0 |
| `create_asset` | 0 |

- `removeBg: "ultra"` **no tiene coste documentado**: no se usa sin preguntar.
- Precedente del proyecto, coherente con estos precios: dash de Isak, 5 créditos (turbo); pose de espaldas, 3.
- `list_jobs` solo registra las hojas, no las poses, así que el historial no da costes por trabajo.

### 3.2 Llamadas y total (plan completo)

| # | Llamada | Pieza | Créditos | Con un reintento |
|---|---|---|---|---|
| 1 | `create_character` (`pixelArt`) | Base «Alerta Mayor» | 3 | 6 |
| 2 | `pad_character` (70) | Margen | 1 | 2 |
| 3 | `generate_pose` | `Inflated` | 3 | 6 |
| 4 | `generate_pose` | `Deflated` | 3 | 6 |
| 5 | `generate_pose` | `Lunge` | 3 | 6 |
| 6 | `generate_spritesheet` turbo | `hover` | 5 | 10 |
| 7 | `generate_spritesheet` turbo | `inflate` | 5 | 10 |
| 8 | `generate_spritesheet` turbo | `descend` | 5 | 10 |
| 9 | `generate_spritesheet` turbo | `ascend` | 5 | 10 |
| 10 | `generate_spritesheet` turbo | `window` (también copias) | 5 | 10 |
| 11 | `generate_spritesheet` turbo | `lunge` | 5 | 10 |
| | | **Total** | **43** | **86** |

| Escenario | Gasto | Saldo después |
|---|---|---|
| Una pasada | 43 | 428 |
| Un reintento por pieza | 86 | 385 |
| Opcional: pose `Dazed` | +3 (+6 con reintento) | — |

### 3.3 Variante reducida (si se quiere gastar menos)

La variante quita `ascend`, que se sustituye por `descend` al revés más un estirado por código, y `window`, que pasa a ser la pose `Deflated` fija con un leve balanceo por código. El cálculo es 3 + 1 + 9 + 4 × 5 = **33 créditos** (66 con reintento). Se pierde el estiramiento propio al subir y la respiración de la ventana.

### 3.4 Reglas de gasto propuestas

- **Por orden y con parada:** primero el base (paso 1); el orquestador lo enseña al usuario antes de seguir. Después las poses y luego las animaciones.
- **Reintentos con criterio:** se reintenta una pieza solo si falla la ficha (§4) y se cambia la pose de partida antes que la redacción del prompt, como aconseja la herramienta.
- **Tope:** si una pieza falla dos veces, se para y se pregunta. El tope total es el aprobado.

---

## 4. Riesgos

| Riesgo | Qué puede pasar | Mitigación |
|---|---|---|
| **Consistencia entre poses** | El badge cambia de forma, de color o de icono entre animaciones; aparece una cara, brazos o texto. | Todas las animaciones parten de poses del mismo personaje (`first_frame_pose_id` / `last_frame_pose_id`), en turbo, que es el modo más consistente. Se revisa con una vista ×4 antes de importar. Si una pieza sale con otro aspecto, se reintenta esa pieza. |
| **Texto basura** | La IA escribe cifras o letras en la pastilla. | La pastilla se pide «blank». Si sale texto, se limpia por script rellenándola de `banner_blanco` antes de la reducción de paleta. |
| **Paleta** | El arte de IA trae cientos de colores, la regla del Mundo 1 es «solo `mundo1.gpl`» y la excepción de paleta libre es solo para Isak. Además, un rojo de la IA podría caer en `carmin`. | Paso nuevo de **reducción a `mundo1.gpl` sin `carmin` ni `carmin_brillo`** (vecino más cercano). Hace falta una herramienta pequeña o una opción `--palette` en `import_sheet.py`: es un cambio de código y se aprueba aparte. Después, `validate_sprites.py --check-palette assets/palettes/mundo1.gpl`. |
| **Tamaño relativo a la arena de 24 × 12 tiles** | El jefe ocupa 4 × 4 tiles arriba (columnas 9-14, filas 1-4) y 2 × 2 abajo. Un arte con otro encuadre cambia el tamaño aparente y la caja de daño (`phase3.body_damage_px` 96). | Un solo factor de escala para todas las hojas (`--scale`, como Isak) y lienzos fijos de 256 y 128. Se comprueba que el badge visible mida unos 232 px arriba y unos 112 abajo. Las cajas de colisión son de datos y no cambian. |
| **Fondo transparente** | Bordes con antialias, halos blancos de la quita de fondo o restos del fondo. | `removeBg: "default"`. Después, `import_sheet.py` quita el fondo, umbraliza el alfa (`--alpha-cut`) y valida esquinas sin alfa parcial. Si quedan halos, se rehace la hoja gratis con `regenerate_single_spritesheet`. `ultra` solo con permiso. |
| **Vuelo y aterrizaje en `import_sheet.py`** | El importador ancla los pies a la última fila, y el jefe flota: el balanceo y la caída se perderían con `--align feet`/`ground`. | Usar `--align sheet` (respeta el movimiento), `--shadow off` y `--baseline` con un margen inferior. Probar antes con `--dry-run --preview`. |
| **`validate_sprites.py` exige pies en la fila base** | El badge que flota no toca la última fila y el validador falla. | Añadir una opción del tipo `--no-baseline` o crear `tools/validate_boss_alert_major.py`, que ya nombra la propuesta (§4.1). Es un cambio de herramienta. |
| **Salir del cuadro** | `lunge` y `ascend` se salen del lienzo. | `pad_character` 70 antes de las poses y animaciones en modo «primer cuadro». |
| **El estiramiento no cabe en los tiempos** | `descend` dura 0,4 s y `ascend` 0,45 s; 25 cuadros a 12 fps son 2 s. | Se eligen 5-6 cuadros clave con `--cells` y los fps se ajustan al tiempo del código. El código no cambia sus tiempos. |
| **Copias** | Si la copia sale distinta del jefe real, rompe la regla de diseño. | Las copias usan **exactamente** los cuadros de `window` y `lunge`. |
| **`PixelBurst` con animación** | Hoy toma `_body.texture`. Con `AnimatedSprite2D` habrá que pasarle el cuadro actual. | Se resuelve en la integración (§5). |
| **Coste por encima de lo previsto** | Más reintentos de los presupuestados. | Tope aprobado y parada tras dos fallos por pieza (§3.4). |

---

## 5. Procedimiento de integración (tras aprobar y generar)

1. **Descargar** cada hoja (`sheetUrl` de `list_spritesheets`) en `hojas/alert_major/<anim>/spritesheet.png`. `hojas/` ya tiene `.gdignore`.
2. **Importar** cada hoja primero en simulación. Por ejemplo:
   ```bash
   python3 tools/import_sheet.py hojas/alert_major/hover/spritesheet.png --anim hover --cols 5 --rows 5 \
       --cells <celdas> --canvas 256 --scale <factor común> --align sheet --shadow off --baseline <fila> \
       --out assets/sprites/bosses --prefix alert_major --dry-run --preview <scratch>/hover.png
   ```
   - Los estados de abajo (`window`, `lunge`, y el final de `descend` y el inicio de `ascend` si se parten) se importan con `--canvas 128` y su propio factor común. Los nombres siguen el patrón `<entidad>_<anim>_<NN>.png` (`alert_major_hover_00.png`…).
   - Se revisa la vista ampliada antes de escribir en `assets/`.
3. **Reducir a la paleta** `mundo1.gpl` sin carmín (herramienta nueva, §4) y **validar**: `python3 tools/validate_sprites.py assets/sprites/bosses --size 256 --check-palette assets/palettes/mundo1.gpl` (y `--size 128` para los de abajo), con la opción que no exige pies en la base.
4. **SpriteFrames y código**, como paso de implementación aparte, con un subagente:
   - un `alert_major_frames.tres` generado por script (como `tools/build_enemy_frames.gd`), con fps y bucles por animación;
   - en `alert_major.gd`, `ART_REST`/`ART_INFLATE`/`ART_DOWN` pasan a animaciones de un `AnimatedSprite2D`, encadenadas con los tiempos actuales (`descend_s`, `ascend_s`, avisos);
   - `alert_major_clone.gd` usa `window` y `lunge` y conserva la estela por script;
   - `PixelBurst` recibe el cuadro actual;
   - en `data/bosses/alert_major.json`, `arena.draw_scale` pasa de 2,0 a 1,0.
5. **Retirar los `_placeholder` sustituidos** y sus `.import`: `rest`, `inflate`, `down`, `clone` y `lunge`.
   - Se quitan de `outputs()` en `tools/gen_boss_alert_major.py`, que conserva lo que sigue por script: shot, shield, bar, frame, panel, core card, eco icon y pop.
   - Esas piezas pueden perder el sufijo `_placeholder` si el usuario las da por finales. **Decisión del usuario**, porque cambia rutas en `data/hud.json`, `data/boss_reward.json`, `data/eco_text_box.json`, `data/world1_objects.json`, `tools/gen_album_cards.py` y `tests/`.
   - Se actualizan `tests/test_boss_data.py` y las referencias de `tests/test_help_inert.gd`.
6. **Verificar:**
   - `Godot --headless --path . --import`;
   - `tools/run_tests.sh` (incluye `--check` de los generadores, los validadores y el bot del jefe; el arte no cambia tiempos, así que los resultados del bot deben ser idénticos);
   - el humo `tools/smoke_boss_arena.gd -- --full`;
   - capturas con ventana de cada fase para la revisión del usuario;
   - `graphify update .`.
7. **Documentar:** añadir una sección «Arte final» a `docs/propuesta-jefe-alerta-mayor.md` (comandos de importación, celdas, fps y créditos gastados) y actualizar la memoria `autosprite-credits.md` con el saldo nuevo.

---

## 6. Qué se pide al usuario

1. **Aprobar el gasto:** plan completo, **43 créditos** (hasta **86** con un reintento por pieza), o variante reducida, 33 (hasta 66). Saldo actual: 471.
2. **Confirmar el concepto:** badge con pastilla en blanco y campana, como en el documento aprobado, o cuerpo de «móvil con pantalla de bloqueo» (§2.3).
3. **Confirmar `pixelArt: true`** para el base, o `pro` sin pixel art.
4. **Aprobar el cambio a ×1** (lienzos de 256 y 128) y los dos cambios de herramientas: reducción de paleta y validador sin pies en la base.
5. **Decidir si las piezas que siguen por script** pierden el sufijo `_placeholder`.
