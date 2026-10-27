# 7. Mapa conceptual: Mundo 2, El Feed

Origen: sección 7 del documento original (`docs/original/diseno.md`).

**Rol en la historia:** Eco le robó el tiempo. Es el primer mundo donde se siente la pérdida de verdad, porque el propio nivel no se detiene.

**Idea del mundo:** un feed de videos infinito que avanza solo. Cada plataforma es una tarjeta con un video. Nadie decide quedarse, simplemente nunca hay un lugar donde parar.

## 7.1 Ambientación

- **Paleta:** violeta y magenta neón, con tarjetas de bordes redondeados. El Debug de este mundo es ámbar, para contrastar con los morados.
- **Música:** bucles de chiptune cortos que se aceleran, como un clip de 15 segundos que se repite. En el jefe se mezclan fragmentos de los bucles anteriores.
- **Humor:** textos como "Quedan 3 segundos para el siguiente video. No puedes cancelar" o "Solo uno más (llevas 400)". Los enemigos hablan en frases de contenido viral.
- **Lo oscuro:** el reloj del HUD salta horas de golpe cuando Isak se descuida. Algunos videos muestran momentos de su vida que él no recuerda haber vivido: cumpleaños, tardes con su familia, conversaciones con amigos.

## 7.2 Mecánica central: scroll forzado

- La cámara avanza sola, de forma vertical. Si Isak se queda atrás en el borde inferior, pierde Sync Rate.
- Las plataformas son tarjetas de video que entran y salen de pantalla.
- Un video se reproduce, y activa a su enemigo, cuando su tarjeta entra en pantalla (autoplay).
- Hay secciones en bucle: el nivel parece repetirse hasta que Isak encuentra el atajo, que solo se ve con el Debug.

## 7.3 Enemigos y elementos del mundo

| Elemento | Comportamiento | Cómo se resuelve |
|---|---|---|
| **Video en autoplay** | Se activa al entrar la tarjeta en pantalla. Lanza ataques que imitan su clip: olas, rayos, cuentas regresivas. | Pulso para aturdirlo y pasar rápido, o esquivar el ataque antes de que termine el clip. |
| **"Un video más"** | Clones que se multiplican si Isak tarda en pasar por una zona. | Avanzar sin detenerse. Con el golpe al suelo se eliminan todos a la vez. |
| **Tarjeta frágil** | Plataforma que se rompe poco después de pisarla. | Cruzarla rápido o romperla a propósito con el golpe al suelo para abrir un camino. |
| **Historia** | Plataforma efímera con un contador que corre muy rápido. | Saltar antes de que expire. |
| **Comentarista** | Escupe texto desde abajo del nivel y daña al contacto. | Mantenerse arriba o aturdirlo con el pulso. |

## 7.4 Nivel 2-1: Para ti

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Presentar el scroll forzado y el autoplay. Duración aproximada: 5 minutos. |
| **Dificultad** | 2 de 5. Más exigente que el tutorial, pero con margen. |
| **Tramo 1** | El scroll empieza lento. Plataformas anchas. El jugador entiende que no puede quedarse parado. |
| **Tramo 2** | Primer video en autoplay. Se activa al entrar la tarjeta, y el jugador aprende a anticiparlo. |
| **Tramo 3** | Primera sección en bucle: el nivel parece repetirse. Hay que usar el Debug para ver la salida, y el juego lo sugiere con una pista visual. |
| **Tramo 4** | Primeras tarjetas frágiles encadenadas y el primer "Un video más". |
| **Cierre** | La tarjeta final dice "Quedan 3 segundos para el siguiente video", y Isak entra en el siguiente nivel sin poder pararse. |
| **Secreto** | Una tarjeta oculta con un video en negro. Al revelarla con el Debug, aparece un recuerdo coleccionable. |
| **Punto de sincronización** | Uno a mitad de nivel. |

## 7.5 Nivel 2-2: Un video más

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Obtener el gesto de Mantener presionado y enseñar a gestionar el ritmo. Duración aproximada: 6 minutos. |
| **Dificultad** | 3 de 5. |
| **Inicio** | Isak encuentra un botón de pausa escondido dentro de un reproductor de video y obtiene el gesto Mantener presionado, el golpe al suelo. Eco comenta: "Mira cuánto tiempo ahorramos juntos." |
| **Tramo 1** | Enseña el golpe al suelo: tarjetas frágiles que bloquean el camino y se rompen para abrir pasos. |
| **Tramo 2** | Enjambre de "Un video más". Quedarse a pelear los multiplica, así que el golpe al suelo limpia la zona. |
| **Tramo 3** | Bucle más largo. El atajo exige combinar Debug y golpe al suelo. |
| **Tramo 4** | El scroll se acelera y los videos en autoplay se activan casi a la vez. |
| **Secreto** | Una zona bajo el nivel, accesible rompiendo una tarjeta específica, con puntos de atención extra y un recuerdo. |

## 7.6 Nivel 2-3: Scroll infinito

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Combinar todo lo aprendido y subir el ritmo. Duración aproximada: 7 minutos. |
| **Dificultad** | 4 de 5 dentro del mundo. |
| **Tramo 1** | El scroll cambia de velocidad. Hay tramos lentos y ráfagas rápidas. |
| **Tramo 2** | El scroll se invierte durante unos segundos y el nivel se recorre al revés. |
| **Tramo 3** | Plataformas tipo Historia con contador, mezcladas con tarjetas frágiles y videos en autoplay. |
| **Tramo 4** | Una pared de "Cargando más..." que no se abre con el pulso. Hay que forzarla con el golpe al suelo, mientras los clones se acumulan. |
| **Secreto** | Una ruta que solo se ve con el Debug y recorre el nivel por fuera del feed, entre tarjetas que no deberían existir. |

## 7.7 Jefe: Autoplay

Un reproductor de video gigante, con un botón de play por ojo. Reproduce clips que se convierten en sus ataques. Eco habla a través de él, ya más insistente.

| Aspecto | Detalle |
|---|---|
| **Arena** | Una pantalla gigante en el centro de un feed que sigue avanzando, aunque más despacio. |
| **Punto débil** | Un botón de pausa que solo se ve con el Debug Mode, en rojo. Hay que mantener presionado sobre él para pausar al jefe. |
| **Fase 1** | Reproduce clips que se vuelven ataques: olas, rayos y barridos. Isak aprende cada clip, lo esquiva y aprovecha el hueco para golpear. |
| **Fase 2** | Cuenta regresiva de "Siguiente video en 5". Si llega a cero sin que lo hayas pausado, el jefe recupera vida. Hay que llegar al botón antes del final. |
| **Fase 3** | Todo va al doble de velocidad. Isak necesita Debug para ralentizar y seguir el ritmo. |
| **Recompensa** | Fragmento de tiempo: un recuerdo largo de una tarde con su familia, una de las que Isak se perdió mientras miraba el feed. Eco dice: "Mira cuánto tiempo ahorramos." |

> **Recompensa (decisión del usuario, 2026-10-18):** recuerdo de jefe (tres capas), ver [propuesta-recuerdos.md](propuesta-recuerdos.md).

## 7.8 Estado del Mundo 2 (2026-10-23): diseño final implementado

Resumen de lo que hay en el juego. El detalle, los desvíos y cada decisión están en [propuesta-mundo-2.md](propuesta-mundo-2.md) (§8 y §8.1); lo que el usuario debe revisar al jugar, en [preguntas.md](preguntas.md) («Mundo 2: lo que el usuario debe revisar al probar»); lo pendiente, en [08-pendientes.md](08-pendientes.md).

**Flujo:** hub → carpeta del Mundo 2 (tras vencer a Alerta Mayor) → 2-1 «Para ti» → 2-2 «Un video más» (golpe al suelo) → 2-3 «Scroll infinito» → jefe «Autoplay» → pieza ámbar del hub y Mundo 3 «Próximamente». Todo jugable en Caché y recorrido por bots (`tools/play_feed_bot.gd --level 2-x`, `tools/play_boss_bot.gd --boss autoplay`).

**Decisiones tomadas (frente al mapa conceptual de arriba):**
- **Paleta B «Índigo frío y Debug miel»** (no violeta neón): `assets/palettes/mundo2.gpl`, Debug `#ffa858`; los puntos de atención llevan contorno de 1 px solo en este mundo.
- **Golpe al suelo = mantener `move_down`** (S / flecha abajo / stick abajo), sin tecla nueva; se obtiene en el reproductor del inicio del 2-2 (pulso de espaldas a su botón de pausa).
- **El borde del scroll nunca mata de golpe:** −10 de Sync, reaparición en la tarjeta segura más baja a la vista y 1 s de invulnerabilidad; techo de carga 2 tiles por encima de la vista.
- **Punto débil del jefe:** Debug → golpe al suelo sobre el cabezal (la «pausa») → láser a la pantalla; **un golpe por pausa** (`pause_hits` 1); sin Debug el golpe solo saca una chispa; el pulso no pausa.
- **Reloj del HUD** «17:04»: +1 h con cada contacto con el borde y cada repetición de un bucle (solo visual).
- Textos de Eco, ayudas Q, carteles y mensajes `msg_2_1`-`msg_2_3`: **propuestos** por el orquestador (revisar al jugar). Arte del jefe, del Comentarista y la pose del golpe al suelo: **provisional por script** hasta el paso 23 (AutoSprite, con permiso).

**Valores finales (ajustables jugando):**

| Pieza | Valores |
|---|---|
| Golpe al suelo | 0,12 s en el aire (anticipación 0,1 s, caída 960 px/s) o 0,35 s en el suelo; onda de 1,5 tiles que aturde y hace 1 de daño; pose 0,35 s; enfriamiento 0,4 s; gratis |
| Scroll | 2-1: 0,78 / 0,96 / 0,96 / 1,1 tiles/s (2026-10-26, segunda prueba del usuario: base +20 %, tramos acelerados +23 %; antes 0,65 / 0,78 / 0,78 / 0,9 y, en el diseño original, 0,5 / 0,6 / 0,7); camino del validador 134,2 s; 2-2: 0,5-0,9; 2-3: 0,4-0,8 con ráfagas de 1,2 e inversión; aviso de 9 cuadros a 12 fps |
| Tarjeta frágil / Historia | 0,6 s al pisarla, aviso 0,5 s, vuelve a los 3 s / 1,6 s encendida de cada 3,2 s |
| Video en autoplay | clip cada 2,5 s con miniatura de 0,75 s (ola, rayo o cuenta); pulso: pausa 3 s; pausado, el láser lo rompe (vida 2, +25 de energía) |
| «Un video más» | un clon cada 1,5 s con aviso de 0,75 s, tope 6, vida 1; un golpe al suelo en la zona los elimina |
| Comentarista / muro «Cargando más…» | bocadillo cada 2,5 s, vida 2 (pulso aturde, láser aturdido derrota) / 3 golpes al suelo |
| Niveles | 2-1 20 × 130 (dificultad 2, objetivo 300 s; bot 134,7 s desde el 2026-10-26); 2-2 20 × 156 (3, 360 s; bot 239 s); 2-3 20 × 170 (4, 420 s; bot 244 s); 3 secretos y un mensaje por nivel |
| Jefe Autoplay | arena 20 × 11 a pantalla completa; golpes por fase 4/4/4 (Caché) y 5/5/5 (Kernel, Raíz); pausa 4 / 3 / 2,5 s; cuenta 5 / 4 / 4 s; fase 3 a ×2; en la arena el Debug gasta ×0,25 y el mundo va a ×0,7; bot ideal 105 / 128 / 136 s, torpe 141 / 162 / 175 s, quieto pierde |

**Capturas y mapas:** mapas en `assets/levels_preview/2-1_mapa.png`, `2-2_mapa.png`, `2-3_mapa.png` y `2-boss_mapa.png` (`tools/render_level_map.py`); capturas de los momentos clave con el flujo real en `assets/levels_preview/2-1/`, `2-2/`, `2-3/` y `2-boss/` (`tools/render_level_2_x.gd`, con ventana).
