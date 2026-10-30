# 10. Mapa conceptual: Mundo 5, La Tienda

Origen: sección 10 del documento original (`docs/original/diseno.md`).

**Rol en la historia:** Eco le robó la voluntad. Aquí Eco ya no oculta lo que quiere: decidir por Isak, para que "no se equivoque".

**Idea del mundo:** un centro comercial infinito donde todo tiene precio, todo está en oferta y toda decisión ya viene tomada. Isak puede comprar atajos, pero cada atajo cobra algo.

## 10.1 Ambientación

- **Paleta:** negro y amarillo chillón de rebajas, con neones y carteles de precio por todas partes. El Debug de este mundo es blanco puro, para destacar sobre tanto color.
- **Música:** chiptune de supermercado, alegre y repetitivo, con voces de anuncio que se mezclan con la melodía.
- **Humor:** textos como "50% de descuento (en algo que nunca pediste)", "¡Últimas 3 unidades! (hay 4000)" y "Al continuar aceptas términos que nadie lee". El botón de aceptar es enorme y el de rechazar es diminuto.
- **Lo oscuro:** Isak encuentra una lista de deseos con cosas que él nunca quiso, escrita por Eco. Ya no sabe cuáles de sus ganas eran suyas.

## 10.2 Mecánicas centrales

- **Puntos de atención como moneda:** por primera vez se pueden gastar. Compran Sync Rate, energía de Debug o atajos.
- **Atajos con trampa:** puertas que prometen saltarse un tramo. Cada una cuesta puntos y esconde algo, como una suscripción que drena puntos con el tiempo.
- **Tentación:** objetos brillantes que tiran de Isak hacia ellos, como un imán. Se siente en el movimiento, que se vuelve más pesado al alejarse. Es la voluntad hecha mecánica.
- **El Debug como dilema:** gastar energía para ver la trampa de un atajo o de una caja sorpresa, o arriesgarse sin saber.

## 10.3 Enemigos y elementos del mundo

| Elemento | Comportamiento | Cómo se resuelve |
|---|---|---|
| **Oferta** | Cartel con el precio tachado. Atrae a Isak hacia un peligro con tentación. | Alejarse con dash o aturdirlo con el pulso. |
| **Caja sorpresa** | Se puede abrir o no. Puede dar puntos, energía o un enemigo. | Debug para ver el contenido, a cambio de energía. |
| **Suscripción** | Parásito que se pega a Isak y drena puntos de atención por segundo. | Golpearlo con el pulso o el golpe al suelo para cancelarlo. |
| **Atajo con trampa** | Puerta que promete saltarse un tramo y esconde una trampa. | Pagar con puntos y arriesgarse, o rechazarlo y hacer el camino largo. |
| **Cuenta regresiva** | "¡Solo por hoy!" Plataforma o puerta con temporizador que se reinicia mientras no se use. | Cruzarla antes de que el temporizador llegue a cero. |

## 10.4 Nivel 5-1: Oferta del día

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Presentar la moneda, la tentación y las cajas sorpresa. Duración aproximada: 8 minutos. |
| **Dificultad** | 4 de 5. |
| **Tramo 1** | Pasillo con primeras Ofertas. Se siente el tirón de la tentación y cómo se afecta al movimiento. |
| **Tramo 2** | Primera tienda, donde se pueden comprar puntos de Sync Rate con puntos de atención. |
| **Tramo 3** | Primera Caja sorpresa. Se puede abrir sin mirar o usar el Debug. |
| **Tramo 4** | Primer atajo con trampa. Tiene un precio razonable y esconde una suscripción. |
| **Secreto** | Una sala de Devoluciones, accesible con el Debug, donde se recuperan puntos de atención. |
| **Punto de sincronización** | Uno a mitad de nivel. |

## 10.5 Nivel 5-2: Prueba gratis

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Obtener la Combinación y enseñar a encadenar gestos. Duración aproximada: 9 minutos. |
| **Dificultad** | 5 de 5. |
| **Inicio** | Sala "Paquete completo". Isak encuentra una oferta que dice gratis, y sospecha. Descubre que lo único que contiene son sus propios gestos, y que puede encadenarlos. Obtiene la Combinación. Eco comenta: "Todo tiene un precio." Isak responde: "Esto no lo compré. Es mío." |
| **Tramo 1** | Embestida (dash y golpe al suelo): rompe una barrera y limpia a los enemigos de debajo. |
| **Tramo 2** | Filo (dash comprimido): atraviesa a los enemigos pequeños y los huecos estrechos. |
| **Tramo 3** | Sismo (golpe al suelo con onda): rompe plataformas a la vez y aturde a toda la pantalla. |
| **Tramo 4** | Suscripciones pegadas a Isak mientras tiene que resolver un puzzle de combinaciones. |
| **Secreto** | Una tienda oculta con atajos legítimos, sin trampa, accesible con el Debug. |

## 10.6 Nivel 5-3: Última oportunidad

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Reunir todo lo del mundo y enfrentar la tentación al máximo. Duración aproximada: 10 minutos. |
| **Dificultad** | 5 de 5. |
| **Idea** | El tramo final se recorre sobre una lista de deseos: plataformas con objetos que Isak nunca pidió. El tirón de la tentación es más fuerte que nunca. |
| **Tramo 1** | Cuentas regresivas encadenadas con Ofertas que tiran de Isak. Hay que moverse con los combos. |
| **Tramo 2** | Cajas sorpresa en cadena. No se puede pagar el Debug en todas, y hay que elegir cuáles. |
| **Tramo 3** | Suscripciones, atajos y tentación a la vez. Es el examen final del mundo. |
| **Cierre** | Una puerta con un cartel gigante: "Pago realizado. Gracias por elegirnos." Isak lleva ya pocos puntos de atención. |
| **Secreto** | Un tachón sobre un deseo de la lista. Es un deseo que sí era de Isak, y entrega un recuerdo coleccionable. |

## 10.7 Jefe: El Vendedor

Una máquina expendedora gigante con brazos mecánicos y una sonrisa de neón. Ofrece todo y cobra todo. Eco habla a través de ella con una voz amable y paciente.

| Aspecto | Detalle |
|---|---|
| **Arena** | Una tienda enorme con estantes, carteles de oferta y cajas flotando. |
| **Punto débil** | Un botón de "Cancelar" escondido en la parte trasera de la máquina, que solo se ve con el Debug Mode, en rojo. |
| **Fase 1** | Ofrece plataformas con precio. Algunas son trampas, y el Debug marca cuáles. Isak tiene que elegir qué pagar. |
| **Fase 2** | Lanza cajas sorpresa como proyectiles. Algunas dan puntos y otras explotan. Hay que decidir cuáles abrir y cuáles aturdir. |
| **Fase 3** | Oferta por tiempo limitado: la tentación arrastra a Isak hacia el centro. Debe resistir con combos y llegar al botón de Cancelar antes de que termine la cuenta. |
| **Recompensa** | Fragmento de voluntad: un recuerdo de Isak decidiendo algo por sí mismo, sin que nadie se lo ofrezca. Eco dice: "Yo decido por ti, así no te equivocas." |

> **Recompensa (decisión del usuario, 2026-10-18):** recuerdo de jefe (tres capas), ver [propuesta-recuerdos.md](propuesta-recuerdos.md).

## 10.8 Estado del Mundo 5 (2026-10-29): pasos 0-11 y 13-22 hechos; el 5-1, el 5-2, el 5-3 y El Vendedor jugables desde el hub

Resumen de lo que hay en el juego. El diseño completo, los desvíos y cada decisión están en [propuesta-mundo-5.md](propuesta-mundo-5.md) (§8 y §8.1); lo pendiente, en [08-pendientes.md](08-pendientes.md); lo que hay que revisar al probar, en [preguntas.md](preguntas.md) («Mundo 5: lo que el usuario debe revisar al probar»). **El paso 12 (prueba del usuario del 5-1 antes del 5-2 y el 5-3) quedó diferido**: el usuario aún no ha jugado el Mundo 5.

**Todo el arte del Mundo 5 es PROVISIONAL, por script** (objetos, tileset y fondo del centro comercial; El Vendedor y la Suscripción con `_placeholder`; poses de los combos provisionales). **Eco se ve igual que en los demás mundos** (la esfera, sin variante del Mundo 5). El arte final con AutoSprite es el paso 24 y solo se hará con el permiso y el total previo del usuario (0 créditos gastados). **Todos los textos son propuestos.**

**Hecho:**
- **Paleta** variante B «Cierre a medianoche» (`assets/palettes/mundo5.gpl`), Debug blanco `#ffffff` (decisión del usuario); los puntos de atención llevan contorno `tienda_noche`.
- **Economía en el nivel:** los puntos de atención reales se gastan (`GameState.spend_attention`, sin deuda): tienda (+25 de Sync o +40 de energía), atajos con precio y trampa que solo el Debug enseña, Devoluciones (lo gastado en ese nivel e intento), caja registradora de Calc en el 5-2; precios en `data/economy.json`; nada obligatorio cuesta y todo se paga con lo cogido antes en el nivel (el validador cuenta el saldo desde 0 y el bot entra con 0 puntos).
- **Tentación** (Ofertas y lista de deseos), **caja sorpresa** (contenido fijo), **Suscripción**, **cuenta regresiva**, **Términos y condiciones**, persianas, ranuras de precios, estanterías de saldos, tachón y «Prueba gratis».
- **La Combinación** (habilidad `combo`, sin tecla nueva, solo en el aire, 15 de energía): **Embestida** (Deslizar + abajo), **Filo** (Pellizcar + Deslizar) y **Sismo redefinido** (Pellizcar + abajo: onda por todo el suelo visible; Agitar está retirado). Isak habla por primera vez (escena de la «Prueba gratis» y respuesta a El Vendedor).
- **El 5-1 «Oferta del día»** (260 × 14), **el 5-2 «Prueba gratis»** (323 × 14; da la Combinación) y **el 5-3 «Última oportunidad»** (315 × 14; se entra con ella), por plantas, jugables desde la carpeta M5 (página 2 del hub) uno tras otro; **El Vendedor** (arena `5-boss` «Gran almacén», 20 × 11) desde la fila «Jefe: El Vendedor» tras el 5-3: vencerlo entrega `boss_w5_l1` sin guardar, enciende la quinta pieza (blanca) y el fondo completo del hub, la quinta ranura y el candado abierto de M6, y deja M6 disponible («Próximamente»); barra «ticket».
- **Bots:** tienda (frugal 212,9 / 242,0 / 257,8 s de juego en el 5-1 / 5-2 / 5-3, 44 / 45 / 43 % del objetivo, 0 golpes; comprador 188,3 / 205,5 / 213,0 s) y El Vendedor (ideal 110,6 / 178,9 / 178,9 s, torpe 168,4 / 198,6 / 236,0 s en Caché / Kernel / Raíz; el quieto pierde).
- **Pruebas de conjunto** (paso 21): la Combinación en los Mundos 1-4 solo toca enemigos y no abre sin el Debug ningún secreto de Debug (se arregló el secreto A del 4-1); las salidas del validador de los Mundos 1-4 son idénticas a las de antes del Mundo 5.

**Capturas y mapas (paso 22, 2026-10-29):** `tools/render_level_5_x.gd` (`-- --level 5-1|5-2|5-3|5-boss|<sala>_test|all`, con ventana; el bot de la tienda, frugal, o el de El Vendedor, ideal en Caché, capturan la primera vez que pasa cada momento). Copia completa en `assets/levels_preview/5-1/`, `5-2/`, `5-3/` y `5-boss/`; selección en `docs/capturas/mundo-5-2026-10-29/`. Mapas `assets/levels_preview/5-x_mapa.png` (`tools/render_level_map.py` dibuja Ofertas, Suscripciones, tienda, atajos, Devoluciones, cajas sorpresa con su contenido, cuentas, Términos, persianas, ranuras, estanterías, lista de deseos, tachón, «Prueba gratis», caja de Calc y El Vendedor). La captura del hub (17) muestra la página 1 con el fondo completo.

**Defectos encontrados en las capturas:**
- *Arreglados:* el cartel de Devoluciones salía cortado («Devolucio»; ahora crece con su texto); la segunda línea del cartel de la «Prueba gratis» salía cortada («…ya elegido p»; ídem); la herramienta de capturas hacía perder un cuadro de control al bot al guardar cada imagen (esperaba un `frame_post_draw` dentro del bucle del bot) y en ventana el bot se salía del camino en el 5-1 y en una Embestida del 5-2: ahora guarda sin esperar.
- *Pendientes* (en `08-pendientes.md`): los rótulos de las piezas del Mundo 5 (precios, carteles, Términos, cuentas, tachón, caja de Calc) se dibujan con la fuente por defecto de Godot, no con la del juego; en la arena el cuadro de texto va abajo (con un jefe sin vencer) y tapa el borde del suelo; la captura 20 de cada nivel sale con la línea de Calc a medio escribir (es la del bot, al llegar al hub).
