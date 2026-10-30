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

Pendiente: visto bueno del usuario al base; después, limpieza (halo, cian), posible estirado y `upload_character` gratis antes de las poses y animaciones.
