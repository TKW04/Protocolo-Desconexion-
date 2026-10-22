# Propuesta: Mundo 2 «El Feed» (2-1, 2-2, 2-3 y jefe Autoplay)

**Estado:** **PROPUESTA (2026-10-22); decisiones de §9 resueltas por el usuario el 2026-10-22** (ver «Aprobada 2026-10-22» en cada una). Implementación en curso: ver el plan de §8 (pasos marcados «Hecho»). Desarrolla `mundo-2-feed.md` sin contradecirlo. Lo que no viene de los docs va marcado **PROPUESTA**. Los valores son orientativos y se ajustan jugando y con el validador. **Los textos de Eco, del jefe, de los carteles y de los mensajes de Mamá son borradores de tono**; la historia se escribe con el usuario. Este documento cubre solo **Caché** (plan de producción: primero los 18 niveles en Easy). Kernel y Raíz salen solo en el jefe, como en Alerta Mayor.

**Fuentes:** `mundo-2-feed.md` (ficha original), `01-ficha-reglas.md` §5, `02-isak-habilidades.md` §3.5, `04-personajes.md` §12.1 y §12.5, `05-hub.md` §13.4, `06-finales.md` §14.1, `07-estilo-visual.md` §15.2-§15.5, `08-pendientes.md`, `preguntas.md` (C8, V14, A15, «Tres vueltas»), `propuesta-recuerdos.md` (§8.4, §10, §11.2 y §11.3), `propuesta-hub-y-guardado.md`, `propuesta-mejoras.md` (§3, §5), `propuesta-1-2.md` §0, `propuesta-1-3.md`, `propuesta-jefe-alerta-mayor.md`, `plan-arte-jefe-alerta-mayor.md`, `lista-sonidos.md` §11, `CLAUDE.md` y el código actual (`scripts/levels/`, `scripts/enemies/`, `scripts/bosses/`, `scripts/player/`, `data/world1_objects.json`, `data/enemies/`, `data/isak_abilities.json`, `data/hub.json`, `data/hud.json`, `data/memories.json`, `project.godot`).

**Física de referencia** (datos actuales): andar 220 px/s (3,4 tiles/s), correr 360 px/s; salto de unos 184 px a 60 Hz (subidas cómodas de 2 tiles), cumbre a 0,4 s. Pulso gratis, radio 96 px, solo en el suelo, pose 0,33 s. Láser 10 de energía, 768 px, horizontal, solo en el suelo. Debug: mantener 1 s, 20/s reales, mundo ×0,5. Dash 192 px en 0,2 s, invulnerable 0,3 s, 10 de energía, enfriamiento 0,5 s, uno en el aire. Golpe recibido −10 de Sync Rate e invulnerabilidad 1 s. Energía 100 (110-120 con las mejoras de Caché). La pantalla mide **20 × 11,25 tiles** (1280 × 720).

---

## 0. Resumen

- **El mundo:** un feed de videos que **sube solo** (scroll vertical forzado). Las plataformas son tarjetas de video. Eco le robó a Isak el **tiempo**. El gesto del mundo es **Mantener presionado** (golpe al suelo), que se obtiene al principio del 2-2.
- **Niveles:** 2-1 «Para ti» (enseña el scroll y el autoplay; 20 × 130), 2-2 «Un video más» (golpe al suelo; 20 × 150), 2-3 «Scroll infinito» (velocidad variable, scroll invertido, Historias, «Cargando más…»; 20 × 170). Los tres tienen **20 tiles de ancho**: la cámara solo se mueve en vertical y nada queda cortado.
- **Lo nuevo que hay que construir:** cámara de scroll forzado con borde que daña, secciones en bucle, golpe al suelo, y seis tipos (Video en autoplay, «Un video más», Tarjeta frágil, Historia, Comentarista y el muro «Cargando más…»). Tarjeta frágil, Historia y casi todos los ataques **reutilizan piezas del Mundo 1**.
- **Jefe Autoplay (PROPUESTA de mecánica):** el Debug revela el **botón de pausa** (cabezal de la barra de reproducción). Un **golpe al suelo** sobre él **pausa** al jefe, lo que equivale a la marca de Alerta Mayor. Mientras está en pausa, el **láser** le hace daño. 9 golpes en Caché. Arena de **20 × 11** tiles: cabe entera en pantalla.
- **Arte:** casi todo por script, porque es la familia de formas «tarjeta». AutoSprite solo para el jefe y el Comentarista, con permiso: unos **69 créditos** (hasta 138 con reintentos) de un saldo de 442.
- **Tamaño:** unos 25 pasos. El contenido propio del mundo cuesta **1,1-1,2 veces** el del Mundo 1 (1-2 + 1-3 + jefe), porque el scroll forzado pide una ampliación grande del validador. En esfuerzo total es **un 60-70 %** del Mundo 1, que además construyó los sistemas generales (hub, guardado, Notas, Calc, vidas, recuerdos, audio).

---

## 1. Qué está decidido y qué es propuesta

| Tema | Decidido en los docs | PROPUESTA de este documento |
|---|---|---|
| Tema | Eco robó el **tiempo**. Es el primer mundo donde se siente la pérdida, porque el nivel no se detiene (`mundo-2` §7). | El tiempo como reloj de domingo por la tarde (§2.3). |
| Paleta | Violeta y magenta neón, tarjetas de bordes redondeados, Debug **ámbar** (`07` §15.3). **Hex: decisión abierta** (`CLAUDE.md`). El ámbar del HUD (`#ffb02e`, `data/hud.json`) es provisional. | Reglas de contraste (§6.1). |
| Música | Bucles chiptune cortos que se aceleran; en el jefe se mezclan los anteriores. | Variantes por velocidad del scroll (§6.4). |
| Humor y lo oscuro | Carteles de interfaz («Quedan 3 segundos para el siguiente video. No puedes cancelar», «Solo uno más (llevas 400)»). Enemigos que hablan con frases virales. El reloj del HUD salta horas. Videos de momentos que Isak no recuerda. | Reloj del HUD (C8) y tarjetas decorativas (§2.3). |
| Mecánica central | Scroll vertical forzado; quedarse atrás en el borde **inferior** quita Sync Rate; las tarjetas entran y salen; autoplay al entrar en pantalla; secciones en bucle con un atajo que solo se ve con el Debug. | Valores, borde que daña sin matar, paradas del scroll y el Debug ralentizándolo (§3.1-§3.2). |
| Enemigos y objetos | Los 5 de `mundo-2` §7.3 y el muro «Cargando más…» del 2-3. | Parámetros, reglas y qué se reutiliza (§3.4). |
| Gesto | **Mantener presionado** = golpe al suelo que rompe plataformas y aturde en área (`02` §3.5); se obtiene en el 2-2 dentro de un reproductor. Embestida (dash + golpe) es del Mundo 5. **El control es una decisión abierta** (skill `godot-isak-fix`). `GameState.ABILITY_GROUND_POUND` ya existe y `gesture_hold` no tiene tecla. | Valores, reglas y control (§3.3). |
| Niveles | Objetivo, dificultad, duración, tramos, cierre y secreto de cada uno (`mundo-2` §7.4-§7.6). Un punto de sincronización en el 2-1. | Tamaños, filas, economía, secretos B y C y la posición de cada cosa (§4). |
| Jefe | Autoplay: reproductor gigante con un botón de play por ojo; Eco habla por él, más insistente; arena en un feed que sigue avanzando más despacio; **punto débil: botón de pausa solo visible con el Debug, en rojo, sobre el que hay que mantener presionado**; fases 1-3 y recompensa (`mundo-2` §7.7). Sin rollback (solo el jefe final lo hace). Recompensa = recuerdo de jefe en tres capas. | Daño con la pausa como marca, arena, energía y Kernel / Raíz (§5). |
| Recuerdo de jefe | Textos de las 3 capas e ilustración del patio (`propuesta-recuerdos.md` §11.2-§11.3, **propuesta del orquestador, revisar al jugar**). | Cómo se entrega: igual que Alerta Mayor (§5.9). |
| Mensajes de secretos | **3 en Caché, uno por subnivel**, escritos por **Mamá**; reaparecen en Kernel y Raíz si no se obtienen; son requisito del final real. Se escriben al construir el mundo. | Borradores de tono `msg_2_1`, `msg_2_2` y `msg_2_3` (§4.5). |
| Familia | El Abuelito (vive con Isak, repara radios) y Mamá; tono cálido, sin duelo (`04` §12.5). **No bloquea nada.** | — |
| Hub | Carpeta M2 en la columna 10 (ya existe, `unlocked_by: ["1-boss"]`); al completar el mundo, **segunda pieza del fondo en ámbar**. | Filas del panel y desbloqueo del Mundo 3 (§4.6). |
| Vidas, power banks, puntos | Vida extra cada 3 mapas: **la siguiente va en el 2-1**. ≈ 9 puntos por mapa (6 + 3). Al menos un power bank por mundo y vuelta. | Dónde va cada cosa (§4). |

---

## 2. Tema y tono

### 2.1 Idea

Un feed de videos infinito que **avanza solo**: «nadie decide quedarse, simplemente nunca hay un lugar donde parar» (`mundo-2` §7). Isak sube de tarjeta en tarjeta mientras el feed sigue, y lo que se queda abajo, se pierde. Es el primer mundo que **quita el control del tiempo** al jugador. El golpe al suelo, que se saca de un **botón de pausa**, es la primera herramienta para recuperarlo: romper, frenar y limpiar.

### 2.2 Tono

- **Superficie (humor):** carteles de interfaz (no de Eco) con la voz de una app de videos: «Quedan 3 segundos para el siguiente video. No puedes cancelar», «Solo uno más (llevas 400)» (los dos son del doc). **PROPUESTA de estilo** (textos por decidir): «Te podría gustar: esto», «Reproducción automática: siempre», «Has visto todo. Mentira». Los enemigos hablan en frases virales, solo con texto y en bocadillos cortos sin marcas reales.
- **Fondo (lo oscuro):** el reloj salta horas y algunas tarjetas muestran escenas de la vida de Isak que él no recuerda haber vivido (cumpleaños, tardes con su familia, conversaciones con amigos).
- **Eco:** «esfera pequeña flotando sobre los videos» (`04` §12.1); su frase del mundo, «Mira cuánto tiempo ahorramos juntos.», la dice al obtener el gesto (decidido, `mundo-2` §7.5). Comenta lo justo: historia y ayuda con Q. En el jefe, «ya más insistente».

### 2.3 Reloj del HUD y tarjetas de recuerdos (PROPUESTA)

- **Reloj (C8 de `preguntas.md`, abierta):** el hueco `ClockSlot` reservado a la izquierda de la barra de estado se **muestra desde el Mundo 2** con la hora del celular. Arranca en un **domingo por la tarde** (p. ej. «Dom 17:04») y **salta +1 h de golpe** cuando Isak «se descuida»: al tocar el borde del scroll (§3.2) y al completar cada repetición de un bucle (§3.5). El salto es solo visual y sonoro (`sfx_w2_clock_skip`): sin efecto en el juego. Si el jugador no se descuida, el reloj avanza a una velocidad que parece normal. **Idea opcional:** que no sea casual que el recuerdo Raíz del jefe hable de «las siete y dos» de esa tarde: el jugador que se fije lo encontrará.
- **Tarjetas de recuerdos:** tipo `decor` (ya existe, `DecorSprite`): marcos de video del fondo con siluetas de un pastel con velas, una mesa de patio o dos chicos riendo, sin texto y sin colisión. Una o dos por nivel, siempre fuera del camino. Por script, con la paleta del mundo.

---

## 3. Mecánicas

### 3.1 Scroll forzado (`camera.vertical: "autoscroll"`, nuevo)

| Regla | Valor propuesto | Por qué |
|---|---|---|
| Dirección | **Hacia arriba** (la ficha dice que se pierde Sync Rate al quedarse atrás en el borde **inferior**) | Fiel al doc. Isak sube por el feed y lo de abajo sale de pantalla. |
| Ancho | Nivel de **20 tiles**: la cámara no se mueve en horizontal. Columnas 0 y 19 de pared (el marco del celular), 18 jugables. | Nada queda cortado: es el defecto pendiente de la arena de Alerta Mayor. |
| Velocidad | Por tramos (`scroll.stages`: `[{y_from, y_to, speed_tiles_s}]`), entre **0,4 y 1,2 tiles/s** (26-77 px/s). Isak sube un máximo de unos 2 tiles por salto (≈ 0,7 s): con 1,2 tiles/s sigue habiendo margen. | Ritmo legible; los cambios se avisan (§3.1.1). |
| Tiempo | **Del mundo**: el Debug ralentiza el scroll a la mitad (×0,5). | Coherente con «los temporizadores van en tiempo del mundo» (1-2) y con el Debug del 1-3. El Debug cuesta energía y quita el dash, así que es una elección. |
| Arranque | `start: "on_enter"`: el scroll no empieza hasta que Isak sale de la sala de inicio. | Hay tiempo de leer el primer cartel. |
| Paradas | El scroll **solo se para** en la sala de inicio, en el punto de sincronización (una tarjeta «En pausa»), ante el muro «Cargando más…» (2-3) y en el cierre. | El tema: no hay sitio donde parar, salvo el que Isak encuentra. |
| Encuadre | La cámara mantiene la vista entre `y_bottom(t)` e `y_bottom(t) − 720 px`. Isak puede subir hasta 2 tiles por encima del borde superior sin que la cámara lo siga; más arriba lo frena un «techo de carga» invisible. | Sin pantallas negras. Correr por delante del feed no rompe el ritmo. |

#### 3.1.1 Avisos

- **Cambio de velocidad** (2-3): 9 cuadros antes, flechas en los bordes (dobles = rápido, simples = lento) y el icono del reloj que late. Sonido `sfx_w2_scroll_speed`.
- **Inversión** (2-3, Tramo 2): 1 s antes, las flechas giran y se encienden en el borde **superior**, que pasa a ser el que daña (§3.2). Mismo sonido, con otra variante.
- **Accesibilidad:** las flechas también cambian de forma, no solo de color.

### 3.2 El borde que daña (PROPUESTA)

- Si los pies de Isak quedan por debajo del borde inferior (o por encima del superior en la inversión), recibe **−10 de Sync Rate** (como cualquier golpe) y **reaparece en la tarjeta segura más baja que tenga a la vista** (sin retroceso, con 1 s de invulnerabilidad y un destello). Un segundo contacto antes de 1 s no cuenta.
- **Nunca mata de golpe:** con Sync 100 aguanta 10 contactos. Así se respeta «pierde Sync Rate» y no hay pozos mortales, igual que en el 1-3. Las tarjetas seguras son las que el nivel marca como `safe_respawn` (al menos una cada 6 tiles de altura); el esquema lo comprueba.
- **Aspecto:** una «barra de progreso» del video en el borde (franja de 16 px en `alerta`, el rojo que daña), con muescas que parpadean cuando Isak está a menos de 1 tile. El reloj salta +1 h (§2.3).
- **Muerte y reaparición:** al morir, en el punto de sincronización o en el vórtice, con el scroll de esa sección vuelto a su inicio.

### 3.3 Golpe al suelo (gesto **Mantener presionado**, habilidad `ground_pound`)

#### 3.3.1 Valores iniciales (PROPUESTA; sección `ground_pound` de `data/isak_abilities.json`)

| Parámetro | Valor | Por qué |
|---|---|---|
| En el aire | Mantener `gesture_hold` **0,12 s** → Isak se para en el aire 0,10 s (anticipación, 6 cuadros) y cae a **960 px/s** en vertical | Telegrafiado y rápido. |
| En el suelo | Mantener **0,35 s** (carga visible: el celular se ilumina en 3 pasos) → saltito de 0,5 tile y golpe | «Mantener presionado» tiene sentido literal; permite romper la tarjeta que se pisa. |
| Onda | Al aterrizar, **radio 1,5 tiles** a ras de suelo (96 px a cada lado, 64 px de alto) | «Aturde en área» (`02` §3.5). |
| Efecto en enemigos | Aturde 3 s (como el pulso) y hace **1 de daño** | Los clones de «Un video más» tienen vida 1, así que la misma onda los **elimina todos a la vez** (`mundo-2` §7.3) y a los demás solo los aturde. |
| Efecto en objetos | Rompe `fragile_card` bajo los pies o dentro de la onda, agrieta `loading_wall`, y activa receptores de pulso que estén en el suelo | Rompe plataformas (`02` §3.5). |
| Coste | **0 de energía** | Es la herramienta básica del mundo, como el pulso. La tensión está en el compromiso, no en la barra. |
| Compromiso | Pose de aterrizaje **0,35 s** sin moverse ni saltar (como el pulso); enfriamiento 0,4 s | Usarlo cuesta tiempo, y en un nivel que no se para eso pesa. |
| Invulnerabilidad | Ninguna | El dash ya es la herramienta invulnerable. |

#### 3.3.2 Reglas

- **Con el Debug: sí** (como el pulso y el láser). Hace falta para el atajo del 2-2 (ver lo oculto y romperlo) y para el jefe (§5.3).
- **Con el dash:** no durante el dash. Después de un dash aéreo se puede golpear, pero **es un golpe normal**: la Embestida (dash + golpe que rompe barreras y limpia lo de debajo) es del Mundo 5 (decisión abierta 3).
- **Ocultarte:** lo apaga, como el pulso y el láser.
- **Plataformas de una vía:** el golpe en el aire las atraviesa hacia abajo solo si son `fragile_card`; las normales lo paran (aterriza en ellas).
- **No sale:** sin la habilidad, en el hub, en Hurt, muerto, de espaldas o en un vórtice; en el suelo, durante otra pose.
- **Tiempo:** es de Isak, así que va en tiempo real.
- **Tienda:** sin pista propia, como el dash («los gestos progresan por las combinaciones del Mundo 5»).

#### 3.3.3 Control (decisión abierta 2)

`gesture_hold` no tiene tecla y **el mando no tiene botones libres** (A, B, X, Y, LB, RB, L3, R3, Start y Back están asignados; LT y RT son el láser y correr). **Recomendación:** asignar a `gesture_hold` los mismos eventos que `move_down` (S / ↓ / cruceta abajo / stick abajo), que hoy no se usa en el juego (solo en los menús), y **mantenerlos**. Encaja con «mantener presionado» y con el futuro port a móvil. Es reasignable en Ajustes > Controles. Aviso de control: «Mantener presionado: mantén S / ↓ (mando)». **Alternativa:** tecla J (fue el pulso hasta el 2026-10-15; puede confundir) y en el mando, abajo mantenido.

### 3.4 Enemigos y objetos (qué se reutiliza)

Todo en **tiempo del mundo**, con `help_id`, `level_params` con rangos validados por el esquema, aviso de 6-12 cuadros antes de dañar y vuelta al estado inicial al reaparecer. Rojo solo para lo que daña.

| Tipo (id) | Comportamiento (doc) | Cómo se resuelve (doc) | Implementación (PROPUESTA) | Reutiliza |
|---|---|---|---|---|
| **Tarjeta frágil** (`fragile_card`, objeto) | Se rompe poco después de pisarla | Cruzarla rápido o romperla con el golpe al suelo para abrir camino | Plataforma sólida de 2-4 tiles; al pisarla cuenta **0,6 s** con 4 segmentos y una grieta que crece; aviso de 9 cuadros; cae sin daño y vuelve a los `respawn_s` (3 s) si nadie ocupa su sitio. El golpe la rompe al instante. Variantes: `one_way` (para dejarse caer) y **de pie** (pared de 1 × 2 que bloquea un paso y solo rompe la onda). | **`ReminderPlatform`** (cuenta, segmentos, aviso, caída, reaparición) con `trigger: "on_step"` y `breakable_by_pound` |
| **Historia** (`story_card`, objeto) | Plataforma efímera con un contador muy rápido | Saltar antes de que expire | Aparece (fundido de 6 cuadros), dura **1,6 s** con la barra de progreso de las historias (4 segmentos) y desaparece; vuelve en ciclo (`cycle_s` 3,2) o siguiendo un metrónomo. Aviso: los últimos 9 cuadros parpadea. | **`BlinkPlatform`** + `RhythmZone` (ritmo, parpadeo, no se materializa con Isak dentro) con el aspecto de historia |
| **Video en autoplay** (`autoplay_video`, enemigo) | Se activa al entrar la tarjeta en pantalla; ataques que imitan su clip: olas, rayos, cuentas regresivas | Pulso para aturdirlo y pasar rápido, o esquivar el ataque antes de que acabe el clip | Tarjeta en la pared (2 × 2) con su clip. Al entrar entera en pantalla, **miniatura del clip 0,75 s** (aviso) y ataque: **ola** (barrido horizontal de una fila), **rayo** (columna vertical de 1 tile, 0,4 s) o **cuenta** (3-2-1 y 3 proyectiles en abanico). Un clip dura 2-3 s y se repite mientras está en pantalla. El **pulso lo aturde 3 s** (el clip se pausa); el **láser lo destruye aturdido** (vida 2, suelta +25 de energía). El dash atraviesa la ola, el rayo y los proyectiles. | Ola = barrido de **`SpamBanner`**; rayo = onda de **`AlarmBell`**; proyectil = **`NotificationShot`**; aturdido y vida = **`EnemyHealth`** / Burbuja. Activación por cámara: nueva. |
| **«Un video más»** (`video_clone`, enemigo, y `clone_zone`, objeto) | Clones que se multiplican si Isak tarda en pasar por una zona | Avanzar sin detenerse; con el golpe al suelo se eliminan todos a la vez | `clone_zone` (rectángulo): con Isak dentro, cada **1,5 s** sin salir hacia arriba nace un clon (tope 6) en un borde de la zona, con 9 cuadros de aviso (un marco de video que se enciende). El clon es una tarjeta pequeña que patrulla y daña al contacto; **vida 1**, el pulso lo aturde y la onda del golpe lo elimina. Sin drops (si no, quedarse sería rentable). | Patrulla y contacto de la **Burbuja**; aviso de aparición como las oleadas de **`UpdateBar`**; generador nuevo |
| **Comentarista** (`commenter`, enemigo) | Escupe texto desde abajo del nivel y daña al contacto | Mantenerse arriba o aturdirlo con el pulso | Vive en un hueco de la pared lateral, cerca del borde inferior; cada 2,5 s **escupe un bocadillo de texto** que sube en vertical (proyectil de 1 × 0,5 tiles, 320 px/s; aviso de 9 cuadros: el bocadillo se infla). El pulso lo aturde 3 s; el láser, aturdido, lo derrota (vida 2). Así cuanto más abajo va Isak, más le molesta. | **`NotificationShot`** en vertical (param `direction`); aturdido = Burbuja. Arte: AutoSprite (§6.2). |
| **«Cargando más…»** (`loading_wall`, objeto; 2-3) | Pared que no se abre con el pulso; hay que forzarla con el golpe al suelo mientras se acumulan los clones | — | Muro de 1 × 3 sobre el suelo con un círculo de carga de 3 segmentos. El pulso y el láser rebotan (chispa gris). **Cada golpe al suelo a 1,5 tiles o menos** (la onda lo alcanza) rellena un segmento; con 3, se rompe para siempre. El scroll está parado delante del muro y dentro hay una `clone_zone`: cada golpe también limpia los clones. | Chispa gris del láser; barra de **`UpdateBar`** |
| **Botón de pausa del reproductor** (`pause_player`, objeto; 2-2) | Isak encuentra un botón de pausa escondido dentro de un reproductor y obtiene el gesto | — | Panel del reproductor en la pared del fondo; **pulso de espaldas** al botón (como el `dnd_switch`): concede `ground_pound`, línea de Eco (importante) y aviso de control; `unless_ability` (un solo uso, vuelve tras un rollback sin el gesto). | **`DndSwitch`** / `PowerSwitch` (pulso de espaldas, obtención, guardado, Papelera) |
| **Sección en bucle** (`loop_section`, objeto lógico) | El nivel parece repetirse hasta encontrar el atajo, que solo se ve con el Debug | Debug (2-1); Debug + golpe al suelo (2-2) | §3.5 | Atajo = plataformas ocultas `h` o **`GlitchWall`** con `visible_only_with_debug` |
| **Tarjeta «En pausa»** (`checkpoint` con `stops_scroll`) | Punto de sincronización (uno a mitad de nivel, 2-1) | — | El checkpoint de siempre, con aspecto de video pausado; con Isak dentro el scroll se detiene y se reanuda al salir por arriba. | **`Checkpoint`** |

Los tipos del Mundo 1 (Burbuja, punto rojo, banner, pop-up) **no aparecen** en el Mundo 2: cada mundo tiene su familia de formas (`07` §15.5). Los objetos genéricos sí: cargador, punto de atención, power bank, vida extra, `memory_pickup`, pared con glitch y vórtices.

### 3.5 Secciones en bucle

- **Cómo funciona (PROPUESTA):** una banda de alturas `[y_from, y_to]` del nivel. Cuando el borde superior de la cámara llega a `y_to`, la cámara, Isak, el scroll y lo que hay dentro **se desplazan juntos** a `y_from` sin corte visible, porque la banda empieza y termina con la misma tarjeta. Los enemigos y objetos de la banda vuelven a su estado inicial. Isak no lo nota salvo por el contador.
- **Pista visual (doc: «el juego lo sugiere»):** una tarjeta-cartel en la banda cuenta «Solo uno más (llevas N)», que sube con cada repetición. **Nunca dice «vuelta»** (la palabra es tabú en la UI). En la segunda repetición, el sitio del atajo **parpadea con glitch** 0,5 s. La Q de Eco marca la sección (`loop_section`, idea: «Esto ya lo vimos. Lo de salir, no.»). Cada repetición hace saltar el reloj +1 h.
- **Salida:** en el 2-1, tarjetas ocultas `h` que solo se ven y se pisan con el Debug y suben por un hueco lateral fuera de la banda. En el 2-2, una `fragile_card` oculta en el suelo de la banda: el Debug la deja ver y el golpe al suelo la rompe para caer a un pasillo que sube por el lado.
- **Sin castigo:** repetir no daña ni gasta nada; solo cuesta tiempo. El validador exige que la salida se alcance con el Debug (y el golpe en el 2-2) y que sin ellos no haya otra.

### 3.6 Lenguaje de combinaciones del Mundo 2 (amplía `propuesta-1-2.md` §0 y `propuesta-1-3.md` §4)

| Regla nueva | Consecuencia de diseño |
|---|---|
| El scroll no espera | Toda espera es un riesgo. Los temporizadores del 1-2 se vuelven una carrera hacia arriba. |
| El Debug ralentiza el scroll pero quita el dash | Ver lo oculto da tiempo, y por eso sale caro en energía. |
| El golpe al suelo es gratis pero inmoviliza 0,35 s | Romper o limpiar cuesta tiempo de scroll. |
| La onda elimina clones y aturde lo demás | Si un sitio te retiene, un golpe lo despeja. |

- **Patrón 10. Bajar para subir:** romper una tarjeta frágil del suelo para caer a un pasillo lateral que sube, sin acercarse al borde (caída ≤ 3 tiles, con 4 tiles de margen sobre el borde).
- **Patrón 11. Leer el clip:** la miniatura avisa del ataque. Se responde con pulso (pausa el clip), dash (atraviesa la ola o el proyectil) o cambiando de columna (rayo). Variantes: uno solo (2); dos alternos (3); dos a la vez con un hueco garantizado (4).
- **Patrón 12. Limpiar y seguir:** zona de clones con el golpe al suelo como salida. Variante del 2-3: limpiar mientras se fuerza un muro.
- **Patrón 13. Historia con prisa:** una cadena de Historias y frágiles donde la frágil se rompe a propósito para enlazar con la Historia siguiente.
- **Fórmula de ventana** (`propuesta-1-2.md` §0.1) con el scroll: ventana ≥ k × (recorrido + poses + golpes 0,35 s + dashes 0,2 s) y, además, **el camino nunca deja a Isak a menos de 3 tiles del borde que daña** (k = 2 en dificultad 3; k = 1,6 en dificultad 4).

---

## 4. Niveles, tramo a tramo

**Convención:** los niveles son verticales. Las **alturas se dan en tiles desde el suelo de la sala de inicio** (h 0 abajo). En el grid, la fila es `alto − 1 − h`. Ancho 20 (columnas 0 y 19, pared). Subidas de 2 tiles medidas con el Isak real (`tests/test_level_climbs.gd`, 16 px de holgura de techo).

### 4.1 Nivel 2-1 «Para ti»

**Doc:** presentar el scroll forzado y el autoplay; unos 5 min; dificultad 2; tramos 1-4, cierre «Quedan 3 segundos…», secreto (tarjeta oculta con video en negro y recuerdo, con el Debug), un punto de sincronización a mitad.

- **Mapa: 20 × 130** (1280 × 8320 px). `target_duration_s` **300**; camino del validador de unos **190-220 s** (con scroll forzado el camino no puede ir más deprisa que el feed). Dificultad `2`. `abilities_available`: pulso, láser, Debug y dash (el gesto `ground_pound`, **no**).

| Tramo | Alturas | Scroll | Contenido | Duración (camino) |
|---|---|---|---|---|
| Inicio «Para ti» | 0-10 | parado | Vórtice (4, h 1), cartel «Para ti», 1 punto. **Primera vez que se ve el reloj** (Q de Eco sobre él, `hud_clock`: «Es la hora de verdad. Aquí dentro se escapa.», idea). Puerta de arranque: al subir a h 8 empieza el scroll. | 15 s |
| Tramo 1 «Desliza hacia arriba» | 10-40 | 0,5 tiles/s | Tarjetas anchas (6-8 tiles) en escalera de 2 tiles; el primer contacto con el borde es casi inevitable para quien se queda quieto (Q `feed_edge`). 1 punto en una tarjeta lateral. | 60 s |
| Tramo 2 «Reproducción automática» | 40-62 | 0,6 | **Primer `autoplay_video`** (ola) en la pared izquierda a h 46, con una tarjeta-repisa para esquivarla subiendo; el segundo (rayo) a h 54. Patrón 11, uno cada vez. 1 punto. | 37 s |
| Pausa | 62-66 | parado | **`sync_1`** «En pausa» (h 63) y **`cargador_1`** al lado (cubre el Debug del bucle). | — |
| Tramo 3 «Solo uno más» | 66-92 | 0,6 | **Bucle** en la banda h 70-84 (§3.5): tarjetas en zigzag, un `autoplay_video` (cuenta) y el cartel «Solo uno más (llevas N)». **Salida:** tarjetas `h` a la derecha (columnas 15-17, h 78-84) que solo existen con el Debug (unos 2 s; 40 de energía). **Secreto A «Video en negro»** (§4.1.1). | 25 s + 1-2 repeticiones (24 s cada una) |
| Tramo 4 «Te podría gustar» | 92-120 | 0,7 | **Primeras tarjetas frágiles encadenadas** (3 de 3 tiles, sin suelo debajo hasta h 94) y la **primera `clone_zone`** (h 104-110). Todavía no hay golpe al suelo: se resuelve **avanzando sin parar** (doc). `cargador_2` en h 100. 1 punto sobre la frágil del medio. **Secreto B** (§4.1.1). | 40 s |
| Cierre «Siguiente video» | 120-130 | parado | Tarjeta final «Quedan 3 segundos para el siguiente video. No puedes cancelar» con una cuenta de 3 s (§4.6, decisión abierta 6) y **vórtice de salida automático** (sin terminal ni pulso). 1 punto antes de la tarjeta. | 10 s |

#### 4.1.1 Secretos y economía del 2-1

- **Secreto A «Video en negro» (doc):** en la banda del bucle hay una tarjeta negra (columnas 2-4, h 80) que sin el Debug parece un hueco del feed. Con el Debug se ve como un video apagado sobre el que se puede saltar y deja ver, pegado a la pared, el **`memory_pickup` `msg_2_1`** y **1 punto**. Alcanzable en Caché con lo que se tiene (pulso, láser, Debug y dash) y sin mejoras; `forbid_abilities: ["dash"]` para que no lo haga trivial un dash. Si se coge en la primera repetición del bucle, no vuelve a salir (el `memory_pickup` solo reaparece si no se obtuvo).
- **Secreto B «Vida extra»:** al final del Tramo 4 hay una **pared con glitch** (`visible_only_with_debug`, columna 18, h 112-113) a la que se llega con **salto + dash aéreo** desde la última frágil (4 tiles en horizontal). Detrás está la **vida extra del Mundo 2** (`vida_extra_2_1`; N = 3: la anterior fue la del 1-1). La segunda del juego.
- **Secreto C:** 1 punto en una repisa alta (h 36, columna 1) a la que se llega desde el Tramo 1 por una subida de 3 tiles que pide **correr por delante del scroll** (anticiparse premia).

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 1 | C: 1 |
| Tramo 2 | 1 | |
| Tramo 3 | 1 | A: 1 + `msg_2_1` |
| Tramo 4 | 1 | B: vida extra |
| Cierre | 1 | |
| **Total** | **6** | **2 puntos + mensaje + vida extra** |

- **8 puntos** (6 + 2): la vida extra ocupa el sitio del tercer punto. **PROPUESTA:** compensarlo con 10 en el 2-3 (§4.3), para que el mundo sume 27 como el Mundo 1.
- **Cargadores:** 2 (+50, reutilizables, 10 s). **Power bank:** no. **Puntos de sincronización:** 1 (`sync_1`, a mitad, doc).
- **Energía:** obligatoria ~40 (Debug del bucle); típica 60-80 (secretos A y B, láser a los videos aturdidos). Cada uso obligatorio tiene un cargador a pie (regla anti-atasco, `propuesta-1-2.md` §0.1).

### 4.2 Nivel 2-2 «Un video más»

**Doc:** obtener Mantener presionado y enseñar a gestionar el ritmo; unos 6 min; dificultad 3; inicio en el reproductor con la línea de Eco «Mira cuánto tiempo ahorramos juntos.»; tramos 1-4; secreto bajo el nivel rompiendo una tarjeta concreta, con puntos extra y un recuerdo.

- **Mapa: 20 × 156** (6 filas bajo la sala de inicio para el secreto). `target_duration_s` **360**; camino de unos **230-260 s**. Dificultad `3`. `abilities_available`: pulso, láser, Debug y dash; `ground_pound` se obtiene en el inicio.

| Tramo | Alturas | Scroll | Contenido | Duración (camino) |
|---|---|---|---|---|
| Bajo el nivel (secreto A) | −6 a 0 | — | §4.2.1 | — |
| Inicio «El reproductor» | 0-14 | parado | Vórtice, 1 punto. **Reproductor gigante** en la pared del fondo con su barra de controles: el botón de pausa (`pause_player`) está dentro, tapado por la miniatura, y se ve al acercarse. **Pulso de espaldas** → Isak obtiene el golpe al suelo; Eco: **«Mira cuánto tiempo ahorramos juntos.»** (línea importante, decidida) y el **aviso de control**. Para salir, **la primera tarjeta frágil de pie** (columna 12, h 1-2) bloquea la puerta: solo la rompe la onda (uso obligatorio a 6 tiles de la obtención). | 25 s |
| Tramo 1 «Romper para pasar» | 14-40 | 0,6 | Tarjetas frágiles **de pie** que cierran pasos laterales y **frágiles de suelo** que se rompen para bajar a pasillos que suben por el otro lado (patrón 10, caídas ≤ 3 tiles). Un `autoplay_video` (ola). 1 punto. | 45 s |
| Tramo 2 «Enjambre» | 40-62 | 0,5 | Dos `clone_zone` grandes (h 44-50 y 54-60) con tarjetas que obligan a esperar una Historia: quedarse a pelear los multiplica y el golpe limpia (patrón 12). `cargador_1` en h 52. 1 punto entre las dos zonas. | 45 s |
| Pausa | 62-66 | parado | **`sync_1`** «En pausa» y **`cargador_2`**. | — |
| Tramo 3 «Uno más, otra vez» | 66-100 | 0,6 | **Bucle largo** (banda h 70-92) con dos videos y un Comentarista. **Salida:** una `fragile_card` **oculta** en el suelo de la banda (columnas 8-10, h 86) que solo se ve con el Debug; el golpe la rompe y se cae a un pasillo de servicio que sube por la izquierda hasta h 100 (doc: «combinar Debug y golpe al suelo»). 1 punto en el pasillo. **Secreto C** (§4.2.1). | 30 s + repeticiones (37 s cada una) |
| Tramo 4 «Autoplay» | 100-144 | 0,6 → 0,9 | **El scroll se acelera** en tres pasos (h 100, 115, 130), con aviso. Los videos se activan casi a la vez: parejas que entran juntas en pantalla con clips desfasados ≥ 0,5 s (siempre queda un hueco seguro; el validador lo comprueba). `cargador_3` en h 118. 1 punto. | 55 s |
| Cierre | 144-156 | parado | Tarjeta final y vórtice de salida automático (como el 2-1). 1 punto. | 10 s |

#### 4.2.1 Secretos y economía del 2-2

- **Secreto A «Bajo el nivel» (doc):** en el suelo de la sala de inicio, **una sola** de las seis tarjetas tiene una grieta de 2 píxeles (columna 16, junto al marco del reproductor). Con el golpe al suelo se rompe y se cae a una zona **bajo el nivel** (h −6 a 0, sin scroll: la sala de inicio está parada). Allí: **2 puntos** («puntos de atención extra», doc) y el **`memory_pickup` `msg_2_2`**. Se vuelve a subir por una escalera de una vía hasta la sala de inicio. Alcanzable en Caché justo después de obtener el gesto. La Q de Eco marca la tarjeta mientras el mensaje esté pendiente (`propuesta-recuerdos.md` §10).
- **Secreto B:** en el Tramo 2, una `clone_zone` pequeña sobre una repisa alta (h 58, columnas 14-17) guarda un **power bank vacío**; para cogerlo hay que quedarse (nacen clones) y limpiar con el golpe.
- **Secreto C:** en el Tramo 3, el pasillo de servicio sigue hacia abajo por una frágil de pie (rompible) hasta un hueco con **1 punto**.

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | A: 2 + `msg_2_2` |
| Tramo 1 | 1 | |
| Tramo 2 | 1 | B: power bank vacío |
| Tramo 3 | 1 | C: 1 |
| Tramo 4 | 1 | |
| Cierre | 1 | |
| **Total** | **6** | **3 puntos + mensaje + power bank** |

- **9 puntos.** **Cargadores:** 3. **Power bank:** 1 vacío. **Vida extra:** no. **Puntos de sincronización:** 1.
- **Energía:** obligatoria ~40 (Debug del atajo); típica 60-90 (láser a los videos y Comentaristas aturdidos). El golpe al suelo no gasta.

### 4.3 Nivel 2-3 «Scroll infinito»

**Doc:** combinar todo y subir el ritmo; unos 7 min; dificultad 4 dentro del mundo; tramos 1-4 (velocidad variable, scroll invertido, Historias con frágiles y autoplay, muro «Cargando más…» con clones); secreto: ruta que solo se ve con el Debug, por fuera del feed, entre tarjetas que no deberían existir.

- **Mapa: 20 × 170.** `target_duration_s` **420**; camino de unos **200-230 s**. Dificultad `4`. Todo el kit: pulso, láser, Debug, dash y golpe al suelo.

| Tramo | Alturas | Scroll | Contenido | Duración (camino) |
|---|---|---|---|---|
| Inicio | 0-8 | parado | Vórtice, 1 punto, cartel «Has visto todo. Mentira» (propuesta). | 10 s |
| Tramo 1 «Ráfagas» | 8-45 | 0,4 / **1,2** | Tramos lentos de 0,4 tiles/s y **ráfagas de 1,2 tiles/s durante 3-4 s**, con aviso (§3.1.1). Durante las ráfagas la subida va en línea recta y sin enemigos; en los lentos están los videos. 1 punto. | 55 s |
| Pausa | 45-49 | parado | **`sync_1`** y **`cargador_1`**. | — |
| Tramo 2 «Al revés» | 49-80 | 0,6 / **−0,8** | A h 60, **el scroll se invierte 6 s** (baja a 0,8 tiles/s; el borde que daña es el superior). Isak baja dejándose caer por plataformas de una vía y rompiendo frágiles con el golpe (patrón 10 al revés). Después vuelve a subir a 0,6. Un Comentarista abajo. 1 punto. | 50 s |
| Tramo 3 «Historias» | 80-128 | 0,8 | **Historias** con contador (1,6 s) mezcladas con **frágiles** y **videos** (patrón 13). La ruta exterior del secreto A empieza aquí. `cargador_2` en h 100. 1 punto. | 55 s |
| Tramo 4 «Cargando más…» | 128-160 | 0,7 → **parado** | Subida con un video. A h 146 el feed se para ante el **muro «Cargando más…»** (columna 13, h 146-148) con una `clone_zone` (clones cada 1,5 s): **3 golpes al suelo** junto al muro, que también limpian a los clones (patrón 12). Detrás, el último tramo, sin scroll. `cargador_3` en h 140. 1 punto. | 40 s |
| Cierre | 160-170 | parado | Tarjeta final y vórtice hacia el hub. 1 punto. | 10 s |

#### 4.3.1 Secretos y economía del 2-3

- **Secreto A «Fuera del feed» (doc):** las columnas 0-1 y 18-19 son el **marco del celular** (pared). Con el Debug, en el marco derecho del Tramo 3 aparecen tarjetas `h` «que no deberían existir» (columnas 18-19, h 84-120): una ruta paralela a la principal que no se separa de ella, así que el scroll no castiga más. Arriba, una sala en el marco con el **`memory_pickup` `msg_2_3`** y **2 puntos**. El Debug se usa a tramos (unos 4-5 s en total, ~90 de energía con `cargador_2` a mitad). `forbid_abilities: ["dash"]`.
- **Secreto B:** en el Tramo 2, durante la inversión, una frágil de pie a la izquierda (columna 2, h 54) solo se rompe bajando: detrás hay un **power bank vacío** y **1 punto**.
- **Secreto C:** 1 punto sobre una Historia alta del Tramo 3 a la que solo se llega con salto + dash aéreo.

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 1 | |
| Tramo 2 | 1 | B: 1 + power bank vacío |
| Tramo 3 | 1 | A: 2 + `msg_2_3`; C: 1 |
| Tramo 4 | 1 | |
| Cierre | 1 | |
| **Total** | **6** | **4 puntos + mensaje + power bank** |

- **10 puntos** (6 + 4; compensa el 2-1). **Mundo 2: 27 puntos** (8 + 9 + 10). Con el Mundo 1, unos **54** al terminar el Mundo 2 en Caché.
- **Cargadores:** 3. **Power banks:** 1 vacío (el Mundo 2 suma 2). **Puntos de sincronización:** 1.

### 4.4 Duración, dificultad y progresión

| Nivel | Mapa | Dificultad | Camino (validador) | Objetivo | Enseña | Combina con |
|---|---|---|---|---|---|---|
| 2-1 | 20 × 130 | 2 | ~200 s | 300 s | Scroll, autoplay, bucle con el Debug, frágiles, clones (huir) | Pulso, láser, Debug y dash del Mundo 1 |
| 2-2 | 20 × 156 | 3 | ~245 s | 360 s | Golpe al suelo, enjambre, bucle con Debug + golpe, aceleración | Todo lo anterior |
| 2-3 | 20 × 170 | 4 | ~215 s | 420 s | Velocidad variable, inversión, Historias, muro con clones | Todo el kit |
| Jefe | 20 × 11 | 4,5 | ~110-140 s (bot) | 240 s | Leer clips, pausar con Debug + golpe, ritmo doble | Todo el kit |

**Qué prepara cada nivel para el jefe:** leer la miniatura del clip (2-1, 2-2) → fase 1; reaccionar con prisa a una cuenta (Historias, 2-3) → fase 2; Debug para ralentizar y ver (bucles, 2-1 y 2-2) → fases 2 y 3; golpe al suelo con el Debug activo (atajo del 2-2) → el botón de pausa.

### 4.5 Mensajes recuperables `msg_2_x` (borradores de tono; PROPUESTA)

Remitente **Mamá**, tono cálido y cotidiano, firma con humor (`04` §12.5). Siguen el hilo del recuerdo del jefe (domingo, radio, taza; `propuesta-recuerdos.md` §11.2) sin contarlo. Van en `data/memories.json` con `level`, `secret` y `first_lap: 1`; reaparecen en Kernel y Raíz si no se obtienen; ≤ 280 caracteres (validador). **Textos por decidir con el usuario.**

| Id | Nivel · secreto | Asunto | Idea del texto (borrador) |
|---|---|---|---|
| `msg_2_1` | 2-1 · `secreto_video_negro` | «Domingo» | «Isak, el vecino trajo su radio y el Abuelito dice que el domingo la abren entre los dos. Que no te comprometas con nadie. Yo solo aviso. — Mamá (la secretaria del taller)» |
| `msg_2_2` | 2-2 · `secreto_bajo_el_nivel` | «Tu taza» | «Puse tu taza en la mesa del patio, la del asa pegada. El Abuelito dice que el café no espera, pero que él sí. — Mamá (bajo en cinco, de verdad)» |
| `msg_2_3` | 2-3 · `secreto_fuera_del_feed` | «Ya suena» | «¡La radio ya suena! El Abuelito quiere que la oigas tú primero. Te guardamos la tarde, sin prisa. — Mamá (subiendo el volumen)» |

### 4.6 Hub y progresión

- **`data/hub.json`, mundo `m2`:** filas `2-1 «Para ti»`, `2-2 «Un video más»`, `2-3 «Scroll infinito»` y `{"id": "2-boss", "name": "Autoplay", "kind": "boss"}`, todas con `laps: [1]`. Mientras no exista cada una, `playable: false` («Próximamente»). Desbloqueo en cadena, como el Mundo 1 (`unlocks`). `m3.unlocked_by: ["2-boss"]`.
- **Carpeta M2** (columna 10, ya existe): miniatura nueva (un triángulo de play de 16 × 16, por script). El álbum de Notas abre la carpeta «El Feed» al desbloquear el mundo.
- **Al vencer a Autoplay:** **segunda pieza del fondo en ámbar** (`05-hub.md` §13.4; `background_on_world`), carpeta del Mundo 3 desbloqueada con «Próximamente» y placa «!» en Notas por el recuerdo sin leer. El hub tiene «más vida» (doc): **PROPUESTA**, una animación de idle más entre Notas y Calc. Calc puede comentar en su LCD (idea: «Tiempo recuperado: +1 tarde»).
- **Cierre del 2-1 (decisión abierta 6):** el doc dice que Isak «entra en el siguiente nivel sin poder pararse», y la regla es que al terminar un nivel se vuelve al hub (`preguntas.md`, revisar al diseñar el Mundo 2). **Recomendación:** la cuenta de 3 s abre el **vórtice de salida sola** (no hace falta pulso: «No puedes cancelar»), **vuelve al hub** y en la carpeta el 2-2 sale como «Siguiente video». Se respeta el guardado manual.
- **Rejugar el Mundo 1 con el golpe al suelo:** permitido (el gesto es de Isak). El validador revisa con `abilities_available.ground_pound` que ningún secreto del 1-1 al 1-3 se vuelva trivial; ningún objeto del Mundo 1 es rompible.

---

## 5. Jefe del Mundo 2: Autoplay

### 5.1 Concepto y tono

- **Decidido:** un reproductor de video gigante con **un botón de play por ojo**. Reproduce clips que se convierten en sus ataques. Eco habla a través de él, **más insistente**. Arena: una pantalla gigante en el centro de un feed que sigue avanzando, más despacio. Punto débil: un **botón de pausa** que **solo se ve con el Debug, en rojo**, sobre el que **hay que mantener presionado para pausar al jefe**. Fases: (1) clips que se vuelven ataques (olas, rayos, barridos) y huecos para golpear; (2) «Siguiente video en 5»: si llega a cero sin pausarlo, recupera vida; (3) todo al doble de velocidad y el Debug para seguir el ritmo. Recompensa: el fragmento de tiempo. Eco: «Mira cuánto tiempo ahorramos».
- **Tono (PROPUESTA):** insistente sin estridencias. El jefe nunca se calla: entre clip y clip la pantalla muestra «A continuación…». Eco habla por él con el cuadro de siempre y el marco filtrado (`eco_boss`). Líneas: **intro** (pausa), **cambios de fase** (sin pausa), **derrota** (pausa, tras la recompensa). **Textos por escribir con el usuario.** Ideas de tono: intro, «Te guardé lo mejor para el final. Bueno, para el siguiente»; fase 2, «No te preocupes, empieza solo»; fase 3, «¿Para qué ir despacio?».
- **Sin rollback** (`propuesta-jefe-alerta-mayor.md` §1.2: solo el jefe final).

### 5.2 Arena «Reproducción automática» (20 × 11 tiles)

- **1280 × 704 px:** cabe entera en pantalla, con cámara fija y sin seguir a Isak. Así se evita el defecto de Alerta Mayor (arena de 1536 px con un extremo cortado). Muros en las columnas 0 y 19, techo en la fila 0 y suelo en la 10. Isak de pie en el suelo ocupa las filas 8-9.
- **El jefe:** una pantalla de 8 × 4 tiles (columnas 6-13, filas 1-4) con dos ojos-botón de play. No es sólida (como Alerta Mayor). Debajo, la **barra de reproducción**: una plataforma de una vía (columnas 5-14, superficie en la fila 6; Isak de pie en las filas 4-5, delante de la pantalla). Sobre la barra se desliza el **cabezal**, que es el **botón de pausa** (§5.3).
- **El feed sigue (doc):** dos columnas de **tarjetas que suben** (cinta: plataformas de 3 tiles, columnas 1-3 y 16-18, a 0,5 tiles/s, que reaparecen abajo al salir por arriba; reutiliza `MovingPlatform` con vuelta). Son el carril alto y el camino a la barra (suelo → tarjeta a 2 tiles → barra a 2 tiles). **En la arena no hay borde que dañe:** el suelo es la barra de navegación del celular (fija).
- **Carriles:** suelo (filas 8-9), tarjetas laterales y barra (filas 4-5). Ningún ataque barre los dos a la vez (regla de Alerta Mayor).
- **Cargadores:** 4 en el suelo, en las columnas 1, 6, 13 y 18: +50, enfriamiento de 4 s en Caché (5 s en Kernel y 6 s en Raíz). Desde cualquier celda del suelo hay uno a 3,5 tiles o menos.
- **Debug en la arena:** `debug_drain_scale` **0,25** y `debug_world_scale` **0,7**, los valores que quedaron en Alerta Mayor (§6.4 de su propuesta). Se recalculan con el validador de arenas (§7).
- Vórtice de llegada en (2, 9). Sin puntos, power banks ni vida extra.

```
      0         1
      01234567890123456789
   0  ####################   techo
   1  # ^   [(>)(>)]   ^ #   Autoplay: pantalla 8x4 (cols 6-13, filas 1-4); ojos = botones de play
   2  # |   [ CLIP ]   | #   la pantalla muestra la miniatura del siguiente clip (aviso)
   3  # |   [      ]   | #
   4  #===  [______]  ===#   tarjetas que suben (cinta, cols 1-3 y 16-18; instantánea)
   5  # |              | #
   6  # |  ==========  | #   barra de reproducción (una vía, cols 5-14); cabezal = botón de pausa (oculto)
   7  # |              | #
   8  #===            ===#   tarjeta a 2 tiles del suelo; la barra, 2 más arriba
   9  #CP   C      C    C#   <- carril del suelo; C = cargadores (1, 6, 13, 18), P = vórtice (2)
  10  ####################   suelo fijo (barra de navegación del celular)
```

### 5.3 Punto débil y daño: la pausa (PROPUESTA; decisión abierta 7)

Se adapta la «marca» de Alerta Mayor (Debug → pulso → láser) a lo que pide la ficha («mantener presionado sobre él»): **Debug → golpe al suelo → láser.**

1. **Oculto:** sin el Debug, el cabezal es un círculo gris más de la barra. Un golpe al suelo sobre él solo hace temblar la barra (chispa gris), sin pausa.
2. **Revelado:** con el Debug activo, el cabezal muestra el **botón de pausa en rojo** (`WeakPoint`, por encima del tinte, pulsante). Se mueve por la barra con el clip (el cabezal avanza con la reproducción).
3. **En pausa:** un **golpe al suelo que aterriza sobre el cabezal revelado** (en su caja de 1 × 1 tile; se puede golpear desde un salto en la barra o desde una tarjeta de encima) **pausa al jefe** durante `pause_duration_s` del mundo (**Caché 4 s, Kernel 3 s, Raíz 2,5 s**; lo mismo que la marca). Mientras dura: los ataques se congelan a mitad, la cuenta de la fase 2 se para, la pantalla muestra el fotograma congelado con el icono de pausa y **cada láser a la pantalla es 1 golpe** (2 con el Láser 4, que no se alcanza en Caché), **sin necesidad del Debug**. El halo de 8 segmentos de la marca va alrededor del icono de pausa (`WeakPoint` ya lo dibuja) y parpadea el último segundo.
- **Nada más hace daño:** ni el pulso ni el dash. La pausa no se refresca sin el Debug. Se pierde al caducar, al cambiar de fase, en el golpe final y al reaparecer.
- **Por qué así:** «pausar» es literal (los ataques se paran) y es lo que abre la ventana. Se mantiene la tensión del Mundo 1 (Debug sí, dash no). El gesto del mundo sustituye al pulso, como preveía V14 («el Mundo 2 usa mantener presionado»). La energía del daño es la de Alerta Mayor (láseres), ya calibrada.
- **Alternativa (A):** cada golpe al suelo sobre el botón revelado es un golpe, sin láser. Es más simple y más fiel a la letra, pero el láser deja de importar y la pelea se reduce a saltar sobre un punto.
- **Contador (vida):** 9 golpes en Caché (3 por fase), con la barra del jefe del HUD (`BossBar`) como una **barra de reproducción** que se vacía (99 → 66 → 33 → 0, como Alerta Mayor, o «3 videos restantes»; detalle de arte). Kernel y Raíz, 12 golpes.

### 5.4 Fase 1 «Clips» (doc: olas, rayos y barridos)

| Ataque (clip) | Aviso | Respuesta | Reutiliza |
|---|---|---|---|
| **Ola:** barrido del carril del suelo de lado a lado | La pantalla muestra la miniatura del clip (una ola) **0,75 s** antes y una línea en el suelo durante 9 cuadros | Subir a una tarjeta o a la barra, o atravesarla con el dash | `SpamBanner` (modo disparo, como Alerta Mayor) |
| **Rayos:** 3 columnas de 1 tile desde el techo hasta el suelo, una tras otra | Miniatura y una línea discontinua en cada columna, 9 cuadros | Moverse a una columna libre (nunca caen dos en la misma tanda) | Onda de `AlarmBell` |
| **Barrido alto:** recorre el carril de la barra | Miniatura y la barra parpadea, 9 cuadros | Bajar al suelo o atravesarlo con el dash | `SpamBanner` |

**Ventana:** al acabar cada clip, el jefe **carga el siguiente** («A continuación…», 5 s del mundo, unos 7 s reales con el Debug a ×0,7): no ataca y el cabezal queda quieto en un sitio de la barra. **Solución:** subir a la barra, Debug, golpe al suelo sobre el cabezal (pausa de 4 s), soltar el Debug y láser a la pantalla desde la barra o desde el suelo (alcance de 768 px). Tres golpes: una ventana bien aprovechada, dos o tres si no.

### 5.5 Fase 2 «Siguiente video en 5»

- **Cuenta regresiva (doc):** al empezar cada ventana, la pantalla muestra «Siguiente video en 5» y cuenta **5 s del mundo**. Si llega a 0 sin pausa, el jefe **recupera 1 golpe** (+11 al contador; nunca por encima del inicio de la fase) y suelta una tanda de clips seguidos. Pausarlo **para la cuenta**.
- **Ataques entre ventanas:** los de la fase 1, más **«Cuenta atrás»**: 3-2-1 en la pantalla y 3 proyectiles en abanico hacia Isak (`NotificationShot`; el dash los atraviesa).
- **El cabezal salta (seek):** en cada ventana aparece en otro punto de la barra (izquierda, centro o derecha), así que hay que mirar con el Debug dónde está.
- **Accesibilidad:** cada número de la cuenta suena (`sfx_boss2_countdown`, señal de ritmo activada por defecto) y la cifra cambia de tamaño, no solo de color.
- 3 golpes: dos ventanas (2 + 1), tres o cuatro si no.

### 5.6 Fase 3 «x2»

- **Todo al doble (doc):** clips, cinta de tarjetas y cabezal a ×2. **Los avisos no se aceleran**: siguen siendo de 9 cuadros del mundo (regla de 6-12 cuadros). Así, «al doble» se nota en el ritmo y no en lo que se puede leer.
- **El Debug como ancla (doc):** con el Debug activo, el mundo va a ×0,7 en la arena (×1,4 frente al ×2 normal). Es la forma de seguir el ritmo, y cuesta energía y quita el dash.
- **Música (doc):** se mezclan fragmentos de los bucles del mundo.
- **Ventanas:** 4 s del mundo (2 s reales sin el Debug, unos 2,9 con él). La pausa también va en tiempo del mundo: con el Debug activo dura más en tiempo real.
- 3 golpes: el último es el **golpe final**: la pantalla se queda en negro, los ojos-botón se apagan y el jefe se desarma en píxeles (`BossDefeat`, `PixelBurst`).

### 5.7 Energía (estimación; la valida `tools/validate_boss.py`)

Mismos supuestos que `propuesta-jefe-alerta-mayor.md` §2.4.7 (pelea torpe: 3 s de Debug por ventana, un láser fallado por ventana y una ventana perdida por fase). Diferencias: el golpe al suelo es gratis y hay menos dashes, porque no hay copias que se lancen.

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Golpes (láseres mínimos) | 9 (90) | 12 (120) | 12 (120) |
| Pausa (`pause_duration_s`) | 4 s | 3 s | 2,5 s |
| Debug en la arena | ×0,25 (5/s), mundo ×0,7 | igual | igual |
| Cargadores | 4 de 4 s | 4 de 5 s | 4 de 6 s |
| Pico torpe estimado por ventana (margen sobre 100) | ~60 (≥ 30) | ~70 (≥ 25) | ~78 (≥ 20) |

**Palancas, solo en datos y por este orden:** `pause_duration_s`, enfriamiento de los cargadores y `debug_drain_scale` del acceso. Las mejoras de Calc ayudan pero nunca son requisito: el validador comprueba la barra base, `--access-cap` y todo al máximo.

### 5.8 Kernel y Raíz (PROPUESTA; se cierran al hacer esas vueltas)

Decidido: «los puntos débiles cambian en cada vuelta».

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Cabezal | Quieto en la ventana | **Avanza** por la barra durante la ventana (hay que golpearlo en marcha) | Hay **dos cabezales**: el de verdad y uno de «Saltar anuncio» que solo distingue el Debug; golpear el falso adelanta la cuenta 2 s |
| Fase 2 | Cuenta de 5 | Cuenta de 4 | Cuenta de 4 y proyectiles en los dos carriles alternos |
| Fase 3 | ×2 | ×2 y cinta que cambia de sentido | ×2, cinta que cambia de sentido y rayos en dos tandas |

### 5.9 Recompensa y vuelta al hub

1. **Golpe final** → desarme → **`BossReward.grant(2, vuelta)`**, que ya existe: entrega la capa del acceso actual (`boss_w2_l1` en Caché) **sin guardar**, más las capas inferiores que falten. El panel muestra «Recuerdo recuperado», el título «Fragmento de tiempo», «Capa: Caché», el texto y el aviso del sistema «Guarda en Notas para conservarlo.». La ilustración del patio (`memory_art_w2`, borrosa en Caché) sale en Notas. No hace falta código nuevo.
2. **Eco** (línea importante, por escribir): en Caché, todavía «amable con prisa». La frase del recuerdo de Caché ya es la del doc: «Mira cuánto tiempo ahorramos».
3. **Hub:** se enciende la pieza ámbar, se desbloquea el Mundo 3 con «Próximamente» y Notas lleva la placa «!» (§4.6).
4. **Muerte en la pelea:** se reaparece al principio de la fase actual con energía ≥ 50, como en Alerta Mayor (`BossBase`). **Game over:** el de siempre. **R:** reinicia la pelea.

### 5.10 Ayuda con Q (tipos nuevos, `world: 2`; textos de Eco por escribir)

| Tipo | Idea del texto (no definitivo) |
|---|---|
| `autoplay_boss` | «Nunca para por su cuenta. Su botón de pausa solo se ve con el Debug. Písalo con fuerza y dispárale mientras esté quieto.» |
| `autoplay_playhead` (Objeto) | «El cabezal. Con el Debug se ve qué es en realidad.» |
| `autoplay_countdown` (Objeto) | «Si la cuenta llega a cero, empieza otro. Y se recupera.» |

---

## 6. Arte y sonido

### 6.1 Paleta del Mundo 2

- **Decidido:** violeta y magenta neón, tarjetas de bordes redondeados, Debug ámbar (`07` §15.3); unos 16 colores más el del Debug, guardados en un archivo (`07` §15.2).
- **Hex: decisión abierta del usuario** (`CLAUDE.md`, `08-pendientes.md`; decisión abierta 1). Solo existe el ámbar provisional del HUD (`#ffb02e`). **Bloquea** el arte definitivo (paso 15 de §8), **no** la mecánica ni las salas de prueba, que pueden usar una paleta provisional.
- **Riesgos que la paleta debe resolver (PROPUESTA de reglas):**
  1. **Ámbar duplicado:** el ámbar ya significa **puntos de atención** (`#ffa000`), el **brillo de Eco con la Q** y **«sin guardar»**. En el Mundo 2 el Debug tiñe la pantalla de ámbar. Recomendación: Debug más anaranjado (tono ~35-38°) frente al amarillo de los puntos (~38-40°) y contorno oscuro de 1 px en los puntos de atención del Mundo 2, que se comprueba con capturas con el Debug activo.
  2. **Magenta frente al rojo de daño:** el rojo significa daño y punto débil. El magenta neón debe quedar claramente **violáceo** (tono ≥ 300°). El rojo de daño de este mundo (`alerta`) y el del botón de pausa (carmín pulsante, como el núcleo del Mundo 1) se reservan.
  3. **Isak y Eco sobre violeta:** la chaqueta gris y el cian de Isak deben contrastar con el fondo (relación ≥ 3:1, como se midió en el 1-2 con `measure_tower_contrast.py`).
- **Cómo (PROPUESTA):** `tools/palette_mundo2_preview.py` (como el del Mundo 1) genera `assets/palettes/mundo2.gpl`, una vista previa y una maqueta (feed, tarjetas, frágil, Historia, video, clon, borde que daña, Debug) con la tabla de contrastes. El usuario elige entre 2-3 variantes, como hizo con el Mundo 1 (variante B).

### 6.2 Qué se hace con AutoSprite y qué por script

Precios conocidos: personaje 3, pose 3, animación turbo 5, `upload_character` y `regenerate_*` 0. **Saldo: 442.** Créditos reservados para enemigos y jefes, y **siempre con permiso previo** del usuario, que recibe el total antes de gastar (regla de `jefe-alerta-mayor`).

| Pieza | Vía | Créditos (una pasada) | Con un reintento por pieza |
|---|---|---|---|
| **Autoplay** (pantalla con ojos-botón): base (+ recorte y `upload_character` si `pixelArt` vuelve a pintar un chico), poses `Playing`, `Loading` y `Paused` y animaciones turbo `idle`, `clip_cast`, `countdown`, `paused`, `x2` y `defeat` | AutoSprite | 3 + 9 + 30 = **42** | 84 |
| **Comentarista** (criatura de texto que escupe bocadillos): base, una pose y animaciones `idle`, `spit` y `stunned` | AutoSprite | 3 + 3 + 15 = **21** | 42 |
| **Golpe al suelo de Isak** (`ground_pound`: agacharse en el aire, caer e impacto) | AutoSprite sobre el personaje «Isak» (precedente: el dash, 5) **o** hoja del usuario | **5** (+3 si hace falta una pose) | 10-16 |
| **Total recomendado** | | **68-71** (saldo después: ~371) | **136-142** (~300) |
| Tarjeta frágil, Historia, Video en autoplay (tarjeta con clip), clon, muro «Cargando más…», cinta de tarjetas, barra de reproducción y cabezal, reproductor del 2-2, borde que daña, carteles, tarjetas de recuerdos, tileset y fondo del feed, reloj del HUD, fichas del álbum, miniatura de la carpeta, pieza ámbar del hub | **Script** (`tools/gen_world2_*.py` con validador de paleta) | 0 | 0 |

- **Por qué así:** la familia de formas del Mundo 2 son **rectángulos de tarjeta** (`07` §15.5): geometría plana donde el script da buena calidad (skill `pixel-art-pipeline`, «Límites»). La IA aporta más en lo grande y orgánico (el jefe) y en la única criatura (el Comentarista).
- **Margen para los Mundos 3-6:** con unos 300-370 créditos tras el Mundo 2 caben 4 jefes (~170) y 4 enemigos (~85) en una pasada. Con reintentos se queda justo: se recomienda la **parada tras el base** (enseñarlo antes de seguir) y el tope de dos fallos por pieza.
- **Hasta tener el arte final:** todo por script (sufijo `_placeholder` en el jefe y el Comentarista). La pose `ground_pound` es provisional por script (cizalla y aplastado de cuadros existentes, como la pose `dash` provisional).
- **Ilustración del recuerdo:** ya existe (`memory_art_w2`, por script; paleta del Mundo 1 sin rojos). Opcional: rehacerla con la paleta del Mundo 2 cuando se apruebe.

### 6.3 Por script (detalle)

- `tools/gen_world2_tiles.py`: tileset del feed (tarjetas de bordes redondeados como suelo y plataformas, marco del celular en las columnas 0 y 19); `data/tileset_mundo2.json`.
- `tools/gen_world2_background.py`: fondo vertical en capas (videos borrosos que suben en paralaje) con la misma solución sin costura de la fachada de la torre del 1-2 (`gen_world1_facade.py`).
- `tools/gen_world2_objects.py`: frágil (con grietas), Historia (barra de progreso), video en autoplay (marco y 3 miniaturas de clip), clon, muro de carga, reproductor y botón de pausa, tarjeta «En pausa», borde que daña, carteles, decorados de recuerdo, cinta y barra del jefe, reloj del HUD, miniatura de la carpeta M2.
- `tools/gen_boss_autoplay.py`: piezas de interfaz del jefe (cabezal, icono de pausa, cuenta regresiva, «A continuación…», barra del HUD, ficha del álbum).

### 6.4 Sonido

IDs de `lista-sonidos.md` (todos «F», futuros). Se conectan en `data/audio.json` a señales nuevas. Archivo ausente = silencio; los definitivos los hace el amigo del usuario.

| ID | Cuándo | Origen |
|---|---|---|
| `sfx_gesture_ground_pound` | Golpe al suelo (impacto + onda) | `lista-sonidos.md` §11 |
| `sfx_w2_autoplay_start` | Un video arranca su clip (aviso del ataque) | §11 |
| `sfx_w2_card_crack` / `sfx_w2_card_break` | Tarjeta frágil | §11 |
| `sfx_w2_story_timer` | Historia: contador (**accesibilidad**, como el recordatorio) | §11 |
| `sfx_w2_clone_spawn` | Nace un clon | §11 |
| `sfx_w2_commenter_spit` | Comentarista escupe | §11 |
| `sfx_w2_scroll_speed` | Cambio o inversión del scroll | §11 |
| `sfx_w2_clock_skip` | El reloj salta una hora | §11 |
| `amb_w2_feed`, `mus_w2_level`, `mus_boss2` | Ambiente, música de nivel (bucles de 15 s que se aceleran; **PROPUESTA:** tres variantes por velocidad de scroll con fundido, **sin** sincronizar al compás, como decidió el audio) y del jefe (mezcla de los bucles) | §9-§10 |
| **Nuevos (PROPUESTA):** `sfx_w2_edge_hit` (tocar el borde), `sfx_w2_loop_wrap` (el bucle se repite, sutil), `sfx_w2_loading_wall_crack`, `sfx_w2_pause_player` (obtener el gesto), `sfx_boss2_intro`, `sfx_boss2_clip_preview`, `sfx_boss2_countdown` (**accesibilidad**: cada número), `sfx_boss2_pause` y `sfx_boss2_resume` | — | nuevos |
| Reutilizados | `sfx_weak_point_mark` / `_warn` / `_end` (la pausa), `sfx_weak_point_hit`, `sfx_boss_phase_change`, `sfx_boss_defeat` → `stg_boss_defeated` → `mus_memory`, `vox_boss_eco_filter`, `sfx_hub_wallpaper_piece`, `sfx_charger`, `sfx_dash_through`, `sfx_memory_pickup` | — |

- **Accesibilidad:** «Señales sonoras de ritmo» (activada por defecto) cubre `sfx_w2_story_timer`, `sfx_w2_scroll_speed` y `sfx_boss2_countdown`.

---

## 7. Validación: validador y bots

### 7.1 Validador de niveles (`tools/validate_level.py` + `tools/level_plan.py`)

- **Scroll forzado:** la línea de tiempo ya existe (búsqueda por tiempo del 1-3). Se añade la cámara como **amenaza que se mueve**: con `y_bottom(t)` (`scroll.stages`, tiempo del mundo, arranque `on_enter`, paradas y `reverse`), toda muestra del camino tiene que quedar a **≥ `validation.scroll_margin_tiles`** (propuesta: 3 en dificultad 2-3 y 2 en dificultad 4) del borde que daña. Las esperas solo valen en tramos parados o si el margen aguanta toda la espera. El Debug no se usa para frenar el scroll en el plan (patrón futuro, como el ritmo).
- **Ventaja mínima:** por tramo, el tiempo del camino entre dos alturas cabe con k = 2 (dificultad 3) en el que da el scroll. Salida: «tramo 2 (h 40-62): camino 30,1 s / scroll 36,7 s, margen mínimo 3,4 tiles».
- **Bucles:** `loop_section` como aristas de vuelta (de `y_to` a `y_from`) en el grafo. La salida exige el Debug (y el golpe en el 2-2), y sin ellos no hay otra (como la plataforma oculta obligatoria del 1-2).
- **Golpe al suelo:** habilidad del grafo (por `abilities_available.ground_pound` o el `pause_player`, que es una puerta). Movimientos: golpe en el aire (caída vertical desde el arco, que rompe la `fragile_card` de llegada) y en el suelo (0,35 s de carga + pose), con su tiempo en el plan. `fragile_card` como sólida hasta que se pisa (cuenta de `trigger: on_step`, como los recordatorios de grupo del 1-2) o rota por un golpe (arista nueva). `loading_wall`: 3 golpes a ≤ 1,5 tiles.
- **Enemigos:** `autoplay_video` (activación cuando su tarjeta entra en la vista de la cámara del plan; ola, rayo y abanico como banners, ondas y proyectiles con su calendario), `clone_zone` (el camino no puede pasar más de `spawn_s` dentro sin un golpe; cada clon nacido es una amenaza que patrulla), `commenter` (proyectiles verticales periódicos), `story_card` (sólida solo en su fase, como `blink_platform`).
- **Secretos:** `forbid_abilities` y recompensa `memory` como en el 1-3. El mensaje tiene que ser alcanzable en Caché con lo de ese punto (en el 2-1, **sin** `ground_pound`).
- **Camino exportado** (`isak-path/1`, campos opcionales): pasos `ground_pound` (`air`, `x_px`, `breaks`: ids) y `wait_scroll` (esperar a que el scroll pare o llegue a una altura); el tiempo absoluto del scroll en cada paso. Holgura `validation.hazard_margin_s` 0,1 (como el 1-3).
- **Esquema:** `camera.vertical: "autoscroll"` con `scroll` (stages, paradas, inversión, `safe_respawn` cada ≤ 6 tiles), ancho 20, tipos nuevos con `level_params` y rangos.
- **Pasadas:** sin mejoras, con mejoras, `--access-cap` y todo al máximo. **La salida del 1-1, el 1-2, el 1-3 y la arena tiene que ser idéntica byte a byte.**
- **Riesgo:** la búsqueda por tiempo sobre un nivel de 20 × 170 con el scroll como estado puede tardar (el 1-3 tarda unos 75 s). El tiempo absoluto forma parte del estado y no hay fase libre: limitar la búsqueda a la ventana [t_min, t_min + holgura] por celda.

### 7.2 Validador de arenas (`tools/validate_boss.py`)

Igual que con Alerta Mayor: alcance del cabezal en cada posición de ventana (golpe en el aire sobre una caja de 1 × 1 desde la barra o una tarjeta); ventanas con k = 2 (recorrido + 1 s de Debug + golpe 0,35 s + primer láser); avisos de 6-12 cuadros (también a ×2 en la fase 3); hueco seguro en cada tanda de rayos; ningún ataque en los dos carriles a la vez; cuenta de la fase 2 ≥ ventana mínima; **energía torpe por acceso** (pico ≤ máximo − 20) y cargador a ≤ 4 tiles. Es la parte de jefe del validador: se generaliza lo que hoy es específico de `AlertMajor` (fases y ataques en `data/bosses/autoplay.json` con `laps`).

### 7.3 Bots

- **Bot de niveles del feed** (`tools/feed_bot.gd` + `tools/play_feed_bot.gd`): **extiende `tools/tower_bot.gd`** (cámara vertical), como `dnd_bot.gd` lo extendió para el 1-3. Pasos nuevos `ground_pound` (mantener `gesture_hold` el tiempo exacto del camino) y `wait_scroll`. Sigue el tiempo absoluto del scroll (sale de cada espera en el instante del camino). Comprobaciones: completa cada nivel y vuelve al hub con él en `completed_levels`; **0 contactos con el borde** en la solución; 0 muertes; energía mínima frente al camino; duración anotada. El 2-2 empieza sin el gesto y el bot lo obtiene en el reproductor.
- **Bot del jefe** (`tools/boss_bot.gd`): política nueva por fase con la API de `BossBase` (reflejos: dash a través de olas, barridos y proyectiles; cambio de columna ante los rayos; en cada ventana: subir a la barra → Debug → golpe sobre el cabezal → soltar el Debug → láser mientras dure la pausa; recargar por debajo de 40). Perfiles `ideal`, `clumsy` e `idle`, y `--lap 1|2|3`. Comprueba la capa `boss_w2_l1` sin guardar y la vuelta al hub con el Mundo 3 desbloqueado.
- **En la suite** (`tools/run_tests.sh`) como los bots del 1-2, el 1-3 y Alerta Mayor. La suite ya tarda unos 30 min: los bots del Mundo 2 en proceso aparte y, si hace falta, una bandera para saltarlos en las pasadas rápidas.

---

## 8. Plan de implementación

Pasos pequeños, como en el 1-3 y en Alerta Mayor. Cada paso lleva sus pruebas y **termina con `tools/run_tests.sh` en verde y `graphify update .`**. El arte es por script (`_placeholder` en el jefe y el Comentarista) hasta el paso 23. Los textos se marcan como propuestos. **Antes de empezar:** decisiones abiertas de §9 (al menos la 2, la 4, la 6 y la 7). Sin push.

| Paso | Qué | Archivos probables | Terminado cuando | Tamaño | Depende de | En paralelo con |
|---|---|---|---|---|---|---|
| 0 | **[Hecho 2026-10-22, provisional; ver §8.1]** **Paleta propuesta:** 2-3 variantes con maqueta y contrastes; el usuario elige | `tools/palette_mundo2_preview.py`, `assets/palettes/mundo2.gpl` | El usuario aprueba los hex; `--check` en la suite | S | — | 1, 2 |
| 1 | **[Hecho 2026-10-22; ver §8.1]** **Golpe al suelo en Isak:** estado `GroundPound` (aire y suelo con carga), valores en datos, `gesture_hold` con su binding, onda (aturde y 1 de daño), reglas con Debug, dash, Ocultarte, vórtices y muerte; pose provisional por script; `test_arena` con el gesto | `scripts/player/states/ground_pound_state.gd`, `scripts/player/isak.gd`, `data/isak_abilities.json`, `project.godot`, `tests/test_ground_pound.gd` | GUT: tiempos, caída, onda (radio, aturde, daño 1), sin energía, con el Debug sí, con el dash no, apaga el Ocultarte | M | decisiones 2-3 | 0, 2 |
| 2 | **[Hecho 2026-10-22; ver §8.1]** **Cámara de scroll forzado:** `ScrollCamera` (`camera.vertical: "autoscroll"`, stages, `on_enter`, paradas, inversión, tiempo del mundo), borde que daña con reaparición en `safe_respawn`, flechas de aviso; sala `scroll_test` (20 × 60) | `scripts/player/scroll_camera.gd`, `scripts/levels/generated_level.gd`, `data/camera_scroll.json`, `tools/build_level.py`, `tools/validate_level_schema.py`, `tests/test_scroll_camera.gd` | GUT: velocidad por tramo, el Debug la frena, borde −10 y reaparición, 1 s de invulnerabilidad, paradas, inversión, reinicio al reaparecer | L | decisiones 4-5 | 0, 1 |
| 3 | **Aviso de control y Ajustes > Controles** («Mantener presionado») | `data/ability_notices.json`, `data/settings.json`, `scripts/ui/control_bindings.gd` | Capturas del aviso y de la fila; pruebas de controles | S | 1 | 4-6 |
| 4 | **Tarjeta frágil e Historia** (`ReminderPlatform` con `trigger: on_step` y `breakable_by_pound`; `story_card` sobre `BlinkPlatform`); sala `tarjetas_test` | `scripts/levels/reminder_platform.gd`, `scripts/levels/story_card.gd`, `data/world2_objects.json`, `tests/test_fragile_story.gd` | GUT: cuenta al pisar, rotura por golpe, caída y vuelta, Historia en ciclo, no se materializa con Isak dentro | S-M | 1 | 3, 5, 6 |
| 5 | **Bucle** (`loop_section`: desplazamiento sin corte, reinicio de lo de dentro, contador «Solo uno más (llevas N)», pista de glitch, salto del reloj) y salida con `h` o frágil oculta; sala `bucle_test` | `scripts/levels/loop_section.gd`, `tests/test_loop_section.gd` | GUT: el bucle se repite sin corte; sin Debug no se sale; con el Debug (y el golpe) sí | M-L | 2 | 3, 4, 6 |
| 6 | **Video en autoplay** (activación por cámara, clips ola / rayo / cuenta reutilizando banner, onda y proyectil, pulso que pausa, láser aturdido); sala `autoplay_test` | `scripts/enemies/autoplay_video.gd`, `data/enemies/autoplay_video.json`, `tests/test_autoplay_video.gd` | GUT: activación al entrar en vista, aviso de 0,75 s y 9 cuadros, el dash atraviesa, el pulso pausa | M | 2 | 3-5 |
| 7 | **«Un video más»** (`clone_zone` + `video_clone`), **Comentarista** (proyectil vertical) y **muro «Cargando más…»**; salas `clones_test` y `carga_test` | `scripts/enemies/video_clone.gd`, `scripts/levels/clone_zone.gd`, `scripts/enemies/commenter.gd`, `scripts/levels/loading_wall.gd`, `tests/test_world2_enemies.gd` | GUT: nace un clon cada 1,5 s dentro (tope 6), un golpe los elimina todos, el Comentarista aturdido, el muro solo con 3 golpes | M | 1 | 8 |
| 8 | **Reproductor con el botón de pausa** (`pause_player` = obtención del gesto, como `dnd_switch`) y **reloj del HUD** (`ClockSlot` visible desde el Mundo 2, saltos de hora) | `scripts/levels/pause_player.gd`, `scripts/ui/hud_clock.gd`, `data/hud.json`, `tests/test_pause_player.gd`, `tests/test_hud_clock.gd` | GUT: un uso, guardado, Papelera y rollback; el reloj salta con el borde y el bucle; oculto en el Mundo 1 | S-M | 1, 3 | 7 |
| 9 | **Validador y camino exportado** (§7.1): scroll como amenaza móvil, ventaja mínima, bucles, golpe al suelo, frágiles, Historias, autoplay, clones, Comentarista, muro, `wait_scroll`; negativos sintéticos | `tools/validate_level.py`, `tools/level_plan.py`, `tests/test_level_plan.py`, `tests/support/puzzle_levels.py` | Las salas 2-8 validan sin avisos; negativos fallan (frágil sin margen, bucle sin Debug, scroll demasiado rápido, clones sin golpe); salida del 1-1 al 1-3 y de la arena idéntica | **XL** | 2, 4-8 | 10 |
| 10 | **Arte por script del mundo** (con la paleta aprobada): tileset, fondo vertical, objetos, borde, carteles, decorados de recuerdo, reloj, carpeta M2; **ayudas Q** (`world: 2`) y **fichas del álbum** | `tools/gen_world2_*.py` + validadores, `data/help.json`, `tools/gen_album_cards.py` | Validadores de paleta en la suite; contraste de Isak ≥ 3:1 medido en capturas | L | 0, 4-8 | 9 |
| 11 | **El 2-1 real** (§4.1) + filas del Mundo 2 en `data/hub.json` (2-1 `playable`) + `msg_2_1` en `data/memories.json` + vida extra | `data/levels/2-1.json`, `scenes/levels/2-1.tscn`, `data/hub.json`, `data/memories.json`, `tests/test_level_2_1.py/.gd` | Valida (todas las pasadas) con camino exportado; jugable desde la carpeta M2 tras Alerta Mayor; cierre automático al hub | L | 9, 10 | 13 |
| 12 | **Bot del feed** (`tools/feed_bot.gd` extiende `tower_bot.gd`) recorriendo el 2-1 | `tools/feed_bot.gd`, `tools/play_feed_bot.gd`, `tests/test_feed_bot.gd` | Código 0: completa el 2-1, 0 contactos con el borde, 0 muertes, duración anotada | M-L | 11 | 13 |
| 13 | **El 2-2 real** (§4.2) + `msg_2_2` + bot | `data/levels/2-2.json`, `tests/test_level_2_2.*` | Valida; el bot lo completa obteniendo el gesto | L | 9-12 | 15 |
| 14 | **El 2-3 real** (§4.3) + `msg_2_3` + bot | `data/levels/2-3.json`, `tests/test_level_2_3.*` | Valida (inversión, ráfagas y muro); el bot lo completa | L | 13 | 15-17 |
| 15 | **`BossBase` generalizado y datos del jefe:** `data/bosses/autoplay.json` (fases, clips y `laps`), `WeakPoint` como cabezal (revelado, pausa = marca, chispa gris), señales | `scripts/bosses/autoplay.gd`, `scripts/bosses/weak_point.gd`, `data/bosses/autoplay.json`, `tests/test_autoplay.gd` | GUT: la pausa solo con el Debug + golpe; el láser daña en pausa; sin pausa, chispa gris | M | 1 | 11-14 |
| 16 | **Arena `2-boss`** (20 × 11, cinta de tarjetas, barra, 4 cargadores, Debug ×0,25 / ×0,7) y **fases 1-3** (clips, cuenta con recuperación, ×2 con los avisos intactos) | `data/levels/2-boss.json`, `scripts/bosses/autoplay.gd`, `scripts/levels/moving_platform.gd` (vuelta) | GUT de cada fase con el tiempo avanzado a mano; la arena cabe entera en pantalla | L | 15, 6 | 11-14 |
| 17 | **Validador de arenas** para Autoplay (§7.2) | `tools/validate_boss.py`, `tests/test_boss_validator.py` | Márgenes de energía torpe ≥ 20 en los tres accesos; avisos ≥ 6 cuadros también a ×2 | M | 16 | 18 |
| 18 | **Barra del jefe, recompensa y hub:** `BossBar` como barra de reproducción, `BossReward.grant(2, …)`, pieza ámbar, `m3` desbloqueado «Próximamente», fila «Jefe: Autoplay» jugable | `data/hud.json`, `data/hub.json`, `data/boss_reward.json`, `tests/test_hub_boss_entry.gd` | Desde la carpeta M2 se entra, se vence, se recibe `boss_w2_l1` sin guardar y se vuelve al hub con la pieza ámbar | S-M | 16 | 17 |
| 19 | **Bot del jefe** (perfiles ideal / torpe / quieto, `--lap 1-3`) | `tools/boss_bot.gd`, `tests/test_boss_bot.gd` | Ideal y torpe vencen sin muertes en los tres accesos; quieto pierde | M-L | 16-18 | 20 |
| 20 | **Textos, ayudas Q y audio:** líneas de Eco (intro, fases, derrota, obtención del gesto) marcadas como propuestas; tipos de ayuda; IDs de §6.4 en `data/audio.json` con provisionales | `data/bosses/autoplay.json`, `data/help.json`, `data/audio.json`, `tools/gen_audio_placeholders.py`, `tools/validate_audio.py` | `validate_audio.py` pasa; la Q explica cada tipo nuevo | S | 15-18 | 19 |
| 21 | **Pruebas de conjunto:** negativos (quieto pierde en el jefe; sin Debug no hay pausa; el scroll castiga al que espera), salidas del validador del Mundo 1 idénticas, suite completa | `tests/*`, `tools/run_tests.sh` | Suite en verde con los bots del Mundo 2 | S | 11-20 | — |
| 22 | **Capturas, mapas y docs** | `tools/render_level_2_*.gd`, `tools/render_level_map.py` (scroll, bucles, frágiles, clones), `CLAUDE.md`, `mundo-2-feed.md`, `08-pendientes.md`, `INDEX.md` | Capturas revisadas por el usuario; mapas en `assets/levels_preview/` | S-M | 21 | 23 |
| 23 | **Arte final con AutoSprite** (con permiso y total previo): Autoplay, Comentarista y pose `ground_pound` (§6.2) | `docs/plan-arte-mundo-2.md`, `tools/import_boss_autoplay.py`, `tools/reduce_palette.py` | Integrado sin cambiar tiempos ni cajas; el bot da los mismos resultados | M | 22 y permiso | — |

**Orden:** 0, 1 y 2 a la vez → 3-8 (máximo 3-4 subagentes a la vez: 3+4, 5+6, 7+8) → 9 y 10 en paralelo → 11 → 12 → 13 → 14. El jefe (15-20) puede empezar tras el 1 y el 6, en paralelo con los niveles 11-14 → 21 → 22 → 23.

**Tamaño relativo (estimación):**

| | Mundo 1 | Mundo 2 |
|---|---|---|
| Habilidades nuevas | Láser, Debug, dash (más los sistemas generales del juego) | Golpe al suelo |
| Mecánica de cámara | Torre (1-2) | Scroll forzado con borde, paradas, inversión y bucles (**más difícil de validar**) |
| Tipos nuevos | ~20 (1-1 a 1-3 y jefe) | ~10, la mitad sobre piezas existentes |
| Validador | Láser, Debug, energía, tiempos, torre, dash y ritmo | Scroll como amenaza móvil y bucles: **el paso más grande del mundo** |
| Jefe | Sistema `BossBase`, `WeakPoint`, recompensa y bot desde cero | Reutiliza el sistema; jefe nuevo y arena más simple |
| **Total** | 100 % | **≈ 60-70 %** del total; **≈ 1,1-1,2×** el contenido propio del Mundo 1 |

**Riesgos:** (1) el **validador con scroll** puede ser lento o frágil: hacerlo primero en salas pequeñas y medir; (2) **el ritmo forzado frustra** si el borde castiga mucho: −10 con reaparición y margen ≥ 3 tiles en el camino; ajustar jugando; (3) **legibilidad del Debug ámbar** sobre violeta y frente al ámbar de los puntos (§6.1); (4) **duración de la suite** (ya ~30 min) con tres bots más; (5) el **golpe al suelo en mapas viejos**: revisar los secretos del Mundo 1; (6) **créditos de AutoSprite** para el resto del juego (§6.2).


### 8.1 Avance y desvíos

Primera tanda (2026-10-22): los fundamentos técnicos (pasos 0-5 y la parte del paso 9 que no depende de los enemigos). Un commit local por paso, sin push.

- **Paso 0 (hecho, provisional).** Desvío por decisión del usuario: no se eligen ni cierran los hex. `tools/palette_mundo2_provisional.py` genera `assets/palettes/mundo2_provisional.gpl` y la sección `palette` de `data/world2_objects.json` (colores de desarrollo por nombre; magenta con tono ≥ 300°, Debug ámbar más anaranjado que los puntos). `--check` en la suite. La comparación de 2-3 variantes con maqueta y contrastes pasa al arte final (paso 10).
- **Paso 1 (hecho).** Estado `GroundPound` (`scripts/player/states/ground_pound_state.gd`: fases saltito / anticipación / caída / pose), sección `ground_pound` de `data/isak_abilities.json` con los valores de §3.3.1, onda (`GroundPoundWave`: aturde y 1 de daño a los enemigos del grupo `enemy`; `EventBus.ground_pound_landed(rect, isak)` para los objetos; si lo pisado se rompe con la onda —`is_broken_by_pound()`— Isak sigue cayendo), efecto provisional por código (`GroundPoundEffect`: carga del celular en 3 pasos, estela y onda) y `test_arena` con el gesto. Pruebas `tests/test_ground_pound.gd`. **Desvíos:** (1) el control **no toca `project.godot`**: `ActionPlayerInput` lee `move_down` mantenido (el stick, desde la mitad de su inclinación) como el gesto, además de `gesture_hold` si algún día tiene eventos; así no hay dos acciones con la misma tecla (conflicto en Ajustes > Controles) y `move_down` sigue sirviendo en los menús. (2) Hay que **soltar** entre dos golpes (mantener no repite). (3) La pose es provisional **por escala del sprite** (cuadro de caída estirado y de aterrizaje aplastado, con los pies fijos), sin cuadros nuevos en `isak_frames.tres`. (4) El láser tampoco sale durante el golpe.
- **Paso 2 (hecho).** `ScrollCamera` (`scripts/player/scroll_camera.gd`, `data/camera_scroll.json`): la cámara no sigue a Isak; su borde de abajo sube en **tiempo del mundo** (el Debug la frena) con la velocidad del tramo (`scroll.stages`, por la fila del borde de abajo; `default_speed_tiles_s` fuera), se para en el inicio (hasta subir por encima de `start_resume_row`), en cada `scroll.stops` (hasta subir por encima de su `resume_row`) y arriba del todo; `scroll.reverses` la hacen bajar `duration_s` con el borde de arriba como el que daña. Borde que daña: −10 de Sync sin retroceso, reaparición en la tarjeta segura (`scroll.safe_respawn`) más baja a la vista a 2 tiles o más del borde, 1 s de invulnerabilidad (un segundo contacto no cuenta) y `EventBus.scroll_edge_hit` (para el reloj). Techo de carga a 2 tiles por encima de la vista. La muerte vuelve el scroll a la parada de la sección (`ScrollCamera.reset_for`). Aviso provisional por código (`ScrollEdgeOverlay`: franja roja con muescas que parpadean cerca, flechas dobles / simples 9 cuadros a 12 fps antes de un cambio y flechas arriba 1 s antes de una inversión). Esquema: `camera.vertical: "autoscroll"` y sección `scroll` (ancho 20, filas, velocidades 0,2-1,5, tramos sin solapar, paradas a la vista, tarjetas seguras con suelo y a 6 filas o menos). Herramientas: **`tools/level_catalog.py`** (un nivel del Mundo 2 usa los tipos del Mundo 1 más los de `data/world2_objects.json`; tileset y fondo del Mundo 1 hasta el arte del paso 10). Sala `scroll_test` (20 × 60, `world: 2`). Pruebas `tests/test_scroll_camera.gd` y `tests/test_world2_schema.py`. **Desvíos:** las paradas, el arranque y las inversiones se declaran en la sección `scroll` (no como `checkpoint` con `stops_scroll`: la parada lleva su id y el punto de sincronización está dentro de su vista); el validador aún trata la sala como una torre (el scroll como amenaza llega con el paso 9).

---

## 9. Decisiones abiertas para el usuario (con recomendación)

1. **Hex de la paleta del Mundo 2** — **Aprobada 2026-10-22 (con matiz):** es decisión del arte final. Para desarrollo se usan colores provisionales por script (`tools/palette_mundo2_provisional.py`, `assets/palettes/mundo2_provisional.gpl`) y **no se cierran los hex**; el arte final comparará 2-3 variantes con el usuario y resolverá el choque del Debug ámbar (frente al ámbar de los puntos) y del magenta frente al rojo de daño. — (decisión abierta de `CLAUDE.md`; vale también para las paletas de los demás mundos). Bloquea el arte final (pasos 10 y 23), no la mecánica. *Recomendación:* que el paso 0 genere 2-3 variantes con maqueta y tabla de contrastes y elegir una, como se hizo con el Mundo 1. Reglas: magenta violáceo (≥ 300°), Debug ámbar más anaranjado que los puntos y puntos con contorno en el Mundo 2.
2. **Control del golpe al suelo** — **Aprobada 2026-10-22:** mantener S / flecha abajo / abajo del mando (los eventos de `move_down`), sin tecla nueva. — (`gesture_hold` no tiene tecla y el mando no tiene botones libres). *Recomendación:* los eventos de `move_down` (S / ↓ / cruceta o stick abajo) **mantenidos**, reasignable. Alternativa: J.
3. **Valores y reglas del golpe** — **Aprobada 2026-10-22:** gratis, carga de 0,35 s en el suelo, funciona con el Debug, no durante el dash; tras un dash aéreo es un golpe normal. — (§3.3): gratis, carga de 0,35 s en el suelo, onda de 1,5 tiles que aturde y hace 1 de daño, funciona con el Debug, no durante el dash; tras un dash aéreo es un golpe normal (la Embestida queda para el Mundo 5). *Recomendación:* empezar así y ajustar jugando.
4. **El borde y el scroll** — **Aprobada 2026-10-22:** scroll hacia arriba; el borde quita 10 de Sync sin matar y devuelve a una tarjeta segura; el Debug lo ralentiza. — (§3.1-§3.2): hacia arriba; tocar el borde = −10 y reaparecer en la tarjeta segura más baja (nunca mata de golpe); el Debug ralentiza el scroll. *Recomendación:* sí a las tres.
5. **Dónde se para el scroll:** — **Aprobada 2026-10-22:** solo en el inicio, el punto de sincronización, el muro «Cargando más…» y el cierre. — solo en el inicio, el punto de sincronización («En pausa»), el muro «Cargando más…» y el cierre. *Recomendación:* sí (es el tema: no hay sitio donde parar, salvo los que Isak encuentra).
6. **Cierre del 2-1** — **Aprobada 2026-10-22:** vórtice automático tras la cuenta de 3 s que vuelve al hub (guardado manual). — («entra en el siguiente nivel sin poder pararse» frente a «al terminar se vuelve al hub»). *Recomendación:* vórtice automático tras la cuenta de 3 s, que **vuelve al hub** (respeta el guardado manual); el 2-2 sale en la carpeta como «Siguiente video».
7. **Daño al jefe Autoplay** — **Aprobada 2026-10-22 (B):** Debug → golpe al suelo (pausa al jefe) → láser; si la cuenta de la fase 2 llega a cero, el jefe recupera un golpe. — (§5.3). *Recomendación (B):* Debug → golpe al suelo sobre el cabezal = **pausa** (4 / 3 / 2,5 s, como la marca) → el láser daña; 9 golpes en Caché; si la cuenta de la fase 2 llega a 0, el jefe recupera 1 golpe (sin pasar del inicio de la fase). Alternativa (A): cada golpe al suelo sobre el botón revelado es un golpe.
8. **Mensajes `msg_2_1`-`msg_2_3`** — **Aprobada 2026-10-22:** como propuesta revisable (se pueden pulir: tono cálido y sobrio, personajes solo con texto). — (§4.5): borradores de Mamá sobre el domingo, la taza y la radio. La familia ya está decidida y **no bloquea nada**. *Recomendación:* aprobarlos como propuesta del orquestador, revisable al jugar (como los del Mundo 1).
9. **Presupuesto de AutoSprite** — **Aprobada 2026-10-22 (solo el jefe):** AutoSprite solo para Autoplay cuando la pelea sea jugable, dando el total antes y parando tras el personaje base; hasta entonces no se usa ni se gastan créditos; el Comentarista solo si sobra margen. — (§6.2): Autoplay 42, Comentarista 21 y pose `ground_pound` 5-8; ~68-71 créditos (hasta ~142 con reintentos) de 442. *Recomendación:* aprobar solo el jefe cuando la pelea sea jugable (paso 23, con el total previo y parada tras el base); el Comentarista si sobra margen; el resto por script.
10. **Reloj del HUD (C8)** — **Aprobada 2026-10-22:** el reloj se muestra desde el Mundo 2 y salta +1 h al tocar el borde o repetir un bucle, solo visual. — (§2.3): mostrar la hora desde el Mundo 2 y que salte +1 h al tocar el borde y en cada repetición de un bucle, sin efecto en el juego. *Recomendación:* sí; resuelve C8 con el hueco que ya está reservado.
