# Guía: hojas de sprites de Isak con IA

Cómo generar las hojas de animación de Isak con una herramienta de IA de imágenes y convertirlas en cuadros del juego con `tools/import_sheet.py`.

- **Diseño de referencia:** la hoja `../Ejemplo/Idle.png` (fuera del repo, 6x6 cuadros de 170x309). Su Isak es el aprobado el 2026-10-14 (ver [07-estilo-visual.md](07-estilo-visual.md), §15.4).
- **Destino en el juego:** canvas de 128x128, Isak con unos 96 px de altura visible y los pies abajo-centro. Resolución base 1280x720.
- Los prompts van en **inglés**, porque las herramientas de imagen lo entienden mejor. La explicación de cada uno está en español.

> **Nota honesta:** el arte generado con IA **no es pixel art verdadero**. Imita el estilo, pero los "píxeles" no caen en una rejilla exacta, hay antialias y los colores no salen de una paleta fija. El importador lo reduce con vecino más cercano (nearest) a 96 px de alto y elimina las semitransparencias. A ese tamaño se ve como pixel art, pero con algo de ruido en los bordes y detalles que pueden bailar un píxel entre cuadros. Si un cuadro molesta en el juego, la solución es retocarlo a mano en Aseprite.

## 1. Cómo conseguir consistencia

1. **Mismo personaje de referencia.** Sube siempre `Idle.png` (o un cuadro recortado de ella) como imagen de referencia del personaje. Es lo que más ayuda a que la ropa, los colores y las proporciones no cambien.
2. **Mismo estilo y misma semilla.** Si la herramienta permite fijar la semilla (seed), el estilo o un "character reference", usa los mismos valores en todas las hojas. Guarda los ajustes que funcionaron.
3. **Una hoja por animación.** No pidas varias animaciones en la misma imagen.
4. **Vista lateral mirando a la DERECHA.** El juego voltea el sprite para la izquierda. Ojo: el ejemplo está en vista de tres cuartos mirando a la izquierda; para las hojas nuevas pide perfil lateral hacia la derecha.
5. **Fondo plano de un solo color, sin sombra proyectada.** Lo ideal es fondo transparente. Si no, magenta puro (#FF00FF): no aparece en Isak. Evita el verde, porque se confunde con el cian de la chaqueta al quitar el borde. El ejemplo trae una sombra elíptica gris bajo los pies: pide que NO la tenga. Si aun así aparece, el importador la quita.
6. **Rejilla regular.** N columnas × M filas, todas las celdas del mismo tamaño, con margen vacío alrededor del personaje en cada celda. Un personaje no debe invadir la celda vecina.
7. **Misma línea base.** Los pies sobre la misma línea en todos los cuadros (salvo los del aire en el salto), y el personaje del mismo tamaño en todos.
8. **Sin texto, números, marcos ni líneas de rejilla** dibujadas en la imagen.
9. **Celda de referencia de pie.** En las hojas donde ningún cuadro es Isak de pie y quieto (salto, daño, muerte), pide una celda extra al final con Isak de pie en reposo. El importador la usa para la escala (`--ref-frame`) y no la exporta. Así todas las animaciones quedan con el mismo tamaño.

## 2. Plantilla de prompt base

Reutilízala en todas las hojas. Sustituye lo que está entre `<...>`.

```text
Sprite sheet of the same character as the reference image, for a 2D side-scrolling platformer.
Character: a 17-year-old boy with slightly chibi proportions (large head), messy dark-brown spiky hair,
big dark eyes, NO glasses. He wears a loose dark-grey tactical jacket with a high collar and glowing
cyan accents on the collar and a cyan patch on the shoulder, a black shirt/vest with a small light-colored
logo on the chest, a brown backpack with a visible shoulder strap, dark-grey cargo pants with pockets,
and sturdy grey boots with small orange details. He always carries a smartphone.
Animation: <ANIMATION NAME>, <N> frames, <POSE DESCRIPTION>.
Layout: a grid of <COLS> columns by <ROWS> rows, all cells exactly the same size, one full-body pose per cell,
frames read left to right, top to bottom. Leave empty margin around the character in every cell.
<EXTRA CELL: The last cell shows the character standing still in a neutral idle pose, as a size reference.>
View: strict side view (profile), character facing RIGHT.
Same character size and same ground line (feet baseline) in every frame.
Style: pixel-art look, clean dark outline, flat shading, same colors as the reference.
Background: flat solid magenta (#FF00FF) or transparent. NO ground shadow, no cast shadow, no floor,
no text, no numbers, no frame borders, no grid lines.
```

**Por qué:** la descripción del personaje fija el diseño aprobado (y recuerda que no lleva lentes); la parte de *Layout* hace que el importador pueda cortar la rejilla; *View* y *baseline* evitan que la animación tiemble; *Background* evita la sombra y facilita quitar el fondo.

Si la herramienta tiene campo de "negative prompt", añade: `glasses, olive jacket, ground shadow, drop shadow, text, watermark, frame, border, grid lines, perspective floor, extra characters`.

## 3. Animaciones

Tamaños de hoja pensados para relaciones de aspecto que casi todas las herramientas ofrecen (1:1 y 3:2). Celdas grandes (unos 384x512 o más) dan mejores resultados al reducir a 96 px. Si la herramienta entrega otro tamaño, no pasa nada mientras la rejilla sea regular.

| Animación | Archivo de la hoja | Cuadros | Rejilla recomendada | Tamaño recomendado |
|---|---|---|---|---|
| Idle | `isak_idle.png` | el ejemplo trae 36 (6x6); 8 a 12 bastan | 6x6 (o 4x3) | la del ejemplo (1020x1854) o 1536x1536 |
| Terminal (idle largo) | `isak_terminal.png` | 8 a 12 | 4x3 | 1536x1536 |
| Caminar | `isak_walk.png` | 8 | 4x2 | 1536x1024 |
| Correr | `isak_run.png` | 8 | 4x2 | 1536x1024 |
| Salto | `isak_jump.png` | 5 + 1 de referencia | 3x2 | 1536x1024 |
| Pulso de datos | `isak_pulse.png` | 6 (el primero, de pie, sirve de referencia) | 3x2 | 1536x1024 |
| Daño | `isak_hurt.png` | 2 + 1 de referencia | 3x1 | 1536x768 |
| Muerte | `isak_dead.png` | 3 a 4 + 1 de referencia | 3x2 (sobran celdas vacías) | 1536x1024 |

Los cuadros resultantes se llaman `isak_<anim>_<NN>.png` (por ejemplo `isak_walk_00.png`).

### Idle
El ejemplo `Idle.png` ya sirve: Isak de pie, respiración ligera, mira el celular y lo baja. Si se regenera:

```text
Animation: idle, 12 frames, standing still with subtle breathing; he slowly raises his smartphone
in one hand, glances at the screen, and lowers it again. Feet do not move.
```
*Explicación:* reposo corto y en bucle. Los pies no se mueven, solo respiración, brazo y cabeza.

### Terminal (idle largo)
Según [02-isak-habilidades.md](02-isak-habilidades.md) §3.1 y [07-estilo-visual.md](07-estilo-visual.md) §15.4: tras unos segundos quieto, Isak **saca una pequeña terminal holográfica de su muñeca para revisar datos**, en un bucle de 8 a 12 cuadros. El documento añade "o ajustar su visor", pero el nuevo diseño no tiene lentes ni visor, así que esa parte queda fuera hasta que se decida.

```text
Animation: holographic terminal idle, 12 frames. Standing still, he raises his left wrist; a small
glowing cyan holographic screen with simple data lines appears above the wrist, he looks at it and taps it
with the other hand, then the hologram fades and he lowers the arm. The hologram is solid bright cyan,
not translucent. Feet do not move.
```
*Explicación:* el holograma va dibujado en la hoja porque forma parte de la pose. Pide que sea cian **sólido**: el importador convierte las semitransparencias en opaco o transparente, y un holograma translúcido quedaría con agujeros.

### Caminar (8)
```text
Animation: walk cycle, 8 frames, relaxed and slightly heavy walk (he is not an athlete),
contact - down - passing - up for each leg, arms swinging naturally, the backpack bouncing slightly.
```
*Explicación:* ciclo completo de dos pasos. El documento pide un movimiento algo pesado y el rebote de la mochila.

### Correr (8)
```text
Animation: run cycle, 8 frames, leaning forward, longer strides, one frame per contact and push-off,
arms pumping, the backpack bouncing noticeably.
```
*Explicación:* ciclo completo de carrera, con la mochila rebotando más que al caminar.

### Salto (5 cuadros individuales + referencia)
```text
Animation: jump, 5 separate key poses in this order: 1) anticipation, knees bent, crouching;
2) rising, body stretched, legs tucked slightly; 3) apex, compact floating pose; 4) falling, legs
reaching down, arms up; 5) landing squash, deep crouch on the ground.
EXTRA CELL: the last cell shows him standing still in a neutral pose, as a size reference.
```
*Explicación:* son poses sueltas, no un ciclo. El juego elige cuál mostrar según la velocidad vertical. La celda 6 es la referencia de tamaño.

### Pulso de datos (6)
```text
Animation: data pulse, 6 frames: he quickly raises his smartphone and points it forward,
a short recoil, then lowers it. Do NOT draw any wave, beam, light or effect; only the character.
```
*Explicación:* Isak levanta el celular y "emite" la onda de datos, pero **la onda la pone el juego**, no la dibujes. Una onda dibujada estorbaría al cortar y al alinear.

### Daño (2 + referencia)
```text
Animation: hurt, 2 frames: a quick flinch, torso pushed back and head turned away from the hit,
then recovering. Normal colors, no effects.
EXTRA CELL: the last cell shows him standing still in a neutral pose, as a size reference.
```
*Explicación:* el documento pide un glitch de píxeles. **El glitch lo aplica el juego con un shader**, así que aquí solo hace falta la pose normal del golpe.

### Muerte (3 a 4 + referencia)
```text
Animation: defeat, 4 frames: he stops, his knees give way and his arms drop, ending in a slumped
pose, still on his feet or kneeling. Normal colors, no effects, no particles.
EXTRA CELL: the last cell shows him standing still in a neutral pose, as a size reference.
```
*Explicación:* solo la pose; **el pixelado y las líneas de código que suben los aplica el juego**. Ojo: el documento dice que "Isak no cae al suelo", se pixela y se desintegra. Por eso el prompt pide una pose de derrota que no termine tumbado. Si quieres otra pose, decídelo antes de generarla.

## 4. Importar la hoja

Primero en simulación, con vista previa:

```bash
python3 tools/import_sheet.py hojas/isak_walk.png --anim walk --cols 4 --rows 2 \
    --dry-run --preview /tmp/isak_walk_preview.png
```

Si la vista previa se ve bien, se repite sin `--dry-run` (escribe en `assets/sprites/isak/`).

| Opción | Uso |
|---|---|
| `--cols N --rows M` | Rejilla. Si se omite, la detecta por las bandas vacías entre personajes. |
| `--frames N` | Cuadros usados en orden de lectura (por ejemplo 5 en el salto). |
| `--ref-frame I` | Celda de Isak de pie que fija la escala y el anclaje. Puede ser la celda extra final, que no se exporta (en el salto de 3x2: `--frames 5 --ref-frame 5`). |
| `--align sheet` / `feet` | `sheet` (por defecto) mueve todos los cuadros igual y respeta los saltos y el balanceo. `feet` ancla cada cuadro por sus pies: útil si la IA dejó los personajes descolocados, pero **no** sirve para el salto. |
| `--height-tol` | Tolerancia de altura visible (0.2 por defecto). Súbela a 0.4 en salto y muerte, donde hay poses agachadas. |
| `--shadow off` | Si la hoja no tiene sombra y el importador confunde algo con ella. |

El importador corta la rejilla, quita el fondo y la sombra del suelo, umbraliza el alfa, escala con nearest con **un solo factor para toda la hoja** (Isak de la celda de referencia a 96 px), coloca los pies en la última fila de un canvas de 128x128 y valida cada cuadro (tamaño, fondo transparente, sin semitransparencias, altura, nada recortado). Termina con código distinto de 0 si algo falla, e imprime la deriva de los pies entre cuadros.

## 5. Lista de comprobación antes de entregar la hoja

- [ ] Es el mismo Isak: pelo castaño desordenado, **sin lentes**, chaqueta gris oscura con cian en cuello y hombro, logo claro, mochila marrón, botas grises con naranja, celular.
- [ ] Vista lateral, mirando a la derecha, en todos los cuadros.
- [ ] Rejilla regular: celdas iguales, un personaje por celda, nadie toca el borde de su celda.
- [ ] El número de cuadros es el pedido y están en orden de lectura.
- [ ] Mismo tamaño de personaje y pies sobre la misma línea (salvo en el aire).
- [ ] Fondo transparente o de un solo color plano (magenta). Sin sombra, suelo, texto, números ni marcos.
- [ ] Sin efectos dibujados (onda del pulso, glitch, partículas).
- [ ] Si la animación no tiene una pose de pie: hay celda extra de referencia al final.
- [ ] PNG sin compresión con pérdida (no JPG).
- [ ] Nombre del archivo: `isak_<anim>.png`.

## 6. Si la IA entrega cuadros inconsistentes

| Problema | Qué hacer |
|---|---|
| Cambia la ropa o la cara, aparecen lentes, otro color de chaqueta | **Reintentar** con la imagen de referencia y la misma semilla; refuerza en el prompt "NO glasses", "same character as the reference". No se arregla con el importador. |
| Vista de tres cuartos o mirando a la izquierda en algunos cuadros | **Reintentar**. Voltear cuadros sueltos rompe la animación. |
| Rejilla irregular, personajes que invaden la celda vecina | **Reintentar** pidiendo más margen, o recolocar los cuadros en una rejilla regular con un editor antes de importar. |
| Personaje un poco más grande o más pequeño en algún cuadro | Lo **corrige el importador** solo en parte: escala toda la hoja con el mismo factor, así que un cuadro más grande sigue siéndolo. Si se nota, reintentar ese cuadro o retocarlo en Aseprite. |
| Pies a distinta altura o personaje desplazado en la celda | Con `--align feet` lo **corrige el importador** (no en el salto). |
| Sombra en el suelo, fondo de color, bordes antialias | Lo **corrige el importador**. |
| Detalle que parpadea entre cuadros (logo, cian, dedos, celular) | Lo **retoca el usuario en Aseprite** sobre los PNG de 128x128 ya importados. |
| Holograma, onda u otro efecto translúcido con agujeros | Pedirlo **sólido** o dejar el efecto al juego. |
| Faltan cuadros o hay cuadros repetidos | **Reintentar**, o usar `--frames` para importar solo los buenos si el ciclo sigue funcionando. |

Después de importar, revisa la vista previa ampliada (guía cian = centro, magenta = línea base) y prueba la animación en el juego antes de darla por buena.
