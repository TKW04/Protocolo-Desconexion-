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
