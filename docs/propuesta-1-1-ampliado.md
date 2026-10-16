# Propuesta: 1-1 ampliado y mejoras permanentes

**Estado:** APROBADA con cambios e IMPLEMENTADA (2026-10-14): ver «Notas del 1-1 ampliado» en `docs/preguntas.md`. El rediseño para el láser (2026-10-15) está en §7 y sustituye lo que contradiga de las secciones anteriores. Lo de abajo es el texto original de la propuesta. No cambia código, datos ni escenas. Lo marcado **[propuesta nueva]** no está en `docs/` y necesita aprobación expresa.

**Punto de partida.** El 1-1 actual (`data/levels/1-1.json`) mide 140x14 tiles, con 5 tramos, 1 Burbuja, 1 punto de sincronización y 17 puntos de atención, y dura unos 25 s corriendo y 38 s caminando. La ficha (`mundo-1-notificaciones.md` §6.3) pide unos 3 min, dificultad 1/5 y "prácticamente sin riesgo de muerte", y `target_duration_s` ya vale 180. Física de referencia (`isak_physics.json`): 220 px/s caminando (3,4 tiles/s), 360 px/s corriendo (5,6 tiles/s), salto efectivo de 177 px (192 × 0,92), límite de exigencia del validador del 85 %.

## 1. Estructura de tramos

Se mantienen los 4 tramos de la ficha y el cierre, en el mismo orden. Cada tramo se divide en partes (a, b, c) que repiten la mecánica con más exigencia. El nivel pasa a **300x14 tiles**. Las columnas son aproximadas y se ajustan con el validador.

| Tramo (columnas, tiles) | Qué enseña y cómo sube la exigencia | Enemigos y objetos | Puntos de atención | Tiempo caminando / corriendo |
|---|---|---|---|---|
| **1. Aterrizaje** (1-55, 55) | Salto, subidas de 1 y 2 tiles y plataformas de una vía. Un segundo foso de 2 tiles, también con fondo (V3). | Sin enemigos. `eco_line` de bienvenida (ya existe). | 6, en la ruta (x 8-45) | 20 s / 12 s |
| **2. Puente** (56-115, 60) | 2a: el puente actual (receptor a ras de suelo, 6 tiles). 2b: el receptor está sobre una repisa de 1 tile y hay que subir antes de pulsar; después vienen dos puentes seguidos (4 y 5 tiles) sobre fosos con fondo. | 3 receptores y 3 puentes en la ruta. | 6 | 30 s / 20 s |
| **Punto de sincronización 1** (x≈118) | Entre el Tramo 2 y el 3, como propone A12. | `C` | | |
| **3. Burbuja** (118-195, 78) | 3a: el techo bajo actual con 1 Burbuja (80 px/s, rango de 320 px), desplazado sin cambios. 3b: una Burbuja delante de una repisa de 3 tiles (192 px, más alta que el salto). Hay que aturdirla y usarla de escalón (plataforma a 74 px). Es obligatorio y enseña que "el aturdimiento abre algo" (§3.2). 3c: dos Burbujas (80 y 100 px/s) con una franja de pinchos de 2 tiles entre ellas (quita un 10 %). | 4 Burbujas y los primeros `^` del juego. | 8 | 45 s / 30 s |
| **Punto de sincronización 2** (x≈198) | Antes del último tramo. Es un desvío de la ficha, que pide "uno": ver la duda 5. | `C` | | |
| **4. Pop-up** (198-265, 68) | 4a: el pop-up actual a ras de suelo. 4b: un pop-up sobre un escalón de 1 tile, con una Burbuja patrullando delante: primero se aturde y luego se cierra el pop-up. 4c: receptor, puente y un pop-up al final del puente, que se cierra de pie sobre el puente. | 3 pop-ups, 1 Burbuja, 1 receptor y 1 puente. | 6 | 40 s / 25 s |
| **Cierre** (266-298, 33) | Recta tranquila. Puerta "Marcar como leído" en x≈288 y pared con glitch detrás (x≈297, como ahora). | `exit_door`, `glitch_wall` | 2 | 10 s / 6 s |

**Totales:** ruta principal de unos 145 s caminando y 95 s corriendo; con los secretos, unos 185 s. Hay 28 puntos de atención en la ruta y 8 más en los secretos (V8 proponía de 10 a 20; ver la duda 4). La dificultad sigue siendo 1/5: no hay huecos sin fondo, la red de seguridad del 1-1 no quita Sync Rate y harían falta 10 golpes para morir.

### Secretos (obligan a fijarse en el mapa y volver atrás)

| Id | Dónde se ve y cómo se llega | Recompensa |
|---|---|---|
| **A. Puente de servicio** | El nicho se ve en lo alto (x≈92-97, fila 4) al cruzar 2a, pero desde ahí no se alcanza. Al final del Tramo 2, unas plataformas de una vía suben hasta un receptor escondido (x≈110, fila 5). Su puente se extiende **hacia la izquierda** (`direction: "left"`, 10 tiles) y hay que volver por él. | Mejora "Pulso amplio" |
| **B. Sobre el techo** | Desde la repisa de 3b se sube por plataformas de una vía hasta el techo de 3a (cara superior a 320 px del suelo) y se vuelve a la izquierda por encima, hasta x≈126-130. | 1 power bank y 5 puntos |
| **C. Pop-up alto** | Un pop-up opcional en una repisa alta (x≈240) tapa un nicho. Para subir hay que usar como escalón la Burbuja de 4b, aturdida, y después volver atrás. | Mejora "Sync reforzado" y 3 puntos |
| **D. Pared con glitch** | La de siempre. No se puede abrir hasta tener el Debug: al rejugar el nivel desde el hub (V12). | 1 power bank y la mejora "Debug eficiente" (V12 sigue pendiente) |

Regla de diseño: ninguna caída sobre una Burbuja debe superar 4 tiles, porque desde 5 tiles ya revienta (`alert_bubble.json`, `pop_speed_threshold_px_s`). Todo secreto debe tener una salida de vuelta a la ruta.

## 2. Mejoras permanentes

Funcionamiento propuesto: un secreto **desbloquea** la mejora y queda guardada como "disponible". Se **activa pagando** en el hub con Calc, que según §13.3 vende "mejoras permanentes a cambio de puntos de atención". Como el hub no existe hasta vencer a Alerta Mayor, mientras tanto la pantalla provisional del hub tendría una lista "Mejoras" para probarlas. Una mejora comprada se aplica en todos los niveles y se guarda en disco.

| Mejora | Efecto (valor actual → nuevo) | Coste | Se consigue en | ¿Se puede usar ya? |
|---|---|---|---|---|
| **Pulso amplio** [propuesta nueva] | `pulse_radius_px` 96 → 112 | 15 puntos | Secreto A (1-1) | Sí, en el 1-1 al rejugarlo |
| **Sync reforzado** (§13.3: "más Sync Rate") | Sync Rate máximo 100 → 120 (el HUD tendría que mostrar más de 100 %) | 30 puntos + 1 power bank | Secreto C (1-1) | Sí, en el 1-1 al rejugarlo |
| **Debug eficiente** (idea del usuario) | `drain_per_second` 20 → 15 (de 5 s a 6,7 s con la barra llena) | 50 puntos + 1 power bank | Secreto D (1-1 con Debug) | No: el Debug llega en el 1-2. Ahora solo se prueba en `debug_sandbox.tscn` |
| **Batería ampliada** (§13.3 y Calc en §12.3) | Energía máxima 100 → 150 | 30 puntos + 1 power bank | Secreto de un nivel posterior (por decidir) | No, desde el 1-2 |
| **Arranque rápido** (idea "cargar el Debug") | `activation_hold_s` 1,0 → 0,5 s | 20 puntos | Por decidir (1-2 o 1-3) | No, desde el 1-2 |
| **Recarga mejorada** | Energía que repone cada punto: 10 → 15 (A10) | 25 puntos | Por decidir | Depende de cómo se decida la recarga |

**Power bank** [propuesta nueva]: es un coleccionable que solo sirve para pagar mejoras. No es una mecánica de juego. En el 1-1 hay 2 (los secretos B y D). Con los 36 puntos del 1-1 no alcanza para "Debug eficiente": hay que sumar los del 1-2, y eso tiene sentido porque el Debug se aprende allí.

**Guardado:** un archivo `user://save.json` con número de versión que guarda `attention_points`, los power banks recogidos (por id), las mejoras disponibles y compradas, los secretos encontrados, las pistas de Eco ya vistas y los niveles completados. Se escribe al tocar un punto de sincronización, al recoger un secreto, al terminar el nivel y al comprar una mejora. `GameState` lo carga al arrancar.

## 3. Frases de Eco para las primeras veces

> **[Reemplazado 2026-10-15 (3)]**: Eco ya no lanza estas líneas solo. Salvo la presentación y el láser (momentos de historia), pasan a ayuda con Q por tipo o se eliminan. La tabla de destino de cada línea está en `propuesta-asistentes-y-vidas.md` §4.

Las dice Eco con su voz: amable, servicial y corporativa, sin amenazar (§12.1). No añaden historia. Se muestran con el cuadro de Eco que ya existe (`eco_line`), una vez por partida guardada. `[pulso]` se cambia por la tecla asignada en el Input Map.

| Primera vez | Frase |
|---|---|
| Foso (T1) | "Ese hueco no es un problema. Salta y seguimos." |
| Punto de atención | "Cada punto de atención cuenta. Yo también los cuento." |
| Receptor (2a) | "Ese receptor espera un pulso. Acércate y pulsa [pulso]. Te ahorro la búsqueda." |
| Puente extendido | "¿Ves? Todo funciona mejor cuando colaboras." |
| Punto de sincronización | "Punto de sincronización. Guardo tu progreso. Para eso estoy." |
| Burbuja (3a) | "Una alerta. Un pulso y se queda en pausa unos segundos." |
| Burbuja aturdida como escalón (3b) | "Una alerta en pausa también sirve de escalón. Nada se desperdicia." |
| Pinchos (3c) | "Zona sin optimizar. Mejor no la pises." |
| Pop-up (4a) | "Un aviso importante. El botón de cerrar es pequeño, por tu bien. Pulso de cerca." |
| Power bank | "Batería externa detectada. Guárdala, quizá te ahorre tiempo." |
| Pared con glitch | "Eso es un error de visualización. Ignóralo, por favor." |
| Puerta | "Marca todo como leído. Así no te preocupas de nada." |

## 4. Impacto técnico y riesgos

- **`data/levels/1-1.json`:** el grid pasa de 140 a 300 columnas, con nuevos rangos en `sections`. Se pasa de 1 a 5 Burbujas (con `params` propios), de 1 a 5 receptores y puentes (uno con `direction: "left"`), de 1 a 4 pop-ups, de 1 a unas 12 `eco_line` y de 1 a 2 checkpoints. Aparecen `^` y `S` con un campo `reward`. Se regenera la escena con `build_level.py`.
- **`data/world1_objects.json`:** nuevo tipo `power_bank` [propuesta nueva] (escena y sprite con la paleta del Mundo 1) y un parámetro `hint_id` en `eco_line` para la regla "una vez por partida guardada".
- **Nuevo `data/upgrades.json`:** id, archivo y clave que modifica, valor nuevo y coste. El juego aplica la mejora sobre el valor base, sin reescribir `isak_physics.json`, `isak_abilities.json` ni `debug_mode.json`.
- **Validadores:** `validate_level_schema.py` tiene que aceptar `reward` en los secretos y el tipo nuevo. `validate_level.py` tiene que modelar la Burbuja aturdida como escalón (hoy solo la modela como puerta bajo el techo bajo), comprobar que los secretos son opcionales y tienen salida, y validar con los valores **base** (sin mejoras).
- **Pruebas que se rompen:** `play_level_bot.gd`, `test_tramo3_ceiling.gd` y las demás pruebas que usan columnas fijas del 1-1. Hay que desplazarlas o leer las columnas del JSON.
- **Riesgos:** (1) un tutorial demasiado largo: la skill `level-builder` avisa de que alargar sin motivo hace el nivel pesado, así que hay que medirlo jugando y recortar 3c o 4c si sobra; (2) que se puedan farmear puntos al rejugar (duda 4); (3) que una mejora como "Pulso amplio" abarate el reto del pop-up; (4) migrar el formato del guardado cuando cambie; (5) que las mejoras de Debug no se puedan probar en el 1-1.

## 5. Dudas para el usuario (en orden de importancia)

1. **¿Dónde se activan las mejoras?** Opción a: en el hub con Calc, como dicen los docs (no existe hasta vencer a Alerta Mayor; mientras tanto, en la pantalla provisional del hub). Opción b: se activan solas al recogerlas, si se tienen los puntos y el power bank.
2. **¿Se aprueba el power bank** como coleccionable nuevo, y **"Pulso amplio"** como mejora que no viene de los docs?
3. **Recarga de energía y "cargar el Debug":** ¿"cargar" significa activarlo más rápido (Arranque rápido) o recargar la energía? La "Recarga mejorada" depende de esta decisión.
4. **Puntos de atención al rejugar:** ¿cada punto se recoge una sola vez por partida guardada (sin farmeo) o reaparece? ¿Se aceptan 28 en la ruta en lugar de los 10 a 20 de V8?
5. **Desvíos de la ficha:** ¿se aceptan un segundo punto de sincronización y pinchos (10 %) en el 1-1?
6. **Pistas de Eco:** ¿se muestran una vez por partida guardada o cada vez que se juega el nivel? ¿Se enseña la tecla dentro del texto?

## 6. Economía de puntos y mejoras (decisión del usuario, 2026-10-15; revisada el mismo día tras jugar el 1-1; IMPLEMENTADA)

Sustituye los costes de §2 y el reparto de puntos de «Notas del 1-1 ampliado» (`docs/preguntas.md`). Los valores son **propuestas** y se ajustan jugando. La primera versión de esta sección (30 puntos por mapa) daba demasiados puntos; los valores «anterior» de las tablas son los de esa versión.

**Decisiones:** (a) pocos puntos de atención por mapa, dispersos y no en filas seguidas: el jugador reúne lo justo para comprar «Pulso amplio» (25) al terminar el 1-3, tres mapas completos, sin que sobren muchos; ningún mapa solo paga una mejora; (b) el 1-1 tiene **un solo** power bank (vacío), escondido en el secreto que exige «Pulso amplio»; los demás llegan desde el 1-2, cuando se aprende el Debug; (c) «Pulso amplio» se presenta como necesidad con ese secreto del 1-1, al que se vuelve tras comprar la mejora en el hub.

**Criterio y fórmula:**

- **Puntos por mapa objetivo:** unos **9** (unos 6 en la ruta y unos 3 en los secretos). Antes: unos 30 (20 + 10). Una vuelta (18 mapas) da como mucho 18 × 9 = **162** puntos (108 solo con la ruta). Los puntos no se recapturan.
- **Coste de una mejora** = 9 × N redondeado a 5, donde N son los mapas completos (con secretos) que hay que ahorrar para pagarla. Antes: 30 × N. N crece con la potencia de la mejora y con el momento del juego en que es útil; se mantiene el de la versión anterior, salvo Pulso amplio, que pasa de 0,83 a unos 3 mapas (1-1, 1-2 y 1-3).
- **Comprobaciones:** (1) un mapa completo (9) no paga ninguna mejora; (2) tres mapas completos (27) pagan Pulso amplio y sobran menos de 5 puntos; (3) la ruta sola de tres mapas (18) no llega: hacen falta los secretos; (4) la suma de todas (210) supera lo que da una vuelta (162), así que en la primera vuelta no se compran todas (propuesta de tres vueltas en `docs/preguntas.md`). `tests/test_level_schema.py` comprueba las cuatro.

| Mejora | Coste anterior → nuevo (puntos) | Power banks | N (mapas completos, 9 por mapa) | Mapas solo con la ruta (6 por mapa) |
|---|---|---|---|---|
| Pulso amplio | 25 → **25** | 0 | 2,8 (1-1, 1-2 y 1-3 completos) | 4,2 |
| Arranque rápido | 60 → **20** | 0 | 2,2 | 3,3 |
| Recarga mejorada | 90 → **25** | 0 | 2,8 | 4,2 |
| Batería ampliada | 120 → **35** | 1 | 3,9 | 5,8 |
| Sync reforzado | 150 → **45** | 1 | 5 | 7,5 |
| Debug eficiente | 200 → **60** | 1 | 6,7 | 10 |
| **Total** | 645 → **210** | 3 | 23,3 (> 18) | 35 |

(N de la tabla = coste / 9 tras redondear a 5; antes de redondear, 3, 2, 3, 4, 5 y 6,7 mapas.)

**Puntos del 1-1 (anterior → nuevo):** ruta 20 → **6** (uno al principio del Tramo 1 junto a la línea de Eco de los puntos, uno en lo alto del Tramo 1, uno en la meseta del 2b, uno en la repisa de la Burbuja escalón del 3b, que solo se alcanza subiendo por la Burbuja aturdida, uno en el escalón del pop-up del 4b y uno antes de la puerta); secretos A 3 → **1**, B 3 → **1** y C 4 → **1**; secreto del Pulso amplio 5 puntos → **1 power bank vacío** (0 puntos). Total 35 → **9** (todos sin mejoras).

**Secretos del 1-1:** A, B y C son secretos de puntos (celda `S` con `reward: "attention_points"` y `points`). El del Pulso amplio es un objeto: `{"object": "power_bank_pickup", "reward": "power_bank", "requires_upgrade": "wide_pulse"}` sobre el power bank `power_bank_pulso_amplio`, el único del 1-1. Vuelve la frase de Eco del power bank («Batería externa detectada. Guárdala, quizá te ahorre tiempo.»), dentro del nicho.

**Secreto del Pulso amplio (`secreto_pulso_amplio`):** un nicho cerrado a la izquierda del techo de 3a (columnas 121-125, filas 1-4; el power bank está en la columna 122, fila 4), tapado por el pop-up `popup_lejano` (columnas 126-128, filas 1-4). Se ve al hacer el secreto B: encima del techo, Isak llega andando hasta pegarse al pop-up, en la columna 129, mirando a la izquierda. Es el único sitio desde el que puede lanzar el pulso hacia el botón (el pulso solo sale de pie; el nicho tiene techo y paredes). El botón de cerrar está en `close_button_px` [52, 192]. Con la geometría del juego (centro de Isak a 16 px de la cara del pop-up y celular en `pulse_effect_origin` (36, -56)), el botón queda a **104 px** del celular, más que el radio base (96) y no más que el mejorado (112). Hay que volver al nivel tras comprar la mejora en el hub; el power bank recogido se guarda por id y no se repite. Línea de Eco de primera vez: «Ese botón queda un poco lejos. Con un pulso más amplio llegarías.» Se usa un pop-up en lugar de un receptor porque la zona de golpe del receptor es fija (`hit_rect` [12, 0, 40, 64]) y, en la cuadrícula de 64 px, desde una pared ninguna posición queda entre 96 y 112 px. Desde el borde de una repisa sí cabría, pero el resultado dependería de cuánto se asoma Isak.

**Burbujas del 1-1 (2026-10-15, tras jugarlo):** antes las cinco iban bajo techo bajo y no se podían pisar ni reventar. Ahora solo `burbuja_1` (3a) sigue bajo techo bajo, como puzle obligatorio del Tramo 3. Las otras cuatro van en abierto (campo `"open": true` del enemigo) con una patrulla corta y una repisa de una vía 3 tiles por encima de su suelo, junto a la patrulla. Con la Burbuja aturdida, Isak la usa de escalón (74 px + salto de 177 px = 251 px, el 76 % para subir 192 px) para llegar a la repisa. Desde la repisa, saltando, cae sobre ella a unos 1357 px/s, por encima del umbral de pop (1150), así que revienta y suelta sus recargas (energía +25, Sync +10). Bajando andando cae a unos 860 px/s y solo la pisa. Una caída sin salto desde 5 o 6 tiles no sirve aquí, porque la Burbuja solo revienta si está aturdida (C7) y el aturdimiento dura 3 s: no da tiempo a subir tan alto. Saltar desde la repisa de 3 tiles equivale a caer desde unos 5,8 tiles. El escalón, la repisa y el pop caben en unos 2,1 s de los 3 s (`tests/test_level_1_1.gd`). No cambia ningún valor de `data/enemies/alert_bubble.json`.

| Burbuja | Tramo | Antes | Ahora |
|---|---|---|---|
| `burbuja_1` | 3a | techo bajo, (132, 9), 80 px/s, rango 320 | igual (único techo bajo) |
| `burbuja_2` | 3b | techo bajo sobre la meseta, (164, 8), 100 px/s, rango 320 | en abierto, (164, 8), 80 px/s, rango 128; repisa en las columnas 166-168 (fila 6) con un punto: «Burbuja escalón», con la línea de Eco «Una alerta en pausa también sirve de escalón. Nada se desperdicia.» |
| `burbuja_3` | 3c | techo bajo, (184, 9), 80 px/s, rango 256 | en abierto, (182, 9), 80 px/s, rango 128 |
| `burbuja_4` | 3c | techo bajo, (193, 9), 100 px/s, rango 256 | en abierto, (190, 9), 100 px/s, rango 128; repisa compartida con `burbuja_3` en las columnas 184-188 (fila 7) |
| `burbuja_5` | 4b | techo bajo, (230, 9), 80 px/s, rango 320 | en abierto, (230, 9), 100 px/s, rango 128; repisa en las columnas 232-233 (fila 7) |

**Validador:** `validate_level.py` usa los valores base y admite `--upgrades wide_pulse`. En cada pasada comprueba que un secreto con `requires_upgrade` no se alcanza sin la mejora y sí con ella, y que la meta se alcanza sin mejoras. `tools/run_tests.sh` lo ejecuta con y sin la mejora. El secreto del Pulso amplio es ahora el power bank (con la mejora se alcanza, sin ella no). Una Burbuja con `"open": true` no avisa de que su pulso no es obligatorio; avisa si en realidad bloquea o si no tiene cerca una repisa desde la que, saltando, se caiga sobre ella por encima del umbral de pop con un 10 % de margen, e informa de esa repisa.

## 7. Rediseño para el láser (decisiones del usuario, 2026-10-15; IMPLEMENTADO)

Decisiones: (a) más Burbujas al principio, de forma gradual, que se esquivan o se aturden con el pulso sin obligar a matarlas; (b) el láser se obtiene en el 1-1, obligatoriamente y a mitad del nivel, con un puzle hecho con el pulso y mecánicas existentes; (c) dos cargadores; (d) energía compartida con el Debug (bloqueado en el 1-1); (e) vida por instancia (`params.health`); (f) las Burbujas en abierto ya no necesitan repisa; (g) se mantienen el checkpoint único, sin pinchos, los 9 puntos, los secretos y la longitud. Física de Isak y valores del láser y de la Burbuja: sin cambios. Los textos nuevos de Eco son **propuestas**.

**Sala del láser (Tramo 3b, columnas 146-176, justo tras el punto de sincronización de la columna 150).** La base de la sala (columnas 169-175, 4 tiles de alto) corta el paso por el suelo, así que hay que subir y cruzarla por dentro:

1. Receptor 1 en el suelo (columna 153): extiende `puente_laser_1` **en alto** (columnas 159-162, fila 8, 2 tiles sobre el suelo), a continuación de un escalón de 2 tiles (155-157), con un hueco de un tile entre ambos.
2. Desde ese puente se sube a una repisa flotante (163-164, fila 6) con el receptor 2 (164, 5), que también se alcanza con el pulso desde el final del primer puente.
3. El receptor 2 extiende `puente_laser_2` (165-168, fila 6), a 4 tiles del suelo, hasta la sala.
4. La entrada está tapada por el pop-up `popup_laser` («Función premium bloqueada. Mira este anuncio para continuar»), con un techo encima. Su botón solo se alcanza de pie al final del segundo puente.
5. Detrás, un túnel de 2 tiles de alto (172-175, filas 4-5) guarda el `ability_pickup` `laser_1_1` (173, 5). Con ese techo no se puede saltar por encima. Al salir por la derecha se cae al suelo.

Sin cada puente no se llega al siguiente nivel de altura: del escalón a la repisa hay 4 tiles en horizontal y de la repisa a la sala otros 4, más que un salto corriendo (unos 3,2 tiles). Sin el pulso no se cierra el pop-up. El suelo bajo los puentes está unido al resto del tramo, así que no hay soft-lock: si Isak cae, vuelve al escalón por el hueco de la columna 158. El puzle es una escalera de dos receptores en la que el primer puente sirve de apoyo para alcanzar el segundo receptor, y acaba con un pop-up en alto.

**Burbujas (9; antes 5).** Todas con `open: true` salvo `burbuja_1`.

| Burbuja | Tramo | Posición | px/s | Rango | Vida | Papel |
|---|---|---|---|---|---|---|
| `burbuja_t1a` | 1 | (30, 9) | 60 | 128 | 2 | Primera, lenta, bajo la plataforma de una vía (se salta, se pasa por arriba o se aturde). Antes, la línea de Eco «Una alerta. Un pulso y se queda en pausa unos segundos.» |
| `burbuja_t1b` | 1 (final) | (50, 9) | 80 | 192 | 2 | Antes del receptor del 2a |
| `burbuja_t2c` | 2c | (104, 9) | 100 | 256 | 2 | La primera rápida |
| `burbuja_1` | 3a | (132, 9) | 80 | 320 | 2 | Techo bajo: aturdirla es obligatorio. Línea nueva: «Aquí no hay sitio para saltarla. Un pulso y la dejo en pausa por ti.» |
| `burbuja_3`, `burbuja_4` | 3c | (182, 9), (190, 9) | 80, 100 | 128 | 2 | Las primeras tras el láser. Su repisa de una vía (184-188, fila 7) guarda ahora el punto de la ruta de la antigua repisa del 3b (186, 6), al que se sube con una de ellas aturdida como escalón. Aquí se mueve la línea «Una alerta en pausa también sirve de escalón. Nada se desperdicia.» |
| `burbuja_t4a` | 4a | (210, 9) | 80 | 192 | 2 | Delante del pop-up del 4a |
| `burbuja_5` | 4b | (230, 9) | 100 | 128 | 2 | Sin repisa (la del 4b solo servía para reventarla) |
| `burbuja_cierre` | Cierre | (283, 9) | 80 | 128 | **3** | Final: tres disparos |

**Cargadores** (valores por defecto: 50 de energía, reutilizables, 20 s): `cargador_1` (178, 9), entre la sala del láser y la primera Burbuja que cuesta energía, y `cargador_2` (279, 9), al empezar el Cierre, antes de la Burbuja con vida 3. No se pone ninguno junto al checkpoint porque antes del láser no se gasta energía: la barra está llena y el cargador no haría nada.

**Energía.** Isak llega al láser con la barra llena (100, `start_state`), porque en el 1-1 nada gasta energía antes. Matar las cinco Burbujas posteriores cuesta 11 disparos (110). Sus drops dan 5 × 25 = 125 y cada Burbuja de vida 2 deja un saldo de +5, así que sin fallar disparos la energía no se agota (el bot termina con 100). El reto real es apuntar. Con un 30 % de fallos harían falta unos 16 disparos (160), y siguen sobrando 100 + 125. Los cargadores son una red de seguridad para quien falla mucho. La duda 1 de «Rediseño del 1-1 para el láser» en `docs/preguntas.md` propone empezar con menos energía.

**Eco (propuestas).** Al recoger el láser sale el aviso de interfaz del catálogo («Láser obtenido. F o gatillo izquierdo: dispara. Gasta energía.») y, en el túnel, «Herramienta nueva. Dispara hacia donde miras; cada disparo gasta energía.». Al disparar por primera vez en el nivel sale «Dos impactos bastan para cerrar una alerta. Lo que suelta, recógelo: es tuyo.». Para esta última, `eco_line` tiene un param nuevo, `trigger_event`, con un valor admitido: `laser_fired`, una señal de EventBus. Con ese param la línea no usa zona. Antes de la sala sale «Ahí arriba guardo algo útil para ti. Los receptores conocen el camino.». Las líneas de Eco no nombran teclas, como las demás.

**Puntos:** siguen siendo 9 (6 en la ruta y 1 en cada secreto A, B y C). El de la repisa del 3b pasa a la repisa del 3c. La economía no cambia.

**Validador (`tools/validate_level.py`):**
- Ya no busca la repisa de pop.
- Un puente extendido es una tabla fina (`bridge.collision_height_px`, 12 px) en lo alto de su celda: se puede estar de pie debajo, pero no atravesarla. Antes se modelaba como un tile sólido, y el suelo bajo un puente en alto parecía un soft-lock.
- Los `ability_pickup` son un estado del grafo que se activa al tocar su celda. El validador comprueba que se alcanzan y que son obligatorios: sin pisar la celda no se llega a la meta.
- Con el láser, una Burbuja se abre disparando en horizontal hasta 768 px, salvo que el terreno corte el disparo. La meta debe alcanzarse **sin** usar el láser.
- Informa de la vida de cada Burbuja y de desde dónde la alcanza el láser.

Resultado del 1-1: el láser se alcanza, es obligatorio y la meta se alcanza sin dispararlo. Margen mínimo: 12,5 puntos, sin cambios.

**Bot:** recoge el láser con la política genérica y mata a distancia las cinco Burbujas posteriores (11 disparos). Duración: **93,8 s caminando** y **62,5 s corriendo** (antes 89,7 y 57,0), sin golpes.
