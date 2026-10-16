# 15. Estilo visual

Origen: sección 15 del documento original (`docs/original/diseno.md`).

Pixel art 2D con paletas limitadas por mundo. El objetivo es que el juego se vea bien, se lea con claridad y que cada mundo tenga identidad propia con solo mirar una captura.

## 15.1 Resolución y técnica

> **Cambio aprobado 2026-10-14:** resolución base **1280x720** (stretch `viewport`, escala `integer`, filtro nearest). **Sprite de Isak** en canvas de **128x128** con unos **96 px** de altura visible y los pies abajo-centro. **Tiles de 64x64** (Isak sigue midiendo un tile y medio). Enemigos entre 64x64 y 128x128, jefes entre 256x256 y 512x512, efectos en múltiplos de 8. La tabla siguiente es la propuesta original y se conserva como referencia histórica; donde choque con esta nota, manda la nota.

| Elemento | Propuesta |
|---|---|
| **Resolución base** | 640x360 (16:9). Escala por múltiplos enteros: x3 da 1920x1080, y x2 da 1280x720. Sin interpolación, con filtro nearest. |
| **Sprite de Isak** | Canvas de 64x64, con unos 48 píxeles de altura visible y margen para las animaciones. Es un tamaño grande, que permite ver los lentes, el logo y la mochila. |
| **Tiles** | 32x32. Isak mide aproximadamente un tile y medio de alto. |
| **Enemigos** | Entre 32x32 y 64x64, según el tipo. |
| **Jefes** | Entre 128x128 y 256x256, para que ocupen buena parte de la pantalla. |
| **Cámara** | Muestra unos 20 por 11 tiles. Es suficiente para leer los peligros sin que el personaje se vea pequeño. |
| **Animación** | Cuadro a cuadro, a unos 12 cuadros por segundo para las animaciones de personaje y a 24 para los efectos. |

El tamaño del sprite es la decisión con más consecuencias. Un sprite de 64 píxeles se ve rico en detalle, pero deja menos espacio de nivel visible. Si en las pruebas la pantalla se siente apretada, la alternativa es bajar el sprite a 48x48 y mantener la resolución base.

## 15.2 Reglas generales

- **Paleta limitada:** unos 16 colores por mundo, más el color del Debug. Cada paleta se guarda como archivo y no se improvisan colores fuera de ella.
- **Silueta primero:** todo personaje o enemigo debe reconocerse por su silueta, incluso en negro.
- **El rojo tiene un significado:** daño y puntos débiles. En el Mundo 1 las alertas usan un rojo anaranjado, y el punto débil del jefe usa un carmín más puro y pulsante, para que no se confundan.
- **Telegrafiar los ataques:** todo ataque enemigo muestra una anticipación visible de 6 a 12 cuadros antes de dañar.
- **Pocas luces, bien usadas:** el brillo se reserva para lo que importa, como las plataformas interactivas, los coleccionables y los puntos débiles.

## 15.3 Paletas por mundo

| Mundo | Paleta base | Acento | Debug |
|---|---|---|---|
| **Hub** | Gris azulado apagado | Se ilumina con cada pieza del fondo | Según el mundo |
| **1. Notificaciones** | Azul noche oscuro y banners blancos | Rojo alerta | Cian |
| **2. El Feed** | Violeta y magenta neón | Tarjetas de bordes redondeados | Ámbar |
| **3. La Vitrina** | Rosa pastel y blanco brillante | Dorado | Verde ácido |
| **4. El Chat** | Azul marino y gris, con burbujas crema | Verde apagado | Coral |
| **5. La Tienda** | Negro con neones | Amarillo chillón | Blanco |
| **6. La Nube** | Plata, blanco y gris frío | Azul pálido, con filtraciones de colores anteriores | Cambia por zona |

### 15.3.1 Paleta del hub (PROPUESTA 2026-10-15)

Estado: **propuesta**, pendiente de aprobación del usuario. El usuario aportó cuatro hex (`#050E3C` y `#002455`, azules muy oscuros; `#DC0000` y `#FF3838`, rojos) y delegó el resto. Archivo: `assets/palettes/hub.gpl` (16 colores). Vista previa con muestras y maqueta (fondo con la foto rota, dock, carpetas completada/disponible/bloqueada, copia local activa, Calc dormida e indicador «sin guardar»): `assets/palettes/hub_paleta.png`. Generador y validador: `tools/palette_hub_preview.py` (ver «Regenerar y validar»).

A diferencia del Mundo 1 (16 + `debug_cian` aparte), el cian va **dentro** de los 16: en el hub el cian no es un tinte de Debug, sino el acento de lo interactivo y de la pieza encendida (§13.4). Cuando el hub muestre piezas de otros mundos, su acento se añadirá como color aparte, igual que el Debug de cada mundo.

| Rol | Hex | Uso |
|---|---|---|
| `fondo_profundo` | `#050e3c` | Contorno de todo y fondo del HUD (dato del usuario; sustituye a `noche_profunda` en el hub). |
| `sombra` | `#002455` | Sombras, interior del dock, marco y huecos de la foto rota (dato del usuario). |
| `panel` | `#1a2a46` | Fondo de los paneles de menú (copia local, Calc, carpetas). |
| `dock` | `#26354f` | Dock (suelo) y repisas. Más oscuro que el fondo, como los tiles del Mundo 1. |
| `base` | `#3a4862` | Fondo ambiente: el «gris azulado apagado». |
| `gris_apagado` | `#56637a` | Piezas apagadas de la foto, carpeta bloqueada, Calc dormida (desde el 2026-10-15 (3), Calc apagada hasta el final del 1-2), huecos del dock y Papelera dormida. |
| `gris_foto` | `#77849a` | Luz de las piezas apagadas y bisel del dock. |
| `traza` | `#4f71c4` | Trazas de circuito de 1 px (mismo hex que `resplandor` del Mundo 1). |
| `borde` | `#9bb0e8` | Borde superior del dock y de las repisas, bisel claro (mismo hex que `borde_luz`). |
| `texto_tenue` | `#aab4c6` | Texto secundario, candado de la carpeta bloqueada. |
| `texto_claro` | `#eef1f7` | Texto de paneles y HUD, iconos claros (Modo Avión). |
| `cian_tenue` | `#12857f` | Pieza 1 encendida (sombra), halo de lo interactivo (mismo hex que `pulse_dim`). |
| `acento_cian` | `#3dfff5` | Interactivos: carpeta disponible, copia local activa, tecla del pulso, opción elegida, pieza 1 (mismo hex que `debug_cian`). |
| `cian_brillo` | `#c2fffc` | Pieza 1 encendida (brillo), pantalla de la copia local (mismo hex que `pulse_core`). |
| `ambar` | `#ffa000` | Puntos de atención e indicador «sin guardar» (mismo hex que `ambar` del Mundo 1). |
| `ambar_sombra` | `#a85f00` | Sombra de los puntos de atención. |

Estados de los elementos (color y además forma, por daltonismo):

- **Foto rota:** piezas apagadas en `gris_apagado`/`gris_foto` con contorno `fondo_profundo` sobre `sombra`. La pieza 1 encendida usa la rampa `cian_tenue` → `acento_cian` → `cian_brillo` (5,49:1 de `cian_brillo` frente a una pieza apagada). En el hub del 1-1, la pieza 1 solo lleva el contorno `acento_cian` parpadeante.
- **Carpetas:** bloqueada = relleno `gris_apagado` con candado `texto_tenue`; disponible = relleno `panel` con contorno y rótulo `acento_cian`; completada = relleno `acento_cian` con check `fondo_profundo`.
- **Copia local:** monitor con pantalla `cian_brillo` y marco `acento_cian` cuando se puede usar; tecla del pulso sobre `panel` con contorno `acento_cian`.
- **Calc:** dormida en `gris_apagado` con la «z» en `texto_tenue`; despierta, con los acentos en `acento_cian`.
- **Indicador «sin guardar»:** punto y texto en `ambar` sobre el HUD (`fondo_profundo`). Se elige el ámbar de los puntos en vez de un rojo, porque en el hub nada hace daño, y en vez de `banner_blanco` (como decía la propuesta del hub, §4.3), porque el blanco no destaca como aviso entre los demás textos del HUD.

**Sin rojo en el hub.** `#dc0000` y `#ff3838`, aportados por el usuario, quedan **reservados** para alertas, jefes y puntos débiles de otros mundos (o la paleta del mundo que corresponda): el rojo significa daño (§15.2). No se pierden; `tools/palette_hub_preview.py` los guarda en `RESERVED` y `--check` falla si alguno entra en `hub.gpl`.

Contrastes WCAG (medidos con `tools/palette_hub_preview.py`). Mínimo 4,5:1 para texto y 3:1 para iconos y bordes (WCAG 1.4.11):

| Frente | Fondo | Ratio | Mínimo | Uso | Cumple |
|---|---|---|---|---|---|
| `texto_claro` | `panel` | 12,68:1 | 4,5 | Texto de panel | Sí |
| `texto_claro` | `fondo_profundo` | 16,36:1 | 4,5 | Texto del HUD | Sí |
| `texto_claro` | `base` | 8,13:1 | 4,5 | Texto sobre el fondo | Sí |
| `texto_claro` | `dock` | 10,89:1 | 4,5 | Rótulo sobre el dock | Sí |
| `texto_tenue` | `panel` | 6,87:1 | 4,5 | Texto secundario de panel | Sí |
| `texto_tenue` | `fondo_profundo` | 8,86:1 | 4,5 | Texto secundario del HUD | Sí |
| `acento_cian` | `panel` | 11,49:1 | 4,5 | Opción elegida en un panel | Sí |
| `ambar` | `fondo_profundo` | 9,06:1 | 4,5 | Puntos y «sin guardar» en el HUD | Sí |
| `ambar` | `panel` | 7,02:1 | 4,5 | Precio en puntos (Calc) | Sí |
| `fondo_profundo` | `acento_cian` | 14,83:1 | 4,5 | Texto oscuro sobre botón cian | Sí |
| `acento_cian` | `base` | 7,37:1 | 3 | Contorno de carpeta disponible y pieza 1 | Sí |
| `acento_cian` | `dock` | 9,87:1 | 3 | Copia local activa | Sí |
| `ambar` | `base` | 4,50:1 | 3 | Punto de atención sobre el fondo | Sí |
| `borde` | `dock` | 5,73:1 | 3 | Borde superior del dock | Sí |
| `borde` | `base` | 4,28:1 | 3 | Borde de repisa sobre el fondo | Sí |
| `texto_tenue` | `base` | 4,40:1 | 3 | Candado de carpeta bloqueada | Sí |
| `fondo_profundo` | `gris_apagado` | 3,05:1 | 3 | Contorno de carpeta bloqueada | Sí |
| `fondo_profundo` | `acento_cian` | 14,83:1 | 3 | Check de carpeta completada | Sí |
| `cian_brillo` | `gris_apagado` | 5,49:1 | 3 | Pieza 1 encendida frente a las apagadas | Sí |
| `fondo_profundo` | `base` | 2,01:1 | 3 | Contorno sobre el fondo | **No (aceptado):** el objeto se separa del fondo por su bisel `borde` (4,28:1) y su relleno, no por el contorno. |
| `gris_apagado` | `base` | 1,52:1 | 3 | Pieza apagada frente al fondo | **No (aceptado):** decorativo; la foto apagada debe fundirse con el fondo. |

Regenerar y validar (desde la raíz del repo; funciona con `python3 -I`):

- `python3 -I tools/palette_hub_preview.py` rehace `hub.gpl` y `hub_paleta.png` e imprime la tabla de contrastes (`--png <ruta>` copia además la vista previa).
- `python3 -I tools/palette_hub_preview.py --check` valida `hub.gpl`: 16 colores, hex y nombres únicos, igual al generador, sin los rojos reservados y con los contrastes mínimos (sale con 1 si falla).
- Los sprites del hub (fondo, carpetas, dock, iconos) se validan contra `hub.gpl` con el `load_gpl`/`check_asset` de `tools/validate_world1_assets.py`, cambiando la ruta de la paleta, como hace `tools/validate_energy_objects.py`.

## 15.4 Isak y su copia

> **Cambio aprobado 2026-10-14:** el diseño de Isak de la hoja de referencia `../Ejemplo/Idle.png` (fuera del repo; arte generado con IA, no pixel art verdadero) **reemplaza** el diseño de la tabla siguiente y se usa como guía. Lo que se ve en la referencia:
>
> | Elemento | Diseño aprobado |
> |---|---|
> | **Cuerpo** | Chico de proporciones algo chibi (cabeza grande), ojos oscuros grandes, **sin lentes**. |
> | **Pelo** | Castaño oscuro, desordenado y en punta. |
> | **Chaqueta** | Gris oscura tipo táctica, holgada, con **detalles cian luminosos** en el cuello alto y un parche cian en el hombro. Ya no es verde oliva. |
> | **Camiseta** | Camiseta/chaleco negro con un **logo claro** (blanco) en el pecho. |
> | **Mochila** | Marrón, con la correa visible sobre el hombro. |
> | **Pantalón** | Gris oscuro, tipo cargo, con bolsillos y una funda o bolsillo oscuro en el muslo. |
> | **Botas** | Grises, robustas, con **detalles naranja**. |
> | **Celular** | Siempre lo lleva; en el idle lo sostiene y lo mira. |
>
> El cian y el celular se mantienen como rasgos de identidad. La luz de contorno y el LED de la mochila de la tabla original no aparecen en la referencia y siguen sin decidir. Las hojas se generan con [guia-sprites-ia.md](guia-sprites-ia.md) y se importan con `tools/import_sheet.py`. `docs/original/diseno.md` queda intacto.

Diseño original (reemplazado, se conserva como referencia):

Isak aparece en todos los fondos, así que su diseño debe leerse sobre cualquier paleta. La camiseta negra es un riesgo en los mundos oscuros, y por eso se compensa con la chaqueta y una luz de contorno.

| Elemento | Diseño |
|---|---|
| **Camiseta** | Negra, con el logo en el centro en color crema. |
| **Chaqueta** | Verde oliva desaturado. Es un color que no se repite en ninguna otra paleta, y mantiene a Isak legible en todos los mundos. |
| **Luz de contorno** | Un píxel de luz en el borde, del color del mundo en el que se encuentra. |
| **Lentes** | Con un reflejo que cambia con el color del mundo. |
| **Mochila** | Técnica, con un pequeño LED de estado que se apaga a medida que baja la energía de Debug. Es un indicador dentro del propio personaje. |
| **Isak Optimizado** | Mismo diseño, pero más saturado y limpio. Sin LED en la mochila, sin reflejo cambiante en los lentes y sin rebote al correr. |

### Animaciones principales

- **Caminar y correr:** de 6 a 8 cuadros, con un ligero peso y el rebote de la mochila.
- **Salto:** con anticipación corta, subida, apogeo y caída con aplastamiento al aterrizar.
- **Idle:** tras unos segundos, saca la terminal holográfica de la muñeca y ajusta su visor. Es un bucle de 8 a 12 cuadros.
- **Pulso de datos:** de 4 a 6 cuadros, con un rastro corto del color del mundo.
- **Daño:** efecto de glitch, con píxeles que parpadean y se desplazan.
- **Muerte:** pixelado progresivo hasta que el cuerpo se desintegra en líneas de código que suben.

## 15.5 Enemigos y jefes

- **Cada mundo, una familia de formas:** las Burbujas son redondas, el Feed usa rectángulos de tarjeta, la Vitrina usa marcos y espejos, el Chat usa burbujas de texto y la Tienda usa carteles y cajas.
- **Copias optimizadas:** misma silueta que el enemigo original, pero con la paleta desaturada y sin animaciones secundarias. Se leen como "perfectas" y sin vida.
- **Jefes:** ocupan buena parte de la pantalla, con animaciones de reposo que muestran su personalidad. El punto débil se muestra siempre igual: un rojo pulsante que solo aparece con el Debug.

## 15.6 Efectos visuales

| Efecto | Cómo se ve | Accesibilidad |
|---|---|---|
| **Debug Mode** | Ralentiza el tiempo y tiñe la pantalla del color del mundo, con una viñeta. Las plataformas ocultas aparecen con contorno. | Contorno claro para daltonismo. |
| **Daño** | Píxeles que parpadean y se desplazan a lo largo del sprite. | Duración corta. |
| **Sync Rate menor al 20%** | Ruido visual y distorsión en la pantalla, con la música deformada. | Opción para reducirlo. |
| **Tentación** | Líneas de atracción brillantes que van hacia el objeto. | Con indicación sonora. |
| **"Visto"** | Tinte gris y un doble check sobre la zona. | Forma además del color. |
| **Filtro (Mundo 3)** | Capa rosada y suavizada. Desaparece al activar el Debug. | Contraste de peligros visible. |
| **Espejos** | Reflejo con un ligero desfase respecto a Isak. | Sin parpadeos. |

## 15.7 Interfaz

El HUD imita la barra de estado de un celular, lo que refuerza que Isak está dentro de uno.

- **Señal:** es el Sync Rate. Se muestra como barras de señal con un porcentaje. Al bajar del 20% las barras parpadean.
- **Batería:** es la energía de Debug. Se vacía al usar el Debug y se recarga con puntos de atención.
- **Contador de puntos de atención:** junto a la barra, con un icono pequeño.
- **Fuente:** pixel art, legible a la resolución base y con soporte para tildes y la letra ñ.
- **En el Mundo 3:** el contador de likes aparece junto al HUD.

## 15.8 Referencias de estilo

Como inspiración, sin copiar, se pueden mirar juegos con rasgos que buscamos: Celeste, por la claridad del movimiento y los controles; Hyper Light Drifter, por el uso de paleta y luz; y Katana ZERO, por el tiempo ralentizado y los efectos de glitch.

## 15.9 Producción del arte

- **Herramienta:** Aseprite para sprites y tilesets, con las paletas fijas por mundo.
- **Motor:** Godot con la resolución base de 640x360 (cambiada a 1280x720 el 2026-10-14, ver nota de 15.1), modo de escala por viewport y filtro nearest en todos los recursos.
- **Arte con apoyo de IA:** se puede usar para explorar conceptos y referencias, pero cada sprite final conviene limpiarlo a mano en Aseprite para mantener la coherencia de paleta y de tamaño.
- **Orden de producción:** primero Isak (caminar, saltar, idle y pulso), luego el tileset del Mundo 1 y el nivel 1-1 jugable. Con eso se prueba el tamaño del sprite y el ritmo del movimiento antes de producir el resto.
