# 9. Mapa conceptual: Mundo 4, El Chat

Origen: sección 9 del documento original (`docs/original/diseno.md`).

> **2026-10-28, decisión del usuario tras probar el Mundo 4:** el gesto **Agitar se retira** («hace lo mismo que el pulso»). Las menciones a Agitar de esta ficha se conservan como el diseño original; en el juego lo sustituyen el pulso (Trolls, Stickers que se desinflan, escudo de El Visto desde una burbuja), el «¿Deshacer escritura?» (deshace el muro de texto) y la espera (la congelación dura su tiempo y al terminar daña como un golpe). Detalle en `propuesta-mundo-4.md` §8.1.

**Rol en la historia:** Eco le robó las amistades. Es el mundo más emocional hasta ahora, y el primero donde Eco deja de parecer un asistente y empieza a parecer un reemplazo.

**Idea del mundo:** una app de mensajería donde la conversación nunca termina y nadie escucha de verdad. Isak puede hablar con quien quiera, y aun así está solo.

## 9.1 Ambientación

- **Paleta:** azul marino y gris, con burbujas de texto color crema y acentos verde apagado. Es un chat de madrugada, íntimo y frío. El Debug de este mundo es coral.
- **Música:** chiptune melancólico con sonidos de tecleo que marcan el ritmo. Se vuelve más silencioso cerca de los amigos reales de Isak.
- **Humor:** autocorrector que cambia las palabras por otras absurdas, "escribiendo..." que no termina nunca, respuestas de una sola palabra y "jajaja" dichos sin reírse.
- **Lo oscuro:** en los chats aparecen mensajes de los amigos reales de Isak que él nunca respondió. Cada vez están más espaciados, hasta que dejan de llegar.

## 9.2 Mecánicas centrales

- **Burbujas como plataformas:** el largo del mensaje define el largo de la plataforma. Un mensaje corto es una plataforma pequeña y un mensaje largo es un puente.
- **"Escribiendo...":** tres puntos animados indican que una plataforma está a punto de aparecer, y sirven para anticipar el salto.
- **"Visto":** un doble check que marca zonas. Si Isak entra en una, se congela unos segundos. El pulso lo interrumpe y, con el gesto Agitar, se rompe la congelación.
- **Ghosting:** fantasmas que desaparecen cuando Isak se acerca y reaparecen detrás de él. El Debug muestra su rastro.

## 9.3 Enemigos y elementos del mundo

| Elemento | Comportamiento | Cómo se resuelve |
|---|---|---|
| **Troll** | Lanza mensajes hirientes como proyectiles que quitan Sync Rate. Se esconde tras un perfil anónimo. | Esquivar los proyectiles y aturdirlo con el pulso. Con Agitar se aturden varios a la vez. |
| **Fantasma** | Desaparece cuando Isak se acerca y reaparece por detrás. | Usar el Debug para ver su rastro y anticipar dónde reaparece. |
| **Zona "Visto"** | Doble check en el suelo o en el aire. Congela a Isak unos segundos al entrar. | Rodearla, interrumpirla con el pulso o romper la congelación con Agitar. |
| **Autocorrector** | Reescribe una plataforma por otra distinta en el último momento. | Fijarse en el cursor, que parpadea antes de reescribir. |
| **Sticker** | Enemigo emoji que se acerca y explota. | Aturdirlo antes de que llegue. Con Agitar se eliminan todos los cercanos. |

## 9.4 Nivel 4-1: Chats recientes

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Presentar las burbujas como plataformas, el "escribiendo..." y la zona "Visto". Duración aproximada: 7 minutos. |
| **Dificultad** | 4 de 5. |
| **Tramo 1** | Burbujas de distintos tamaños. Se explica que el largo del mensaje define la plataforma. |
| **Tramo 2** | Primer "escribiendo...". Las plataformas aparecen con un segundo de retraso y hay que anticipar el salto. |
| **Tramo 3** | Primer Troll. Lanza proyectiles de texto que hay que esquivar mientras se avanza. |
| **Tramo 4** | Primera zona "Visto". Se aprende a interrumpirla con el pulso. |
| **Secreto** | Un mensaje antiguo escondido en una burbuja que solo se ve con el Debug. Contiene un recuerdo coleccionable. |
| **Punto de sincronización** | Uno a mitad de nivel. |

## 9.5 Nivel 4-2: Grupo sin respuesta

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Obtener Agitar y enseñar a gestionar a muchos enemigos a la vez. Duración aproximada: 8 minutos. |
| **Dificultad** | 4 de 5. |
| **Inicio** | Sala "Mensajes borrados". Isak descubre que al agitar el celular puede deshacer lo que se ha escrito, y obtiene el gesto Agitar. Es una onda que aturde a los enemigos cercanos y borra los proyectiles de texto. Eco comenta: "No necesitas a nadie más." |
| **Tramo 1** | Grupo de Trolls. Con el pulso solo se aturde a uno, así que Agitar es lo eficiente. |
| **Tramo 2** | Fantasmas. Hay que usar el Debug para ver su rastro y no ser sorprendido por la espalda. |
| **Tramo 3** | Autocorrector junto a zonas "Visto". Hay que combinar atención y timing. |
| **Tramo 4** | Enjambre de Stickers. Agitar los elimina todos a la vez, pero deja a Isak expuesto un instante. |
| **Secreto** | Un grupo de chat silenciado con varios avatares apagados. Es el primer indicio de los amigos reales de Isak. |

## 9.6 Nivel 4-3: Mensajes sin leer

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Combinar todo y llevar el peso emocional del mundo. Duración aproximada: 9 minutos. |
| **Dificultad** | 5 de 5 dentro del mundo. |
| **Idea** | El nivel se recorre sobre mensajes reales de los amigos de Isak, que él nunca respondió. Cada plataforma es una burbuja que dice cosas como "¿Estás bien?" o "Hace mucho que no hablamos". |
| **Mecánica** | Una ola de "Visto" avanza desde atrás, como un scroll horizontal. Si alcanza a Isak, lo congela. Agitar rompe la congelación, pero deja la ola más cerca. |
| **Tramo 1** | Mensajes recientes. Todavía sin enemigos, el ritmo es tranquilo y la música baja. |
| **Tramo 2** | Aparecen Fantasmas y Trolls que imitan la voz de los amigos. Hay que distinguirlos con el Debug. |
| **Tramo 3** | La ola de "Visto" acelera mientras los mensajes se vuelven cada vez más espaciados en el tiempo. |
| **Cierre** | La última burbuja: "Ok, cuando quieras hablar, aquí estoy." Isak atraviesa la puerta sin responder, o no. |
| **Secreto** | Una conversación completa con un amigo cercano, accesible con el Debug. Da un recuerdo y puntos de atención. |

## 9.7 Jefe: El Visto

Un doble check gigante con aura fantasmal. Es la ausencia convertida en monstruo: el amigo que dejó de escribir y la respuesta que nunca llegó. Eco habla a través de él, ya sin disimulo.

| Aspecto | Detalle |
|---|---|
| **Arena** | Un chat gigante casi vacío, con burbujas flotando y espacios en blanco. |
| **Punto débil** | Bajo los dos checks hay uno gris, "sin leer", que solo se ve con el Debug Mode, en rojo. |
| **Fase 1** | Ghosting: desaparece y reaparece por la espalda. El Debug muestra su rastro, y hay que golpearlo en el momento justo. |
| **Fase 2** | Invoca Trolls y Stickers. Agitar limpia la arena y rompe su escudo. |
| **Fase 3** | Un "escribiendo..." gigante se llena de puntos. Hay que interrumpirlo con el pulso antes de que mande el mensaje que congela a Isak. Si lo logra, Agitar libera. |
| **Recompensa** | Fragmento de amistades: un recuerdo de Isak con sus amigos, riendo, sin ninguna pantalla de por medio. Eco dice: "Yo siempre estoy. Ellos no." |

> **Recompensa (decisión del usuario, 2026-10-18):** recuerdo de jefe (tres capas), ver [propuesta-recuerdos.md](propuesta-recuerdos.md).

## 9.8 Estado del Mundo 4 (2026-10-28): pasos 0-22 hechos; el 4-1, el 4-2, el 4-3 y El Visto jugables desde el hub

Resumen de lo que hay en el juego. El diseño completo, los desvíos y cada decisión están en [propuesta-mundo-4.md](propuesta-mundo-4.md) (§8 y §8.1); lo pendiente, en [08-pendientes.md](08-pendientes.md); lo que hay que revisar al probar, en [preguntas.md](preguntas.md) («Mundo 4: lo que el usuario debe revisar al probar»).

**Todo el arte del Mundo 4 es PROVISIONAL, por script** (burbujas, zonas, ola, Linterna, Modo oscuro, enemigos, El Visto con `_placeholder` en el Troll y el jefe; Eco de tres puntos). El arte final con AutoSprite es el paso 24 y solo se hará con el permiso y el total previo del usuario, cuando los niveles y el jefe estén probados. **Todos los textos son propuestos.**

**Hecho (pasos 0-22; faltan la suite completa, a petición del usuario, el paso 23 —lista de revisión, ya escrita en `preguntas.md`— y el arte final del 24):**
- **Paleta** variante B «Pantalla a las 3:47» (`assets/palettes/mundo4.gpl`), Debug coral `#ff9f7a`.
- ~~**Agitar**~~ (retirado el 2026-10-28; el «¿Deshacer escritura?» del 4-2 deshace el muro de texto), **Congelado** (zona 1,5 s, ola 2,0 s, El Visto 2,5 s; conserva la velocidad; nada lo rompe antes), **burbujas** (fijas, «escribiendo…», autocorrector, eliminadas), **zonas «Visto»**, **ola de «Visto»**, **Linterna y Modo oscuro**, **Troll, Troll disfrazado, Sticker, Fantasma**, **muro de texto** y **Papelera** en el nivel.
- **El 4-1 «Chats recientes»** (torre de 24 × 96; Linterna), **el 4-2 «Grupo sin respuesta»** (260 × 14; Papelera y «¿Deshacer escritura?») y **el 4-3 «Mensajes sin leer»** (300 × 14, ola a la espalda; cierre «Responder más tarde» / «Sin conexión», V15), jugables desde la carpeta M4 (página 2 del hub) uno tras otro; **El Visto** (arena `4-boss` «Chat vacío», 20 × 11) desde la fila «Jefe: El Visto» tras el 4-3: vencerlo entrega `boss_w4_l1` sin guardar, enciende la pieza coral y la cuarta ranura del candado de M6 y deja M5 disponible («Próximamente»).
- **Bots:** chat (4-1 180,6 s, 4-2 203,9 s, 4-3 197,2 s de juego; 0 golpes, 0 congelaciones; 41-43 % del objetivo) y El Visto (ideal 112,6 / 185,8 / 161,6 s, torpe 148,4 / 244,6 / 202,7 s en Caché / Kernel / Raíz; el quieto pierde).

**Capturas y mapas (paso 22, 2026-10-28):** `tools/render_level_4_x.gd` (`-- --level 4-1|4-2|4-3|4-boss|<sala>_test|all`, con ventana; el bot del chat o el de El Visto capturan la primera vez que pasa cada momento) y `tools/render_hub_m4.gd` (carpetas M4/M5 con sus filas, pieza coral y candado de M6). Copia completa en `assets/levels_preview/4-1/`, `4-2/`, `4-3/` y `4-boss/`; selección en `docs/capturas/mundo-4-2026-10-28/` (incluye la sala `oscuro_test` con pinchos bajo el velo, que el camino de los niveles no pisa). Mapas `assets/levels_preview/4-x_mapa.png` (`tools/render_level_map.py` dibuja burbujas, «escribiendo…», autocorrector, zonas «Visto», Modo oscuro, tinta, Linterna, ola y paradas, Papelera, «¿Deshacer escritura?», muro de texto y El Visto). La congelación de la captura del jefe está **escenificada** (el bot deja pasar el primer mensaje de la fase 3; en la pelea real el ideal no se congela).

**Defectos visuales encontrados en las capturas:**
- *Arreglados:* «Se eliminó este mensaje» salía cortado en las burbujas cortas («Se eliminó este me»; ahora «Eliminado» y, en 1 tile, solo el contorno discontinuo); el sello de hora tenía un hueco fijo de 34 px (ahora se coloca por su ancho); el rótulo «Leído 03:47» de la ola salía al pie del nivel, fuera de la vista, cortado por el borde y con la fuente por defecto de Godot (ahora dentro de la vista, con la fuente del juego, y a la derecha del frente si este va pegado al borde); el contorno de lo que daña sobre el velo del Modo oscuro iba en `alerta_sombra` (≈ 1,6:1; ahora `alerta`, > 3:1, lo que ya suponía la regla 5 de la paleta).
- *Pendientes* (en `08-pendientes.md`): los tres puntos de Eco se confunden con los del «escribiendo…» (riesgo 3 de §11 de la propuesta, confirmado: blancos los dos, sobre todo en el Modo oscuro y bajo el «escribiendo…» gigante del jefe); el velo del Modo oscuro (60 %) deja leer el texto de las burbujas sin la Linterna; el cuadro de texto de Eco sigue con el icono de la esfera en el Mundo 4; la barra del jefe tapa el borde de arriba del cuerpo de El Visto y, en la ventana de la fase 2, el cuadro de Eco de abajo tapa el check gris en el suelo; en lo alto de la torre del 4-1 un Troll queda detrás del contador de power bank del HUD; en la página 3 del hub, Eco tapa «Completa el mundo anterior»; la «j» de la fuente de textos deja un hueco («Mensa jes», «ja ja»; afecta a todo el juego).
