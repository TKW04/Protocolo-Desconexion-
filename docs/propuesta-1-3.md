# Propuesta: nivel 1-3 «No molestar» y el gesto Deslizar (dash)

**Estado:** **APROBADA (2026-10-19)** por el usuario con las 13 recomendaciones de §8. **Pasos 1-6 de §7 hechos el 2026-10-19 y el 7 el 2026-10-20** (dash en Isak, aviso y controles, interruptor «No molestar» con la sala `ajustes_test`, banner y dash con la sala `silenciados_test`, metrónomo y plataformas que parpadean con la sala `vibracion_test`, túnel y campanas con la sala `alarmas_test`; secreto «Excepciones» —pared visible solo con el Debug, decorado y `msg_1_3`— con la sala `excepciones_test`; detalle y desvíos en §7); los pasos 8-12, sin hacer. Sustituye lo que contradiga de `mundo-1-notificaciones.md` §6.5 (las marcas están allí). Los valores son orientativos y se ajustan jugando y con el validador. **Los textos de Eco, del interruptor, de los banners y del mensaje de Mamá son propuestas o están por decidir**; la historia no se escribe aquí. El jefe Alerta Mayor queda fuera de este documento salvo lo imprescindible (§3.6).

**Decisiones del usuario (2026-10-19) que respeta:**

1. **C5 resuelto:** el dash (gesto **Deslizar**) es un **gesto aparte**, una variante del pulso con su **propia acción** (`gesture_swipe` del Input Map; tecla y botón propios, reasignables en Ajustes > Controles). **El pulso normal sigue disponible**, así que el Tramo 3 del 1-3 y la Fase 2 de Alerta Mayor usan los dos.
2. **El dash no sube de nivel:** no hay pista de Calc para él. Los gestos progresan por las combinaciones del Mundo 5 (Embestida = dash + golpe al suelo, Filo = dash comprimido, Sismo = golpe al suelo con onda). La pista de **Energía** lo abarata de forma indirecta (más máximo, recarga pasiva en el nivel 5).
3. **Reglas por defecto (el usuario no objetó):** cuesta energía y tiene un enfriamiento corto; se usa **en el suelo y en el aire**; Isak es **invulnerable mientras dura**; **atraviesa banners y proyectiles**, **no** el terreno ni los objetos sólidos; **no se combina con el Ocultarte ni con el Debug**. Los números son provisionales.
4. **Diseño del 1-3:** sala «Ajustes» al inicio con el interruptor «No molestar», donde Isak obtiene Deslizar (Eco comenta algo molesto; aviso de control como los demás); unos 6 min; dificultad 3 de 5. **Tramo 1:** pasillos con banners; **el primer banner es obligatorio con el dash** (sin nicho ni alternativa, justo tras obtener el gesto); los siguientes admiten el dash o el nicho. **Tramo 2:** plataformas que parpadean al ritmo, **solo con señales visuales** (un parpadeo que se acelera cada pocos ciclos; no hay música ni efectos de sonido todavía: se tratarán al terminar el 1-1, el 1-2 y el 1-3). **Tramo 3:** Burbujas y puntos rojos juntos, combinando pulso y dash. **Tramo 4:** túnel de alarmas que se acelera. **Cierre:** pantalla de bloqueo hacia Alerta Mayor.
5. **Secreto (mensaje de Mamá):** sala **«Excepciones»** (la lista de contactos que pueden saltarse el No molestar, «Permitir llamadas de: Favoritos») tras una pared visible **solo con el Debug**; **la ruta no exige el dash**; en el Tramo 2 o 3; contiene `msg_1_3` (`data/memories.json`, secreto `secreto_excepciones`; texto provisional en `propuesta-recuerdos.md` §10). Debe alcanzarse en Caché (el Debug ya se tiene desde el 1-2).

**Física de referencia** (`data/isak_physics.json`, `data/isak_abilities.json`, `data/debug_mode.json`): andar 220 px/s (3,4 tiles/s), correr 360 px/s, aceleración en el suelo 1800 px/s², en el aire 1200 px/s²; salto de 192 px (efectivo 177-184 px; subidas de 2 tiles), cumbre a 0,4 s, salto horizontal corriendo unos 3,2 tiles; coyote y buffer de 0,1 s. Pulso: radio 96 px, gratis, solo en el suelo, pose 0,33 s. Láser: 10 de energía, 768 px, solo horizontal y en el suelo, pose 0,30 s, enfriamiento 0,4 s. Debug: mantener 1 s, 20/s en tiempo real, mundo ×0,5. Golpe recibido: −10, retroceso 240 px/s en x y −360 en y durante 0,3 s, invulnerabilidad 1 s. Energía máxima 100 (110-130 con la pista de Energía).

---

## 1. Concepto, objetivo y tono

- **Idea:** el panel de **ajustes** del celular y su modo **No molestar**. Isak lo activa creyendo que va a tener silencio, y el mundo responde con más ruido: banners que no se callan, vibraciones, alarmas. El nivel enseña que **atravesar** una interrupción (deslizarla) es distinto de esquivarla o de apagarla.
- **Objetivo de diseño:** enseñar el **dash** (obligatorio en el Tramo 1) y el **ritmo visual** (Tramo 2); combinar **pulso + dash** contra enemigos juntos (Tramo 3); poner a prueba todo con presión creciente (Tramo 4) antes del jefe.
- **Tono:** humor de interfaz en los carteles del mundo (textos de interfaz, no de Eco; propuesta de estilo: «No molestar: activado (casi)», «Silenciado… excepto esto», «Recordatorio de que tienes recordatorios»). **Eco comenta lo justo:** la historia de la obtención del gesto (§3.1) y lo que el jugador pregunta con Q. Todos los personajes hablan **solo con texto**.

## 2. Mecánica del dash (gesto Deslizar)

### 2.1 Valores iniciales propuestos

Coherentes con el movimiento real de Isak (correr 360 px/s, salto horizontal de unos 3,2 tiles). Irían en una sección nueva `dash` de `data/isak_abilities.json` (o en `data/dash.json`; a elegir al implementar). Todo **provisional**, se ajusta jugando.

| Parámetro | Valor | Por qué |
|---|---|---|
| `dash_distance_px` | **192** (3 tiles) | Lo mismo que el alto del salto: se lee como «un salto en horizontal». Más que el hueco de un banner (116 px de zona de daño). |
| `dash_duration_s` | **0,20** | 960 px/s (2,7 veces correr): rápido pero legible a 60 fps (12 cuadros). |
| `dash_invulnerable_s` | **0,30** desde el inicio | La duración + 0,10 s de cola: el banner que ya está encima al terminar no golpea en el último cuadro. Ventana de cruce de un banner a 640 px/s ≈ 0,35 s; a 320 px/s ≈ 0,7 s (§3.2). |
| `dash_energy_cost` | **10** | Lo mismo que un disparo del láser (una décima de la barra base). Se cobra al salir el dash. |
| `dash_cooldown_s` | **0,50** desde el final | «Enfriamiento corto»: dos dashes seguidos cuestan unos 0,7 s. |
| `dash_end_speed_px_s` | **360** | Al terminar conserva la velocidad de correr en su dirección (luego manda la aceleración normal). |
| `air_dashes` | **1** por estancia en el aire | Se repone al tocar el suelo (o una plataforma de una vía, una Burbuja o un punto rojo aturdidos). |
| Gravedad durante el dash | **0** (trayectoria horizontal) | La altura no cambia mientras dura; después cae con la gravedad normal (y el multiplicador de caída). |

**Alcance resultante:** en el suelo, 3 tiles en 0,2 s. En el aire, salto corriendo + dash desde la cumbre cruza unos **5-6 tiles** de foso (el validador lo calcula; §6.1). Por eso un foso de más de 3,2 tiles sin otra salida es, desde el 1-3, una **puerta del dash** y el diseño debe decidir si es obligatoria o un secreto.

### 2.2 Reglas

- **Acción `gesture_swipe`** (ya existe en el Input Map: **L / B (mando)**). Pulsar = dash hacia donde mira Isak; si se mantiene una dirección, hacia ella (solo izquierda o derecha: **no hay dash vertical ni diagonal**).
- **Cuándo no sale:** sin la habilidad (`GameState.ABILITY_DASH`, id `dash`, ya declarado); con energía < coste (**chispa gris** en el celular, como el láser sin energía, y `EventBus.dash_denied` propuesto); durante el enfriamiento; durante la pose del pulso o del láser (cada uso es un compromiso, §0.1 de `propuesta-1-2.md`); recibiendo un golpe (Hurt), muerto, de espaldas o en un vórtice; **con el Debug activo o cargando** (chispa gris; ver §2.3); en el hub (`Isak.level_mode`).
- **Qué atraviesa:** **banners** (`spam_banner` y sus variantes) y **proyectiles** (los del jefe, en el futuro): Isak no recibe daño mientras es invulnerable. **No atraviesa** el terreno ni los objetos sólidos (paredes, puertas, la barra del 99 %, pop-ups bloqueantes, recordatorios, paredes con glitch cerradas): `move_and_slide` lo para y el dash termina antes (sin rebote ni daño). Las plataformas de una vía solo frenan desde arriba, así que se cruzan en horizontal.
- **Enemigos (propuesta):** el contacto con una Burbuja o un punto rojo durante la invulnerabilidad no hace daño; el dash **no los aturde ni los daña** (eso será la Embestida y el Filo del Mundo 5). Si Isak ya no choca físicamente con ellos (hoy el daño es por contacto de áreas), los atraviesa; **comprobar al implementar** (pregunta 2).
- **Pulso y láser:** no se pueden usar durante el dash; al terminar en el suelo, sí (tras el cuadro de aterrizaje). Un dash aéreo no habilita el pulso ni el láser en el aire (siguen solo en el suelo).
- **Salto:** se puede saltar justo al terminar un dash en el suelo (el buffer de salto de 0,1 s vale durante el último tramo del dash). Un dash que sale de un borde da el coyote normal.
- **Ocultarte:** el dash **lo apaga** (como el pulso y el láser) y no se puede ocultar durante un dash.
- **Debug:** con el Debug activo o cargando **no hay dash** (regla decidida «no se combina»; la forma concreta, en la pregunta 3). Así una plataforma oculta nunca se cruza con un dash y el validador no mezcla los dos.
- **Vidas y Sync Rate:** la invulnerabilidad no salva de la red de caída ni de un pozo (no hay pozos mortales en el 1-3, §4). El dash no gasta Sync Rate y no puede matar. Morir durante un dash resta una vida como siempre; al reaparecer se repone el dash aéreo y se reinicia el enfriamiento.
- **Tiempo:** el dash es de Isak, así que va en **tiempo real** (el Debug no lo ralentiza; además no se combinan). El enfriamiento también.
- **Tienda:** sin pista propia. Energía 2-4 (110-130) da 1-3 dashes más; Energía 5 (recarga pasiva) no recarga **durante** el dash, sí 3 s después del último gasto (el dash cuenta como gasto). Láser 3 (coste 8) no afecta al dash.

### 2.3 Aspecto y respuesta (propuesta)

Estela de datos con `resplandor` y `cian_tenue` de `mundo1.gpl` (sin `debug_cian`, para no confundirse con el Debug; a decidir en el arte), Isak inclinado con el celular por delante (pose nueva `dash`, 3-4 cuadros; arte del usuario o variante por script de la pose de correr hasta que llegue la hoja), un parpadeo blanco suave mientras es invulnerable y un anillo que se rellena en el celular durante el enfriamiento. Ningún sonido (todavía no hay audio).

### 2.4 Aviso de control, ayuda y álbum

- **Aviso de control** (`data/ability_notices.json`, `abilities`): entrada nueva `"dash": {"name": "Deslizar", "action": "gesture_swipe", "text": "{name}: {control}"}` → «Deslizar: L / B (mando)», leído del Input Map, línea importante, una vez por partida guardada (`seen_notices`). Sale tras la línea de historia del interruptor (§3.1), como el del Debug tras su chip.
- **Ajustes > Controles** (`ControlBindings`): añadir `gesture_swipe` («Deslizar») a la lista de acciones reasignables (hoy: mover, saltar, correr, pulso, láser, Debug, ayuda, Ocultarte y pausa). B ya es «volver» en los menús (`ui_cancel`), pero en el juego está libre.
- **Ayuda Q** (`data/help.json`, `world: 1`; textos de Eco **propuestos**, breves y sin teclas):

| Tipo | Álbum | Texto de Eco (propuesta) |
|---|---|---|
| `dnd_switch` | Objeto | «El interruptor de No molestar. Prometo no molestarte. Mucho.» (por decidir) |
| `spam_banner` (con el dash obtenido) | Enemigo | Se mantiene el texto actual (sigue siendo cierto: «las ayudas nunca mienten»); la variante del pasillo obligatorio usa su propio `help_id` `spam_banner_dash`: «Este pasillo no deja saltar. Deslízate a través cuando llegue.» (por decidir) |
| `blink_platform` | Objeto | «Vibra a su ritmo. Mira cómo parpadea antes de apagarse: cada pocas vueltas va más deprisa.» (por decidir) |
| `alarm_bell` | Enemigo | «Una alarma. Avisa, suena y vuelve a sonar antes. Atraviésala o espera.» (por decidir) |
| `memory_pickup` | Objeto | El de `propuesta-recuerdos.md` §7 paso 4 (por decidir con el mensaje). |

- **Fichas del álbum** (`tools/gen_album_cards.py`): `dnd_switch`, `blink_platform`, `alarm_bell` y `spam_banner_dash` (si se acepta la variante). El dash, como el pulso y el láser, **no tiene ficha** (es una habilidad, no un tipo del mundo). La pared del secreto reutiliza la ficha de `glitch_wall`.

## 3. Esquema del nivel, tramo a tramo

### 3.0 Dimensiones y estructura

- **Horizontal**, como el 1-1 (`camera.vertical: "simple"`): el ritmo y el dash se leen mejor de lado y el bot horizontal existente es la base. **Mapa propuesto: 260 × 14 tiles** (16 640 × 896 px; el 1-1 mide 300 × 14). Suelo general en la fila 10 (Isak de pie en la 9), como el 1-1; filas 1-6 para repisas altas y secretos.
- **Duración:** unos 160 s de camino del validador (sin dudas del jugador) y `target_duration_s` **360** (6 min). Dificultad `3`.
- **`abilities_available`:** pulso, láser y Debug (obtenidos en el 1-1 y el 1-2); el dash **no**: se obtiene en la sala «Ajustes» (como el chip del Debug en el 1-2).
- **Columnas y filas aproximadas** (se ajustan con el validador y con las subidas medidas con el Isak real, `tests/test_level_climbs.gd`, 16 px de holgura de techo).

| Tramo | Columnas | Dificultad | Duración (camino) |
|---|---|---|---|
| Inicio: Ajustes | 1-22 | 1 | 20 s (con la escena) |
| Tramo 1: Silenciados | 23-72 | 2 | 25 s |
| Tramo 2: Vibración | 73-130 | 3 | 35 s |
| Tramo 3: Interrupciones | 131-185 | 3 | 30 s |
| Tramo 4: Alarmas | 186-240 | 3,5 | 30 s |
| Cierre: Pantalla de bloqueo | 241-259 | 1 | 10 s |
| **Total** | **260** | **3** | **unos 150-160 s; objetivo 360 s** |

### 3.1 Inicio: sala «Ajustes» (columnas 1-22)

- Vórtice de llegada en (4, 9); Eco entra con Isak. Sala cerrada con un techo bajo decorativo y paneles de interruptores de fondo (Wi-Fi, brillo, rotación; decorado, sin marcas reales).
- **1 punto de atención** (9, 9).
- **Interruptor «No molestar»** `dnd_1_3` (tipo nuevo `dnd_switch`, §5.1) en la pared del fondo, (14, 9): Isak le lanza el **pulso** de espaldas (como el `power_switch` de la azotea del 1-2). El interruptor se enciende (luna), el tinte de la sala baja un punto y **Isak obtiene Deslizar**.
- **Momento de historia:** Eco dice una **línea importante** (pausa) que comenta algo molesto (texto **por decidir**; idea de tono, no texto: Eco se presenta como la única excepción al No molestar). Sigue el **aviso de control** «Deslizar: L / B (mando)» (§2.4).
- **Un solo uso:** con el dash ya obtenido el interruptor arranca encendido e inerte y su línea no sale (`unless_ability: "dash"`, misma regla que los objetos de historia del 1-1 y el 1-2). Tras un rollback sin el dash, vuelve.
- **`cargador_1`** (19, 9): el primer uso obligatorio del dash está a 6 tiles (regla anti-atasco, §0.1 de `propuesta-1-2.md`).

### 3.2 Tramo 1: Silenciados (columnas 23-72)

1. **1a. Primer banner, obligatorio** (columnas 25-38): pasillo con **techo bajo** (2 filas libres, 8-9; no hay salto que pase por encima del banner) y **sin nicho**. `banner_dash` (variante `spam_banner_dash`, §5.2): entrada en la columna 38, barre hacia la izquierda (hacia Isak) un pasillo de 12 tiles, **despacio** (320 px/s; ventana del dash ≈ 0,7 s), cada 3 s, aviso de 9 cuadros. **Sin alternativa:** andando (3,5 s) o corriendo (2,1 s) el siguiente barrido siempre lo alcanza, y el golpe **lo devuelve a la entrada del pasillo** (`knockback_to_entry`, propuesta; pregunta 1), así que encajar golpes no sirve para cruzar. Con el dash: esperar el aviso, dejar que el banner se acerque y deslizarse a través. Fallar = −10 y vuelta a empezar el pasillo (con 10 golpes de margen y el cargador a 6 tiles).
2. **1b. Banner con nicho** (columnas 40-55): pasillo de 3 filas libres con `banner_1b` (640 px/s, cada 3 s) y un nicho de una vía en el techo: se salta, se espera en el nicho **o** se atraviesa con el dash. **1 punto** en el nicho.
3. **1c. Dos banners desfasados** (columnas 56-72): `banner_1c_a` y `banner_1c_b` (cada 2,5 s, desfase 1,25 s; patrón 5, variante «dos amenazas desfasadas»), dos nichos. Dash o nicho.
4. **Secreto B «Silenciados»** (columnas 62-65, fila 4): repisa alta sobre 1c que solo se alcanza con **salto + dash aéreo** desde el segundo nicho (5 tiles en horizontal). **1 punto.** Primera pista de que el dash funciona en el aire.

### 3.3 Tramo 2: Vibración (columnas 73-130)

- **`sync_1`** (75, 9) al entrar y **`cargador_2`** (77, 9) (cubre el Debug del secreto A y el Tramo 3).
- **Ritmo solo visual** (no hay audio): un **metrónomo** del nivel (`rhythm_zone`, §5.3) marca el pulso; todas las plataformas del tramo lo siguen. Cada plataforma muestra **4 segmentos** que se encienden con el compás y **parpadea 9 cuadros** (0,75 s a 12 fps) antes de apagarse (regla de 6-12 cuadros de aviso); un icono de vibración en el fondo late con el mismo compás. **El compás se acelera cada 4 ciclos**: 1,6 s → 1,3 s → 1,0 s por ciclo (encendida + apagada) y vuelve al lento (pregunta 6). Tiempo del mundo: **el Debug lo ralentiza ×0,5** (uso opcional del Debug, coherente con «los temporizadores van en tiempo del mundo»).
1. **2a. Dos grupos alternos** (columnas 80-95): plataformas `blink_platform` de 2 tiles sobre un **foso de 3 tiles** con escalón de vuelta (caer no hace daño). Grupo A encendido mientras el B está apagado y al revés. Se cruza saltando de una a otra al cambio.
2. **2b. Tres grupos en ola** (columnas 96-115): subida en escalera (subidas de 2 tiles) con grupos A → B → C que se encienden en secuencia; con el compás rápido, la ola obliga a no pararse. **1 punto** en la plataforma del medio.
3. **2c. Rellano y subida al secreto** (columnas 116-130): suelo firme. Una escalera de repisas de una vía **normales** (no parpadean) sube a una repisa alta (fila 5) que acaba en una pared lisa en la columna 120.
4. **Secreto A «Excepciones»** (columnas 121-129, filas 2-5; detalle en §5.4): la pared de la columna 120 es una **pared con glitch que solo se ve con el Debug** (sin el Debug parece terreno normal; con él muestra el glitch y se disuelve a menos de 3 tiles). Dentro, la sala «Excepciones» con el **mensaje de Mamá** (`memory_pickup`, `msg_1_3`) y **1 punto**. **La ruta no exige el dash ni el ritmo**: escalera fija + Debug (unos 2 s activos, 1 s de carga; 40 de energía con `cargador_2` a unos 45 tiles y el de vuelta, `sync_1`). Alcanzable en Caché sin mejoras.

### 3.4 Tramo 3: Interrupciones (columnas 131-185)

Pulso y dash juntos contra Burbujas y puntos rojos (lenguaje de §4). Sin pozos.

1. **3a. Cortina** (columnas 133-148): `banner_3a` barre un pasillo de 3 filas mientras `burbuja_3a` patrulla dentro. Pulso a la Burbuja (aturdida 3 s) y dash a través del banner antes de que despierte (patrón 7).
2. **3b. Esquivar y contraatacar** (columnas 150-168): `badge_3b_a` y `badge_3b_b` en una sala abierta. El punto rojo se infla 0,75 s y se lanza 0,3 s; **el dash lo esquiva** (invulnerable) y lo deja detrás de Isak, quieto 0,6 s: pulso y remate con dos disparos (patrón 6). **1 punto** en una repisa.
3. **3c. Escolta** (columnas 170-185): techo bajo de 2 filas con `burbuja_3c` patrullando y un punto rojo que llega por detrás: pulso a la Burbuja que viene de frente y dash bajo el techo para dejar atrás al punto rojo (patrón 8). **1 punto** al salir.
- Energía: obligatoria ~20 (dos dashes); típica 60-80 con los remates; los drops (+25 cada enemigo derrotado) reponen.

### 3.5 Tramo 4: Alarmas (columnas 186-240)

- **`sync_2`** (187, 9) y **`cargador_3`** (189, 9) al entrar.
- **Túnel de alarmas** (columnas 192-236, `alarm_tunnel`, §5.5): túnel de techo variable con **campanas de alarma** (`alarm_bell`) en el techo que, tras un aviso de 9 cuadros, sueltan una **onda vertical** de 1 tile de ancho hasta el suelo durante 0,4 s, y **banners** sincronizados con el mismo metrónomo. **Se acelera por tramos** (por la posición de Isak, no por tiempo): 4a (192-206) compás de 2,0 s, techo de 3 filas (se salta o se desliza); 4b (207-221) 1,5 s, alterna techo de 3 y de 2 filas (en las de 2 solo el dash); 4c (222-236) 1,1 s, techo de 2 filas: dash cada ciclo (enfriamiento 0,5 s y coste 10: 4-5 dashes, 40-50 de energía, cubiertos por `cargador_3`). Retroceder no lo hace más lento (pregunta 6). Al reaparecer en `sync_2` el túnel vuelve al principio.
- **Secreto C «Alarma pospuesta»** (columnas 237-240, fila 3): a la salida del túnel, repisa alta a 5 tiles en horizontal desde el borde del túnel: salto + dash aéreo. **1 power bank vacío y 1 punto** (pregunta 7).

### 3.6 Cierre: Pantalla de bloqueo (columnas 241-259)

- Recta tranquila con **1 punto** y la **puerta de la pantalla de bloqueo**: una `exit_terminal` con arte de pantalla de bloqueo (reloj grande, notificaciones apagadas), que se activa con el pulso como en el 1-1 y el 1-2.
- **Mientras no exista Alerta Mayor**, la puerta vuelve al hub y deja el 1-3 en `completed_levels` (el jefe sale «Próximamente» en la carpeta del Mundo 1). Cuando exista, lleva al jefe (`next_level`, a definir con su propuesta).
- **Jefe (solo lo imprescindible):** su Fase 2 («cerrar los pop-ups con el pulso y esquivar con dash») ya es posible con este diseño: pulso y dash son acciones distintas y el dash atraviesa proyectiles. Su diseño es otro paso.

### 3.7 Economía

| Dónde | Ruta | Secretos |
|---|---|---|
| Ajustes | 1 | |
| Tramo 1 (nicho de 1b) | 1 | B: 1 (dash aéreo) |
| Tramo 2 (plataforma de 2b) | 1 | A «Excepciones»: 1 + mensaje `msg_1_3` |
| Tramo 3 (3b y salida de 3c) | 2 | |
| Cierre | 1 | |
| Tramo 4 | | C: 1 + power bank vacío |
| **Total** | **6** | **3 puntos + mensaje + power bank** |

- **9 puntos con todo** (6 + 3), el criterio del 1-1 y el 1-2 (el punto del secreto C acompaña al power bank; pregunta 7). Con el 1-1 y el 1-2, unos 27 puntos al terminar el Mundo 1 en Caché: Pulso 2 (25) se puede pagar al terminar el 1-3, como estaba previsto.
- **Cargadores:** 3 (+50, reutilizables, 10 s de enfriamiento como el 1-2): `cargador_1` antes del banner obligatorio, `cargador_2` en `sync_1`, `cargador_3` en `sync_2`. Cumple la regla anti-atasco: cada uso obligatorio de energía (dash del 1a, dashes del 3 y del 4) tiene uno a pie.
- **Power bank:** 1 vacío (secreto C). **Vida extra: no** (N = 3: la siguiente va en el 2-1).
- **Puntos de sincronización:** 2 (`sync_1` al entrar al Tramo 2, `sync_2` al entrar al Tramo 4). El vórtice cubre el Inicio y el Tramo 1.

| Tramo | Energía obligatoria | Típica | Fuentes |
|---|---|---|---|
| Tramo 1 | 10 (1a) | 30-50 (dashes opcionales, secreto B) | `cargador_1` |
| Tramo 2 | 0 | 40 (Debug del secreto A; opcional, Debug para el ritmo) | `cargador_2` |
| Tramo 3 | 20 | 60-80 | drops (+25), `cargador_2` |
| Tramo 4 | 40-50 | 50-70 | `cargador_3` |

## 4. Lenguaje de combinaciones del dash (amplía §0 de `propuesta-1-2.md`)

Reglas físicas nuevas que se respetan y se explotan:

| Regla | Consecuencia de diseño |
|---|---|
| Dash de 3 tiles, invulnerable 0,3 s, 10 de energía, 0,5 s de enfriamiento | Cada dash cuesta lo que un disparo: atravesar compite con rematar y con el Debug. |
| El dash no se usa con el Debug ni durante las poses | No hay «dash + oculta»; tras un pulso hay 0,33 s de compromiso antes de poder deslizarse. |
| Atraviesa banners y proyectiles, no el terreno | Un techo bajo **quita el salto y deja el dash**: la geometría decide qué herramienta se usa. |
| Un dash aéreo por salto | Fosos de 4-6 tiles = puerta del dash (obligatoria o secreta, según el tramo). |

- **Patrón 6. Esquivar y contraatacar:** el punto rojo se infla (aviso) → dash a través de su lanzamiento → queda detrás, quieto 0,6 s → pulso → dos disparos. Variantes: uno solo (dificultad 3); dos que se lanzan desfasados (4); en un pasillo de techo bajo, donde no se puede saltar (4-5).
- **Patrón 7. Cortina:** una amenaza que se aturde (Burbuja) dentro del recorrido de un banner: pulso primero, dash a través del banner después, antes de que el aturdimiento acabe (3 s). Ventana con k = 2 en dificultad 3 (pulso 0,33 s + espera del banner + dash 0,2 s).
- **Patrón 8. Escolta:** techo bajo con una amenaza delante y un perseguidor detrás: lo de delante se aturde con el pulso y lo de detrás se deja atrás con el dash. Variante: el perseguidor llega mientras se hace una pose (obliga a pulsar antes).
- **Patrón 9. Compás:** plataformas o amenazas que siguen un metrónomo visible que se acelera; se lee el parpadeo, no un sonido. Variantes: dos grupos alternos (3); ola de tres grupos (3); con banners en el mismo compás (4); con el dash aéreo para enlazar dos olas (4-5).
- **Futuras (no implementar):** «Ralentizar el compás» (el Debug ralentiza el ritmo pero impide el dash: elegir uno), «Deslizar el núcleo» (Alerta Mayor: esquivar con dash y abrir con Debug, sin combinarlos a la vez).

**Fórmula de ventana** (de `propuesta-1-2.md` §0.1, con el dash): ventana ≥ k × (recorrido + poses + dashes de 0,2 s + enfriamientos); k = 2 en dificultad 3.

## 5. Objetos y enemigos nuevos o variantes

Todos con arte por script (sin AutoSprite: sus ~470 créditos quedan para enemigos y jefes con permiso), paleta `mundo1.gpl` (rojo alerta solo para lo que daña y sus avisos), `help_id`, `level_params` con rangos validados por el esquema, tiempo del mundo salvo que se diga, y vuelta al estado inicial al reaparecer. Textos de interfaz con los glifos de la fuente de textos (la están ampliando aparte).

### 5.1 Interruptor «No molestar» (`dnd_switch`, objeto)

- Panel en la pared del fondo (no sólido, 1 × 2 tiles). Un pulso de espaldas lo activa (reutiliza la pose y el conteo de `power_switch` con `pulses: 1`).
- Al activarse: concede la habilidad `ability` (aquí `dash`) con la misma lógica que `ability_pickup` (`GameState`, guardado, Papelera en un game over), lanza la línea de historia (`story_line`, importante; texto por decidir) y después el aviso de control; `unless_ability`: con la habilidad ya obtenida arranca encendido e inerte, sin Q ni línea.
- Catálogo (`data/world1_objects.json`): `{"type": "dnd_switch", "x": 14, "y": 9, "params": {"id": "dnd_1_3", "ability": "dash", "story_line": "dnd_1_3"}}`. Arte: apagado, encendido (luna), golpeado.

### 5.2 Banner obligatorio (`spam_banner` con params nuevos)

- Variante del banner existente, no un tipo nuevo. Params nuevos (opcionales; por defecto el 1-2 no cambia): `knockback_to_entry: true` (el golpe devuelve a Isak a la celda de entrada del pasillo con el retroceso normal hasta allí; propuesta, pregunta 1) y `help_id: "spam_banner_dash"`.
- Esquema: el pasillo con `knockback_to_entry` debe tener **techo bajo** (≤ 2 filas libres en todo su largo) y ningún nicho; `level_params` ya admite 320 px/s.

### 5.3 Metrónomo y plataforma que parpadea (`rhythm_zone` y `blink_platform`, objetos)

- **`rhythm_zone`** (objeto lógico, sin arte salvo el icono de vibración del fondo): `id`, `zone` (rectángulo de celdas), `tempo_steps_s` (lista de duraciones de ciclo, p. ej. `[1.6, 1.3, 1.0]`), `cycles_per_step` (4), `loop` (true: vuelve al primero), `start` (`on_enter`: arranca cuando Isak entra en la zona; `always`). Expone la fase y el ciclo actuales (`get_beat_phase()`), en tiempo del mundo; se reinicia al reaparecer.
- **`blink_platform`**: plataforma sólida (no de una vía, como el recordatorio, para que caer sea claro) de 1-3 tiles con `rhythm` (id), `group` (`A` / `B` / `C`…), `on_fraction` (parte del ciclo encendida, 0,5 por defecto) y `offset` (fracción del ciclo). Encendida: sólida, 4 segmentos que se llenan con el compás. Los últimos **9 cuadros** antes de apagarse parpadea; apagada: contorno punteado sin colisión (Isak cae sin daño). Si Isak está dentro de su caja al encenderse, no se materializa hasta que salga.
- Esquema: `rhythm` existente; `on_fraction` × el ciclo más corto ≥ aviso + 0,25 s; la plataforma dentro de la `zone` de su metrónomo.

### 5.4 Pared del secreto y sala «Excepciones»

- **Pared:** `glitch_wall` con un param nuevo `visible_only_with_debug: true` (propuesta): sin el Debug se dibuja como terreno normal (sin el glitch leve del 1-1); con el Debug activo muestra el glitch y se disuelve a menos de `reveal_radius_px` (3 tiles), como hoy. El validador ya la trata como sólida sin Debug y libre con él (regla 4b).
- **Sala:** decorado de la lista de contactos (`Permitir llamadas de: Favoritos`, filas de contactos con iconos genéricos, una estrella) como capa de fondo o un objeto decorativo `exceptions_panel` (sin colisión ni Q); los nombres visibles son genéricos («Mamá», «Abuelito»; ninguna marca).
- **Mensaje:** `memory_pickup` (paso 4 de `propuesta-recuerdos.md` §7, hecho el 2026-10-19) con `memory_id: "msg_1_3"`; reaparece en Kernel y Raíz si no se obtuvo. En `data/levels/1-3.json`:

```json
{"id": "secreto_excepciones", "x": 125, "y": 4, "reward": "memory", "memory_id": "msg_1_3",
 "points": 1, "needs_debug": true, "forbid_abilities": ["dash"],
 "object": "memory_pickup", "note": "A. Excepciones: pared con glitch visible solo con el Debug (columna 120); ruta sin dash."}
```

  `forbid_abilities` (propuesta) obliga al validador a encontrar la ruta **sin el dash**. El id coincide con el `secret` de `msg_1_3` en `data/memories.json`. El texto del mensaje es **definitivo** desde el 2026-10-20 (asunto «Cuando quieras»; §10 de `propuesta-recuerdos.md`), igual que los textos del panel («Permitir llamadas de: Favoritos», «Mamá», «Abuelito»).

### 5.5 Túnel de alarmas (`alarm_tunnel` y `alarm_bell`)

- **`alarm_tunnel`**: un `rhythm_zone` con `stages` por posición (`[{x_from, x_to, cycle_s}]`, sin bucle): el compás lo marca la columna más avanzada que ha pisado Isak dentro de la zona (no retrocede). Los banners del túnel llevan `rhythm` (param nuevo de `spam_banner`, opcional: su `interval_s` pasa a ser el ciclo del metrónomo).
- **`alarm_bell`** (enemigo indestructible, de la familia del banner: no es un cuerpo, el láser la atraviesa y el pulso no le afecta, el dash la atraviesa): campana en el techo; con cada ciclo de su `rhythm` y su `offset`, aviso de **9 cuadros** (la campana tiembla y una línea discontinua roja marca la columna en el suelo) y **onda** vertical de 1 tile de ancho hasta el suelo durante 0,4 s; −10 de Sync Rate, empuja hacia atrás.
- Esquema: la onda cabe en el grid sin cruzar terreno sólido; el ciclo deja reposo (aviso + onda + 0,25 s).

## 6. Validador y camino exportado

### 6.1 El dash en `tools/validate_level.py` + `tools/level_plan.py`

- **Estado:** `dash` como habilidad del grafo, como el láser y el Debug: disponible por `abilities_available.dash` o tras el `dnd_switch` (una puerta: el nodo del interruptor alcanzable con el pulso de espaldas).
- **Movimientos nuevos:**
  - **Dash en el suelo:** desde una celda de pie, hasta `dash_distance_px` en la misma fila hacia cada lado, cortado por el terreno y los objetos sólidos (termina en la última x libre); si acaba sin suelo, sigue con una caída con `vx` = 360.
  - **Dash aéreo:** desde las muestras del arco de un salto (andando y corriendo; propuesta: cada 0,05 s entre el despegue y la cumbre + 0,15 s) un tramo horizontal de 192 px y una caída con `vx` = 360; uno por salto; la cabeza se comprueba con `ceiling_margin_px` igual que en las subidas.
  - Nunca en tramos con el Debug encendido (regla «no se combinan») ni en celdas `h`.
- **Coste y enfriamiento:** 10 de energía por dash en el presupuesto (se suma al láser y al Debug; cargadores y drops como hoy); en la línea de tiempo, 0,2 s por dash y ≥ 0,5 s entre el final de uno y el siguiente.
- **Banners y alarmas:** en la búsqueda por fase (`hazard_search`), un paso `dash` deja a Isak invulnerable `dash_invulnerable_s` desde su inicio: el paso es seguro si todo solape con el barrido (o la onda) cae dentro de esa ventana. Con `knockback_to_entry`, un golpe no cuenta como «cruce con daño»: el cruce no existe.
- **Banner obligatorio:** `validation.dash_required: ["banner_dash"]` (como `snooze_required`): sin dash no hay cruce sin daño de ese pasillo y con dash sí, con `time_margin_s` de margen sobre la ventana de cruce (mínimo 0,3 s: ventana ≈ 0,7 s a 320 px/s). Negativos en `tests/test_level_plan.py`: pasillo obligatorio con nicho (falla), con techo de 3 filas (falla: se salta), banner demasiado rápido para la invulnerabilidad (falla), dash sin energía (falla).
- **Ritmo:** `blink_platform` como sólida solo en las fases encendidas del metrónomo (con el calendario de `tempo_steps_s`); búsqueda por (celda, fase) como los banners, con esperas en suelo firme; ventana con k = 2 (dificultad 3); el Debug no se usa para ralentizarlo en el plan (patrón futuro).
- **Túnel:** `alarm_tunnel` por posición (la fase depende de la columna más avanzada); la onda de `alarm_bell` como un barrido vertical de duración fija.
- **Secretos:** `forbid_abilities` recalcula la alcanzabilidad sin esas habilidades; `reward: "memory"` exige que el mensaje sea alcanzable con lo de su acceso (Caché: pulso, láser, Debug, dash; aquí, además, sin dash) y sin mejoras de Calc.
- **Pasadas:** sin mejoras, con `--access-cap` y con todo al máximo (la suite ya lo hace con el 1-2).

### 6.2 Exportación del camino y bot

- **Formato `isak-path/1`** (skill `level-builder`): pasos nuevos `dash` (`dir`, `air`: bool, `from_px`, `to_px`, tiempos real y del mundo, energía) y `wait_beat` (esperar la fase del metrónomo, como `wait_phase` con los banners). Subir a `isak-path/2` solo si el bot vertical deja de entender el formato (los pasos nuevos se ignoran en el 1-2, que no los tiene).
- **Bot:** el del 1-1 (`tools/level_bot.gd`, «avanzar y saltar») no basta (no hace dash ni lee el compás). Propuesta: **generalizar `tools/tower_bot.gd`** a un bot de camino para cualquier cámara (`simple` o `tower`) y añadir `dash` (pulsa `gesture_swipe` el cuadro exacto del camino, con la dirección mantenida) y `wait_beat` (`get_beat_phase()` del metrónomo, como `get_cycle_time()` de los banners). El bot del 1-1 se mantiene. Comprobaciones: completa el 1-3 por la puerta de bloqueo y llega al hub con el 1-3 en `completed_levels`; 0 golpes en el banner obligatorio; energía mínima frente al camino; duración anotada.

## 7. Plan de implementación (pasos pequeños)

| Paso | Qué | Tamaño | Depende de |
|---|---|---|---|
| 1 | **Hecho (2026-10-19).** **Dash en Isak:** estado `Dash` en la máquina de estados, valores en datos (§2.1), acción `gesture_swipe`, energía y chispa gris, enfriamiento, dash aéreo, invulnerabilidad, reglas con pulso, láser, Debug, Ocultarte, vórtices y muerte. Sala de movimiento `test_arena` con el dash desbloqueado. GUT: distancia, tiempos, coste, invulnerabilidad, paredes. | M | |
| 2 | **Hecho (2026-10-19).** **Aviso y controles:** entrada `dash` en `data/ability_notices.json`; `gesture_swipe` en Ajustes > Controles; capturas en `tools/render_ability_notices.gd` y `tools/render_pause_menu.gd`. | S | 1 |
| 3 | **Hecho (2026-10-19).** **Interruptor «No molestar»** (`dnd_switch`) con la obtención del gesto, línea de historia (texto propuesto, por decidir), `unless_ability`; sala de prueba `ajustes_test`. | S | 1, 2 |
| 4 | **Hecho (2026-10-19).** **Banner y dash:** invulnerabilidad contra `spam_banner`, `knockback_to_entry`, `help_id` `spam_banner_dash`; sala de prueba `silenciados_test` (pasillo obligatorio + pasillo con nicho). | S | 1 |
| 5 | **Hecho (2026-10-19).** **Metrónomo y plataformas que parpadean** (`rhythm_zone`, `blink_platform`); sala `vibracion_test`. | M | |
| 6 | **Hecho (2026-10-19).** **Túnel y campanas** (`alarm_tunnel`, `alarm_bell`, banners con `rhythm`); sala `alarmas_test`. | M | 4, 5 |
| 7 | **Hecho (2026-10-20).** **Secreto:** `glitch_wall.visible_only_with_debug`, `memory_pickup` y recompensa `memory` (paso 4 de `propuesta-recuerdos.md`), decorado de «Excepciones»; sala `excepciones_test`. | M | paso 4 de recuerdos |
| 8 | **Arte por script** de lo nuevo (generador nuevo, p. ej. `tools/gen_world1_dnd.py`, con su validador de paleta), estela y pose provisional del dash, fichas del álbum y ayudas Q (`data/help.json`). | M | 3-7 |
| 9 | **Validador y exportación** (§6): dash en suelo y aire, coste y enfriamiento, banners y campanas con invulnerabilidad, `dash_required`, ritmo, túnel, `forbid_abilities`, pasos `dash` y `wait_beat`; negativos sintéticos. | L | 1, 4-7 |
| 10 | **El 1-3 real:** `data/levels/1-3.json` (260 × 14), escena generada, `data/hub.json` (1-3 `playable`), pruebas GUT y Python del nivel (obtención del gesto, banner obligatorio, ritmo, túnel, secretos, economía, terminal → hub). | L | 1-9 |
| 11 | **Bot de camino horizontal** (generalizar `tools/tower_bot.gd`), en la suite. | M-L | 9, 10 |
| 12 | **Capturas y docs:** `tools/render_level_1_3.gd` (Ajustes y la obtención, aviso, banner obligatorio antes / durante / después del dash, ritmo lento y rápido, Debug en la pared, sala «Excepciones», Tramo 3 con el dash esquivando un lanzamiento, túnel en sus tres compases, pantalla de bloqueo); mapa con `tools/render_level_map.py`; actualizar `CLAUDE.md`, `mundo-1` y `08-pendientes.md`. | S | 10 |

**Pasos 1-6 hechos (2026-10-19) y paso 7 (2026-10-20), con estos detalles y desvíos:**

- **Paso 1.** Valores de §2.1 en la sección `dash` de `data/isak_abilities.json` (provisionales; `PlayerAbilities.dash_*`). Estado `Dash` (`scripts/player/states/dash_state.gd`); entrada `PlayerInput.dash_pressed` (acción `gesture_swipe`). Recorre exactamente `distance_px` (el último cuadro se recorta), sin gravedad, y al terminar deja `end_speed_px_s` (contra una pared, 0). «Debug cargando» = la pulsación larga en curso (`DebugMode.is_engaged()`, nuevo). Chispa gris = la del láser sin energía (`LaserMuzzle`), con `Isak.dash_denied` / `EventBus.dash_denied` (motivos `energy` y `debug`; el resto de casos se ignora sin aviso, como el pulso en el aire). Un dash del suelo que sale de un borde da el coyote y **no gasta** el dash aéreo (se puede deslizar otra vez en el aire tras el enfriamiento: revisarlo jugando y en el validador, paso 9). El dash no cuenta como combate para la regeneración pasiva (el gasto de energía sí lo detecta Energía 5). Arte provisional por script (`scripts/player/dash_effect.gd`): cuadro 2 de correr inclinado 8°, estela en `resplandor` con el borde en `borde_luz` (**`cian_tenue` no está en `mundo1.gpl`**: a decidir en el arte, paso 8), parpadeo blanco suave (el sprite se aclara) y anillo del enfriamiento en el celular. `test_arena` lo tiene desbloqueado. Pruebas: `tests/test_dash.gd`.
- **Paso 2.** Aviso `dash` en `data/ability_notices.json` («Deslizar: L / B (mando)»); fila «Deslizar» en Ajustes > Controles (tras Láser; `data/settings.json`). Como B ya era de Deslizar, al capturar B para otra acción sale el conflicto (Intercambiar / Cancelar). Capturas: 15-16 de `tools/render_pause_menu.gd` y 03-05 de `tools/render_ability_notices.gd` (en `ajustes_test`, con la línea del interruptor y un dash). Pruebas: `tests/test_ability_notices.gd` y `tests/test_controls.gd`.
- **Paso 3.** `dnd_switch` (`scripts/levels/dnd_switch.gd`, escena `scenes/levels/dnd_switch.tscn`; catálogo y sección `dnd_switch` de `data/world1_objects.json`; `tools/validate_level_schema.py` lo acepta, `ability` solo `dash`). Un pulso de espaldas; la línea `dnd_1_3` es **propuesta, por decidir**: «"No molestar" activado. Tranquilo, {apodo}: yo no cuento. Soy tu única excepción.» (con comillas latinas). Sin ayuda Q ni ficha del álbum (paso 8; el texto de Q de §2.4 sigue por decidir) y con el arte del `power_switch` más una luna por código; el tinte de la sala que «baja un punto» queda para el paso 8. `eco_line.unless_ability` admite `dash`. Sala `data/levels/ajustes_test.json` (26 × 12): interruptor, pasillo de techo bajo para probar el dash y terminal; la ruta no exige el dash. El validador no conoce aún el `dnd_switch` ni el dash (paso 9); la salida del 1-1 y del 1-2 es idéntica byte a byte. Pruebas: `tests/test_dnd_switch.gd` y `tests/test_level_schema.py`.
- **Paso 4.** El banner ya no golpea a Isak invulnerable (el dash usa la misma invulnerabilidad que `take_hit` ignora). Param nuevo de `spam_banner` **`knockback_to_entry`** (booleano, por defecto `false`: el 1-2 no cambia): el golpe resta 10 y **coloca a Isak en la celda de entrada del pasillo por su lado** (la siguiente al final del barrido: la `E` más `corridor_tiles` celdas hacia `direction`; `SpamBanner.get_return_position()`) y desde allí el retroceso normal; **desvío:** es un salto instantáneo a esa celda, no un deslizamiento animado (provisional, a revisar jugando). Esquema: `level_params` admite reglas booleanas; con `knockback_to_entry` el pasillo exige techo bajo en todo su largo (2 filas libres y la de encima sólida: sin nicho ni salto) y la celda de vuelta libre, con sitio y con suelo; `abilities_available` admite `dash`. **Desvío:** la ayuda propia va en el `help_id` del enemigo en el nivel (mecanismo que ya existía), no en `params`; tipo `spam_banner_dash` en `data/help.json` (título «Banner sin salida» y texto de §2.4, **propuestos, por decidir**) con ficha del álbum **provisional** (el dibujo del banner; la propia, en el paso 8). Validador: hasta el paso 9 **omite del plan** los banners con `knockback_to_entry` con un aviso («su pasillo solo se cruza con el dash…»); la salida del 1-1 y del 1-2 no cambia. Sala `data/levels/silenciados_test.json` (40 × 12): pasillo obligatorio de 12 tiles con `banner_dash` (320 px/s hacia Isak, cada 3 s) y pasillo con nicho con `banner_1b` (640 px/s); **desvío:** el 1b tiene 4 filas libres, no 3 (con 3, de pie en el nicho la cabeza toca el techo y no se puede salir: el validador lo da por soft-lock). Pruebas: `tests/test_spam_banner.gd` (dash a través, `knockback_to_entry`), `tests/test_silenciados_test_level.gd`, `tests/test_level_schema.py` y `tests/test_level_plan.py`. Capturas: `tools/render_silenciados_test.gd`.
- **Paso 5.** **`rhythm_zone`** (`RhythmZone`, `scripts/levels/rhythm_zone.gd`; catálogo y sección `rhythm_zone` de `data/world1_objects.json`): objeto lógico con `zone` (celdas absolutas), `tempo_steps_s`, `cycles_per_step`, `loop` y `start` (`on_enter` / `always`); su celda (x, y) es la del **icono de vibración** del fondo (dibujado por código, provisional), que late al empezar cada ciclo. Expone `get_beat_phase()` (0-1), `get_cycle_time()`, `get_cycle_s()`, `get_step_index()` y la señal `beat`; tiempo del mundo (el Debug lo ralentiza); vuelve al principio con `EventBus.player_respawned` (y, con `on_enter`, espera a que Isak vuelva a entrar). **`blink_platform`** (`BlinkPlatform`): sólida (tarjeta de 32 px como el recordatorio), sigue su `rhythm` con `on_fraction` y `offset` (fracción del ciclo); `group` es una etiqueta (los del mismo grupo llevan el mismo `offset`); 4 segmentos que se vacian, parpadeo de 9 cuadros a 12 fps antes de apagarse, contorno punteado apagada, no se materializa con Isak dentro. Esquema: zona dentro del grid, ciclos de 0,5-12 s, plataforma dentro de la zona de su metrónomo y `on_fraction` × ciclo más corto ≥ aviso + 0,25 s. `tools/build_level.py` escribe `tempo_steps_s` como lista aunque tenga dos números. **Desvío (a decidir jugando):** los ciclos de §3.3 (1,6 / 1,3 / 1,0 s con la mitad encendida) **no cumplen la propia regla del esquema** (0,5-0,8 s encendida < 0,75 s de aviso + 0,25 s), así que la sala usa el doble, **3,2 / 2,6 / 2,0 s**, y en el foso del 2a cada grupo está encendido el 60 % (se solapan un poco para poder saltar de una a otra). Validador: hasta el paso 9 trata las plataformas como **fijas** con un aviso; la salida del 1-1 y del 1-2 no cambia. Sin ayuda Q ni ficha (paso 8). Sala `data/levels/vibracion_test.json` (36 × 12): foso con A/B alternos, escalera en ola A → B → C y Debug disponible. Pruebas: `tests/test_rhythm_blink.gd`, `tests/test_vibracion_test_level.gd`, `tests/test_level_schema.py`, `tests/test_level_plan.py` y `tests/test_build_level.py`. Capturas: `tools/render_vibracion_test.gd`.
- **Paso 6.** **`alarm_tunnel`** (`AlarmTunnel`, extiende `RhythmZone`; catálogo de `data/world1_objects.json`): `zone` y `stages` (`[{x_from, x_to, cycle_s}]`, columnas absolutas en orden dentro de la zona); manda el tramo de la columna más avanzada que ha pisado Isak dentro de la zona (no retrocede, sin bucle; el tiempo no lo acelera); vuelve al principio al reaparecer. **`alarm_bell`** (`AlarmBell`, enemigo, `data/enemies/alarm_bell.json`): campana en la celda `E` colgada del techo; con cada ciclo de su `rhythm` (desplazado `offset`) o de su propio `interval_s`, aviso de 9 cuadros (tiembla y una línea discontinua roja marca la columna en el suelo) y onda de 0,4 s y un tile de ancho hasta el suelo (`wave_tiles`): −10 y empuja hacia atrás (`push_direction`); indestructible, no es un cuerpo, el dash la atraviesa; tiempo del mundo; grupo `enemy` (se reinicia al reaparecer). **`spam_banner`** admite **`rhythm`** y **`rhythm_offset`** (fracción): su intervalo pasa a ser el ciclo del metrónomo y su ciclo va con el compás (sin `rhythm`, como antes). Esquema: reglas de texto en `level_params`; campana con techo encima, onda libre hasta el suelo y ciclo ≥ aviso + onda + 0,25 s; banners y campanas con `rhythm` existente y ciclo más corto que deja reposo; tramos del túnel en orden y dentro de la zona. **Desvío (a decidir jugando):** los compases de §3.5 (2,0 / 1,5 / 1,1 s) no caben con la regla «aviso + onda + 0,25 s = 1,4 s» de la propia propuesta; la sala usa **2,0 / 1,6 / 1,4 s**. Validador: hasta el paso 9 omite del plan los banners con `rhythm` y no esquiva las campanas, con avisos; la salida del 1-1 y del 1-2 no cambia. Sin ayuda Q ni ficha (paso 8; arte provisional por código). Sala `data/levels/alarmas_test.json` (40 × 12): túnel de tres tramos (4a techo de 3 filas, 4b de 3 y después de 2, 4c de 2), seis campanas desfasadas y dos banners con `rhythm`. Pruebas: `tests/test_alarm_tunnel.gd`, `tests/test_alarmas_test_level.gd`, `tests/test_level_schema.py` y `tests/test_level_plan.py`. Capturas: `tools/render_alarmas_test.gd`.
- **Paso 7.** **`glitch_wall`** admite **`visible_only_with_debug`** (booleano, por defecto `false`: el 1-1 y el 1-2 no cambian): sin nada revelado por el Debug (`DebugMode.is_revealing()`: activo o su persistencia de Debug 3) la pared no hace ráfagas y se ve como terreno normal (cuadro 0 del borde que le toca); con el Debug muestra el glitch y se disuelve como siempre (activo e Isak a menos de 3 tiles). La Q la sigue marcando (decisión 8 de §8). `GlitchWall.is_glitch_shown()`. **Decorado `exceptions_panel`** (`ExceptionsPanel`, `scripts/levels/exceptions_panel.gd`; catálogo y sección `exceptions_panel` de `data/world1_objects.json`): panel de `width_tiles` × `height_tiles` detrás de Isak con `title` («Permitir llamadas de: Favoritos») y una fila por nombre de `contacts` («Mamá», «Abuelito») con un icono genérico de persona y una estrella; **solo decorado** (sin colisión, sin Q ni ficha, sin estado); **arte provisional por código** (paleta del Mundo 1; la estrella en `borde_luz`, no en ámbar, que es de los puntos); los textos del panel son **propuesta**. El `memory_pickup` y la recompensa `memory` ya existían (paso 4 de `propuesta-recuerdos.md`): no cambian. Esquema: `visible_only_with_debug` booleano; `exceptions_panel` con `title` no vacío, `contacts` lista no vacía de nombres y tamaño 2-16 × 2-8; **`forbid_abilities`** en `secrets` (lista no vacía de habilidades conocidas, sin repetir; el validador de alcanzabilidad la exige en el paso 9: hoy no modela el dash, así que su ruta ya es sin dash). **Desvío:** como el 1-3 aún no existe y `msg_1_3` es del nivel `1-3`, una sala de prueba puede llevar **`stands_for: "1-3"`** (solo en niveles `*_test`, subnivel del mismo mundo): hace las veces de ese subnivel para los mensajes de secreto (`tools/validate_level_schema.py` y `tools/validate_memories.py`); al construir el 1-3 real el secreto irá en su celda (125, 4) con el JSON de §5.4. **Desvío:** el punto del secreto va en una celda `o` junto a la `S` (como el 1-1 y el 1-2), no como `"object": "memory_pickup"` del ejemplo de §5.4 (el sobre está en la celda `S`, en su mitad alta). Sala `data/levels/excepciones_test.json` (30 × 12; pulso, Debug y dash; `stands_for` 1-3): pasillo con la terminal (15, 9) antes de la pared, pared de la columna 18 con la `glitch_wall` `pared_excepciones` de 1 × 2 en (18, 9) y, detrás, la sala con el panel `panel_excepciones` (20, 3; 5 × 3), el sobre `mensaje_1_3` en `secreto_excepciones` (24, 10) y su punto (26, 10). El texto de `msg_1_3` seguía provisional en este paso; **definitivo desde el 2026-10-20** (asunto «Cuando quieras», §10 de `propuesta-recuerdos.md`), igual que los textos del panel. Pruebas: `tests/test_excepciones_test_level.gd` (sin el Debug parece terreno y no se cruza; con el Debug lejos muestra el glitch sin abrirse y al apagarlo vuelve a parecer terreno; con el Debug cerca se abre y el mensaje y el punto se recogen andando, sin el dash; obtenido no reaparece; el panel es solo decorado; la pared normal sigue haciendo ráfagas), `tests/test_level_schema.py` y `tests/test_memories.py`. Sin capturas propias (las de la sala «Excepciones» son del paso 12).

Orden: 1 → 2 → 3; 4 y 5 en paralelo con 3; 6 tras 4 y 5; 7 cuando exista el paso 4 de recuerdos; 8; 9; 10; 11; 12.

**Pruebas previstas:** GUT del dash (suelo, aire, paredes, plataformas de una vía, sin energía, enfriamiento, invulnerable contra banner y punto rojo lanzado, no con Debug, apaga Ocultarte, reaparición), del interruptor (una vez, guardado, Papelera, rollback), de cada objeto nuevo y de su sala, del nivel completo y del bot; Python del esquema, del validador (casos positivos y negativos) y del camino exportado; `tools/level_climbs.py` sobre el 1-3 con su fixture.

**Riesgos:** (1) el dash aéreo abre atajos en mapas ya hechos (1-1, 1-2): al rejugarlos con el gesto, el validador debe seguir dándolos por válidos y los secretos no deben volverse triviales (revisarlo en el paso 9 con `abilities_available.dash`); (2) el ritmo sin sonido puede leerse mal: probar con jugadores y, si hace falta, reforzar el aviso (más segmentos, más contraste); (3) energía en el Tramo 4: medir con el bot que `cargador_3` basta; (4) el validador crece otra vez (dash + fases): mantener la salida del 1-1 y del 1-2 idéntica byte a byte.

## 8. Preguntas abiertas (con recomendación)

**Aprobadas el 2026-10-19:** el usuario aceptó las 13 con la recomendación que figura en cada una (primer banner con `knockback_to_entry`; el dash atraviesa Burbujas y puntos rojos sin daño ni aturdirlos; con el Debug activo no sale —chispa gris—; apaga el Ocultarte; valores de §2.1 provisionales que se ajustan jugando; bucle en el Tramo 2 y túnel por posición; power bank y punto en el secreto C; pared sin glitch sin el Debug y marcada por la Q; la puerta vuelve al hub hasta que exista Alerta Mayor; el Debug ralentiza el ritmo; L / B se mantienen; rejugar el 1-1 y el 1-2 con el dash permitido). La 12 (historia) sigue **por decidir**: los textos de Eco y de los carteles que se implementen son propuestas marcadas como tales. Los pasos 1-3 de §7 están hechos (2026-10-19).

1. **¿Cómo se hace obligatorio el primer banner?** *Recomendación:* techo bajo sin nicho + `knockback_to_entry` (el golpe te devuelve a la entrada). Alternativa: un «banner fijo» que tapa el pasillo y solo se cruza con el dash (no barre, menos fiel a «barren a un ritmo»).
2. **¿El dash atraviesa a Burbujas y puntos rojos sin daño?** *Recomendación:* sí, invulnerable y sin aturdirlos ni dañarlos (eso queda para Embestida y Filo del Mundo 5).
3. **Dash con el Debug activo («no se combinan»): ¿no sale, o apaga el Debug?** *Recomendación:* no sale (chispa gris); así el jugador nunca pierde el Debug por error encima de una plataforma oculta.
4. **¿El dash apaga el Ocultarte?** *Recomendación:* sí, como el pulso y el láser.
5. **Valores:** distancia 3 tiles, 0,2 s, invulnerable 0,3 s, coste 10, enfriamiento 0,5 s, un dash aéreo sin gravedad. *Recomendación:* empezar así y ajustar jugando.
6. **Ritmo:** ¿el compás vuelve al lento tras el más rápido (bucle) o se queda rápido? ¿y el túnel se acelera por posición? *Recomendación:* bucle en el Tramo 2 (quien espera recupera el lento); por posición y sin bucle en el túnel (es la prueba final).
7. **¿Power bank en el 1-3 y punto extra en el secreto C?** *Recomendación:* sí, 1 power bank vacío + 1 punto en el secreto C (9 puntos en total; los niveles 5 de las cinco pistas piden 5 power banks con un tope de 3 a la vez).
8. **Pared del secreto:** ¿sin glitch visible sin el Debug? ¿La Q de Eco la marca antes de usar el Debug? *Recomendación:* sí a las dos (la Q marca el secreto de un mensaje pendiente, regla de `propuesta-recuerdos.md` §10; el Debug ya se tiene).
9. **Cierre sin jefe:** *Recomendación:* la puerta de bloqueo vuelve al hub hasta que exista Alerta Mayor.
10. **¿El Debug ralentiza el ritmo (tiempo del mundo)?** *Recomendación:* sí, coherente con los temporizadores del 1-2; como impide el dash, es una elección.
11. **Controles:** L / B (mando) ya asignados a `gesture_swipe`. *Recomendación:* mantenerlos.
12. **Historia:** línea de Eco al obtener el gesto, textos de interfaz de los carteles y mensaje definitivo de Mamá. **Por decidir con el usuario.**
13. **Rejugar el 1-1 y el 1-2 con el dash:** *Recomendación:* permitirlo (el gesto es de Isak) y revisar con el validador que ningún secreto se vuelve trivial.
