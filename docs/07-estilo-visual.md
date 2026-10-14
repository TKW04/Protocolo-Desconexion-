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
