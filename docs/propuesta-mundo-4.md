# Propuesta: Mundo 4 «El Chat» (4-1, 4-2, 4-3 y jefe El Visto)

**Estado:** **PROPUESTA (2026-10-27), en implementación desde el 2026-10-28 (pasos hechos en §8.1).** Las decisiones de diseño que no son de gusto personal las toma el orquestador con la autoridad que el usuario delegó en los Mundos 2 y 3 (§9, cada una marcada «Decisión tomada»). Las **cuatro decisiones del usuario** (§10: el **coral** del Debug, **V15**, los **amigos** como remitentes y el **arte de AutoSprite**) están **tomadas por el usuario el 2026-10-28** (coral B `#ff9f7a`; sin elección en Caché y respuesta en Raíz; Lía, Marco y Tomi; placeholders por script y AutoSprite solo al final, sin gastar créditos ahora). Desarrolla `mundo-4-chat.md` sin contradecirlo. Lo que no viene de los docs va marcado **PROPUESTA**. Los valores son orientativos y se ajustan jugando y con el validador. **Todos los textos (Eco, Papelera, carteles, Trolls, El Visto, mensajes de los amigos) son borradores marcados «propuesto»**, revisables al jugar. Como en los Mundos 2 y 3, este documento cubre **solo Caché**; Kernel y Raíz salen solo en el jefe y a alto nivel.

**Fuentes:** `mundo-4-chat.md` (ficha original), `01-ficha-reglas.md` §5 (Mundo 4: Amistades, Agitar, «el visto te congela»), `02-isak-habilidades.md` §3.5 (Agitar: «onda que aturde a todos los enemigos cercanos»), `04-personajes.md` §12.1 (Eco en el Mundo 4: «tres puntos de escribiendo…, sin cuerpo»), §12.3 (Linterna y Papelera) y §12.4 (Lía, Marco y Tomi), `05-hub.md` §13.2 y §13.4, `07-estilo-visual.md` §15.3 y §15.5, `08-pendientes.md` (V15), `preguntas.md` (V15; dudas 2 y 3 de los asistentes), `propuesta-asistentes-y-vidas.md` §2.4-§2.5, `propuesta-recuerdos.md` §11.2 (capas `boss_w4_l1`-`l3` ya escritas), `propuesta-hub-mundos-4-6.md` (carpeta M4 en la página 2, pieza coral provisional, M5 con `4-boss`), `propuesta-mundo-2.md` y `propuesta-mundo-3.md` (plantillas de este documento), `lista-sonidos.md` (IDs `*_w4_*`), `CLAUDE.md` y los datos actuales (`project.godot`, `scripts/autoload/game_state.gd`, `data/hub.json`, `data/memories.json`, `tools/gen_hub_update_art.py`).

**Física de referencia** (datos actuales; la misma de `propuesta-mundo-3.md`): andar 220 px/s (3,4 tiles/s), correr 360 px/s; salto de unos 184 px (subidas cómodas de 2 tiles), cumbre a 0,4 s. Caja de Isak 32 × 80 px (comprimido 32 × 40). Pulso gratis, radio 96 px, solo en el suelo, pose 0,33 s. Láser 10 de energía, 768 px, horizontal, solo en el suelo. Debug: mantener 1 s, 20/s reales, mundo ×0,5. Dash 192 px en 0,2 s, invulnerable 0,3 s, 10 de energía. Golpe al suelo gratis. Pellizcar gratis (sin pulso ni láser comprimido). Golpe recibido −10 de Sync e invulnerabilidad 1 s. Energía 100 (110-130 con mejoras). Pantalla de **20 × 11,25 tiles**.

**Lo que ya existe y este mundo aprovecha:** la acción **`gesture_shake`** ya está en el Input Map (**U / LB**), la habilidad **`shockwave`** (`GameState.ABILITY_SHOCKWAVE`) y los aliados **`linterna`** y **`papelera`** (`GameState.ALLY_*`) ya existen como constantes; la carpeta **M4** ya está en la página 2 del hub (columna 4, `unlocked_by: ["3-boss"]`, `requires_upgrade`, `levels: []`); los textos de las tres capas del recuerdo **«Fragmento de amistades»** ya están en `data/memories.json`; el candado de La Nube ya cuenta la ranura `boss_w4_l1`.

---

## 0. Resumen

- **El mundo:** una app de mensajería de madrugada donde la conversación no termina y nadie escucha. Eco le robó a Isak las **amistades** y aquí deja de parecer un asistente para parecer un **reemplazo**. La **mecánica central nueva** es que **la conversación es el terreno y esperar respuesta cuesta**: las **burbujas de mensaje son las plataformas** (el largo del mensaje = el largo de la plataforma), el **«escribiendo…»** avisa de una plataforma que va a aparecer (hay que **anticipar** el salto) y el **«Visto»** **congela** a Isak (el precio de que te lean y no te contesten). Ni prisa por temporizador (Mundo 1), ni scroll forzado salvo en el 4-3 (Mundo 2), ni cifras que sostienen el suelo (Mundo 3): aquí el reto es **de timing y de lectura del ritmo de una conversación**.
- **Gesto del mundo:** **Agitar** (habilidad `shockwave`; acción `gesture_shake`, **U / LB**, ya asignada): onda de 2,5 tiles que **aturde a todos los enemigos cercanos**, **borra los proyectiles de texto** y **rompe la congelación**. Cuesta 10 de energía y deja a Isak **expuesto 0,25 s**. Se obtiene al principio del 4-2, en la sala «Mensajes borrados», donde **habla por primera vez la Papelera**.
- **Linterna (aliada):** se encuentra **al entrar en el 4-1** (el Mundo 4 es el «mundo oscuro», recomendación vigente de la duda 2 de los asistentes). Ilumina las **zonas «Modo oscuro»** y revela lo escrito «en tinta» que solo se ve con luz. Su hueco del dock del hub (columna 13) se enciende.
- **Niveles:** 4-1 «Chats recientes» (**torre vertical** de 24 × 96: se sube por el hilo de la conversación; burbujas, «escribiendo…», Troll y zonas «Visto»), 4-2 «Grupo sin respuesta» (horizontal 260 × 14: Agitar, grupos de Trolls, Fantasmas, Autocorrector y Stickers) y 4-3 «Mensajes sin leer» (horizontal 300 × 14 con la **ola de «Visto»** que avanza desde atrás; los mensajes reales de Lía, Marco y Tomi, cada vez más espaciados).
- **Jefe El Visto:** doble check gigante con aura fantasmal. Daño = **Debug revela el check gris «sin leer» → pulso que marca → láser** (la regla de Alerta Mayor y de la Curadora), con el giro de cada fase: (1) **ghosting**: reaparece a la espalda de Isak, a tiro de pulso; (2) **invoca Trolls y Stickers** y se escuda: **Agitar** limpia la arena y rompe el escudo; (3) un **«escribiendo…» gigante**: el **pulso lo interrumpe** (el silencio, la debilidad de Eco que cuenta la Papelera) antes de que mande el mensaje que congela; si lo manda, Agitar libera. Arena 20 × 11, cámara fija. 9 golpes en Caché.
- **Arte:** casi todo por script (familia de formas: **burbujas de texto**, `07` §15.5). **Decisión del usuario (2026-10-28):** El Visto, el Troll y la pose de Agitar se hacen como **placeholders por script** mientras se construyen los niveles y el jefe; el arte final con AutoSprite (estimado en **68-71 créditos** en una pasada, hasta ~142 con reintentos, de un saldo de **315**) se hace **después**, con los 3 niveles y las mecánicas del jefe terminados, y **no se gasta ningún crédito hasta entonces** (paso 24).
- **Tamaño:** **25 pasos** (§8). ≈ **65-75 %** del esfuerzo del Mundo 1: dos estados nuevos de Isak (Agitar y congelado), una aliada con luz, una amenaza móvil horizontal (la ola) y seis tipos nuevos, casi todos sobre piezas existentes.

---

## 1. Qué está decidido y qué es propuesta

| Tema | Decidido en los docs | PROPUESTA / decisión tomada en este documento |
|---|---|---|
| Tema | Eco robó las **amistades**; mundo más emocional; Eco empieza a parecer un **reemplazo** (`mundo-4` §9). | La espera como coste (congelarse, anticipar, la ola) y los huecos cada vez más grandes del 4-3 = el tiempo entre mensajes (§2). |
| Paleta | Azul marino y gris, burbujas **crema**, acento **verde apagado**, Debug **coral** (`mundo-4` §9.1, `07` §15.3). | Reglas de contraste (coral frente al rojo de daño, crema frente a los puntos ámbar, cian de Eco sobre marino) y **3 opciones de coral** para el usuario (§6.1). |
| Música | Chiptune melancólico con tecleo como ritmo; más silencioso cerca de los amigos reales. | Capa de tecleo que es también señal de accesibilidad; «silencio» como parámetro de la mezcla cerca de las burbujas de amigos (§6.4). |
| Humor y lo oscuro | Autocorrector absurdo, «escribiendo…» eterno, respuestas de una palabra, «jajaja» sin reírse; mensajes de los amigos sin responder, cada vez más espaciados. | Carteles y textos propuestos (§2.2); la distancia física entre burbujas del 4-3 sigue a la distancia temporal (§4.3). |
| Mecánicas | Burbujas = plataformas por largo; «escribiendo…» anticipa; «Visto» congela (pulso lo interrumpe, Agitar rompe la congelación); ghosting con rastro en el Debug. | Valores y reglas (§3.1-§3.6); estado **Congelado** de Isak; ola de «Visto» como amenaza móvil horizontal (§3.5). |
| Enemigos | Troll, Fantasma, zona «Visto», Autocorrector y Sticker (`mundo-4` §9.3). | Parámetros, reglas y qué se reutiliza (§3.7); Troll que imita a un amigo (4-3) y muro de texto (4-2). |
| Gesto | **Agitar** en el 4-2, sala «Mensajes borrados»: deshace lo escrito; onda que aturde y borra proyectiles; Eco: **«No necesitas a nadie más.»** | Valores, reglas y control (§3.2); la obtención con la Papelera (§4.2). |
| Aliados | **Linterna** «aparece sobre todo en el Mundo 4»; **Papelera** «aparece en la sala "Mensajes borrados" del 4-2… conoce su debilidad: el silencio» (`04` §12.3). | **Decisión tomada:** Linterna en el 4-1 (duda 2 de los asistentes) y Papelera que habla por primera vez en el 4-2 (duda 3, con su recomendación) (§3.6, §4.2). |
| Niveles | Objetivo, dificultad (4, 4, 5), duración (7, 8 y 9 min), tramos, cierre y secretos (`mundo-4` §9.4-§9.6). | Forma (torre en el 4-1), tamaños, columnas, economía, secretos B y C (§4). |
| Cierre del 4-3 | «Isak atraviesa la puerta sin responder, o no» (V15, **aplazado** hasta el Mundo 4). | **Decisión del usuario tomada** (§10.2, 2026-10-28): en Caché no hay elección («Sin conexión», Isak sale sin responder); la respuesta llega en Raíz, ligada al epílogo. |
| Jefe | El Visto: doble check gigante, aura fantasmal; punto débil gris «sin leer» solo con el Debug, en rojo; fases 1-3; recompensa «Fragmento de amistades»; Eco: «Yo siempre estoy. Ellos no.» | Daño (marca), arena, ataques, energía y Kernel / Raíz (§5). |
| Recuerdo de jefe | Capas `boss_w4_l1`-`l3` ya escritas (el garaje, la cadena de la bici, el grupo silenciado) e ilustración por script (`memory_art_w4`). | Entrega igual que en los Mundos 1-3 (§5.9). |
| Mensajes de secretos | **3 por mundo en Caché**; reaparecen en Kernel y Raíz si no se obtienen; requisito del final real. «Familiares y amigos». | **Remitentes: los amigos** (Tomi, Marco, Lía) en lugar de Mamá: **decisión del usuario tomada** (§10.3, 2026-10-28); borradores en §4.5. |
| Hub | Carpeta M4 en la página 2 (columna 4); **cuarta pieza en coral** al completar el mundo; M5 se desbloquea con `4-boss`. | Filas del panel, `available_text`, miniatura, línea de Calc, hueco de Linterna (§4.6). |
| Vidas, power banks, puntos | Vida extra cada 3 mapas (1-1, 2-1, 3-1): **la siguiente va en el 4-1**. ≈ 9 puntos por mapa. Al menos un power bank por mundo y vuelta. | Dónde va cada cosa (§4). |
| Eco | «Tres puntos de "escribiendo…", sin cuerpo» (`04` §12.1). | Variante de la esfera compañera del Mundo 4 y cómo no se confunde con las burbujas «escribiendo…» (§6.3). |

---

## 2. Tema y tono

### 2.1 Idea

Una app de chat a las tres de la madrugada. Isak avanza **sobre los mensajes**: una respuesta corta es un saliente, un mensaje largo es un puente, un «jajaja» es casi nada. Cuando alguien escribe, aparecen tres puntos y, un segundo después, la burbuja: **el salto se da antes de que exista el suelo**, porque en un chat siempre se contesta a algo que todavía no ha llegado. El «Visto» es el doble check que congela: **te leyeron y no pasa nada**. El gesto del mundo, **Agitar**, se obtiene «deshaciendo lo escrito»: es la primera habilidad que **aparta a todos a la vez**, y Eco la celebra con «No necesitas a nadie más.». En el 4-3 el chat ya no es de desconocidos: son **Lía, Marco y Tomi**, con mensajes que Isak nunca contestó, y **los huecos entre burbujas crecen como crece el tiempo entre mensajes** hasta que dejan de llegar.

### 2.2 Tono

- **Superficie (humor), PROPUESTA de estilo (textos revisables):** carteles con la voz de una app de mensajería inventada (sin marcas): «En línea hace 3 h», «Silenciado por 8 horas», «Se eliminó este mensaje», «Archivado», «escribiendo…» que dura demasiado. Autocorrector: «voy para allá» → «voy para Alaska», «ahorita te llamo» → «ahorita te llamo mañana», «te extraño» → «te extraigo». Trolls con mensajes de una palabra: «ok.», «¿y?», «jajaja», «nadie preguntó», «visto». Nada hiriente de verdad: el daño es la indiferencia, no el insulto.
- **Fondo (lo oscuro):** el fondo del nivel es la **lista de chats** en paralaje, con avatares apagados y contadores de no leídos que suben solos. En el 4-3, la música baja y el tecleo se espacia cerca de las burbujas de los amigos; los sellos de hora pasan de «hace 2 días» a «hace 3 meses».
- **Eco:** sin cuerpo: **tres puntos que laten** (`04` §12.1). Habla poco y suave, como alguien que siempre contesta al instante. Su frase del mundo, **«No necesitas a nadie más.»**, al obtener Agitar (decidida, `mundo-4` §9.5); la del recuerdo, «Yo siempre estoy. Ellos no.», en la recompensa. En el jefe, **sin disimulo** (`mundo-4` §9.7).
- **Papelera:** melancólica y cálida (`04` §12.3). Habla por primera vez en el 4-2, en voz baja, con frases cortas.
- **Linterna:** casi no habla: **parpadea** (un destello = sí, dos = mira aquí). Sin líneas de texto propias.

### 2.3 El 4-3 no es un nivel de enemigos (PROPUESTA de presentación)

- El Tramo 1 del 4-3 no tiene enemigos (doc). La presión es solo la ola y el ritmo es tranquilo: el jugador **lee** las burbujas mientras salta sobre ellas.
- Las burbujas de los amigos **no se pueden romper ni dañan**; los Trolls que imitan a los amigos sí, y el Debug los distingue (§3.7). **Las ayudas nunca mienten:** la Q de una burbuja falsa la llama Troll.
- **Sin HUD nuevo.** El reloj del HUD sigue visible (desde el Mundo 2), sin saltos.

---

## 3. Mecánicas

### 3.1 Burbujas como plataformas (`chat_bubble`)

| Regla | Valor propuesto | Por qué |
|---|---|---|
| Qué es | Plataforma **de una vía** con un texto (`text`) y su autor (`side`: `left` = otros, `right` = Isak) y la cola del bocadillo hacia su lado. | El doc. Las de una vía dejan subir en zigzag como en un chat. |
| Largo | **1 tile por cada 6 caracteres** (redondeo hacia arriba), mínimo 1, máximo 8. Lo calcula `tools/build_level.py` desde `text`; el esquema rechaza un `width` que no cuadre. | «El largo del mensaje define el largo de la plataforma.» Regla legible: el jugador aprende a «medir» leyendo. |
| Texto | Fuente de textos del juego, sobre crema, con sello de hora pequeño; **solo glifos de la fuente** (como `memories.json`). | Legibilidad y validación sin sorpresas. |
| Burbuja de amigo (4-3) | `chat_bubble` con `friend: "lia" | "marco" | "tomi"`: avatar con inicial. No se rompe, no daña. | Lo que el jugador debe proteger es la lectura, no la plataforma. |
| «Se eliminó este mensaje» (`deleted: true`) | Contorno discontinuo sin colisión (el aspecto de la plataforma apagada del 1-3). | Decorado legible y reutilizado. |

### 3.2 Agitar (gesto, habilidad `shockwave`)

#### 3.2.1 Valores iniciales (PROPUESTA; sección `shockwave` de `data/isak_abilities.json`)

| Parámetro | Valor | Por qué |
|---|---|---|
| Control | **Pulsar `gesture_shake`** (U / LB; ya en el Input Map, reasignable en Ajustes > Controles) | No se toca `project.godot` ni el mando. |
| Onda | Radio **160 px** (2,5 tiles) alrededor del celular; sale en **0,15 s** (anticipación: Isak sacude el celular 3 cuadros) | Mayor que el pulso (96 px): «a todos los cercanos». |
| Efecto | **Aturde 3 s** a todos los enemigos dentro (el Sticker aturdido se desinfla y desaparece), **borra los proyectiles de texto** dentro y **rompe la congelación** de Isak. **0 de daño.** | El doc: aturde, deshace lo escrito y libera. Sin daño para que el láser siga siendo lo que elimina. |
| Coste | **10 de energía** | Distinto del pulso (gratis, uno a uno): limpiar a muchos de golpe tiene precio. Mismo coste que el dash y el láser. |
| Exposición | Tras la onda, **0,25 s** sin moverse ni saltar (pose total **0,4 s**); sin invulnerabilidad | «Deja a Isak expuesto un instante» (doc, Tramo 4 del 4-2). |
| Enfriamiento | **1,0 s** desde el final de la pose | Evita encadenarlo como escudo. |
| Dónde | **Solo en el suelo**, como el pulso y el láser; **excepción: congelado**, en cualquier sitio (también en el aire) | Coherencia con el kit; la excepción es la que lo hace útil contra el «Visto». |
| Con el Debug | **Sí** | Se combina con lo que se ve con el Debug (Fantasmas). |
| No sale | Sin la habilidad, en el hub, en Hurt, muerto, de espaldas, en un vórtice, comprimido, durante el dash, el golpe al suelo, el pulso o el láser; sin energía (chispa gris del láser y `EventBus.shockwave_denied`) | Mismas reglas que los otros gestos. |
| Ocultarte | **Lo apaga** | Agitar es lo contrario de esconderse. |
| Tienda | Sin pista propia | Como los otros gestos: progresan con las combinaciones del Mundo 5 (Sismo = golpe al suelo con onda). |
| Tiempo | De Isak: tiempo real | Como los demás gestos. |

#### 3.2.2 Aviso y obtención

Aviso «Agitar: U / LB (mando)» (entrada `shockwave` de `data/ability_notices.json`, una vez por partida guardada) y fila **Agitar** en Ajustes > Controles (tras Pellizcar). Se obtiene con el objeto **«¿Deshacer escritura?»** del 4-2 (§3.7, §4.2). Guardado, Papelera y rollback como el dash (`unless_ability`).

### 3.3 Congelado (estado nuevo de Isak, `Frozen`)

| Regla | Valor | Por qué |
|---|---|---|
| Qué pasa | Isak queda **quieto donde está** (también en el aire), con su velocidad **guardada**, un velo gris con el doble check sobre la cabeza y una barra de 4 segmentos que se vacía. Al terminar, **sigue con la velocidad que llevaba**. | «Te congela unos segundos» (doc). Conservar la velocidad hace que congelarse en un salto cueste **tiempo** y no una caída. |
| Duración | Zona «Visto»: **1,5 s**; ola de «Visto»: **2,0 s**; mensaje de El Visto: **2,5 s** (tiempo del mundo) | De menos a más, como la ficha. |
| Salir antes | **Agitar** (§3.2) rompe la congelación al instante (10 de energía). Sin Agitar (4-1) se espera. | El doc. |
| Daño | Congelarse **no hace daño**. Congelado **sí se recibe daño**. **Regla de diseño (la exige el validador):** en el 4-1 (sin Agitar) ningún peligro alcanza a Isak congelado; desde el 4-2, sí puede, porque Agitar libera. | Justo antes del gesto; con el gesto, la congelación pasa a ser una decisión (gastar 10 o esperar). |
| Invulnerabilidad | 0,5 s tras descongelarse, solo frente a otra zona «Visto» | Evita cadenas de congelación. |
| Con el Debug | El Debug ralentiza la cuenta (tiempo del mundo) pero no la rompe | La congelación es del mundo. |

### 3.4 «Escribiendo…» y Autocorrector (`typing_bubble`, `autocorrect_bubble`)

- **`typing_bubble`:** al dispararse (`trigger`: Isak pisa la burbuja anterior o entra en una zona) aparecen **tres puntos** en su sitio, uno cada 0,33 s, y al tercero (**1,0 s**, doc) **la burbuja aparece sólida**. Los puntos son el aviso (9 cuadros de cada punto a 12 fps) y `sfx_w4_typing` lo acompaña (accesibilidad). Variantes: `stay: "forever"` (por defecto) o `cycle_s` (aparece, se queda `on_s`, pasa a «Se eliminó este mensaje» con aviso de 9 cuadros y vuelve a escribirse). **No se materializa con Isak dentro.** Reutiliza **`BlinkPlatform`** (ciclo, aviso y no materializarse) y la plataforma oculta `h` (sólida desde un instante).
- **Anticipar el salto:** el patrón del mundo es saltar **cuando sale el segundo punto** para caer sobre la burbuja recién aparecida. El validador lo modela como una plataforma sólida desde `t0 + 1,0 s` (paso `wait_typing` en el camino exportado).
- **`autocorrect_bubble`:** una burbuja con dos textos (`text` y `corrected`); al acercarse Isak a ≤ `trigger_tiles` (por defecto 3) o al pisarla, **el cursor parpadea 0,75 s** (9 cuadros a 12 fps, doc: «fijarse en el cursor») y el texto cambia: **la plataforma cambia de largo** (regla de §3.1) y a veces de sitio dentro de su ranura. Una sola vez por intento; vuelve al estado inicial al reaparecer.
- **Justo y legible (regla del validador):** **el autocorrector engaña, no mata**: lo que deja al descubierto da como mucho a una caída de 3 tiles con salida, nunca a un pozo mortal; y siempre se ve el texto «antes» y el cursor.

### 3.5 «Visto»: zonas y ola (`seen_zone`, `seen_wave`)

- **Zona «Visto» (`seen_zone`):** rectángulo de 1-4 × 1-3 tiles, en el suelo o en el aire, marcado con un **doble check** en su borde. Estados: **en espera** (checks en contorno gris), **activa** (checks rellenos en el verde apagado del mundo; tocarla congela 1,5 s) e **interrumpida** (checks tachados, 4 s del mundo). Puede estar siempre activa o seguir un ciclo (`on_s` / `off_s`, con aviso de 9 cuadros: los checks se rellenan de uno en uno). **El pulso al doble check** (a ≤ 96 px; el icono está en el borde, para pulsar desde fuera) **la interrumpe** (doc). **Rojo nunca:** la zona no hace daño.
- **Ola de «Visto» (`seen_wave`, 4-3):** un frente vertical de toda la altura que avanza **desde la izquierda** en tiempo del mundo (el Debug la frena) y deja detrás el nivel en gris con «Leído 03:47». Velocidad por tramo en `wave.sections` (`speed_tiles_s`, de **1,0 a 1,6 tiles/s**; andar es 3,4); **paradas** en los puntos de sincronización y en el secreto A (se para hasta que Isak sale de la parada, como las paradas del scroll del Mundo 2). Aviso: un borde con checks que laten y `sfx_w4_seen_wave` cada vez más fuerte al acercarse (accesibilidad).
- **Si la ola alcanza a Isak:** −10 de Sync **sin matar** (la regla del borde del scroll del Mundo 2) y **congelado 2,0 s**. Al descongelarse **solo**, la ola **retrocede 4 tiles** («ya te leyó»). **Agitar** rompe la congelación al instante, pero **la ola se queda a 1 tile** (doc: «Agitar rompe la congelación, pero deja la ola más cerca»). Es una decisión: tiempo contra distancia.
- **Muerte en el 4-3:** la ola vuelve a la parada de su sección, como el scroll del Mundo 2.
- **Reutiliza:** el modelo del scroll como amenaza que se mueve (`tools/scroll_model.py`, ahora en X) y `ScrollEdgeOverlay` para el borde; **sin cámara nueva** (la cámara del 1-1 sigue a Isak).

### 3.6 Linterna y zonas oscuras (`flashlight_pickup`, `dark_zone`)

- **Linterna:** se encuentra **al entrar en el 4-1** (`propuesta-asistentes-y-vidas.md` §2.4: «al entrar en el X-1 de un mundo oscuro»): un objeto en la sala de llegada que se recoge al tocarlo. Queda **conocida** (`GameState.meet_ally("linterna")`, aliada de registro como Calc: **un game over no la quita**). Desde entonces es una lucecita que sigue a Isak (debajo de Eco, sin colisión) y **solo se enciende en zonas oscuras**. En el hub, su hueco del dock (**columna 13**) se enciende (sin panel, `05` §13.3).
- **Zona oscura (`dark_zone`, «Modo oscuro»):** rectángulo del nivel con un velo casi negro; la Linterna abre un círculo de luz de **3 tiles de radio** alrededor de Isak. **Regla de legibilidad (la exige el validador):** dentro de lo oscuro **siempre se ven** el contorno rojo de lo que daña, los tres puntos del «escribiendo…» (son luz), los checks del «Visto» y el borde de las burbujas al 30 %; lo que la Linterna añade es el texto, el largo exacto y lo escrito «en tinta» (`ink_only`: decorado, puntos o pasos que solo existen bajo su luz). Sin Linterna (no puede pasar en el Mundo 4) la zona se recorre igual.
- **Linterna frente al Debug:** el Debug enseña **lo que es mentira** (Fantasmas, Trolls disfrazados, burbujas ocultas) y gasta energía; la Linterna enseña **lo que está a oscuras**, gratis, en un radio pequeño. No se solapan: nada pide las dos a la vez en Caché.
- **Revela secretos:** `ink_only` marca la entrada de dos secretos (4-2 A y 4-3 B). Eso cumple «ilumina zonas oscuras y revela secretos» (`04` §12.3) sin el antiguo «indica cuántos secretos hay».

### 3.7 Enemigos y objetos (qué se reutiliza)

Todo en **tiempo del mundo**, con `help_id`, `level_params` con rangos validados por el esquema, aviso de 6-12 cuadros antes de dañar y vuelta al estado inicial al reaparecer. **Rojo solo para lo que daña.**

| Tipo (id) | Comportamiento (doc) | Cómo se resuelve (doc) | Implementación (PROPUESTA) | Reutiliza |
|---|---|---|---|---|
| **Troll** (`troll`, enemigo) | Lanza mensajes hirientes que quitan Sync; perfil anónimo | Esquivar y aturdir con el pulso; Agitar aturde a varios | Avatar anónimo (silueta gris) sobre un saliente. Con Isak a ≤ 9 tiles en línea horizontal, cada **2,5 s** escribe (bocadillo «escribiendo…» de **0,75 s**, el aviso) y lanza un **proyectil de texto** horizontal a **240 px/s** («ok.», «¿y?», «jajaja»): −10. El dash lo atraviesa; Agitar lo borra. **Pulso: aturde 3 s**; aturdido, el **láser lo derrota** (vida 2, +20 de energía). | **Comentarista** del Mundo 2 (bocadillo con aviso), `NotificationShot` (proyectil), `EnemyHealth` |
| **Troll disfrazado** (`troll_mimic`, enemigo; 4-3) | Trolls que imitan la voz de los amigos; se distinguen con el Debug | Debug | Parece una **burbuja de amigo** (avatar e inicial). **Con el Debug**: avatar anónimo y **costuras rojas**. A ≤ 2 tiles se quita el disfraz (9 cuadros) y es un Troll; si Isak la pisa antes, se hunde 1 tile (sin daño) y se descubre. | `chat_bubble` + `troll`; revelado de `WeakPoint` / plataforma oculta |
| **Fantasma** (`ghost`, enemigo) | Desaparece al acercarse Isak y reaparece por detrás; el Debug muestra su rastro | Debug para anticipar | Avatar en blanco translúcido que patrulla. Con Isak a ≤ 3 tiles **se esfuma** (0,3 s) y **1,0 s después reaparece 2 tiles detrás de Isak** (contrario a donde mira) con aviso de **9 cuadros** (silueta y `sfx_w4_ghost_appear` posicional); **0,5 s después embiste** (contacto −10). **Con el Debug**: una línea de puntos coral desde donde se esfumó hasta donde va a reaparecer (el «rastro»). **Pulso al reaparecer** (está a tiro: 2 tiles = 128 px, se da la vuelta o se deja llegar a 96): aturdido 3 s; aturdido, el láser lo derrota (vida 2). | Patrulla y contacto de la **Burbuja**; revelado del Debug; inflado del **punto rojo** como aviso |
| **Zona «Visto»** (`seen_zone`, objeto) | Congela al entrar | Rodear, pulso, Agitar | §3.5 | Zona de `CloneZone` (detección), `relay_receiver` (respuesta al pulso) |
| **Autocorrector** (`autocorrect_bubble`, objeto) | Reescribe la plataforma en el último momento; el cursor parpadea antes | Fijarse en el cursor | §3.4 | `BlinkPlatform`, `reminder_platform` (disparo al pisar) |
| **Sticker** (`sticker`, enemigo) | Emoji que se acerca y explota | Aturdirlo antes; Agitar elimina a los cercanos | Cara redonda inventada (sin marcas) que **rebota hacia Isak a 120 px/s** a ≤ 6 tiles. A ≤ 1,5 tiles **se infla 9 cuadros** y **explota** (radio 1,5 tiles, −10); queda como confeti sin daño. **Pulso:** aturdido 3 s (se para; si sigue cerca al despertar, vuelve a inflarse). **Agitar:** se desinfla y desaparece (+5 de energía). Láser: vida 1. | **Punto rojo** del 1-2 (persigue e infla 9 cuadros), `PixelBurst` |
| **Muro de texto** (`typed_wall`, objeto; 4-2) | — | — | Pared de 1 × 3 de líneas de texto escrito («y entonces le dije que…»). **Agitar a ≤ 2,5 tiles la deshace** para siempre (letras que se borran de atrás adelante, 0,4 s). Pulso y láser rebotan. | **Muro «Cargando más…»** del Mundo 2 |
| **«¿Deshacer escritura?»** (`undo_prompt`, objeto; 4-2) | Isak descubre que agitando deshace lo escrito y obtiene Agitar | — | Panel de sistema en la pared del fondo («¿Deshacer escritura? Agita el dispositivo»). **Pulso de espaldas**: concede `shockwave`, la línea de Eco (importante) y el aviso; un solo uso (`unless_ability`), vuelve tras un rollback sin el gesto. | **`DndSwitch`** / `PausePlayer` / `crop_tool` |
| **Linterna** (`flashlight_pickup`) y **Modo oscuro** (`dark_zone`) | — | — | §3.6 | Recogida de `ability_pickup` (una vez), velo de `OverlayPopup`, luz por `PointLight2D` o máscara por shader |
| **Papelera** en el nivel (`papelera_actor`, 4-2) | Aparece en «Mensajes borrados» | — | Actor de historia con el arte de su estación del hub (§6.3); habla con líneas importantes; sin colisión. | `calc_actor` del 1-2 |
| **Puerta «Responder más tarde»** (`exit_terminal`, `skin: "chat_reply"`) | Cierre del 4-3 | — | Terminal de salida con otro aspecto (pulso); su escena final depende de V15 (§10.2). | `exit_terminal` (`skin`) |

Los tipos de los Mundos 1-3 **no aparecen** (cada mundo tiene su familia de formas, `07` §15.5). Los genéricos sí: cargador, punto de atención, power bank, vida extra, `memory_pickup`, pared con glitch, lector láser, receptor enlazado, `decor`, vórtices y pinchos. **Rejugar con Agitar** (y con la Linterna) los Mundos 1-3: el validador revisa con `abilities_available.shockwave` que no se trivialice ningún secreto.

### 3.8 Lenguaje de combinaciones del Mundo 4 (amplía `propuesta-mundo-3.md` §3.5)

| Regla nueva | Consecuencia de diseño |
|---|---|
| El suelo llega tarde | Se salta antes de que exista: el «escribiendo…» es un aviso y una cuenta. |
| Que te vean cuesta tiempo | El «Visto» no quita vida: quita segundos, y los segundos importan con plataformas que desaparecen o con la ola. |
| Uno a uno o todos a la vez | Pulso gratis contra uno; Agitar cuesta 10 contra muchos y te deja expuesto. |
| La luz y la verdad son distintas | Linterna para lo oscuro, Debug para lo falso. |

- **Patrón 18. Anticipar:** burbuja fija → «escribiendo…» sobre un hueco de 2 tiles: saltar con el segundo punto.
- **Patrón 19. Interrumpir antes de pasar:** zona «Visto» en el aire entre dos burbujas, con su doble check junto al borde de la primera: pulso y saltar en los 4 s de la interrupción.
- **Patrón 20. Limpiar el grupo:** tres Trolls a distintas alturas; el pulso solo llega a uno, Agitar desde el centro los aturde a todos y borra sus mensajes.
- **Patrón 21. Rastro:** Fantasma en un pasillo de techo bajo; con el Debug se ve dónde reaparece y se le espera de cara.
- **Patrón 22. Tiempo contra distancia:** zona «Visto» obligatoria con la ola a la espalda: esperar 1,5 s o gastar un Agitar.
- **Fórmula de ventana** (`propuesta-1-2.md` §0.1): ventana ≥ k × (recorrido + poses + congelaciones obligatorias + 1,0 s por cada «escribiendo…»), con **k = 1,6 en dificultad 4 y k = 1,4 en dificultad 5** (el 4-3).

---

## 4. Niveles, tramo a tramo

**Convención:** el **4-1 es vertical** (torre, cámara de torre del 1-2, `TowerCamera`): se sube por el hilo de la conversación. El **4-2 y el 4-3 son horizontales de 14 filas** (cámara del 1-1). Columnas desde la izquierda; filas desde arriba. Subidas de 2 tiles medidas con el Isak real (`tests/test_level_climbs.gd`). **Los mapas son orientativos**: las posiciones exactas las fija el validador en el paso de cada nivel, como en el hub.

**Duración (lección del Mundo 3, decisión tomada §9.10):** en el Mundo 3 el bot recorrió el 3-1, el 3-2 y el 3-3 en **68, 85 y 129 s** frente a objetivos de **360, 420 y 480 s** (19-27 %); en el Mundo 2, en **161, 239 y 244 s** frente a 300-420 (54-66 %). Para el Mundo 4 se pide que **el camino del validador quede entre el 40 y el 55 % del objetivo** (≈ 3-4 min de bot, unos 7-9 min de un jugador que lee, duda y reintenta). El 4-3 tiene el ritmo atado a la ola, así que su duración mínima la marca ella.

### 4.1 Nivel 4-1 «Chats recientes»

**Doc:** presentar las burbujas como plataformas, el «escribiendo…» y la zona «Visto»; unos 7 min; dificultad 4; tramos 1-4; secreto: un mensaje antiguo escondido en una burbuja que solo se ve con el Debug, con un recuerdo; un punto de sincronización a mitad.

- **Mapa: 24 × 96** (torre; 1536 × 6144 px). `target_duration_s` **420**; camino del validador de unos **170-210 s**. Dificultad `4`. `abilities_available`: pulso, láser, Debug, dash, golpe al suelo y Pellizcar (Agitar, **no**). Se sube de la fila 95 a la 0; los pisos se separan con forjados de una vía.

| Piso | Filas | Contenido | Duración (camino) |
|---|---|---|---|
| Vestíbulo «Lista de chats» | 84-95 | Vórtice (4, 94). **Linterna** sobre la repisa de la llegada (se recoge al pasar; Eco: «Una linterna. Qué antigüedad. Yo ilumino mejor, {apodo}.», **propuesto**, no importante). Cartel «En línea hace 3 h». 1 punto. | 15 s |
| Piso 1 «Burbujas» | 68-83 | **Primeras burbujas** (doc): zigzag de burbujas de 1 a 8 tiles; un «jajaja» de 2 tiles sobre un hueco, un mensaje largo de 7 que hace de puente. Q `chat_bubble` (texto de Eco **propuesto**: «Cuanto más dicen, más sitio te dejan.»). Una burbuja «Se eliminó este mensaje» (contorno sin colisión). 1 punto. | 35 s |
| Piso 2 «Escribiendo… · Modo oscuro» | 52-67 | **Primer «escribiendo…»** (doc) en una **zona oscura** (03:12): los tres puntos se ven en la oscuridad antes que la burbuja (patrón 18, cuatro veces). `cargador_1`. **Secreto A** (§4.1.1). 1 punto. | 45 s |
| Pausa | 50-51 | **`sync_1`** (doc: a mitad). | — |
| Piso 3 «Troll» | 34-49 | **Primer Troll** (doc) en el centro del piso, disparando a través del hueco mientras se sube por los lados; las burbujas largas lo tapan. Se le aturde desde una burbuja a su altura y, aturdido, el láser lo derrota. `cargador_2`. **Secreto B**. 1 punto. | 40 s |
| Piso 4 «Visto» | 16-33 | **Primeras zonas «Visto»** (doc): una en el suelo (rodearla), una entre dos burbujas en el aire (patrón 19: pulso al check y pasar) y una con ciclo. **Sin peligros a tiro de una zona** (regla de §3.3). **Secreto C**. 1 punto. | 40 s |
| Azotea «En línea» | 0-15 | Terminal «Enviar» (`exit_terminal`, pulso): fundido y vuelta al hub. 1 punto. | 10 s |

**Mapa de conjunto** (escala: 1 carácter = 1 columna; 1 línea = 4 filas; `-` forjado de una vía, `=` burbuja fija, `~` «escribiendo…», `V` zona «Visto», `T` Troll, `:` oscuro, `C` cargador, `S` sync, `o` punto, `L` Linterna, `P` vórtice, `E` terminal, `?` secreto):

```
filas  0         1         2
       012345678901234567890123
 0- 3  #         E     o      #   Azotea «En línea»
 4- 7  #=====          ======-#
 8-11  #      ====  ===      -#
12-15  ##########----##########
16-19  #  V    ====   V====  ?#   Piso 4 «Visto» (? = C, vida extra, glitch + dash aéreo)
20-23  #=====    VV    ====   #
24-27  #     ====    ===    V #
28-31  #  o   ===  ====       #
32-35  ##########----##########
36-39  #====     T      ====  #   Piso 3 «Troll» (T en la columna 11)
40-43  #   ====      o  ====?##   ? = B, power bank
44-47  #======  C      =======#
48-51  #####------S-###########   S = sync_1
52-55  #::::::::~~~~::::::::::#   Piso 2 «Escribiendo…» en Modo oscuro
56-59  #:::~~~~:::::~~~~:::::?#   ? = A, msg_4_1 (burbuja oculta, solo con el Debug)
60-63  #::::::::~~~~::=====::o#
64-67  #####=====:::::::::C:::#
68-71  #   ====     =======   #   Piso 1 «Burbujas»
72-75  #=======   ==      ====#
76-79  #     ==   o   ======  #
80-83  ######----#############
84-87  #                      #   Vestíbulo «Lista de chats»
88-91  #  L====        o      #
92-95  #  P                   #
```

**Detalle a escala 1:1 del Piso 2** (filas 52-67; columnas 0-23; burbujas cada 2 filas, huecos de 1-2 tiles):

```
       0         1         2
       012345678901234567890123
  51   #########----###########   forjado; ---- de una vía (cols 9-12) al piso 3
  52   #::::::::::::::::::::::#
  53   #::::::::~~~~::::::::::#   T4 «escribiendo…» (cols 9-12), bajo el hueco
  54   #::::::::::::::::::::::#
  55   #::::::::===::::::::::M#   B3 fija (cols 9-11) · M = msg_4_1 en el nicho (col 22)
  56   #:::::::::::::::::::::##
  57   #::::~~~~:::::::::hhhh:#   T3 (cols 5-8) · hhhh = burbuja oculta (solo Debug) del secreto A
  58   #::::::::::::::::::::::#
  59   #::::::::~~~~::::::::::#   T2 (cols 9-12)
  60   #:::::::::::::::::::o::#
  61   #:::::::::::::=======::#   B2 fija larga (cols 14-20) «Tomi: te mandé un meme»
  62   #::::::::::::::::::::::#
  63   #::::::::~~~~::::::::::#   T1 (cols 9-12): aparece 1 s después de pisar B1
  64   #::::::::::::::::::::::#
  65   #::=====:::::::::::::::#   B1 fija (cols 3-7) «Hoy 03:12»
  66   #:::::::::::::::::C::::#   C = cargador_1 (col 18)
  67   #####----###############   suelo; ---- de una vía (cols 5-8) desde el piso 1
```

#### 4.1.1 Secretos y economía del 4-1

- **Secreto A «Mensaje antiguo» (doc):** en el Piso 2, una burbuja **oculta** (plataforma `h`, solo con el Debug, con su texto «hace 4 meses») sale de T3 hacia la pared derecha y lleva a un nicho con el **`memory_pickup` `msg_4_1`** (Tomi) y **1 punto**. `forbid_abilities: ["dash"]` (que se lea, no que se salte).
- **Secreto B «Archivado»:** en el Piso 3, tras la pared derecha, una sala «Archivado» con el **power bank** del nivel y **1 punto**; se entra por un **marco pequeño** (Pellizcar, que el jugador ya tiene) junto al Troll: hay que aturdirlo antes de comprimirse (comprimido no hay pulso).
- **Secreto C «Vida extra»:** en el Piso 4, una **pared con glitch** (`visible_only_with_debug`) en la esquina superior derecha, a la que se llega con **salto + dash aéreo** desde la última burbuja; detrás, **`vida_extra_4_1`** (N = 3: la anterior fue la del 3-1). La cuarta del juego.

| Dónde | Ruta | Secretos |
|---|---|---|
| Vestíbulo | 1 | |
| Piso 1 | 1 | |
| Piso 2 | 1 | A: 1 + `msg_4_1` |
| Piso 3 | 1 | B: 1 + power bank |
| Piso 4 | 1 | C: vida extra |
| Azotea | 1 | |
| **Total** | **6** | **2 puntos + mensaje + power bank + vida extra** |

- **8 puntos.** **Cargadores:** 2 (+50, reutilizables, 10 s). **Power bank:** 1. **Puntos de sincronización:** 1.
- **Energía:** obligatoria ~20 (láser al Troll aturdido, opcional); típica 40-70 (Debug del secreto A y del C).

### 4.2 Nivel 4-2 «Grupo sin respuesta»

**Doc:** obtener Agitar y enseñar a gestionar muchos enemigos; unos 8 min; dificultad 4; inicio en «Mensajes borrados» (deshacer lo escrito; Eco: «No necesitas a nadie más.»); tramos 1-4; secreto: un grupo de chat silenciado con avatares apagados.

- **Mapa: 260 × 14** (16 640 × 896 px). `target_duration_s` **480**; camino de unos **200-250 s**. Dificultad `4`. `abilities_available`: todo lo anterior; `shockwave` se obtiene en el inicio.

| Tramo | Columnas | Contenido | Duración (camino) |
|---|---|---|---|
| Inicio «Mensajes borrados» | 0-24 | Vórtice (3, 11). Sala llena de burbujas «Se eliminó este mensaje». **La Papelera** está allí (actor; **momento de historia** con pausa, §4.2.2). **«¿Deshacer escritura?»** (`undo_prompt`, col. 14): pulso de espaldas → Agitar; Eco: **«No necesitas a nadie más.»** (importante, decidida) y el aviso «Agitar: U / LB (mando)». **La salida es un muro de texto** (`typed_wall`, col. 22): uso obligatorio a 8 tiles de la obtención. 1 punto. | 30 s |
| Tramo 1 «Grupo» | 25-80 | **Grupos de Trolls** (doc; patrón 20): tres a distintas alturas que cubren el pasillo; con el pulso solo se aturde a uno. Agitar desde el centro los aturde a todos y borra sus mensajes; después, láseres. Burbujas de grupo como suelo («Clase 4ºB · 47 participantes»). 1 punto. | 50 s |
| Tramo 2 «Fantasmas» | 81-130 | **Fantasmas** (doc; patrón 21) en un pasillo de techo bajo y en burbujas sueltas; con el Debug se ve dónde reaparecen. `cargador_1` (col. 84). **Secreto A** (§4.2.1). 1 punto. | 45 s |
| Pausa | 131-135 | **`sync_1`**. | — |
| Tramo 3 «Autocorrector» | 136-195 | **Autocorrector junto a zonas «Visto»** (doc): una burbuja larga que se corrige a corta justo antes de una zona en el aire (fijarse en el cursor y saltar antes, o pulsar la zona); un Troll que dispara mientras Isak está congelado (aquí ya hay Agitar). `cargador_2` (col. 160). **Secreto B**. 1 punto. | 55 s |
| Tramo 4 «Stickers» | 196-250 | **Enjambre de Stickers** (doc): llegan en tandas de 4-6 por el suelo y por las burbujas; un Agitar los elimina a todos, pero los 0,25 s expuestos coinciden con un proyectil de Troll si se agita tarde. `cargador_3` (col. 205). **Secreto C**. 1 punto. | 55 s |
| Cierre | 251-259 | Terminal «Salir del chat» (pulso) y vuelta al hub. 1 punto. | 10 s |

**Mapa de conjunto** (escala: 1 carácter = 4 columnas; 1 línea = 1 fila):

```
col/4  0    5    10   15   20   25   30   35   40   45   50   55   60  64
fila0  #################################################################
  1    #                                                               #
  2    #      ===          ==    ==       ~~      ===        ===       #
  3    #  T      T   T             V          T      ~~   ==     E     #
  4    #   ==   ===    ==   ===       ====  ==   V     ==    ====      #
  5    #  W         ==         hh  :::      ===        ==  s s  s      #
  6    #=====  ===      ==  ===   :?:  ===     ~~~  ==    ====   ==    #
  7    #  U  #     ==  ===   g   :::   S   ====   V    ==  s  s        #
  8    # Pa  #  ===    ==   ===         ===  ==  ====  ?       ==   ?  #
  9    #  P  W     T     g     ===  ===   ====      C      s    C      #
 10    #===================  ======  ========================  ========#
 11    #################################################################
       |Inicio|T1 Grupo  |T2 Fantasmas|S| T3 Autocorrector | T4 Stickers |Cierre
```

`P` vórtice · `Pa` Papelera · `U` «¿Deshacer escritura?» · `W` muro de texto · `T` Troll · `g` Fantasma · `V` zona «Visto» · `~` «escribiendo…» · `s` Sticker · `hh` burbuja corregida · `:` zona oscura · `?` secreto · `C` cargador · `S` sync · `E` terminal.

**Detalle a escala 1:1 de «Mensajes borrados»** (columnas 0-24, filas 0-13):

```
       0         1         2
       0123456789012345678901234
   0   #########################
   1   #                       #
   2   #   [Se eliminó este    #   decorado: burbujas eliminadas (contorno, sin colisión)
   3   #    mensaje]     o     #
   4   #        ======         #   burbuja fija de una vía (cols 8-13), 1 punto encima
   5   #                       #
   6   #  [Se eliminó]         #
   7   #                       #
   8   #              U      W #   U = «¿Deshacer escritura?» (col 14, panel en la pared del fondo)
   9   #   Pa                W #   Pa = Papelera (col 4); W = muro de texto (col 22, 1 × 3)
  10   #  P                  W #   P = vórtice (col 3)
  11   #########################
  12   #########################
  13   #########################
```

#### 4.2.1 Secretos y economía del 4-2

- **Secreto A «Silenciado» (doc):** en el Tramo 2, una burbuja de grupo con la campana tachada («Garaje · Silenciado») parece decorado. Bajo ella, un **marco pequeño** (Pellizcar) da a una sala **a oscuras**: con la **Linterna** se ven los avatares apagados de Lía, Marco y Tomi y, escrito «en tinta» (`ink_only`), el camino a la burbuja con el **`memory_pickup` `msg_4_2`** (Marco) y **2 puntos**. Es el primer indicio de los amigos reales. Combina Pellizcar (Mundo 3) y Linterna (Mundo 4), sin Debug.
- **Secreto B «Ok, ¿y tú?»:** en el Tramo 3, un **autocorrector al revés**: una burbuja «ok» de 1 tile que, **si Isak espera 3 s junto a ella**, se corrige a «ok, ¿y tú qué tal? cuéntame» (5 tiles) y hace de puente a una repisa con el **power bank** y **1 punto**. El tema del mundo en una mecánica: esperar una respuesta de verdad.
- **Secreto C:** **1 punto** en una burbuja alta del Tramo 4, a la que se llega con un «escribiendo…» y un dash aéreo **sin Stickers despiertos** (hay que agitarlos antes).

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 1 | |
| Tramo 2 | 1 | A: 2 + `msg_4_2` |
| Tramo 3 | 1 | B: 1 + power bank |
| Tramo 4 | 1 | C: 1 |
| Cierre | 1 | |
| **Total** | **6** | **4 puntos + mensaje + power bank** |

- **10 puntos.** **Cargadores:** 3. **Power bank:** 1. **Vida extra:** no. **Puntos de sincronización:** 1.
- **Energía:** obligatoria ~60 (Agitar en el muro, en el grupo del Tramo 1 y en el enjambre; Debug en los Fantasmas), con un cargador a pie de cada tramo; típica 90-120. Los Stickers agitados devuelven +5 cada uno.

#### 4.2.2 Momento de historia: la Papelera (PROPUESTA; textos «propuesto»)

Pausa de principio a fin, como el encuentro con Eco del 1-1 y la azotea del 1-2:

1. **Papelera** (primera vez que habla; interlocutor nuevo `papelera` en `speaker_styles`, estilo `panel` con un icono propio): «Aquí llega lo que él tira. No lo borra. Lo guarda donde no mires.» (**propuesto**)
2. **Papelera:** «Si quieres deshacer algo, agita. Lo escrito no siempre se queda.» (**propuesto**)
3. Isak usa **«¿Deshacer escritura?»**: Agitar obtenido; **Eco** (importante): **«No necesitas a nadie más.»** (doc); aviso de control.
4. **Papelera**, en voz baja (no importante, ya sin pausa): «Él no soporta el silencio. Acuérdate.» (**propuesto**; anticipa la fase 3 de El Visto, §5.6).

Un solo uso: `seen_notices` `papelera_4_2` (sin subir la versión del guardado). **En el hub no cambia nada de la Papelera** (sigue su regla: se activa con el primer game over; la marca `"papelera"` de `allies_met` sigue siendo ese «primera vez»). **Razón:** la duda 3 de los asistentes recomendaba «actúa en silencio y habla por primera vez allí»; así la Papelera del hub y la del 4-2 son la misma sin tocar el guardado.

### 4.3 Nivel 4-3 «Mensajes sin leer»

**Doc:** combinar todo y llevar el peso emocional; unos 9 min; dificultad 5 de 5 dentro del mundo; mensajes reales de los amigos como plataformas; una ola de «Visto» avanza desde atrás; Tramo 1 sin enemigos y música baja; Tramo 2 Fantasmas y Trolls que imitan a los amigos (Debug); Tramo 3 la ola acelera y los mensajes se espacian; cierre con la última burbuja de Tomi y la puerta; secreto: una conversación completa con un amigo cercano, con el Debug.

- **Mapa: 300 × 14.** `target_duration_s` **480** (ver nota); camino de unos **220-250 s** (lo marca la ola). Dificultad `5`. Todo el kit, con Agitar.
- **Nota de duración:** la ficha dice 9 min. Con la ola, el jugador no puede ir más lento que ella, así que la duración la marcan su velocidad y los reintentos: se propone **480 s** de objetivo con un camino de unos 230 s. Alargarlo a 9 min pediría unos 380 tiles o una ola de 0,8 tiles/s (aburrida). **Decisión tomada** (§9.10).

| Tramo | Columnas | Contenido | Ola | Duración (camino) |
|---|---|---|---|---|
| Inicio «Sin leer (37)» | 0-20 | Vórtice, cartel «37 mensajes sin leer», 1 punto. La ola **arranca al cruzar la columna 20**. | parada | 15 s |
| Tramo 1 «Recientes» | 21-100 | **Sin enemigos** (doc): burbujas de **Lía** («¿Estás bien? Hace días que no contestas.», `04` §12.4) y de los otros, sellos «hace 2 días», «hace 5 días»; huecos de 1-2 tiles; dos «escribiendo…»; una zona «Visto» obligatoria (patrón 22). Música baja. `cargador_1` (col. 60). 2 puntos (uno en una burbuja alta). | 1,0 tiles/s | 80 s |
| Pausa | 101-108 | **`sync_1`** (la ola se para). **Secreto A** en la parada (§4.3.1). | parada | — |
| Tramo 2 «Voces» | 109-200 | **Fantasmas y Trolls disfrazados** (doc): burbujas «de Marco» que con el Debug son Trolls; la de verdad, «Te guardé un lugar para el torneo.» (`04` §12.4). Fantasmas que reaparecen **entre Isak y la ola**. `cargador_2` (col. 150). 1 punto. | 1,2 tiles/s | 75 s |
| Pausa | 201-206 | **`sync_2`** (la ola se para). | parada | — |
| Tramo 3 «Cada vez más lejos» | 207-285 | La ola **acelera** 1,2 → 1,6 tiles/s (doc) y **los huecos crecen con el tiempo entre mensajes**: «hace 2 semanas» (2 tiles), «hace 1 mes» (3, corriendo), «hace 2 meses» (4, salto + dash aéreo), «hace 3 meses» (dos «escribiendo…» encadenados). La segunda mitad es **Modo oscuro** (la madrugada se cierra; Linterna). `cargador_3` (col. 230). **Secreto B** y **C**. 1 punto. | 1,2 → 1,6 tiles/s | 60 s |
| Cierre «Tomi» | 286-299 | La ola **se para** a 6 tiles y se apaga. La música se queda en silencio. Última burbuja, de **Tomi**: «Ok, cuando quieras hablar, aquí estoy.» (`04` §12.4). Puerta «Responder más tarde» (`exit_terminal`, `skin: "chat_reply"`): al pulsarla, el campo de respuesta parpadea con el cursor y sale «Sin conexión» (Eco no deja enviar); Isak sale **sin responder** (V15 decidida, §10.2). 1 punto. | apagada | 15 s |

**Mapa de conjunto** (escala: 1 carácter = 4 columnas; 1 línea = 1 fila). Arriba, los sellos de hora; los huecos entre burbujas crecen hacia la derecha:

```
sellos       hace 2 días      hace 5 días   |S|  hace 1 semana     |S| 2 sem  1 mes   2 meses  3 meses |
col/4  0    5    10   15   20   25   30   35   40   45   50   55   60   65   70  75
fila0  ###########################################################################
  1    #                                                                         #
  2    #                                    ?                                 ?  #
  3    #           ~~       ==     ==      hhh      ==    m=     ::::::::::::::  #
  4    #      ==       ===     ==      ===     ==  g    ==    ===:: ~~ ::::==::  #
  5    #   ==     ==      V        ==   G      m=      ==    ==  ::   ::  ~~::E  #
  6    #<<<  ==      ==       ==      ===   ===   =m   g  ==   == :: ==   ::  T  #
  7    #<<<     ==       ==      ==  S  ==     ==     ==      S == ::    :: ==:  #
  8    #<<< o     C  ==     ==      ===    ==   C   ==   ==  ===  ::C  ==  ::==  #
  9    #<<< P  ==         ==    ==         ==        ===    ==   ::   ==    :::  #
 10    ####  #######   ####   ####   ##########  ####   ####   #### ##   ##  ####
 11    ###########################################################################
       |Ini| Tramo 1 «Recientes» (sin enemigos) |S| Tramo 2 «Voces»   |S| Tramo 3 | Cierre
```

`<<<` ola de «Visto» (arranca en la columna 20) · `=` burbuja (de amigo o de otros) · `m=` burbuja de «Marco» que con el Debug es un Troll disfrazado · `~` «escribiendo…» · `V` zona «Visto» · `g` Fantasma · `G` pared con glitch del secreto A · `hhh` burbujas ocultas · `:` Modo oscuro · `T` Tomi (última burbuja) · `E` puerta · `?` secretos.

**Detalle a escala 1:1 del Tramo 3** (columnas 240-269: los huecos crecen; Isak va de izquierda a derecha con la ola detrás):

```
col    240       250       260
       0123456789012345678901234567890
   4   ::::::::::::::::::::::::::::::   Modo oscuro desde la columna 258
   5   ::::::::::::::::::::::::::::::
   6                         ~~~~:::::  «escribiendo…» (cols 265-268), «hace 3 meses»
   7                ====  ::::::::::::  burbuja «hace 2 meses» (cols 256-259)
   8          ====    ::::::::::::::::  hueco de 4 (cols 260-263): salto + dash aéreo
   9   ===           :::::::::::::::::  burbuja «hace 1 mes» (cols 250-253); hueco de 3 (247-249)
  10   ###  ##                ::::::::  suelo con fosos (caída de ≤ 3 tiles con salida al suelo bajo)
  11   ###############################
```

#### 4.3.1 Secretos y economía del 4-3

- **Secreto A «Conversación completa» (doc):** en la parada de `sync_1` (la ola espera), una **pared con glitch** (`visible_only_with_debug`) en la parte alta da a burbujas **ocultas** (solo Debug) con la conversación entera de **Lía**; al final, el **`memory_pickup` `msg_4_3`** y **2 puntos** («da un recuerdo y puntos de atención», doc). `forbid_abilities: ["dash"]`.
- **Secreto B «Borrador»:** en el Tramo 3, ya en lo oscuro, una burbuja escrita «en tinta» (`ink_only`, solo con la Linterna) **sobre** la ruta: un mensaje que Isak empezó y nunca mandó («perdón por no contestar, es que…»); lleva al **power bank** del nivel. Se coge sin parar si se lee a tiempo: la ola no se detiene.
- **Secreto C:** **1 punto** en la penúltima burbuja «hace 3 meses», a la que solo se llega con un Agitar que rompe una zona «Visto» en el aire (tiempo contra distancia).

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 2 (una en una burbuja alta) | |
| Parada 1 | — | A: 2 + `msg_4_3` |
| Tramo 2 | 1 | |
| Tramo 3 | 1 | B: power bank; C: 1 |
| Cierre | 1 | |
| **Total** | **6** | **3 puntos + mensaje + power bank** |

- **9 puntos.** **Mundo 4: 27 puntos** (8 + 10 + 9). Con los Mundos 1-3, unos **108** al terminar el Mundo 4 en Caché.
- **Cargadores:** 3. **Power banks:** 1 (el Mundo 4 suma 3). **Puntos de sincronización:** 2 (la ola los necesita: cada reintento empieza en una parada).
- **Energía:** obligatoria ~40 (Debug para distinguir a los Trolls disfrazados que tapan el camino); típica 70-100 (Agitar para liberarse de la ola).

### 4.4 Duración, dificultad y progresión

| Nivel | Mapa | Dificultad | Camino (validador) | Objetivo | Enseña | Combina con |
|---|---|---|---|---|---|---|
| 4-1 | 24 × 96 (torre) | 4 | ~190 s | 420 s | Burbujas, «escribiendo…», Modo oscuro (Linterna), Troll, zonas «Visto» | Pulso, láser, Debug, dash, golpe al suelo, Pellizcar |
| 4-2 | 260 × 14 | 4 | ~225 s | 480 s | Agitar, muro de texto, grupos de Trolls, Fantasmas, Autocorrector, Stickers | Todo lo anterior |
| 4-3 | 300 × 14 | 5 | ~230 s (ola) | 480 s | Ola de «Visto», Trolls disfrazados, tiempo contra distancia | Todo el kit |
| Jefe | 20 × 11 | 5 | ~110-150 s (bot) | 240 s | Ghosting, escudo con Agitar, interrumpir el «escribiendo…» | Todo el kit |

**Curva:** el 4-1 sube respecto al 3-1 (dificultad 3 → 4) porque el jugador trae todo el kit y la torre añade caídas; el 4-2 se distingue por **la cantidad** (muchos a la vez, Agitar) y el 4-3 por **la presión constante** (la ola), con el Tramo 1 en calma a propósito.

**Qué prepara cada nivel para el jefe:** Fantasmas y su rastro (4-2, 4-3) → fase 1; grupos de Trolls y enjambres con Agitar (4-2) → fase 2; «escribiendo…» y congelación (4-1, 4-3) → fase 3; Debug para distinguir lo falso (4-3) → el punto débil.

### 4.5 Mensajes recuperables `msg_4_x` (borradores de tono; PROPUESTA)

**Remitentes: los amigos Lía, Marco y Tomi** (decisión del usuario tomada el 2026-10-28, §10.3; no Mamá). Tono cálido, cotidiano, con humor; siguen el hilo del recuerdo del jefe (el garaje, la cadena de la bici, el grupo silenciado; `propuesta-recuerdos.md` §11.2) **sin contarlo**. Van en `data/memories.json` con `level`, `secret` y `first_lap: 1`; reaparecen en Kernel y Raíz si no se obtienen; ≤ 280 caracteres; solo glifos de la fuente.

| Id | Nivel · secreto | Remitente · asunto | Idea del texto (borrador, **propuesto**) |
|---|---|---|---|
| `msg_4_1` | 4-1 · `secreto_mensaje_antiguo` | Tomi · «Meme del día» | «Te mandé el meme del perro con casco. Si no te ríes es que te secuestraron. Parpadea dos veces. — Tomi» |
| `msg_4_2` | 4-2 · `secreto_silenciado` | Marco · «Sábado» | «Traje la cadena nueva para la bici de Lía. Falta el mecánico. Ya sabes quién. Sábado, como siempre. — Marco» |
| `msg_4_3` | 4-3 · `secreto_conversacion` | Lía · «Conversación completa» | «¿Te acuerdas del garaje? Tomi todavía cuenta lo de la cadena como si fuera magia. Hoy no te escribo más. Mañana sí. — Lía» |

### 4.6 Hub y progresión

- **`data/hub.json`, mundo `m4`** (hoy `levels: []`): filas `4-1 «Chats recientes»`, `4-2 «Grupo sin respuesta»`, `4-3 «Mensajes sin leer»` y `{"id": "4-boss", "name": "El Visto", "kind": "boss"}`, todas con `laps: [1]` y `playable: false` («Próximamente») hasta que existan; desbloqueo en cadena (`unlocks`); el 4-2 y el 4-3 con `available_text` **«Nuevo mensaje»** (propuesto, como «Siguiente video» y «Nueva foto»). Iconos `menu_level_4_*` por script.
- **Carpeta M4** (página 2, columna 4, ya existe): se añade la **miniatura** que hoy falta (`world_icon_m4`: un bocadillo con tres puntos). El álbum de Notas abre la carpeta «El Chat» al instalar el upgrade (ya implementado).
- **Linterna:** al conocerla, su hueco del dock (**página 1, columna 13**) se enciende (`requires_ally`), sin panel.
- **Calc** (comentario de llegada `calc.remarks`, tras el 4-1; no importante): «Mensajes enviados: 0. Recibidos: 37. Saldo: preocupante.» (**propuesto**).
- **Al vencer a El Visto:** **cuarta pieza del fondo en coral** (pasa de `off` a `on`; se regenera con el coral definitivo, §6.1), placa «!» en Notas, **cuarta ranura del candado de La Nube** encendida (`boss_w4_l1`) y **Mundo 5 «La Tienda» disponible** («Próximamente»; `m5.unlocked_by: ["4-boss"]`, ya en datos).

---

## 5. Jefe del Mundo 4: El Visto

### 5.1 Concepto y tono

- **Decidido:** «un doble check gigante con aura fantasmal»; la ausencia convertida en monstruo; **Eco habla a través de él, ya sin disimulo**. Arena: un chat gigante casi vacío, con burbujas flotando y espacios en blanco. Punto débil: bajo los dos checks, uno **gris «sin leer»**, solo visible con el Debug, **en rojo**. Fases: (1) ghosting, reaparece por la espalda, el Debug muestra su rastro; (2) invoca Trolls y Stickers, Agitar limpia la arena y rompe su escudo; (3) un «escribiendo…» gigante que hay que interrumpir con el pulso antes del mensaje que congela; si lo manda, Agitar libera. Recompensa: «Fragmento de amistades»; Eco: «Yo siempre estoy. Ellos no.».
- **Tono (PROPUESTA; textos «propuesto»):** frío y tranquilo; nunca grita, nunca contesta del todo. Líneas: **intro** (pausa), **cambios de fase** (sin pausa), **derrota** (pausa, tras la recompensa). Borradores: intro, «Ya lo leí. No hace falta que contestes.»; fase 2, «Mira cuánta gente. Ninguno te escribe.»; fase 3, «Escribiendo… para ti. Solo para ti.».
- **Sin rollback** (solo el jefe final).

### 5.2 Arena «Chat vacío» (20 × 11 tiles)

- **1280 × 704 px:** cabe entera en pantalla, **cámara fija** (como Autoplay y la Curadora). Muros en las columnas 0 y 19, techo en la fila 0, suelo en la 10. Isak de pie en el suelo ocupa las filas 8-9.
- **El Visto:** doble check de **6 × 3 tiles** (columnas 7-12, filas 1-3) con aura; no es sólido. Debajo de los dos checks, el **check gris «sin leer»** (el `WeakPoint`).
- **Burbujas fijas** de una vía (columnas 3-6 y 13-16, superficie en la fila 6) y dos burbujas bajas (columnas 1-2 y 17-18, fila 8).
- **Fase 3:** la burbuja **«escribiendo…» gigante** baja a las columnas 7-12, filas 6-7 (a tiro de pulso desde el suelo: ~48 px del celular).
- **Cargadores:** 4 en el suelo, columnas 3, 7, 12 y 16: +50, enfriamiento 4 / 5 / 6 s (Caché / Kernel / Raíz).
- **Debug en la arena:** `debug_drain_scale` **0,25** y `debug_world_scale` **0,7** (los de los otros jefes; los recalcula el validador de arenas).
- Vórtice de llegada en (5, 9). Sin puntos, power banks ni vida extra.

```
      0         1
      01234567890123456789
   0  ####################   techo
   1  #      [✓✓  ✓✓]    #   El Visto: doble check 6x3 (cols 7-12, filas 1-3), aura fantasmal
   2  #      [ ✓✓✓✓ ]    #
   3  #      [  (✓)  ]   #   (✓) = check gris «sin leer» (punto débil; rojo con el Debug)
   4  #                  #
   5  #                  #
   6  #  ====      ====  #   burbujas fijas de una vía (cols 3-6 y 13-16)
   7  #      [ · · · ]   #   fase 3: «escribiendo…» gigante (cols 7-12, filas 6-7)
   8  # ==            == #   burbujas bajas (cols 1-2 y 17-18)
   9  #  C P C    C   C  #   suelo: C = cargadores (3, 7, 12, 16); P = vórtice (5)
  10  ####################
```

### 5.3 Punto débil y daño: la marca «sin leer» (decisión tomada)

La regla de Alerta Mayor y de la Curadora, la de V14: **Debug → pulso que marca → láser**.

1. **Oculto:** sin el Debug, el check gris no se ve; el láser atraviesa el aura (chispa gris) y el pulso no hace nada.
2. **Revelado:** con el Debug activo, el **check «sin leer»** se ve en **rojo pulsante** (`WeakPoint`, por encima del tinte coral).
3. **Marcado:** un **pulso** que lo alcanza con el Debug activo lo marca `mark_duration_s` (**Caché 4 s, Kernel 3 s, Raíz 2,5 s**). Con la marca, **un láser** es **un golpe** (2 con el Láser 4) **sin necesidad del Debug**, y la marca termina (**un golpe por marca**).
4. **Cómo se pone a tiro en cada fase:** (1) reaparece **a la espalda** de Isak; (2) **cae al suelo** al romperse su escudo; (3) se queda **aturdido** a la altura de la burbuja al interrumpirle el «escribiendo…».
- **Nada más hace daño:** ni el dash, ni el golpe al suelo, ni Agitar, ni Pellizcar. La marca se pierde al caducar, al cambiar de fase, en el golpe final y al reaparecer.
- **Contador:** **9 golpes en Caché (3 por fase)**; **12 en Kernel y Raíz (4 por fase)**. `BossBar` con el estilo **«conversación»**: una barra de mensajes leídos que se vacía por tercios (99 → 66 → 33 → 0).

### 5.4 Fase 1 «Ghosting» (doc: desaparece y reaparece por la espalda; el Debug muestra su rastro)

| Ataque | Aviso | Respuesta | Reutiliza |
|---|---|---|---|
| **Se esfuma y embiste:** desaparece y **reaparece 2 tiles detrás de Isak** a su altura; 0,6 s después embiste (−10) | Silueta de 9 cuadros + `sfx_boss4_vanish` posicional; **con el Debug**, el rastro de puntos desde que se esfuma | Darse la vuelta y, con el Debug, **pulso** (marca) → láser; o dash a través de la embestida | `ghost` (§3.7) a escala |
| **Burbujas que caen:** 3 mensajes vacíos caen en columnas | Sombra en el suelo y contorno rojo 9 cuadros | Salir de la columna | Onda de `AlarmBell` con otra forma |
| **Zonas «Visto»:** 2 zonas en el suelo, 3 s | Checks que se rellenan uno a uno | Rodearlas o pulsar su check | `seen_zone` |

**Ventana:** cada reaparición **es** la ventana: los **1,2 s del mundo** entre aparecer y embestir (unos 1,7 s reales con el Debug a ×0,7). Si se ha encendido el Debug **antes** (leyendo el rastro), da tiempo a pulso + láser. 3 golpes.

### 5.5 Fase 2 «Grupo» (doc: invoca Trolls y Stickers; Agitar limpia la arena y rompe su escudo)

- **El Visto se escuda:** un anillo de burbujas de texto lo rodea (`shield`) y sube a las filas 1-3.
- **Invoca:** 2 Trolls en las burbujas fijas y tandas de 3 Stickers por el suelo, cada 6 s.
- **Cómo se le da:** el escudo **solo se rompe con la arena limpia** (sin Trolls ni Stickers despiertos): primero **Agitar** en el suelo (aturde y elimina Stickers, borra mensajes), después subir a una burbuja fija y **Agitar desde su borde interior** (a ≤ 2,5 tiles del escudo) → el escudo estalla y El Visto **cae al suelo 4 s del mundo**: Debug → pulso → láser. Dos Agitares por ventana (20 de energía): **Agitar es la llave de la fase**.
- **Ataques entre ventanas:** proyectiles de los Trolls, explosiones de Stickers y una zona «Visto» que barre una burbuja fija. 3 golpes.

### 5.6 Fase 3 «Escribiendo…» (doc: un «escribiendo…» gigante; interrumpirlo con el pulso antes de que mande el mensaje que congela; si lo manda, Agitar libera)

- **El «escribiendo…» gigante** baja a las filas 6-7 y se llena de puntos: **uno cada 1,5 s del mundo, tres en total** (aviso continuo, `sfx_boss4_typing` en cada punto: accesibilidad).
- **Interrumpirlo:** un **pulso** a la burbuja (desde el suelo, debajo de ella) antes del tercer punto **la deja en silencio** («la debilidad de Eco: el silencio», `04` §12.3, lo que contó la Papelera en el 4-2): El Visto queda **aturdido 3 s del mundo** con el check gris a la altura de las burbujas fijas: Debug → pulso → láser desde una burbuja. 
- **Si lo manda:** un mensaje gigante cruza la arena y **congela a Isak 2,5 s**; El Visto no ataca mientras dura (te está «mirando»: es el visto). **Agitar** libera al instante para llegar a la siguiente ventana; sin energía, se espera. Después vuelve a escribir.
- **Entre medias:** Fantasmas pequeños (2) que reaparecen por la espalda.
- **Golpe final:** el tercero; el doble check **se tacha**, queda solo el gris y **se desarma en píxeles** (`BossDefeat`, `PixelBurst`). 3 golpes.

### 5.7 Energía (estimación; la valida `tools/validate_boss.py`)

Mismos supuestos que la Curadora (pelea torpe: 3 s de Debug por ventana, un láser fallado por ventana y una ventana perdida por fase). Diferencia: la fase 2 gasta **2 Agitares** por ventana y la fase 3 uno por cada mensaje que llega.

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Golpes (láseres mínimos) | 9 (90) | 12 (120) | 12 (120) |
| Agitares mínimos | 6 (60) | 8 (80) | 8 (80) |
| Marca (`mark_duration_s`) | 4 s | 3 s | 2,5 s |
| Debug en la arena | ×0,25 (5/s), mundo ×0,7 | igual | igual |
| Cargadores | 4 de 4 s | 4 de 5 s | 4 de 6 s |
| Pico torpe estimado por ventana (margen sobre 100) | ~65 (≥ 30) | ~75 (≥ 25) | ~80 (≥ 20) |

**Palancas, solo en datos y por este orden:** `mark_duration_s`, enfriamiento de los cargadores, coste de Agitar en la arena (`shockwave_cost_scale`, como `debug_drain_scale`) y `debug_drain_scale`. Las mejoras de Calc ayudan pero nunca son requisito.

### 5.8 Kernel y Raíz (PROPUESTA a alto nivel; se cierran al hacer esas vueltas)

Decidido: «los puntos débiles cambian en cada vuelta».

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Fase 1 | Reaparece detrás | Dos siluetas; solo la del **rastro** es real (el Debug la señala) | Reaparece **delante** una vez de cada tres (el rastro lo dice) |
| Fase 2 | Un escudo, 2 Trolls | Escudo de dos capas (dos Agitares cerca) | Los Trolls imitan a los amigos (Debug) |
| Fase 3 | Un «escribiendo…», 1,5 s por punto | Dos «escribiendo…» (izquierda y derecha); solo uno es de verdad (Debug) | 1,0 s por punto y el mensaje lanza además una ola de «Visto» por la arena |
| Ocultarte (Kernel+) | — | El Visto «no te ve» oculto: no reaparece detrás (idea de `propuesta-mejoras.md` §4) | Igual; **nunca es requisito** |

### 5.9 Recompensa, vidas y vuelta al hub

1. **Golpe final** → desarme → **`BossReward.grant(4, vuelta)`** (ya existe): entrega `boss_w4_l1` en Caché **sin guardar** (más las capas inferiores que falten). Panel «Recuerdo recuperado», título «Fragmento de amistades», «Capa: Caché», texto (ya en datos, con «Eco: «Yo siempre estoy. Ellos no».») y «Guarda en Notas para conservarlo.». La ilustración `memory_art_w4` (borrosa en Caché) sale en Notas. Sin código nuevo.
2. **Eco** (línea de derrota, importante, **propuesto**): «Me quedo yo. Siempre me quedo yo.».
3. **Hub:** pieza coral, cuarta ranura del candado, Mundo 5 disponible, placa «!» en Notas (§4.6).
4. **Vidas y rollback (reglas vigentes, sin cambios):** 3 vidas por intento, se reponen al entrar desde la carpeta; **morir** reaparece al principio de la fase con energía ≥ 50; **game over** = `GameState.apply_rollback`: vuelta a la última copia guardada (lo no guardado se pierde, también la victoria y la capa del recuerdo), lo guardado a la **Papelera**, carpetas bloqueadas hasta recuperarlo. **Agitar sin guardar** se pierde con un game over y «¿Deshacer escritura?» vuelve a ofrecerlo; **la Linterna no** (aliada de registro). **R:** reinicia la pelea. **Sin rollback de jefe** (solo el jefe final).

### 5.10 Ayuda con Q (tipos nuevos del jefe, `world: 4`; textos «propuesto»)

| Tipo | Idea del texto |
|---|---|
| `seen_boss` | «Te lee y no contesta. Con el Debug se ve el que no ha leído. Márcalo con el pulso y dispárale.» |
| `seen_shield` (Objeto) | «Mucha gente alrededor. Agita cuando no quede nadie.» |
| `seen_typing` (Objeto) | «Está a punto de mandarlo. Si lo interrumpes, se queda callado.» |

---

## 6. Arte y sonido

### 6.1 Paleta del Mundo 4

- **Decidido:** azul marino y gris, burbujas **crema**, acento **verde apagado**, Debug **coral** (`07` §15.3); unos 16 colores más el del Debug en `assets/palettes/mundo4.gpl` (`07` §15.2).
- **Hex:** cierre del usuario (`CLAUDE.md`, decisión abierta). Como en el Mundo 3: hex provisionales por script en el paso 0 y **3 variantes completas con maqueta** en el paso 10 (`tools/palette_mundo4_variants.py`). **El coral se decide antes** porque ya se ve en el hub (pieza 4, `CORAL` de `tools/gen_hub_update_art.py`, antes `#ff7f66` provisional). **Decidido por el usuario el 2026-10-28: B `#ff9f7a`** (aplicado en el paso 0).
- **Opciones de coral para el usuario** (medidas con ΔE76 en Lab frente a los colores reservados: `alerta` `#ff4a2a`, rojo de daño; `ambar` `#ffa000`, puntos; `carmin` `#e0004a`, punto débil del Mundo 1; y contraste sobre un marino de referencia `#1a2238`):

| Opción | Hex | Tono | ΔE con el rojo de daño | ΔE con el ámbar | ΔE con el carmín | Contraste sobre marino | Lectura |
|---|---|---|---|---|---|---|---|
| **A «Coral salmón»** (la provisional) | `#ff7f66` | 10° | 30 | 47 | 36 | 6,4:1 | La más «coral» de libro; la más cercana al rojo de daño (bajo el tinte del Debug, el rojo pierde distancia). |
| **B «Coral melocotón»** (RECOMENDADA; **ELEGIDA** 2026-10-28) | `#ff9f7a` | 17° | **44** | 44 | 51 | **7,9:1** | Más clara y cálida; la que más se separa a la vez del rojo, del ámbar y del carmín, y la que más contrasta sobre el marino. Tinte de madrugada, «luz de pantalla». |
| **C «Coral rosado»** | `#f78fa0` | 350° | **56** | 71 | 44 | 7,1:1 | La más lejos del rojo de daño, pero tira a rosa (recuerda al Mundo 3). |

- **Reglas que toda variante debe cumplir** (las comprueba `--check`):
  1. **Coral frente al rojo de daño** (`alerta`) y al punto débil: ΔE ≥ 30, también con el tinte del Debug; **lo que daña conserva su contorno `alerta_sombra`** en la oscuridad y bajo el velo del congelado.
  2. **Crema de las burbujas frente al ámbar de los puntos:** ΔE ≥ 20; los puntos de atención llevan el **contorno oscuro de 1 px** también en el Mundo 4 (`AttentionPoint.has_outline()` pasa a «mundos 2-4»).
  3. **Cian de Eco y de Isak sobre marino:** ≥ 3:1 (medido en capturas como en el 1-2); **los tres puntos de Eco son cian** y los del «escribiendo…» son **crema sobre la burbuja**: nunca del mismo color (§6.3).
  4. **Verde apagado del «Visto» frente al verde ácido del Mundo 3:** saturación ≤ 40 % (el Debug del Mundo 3 no aparece en el Mundo 4, pero el hub los enseña juntos).
  5. **Modo oscuro:** el contorno de lo que daña, los puntos del «escribiendo…» y los checks del «Visto» con contraste ≥ 3:1 sobre el velo.

### 6.2 Qué se hace con AutoSprite y qué por script

Precios: personaje 3, pose 3, animación turbo 5, `upload_character` y `regenerate_*` 0. **Saldo: 315** (2026-10-27). **No se gasta nada sin permiso del usuario**, que recibe el total antes y con **parada tras cada personaje base** (regla de los Mundos 2 y 3).

| Pieza | Vía | Créditos (una pasada) | Con un reintento por pieza |
|---|---|---|---|
| **El Visto** (doble check con aura): base (+ recorte y `upload_character` si la IA pinta un personaje, como Autoplay), poses `Watching`, `Vanished` y `Typing`, y animaciones turbo `idle`, `vanish`, `reappear`, `shield`, `typing` y `defeat` | AutoSprite | 3 + 9 + 30 = **42** | 84 |
| **Troll** (perfil anónimo con personalidad): base, una pose y animaciones `idle`, `typing_shot` y `stunned` | AutoSprite | 3 + 3 + 15 = **21** | 42 |
| **Pose `shockwave` de Isak** (sacudir el celular y la onda) | AutoSprite sobre el personaje «Isak» (precedentes: dash, golpe al suelo y `compress`) | **5** (+3 si hace falta una pose) | 10-16 |
| **Total recomendado** | | **68-71** (saldo después: **~244-247**) | **136-142** (~173-179) |
| Fantasma, Sticker, Troll disfrazado (reutiliza el Troll y la burbuja), burbujas (fija, «escribiendo…», autocorrector, eliminada, de amigo con avatar), zona «Visto», ola, muro de texto, «¿Deshacer escritura?», Linterna y su luz, Modo oscuro, Papelera en el nivel (su arte del hub), tileset y fondo del chat, carteles, fichas del álbum, miniaturas de nivel, miniatura de la carpeta M4, pieza coral del hub, piezas de interfaz del jefe (escudo, «escribiendo…» gigante, barra «conversación»), variante de Eco | **Script** (`tools/gen_world4_*.py` con validador de paleta) | 0 | 0 |

- **Por qué así:** la familia de formas del Mundo 4 son **burbujas de texto** (`07` §15.5): formas redondeadas y texto que el script resuelve bien. La IA aporta en el jefe y en la única criatura con cara y gesto (el Troll). El Fantasma es una sábana translúcida y el Sticker una cara redonda inventada: por script.
- **Margen para los Mundos 5-6:** tras el Mundo 4 quedarían ~245 en una pasada: caben 2 jefes (~84) y 2 enemigos (~42) con ~120 de reserva.
- **Hasta tener el arte final:** todo por script (sufijo `_placeholder` en El Visto y el Troll). La pose `shockwave` es provisional por código (sacudida del sprite + onda), como las de los otros gestos antes de su hoja.
- **Decisión del usuario (2026-10-28): no se usa AutoSprite ni se gastan créditos por ahora.** Todos los personajes, enemigos y el jefe nuevos (El Visto, el Troll, la pose de Agitar…) se hacen como **placeholders temporales generados por script** (`tools/gen_*_art.py` / `tools/gen_world4_*.py`, como el resto del arte provisional). Los diseños finales con AutoSprite se hacen **después**, cuando los 3 niveles y las mecánicas del jefe estén listos (paso 24, que va tras el 22), y siguen necesitando el permiso con el total previo y la parada tras cada personaje base.

### 6.3 Por script (detalle)

- `tools/gen_world4_tiles.py`: tileset del chat (suelo de «barra de escribir» con borde gris, paredes de lista de chats, plataforma de una vía «burbuja»); `data/tileset_mundo4.json`.
- `tools/gen_world4_background.py`: fondo horizontal en capas (lista de chats en paralaje con avatares apagados y contadores de no leídos, sin costura) y **fachada vertical** para la torre del 4-1 (como `tools/gen_world1_facade.py`).
- `tools/gen_world4_objects.py`: burbujas por ancho (izquierda / derecha, de amigo con avatar e inicial, eliminada), «escribiendo…» (3 puntos), cursor del autocorrector, zona «Visto» (3 estados), ola (borde y velo «Leído»), muro de texto, «¿Deshacer escritura?», Linterna, velo del Modo oscuro, `ink_only`, carteles, miniaturas de nivel, `world_icon_m4`.
- `tools/gen_world4_enemies.py`: Fantasma, Sticker, Troll provisional, proyectil de texto.
- `tools/gen_eco_companion.py`: variante del Mundo 4 de Eco: **tres puntos cian que laten, sin esfera** (`04` §12.1), con el mismo halo dorado de la Q. Se distingue del «escribiendo…»: los de Eco **flotan juntos a Isak, en cian y sin burbuja**; los del nivel son **crema dentro de una burbuja con contorno**.
- `tools/gen_boss_seen.py`: piezas de interfaz del jefe y cuerpo provisional.
- `tools/gen_hub_update_art.py` (constante `CORAL`) y `tools/gen_hub_piece_w4.py`: la pieza coral con el hex elegido.

### 6.4 Sonido

IDs de `lista-sonidos.md` (los del Mundo 4 ya listados) y nuevos. Se conectan en `data/audio.json` a señales; archivo ausente = silencio; provisionales de `tools/gen_audio_placeholders.py`; los definitivos los hace el amigo del usuario con el mismo nombre (= ID).

| ID | Cuándo | Origen |
|---|---|---|
| `sfx_gesture_shake` | Agitar (onda) | `lista-sonidos.md` |
| `sfx_w4_typing` | «Escribiendo…» (cada punto; **accesibilidad**: anticipa el salto) | idem |
| `sfx_w4_bubble_pop_in` | Burbuja que aparece | idem |
| `sfx_w4_seen_freeze` / `sfx_w4_seen_break` | Congelarse / romper la congelación | idem |
| `sfx_w4_troll_shot` | Proyectil de texto | idem |
| `sfx_w4_ghost_vanish` / `sfx_w4_ghost_appear` | Fantasma (aparición **posicional**, detrás de Isak) | idem |
| `sfx_w4_autocorrect` | Autocorrector (con el cursor) | idem |
| `sfx_w4_sticker_explode` | Sticker | idem |
| `amb_w4_chat_night`, `mus_w4_level`, `mus_boss4` | Ambiente, nivel (tecleo como ritmo; **capa de silencio** cerca de las burbujas de amigos) y jefe | idem |
| **Nuevos (PROPUESTA):** `sfx_w4_seen_interrupt` (pulso a la zona), `sfx_w4_seen_wave` (bucle por nodo que sube al acercarse: **accesibilidad**), `sfx_w4_undo` (obtener Agitar), `sfx_w4_typed_wall_erase`, `sfx_w4_message_deleted`, `sfx_w4_flashlight_on`, `sfx_boss4_intro`, `sfx_boss4_vanish` (posicional), `sfx_boss4_shield_break`, `sfx_boss4_typing` (**accesibilidad**: cada punto), `sfx_boss4_send` | — | nuevos |
| Reutilizados | `sfx_weak_point_mark` / `_warn` / `_end`, `sfx_weak_point_hit`, `sfx_boss_phase_change`, `sfx_boss_defeat` → `stg_boss_defeated` → `mus_memory`, `sfx_hub_wallpaper_piece`, `sfx_memory_pickup` | — |

- **Accesibilidad:** «Señales sonoras de ritmo» (activada por defecto) cubre el «escribiendo…», la ola y el «escribiendo…» del jefe. La **capa de silencio** nunca es la única pista: las burbujas de amigos llevan avatar.

---

## 7. Validación: validador, bots y pruebas

### 7.1 Validador de niveles (`tools/validate_level.py` + `tools/level_plan.py` + `tools/world4_model.py` nuevo)

- **Burbujas:** el esquema comprueba que `width` cuadra con `text` (§3.1) y que las burbujas de amigo no son destructibles. Son plataformas de una vía para el grafo.
- **«Escribiendo…»:** plataforma sólida desde `t0 + 1,0 s` del disparo (con ciclo, en sus ventanas); el camino exportado gana el paso **`wait_typing`**; se acepta el salto que **despega antes** de que exista si aterriza después.
- **Autocorrector:** dos estados por posición de Isak; el plan no puede contar con el ancho «antes» una vez disparado; regla «engaña, no mata» (caída ≤ 3 tiles con salida).
- **«Visto»:** zonas como peligro de tiempo (congelación = coste en segundos, sin daño); arista **`pulse_seen`** que la interrumpe 4 s; ciclos. **Regla del 4-1:** ningún peligro alcanza a Isak congelado si `shockwave` no está disponible.
- **Agitar:** habilidad del grafo (`abilities_available.shockwave` o el `undo_prompt`, que es una puerta); `typed_wall` exige Agitar; aturde grupos en su radio; 10 de energía en el presupuesto; los 0,25 s expuestos cuentan en las amenazas.
- **Ola:** amenaza móvil en X con secciones y paradas (generaliza `tools/scroll_model.py`); `validation.wave_margin_tiles` (propuesto: 3 en Caché); el plan nunca la toca; esperas **`wait_wave`** en las paradas.
- **Linterna y oscuridad:** `dark_zone` y `ink_only` (solo con la Linterna conocida o recogida en el nivel); regla de legibilidad de §3.6 (lo que daña, los puntos y los checks siempre visibles).
- **Enemigos:** Troll (línea horizontal y proyectiles con fase, como los Comentaristas), Troll disfrazado (Debug para distinguirlo si tapa el camino), Fantasma (reaparición detrás con su retraso: el plan lo aturde o no se detiene), Sticker (persecución e inflado, como el punto rojo).
- **Secretos:** `forbid_abilities`, `requires_abilities` (Pellizcar en el 4-1 B y el 4-2 A) y recompensa `memory`; `ink_only` como requisito «Linterna».
- **Camino exportado** (`isak-path/1`): pasos nuevos `shake`, `wait_typing`, `pulse_seen`, `wait_autocorrect`, `wait_ghost` y `wait_wave`.
- **Pasadas:** sin mejoras, con mejoras, `--access-cap` y todo al máximo. **La salida del 1-1 al 3-3 y de las arenas tiene que ser idéntica byte a byte.**
- **Negativos sintéticos** (`tests/test_world4_validator.py`): sin Agitar el muro no se cruza; «escribiendo…» que pide saltar antes de 1,0 s; zona «Visto» obligatoria sin check a tiro de pulso; peligro que alcanza al congelado en el 4-1; ola que alcanza si el camino se para; autocorrector que deja un pozo mortal; Troll disfrazado que solo se distingue sin Debug disponible.

### 7.2 Validador de arenas (`tools/validate_boss.py`)

Rama `validate_seen_arena` (las otras no cambian): en la fase 1, que la reaparición quede a ≤ 96 px de algún punto que Isak pueda ocupar con 1,2 s de ventana; en la fase 2, que el escudo esté a ≤ 2,5 tiles del borde interior de una burbuja fija y que la arena se pueda limpiar con un Agitar desde el suelo; en la fase 3, que la burbuja quede a tiro de pulso desde el suelo y que nada dañe a Isak congelado; ventanas con k = 2; avisos de 6-12 cuadros; **energía torpe por acceso** (pico ≤ máximo − 20) y cargador a ≤ 4 tiles.

### 7.3 Bots

- **Bot del chat** (`tools/chat_bot.gd` + `tools/play_chat_bot.gd`): **extiende `tools/gallery_bot.gd`** (horizontal, Pellizcar, likes inertes aquí) y, por su base `tower_bot.gd`, recorre también la torre del 4-1. Pasos nuevos `shake`, `wait_typing`, `pulse_seen`, `wait_autocorrect`, `wait_ghost` y `wait_wave`. Comprobaciones: completa el nivel y vuelve al hub con él en `completed_levels`; 0 muertes; 0 contactos con la ola; 0 congelaciones fuera de las obligatorias; energía mínima frente al camino; duración anotada **frente al 40-55 % del objetivo** (§4). El 4-1 recoge la Linterna; el 4-2 empieza sin Agitar y lo obtiene en «¿Deshacer escritura?» (y cierra las líneas de la Papelera).
- **Bot del jefe** (`tools/seen_bot.gd`, lanzador `tools/play_boss_bot.gd -- --boss seen`): política por fase (fase 1: Debug al ver el rastro, girarse y pulso + láser en la reaparición; fase 2: Agitar en el suelo, subir, Agitar al escudo y la ventana en el suelo; fase 3: pulso a la burbuja antes del tercer punto, Agitar si llega el mensaje). Perfiles `ideal`, `clumsy` (`validation_model` de `data/bosses/seen.json`) e `idle`, y `--lap 1|2|3`. Comprueba `boss_w4_l<n>` sin guardar y la vuelta al hub con el Mundo 5 disponible y la pieza coral. Objetivo: ideal en Caché entre **100 y 150 s**.
- **En la suite** (`tools/run_tests.sh`), como los de los Mundos 2 y 3 (proceso aparte).

### 7.4 Pruebas GUT y de Python necesarias

| Prueba | Qué comprueba |
|---|---|
| `tests/test_shockwave.gd` | Radio, coste, enfriamiento, exposición, solo en el suelo salvo congelado, con el Debug sí, comprimido no, apaga el Ocultarte, aviso y reasignación |
| `tests/test_frozen.gd` | Conserva la velocidad, duraciones, Agitar libera, invulnerabilidad de 0,5 s frente a otra zona, muerte congelado |
| `tests/test_seen_zone.gd` / `tests/test_seen_wave.gd` | Estados y ciclo, pulso que interrumpe; ola por secciones, paradas, −10 sin matar, retroceso de 4 tiles frente a 1 tile con Agitar, muerte |
| `tests/test_chat_bubbles.gd` | Ancho por texto, «escribiendo…» a 1,0 s y que no se materializa con Isak dentro, autocorrector con cursor de 0,75 s y vuelta al reaparecer |
| `tests/test_flashlight.gd` | Recogida, aliada de registro (game over no la quita), luz solo en zonas oscuras, `ink_only`, hueco del hub |
| `tests/test_world4_enemies.gd` | Troll (aviso, proyectil, aturdido, láser), disfrazado (Debug), Fantasma (reaparición detrás, rastro), Sticker (inflado, Agitar, +5) |
| `tests/test_undo_prompt.gd` | Un uso, guardado, Papelera y rollback; Papelera y Eco; muro de texto |
| `tests/test_world4_validator.py` | Modelos y negativos de §7.1 |
| `tests/test_level_4_1.py/.gd`, `4_2`, `4_3` | Estructura, secretos, economía y flujo hub → nivel → hub |
| `tests/test_seen_boss.gd` | Sin Debug no hay marca; cada fase pone el punto débil a tiro; un golpe por marca; escudo con la arena limpia; congelado sin ataques |
| `tests/test_boss_validator.py` (rama nueva) | §7.2 |
| `tests/test_chat_bot.gd`, `tests/test_seen_bot.gd` | Bots en la suite |
| `tests/test_world4_negatives.gd` / `.py` | Quieto pierde; sin Agitar no se sale de «Mensajes borrados»; congelarse no mata; la ola no mata sola; Kernel/Raíz sin cambios en los Mundos 1-3 |
| `tests/test_palette_mundo4.py` | Reglas de §6.1 |

---

## 8. Plan de implementación

Pasos pequeños, como en los Mundos 2 y 3. Cada paso lleva sus pruebas y **termina con la parte afectada de `tools/run_tests.sh` en verde (la suite completa en los pasos 21-22) y `graphify update .`**. El arte es por script (`_placeholder` en El Visto y el Troll) hasta el paso 24. Los textos se marcan como propuestos. **Un commit local por paso, sin push**, con mensaje «Mundo 4, paso N: …» y la línea de coautoría. Las decisiones que surjan se anotan en una sección «Avance y desvíos» (§8.1, vacía hasta empezar).

| Paso | Qué | Archivos probables | Terminado cuando | Tamaño | Depende de | En paralelo con |
|---|---|---|---|---|---|---|
| 0 | **Paleta provisional** por script con el coral elegido (B `#ff9f7a`, §10.1) y las reglas de §6.1 en `--check`; `palette` de `data/world4_objects.json` | `tools/palette_mundo4_provisional.py`, `assets/palettes/mundo4_provisional.gpl`, `data/world4_objects.json`, `tests/test_palette_mundo4.py` | `--check` en la suite | S | — | 1, 2 |
| 1 | **Agitar en Isak:** estado `Shockwave` (onda, coste, exposición, enfriamiento, reglas con Debug, dash, golpe, pulso, láser, Pellizcar, Ocultarte, vórtices); valores en `data/isak_abilities.json`; aviso y fila en Ajustes > Controles; pose provisional; `test_arena` con el gesto | `scripts/player/states/shockwave_state.gd`, `scripts/player/isak.gd`, `data/ability_notices.json`, `scripts/ui/control_bindings.gd`, `tests/test_shockwave.gd` | GUT de §7.4 | M | — | 0, 2 |
| 2 | **Congelado** (estado `Frozen`) y **zona «Visto»** (estados, ciclo, pulso que interrumpe); sala `visto_test` | `scripts/player/states/frozen_state.gd`, `scripts/levels/seen_zone.gd`, `tests/test_frozen.gd`, `tests/test_seen_zone.gd` | GUT: conserva la velocidad, Agitar libera, el pulso interrumpe 4 s | M | 1 | 3 |
| 3 | **Burbujas:** `chat_bubble` (ancho por texto en `build_level.py` y en el esquema), `typing_bubble`, `autocorrect_bubble`; sala `burbujas_test` | `scripts/levels/chat_bubble.gd`, `scripts/levels/typing_bubble.gd`, `scripts/levels/autocorrect_bubble.gd`, `tools/build_level.py`, `tools/validate_level_schema.py`, `tests/test_chat_bubbles.gd` | GUT y esquema | M | 0 | 2, 4 |
| 4 | **Linterna y Modo oscuro:** `flashlight_pickup`, `dark_zone`, `ink_only`, aliada de registro, hueco del hub; sala `oscuro_test` | `scripts/levels/flashlight_pickup.gd`, `scripts/levels/dark_zone.gd`, `scripts/player/flashlight_companion.gd`, `data/hub.json`, `tests/test_flashlight.gd` | GUT de §7.4; el hueco se enciende | M | 0 | 3, 5 |
| 5 | **Troll, Troll disfrazado y Sticker**; sala `grupo_test` | `scripts/enemies/troll.gd`, `scripts/enemies/troll_mimic.gd`, `scripts/enemies/sticker.gd`, `data/enemies/*.json`, `tests/test_world4_enemies.gd` | GUT: avisos, aturdido, Agitar en grupo | M | 1 | 4, 6 |
| 6 | **Fantasma** (reaparición detrás, rastro con el Debug); sala `fantasmas_test` | `scripts/enemies/ghost.gd`, `tests/test_world4_enemies.gd` | GUT: 1,0 s, 2 tiles detrás, aviso de 9 cuadros, rastro | S-M | — | 5, 7 |
| 7 | **Ola de «Visto»** (secciones, paradas, −10 sin matar, retroceso frente a Agitar, muerte); sala `ola_test` | `scripts/levels/seen_wave.gd`, `tests/test_seen_wave.gd` | GUT de §7.4 | M | 2 | 6, 8 |
| 8 | **«¿Deshacer escritura?», muro de texto y Papelera en el nivel** (actor, líneas, `seen_notices`, interlocutor `papelera`); sala `borrados_test` | `scripts/levels/undo_prompt.gd`, `scripts/levels/typed_wall.gd`, `scripts/levels/papelera_actor.gd`, `data/eco_text_box.json`, `tests/test_undo_prompt.gd` | GUT: un uso, guardado, Papelera y rollback; la escena de historia | S-M | 1 | 7 |
| 9 | **Validador y camino exportado** (§7.1), en dos partes: 9a burbujas, «escribiendo…», autocorrector, «Visto», congelado, Agitar, oscuridad; 9b enemigos, Fantasma, ola, muro; negativos | `tools/validate_level.py`, `tools/level_plan.py`, `tools/world4_model.py`, `tools/scroll_model.py`, `tests/test_world4_validator.py` | Salas 2-8 validan; negativos fallan; salidas de los Mundos 1-3 idénticas | **XL** | 1-8 | 10 |
| 10 | **Arte por script del mundo** (§6.3), Eco de tres puntos, ayudas Q (`world: 4`) y fichas del álbum; **3 variantes de paleta** con maqueta y aplicar la elegida | `tools/gen_world4_*.py` + validadores, `tools/palette_mundo4_variants.py`, `data/help.json`, `tools/gen_album_cards.py` | Validadores en la suite; contraste ≥ 3:1 en capturas; paleta elegida | L | 0, 2-8 | 9 |
| 11 | **El 4-1 real** (§4.1, torre) + filas M4 en `data/hub.json` + `msg_4_1` + vida extra + Linterna + miniatura M4 | `data/levels/4-1.json`, `scenes/levels/4-1.tscn`, `data/hub.json`, `data/memories.json`, `tests/test_level_4_1.py/.gd`, `tests/fixtures/climbs_4-1.json` | Valida en todas las pasadas con camino exportado; jugable desde la carpeta M4 | L | 9, 10 | 12 |
| 12 | **Bot del chat** recorriendo el 4-1 | `tools/chat_bot.gd`, `tools/play_chat_bot.gd`, `tests/test_chat_bot.gd` | Código 0; duración en el 40-55 % del objetivo (si no, se ajusta el nivel) | M-L | 11 | 13 |
| 13 | **El 4-2 real** (§4.2) + `msg_4_2` + bot (obtiene Agitar) | `data/levels/4-2.json`, `tests/test_level_4_2.*` | Valida; el bot lo completa; los secretos A (Pellizcar + Linterna) y B validan | L | 9-12 | 15 |
| 14 | **El 4-3 real** (§4.3) + `msg_4_3` + bot + **cierre según V15** (§10.2) | `data/levels/4-3.json`, `tests/test_level_4_3.*` | Valida (ola, disfrazados, huecos crecientes); el bot lo completa sin tocar la ola; desbloquea la fila del jefe | L | 13 y V15 | 15-17 |
| 15 | **Datos y lógica de El Visto:** `data/bosses/seen.json` (fases, ataques, `laps` con `mark_hits`), `WeakPoint` en cada fase, escudo | `scripts/bosses/seen.gd`, `tests/test_seen_boss.gd` | GUT: sin Debug no hay marca; un golpe por marca; escudo con la arena limpia | M | 1, 2, 5, 6 | 11-14 |
| 16 | **Arena `4-boss`** y **fases 1-3** | `data/levels/4-boss.json`, `scripts/bosses/seen.gd` | GUT de cada fase con el tiempo avanzado a mano; cabe en pantalla | L | 15 | 11-14 |
| 17 | **Validador de arenas** para El Visto (§7.2) | `tools/validate_boss.py`, `tests/test_boss_validator.py` | Márgenes de energía torpe ≥ 20 en los tres accesos | M | 16 | 18 |
| 18 | **Barra «conversación», recompensa y hub:** `BossBar` con su estilo, `BossReward.grant(4, …)`, pieza coral, cuarta ranura, M5 disponible, fila «Jefe: El Visto», línea de Calc | `data/hud.json`, `data/hub.json`, `tools/gen_hub_piece_w4.py`, `tests/test_hub_boss_entry.gd` | Desde la carpeta M4 se entra, se vence, se recibe `boss_w4_l1` sin guardar y se vuelve con la pieza coral y M5 disponible | S-M | 16 | 17 |
| 19 | **Bot del jefe** (ideal / torpe / quieto, `--lap 1-3`) | `tools/seen_bot.gd`, `tests/test_seen_bot.gd` | Ideal y torpe vencen sin muertes; quieto pierde; ideal en Caché entre 100 y 150 s | M-L | 16-18 | 20 |
| 20 | **Textos, ayudas Q y audio:** líneas de Eco, Papelera y El Visto, ayudas, carteles, IDs de §6.4 con provisionales | `data/bosses/seen.json`, `data/help.json`, `data/audio.json`, `tools/gen_audio_placeholders.py` | `validate_audio.py` pasa; la Q explica cada tipo nuevo | S | 15-18 | 19 |
| 21 | **Pruebas de conjunto:** negativos de §7.4, salidas del validador de los Mundos 1-3 idénticas, rejugar M1-M3 con Agitar | `tests/*`, `tools/run_tests.sh` | Suite completa en verde con los bots del Mundo 4 | S | 11-20 | — |
| 22 | **Capturas, mapas y docs** (`mundo-4-chat.md` §9.8, `08-pendientes.md`, `CLAUDE.md`, `INDEX.md`, `05-hub.md`) | `tools/render_level_4_x.gd`, `tools/render_level_map.py` | Capturas en `assets/levels_preview/4-x/`; mapas al día | S-M | 21 | 23 |
| 23 | **Lista de revisión del usuario** (§11) volcada a `preguntas.md` | `docs/preguntas.md` | Lista publicada | S | 22 | — |
| 24 | **Arte final con AutoSprite** (con permiso y total previo; parada tras cada base): El Visto, Troll y pose `shockwave` (§6.2). **Orden decidido por el usuario (2026-10-28):** solo cuando los 3 niveles (pasos 11-14) y las mecánicas del jefe (pasos 15-19) estén terminados y probados; hasta entonces, placeholders por script y ningún crédito gastado | `docs/plan-arte-mundo-4.md`, `tools/import_boss_seen.py`, `tools/reduce_palette.py` | Integrado sin cambiar tiempos ni cajas; los bots dan los mismos resultados | M | 22 y permiso | — |

**Orden:** 0, 1 y 3 a la vez → 2, 4, 5 y 6 (máximo 3-4 subagentes a la vez: 2+4, 5+6) → 7 y 8 → 9 y 10 en paralelo → 11 → 12 → 13 → 14. El jefe (15-20) puede empezar tras el 6, en paralelo con los niveles 11-14 → 21 → 22 → 23 → 24. **25 pasos en total (0-24).**

**Tamaño relativo (estimación):**

| | Mundo 3 | Mundo 4 |
|---|---|---|
| Habilidad nueva | Pellizcar (cambia la caja) | Agitar (área, más simple) + **estado Congelado** (toca el control de Isak) |
| Aliada | — | Linterna (luz y zonas oscuras) |
| Cámara | Ninguna nueva | Ninguna nueva (torre del 1-2 y horizontal del 1-1) |
| Amenaza móvil | — | Ola de «Visto» (generaliza el scroll del Mundo 2) |
| Tipos nuevos | ~14 | ~13, casi todos sobre piezas existentes |
| Validador | Caja comprimida, likes, espejos, reflejo | Plataformas que llegan tarde, congelación como tiempo, ola en X, Agitar en grupo |
| Jefe | `BossBase`, `WeakPoint` | Igual; tres fases que reutilizan los tipos del mundo |
| **Total** | ≈ 55-65 % del Mundo 1 | **≈ 65-75 %** del Mundo 1 |

### 8.1 Avance y desvíos

Cada paso hecho se anota aquí con su fecha, lo que se hizo, los desvíos y, si hace falta decidir algo, la entrada «Decisión tomada» con su razón.

- **Decisiones del usuario (2026-10-28):** las cuatro de §10 quedan tomadas (coral B, V15 sin elección en Caché, amigos como remitentes, arte por script y AutoSprite al final). Se aplican desde el paso 0.
- **Paso 0 (2026-10-28), paleta provisional:** `tools/palette_mundo4_provisional.py` (16 colores + `debug_coral` `#ff9f7a`; `--check` con las 5 reglas de §6.1 y la coincidencia del coral en la paleta, `debug_colors["4"]` de `data/hud.json` y `CORAL` de `tools/gen_hub_update_art.py`), `assets/palettes/mundo4_provisional.gpl`, `data/world4_objects.json` (nuevo: `types` vacío y `palette`), `tests/test_palette_mundo4.py` y la entrada en `tools/run_tests.sh`. Coral aplicado: `CORAL` del generador del hub (pieza 4 regenerada), `debug_colors["4"]` (era `#ff7f6b`), los respaldos de `scripts/hub/hub_room.gd` y `data/hub.json`. **Desvíos:** (1) clase nueva `World4ObjectsConfig` (`scripts/levels/world4_objects_config.gd`) y contorno de los puntos de atención también en el Mundo 4 (`AttentionPoint.has_outline()`, regla 2, con `chat_noche`; prueba en `tests/test_attention_point_outline.gd`), adelantados del paso 10 porque la regla los pide; (2) medidas concretas de los velos (no estaban en el doc): Modo oscuro = `chat_noche` al 60 %, congelado = `gris_oscuro` al 50 % (con `gris_medio` el contorno rojo se quedaba en 2,4:1); se revisan en los pasos 2 y 4; (3) la regla 1 compara el rojo de daño y el carmín **tenidos** por el Debug con el coral sin tenir (el de los contornos del Debug): la A `#ff7f66` da 22 y falla, la B da 34.
- **Paso 1 (2026-10-28), Agitar en Isak:** estado `ShockwaveState` (`scripts/player/states/shockwave_state.gd`; `PlayerState.SHOCKWAVE`): pulsar `gesture_shake` (U / LB) en el suelo → 0,15 s de sacudida, la onda (`ShockwaveWave`, círculo de 160 px alrededor del celular: aturde 3 s a todos los enemigos que alcanza por los dos lados, 0 de daño; `receive_shockwave(center, radius, stun_s)` para los que deciden ellos) y 0,25 s expuesto sin moverse ni saltar y sin invulnerabilidad; 10 de energía (sin ella, chispa gris y `EventBus.shockwave_denied`), enfriamiento de 1 s desde el final de la pose, con el Debug sí, no comprimido ni durante el pulso, el láser, el dash o el golpe al suelo (y al revés), no sale sin la habilidad ni en el hub, apaga el Ocultarte (`HideMode.REASON_SHOCKWAVE`), un golpe lo corta, reaparecer lo limpia. Valores en la sección `shockwave` de `data/isak_abilities.json`; señales `Isak.shockwave_fired` y `EventBus.shockwave_fired(center, radius, source)` (los proyectiles de texto se engancharán ahí en el paso 5); efecto provisional `ShockwaveEffect` (sacudida del sprite y anillo); aviso «Agitar: U / LB (mando)» (`data/ability_notices.json`), fila **Agitar** tras Pellizcar en Ajustes > Controles (`data/settings.json`), `test_arena` con el gesto y `tests/test_shockwave.gd` (18 pruebas). **Desvíos:** (1) la **excepción del congelado** (Agitar en el aire y romper la congelación) queda para el **paso 2**, que crea el estado `Frozen`; hoy en el aire se niega (`SHOCKWAVE_DENIED_AIR`, sin aviso) — **hecha en el paso 2**; (2) la energía se cobra al **empezar** la pose (como el dash); si un golpe la corta antes de la onda, no sale la onda; (3) la pose provisional reutiliza la animación del pulso (sube el celular) con la sacudida por código; la pose final es del paso 24; (4) el aturdimiento de 3 s se consigue con la escala de `stun()` de cada enemigo (`stun_s` o `stun_duration_s`); (5) con Agitar reasignable, U y LB ya son de una fila de Ajustes: las pruebas de `tests/test_controls.gd` y `tests/test_hide_mode.gd` que usaban U o LB como teclas libres pasan a O y a la cruceta arriba; `tests/test_test_arena.gd` y `tests/test_debug_sandbox.gd` devuelven Agitar al terminar (la `test_arena` lo desbloquea).
- **Paso 2 (2026-10-28), Congelado y zona «Visto»:** estado **`FrozenState`** (`scripts/player/states/frozen_state.gd`; `PlayerState.FROZEN`) que se pide con `Isak.freeze(segundos, fuente)` (`FREEZE_SOURCE_ZONE` / `_WAVE` / `_BOSS`; la duración la pone quien congela: zona 1,5 s, ola 2,0 s, El Visto 2,5 s): Isak queda quieto donde está, también en el aire (sin gravedad), con la velocidad guardada y devuelta al salir; cuenta en tiempo del mundo (el Debug la alarga); sin pulso, láser (corta el que estaba en curso), dash, golpe al suelo, Pellizcar ni Ocultarte; un vórtice o la pose de espaldas lo cortan; morir y reaparecer lo limpian. **Agitar congelado** sale también en el aire (la excepción pendiente del paso 1): la onda nace **al instante** (sin los 0,15 s de anticipación), cobra los 10 de energía y sigue la exposición de 0,25 s. Inmunidad de `frozen.seen_immunity_s` (0,5 s, tiempo del mundo) tras descongelarse, solo frente a otra zona. Señales `Isak.frozen_started(seconds, source)` y `frozen_ended(broken)` (`broken` = por Agitar, para la ola del paso 7). Efecto provisional `FrozenEffect` (velo de la escena en `gris_oscuro` al 50 %, doble check en `verde_apagado` sobre la cabeza y barra de 4 segmentos en crema). Sección `frozen` de `data/isak_abilities.json`. **Zona «Visto»** (`seen_zone`, `SeenZone`, `scripts/levels/seen_zone.gd`; primer tipo de `data/world4_objects.json`, sección `seen_zone`): 1-4 × 1-3 tiles sin colisión ni daño, estados en espera / aviso / activa / interrumpida, siempre activa o con ciclo `on_s` / `off_s` y desfase `phase_s`, aviso de 9 cuadros a 12 fps (los checks se rellenan de uno en uno), el pulso al doble check (lado `icon`) la interrumpe 4 s del mundo, vuelve a su estado inicial al reaparecer. Esquema: `shockwave` en `abilities_available`, `seen_zone` fuera del terreno, `on_s` y `off_s` juntos y la celda de fuera junto al doble check libre. Sala **`visto_test`** (36 × 12, `-- --start-level=visto_test`). Pruebas `tests/test_frozen.gd` (15) y `tests/test_seen_zone.gd` (14). **Decisiones tomadas** (el doc no lo decía): (1) **un golpe congelado no descongela ni empuja**: resta (lo pone quien golpea), da su invulnerabilidad y avisa, pero Isak sigue congelado; *razón:* si el daño liberase, los enemigos serían una salida gratis y Agitar dejaría de ser la decisión «gastar 10 o esperar» (§3.3); (2) **Agitar desde el congelado sin anticipación**: «rompe la congelación al instante» (§3.3) se lee literal; la exposición de 0,25 s se mantiene (en el aire, cayendo); (3) **el dash no protege** de la congelación (no es daño) y no se puede empezar congelado; (4) **otra congelación encima solo alarga la cuenta** si es más larga (no hay cadenas ni señal nueva); (5) **el doble check va a media altura del borde lateral** (`icon`: `left` / `right`, zona de golpe de 36 × 28 px a caballo del borde), para pulsarlo desde fuera; (6) **la interrupción para el ciclo** (la cuenta sigue donde estaba al terminar) y, si al volver toca estar activa, el aviso de 9 cuadros sale al final de la interrupción (`is_rearming`); (7) **un ciclo empieza activo** (`on_s` primero, luego `off_s` con el aviso al final), desplazable con `phase_s`; (8) **la inmunidad corre en tiempo del mundo** como la zona; (9) **el velo cubre la escena** (no solo a Isak), como mide la regla 5 de la paleta; (10) `frozen_ended` se emite también al morir o reaparecer congelado (con `broken` falso); la ola (paso 7) debe ignorar ese caso porque la muerte ya la devuelve a su parada. **Desvíos:** sin Q ni ficha todavía (`help_id` `seen_zone` y su texto van en el paso 10, como hizo el Mundo 3; el esquema exige que el `help_id` exista en `data/help.json`); el validador aún no modela la zona (paso 9: arista `pulse_seen` y congelación como coste de tiempo), así que en `visto_test` solo valida «andar de P a G».
- **Paso 3 (2026-10-28), burbujas:** **`chat_bubble`** (`ChatBubble`, `scripts/levels/chat_bubble.gd`): plataforma de una vía (tarjeta de 32 px arriba de su celda, como una `-`) con `text`, autor (`side`), sello de hora (`stamp`), amigo (`friend`: avatar con la inicial) y `deleted` («Se eliminó este mensaje», contorno discontinuo sin colisión); largo = 1 tile por cada 6 caracteres, entre 1 y 8 (`ChatBubble.width_for_text` y `bubble_width` de `tools/build_level.py`, que lo escribe en `width_tiles`; el esquema rechaza uno que no cuadre); señal `stepped` al pisarla. **`typing_bubble`** (`TypingBubble`): no existe hasta que se dispara (`trigger`: id de otra burbuja que Isak pisa; `trigger_zone`: `[x, y, ancho, alto]` en celdas); tres puntos crema en una burbuja con contorno, uno cada 0,33 s, y sólida a los 1,0 s; no se materializa con Isak dentro; se queda o sigue un ciclo (`cycle_s`, `on_s`: sólida, aviso de 9 cuadros, eliminada y otra vez a escribirse). **`autocorrect_bubble`** (`AutocorrectBubble`): `text` y `corrected`; con Isak a ≤ `trigger_tiles` (3) o al pisarla, cursor de 0,75 s y cambio de largo y de sitio en su ranura (`anchor`); una vez por intento. Todo en tiempo del mundo y de vuelta al estado inicial al reaparecer. Sección `chat_bubble` de `data/world4_objects.json`. Esquema: textos no vacíos y con los glifos de la fuente, largo que cuadra, celdas (la ranura del autocorrector) vacías, disparo válido, ciclo suficiente y el autocorrector «engaña, no mata». Sala **`burbujas_test`** (40 × 12). Pruebas `tests/test_chat_bubbles.gd` (14) y `tests/test_world4_schema.py` (`BubbleSchemaTest`). **Decisiones tomadas:** (1) **base común `ChatBubble`** para las tres (pisada, forma, dibujo), en vez de heredar de `BlinkPlatform`, que va atada al metrónomo; del parpadeo se reutiliza la regla «no se materializa con Isak dentro» y el aviso de 9 cuadros; (2) **disparo** por id de otra burbuja (cualquiera de los tres tipos) o por zona en celdas, una de las dos obligatoria; una vez disparada no se desdispara; (3) **el primer punto sale al dispararse**, el segundo a los 0,33 s y el tercero a los 0,67 s; sólida a 1,0 s; (4) **`cycle_s` se cuenta de aparición a aparición**: eliminada `cycle_s − on_s − 0,75 − 1,0` s, y el esquema exige `cycle_s ≥ on_s + 0,75 + 1,0 + 0,25`; (5) **el autocorrector mide los 3 tiles del borde de la tarjeta al cuerpo de Isak**; su ranura es el mayor de los dos largos y por defecto se ancla al lado de su autor; (6) **«engaña, no mata» en el esquema**: bajo cada columna que deja al descubierto hay `#` o `-` a ≤ 3 filas, sin pinchos por medio (el validador del paso 9 lo cruzará con el camino); (7) **antes de dispararse no se dibuja nada** (la burbuja no existe; los puntos son el aviso) y eliminada sí (contorno discontinuo); (8) `stamp` de ≤ 5 caracteres. **Desvíos:** las propiedades se llaman `author_side`, `friend_id` y `anchor_side` (el param del nivel sigue siendo `side`, `friend` y `anchor`) porque `side` ya es un `String` de `mirror_wall` y pasarlo a `StringName` cambiaría las escenas del Mundo 3; sin Q ni ficha (paso 10); el validador aún no modela las burbujas (paso 9: `wait_typing`, `wait_autocorrect`), así que `burbujas_test` se recorre por el suelo hasta la terminal.

---

## 9. Decisiones tomadas (2026-10-27, por el orquestador con la autoridad delegada por el usuario)

Cada una se puede cambiar cuando el usuario pruebe el mundo.

1. **Decisión tomada: mecánica central = la conversación es el terreno y esperar respuesta cuesta** (burbujas por largo, «escribiendo…» que llega tarde, «Visto» que congela; §3). *Razón:* es lo que pide la ficha (`01` §5, `mundo-4` §9.2) y es distinta de los Mundos 1-3: el reto es de **timing y anticipación**; la congelación cuesta tiempo, no vida.
2. **Decisión tomada: Agitar = pulsar U / LB** (`gesture_shake`, ya asignado), radio 2,5 tiles, 10 de energía, 0,25 s expuesto, enfriamiento 1 s, solo en el suelo salvo para romper la congelación, sin daño (§3.2). *Razón:* no se toca `project.godot`; el coste y la exposición vienen del doc («deja a Isak expuesto un instante») y lo separan del pulso gratis.
3. **Decisión tomada: Congelado conserva la velocidad, no hace daño y, en el 4-1, nada alcanza a Isak congelado** (§3.3). *Razón:* la congelación sin Agitar no puede ser una trampa mortal; con Agitar pasa a ser una decisión.
4. **Decisión tomada: ola del 4-3 = −10 sin matar y congelado 2 s; descongelarse solo la hace retroceder 4 tiles; con Agitar se queda a 1** (§3.5). *Razón:* traduce literal «Agitar rompe la congelación, pero deja la ola más cerca» y reutiliza la regla del borde del scroll del Mundo 2, ya probada.
5. **Decisión tomada: Linterna en el 4-1** (duda 2 de los asistentes, recomendación vigente; `04` §12.3: «aparece sobre todo en el Mundo 4, el chat de madrugada»), aliada de registro, con zonas «Modo oscuro» y `ink_only` (§3.6). *Razón:* es el único mundo oscuro de los seis y la recomendación ya estaba escrita; separa claramente luz (gratis) y Debug (verdad, con energía).
6. **Decisión tomada: la Papelera habla por primera vez en el 4-2**, en «Mensajes borrados», junto a la obtención de Agitar, y su línea sobre «el silencio» prepara la fase 3 del jefe; en el hub no cambia nada (§4.2.2). *Razón:* recomendación de la duda 3; no toca el guardado.
7. **Decisión tomada: el 4-1 es una torre vertical** (24 × 96) y el 4-2 y el 4-3 horizontales de 14 filas (§4). *Razón:* un chat se lee hacia arriba y el zigzag de burbujas izquierda / derecha es plataformeo natural; la cámara de torre y su bot ya existen; el 4-3 tiene que ser horizontal por la ola (doc).
8. **Decisión tomada: los huecos del Tramo 3 del 4-3 crecen con los sellos de hora** (§4.3). *Razón:* «los mensajes se vuelven cada vez más espaciados en el tiempo» (doc) convertido en distancia de salto, sin texto que lo explique.
9. **Decisión tomada: daño a El Visto = Debug revela → pulso marca → láser**, un golpe por marca, 9 golpes en Caché y 12 en Kernel y Raíz; cada fase pone el punto débil a tiro con su mecánica (espalda, escudo roto, silencio) (§5). *Razón:* la regla de V14, ya probada en dos jefes; «un golpe por marca» da peleas de 100-150 s.
10. **Decisión tomada: duración** objetivos de 420 / 480 / 480 s y **camino del validador entre el 40 y el 55 % del objetivo** (el bot del Mundo 3 se quedó en el 19-27 %); el 4-3 a 480 s en lugar de 540 porque la ola marca el ritmo (§4). *Razón:* corrige la desviación medida en el Mundo 3 sin alargar el 4-3 con una ola aburrida.
11. **Decisión tomada: el autocorrector y la oscuridad engañan, no matan** (caídas ≤ 3 tiles con salida; lo que daña siempre con contorno). *Razón:* la regla del filtro del Mundo 3; accesibilidad.
12. **Decisión tomada: arte por script salvo El Visto, el Troll y la pose `shockwave`** (§6.2). *Razón:* familia de formas de burbujas; créditos para los Mundos 5-6. **Actualizada por el usuario (2026-10-28):** placeholders por script de todo, también El Visto, el Troll y la pose; AutoSprite solo al final (paso 24) y sin gastar créditos hasta entonces.
13. **Decisión tomada: vida extra en el 4-1** (N = 3) y **3 power banks**, **27 puntos** en el mundo (§4). *Razón:* la economía de los mundos anteriores.
14. **Decisión tomada: Kernel y Raíz del jefe solo a alto nivel** (§5.8). *Razón:* plan de producción: primero los 18 niveles en Caché.

---

## 10. Decisiones para el usuario (con recomendación por defecto)

Solo las de gusto personal o las reservadas al usuario. **Las cuatro están tomadas por el usuario (2026-10-28)**; debajo de cada una, la propuesta original como contexto.

1. **Decisión tomada (usuario, 2026-10-28): coral B «Coral melocotón» `#ff9f7a`.** Aplicado en el paso 0 (paleta provisional, `debug_colors["4"]` y pieza 4 del hub). *Propuesta original:* coral definitivo del Debug (§6.1; era `#ff7f66` provisional en el hub). **Recomendación: B «Coral melocotón» `#ff9f7a`**: la que más se separa del rojo de daño, del ámbar y del carmín, y la que más contrasta sobre el marino. Las otras: A `#ff7f66` (la actual, más cerca del rojo) y C `#f78fa0` (tira a rosa). El resto de la paleta (16 colores) se elige entre 3 variantes en el paso 10, como en el Mundo 3.
2. **Decisión tomada (usuario, 2026-10-28): la recomendación.** En Caché no hay elección en el 4-3 («Sin conexión», Isak sale sin responder); la respuesta llega en Raíz, ligada al epílogo. *Propuesta original:* **V15: responder o no en el 4-3** (§4.3, cierre; aplazado desde el 2026-10-14 «hasta el Mundo 4»). **Recomendación:** en **Caché no hay elección**: al pulsar la puerta, el campo de respuesta parpadea con el cursor y «Sin conexión» (Eco no deja enviar) e Isak sale sin responder; **la respuesta llega en Raíz** (un «Enviar» que sí funciona y queda apuntado para el epílogo, `06` §14.4). Encaja con las tres vueltas (Raíz = la verdad) sin inventar ahora consecuencias. Alternativas: elección real ya en Caché (un «Responder» opcional que cambia una línea del epílogo) o nunca responder dentro del Mundo 4.
3. **Decisión tomada (usuario, 2026-10-28): los remitentes de `msg_4_x` son los amigos Lía, Marco y Tomi (no Mamá).** *Propuesta original:* **Amigos como remitentes de los mensajes `msg_4_x`** (§4.5) y sus nombres (Lía, Marco, Tomi, propuestos en `04` §12.4). **Recomendación: sí** (los mensajes de los Mundos 1-3 son de Mamá; en el mundo de las amistades, los de los amigos) y conservar los nombres.
4. **Decisión tomada (usuario, 2026-10-28): no se usa AutoSprite ni se gastan créditos por ahora.** El Visto, el Troll, la pose de Agitar y el resto de personajes y enemigos nuevos se hacen como placeholders temporales por script; los diseños finales con AutoSprite van **después**, con los 3 niveles y las mecánicas del jefe listos (paso 24), con permiso y total previo. *Propuesta original:* **Créditos de AutoSprite** (§6.2): **68-71** en una pasada (hasta ~142 con reintentos) de **315**, para El Visto, el Troll y la pose de Agitar. **Recomendación:** aprobarlo para el paso 24, con parada tras cada personaje base.

---

## 11. Riesgos y qué debe revisar el usuario al probar

**Riesgos:**
1. **El estado Congelado toca el control de Isak** (entrada, física en el aire, cámara, Eco, vórtices, muerte): hacerlo primero en `test_arena` y medir que conservar la velocidad no da saltos imposibles.
2. **Coral frente al rojo de daño**, sobre todo con el tinte del Debug y en el Modo oscuro: reglas de §6.1 con `--check` y capturas.
3. **Los tres puntos de Eco frente a los del «escribiendo…»**: color, burbuja y posición distintos (§6.3); revisarlo en capturas.
4. **La ola puede frustrar** (dificultad 5 y presión constante): dos puntos de sincronización con paradas, −10 sin matar, Debug que la frena, velocidades en datos.
5. **Duración:** si el bot sigue muy por debajo del 40 % del objetivo, alargar los niveles (pisos o tramos) antes de seguir, no después; vale también revisar el Mundo 3 (19-27 %).
6. **Validador:** plataformas que existen desde un instante, congelación como coste de tiempo y la ola en X son modelos nuevos; la ola reutiliza el del scroll. Riesgo de duración de la suite con más bots: proceso aparte.
7. **Agitar y la Linterna en mapas viejos:** revisar que no abran atajos en los Mundos 1-3.
8. **Tono:** el 4-3 es el nivel más emocional; los textos de los amigos y del cierre tienen que leerse cálidos, no tristes de más (`04` §12.5: sin duelo). Revisarlos jugando.
9. **Créditos:** ~70 en una pasada; con reintentos, ~140. Parada tras cada base.

**Qué debe revisar el usuario al probar (se volcará a `preguntas.md`, paso 23):**
- Ritmo de cada nivel y si el 4-1 en torre se siente un paso por encima del 3-1.
- Agitar: radio, coste, exposición, si U / LB es cómodo.
- Congelado: duraciones (1,5 / 2,0 / 2,5 s) y si conservar la velocidad se entiende.
- «Escribiendo…» (1,0 s) y si se aprende a saltar con el segundo punto.
- Autocorrector: si el cursor avisa a tiempo y si los textos hacen gracia.
- Ola: velocidades, retroceso de 4 tiles frente a 1 con Agitar.
- Linterna y Modo oscuro: radio de luz y legibilidad.
- Fantasma: si el rastro con el Debug se entiende.
- La pelea de El Visto: duración (objetivo 100-150 s en Caché), el escudo con dos Agitares y la interrupción del «escribiendo…».
- Textos propuestos: Papelera, Eco (Linterna, Agitar, derrota), El Visto, carteles, ayudas Q, Calc, mensajes `msg_4_1`-`msg_4_3` y el cierre del 4-3 según V15.
- La paleta (coral y variante completa) y el arte de AutoSprite tras cada base.
