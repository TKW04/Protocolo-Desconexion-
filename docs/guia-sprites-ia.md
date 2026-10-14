# Guía: hojas de sprites de Isak con IA

Cómo generar las hojas de animación de Isak con una herramienta de IA de imágenes y convertirlas en cuadros del juego con `tools/import_sheet.py`.

- **Diseño de referencia:** la hoja `../Ejemplo/Idle.png` (fuera del repo, 6x6 cuadros de 170x309). Su Isak es el aprobado el 2026-10-14 (ver [07-estilo-visual.md](07-estilo-visual.md), §15.4).
- **Destino en el juego:** canvas de 128x128, Isak con unos 96 px de altura visible y los pies abajo-centro. Resolución base 1280x720.
- Los prompts van en **inglés**, porque las herramientas de imagen lo entienden mejor. Las explicaciones van en español.
- Cada prompt de la §3 está **completo**: se copia el bloque entero y se pega tal cual. Ya incluye la ficha fija de la §1.

> **Nota honesta:** el arte generado con IA **no es pixel art verdadero**. Imita el estilo, pero los "píxeles" no caen en una rejilla exacta, hay antialias y los colores no salen de una paleta fija. El importador lo reduce con vecino más cercano (nearest) a 96 px de alto y elimina las semitransparencias. A ese tamaño se ve como pixel art, pero con algo de ruido en los bordes y detalles que pueden bailar un píxel entre cuadros. Si un cuadro molesta en el juego, la solución es retocarlo a mano en Aseprite.

## 1. Ficha fija de Isak

Este bloque va **al inicio de todos los prompts, siempre idéntico**. No lo resumas ni lo cambies entre hojas: cualquier variación en la descripción produce variaciones en el personaje. Los prompts de la §3 ya lo llevan copiado; si escribes un prompt nuevo, pégalo primero.

Describe lo que se ve en `Idle.png` y en §15.4. La paleta va en palabras; los hex exactos no están decididos. El único hex es el del fondo (#FF00FF), que no es un color del personaje.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===
```

Si la herramienta tiene campo de **negative prompt**, pega siempre este:

```text
glasses, visor, goggles, olive jacket, green jacket, LED on backpack, rim light, glowing outline,
three-quarter view, facing left, front view, ground shadow, drop shadow, cast shadow, floor, scenery,
text, letters, numbers, watermark, signature, frame, border, grid lines, extra characters,
gradient, blur, motion lines, speed lines, particles, sparkles
```

Notas sobre la ficha:

- **Magenta #FF00FF** porque no aparece en Isak. No uses verde de fondo: se confunde con el cian de la chaqueta al quitar el borde. Si la herramienta da fondo transparente real, también sirve.
- **Sin lentes, sin LED en la mochila, sin luz de contorno:** la luz de contorno y el LED del diseño original siguen sin decidir (§15.4), así que no se dibujan.
- **Celular en la mano derecha:** es la que lo sostiene en `Idle.png`. En perfil hacia la derecha esa mano queda en el lado lejano, pero el celular se ve cuando está delante del cuerpo.

## 2. Orden de generación y consistencia

### 2.1 Orden

1. **Imagen de referencia de pie** (§2.2). Es la base de todo lo demás.
2. **Hoja de giro** (§2.3), opcional, si la herramienta acepta varias vistas.
3. **Idle** (§3.1), que sirve para comprobar que la ficha da el Isak correcto en movimiento suave.
4. **Terminal** (§3.2), **caminar** (§3.3), **correr** (§3.4).
5. **Salto** (§3.5), **pulso** (§3.6), **daño** (§3.7), **muerte** (§3.8).

Importa y prueba cada hoja (§5) antes de pasar a la siguiente. Así un fallo de estilo se detecta pronto.

### 2.2 Imagen de referencia de pie (ref-frame)

Isak quieto, de perfil hacia la derecha. Se usa como **imagen de referencia** que se sube a la herramienta en todas las hojas, y su pose es la misma que se pide en la celda extra de salto, daño y muerte. Así todas las animaciones comparten escala y línea base.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

IMAGE: a single full-body character, square image (1:1), centered horizontally.
The character is about 75% of the image height, feet near the bottom with an empty margin below them
and above the hair.
POSE: neutral standing reference pose. Standing upright and still, feet flat on the ground about
hip-width apart (in profile the near leg slightly in front of the far leg), knees straight but relaxed,
torso vertical, head level looking forward to the right. Both arms hang relaxed at his sides;
the right (far) hand holds the phone low next to the thigh, screen facing his leg.
Calm expression, mouth closed.
DO NOT: no motion, no action pose, no second view, no turnaround, no shadow, no effects.
```

Guárdala como `isak_ref.png`. No se importa al juego. Revisa que sea exactamente el Isak de la ficha antes de seguir: todo lo demás se copia de ella.

### 2.3 Hoja de giro (opcional)

Solo si la herramienta acepta varias vistas en una imagen y mantiene bien el personaje. Ayuda a que la herramienta entienda la mochila y la chaqueta desde todos los lados. Tampoco se importa.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

EXCEPTION TO THE VIEW RULE FOR THIS IMAGE ONLY: this is a character turnaround.
LAYOUT: 4 columns x 1 row, wide image (2:1), four equal cells with empty space between them,
same character size and same feet line in all four.
CELLS, left to right: 1) side profile facing right; 2) front view; 3) side profile facing left;
4) back view showing the whole backpack.
POSE: the same neutral standing pose in all four: upright, feet flat, arms relaxed at the sides,
phone held low in the right hand.
DO NOT: no action poses, no labels, no text under the views, no shadow, no effects.
```

### 2.4 Cómo mantener la consistencia entre sesiones

1. **Misma imagen de referencia.** Sube `isak_ref.png` (y, si la herramienta acepta varias, también `Idle.png` y la hoja de giro) en cada hoja, como "character reference" o "image reference". Es lo que más ayuda.
2. **Misma ficha, palabra por palabra.** Copia siempre el bloque de la §1 sin tocarlo.
3. **Misma semilla y mismos ajustes.** Si la herramienta permite fijar la semilla (seed), el modelo, el estilo o la fuerza de la referencia, usa los mismos valores en todas las hojas. Anótalos en un archivo junto a las hojas (por ejemplo `hojas/ajustes.txt`) para la siguiente sesión.
4. **Una hoja por animación.** No pidas varias animaciones en la misma imagen.
5. **Guarda las hojas buenas** aunque aún no las importes: sirven como referencia extra para las siguientes.

## 3. Prompts por estado

Todas las hojas usan celdas iguales, orden de lectura de izquierda a derecha y de arriba abajo, un Isak por celda con margen vacío, y los pies sobre la misma línea (salvo los cuadros en el aire). Los tamaños son relaciones de aspecto que casi todas las herramientas ofrecen (1:1, 3:2, 2:1). Si la herramienta entrega otro tamaño, no pasa nada mientras la rejilla sea regular.

Las hojas van en una carpeta `hojas/` (o la que prefieras; ajusta la ruta del comando). Los cuadros resultantes se llaman `isak_<anim>_<NN>.png` (por ejemplo `isak_walk_00.png`) y se guardan en `assets/sprites/isak/`.

| Estado | Archivo de la hoja | Cuadros | Rejilla (cols x rows) | Tamaño de la hoja (celda) | Celda de referencia |
|---|---|---|---|---|---|
| Idle | `isak_idle.png` | 12 | 4x3 | 1536x1536 (384x512) | cuadro 1 (índice 0) |
| Terminal (idle largo) | `isak_terminal.png` | 12 | 4x3 | 1536x1536 (384x512) | cuadro 1 (índice 0) |
| Caminar | `isak_walk.png` | 8 | 4x2 | 1536x1024 (384x512) | cuadro 3, paso (índice 2) |
| Correr | `isak_run.png` | 8 | 4x2 | 1536x1024 (384x512) | cuadro 3 (índice 2) |
| Salto | `isak_jump.png` | 5 + 1 de referencia | 3x2 | 1536x1024 (512x512) | celda 6 (índice 5), no se exporta |
| Pulso de datos | `isak_pulse.png` | 6 | 3x2 | 1536x1024 (512x512) | cuadro 1 (índice 0) |
| Daño | `isak_hurt.png` | 2 + 1 de referencia | 3x1 | 1536x768 (512x768) | celda 3 (índice 2), no se exporta |
| Muerte | `isak_dead.png` | 4 + 1 de referencia (+1 vacía) | 3x2 | 1536x1024 (512x512) | celda 5 (índice 4), no se exporta |

`--ref-frame` cuenta desde 0. El idle de ejemplo `Idle.png` (6x6, 36 cuadros) también se puede importar tal cual; ver §3.1.

En caminar y correr, la celda de referencia es un cuadro del ciclo (el de paso, el más erguido). Si al importar la altura de algún cuadro se sale de la tolerancia, prueba otra celda o sube `--height-tol`.

### 3.1 Idle (12 cuadros, 4x3, bucle)

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: idle, 12 frames, seamless loop.
SHEET LAYOUT: square image (1:1), a grid of 4 columns x 3 rows, 12 equal cells with empty space between
the characters. One full-body pose per cell. Frames read left to right, top to bottom.
In every cell: same character size (about 75% of the cell height), horizontally centered, and the soles
of the feet on exactly the same ground line near the bottom of the cell. The feet NEVER move in this
animation.
FRAMES:
1) Neutral standing pose: upright, feet flat, arms relaxed at the sides, phone held low in the right hand
   next to the thigh. Looking forward.
2) Same pose, breathing in: chest and shoulders rise very slightly.
3) The right forearm starts to bend, lifting the phone to hip height. Head still forward.
4) Phone at stomach height in front of the body, head starts to tilt down toward it.
5) Phone in front of the chest, screen facing his face; head tilted down, eyes on the screen.
6) Same as 5, breathing out: shoulders drop very slightly.
7) Same as 5, his thumb taps the screen.
8) Same as 5, breathing in again, still reading the screen.
9) Head starts to lift back up; the phone begins to lower.
10) Phone at hip height, head looking forward again.
11) Arm almost straight at the side, phone next to the thigh, breathing out.
12) Almost identical to frame 1, chest a tiny bit lower, so frame 12 flows directly back into frame 1.
The left (near) arm stays relaxed at his side in all frames.
DO NOT: no walking, no foot movement, no change of facing direction, no hologram, no light from the
phone screen, no effects, no shadow under the feet.
```

- **Archivo:** `hojas/isak_idle.png` (4 columnas x 3 filas, 12 cuadros).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_idle.png --anim idle --cols 4 --rows 3 --frames 12 \
      --dry-run --preview /tmp/isak_idle_preview.png
  python3 tools/import_sheet.py hojas/isak_idle.png --anim idle --cols 4 --rows 3 --frames 12
  ```
- **Usar el ejemplo tal cual** (3/4 mirando a la izquierda, con sombra; la quita el importador):
  ```bash
  python3 tools/import_sheet.py ../Ejemplo/Idle.png --anim idle --cols 6 --rows 6 --frames 36 --dry-run
  ```
- **Revisar:** los pies no se mueven entre cuadros; el celular siempre en la mano derecha; el cuadro 12 empalma con el 1 sin salto.

### 3.2 Terminal holográfica (idle largo, 12 cuadros, 4x3, bucle)

Según [02-isak-habilidades.md](02-isak-habilidades.md) §3.1 y [07-estilo-visual.md](07-estilo-visual.md) §15.4: tras unos segundos quieto, Isak **saca una pequeña terminal holográfica de su muñeca para revisar datos**, en un bucle de 8 a 12 cuadros. El documento añade "o ajustar su visor", pero el diseño aprobado no tiene lentes ni visor, así que esa parte queda fuera. La referencia no muestra ningún aparato en la muñeca, así que el prompt no lo añade: el holograma aparece sobre la muñeca izquierda (la cercana a la cámara).

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: holographic wrist terminal idle, 12 frames, seamless loop. He checks data on a small
holographic screen that appears above his left wrist.
SHEET LAYOUT: square image (1:1), a grid of 4 columns x 3 rows, 12 equal cells with empty space between
the characters. One full-body pose per cell. Frames read left to right, top to bottom.
In every cell: same character size (about 75% of the cell height), horizontally centered, and the soles
of the feet on exactly the same ground line near the bottom of the cell. The feet NEVER move.
HOLOGRAM RULES: the hologram is part of the drawing. It is a small flat rectangle, about the size of his
head, floating just above his left wrist in front of his chest. It is SOLID, OPAQUE bright cyan with a few
simple dark lines of data inside (short horizontal bars, no readable text). Not transparent, not
blurred, no glow halo around it. Do not draw any wristwatch or new gadget on the wrist.
FRAMES:
1) Neutral standing pose: upright, feet flat, arms relaxed at the sides, phone held low in the right hand.
2) He raises his left (near) forearm horizontally in front of his chest, wrist turned up; head starts
   to tilt down toward the wrist.
3) A thin short horizontal line of solid cyan appears just above the left wrist.
4) The line opens into the small cyan screen, half height.
5) The cyan screen is fully open; he looks at it, head tilted down.
6) His right hand, still holding the phone, comes up and taps the screen with the index finger.
7) The data lines inside the screen change pattern; right hand moves slightly back; he keeps reading.
8) He taps the screen again with the right index finger.
9) Right hand lowers to hip height; he reads the screen, tiny nod.
10) The screen shrinks back to a thin cyan line above the wrist.
11) The hologram is gone; the left forearm starts lowering.
12) Almost back to frame 1: both arms nearly at the sides, head looking forward, so frame 12 flows
    directly back into frame 1.
DO NOT: no translucent or see-through hologram, no light rays, no particles, no glow on the body,
no visor or glasses, no wrist device, no foot movement, no change of facing direction, no shadow.
```

- **Archivo:** `hojas/isak_terminal.png` (4 columnas x 3 filas, 12 cuadros).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_terminal.png --anim terminal --cols 4 --rows 3 --frames 12 \
      --dry-run --preview /tmp/isak_terminal_preview.png
  python3 tools/import_sheet.py hojas/isak_terminal.png --anim terminal --cols 4 --rows 3 --frames 12
  ```
- **Revisar:** el holograma es cian **sólido** (el importador convierte las semitransparencias en opaco o transparente; uno translúcido queda con agujeros); no hay aparato nuevo en la muñeca ni visor; los pies no se mueven.

### 3.3 Caminar (8 cuadros, 4x2, bucle)

Ciclo de dos pasos: contacto, bajada, paso y subida con una pierna, y lo mismo con la otra. El documento pide un movimiento algo pesado y el rebote de la mochila. "Pierna cercana" es la izquierda (la que ve la cámara), "lejana" la derecha.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: walk cycle, 8 frames, seamless loop, walking in place toward the right (no forward travel
inside the sheet). A relaxed, slightly heavy walk: he is not an athlete. Torso leans forward only very
slightly. The backpack bounces a little, following the body one frame late.
SHEET LAYOUT: wide image (3:2), a grid of 4 columns x 2 rows, 8 equal cells with empty space between the
characters. One full-body pose per cell. Frames read left to right, top to bottom.
In every cell: same character size (about 75% of the cell height), horizontally centered, and the
supporting foot on exactly the same ground line near the bottom of the cell.
"Near" = his left side, closest to the viewer. "Far" = his right side.
FRAMES:
1) CONTACT: near (left) leg forward, straight, heel touching the ground; far (right) leg behind, on its
   toes. Widest stride. Arms swing opposite to the legs: far arm (holding the phone) forward,
   near arm back.
2) DOWN: weight lands on the near leg, near knee bends, body at its LOWEST point; far foot lifts off
   behind. Arms start to come back toward the body.
3) PASSING: near leg straight under the body, far leg passes beside it with the knee bent and the foot
   lifted. Arms hang close to the sides, phone next to the thigh. Body at normal height.
4) UP: near leg pushes off on its toes, body at its HIGHEST point; far leg swings forward.
   Near arm starts to go forward, far arm back.
5) CONTACT (mirror of 1): far (right) leg forward, heel touching the ground; near leg behind on its
   toes. Near arm forward, far arm (with the phone) back.
6) DOWN (mirror of 2): weight on the far leg, knee bent, body at its LOWEST point; near foot lifts.
7) PASSING (mirror of 3): far leg straight under the body, near leg passes with bent knee.
   Arms close to the sides.
8) UP (mirror of 4): far leg pushes off on its toes, body at its HIGHEST point; near leg swings forward,
   leading straight back into frame 1.
The phone stays in the right hand in every frame, held loosely with the screen toward the leg, swinging
with the arm. It is never dropped or switched to the other hand.
DO NOT: no running pose, no motion lines, no dust, no change of facing direction, no shadow, no effects.
```

- **Archivo:** `hojas/isak_walk.png` (4 columnas x 2 filas, 8 cuadros).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_walk.png --anim walk --cols 4 --rows 2 --frames 8 --ref-frame 2 \
      --dry-run --preview /tmp/isak_walk_preview.png
  python3 tools/import_sheet.py hojas/isak_walk.png --anim walk --cols 4 --rows 2 --frames 8 --ref-frame 2
  ```
  Si los pies quedan a distinta altura entre cuadros, añade `--align feet`.
- **Revisar:** las piernas alternan de verdad (los cuadros 5 a 8 son el espejo de 1 a 4, no una copia); el cuerpo baja en 2 y 6 y sube en 4 y 8; el celular no cambia de mano; el cuadro 8 lleva al 1.

### 3.4 Correr (8 cuadros, 4x2, bucle)

Mismo esquema de dos pasos, con zancadas más largas, inclinación hacia delante, brazos doblados y la mochila rebotando más que al caminar.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: run cycle, 8 frames, seamless loop, running in place toward the right (no forward travel
inside the sheet). Torso leans forward about 15 degrees in every frame, head up looking ahead.
Both elbows bent at about 90 degrees, arms pumping opposite to the legs. Long strides.
The backpack bounces noticeably, following the body one frame late.
SHEET LAYOUT: wide image (3:2), a grid of 4 columns x 2 rows, 8 equal cells with empty space between the
characters. One full-body pose per cell. Frames read left to right, top to bottom.
In every cell: same character size, horizontally centered, the supporting foot on the same ground line
near the bottom of the cell. In the two flight frames (4 and 8) both feet are only slightly above that
line.
"Near" = his left side, closest to the viewer. "Far" = his right side.
FRAMES:
1) CONTACT: near (left) foot lands on the ground slightly in front of the hips, leg almost straight;
   far leg behind, knee bent, foot high. Far arm (with the phone) forward, near arm back.
2) DOWN: near knee bends to absorb the landing, body at its LOWEST point; far knee swings forward.
   Arms passing the body.
3) PUSH-OFF: near leg extends behind, pushing off the ground with the toes; far knee driven high and
   forward. Near arm forward, far arm (with the phone) back.
4) FLIGHT: both feet off the ground, body at its HIGHEST point; far leg reaching forward, near leg
   trailing behind with the knee bent.
5) CONTACT (mirror of 1): far (right) foot lands in front, near leg behind with the knee bent.
   Near arm forward, far arm back.
6) DOWN (mirror of 2): far knee bends, body LOWEST; near knee swings forward.
7) PUSH-OFF (mirror of 3): far leg pushes off behind, near knee driven high and forward.
   Far arm (with the phone) forward, near arm back.
8) FLIGHT (mirror of 4): both feet off the ground, near leg reaching forward, far leg trailing,
   leading straight back into frame 1.
The phone stays gripped firmly in the right hand in every frame, moving with the pumping arm.
It is never dropped or switched to the other hand.
DO NOT: no motion lines, no speed lines, no dust clouds, no afterimages, no change of facing direction,
no shadow, no effects.
```

- **Archivo:** `hojas/isak_run.png` (4 columnas x 2 filas, 8 cuadros).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_run.png --anim run --cols 4 --rows 2 --frames 8 --ref-frame 2 \
      --dry-run --preview /tmp/isak_run_preview.png
  python3 tools/import_sheet.py hojas/isak_run.png --anim run --cols 4 --rows 2 --frames 8 --ref-frame 2
  ```
  La inclinación hace que Isak se vea algo más bajo que de pie; si falla la validación de altura, añade `--height-tol 0.3`.
- **Revisar:** inclinación igual en todos los cuadros; los cuadros 4 y 8 apenas despegan; sin líneas de velocidad; mochila rebotando; el cuadro 8 lleva al 1.

### 3.5 Salto (5 poses + 1 de referencia, 3x2)

Son poses sueltas, no un ciclo: el juego elige cuál mostrar según la velocidad vertical. La celda 6 es la referencia de tamaño y no se exporta. El juego ya mueve a Isak en el aire, así que las poses aéreas se dibujan solo un poco por encima de la línea del suelo (si se dibujan muy arriba, el cuadro se recorta en el canvas de 128x128).

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: jump, 5 separate key poses (not a loop) plus 1 standing reference pose.
SHEET LAYOUT: wide image (3:2), a grid of 3 columns x 2 rows, 6 equal cells with empty space between the
characters. One full-body pose per cell. Cells read left to right, top to bottom.
Same character scale in every cell (the standing pose in cell 6 is about 70% of the cell height).
Cells 1, 5 and 6 have the feet on the same ground line near the bottom of the cell. In cells 2, 3 and 4
he is in the air, drawn only slightly higher than that line, fully inside the cell.
CELLS:
1) ANTICIPATION: on the ground, knees deeply bent, crouching, torso leaning forward, arms swung back
   behind the hips, phone in the right hand.
2) RISING: in the air, body stretched upward, legs extended down with the toes pointing down,
   arms swung up and forward, head up.
3) APEX: in the air, compact floating pose, knees tucked up slightly, arms bent at chest height,
   body upright.
4) FALLING: in the air, legs extended down reaching for the ground, knees slightly bent, arms raised
   up and out for balance, jacket and hair lifted slightly by the fall.
5) LANDING: on the ground, squash pose, deep crouch, knees bent, torso low and leaning forward,
   arms forward and down for balance.
6) SIZE REFERENCE: the neutral standing pose from the reference image: upright, feet flat on the ground,
   arms relaxed at the sides, phone held low in the right hand. Same scale as the other cells.
The phone stays in the right hand in all six cells.
DO NOT: no ground, no platform, no dust, no landing impact effect, no motion lines, no change of facing
direction, no shadow, no effects.
```

- **Archivo:** `hojas/isak_jump.png` (3 columnas x 2 filas, 5 cuadros + referencia en la celda 6).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_jump.png --anim jump --cols 3 --rows 2 --frames 5 --ref-frame 5 \
      --height-tol 0.4 --dry-run --preview /tmp/isak_jump_preview.png
  python3 tools/import_sheet.py hojas/isak_jump.png --anim jump --cols 3 --rows 2 --frames 5 --ref-frame 5 \
      --height-tol 0.4
  ```
  No uses `--align feet` en el salto: pondría las poses aéreas en el suelo.
- **Revisar:** la celda 6 es la misma pose que `isak_ref.png` y a la misma escala que las demás; las poses aéreas no tocan el borde de su celda; 1 y 5 son claramente agachadas.

### 3.6 Pulso de datos (6 cuadros, 3x2)

Isak levanta el celular y "emite" el pulso. **La onda la pone el juego**, no se dibuja: una onda dibujada estorbaría al cortar y al alinear. El cuadro 1 es Isak de pie y sirve de referencia.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: data pulse, 6 frames, a quick action: he raises his smartphone, points it forward like a
remote, a short recoil, then lowers it.
SHEET LAYOUT: wide image (3:2), a grid of 3 columns x 2 rows, 6 equal cells with empty space between the
characters. One full-body pose per cell. Frames read left to right, top to bottom.
In every cell: same character size (the standing pose is about 70% of the cell height), the body
horizontally centered with room in front for the extended arm, and the feet on exactly the same ground
line near the bottom of the cell. The feet stay planted in all frames.
FRAMES:
1) Neutral standing pose: upright, feet flat, arms relaxed at the sides, phone held low in the right hand.
2) ANTICIPATION: knees bend slightly, torso turns a little back; the right hand brings the phone up
   to the chest, screen facing forward.
3) POINT: the right arm extends straight forward at shoulder height, the phone at the end of the arm with
   the screen facing right; torso leans slightly forward; the left (near) arm pulled back for balance.
4) RECOIL: the right arm and the phone kick back and slightly up, elbow bent a little; torso pushed
   back slightly.
5) The right arm lowers halfway, phone at stomach height; body upright again.
6) Almost back to frame 1: arm near the side, phone low next to the thigh.
DO NOT: do NOT draw any wave, ring, beam, light, flash, glow, spark or effect coming from the phone;
the phone screen is plain. No motion lines, no change of facing direction, no shadow.
```

- **Archivo:** `hojas/isak_pulse.png` (3 columnas x 2 filas, 6 cuadros).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_pulse.png --anim pulse --cols 3 --rows 2 --frames 6 \
      --dry-run --preview /tmp/isak_pulse_preview.png
  python3 tools/import_sheet.py hojas/isak_pulse.png --anim pulse --cols 3 --rows 2 --frames 6
  ```
- **Revisar:** no hay ninguna onda, luz ni destello; el brazo extendido no toca el borde de la celda; los pies no se mueven.

### 3.7 Daño (2 cuadros + 1 de referencia, 3x1)

El documento pide un glitch de píxeles. **El glitch lo aplica el juego con un shader**, así que aquí solo hace falta la pose normal del golpe. El golpe llega de frente (desde la derecha); el juego voltea el sprite cuando Isak mira a la izquierda.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: hurt, 2 frames (a hit coming from the front, from the right side of the image) plus 1
standing reference pose.
SHEET LAYOUT: wide image (2:1), a grid of 3 columns x 1 row, 3 equal cells with empty space between the
characters. One full-body pose per cell. Cells read left to right.
In every cell: same character scale (the standing pose in cell 3 is about 75% of the cell height),
horizontally centered, feet on exactly the same ground line near the bottom of the cell.
CELLS:
1) FLINCH: torso pushed backward (leaning to the left of the image), head turned down and away from the
   hit, eyes squeezed shut, teeth clenched; the near (left) arm raised in front of the chest to protect,
   the right hand still holding the phone, pulled back. Feet stay on the ground, the front foot slid a
   little backward.
2) RECOVERING: halfway back to upright, torso still slightly back, wincing with one eye open, arms
   coming down, phone still in the right hand.
3) SIZE REFERENCE: the neutral standing pose from the reference image: upright, feet flat on the ground,
   arms relaxed at the sides, phone held low in the right hand. Same scale as the other cells.
Normal colors in all cells.
DO NOT: no glitch, no pixel noise, no color shift, no red tint, no flash, no blood, no impact star,
no particles, no motion lines, no change of facing direction, no shadow.
```

- **Archivo:** `hojas/isak_hurt.png` (3 columnas x 1 fila, 2 cuadros + referencia en la celda 3).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_hurt.png --anim hurt --cols 3 --rows 1 --frames 2 --ref-frame 2 \
      --height-tol 0.3 --dry-run --preview /tmp/isak_hurt_preview.png
  python3 tools/import_sheet.py hojas/isak_hurt.png --anim hurt --cols 3 --rows 1 --frames 2 --ref-frame 2 \
      --height-tol 0.3
  ```
- **Revisar:** colores normales, sin glitch ni tinte rojo; la celda 3 es la pose de `isak_ref.png`; los pies siguen en el suelo.

### 3.8 Muerte (4 cuadros + 1 de referencia, 3x2)

Solo la pose; **el pixelado y las líneas de código que suben los aplica el juego**. El documento dice que "Isak no cae al suelo": se pixela y se desintegra. Por eso la pose es de derrota y **no termina tumbado**. La pose final propuesta es con una rodilla en el suelo; si prefieres que siga de pie, cambia el cuadro 4 antes de generar.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

ANIMATION: defeat, 4 frames (not a loop) plus 1 standing reference pose. He is defeated but he does
NOT fall to the ground and does NOT lie down.
SHEET LAYOUT: wide image (3:2), a grid of 3 columns x 2 rows, 6 equal cells with empty space between the
characters. Cells read left to right, top to bottom. Cells 1 to 5 each hold one full-body pose;
cell 6 (bottom right) is EMPTY: only the flat magenta background.
Same character scale in every cell (the standing pose in cell 5 is about 70% of the cell height),
horizontally centered, feet or knee on exactly the same ground line near the bottom of the cell.
CELLS:
1) STOP: he freezes upright, body tense, shoulders raised, arms slightly away from the body, phone still
   in the right hand, eyes wide.
2) WEAKEN: shoulders drop, head starts to bow, arms hang loose, knees start to bend.
3) BUCKLE: knees give way, body sinks into a half crouch, torso bent forward, head down, arms hanging.
4) DEFEATED (final pose): down on one knee, the other foot flat on the ground, torso upright but bowed,
   head down, arms hanging limp at the sides, phone held loosely in the right hand near the ground.
   He is NOT lying down and his body does NOT touch the ground except the knee and the foot.
5) SIZE REFERENCE: the neutral standing pose from the reference image: upright, feet flat on the ground,
   arms relaxed at the sides, phone held low in the right hand. Same scale as the other cells.
6) EMPTY cell.
Normal colors in all cells.
DO NOT: no lying down, no falling on the back or face, no pixelation, no disintegration, no code lines,
no particles, no glow, no fading, no transparency, no ghost, no change of facing direction, no shadow.
```

- **Archivo:** `hojas/isak_dead.png` (3 columnas x 2 filas, 4 cuadros + referencia en la celda 5; la celda 6 vacía).
- **Importar:**
  ```bash
  python3 tools/import_sheet.py hojas/isak_dead.png --anim dead --cols 3 --rows 2 --frames 4 --ref-frame 4 \
      --height-tol 0.4 --dry-run --preview /tmp/isak_dead_preview.png
  python3 tools/import_sheet.py hojas/isak_dead.png --anim dead --cols 3 --rows 2 --frames 4 --ref-frame 4 \
      --height-tol 0.4
  ```
  La celda 6 no se lee: con `--frames 4 --ref-frame 4` el importador solo usa las celdas 1 a 5.
- **Revisar:** Isak nunca queda tumbado; sin pixelado ni partículas; la celda 5 es la pose de `isak_ref.png`; la celda 6 está vacía (si la herramienta la llena, da igual, pero no debe invadir otra celda).

## 4. Alternativa cuadro por cuadro

Si la herramienta no entrega hojas consistentes (cambia el personaje entre celdas, no respeta la rejilla), genera **un cuadro por imagen** y monta tú la hoja.

1. Sube `isak_ref.png` como imagen de referencia en cada generación (y la misma semilla, si se puede).
2. Usa siempre el mismo tamaño de imagen para toda la animación (el de la celda de la §3, por ejemplo 384x512 para caminar).
3. Pega el prompt de abajo y sustituye `<ANIMATION>` y `<POSE>` por una fila de la tabla.
4. Guarda los cuadros numerados (`walk_01.png`, `walk_02.png`, ...).
5. Monta la hoja: en Aseprite, abre el primer archivo (detecta la secuencia y la carga como cuadros) y usa *File > Export Sprite Sheet* con disposición por filas y el número de columnas de la §3. Fondo magenta o transparente.
6. Importa la hoja con el comando de su estado. Añade `--align feet` (salvo en el salto) para corregir pies desplazados entre imágenes.

```text
=== ISAK CHARACTER SHEET (always paste unchanged) ===
Same character as the attached reference image. Isak is a 17-year-old boy drawn with slightly chibi
proportions: big head, about 3.5 heads tall, slim body.
Face: fair skin with a warm light-peach tone, large dark-brown eyes, calm and slightly tired expression.
NO glasses, no visor, no goggles.
Hair: dark brown with reddish-brown highlights, messy and spiky, bangs over the forehead, covering the ears.
Jacket: loose dark charcoal-grey tactical jacket, worn open, with a high collar and puffy sleeves.
Bright cyan glowing trim lines on the collar and a small bright cyan patch on the left shoulder.
Shirt: black shirt/vest with a small white logo on the chest.
Backpack: medium-brown backpack worn on his back, with a darker brown strap visible over the shoulder.
Pants: dark-grey cargo pants with side pockets and a darker pocket/holster on the thigh.
Boots: chunky medium-grey boots with small orange details.
Phone: a black smartphone with a grey edge, always held in his RIGHT hand.
Color palette (only these colors on the character): dark brown and reddish brown (hair), light peach (skin),
dark charcoal grey and medium grey (jacket), bright cyan (accents), black (shirt), white (logo),
medium brown and dark brown (backpack), dark grey (pants), medium grey and orange (boots),
black and grey (phone), very dark brown/black (outline).
Style: pixel art style game sprite for a 2D side-scrolling platformer. Clean dark outline around the
whole character, flat colors, NO gradients, simple cel shading with 2 to 3 tones per color,
crisp hard edges, no blur, no glow halo, no rim light.
View: strict side view (pure profile), character facing RIGHT. The reference image shows him in
three-quarter view facing left; redraw the SAME character in pure profile facing right. In profile we
see his left side: the cyan shoulder patch is on the near shoulder, the backpack sticks out behind him
on the left of the image, and the phone is in his right (far-side) hand.
Background: one flat solid magenta color (#FF00FF) filling the whole image. No ground shadow,
no cast shadow, no floor line, no scenery, no text, no numbers, no watermark, no frame borders,
no grid lines, no extra characters, no visual effects.
=== END OF CHARACTER SHEET ===

SINGLE FRAME of the <ANIMATION> animation. Exactly the same character, the same scale and the same
framing as the attached standing reference image: same character height, horizontally centered, the
feet on the same ground line at the same distance from the bottom of the image (unless the pose is in
the air). One character only.
POSE: <POSE>
DO NOT: no second character, no other poses, no effects, no motion lines, no shadow, no text.
```

Tabla de poses para sustituir. "Near" es la izquierda de Isak (la que ve la cámara), "far" la derecha. Cada fila es un resumen del cuadro correspondiente de la §3; si una pose sale ambigua, copia la frase completa de allí.

| Estado | Cuadro | `<POSE>` |
|---|---|---|
| idle | 1 | neutral standing, arms relaxed at the sides, phone low in the right hand |
| idle | 2 | same as neutral, breathing in, chest slightly raised |
| idle | 3 | right forearm bending, phone lifted to hip height, head forward |
| idle | 4 | phone at stomach height, head starting to tilt down |
| idle | 5-8 | phone in front of the chest, head tilted down reading the screen (6: shoulders slightly lower; 7: thumb tapping; 8: breathing in) |
| idle | 9 | head lifting, phone starting to lower |
| idle | 10 | phone at hip height, head forward |
| idle | 11 | arm almost straight at the side, breathing out |
| idle | 12 | almost identical to neutral, chest a tiny bit lower |
| terminal | 1 | neutral standing, arms relaxed, phone low in the right hand |
| terminal | 2 | left forearm raised horizontally in front of the chest, wrist up, head tilting down |
| terminal | 3 | same, a thin solid cyan line just above the left wrist |
| terminal | 4 | same, a small solid opaque cyan screen half open above the wrist |
| terminal | 5 | same, the small cyan screen (size of his head, dark data bars inside) fully open, he reads it |
| terminal | 6 / 8 | same, right hand (holding the phone) taps the screen with the index finger |
| terminal | 7 | same, data bars changed, right hand slightly back |
| terminal | 9 | same, right hand lowered to hip height, tiny nod |
| terminal | 10 | the screen shrunk back to a thin cyan line |
| terminal | 11 | no hologram, left forearm lowering |
| terminal | 12 | almost neutral, arms nearly at the sides |
| walk | 1 | contact: near leg forward heel down, far leg behind on toes, far arm (phone) forward, near arm back |
| walk | 2 | down: weight on near leg, knee bent, body lowest, far foot lifting behind |
| walk | 3 | passing: near leg straight under body, far knee bent passing, arms at the sides |
| walk | 4 | up: near leg on toes, body highest, far leg swinging forward |
| walk | 5-8 | mirror of 1-4 with legs and arms swapped |
| run | 1 | contact: torso leaning 15 degrees, near foot landing in front, far leg behind knee bent, far arm forward |
| run | 2 | down: near knee bent absorbing, body lowest, far knee swinging forward |
| run | 3 | push-off: near leg extended behind on toes, far knee high and forward |
| run | 4 | flight: both feet slightly off the ground, far leg reaching forward, near leg trailing |
| run | 5-8 | mirror of 1-4 with legs and arms swapped |
| jump | 1 | anticipation: deep crouch, torso forward, arms swung back |
| jump | 2 | rising, slightly in the air: body stretched up, toes pointing down, arms up and forward |
| jump | 3 | apex, slightly in the air: compact, knees tucked slightly, arms bent at chest height |
| jump | 4 | falling, slightly in the air: legs reaching down, arms raised up and out |
| jump | 5 | landing: squash, deep crouch on the ground, arms forward and down |
| pulse | 1 | neutral standing, phone low in the right hand |
| pulse | 2 | knees slightly bent, phone brought up to the chest |
| pulse | 3 | right arm extended straight forward at shoulder height pointing the phone, left arm back |
| pulse | 4 | recoil: right arm kicked back and slightly up, torso slightly back |
| pulse | 5 | right arm halfway down, phone at stomach height |
| pulse | 6 | almost neutral, phone low next to the thigh |
| hurt | 1 | flinch: torso pushed back, head turned away, eyes shut, near arm raised to protect |
| hurt | 2 | recovering: halfway upright, wincing, arms coming down |
| dead | 1 | frozen upright, tense, shoulders raised, eyes wide |
| dead | 2 | shoulders dropping, head bowing, arms loose, knees starting to bend |
| dead | 3 | half crouch, torso bent forward, head down, arms hanging |
| dead | 4 | down on one knee, other foot flat, torso upright but bowed, head down, arms limp; NOT lying down |

Para salto, daño y muerte, la celda de referencia es la propia `isak_ref.png` (o una copia al mismo tamaño), colocada en la celda que indica la §3.

## 5. Importar la hoja

Primero en simulación, con vista previa (los comandos exactos de cada estado están en la §3):

```bash
python3 tools/import_sheet.py hojas/isak_walk.png --anim walk --cols 4 --rows 2 --frames 8 --ref-frame 2 \
    --dry-run --preview /tmp/isak_walk_preview.png
```

Si la vista previa se ve bien, se repite sin `--dry-run` ni `--preview` (escribe en `assets/sprites/isak/`).

| Opción | Uso |
|---|---|
| `--cols N --rows M` | Rejilla. Si se omite, la detecta por las bandas vacías entre personajes. |
| `--frames N` | Cuadros usados en orden de lectura (por ejemplo 5 en el salto). |
| `--ref-frame I` | Celda de Isak de pie que fija la escala y el anclaje (cuenta desde 0). Puede ser la celda extra final, que no se exporta (en el salto de 3x2: `--frames 5 --ref-frame 5`). |
| `--align sheet` / `feet` | `sheet` (por defecto) mueve todos los cuadros igual y respeta los saltos y el balanceo. `feet` ancla cada cuadro por sus pies: útil si la IA dejó los personajes descolocados, pero **no** sirve para el salto. |
| `--height-tol` | Tolerancia de altura visible (0.2 por defecto). Súbela a 0.4 en salto y muerte, donde hay poses agachadas. |
| `--shadow off` | Si la hoja no tiene sombra y el importador confunde algo con ella. |

El importador corta la rejilla, quita el fondo y la sombra del suelo, umbraliza el alfa, escala con nearest con **un solo factor para toda la hoja** (Isak de la celda de referencia a 96 px), coloca los pies en la última fila de un canvas de 128x128 y valida cada cuadro (tamaño, fondo transparente, sin semitransparencias, altura, nada recortado). Termina con código distinto de 0 si algo falla, e imprime la deriva de los pies entre cuadros.

## 6. Lista de comprobación antes de entregar la hoja

- [ ] Es el mismo Isak: pelo castaño desordenado, **sin lentes**, chaqueta gris oscura con cian en cuello y hombro, logo claro, mochila marrón, botas grises con naranja, celular en la mano derecha.
- [ ] Sin LED en la mochila ni luz de contorno.
- [ ] Vista lateral, mirando a la derecha, en todos los cuadros.
- [ ] Rejilla regular: celdas iguales, un personaje por celda, nadie toca el borde de su celda.
- [ ] El número de cuadros es el pedido y están en orden de lectura.
- [ ] Mismo tamaño de personaje y pies sobre la misma línea (salvo en el aire).
- [ ] En los bucles (idle, terminal, caminar, correr), el último cuadro empalma con el primero.
- [ ] Fondo transparente o de un solo color plano (magenta). Sin sombra, suelo, texto, números ni marcos.
- [ ] Sin efectos dibujados (onda del pulso, glitch, pixelado, partículas). El holograma de la terminal es la única excepción, y es cian sólido.
- [ ] Si la animación no tiene una pose de pie: hay celda extra de referencia donde indica la §3.
- [ ] PNG sin compresión con pérdida (no JPG).
- [ ] Nombre del archivo: `isak_<anim>.png`.

## 7. Si la IA entrega cuadros inconsistentes

| Problema | Qué hacer |
|---|---|
| Cambia la ropa o la cara, aparecen lentes, otro color de chaqueta | **Reintentar** con la imagen de referencia y la misma semilla; comprueba que la ficha de la §1 está completa y sin cambios. No se arregla con el importador. |
| Vista de tres cuartos o mirando a la izquierda en algunos cuadros | **Reintentar**. Voltear cuadros sueltos rompe la animación. Si se repite, usa la alternativa cuadro por cuadro (§4). |
| Rejilla irregular, personajes que invaden la celda vecina | **Reintentar** pidiendo más margen, o recolocar los cuadros en una rejilla regular con un editor antes de importar. |
| Personaje un poco más grande o más pequeño en algún cuadro | Lo **corrige el importador** solo en parte: escala toda la hoja con el mismo factor, así que un cuadro más grande sigue siéndolo. Si se nota, reintentar ese cuadro (§4) o retocarlo en Aseprite. |
| Pies a distinta altura o personaje desplazado en la celda | Con `--align feet` lo **corrige el importador** (no en el salto). |
| Sombra en el suelo, fondo de color, bordes antialias | Lo **corrige el importador**. |
| Detalle que parpadea entre cuadros (logo, cian, dedos, celular) | Lo **retoca el usuario en Aseprite** sobre los PNG de 128x128 ya importados. |
| Holograma, onda u otro efecto translúcido con agujeros | Pedirlo **sólido** o dejar el efecto al juego. |
| El ciclo no cierra (salto visible entre el último cuadro y el primero) | **Reintentar** recalcando la frase "leading straight back into frame 1", o regenerar solo el último cuadro con la §4. |
| Faltan cuadros o hay cuadros repetidos | **Reintentar**, o usar `--frames` para importar solo los buenos si el ciclo sigue funcionando. |

Después de importar, revisa la vista previa ampliada (guía cian = centro, magenta = línea base) y prueba la animación en el juego antes de darla por buena.
