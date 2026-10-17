# Propuesta: nivel 1-2 «Centro de notificaciones» y lenguaje de combinaciones

**Estado:** **APROBADA 2026-10-16** por el usuario con todas las recomendaciones de §11 (detalle en «Decisiones aprobadas», abajo). En implementación: pasos 1 a 9 del plan (§10) hechos el 2026-10-16; el resto, pendiente. Sustituye lo que contradiga de `mundo-1-notificaciones.md` §6.4 (las marcas están allí). Los valores son orientativos y se ajustan jugando y con el validador. Los textos de Eco y de Calc son **propuestas** hasta que el usuario los decida.

**Decisiones del usuario (2026-10-16) que respeta:** torre vertical de 4 pisos (Mensajes, Correo, Recordatorios, Actualizaciones); dificultad 2 de 5 «subida un poco» (más combinación y gestión de energía, no más castigo); unos 5 min; pulso y láser se combinan para avanzar; el **Debug se obtiene en el piso 2** resolviendo un acertijo de pulso + láser y es obligatorio para seguir en ese piso; **Calc al final del 1-2**, tras el Debug; recordatorios con botón **«Posponer»**; elementos nuevos de §6.2 (punto rojo, banner, recordatorio, pop-up translúcido).

**Decisiones aprobadas (2026-10-16), con sus respuestas:**

1. **Encuentro con Calc: opción A** (§8): Calc está apagada en la azotea, junto a la terminal, con el arte `powered_off` del hub; su Q usa `calc_off`; **el pulso la enciende** (líneas importantes de Calc, `meet_ally("calc")`) y se va con Isak por el vórtice. Los textos de Calc los decide el usuario.
2. **Recuerdo coleccionable** (secreto A): pestaña **«Recuerdos»** en el álbum de Notas (carpeta del Mundo 1), guardada en `memories`, **sin efecto en el juego** (V16). **Contenido: correos y mensajes de texto recibidos de familiares y amigos** (el Mundo 1 es el de las notificaciones). Qué dice cada uno es historia y queda **por decidir** con el usuario.
3. **El punto rojo despierto es inmune al láser** (chispa gris): hay que aturdirlo con el pulso antes de rematarlo (patrón 1).
4. **Los temporizadores van en tiempo del mundo** (recordatorios, ventana del cable, espera del 99 %): el Debug los ralentiza a la mitad.
5. **Recoger el chip del Debug llena la energía** (`refill_energy`, solo ese chip y la primera vez).

Se confirman además: acertijo **«Correo certificado»** del piso 2 combinando pulso y láser (§4); dificultad **2 de 5 «un poco más»** (§9); **sin vida extra en el 1-2** (§5); y las recomendaciones de las preguntas 6-10 de §11 (power bank vacío en el secreto C, ancho de 28 tiles, puntos de sincronización al entrar a los pisos 2 y 4, espera de 20 s con tres oleadas, sin línea automática para el secreto D del 1-1).

**Física de referencia** (`isak_physics.json`, `isak_abilities.json`, `debug_mode.json`): 220 px/s caminando (3,4 tiles/s), 360 corriendo; salto efectivo 177 px (2,8 tiles; con el 85 % del validador, subidas de **2 tiles**); salto horizontal corriendo unos 3,2 tiles. Pulso: radio 96 px desde el celular, sin coste, solo en el suelo, pose 0,33 s sin moverse. Láser: 10 de energía (máx. 100), daño 1, enfriamiento 0,4 s, 768 px (12 tiles), **solo horizontal** a la altura del celular (56 px sobre los pies), solo en el suelo, pose 0,30 s sin moverse. Debug: activar = mantener 1,0 s, gasta 20/s en tiempo real (5 s con la barra llena), exige energía > 0, el mundo va a ×0,5 y las plataformas `h` solo son visibles **y sólidas** con el Debug activo.

---

## 0. Lenguaje de combinaciones (reutilizable en todos los niveles)

Vocabulario común de puzles para el diseño de niveles. Cada patrón tiene un **nombre** (para hablar de él en los docs y en el JSON del nivel, campo `sections[].patterns`), una intención, reglas y variantes por dificultad. El Debug entra como «tercera herramienta» en §0.7.

### 0.1 Reglas físicas que se respetan y se explotan

| Regla | Consecuencia de diseño |
|---|---|
| Pulso y láser solo en el suelo y bloquean el movimiento ~0,3 s | Cada uso es un **compromiso**: parar cerca de una amenaza cuesta. Las secuencias se calculan con esas poses. Nunca se pide disparar o pulsar en el aire. |
| Pulso corto (96 px) y gratis | Lo «cercano», lo que se hace de pie junto al objeto. Es la herramienta segura. |
| Láser largo (12 tiles), horizontal, 10 de energía | Lo «lejano»: objetivos al otro lado de un foso o fuera del alcance a pie. **El objetivo debe estar a la altura del celular** desde una posición de pie (56 px sobre el suelo de esa posición): así la geometría decide desde dónde se dispara. |
| Láser con enfriamiento 0,4 s | Dos disparos seguidos cuestan unos 0,85 s. |
| Debug: carga de 1 s, 20/s, tiempo ×0,5 | Es caro y se enciende antes de necesitarlo. Ralentiza **todo lo del mundo** (enemigos, banners, temporizadores), no a Isak. |
| Energía compartida (láser + Debug) | Cada disparo es Debug que no tendrás. La gestión de energía es parte del puzle. |

**Fórmula de ventana** (para patrones con tiempo): ventana ≥ k × (recorrido a pie a 220 px/s + poses de las acciones + enfriamientos). k = 3 en dificultad 1-2, 2 en 3, 1,5 en 4-5.

**Regla anti-atasco (obligatoria en todos los niveles):** todo uso **obligatorio** de energía tiene un **cargador reutilizable** alcanzable a pie desde ese punto sin gastar energía, o una fuente fija de drops. Ningún estado temporal de un puzle bloquea el avance: lo temporal vuelve solo a su estado inicial y lo permanente (puentes, anuncios rotos, pop-ups cerrados) no se puede deshacer. Caer dentro de un puzle lleva a su suelo, con un escalón de vuelta al inicio y sin daño.

### 0.2 Patrón 1: Aturdir y rematar

- **Intención:** el pulso abre una ventana y el láser la aprovecha. Enseña que las herramientas se encadenan.
- **Reglas:** el enemigo despierto **no recibe daño del láser** (chispa gris, propuesta para el punto rojo: pregunta 2); aturdido (3 s) sí. Matar cuesta energía (vida 2 = 20) y suelta drops (+25): saldo positivo si no fallas.
- **Variantes:** (1) uno solo y lento; (2) dos a la vez: aturdir a uno y rematar mientras el otro se acerca; (3) aturdido como escalón y luego rematado desde arriba; (4, dificultad 3+) el pulso lo empuja y hay que rematarlo lejos, antes de que vuelva.

### 0.3 Patrón 2: Desbloquear a distancia y activar de cerca

- **Intención:** el láser «enciende» algo lejano que da corriente a algo cercano; el pulso lo activa dentro de una ventana.
- **Reglas:** el **lector láser** alimenta por un cable visible a un **receptor enlazado**; mientras el cable brilla (ventana), el pulso lo activa; si vence, el cable se vacía (aviso: parpadea los últimos 1,5 s) y se repite sin penalización salvo los 10 de energía. Lo activado (puente) queda.
- **Variantes:** ventana de 6 s (dificultad 2), 4 s (3), 2,5 s (4); el disparo y el receptor a distinta altura (hay que subir); dos lectores en serie; un banner que barre el recorrido (combina con P5).

### 0.4 Patrón 3: Posponer

- **Intención:** gestionar un temporizador ajeno: el láser lo alarga desde lejos mientras el pulso hace otra cosa cerca.
- **Reglas:** un grupo de **recordatorios** (plataformas) arranca su cuenta al pisar el primero; el **botón Posponer** (objetivo del láser) suma tiempo solo si el grupo está contando (si no, chispa gris: «nada que posponer»); tope de tiempo acumulado. Cuando vence, el grupo tiembla (aviso) y cae; vuelve poco después.
- **Variantes:** +4 s con tope 8 s (dificultad 2); +3 s con tope 5 s (3); dos botones para dos grupos; el botón tapado por un pop-up translúcido (combina con P4 o con el Debug).

### 0.5 Patrón 4: Quitar la protección y cerrar

- **Intención:** el objetivo del pulso está protegido; el láser quita la protección primero.
- **Reglas:** un **anuncio** (1 impacto de láser) tapa el botón de cerrar de un pop-up; el pulso rebota en él (chispa gris). Roto el anuncio, el pulso cierra el pop-up. Ambos estados son permanentes.
- **Variantes:** el anuncio a la altura de un puente o una repisa (hay que colocarse); dos anuncios; un anuncio que «se recarga» a los 5 s (dificultad 3+: obliga a cerrar rápido).

### 0.6 Patrón 5: Carrera contra amenaza

- **Intención:** una secuencia ya aprendida, ahora con presión: banners que barren o perseguidores que se acercan mientras haces las poses.
- **Reglas:** la amenaza es **periódica o lenta y siempre anunciada** (6-12 cuadros de aviso); nunca se combina con un pozo mortal en dificultad 1-2; hay un hueco seguro (nicho) cerca de cada pose.
- **Variantes:** banner con intervalo de 3 s (dificultad 2) o 2 s (3+); un punto rojo que persigue durante un P2; dos amenazas desfasadas.

### 0.7 Patrones con el Debug (**futuras, no implementar**)

Ideas para añadir el Debug a las combinaciones a partir del 1-3 y los mundos siguientes. Se dejan con nombre para reservar el concepto:

1. **Revelar y activar** (*futura*): un lector láser o un receptor solo visible con el Debug; se activa con el láser o el pulso tras apagar el Debug (energía: Debug + disparo).
2. **Ver el núcleo** (*futura*): un enemigo grande solo recibe daño en un punto débil carmín visible con el Debug (anticipa el jefe Alerta Mayor, §6.6).
3. **Ralentizar la ventana** (*futura*): un P2 o P3 con una ventana imposible a velocidad normal que cabe con el mundo a ×0,5 (el Debug compite con el láser por la energía).
4. **Ver a través** (*futura*): un pop-up translúcido oculta el objetivo del láser; con el Debug se ve y se apunta (en el 1-2 solo se usa de forma opcional, §3.3).

---

## 1. Concepto, objetivo y tono

- **Idea:** el centro de notificaciones del celular visto como una **torre de pestañas**. Isak sube de la base (vestíbulo) a la azotea; cada piso es una pestaña con su tipo de interrupción.
- **Objetivo de diseño:** introducir el **Debug** (obligatorio en el piso 2), los **perseguidores** (punto rojo), los **banners**, los **recordatorios** con «Posponer» y los **pop-ups translúcidos**; consolidar el láser del 1-1 combinándolo con el pulso (patrones 1-5).
- **Tono:** humor de notificaciones (textos absurdos en pop-ups, banners y barras, como §6.1: «Tienes 99+ mensajes que no son importantes», «Tu buzón está lleno. Compra más espacio», «Saltar anuncio en 5…», «Instalando 99 %»). Son textos de interfaz del mundo, no de Eco. **Eco comenta lo justo:** solo la historia de la obtención del Debug y lo que el jugador pregunta con Q.

## 2. Estructura vertical

### 2.1 Dimensiones

| Banda (filas, de arriba abajo) | Alto | Contenido |
|---|---|---|
| **Azotea** (0-7) | 8 | Encuentro con Calc y terminal de salida. |
| **Piso 4: Actualizaciones** (8-19) | 12 | Sala de espera del 99 %. Punto de sincronización 2 al entrar. |
| **Piso 3: Recordatorios** (20-31) | 12 | Recordatorios y Posponer. Cargador 2. |
| **Piso 2: Correo** (32-43) | 12 | Banners, acertijo del Debug, plataforma oculta, carpeta de Spam. Punto de sincronización 1 al entrar. Cargador 1. |
| **Piso 1: Mensajes** (44-55) | 12 | Puntos rojos y primer pop-up translúcido. |
| **Vestíbulo** (56-61) | 6 | Vórtice de llegada (P en la columna 4, suelo de la fila 60). |

- **Mapa:** **28 × 62 tiles** (1792 × 3968 px). La cámara ve unos 20 × 11 tiles: un piso entero de alto y algo de juego horizontal, lo justo para que el láser (12 tiles) tenga recorrido. Paredes exteriores en las columnas 0 y 27.
- **Forjados:** la última fila de cada banda es el suelo del piso. Se sube al siguiente por un **hueco** con plataformas de una vía (`-`) que **se atraviesan hacia arriba y no dejan caer al piso de abajo**: una caída nunca baja más de un piso ni más de 4 tiles (regla de diseño del nivel; no hay pozos sin fondo).
- **Huecos alternos:** el hueco del piso 1 está a la derecha, el del 2 a la izquierda, el del 3 a la derecha y el del 4 a la izquierda (recorrido en zigzag).

### 2.2 Cámara con scroll vertical

Hoy la `Camera2D` de Isak sigue en los dos ejes con suavizado (`position_smoothing_speed` 8) y límites = tamaño del grid (`build_level.py` → `camera_limits`). Funciona en una torre, pero **cada salto mueve la cámara**, que en un nivel vertical marea. Propuesta: `camera.vertical: "tower"` en el JSON del nivel con márgenes de arrastre vertical (`drag_vertical_enabled`, zona muerta del 25 % arriba y 15 % abajo), anticipación hacia arriba al subir por un hueco y ajuste al aterrizar en un suelo nuevo (lo que A13 proponía para el eje horizontal). El fondo de parallax (`world1_background.json`) está fijo en Y (`scroll_scale` 0): sirve, pero conviene una capa de «fachada de la torre» que se repita en vertical para notar que se sube (§10, paso 2).

**Implementado (2026-10-16, pasos 1 y 2):** `camera.vertical: "tower"` en el JSON del nivel; `tools/build_level.py` pone en Isak `camera_mode = &"tower"` y `camera_bands` (las bandas de los tramos con `y_from`/`y_to`, en px) y en el fondo `vertical = true`. La cámara (`TowerCamera`, `scripts/player/tower_camera.gd`; parámetros en `data/camera_tower.json`) es tipo plataforma-torre: se **ancla al último suelo** que pisó Isak (en el aire el ancla no cambia, así que **saltar no mueve la cámara**) y solo se desliza, suavizada y con tope de velocidad, al aterrizar a otra altura; mira 96 px por encima de Isak (anticipación al subir); dentro de un piso se **encaja en su banda** (si el piso cabe en pantalla queda centrado e inmóvil); Isak de pie nunca queda fuera de una zona de reposo y, en el aire, una **zona muerta** (borde duro) lo mantiene en pantalla al caer o al subir por un hueco. Límites desde el grid; el eje horizontal sigue a Isak como en el 1-1. El 1-1 (`camera.vertical: "simple"`) **no cambia** (Camera2D hija con suavizado 8; prueba de regresión). El fondo en modo vertical usa las mismas capas con desplazamiento y repetición en Y (bloque `tower` de `data/world1_background.json`); la repetición deja ver la costura de las imágenes (pensadas fijas en Y): la fachada de la torre sin costura llega con el arte (paso 11). Nivel de prueba: `data/levels/tower_test.json` (28 × 40, tres pisos en zigzag; escena `scenes/levels/tower_test.tscn`, no enlazada desde el hub). El vórtice de llegada (abajo) y la terminal de salida (arriba) funcionan con coordenadas de torre.

### 2.3 Puntos de sincronización (uno cada dos pisos)

- **`sync_1`**: entrada del piso 2 (rellano tras el hueco del piso 1, columna 24). Cubre los pisos 2 y 3: si mueres en el acertijo o después, no repites el piso 1.
- **`sync_2`**: entrada del piso 4. Cubre el piso 4 y la azotea.
- El vórtice de llegada cubre el piso 1. Las vidas siguen las reglas vigentes (3, no se reponen en los puntos de sincronización).

## 3. Los pisos

Columnas y filas aproximadas (se ajustan con el validador). «Fila del suelo» = fila de la celda donde está Isak de pie.

### 3.0 Vestíbulo (filas 56-61)

Vórtice en (4, 60), Eco entra con Isak. Recta corta con **1 punto de atención** y la subida al hueco del piso 1 (columnas 22-24). Sin enemigos. Unos 10 s.

### 3.1 Piso 1: Mensajes (filas 44-55). Dificultad 1,5 de 5

**Propósito:** el **punto rojo** y el **patrón 1** (aturdir y rematar); no quedarse quieto. El láser no es obligatorio en este piso (los puntos rojos se esquivan o se pasan aturdidos), así que no hace falta cargador.

1. **1a. Primer aviso** (columnas 20-26, suelo 55): `badge_1` dormido en una repisa baja; despierta al acercarse (6 tiles) y persigue despacio. Aturdirlo con el pulso y rematarlo con dos disparos. Punto de atención en la repisa de la que baja.
2. **1b. Subida perseguido** (columnas 6-20, filas 47-55): zigzag de tres repisas de una vía (subidas de 2 tiles) con `badge_2` siguiendo desde abajo. Parar a disparar en una repisa estrecha es el riesgo. **Secreto B («Borradores»)**: `badge_2` aturdido sirve de escalón hasta un nicho alto (columnas 2-4, fila 46) con 1 punto.
3. **1c. Rellano de salida** (columnas 18-26, filas 44-47): `badge_3` y `badge_4` juntos (variante 2 del patrón 1) y el primer **pop-up translúcido** `overlay_1` («Tienes 99+ mensajes que no son importantes») que tapa el hueco de subida: no hace daño ni bloquea, pero no deja ver dónde está el hueco. Se cierra con un pulso a su botón (abajo a la derecha, alcanzable de pie). Punto de atención junto al hueco.

**Punto rojo (`notification_badge`, parámetros orientativos):** vuela (sin gravedad) hacia Isak a 60-80 px/s (Isak camina a 220) cuando está a menos de 6 tiles; se para ante el terreno (no lo atraviesa); se queda **en su piso** (zona de correa = el rectángulo del piso) y vuelve despacio a su sitio si Isak sale. Contacto: −10 de Sync Rate (contacto pasivo, sin anticipación, como la Burbuja, A8). Vida 2. Pulso: aturdido 3 s (los últimos 0,75 s parpadea, aviso de 9 cuadros a 12 fps), quieto en el aire y sólido como plataforma de una vía (como la Burbuja aturdida). Despierto, el láser no le hace daño (pregunta 2). Drops: energía +25 y Sync +10 (como la Burbuja). Lienzo de 64 × 64.

**Pop-up translúcido (`overlay_popup`):** ventana de 4-8 × 3-5 tiles al 70 % de opacidad, dibujada **por encima** del mundo (no de la interfaz). No tiene colisión. Se cierra con el pulso a su botón (zona de golpe 24 × 24 px) o se ve a través con el Debug activo (la opacidad baja al 15 % mientras dura). Cerrado, queda cerrado.

### 3.2 Piso 2: Correo (filas 32-43). Dificultad 2 de 5

**Propósito:** el **banner** (patrón 5 suave), el **acertijo del Debug** (patrones 2 y 4) y el **Debug obligatorio** (plataforma oculta). `sync_1` en el rellano de entrada (columna 24, fila 43).

Dos alturas: abajo el pasillo de 2a (Isak de pie en la fila 42, techo en la 39: 3 tiles libres) y arriba la sala del acertijo (Isak de pie en la fila 37 en el suelo de la sala y en la 33 en las repisas altas; el forjado del piso 3 es la fila 31).

1. **2a. Bandeja de spam** (columnas 3-26, fila 42; se recorre de derecha a izquierda): `banner_1`: cada 3,0 s un banner blanco («¡OFERTA! Solo hoy») de 1 tile de alto barre el pasillo a ras de suelo a 640 px/s (unos 1,4 s en cruzarlo). Aviso: el borde de entrada parpadea en rojo alerta con una flecha 0,75 s antes (9 cuadros a 12 fps). Se salta por encima (el salto da 2,8 tiles y hay 3 libres) o se espera en uno de los dos nichos del techo. Contacto: −10. Indestructible (desde el 1-3 el dash lo atraviesa, §6.5). Al final, una escalera de repisas de una vía (columnas 1-3) sube a la sala.
2. **2b. Acertijo «Correo certificado»** (§4; columnas 4-20, filas 32-37): sin enemigos ni banners. `cargador_1` al entrar.
3. **2c. Falta una plataforma** (columnas 1-6, fila 33, a la izquierda de la repisa alta del acertijo): con el Debug recién obtenido, la repisa alta termina en el aire (columna 6) ante un hueco de 4 tiles (columnas 2-5; no se salta: más de 3,2). En el centro, una plataforma oculta `h` de 2 tiles (columnas 3-4) y, encima a la izquierda, la repisa de una vía del hueco al piso 3 (columnas 1-2, fila 32), que solo se alcanza desde la plataforma oculta. Pista visual: un contorno de píxeles cian rotos que parpadea un cuadro cada 2 s donde está la plataforma y una barandilla rota que «continúa» en el aire; la Q de Eco sale sobre el parpadeo (`hidden_platform`). Si el Debug se apaga a medio cruzar, Isak cae 4 tiles al suelo de la sala, junto a `cargador_1`, y vuelve a subir por las repisas.
4. **2d. Carpeta de Spam** (secreto A, §5): a la derecha de la caja fuerte, al otro lado de otra plataforma oculta.
5. Hueco al piso 3 en las columnas 1-2.

Al rejugar el 1-2 con el Debug ya obtenido, el acertijo es opcional: la repisa alta se alcanza desde el suelo de la sala y el hueco de 2c se cruza con el Debug.

### 3.3 Piso 3: Recordatorios (filas 20-31). Dificultad 2,5 de 5 (el pico del nivel)

**Propósito:** **recordatorio** y **patrón 3** (Posponer), y su combinación con el pulso.

1. **3a. Recordatorios sueltos** (columnas 6-20, suelo del piso): tres recordatorios de 2 tiles sobre un foso de 3 tiles de fondo (caer = volver por un escalón, sin daño). Cada uno arranca su cuenta de 2,5 s al pisarlo (4 segmentos sobre la plataforma); los últimos 0,5 s tiembla (aviso de 6 cuadros a 12 fps); cae y vuelve a su sitio a los 3 s. Basta con no pararse.
2. **3b. Posponer** (columnas 4-24, filas 26-28): un grupo de cuatro recordatorios (cuenta compartida de 3 s desde el primero) demasiado largo para cruzarlo en 3 s caminando (unos 4,5 s). En la pared del fondo, a la altura del celular desde el segundo recordatorio, el **botón Posponer** `snooze_1`. Pisar, parar, disparar: +4 s (tope 8 s). Sin el grupo contando, el disparo da chispa gris («nada que posponer»). Un pop-up translúcido opcional, `overlay_2` («Recordatorio: no olvides tus recordatorios»), tapa el botón: se cierra con un pulso desde la repisa de salida o se ve a través con el Debug (uso opcional del Debug).
3. **3c. Posponer y pulso** (columnas 14-26, filas 21-25): `cargador_2` al empezar. Grupo de tres recordatorios (3 s) que termina ante un receptor de pulso cuyo puente lleva al hueco del piso 4. Secuencia: pisar → disparar a `snooze_2` (+4 s) → caminar al receptor → pulso → esperar el puente → cruzar. Ventana total: 7 s frente a unos 3,3 s de recorrido y poses (k ≈ 2: es el pico del nivel). El puente queda.
4. **Secreto C** (columnas 22-26, fila 20): un grupo de recordatorios que solo llega al nicho con **dos** Posponer seguidos (tope 8 s): guarda el power bank del 1-2 (pregunta 6).

**Recordatorio (`reminder_platform`):** plataforma sólida de 1-3 tiles (no de una vía, para que caer de él sea claro), con `group`, `timer_s`, `warn_s` 0,5, `respawn_s` 3. Los tiempos van en **tiempo del mundo**: el Debug los ralentiza a la mitad (pregunta 1). **Botón Posponer (`snooze_button`):** objetivo del láser (grupo `laser_activatable`, ya preparado en `laser_projectile.gd`), con `targets` (grupos), `add_s` 4, `cap_s` 8; destello «Zzz» al acertar.

### 3.4 Piso 4: Actualizaciones (filas 8-19). Dificultad 2 de 5

**Propósito:** el respiro humorístico antes del final y un repaso de todo con presión suave (patrones 1 y 5). `sync_2` al entrar (columna 4, fila 19). El láser no es obligatorio.

1. **4a. Aviso de actualización** (columnas 2-12, filas 16-19): subida corta con `overlay_3` («Actualización disponible. ¿Instalar ahora? Sí / Sí») tapando una repisa y un `banner_2` de intervalo 3 s.
2. **4b. Sala de espera** (columnas 2-26, filas 8-15; dos alturas de repisas): la **barra de progreso** `update_bar` («Instalando… 97 %») cierra la subida a la azotea. Al entrar sube rápido a 99 % y se queda: **20 s de espera** (tiempo del mundo) con textos de interfaz que cambian («99 %», «99,9 %», «Calculando tiempo restante…», «Casi listo»). Mientras, caen enemigos de «paquetes» del techo en tres oleadas, cada una anunciada 0,75 s antes con una sombra y una flecha roja: t = 4 s, dos Burbujas (vida 2); t = 10 s, dos puntos rojos; t = 15 s, una Burbuja y un punto rojo. Se esquivan o se matan (los drops reponen energía). Al 100 % («Reiniciando…») la barra se abre y los enemigos que queden se apagan con un pop. Con el Debug la espera dura el doble en tiempo real: lo dice la Q, en broma.
3. Subida a la azotea por el hueco de la izquierda.

**Barra (`update_bar`):** puerta de 1 × 3 tiles con `wait_s` 20 y `waves` (`[{t, type, x, params}]`); se arma al cruzar su zona y no se reinicia si Isak muere después de abrirla.

### 3.5 Azotea (filas 0-7)

Recta tranquila: **Calc** (§8), 1 punto de atención y la **terminal de salida** (`exit_terminal`, con el pulso, como en el 1-1), que lleva al hub. Unos 20 s con el encuentro.

## 4. El acertijo del Debug (piso 2, «Correo certificado»)

### 4.1 Elementos

| Id | Tipo nuevo | Dónde (aprox.) | Qué hace |
|---|---|---|---|
| `cargador_1` | `charger` (existe) | (4, 37), al entrar en la sala | +50, reutilizable, `cooldown_s` 10 (más corto que el del 1-1 para que esperar no aburra). |
| `lector_1` | `laser_receiver` | (15, 37), en la cara izquierda del bloque de la caja fuerte, a la altura del celular desde el suelo de la sala | Al recibir un impacto se enciende y da corriente a `receptor_enlazado_1` durante 6 s. |
| `receptor_enlazado_1` | `relay_receiver` | (9, 33), extremo de la repisa alta (columnas 6-9) | Receptor de pulso que solo responde con corriente; extiende `puente_correo` (columnas 10-15, fila 33) hacia la derecha, hasta la caja fuerte. |
| `popup_buzon` | `popup_blocker` (existe) | (16-17, 32-33), entrada de la «caja fuerte» (columnas 16-20, sobre un bloque macizo de las filas 34-37) | «Tu buzón está lleno. Compra más espacio». |
| `anuncio_buzon` | `ad_cover` | Encima del botón de cerrar de `popup_buzon`, a la altura del celular desde el final del puente | «Saltar anuncio en 5…» (falso: no se salta). El pulso rebota; 1 impacto de láser lo rompe. |
| `debug_1_2` | `ability_pickup` (existe, `ability: "debug"`) | (19, 33), dentro | El chip del Debug. |

Geometría clave: entre la repisa alta (columnas 6-9) y la caja fuerte (columna 16) hay **6 tiles de aire** sobre el suelo de la sala (más que un salto; caer son 4 tiles, sin daño). Desde la repisa alta la línea del láser pasa 4 tiles por encima de `lector_1` y no lo toca: **el disparo solo sale desde el suelo de la sala**, y el receptor solo está en la repisa alta, a dos subidas de una vía (unos 1,5 s) del punto de disparo.

### 4.2 Pasos (orden obligatorio)

1. **Disparar a `lector_1`** desde el suelo de la sala (patrón 2). Se enciende y el cable de circuito que sube por la pared hasta la repisa alta se ilumina en cian y empieza a vaciarse (6 s).
2. **Subir** las dos repisas de una vía hasta `receptor_enlazado_1` (unos 1,5 s) y **lanzarle el pulso** con el cable encendido. El puente se extiende hasta la caja fuerte (permanente). Recorrido y poses: unos 2 s frente a 6 s (k = 3, dificultad 2).
3. **Cruzar el puente** hasta su extremo. Desde allí `anuncio_buzon` queda a la altura del celular: **disparar** (1 impacto) y el anuncio se rompe («Anuncio omitido»).
4. **Pulso al botón de cerrar** de `popup_buzon`, de pie al final del puente (patrón 4). El pop-up se cierra.
5. **Recoger `debug_1_2`** en la caja fuerte (§4.4).
6. **Volver por el puente y la repisa alta** hacia la izquierda, a la sección 2c («Falta una plataforma»): Debug → plataforma oculta visible → cruzar → seguir.

Orden en una línea: **acertijo → Debug obtenido → plataforma oculta visible con el Debug → continuar**. Sin el Debug no hay forma de cruzar el hueco de 2c (4 tiles), así que el Debug es obligatorio para seguir en el piso 2, como pide §6.4.

### 4.3 Pistas, fallos y reinicio

- **Pistas visuales (sin texto de Eco):** `lector_1` tiene una diana; el cable une `lector_1` con `receptor_enlazado_1` (trazas de circuito `resplandor` apagadas, cian al encenderse); `receptor_enlazado_1` sin corriente muestra un enchufe tachado y, si se le lanza el pulso, chispa gris; el anuncio muestra un «✕» gris falso. La **Q de Eco** sale sobre cada tipo nuevo (`laser_receiver`, `relay_receiver`, `ad_cover`; §7) y nunca es obligatoria.
- **Si vence la ventana:** el cable parpadea los últimos 1,5 s y se apaga; `lector_1` vuelve a estar listo. Se repite (10 de energía).
- **Si fallas el disparo o te caes del puente:** al suelo de la sala, sin daño; las repisas de una vía devuelven arriba.
- **Si te quedas sin energía:** `cargador_1` está a 3 tiles del punto de disparo y se reutiliza cada 10 s. Lo mínimo del acertijo son 2 disparos (20 de energía).
- **Reinicio:** no hace falta un botón: lo temporal (la ventana) vuelve solo; lo permanente (puente, anuncio roto, pop-up cerrado) no se puede deshacer y no bloquea nada. Si Isak muere antes (solo puede ser en 2a), reaparece en `sync_1`, antes del acertijo. Como en el 1-1, al reaparecer el mapa no se reinicia (a comprobar en la implementación).
- **Sin castigo de muerte:** en la sala no hay enemigos, banners, pinchos ni caídas de más de 4 tiles.

### 4.4 Obtención del Debug (momento de historia)

- **Objeto:** `ability_pickup` con `ability: "debug"` (ya admitido por el esquema). Chip con un destello cian; al tocarlo, Isak lo «instala» (anillo cian que se expande y un parpadeo del tinte del Debug a pantalla completa, 0,5 s).
- **Efectos:** `debug` pasa a `abilities_obtained` / `abilities_unlocked` (se guarda como el láser y, como él, va a la Papelera en un game over); **la energía se llena** (parámetro nuevo `refill_energy: true`, pregunta 3), para que el primer cruce no dependa de lo gastado.
- **Eco (línea importante, pausa; texto propuesto):** «Una herramienta de diagnóstico. Te deja ver los errores del sistema… y gasta la misma energía que el láser.» Sigue el **aviso de control** existente de `data/ability_notices.json`: «Debug: mantén K / Y (mando)» (línea importante, una vez por partida guardada).
- **Al volver al 1-2** con el Debug ya obtenido: el chip no aparece y su línea tampoco (`unless_ability: "debug"`, regla de «objetos de historia de un solo uso»).

## 5. Secretos

| Id | Dónde y cómo | Recompensa |
|---|---|---|
| **A. Carpeta de Spam** (piso 2, columnas 25-26, fila 33) | Al salir de la caja fuerte por la derecha (columna 20), una repisa al otro lado de un hueco de 4 tiles (columnas 21-24) con una plataforma `h` de 2 tiles en el centro (unos 2 s de Debug). Debajo, un pozo con repisas de una vía de vuelta a la caja fuerte (sin atasco). Se ve la carpeta desde la caja fuerte. Exige el Debug (`needs_debug`). | **2 puntos** de atención y el **primer recuerdo coleccionable** (ver abajo). |
| **B. Borradores** (piso 1, columnas 2-4, fila 46) | `badge_2` aturdido como escalón (patrón 1, variante 3). | 1 punto. |
| **C. Recordatorio olvidado** (piso 3, columnas 22-26, fila 20) | Dos Posponer seguidos (tope 8 s) sobre un grupo largo. | 1 power bank (vacío; pregunta 6). |

- **Recuerdo coleccionable:** V16 propone que los recuerdos se vean en Notas y no desbloqueen nada (el candado de La Nube usa los fragmentos de los jefes). Se propone guardarlo en `found_secrets` («1-2» / «A») y en una lista nueva `memories` del guardado, con una pestaña **Recuerdos** en la carpeta del Mundo 1 del álbum. **Qué recuerdo es** (texto o imagen) es historia: lo decide el usuario (pregunta 5).
- **Vida extra: no hay en el 1-2.** Regla vigente: una cada N mapas con **N = 3** (`propuesta-asistentes-y-vidas.md` §5.1: «una por mundo en cada vuelta: 1-1, 2-1, 3-1…»). La del 1-1 ya cuenta; la siguiente iría en el **2-1** (no en el 1-3). Es ajustable jugando: con N = 2 tocaría el 1-3.
- **Secreto D del 1-1:** con el Debug ya se puede abrir la pared con glitch del 1-1 (columna 298) y coger la **vida extra del 1-1**. El jugador vuelve desde el hub (carpeta del Mundo 1). No se añade una línea automática de Eco (regla: Eco no lanza mensajes); lo recuerdan la Q de `glitch_wall` y su ficha del álbum («Eso es un error de visualización…»). Ver pregunta 10.

## 6. Economía: puntos, energía, cargadores y drops

### 6.1 Puntos de atención (≈ 9 por mapa, criterio del 1-1)

| Dónde | Ruta | Secretos |
|---|---|---|
| Vestíbulo | 1 | |
| Piso 1 (repisa de 1a, junto al hueco de 1c) | 2 | B: 1 |
| Piso 2 (rellano de `sync_1`) | 1 | A: 2 |
| Piso 3 (al final de 3b) | 1 | |
| Azotea | 1 | |
| **Total** | **6** | **3** |

Total 9, como el 1-1: al final del 1-2 hay unos 18 puntos con todo; Pulso amplio (25) sigue pagándose al terminar el 1-3 (comprobaciones de `test_level_schema.py` sin cambios). Dispersos, nunca en fila. Power banks: 1 (secreto C).

### 6.2 Energía (empieza al 100 %)

| Tramo | Gasto obligatorio | Gasto típico | Fuentes |
|---|---|---|---|
| Piso 1 | 0 (el láser no es obligatorio) | 4 puntos rojos × 2 disparos = 80 | Drops 4 × 25 = 100 (saldo +20) |
| Piso 2, acertijo | 20 (lector + anuncio) | 30-40 con fallos | `cargador_1` (+50, cada 10 s) |
| Piso 2, 2c (Debug) | ~40 (2 s activo; la carga de 1 s no gasta) | 40-60 | La recogida del Debug llena la barra; `cargador_1` debajo del hueco |
| Piso 2, secreto A | ~40 más (opcional) | | Si se agota, se cae a la ruta |
| Piso 3 | 20 (`snooze_1`, `snooze_2`) | 30-50 (+20 del secreto C) | `cargador_2` en 3c; drops si hay enemigos |
| Piso 4 | 0 | 0-60 | Drops de las oleadas (hasta 6 × 25) |

**Dos cargadores, como el 1-1**, cada uno donde hay un gasto obligatorio (acertijo y Debug del piso 2; Posponer del piso 3). Se cumple la regla anti-atasco (§0.1): ningún gasto obligatorio queda lejos de un cargador reutilizable.

## 7. Ayudas Q y álbum del 1-2

Tipos nuevos en `data/help.json` (`world: 1`), con su `help_id` en el catálogo o el JSON del enemigo y su ficha del álbum (`tools/gen_album_cards.py`). Textos propuestos (Eco, breves, sin teclas):

| Tipo | Álbum | Texto de Eco (propuesta) |
|---|---|---|
| `notification_badge` | Enemigo | «Un aviso sin leer. Te sigue a todas partes. Un pulso lo deja en pausa y, en pausa, el láser lo cierra. Despierto, ni lo nota.» |
| `spam_banner` | Enemigo | «Publicidad que pasa cada pocos segundos. Mira el aviso del borde y salta cuando llegue.» |
| `overlay_popup` | Objeto | «Una ventana translúcida. No hace daño, solo tapa. Un pulso a su botón la cierra; con el Debug se ve a través.» |
| `laser_receiver` | Objeto | «Un lector a distancia. Responde al láser, no al pulso. Mira a dónde va su cable.» |
| `relay_receiver` | Objeto | «Este receptor necesita corriente. Cuando su cable brille, tienes unos segundos para el pulso.» |
| `ad_cover` | Objeto | «Un anuncio encima del botón de cerrar. El pulso rebota; el láser lo quita.» |
| `hidden_platform` | Objeto | «Un error del sistema: una plataforma que no debería estar. Con el Debug se ve y se pisa. Sin él, no.» |
| `reminder_platform` | Objeto | «Un recordatorio. Al pisarlo empieza la cuenta; cuando vence, cae. Vuelve enseguida, como todos.» |
| `snooze_button` | Objeto | «Botón Posponer. Un disparo mientras corre la cuenta y los recordatorios esperan un poco más.» |
| `update_bar` | Objeto | «Actualización en curso. Solo hay que esperar. Se queda en 99 %. Siempre. Con el Debug, el doble.» |
| `memory_pickup` | Objeto | Por decidir con el recuerdo (pregunta 5). |

La Burbuja, el cargador, el punto de sincronización, el pop-up, el receptor, el puente, la terminal y el chip ya tienen ayuda (1-1). La Q del chip del Debug no es necesaria: es historia.

**Arte por script** (circuito limpio, `mundo1.gpl` + `effects_pulse.gpl`; rojo alerta solo para lo que hace daño y sus avisos; cian = Debug e interactivo): un generador nuevo `tools/gen_world1_tower.py` (o ampliar `gen_world1_objects.py`) con su validador de paleta. **Enemigos que podrían ir por AutoSprite:** el punto rojo y el banner. **Recomendación: por script los dos** (formas simples: círculo rojo alerta con «1» blanco, ojos y halo; rectángulo `banner_blanco` con texto de píxeles y borde `alerta`), sin gastar créditos (quedan ~470) y con el mismo estilo de circuito que la Burbuja. AutoSprite solo si el usuario lo pide.

## 8. Eco y Calc: historia

**Líneas de historia imprescindibles:** (1) la obtención del Debug (§4.4); (2) el encuentro con Calc en la azotea. Nada más es automático: el resto es ayuda con Q.

**Encuentro con Calc (la historia está por decidir; tres opciones breves, sin añadir historia nueva):**

| Opción | Qué pasa | A favor | En contra |
|---|---|---|---|
| **A. Calc colgada en la azotea** (recomendada) | En la azotea, junto a la terminal, Calc está **apagada** (el mismo arte `powered_off` del hub). La Q de Eco usa el texto ya previsto de `calc_off` («Una aplicación apagada. Quizá la encontremos por ahí.»). Un pulso la enciende: líneas importantes de Calc (seca y literal, §12.3), le dice a Isak que estará en el hub y se va con él por el vórtice. `meet_ally("calc")`. | Reutiliza arte, la Q de `calc_off` y el pulso; cierra el nivel con un momento claro; coherente con «tras obtener el Debug». | No usa el Debug recién obtenido. |
| **B. Calc tras el error** | Igual que A, pero Calc está en un nicho tras una pared con glitch que se abre con el Debug (reutiliza `GlitchWall`). | Repite el Debug al final; sin arte nuevo. | Un segundo gasto de Debug al final; si te quedas sin energía, hace falta otro cargador o drops cerca. |
| **C. Calc llega al hub** | Al terminar el 1-2, en el hub, Calc se enciende sola y se presenta (como Notas). | La más barata: reutiliza `NotasIntro`. | No es «al final del 1-2» en el nivel; menos encuentro. |

Recomendación: **A**. Los textos de Calc los decide el usuario (solo se proponen como borrador cuando se elija la opción).

## 9. Dificultad y tiempos

| Tramo | Dificultad («X de 5») | Duración caminando (aprox.) | Qué sube respecto al 1-1 |
|---|---|---|---|
| Vestíbulo | 1 | 10 s | Nada |
| Piso 1: Mensajes | 1,5 | 50 s | Un enemigo que persigue (te obliga a moverte) |
| Piso 2: Correo | 2 | 90 s (acertijo ~45 s) | Primer puzle de dos herramientas; Debug con energía |
| Piso 3: Recordatorios | 2,5 | 60 s | Temporizadores; combinación con tiempo (Posponer + pulso) |
| Piso 4: Actualizaciones | 2 | 50 s (20 s de espera) | Varias amenazas a la vez, pero evitables |
| Azotea | 1 | 20 s (con Calc) | Nada |
| **Total** | **2** | **unos 280 s (≈ 5 min)**; `target_duration_s` 300 | |

**Cómo se sube «un poco» sin frustrar:** el daño no cambia (−10 por golpe: 10 golpes para morir); **no hay pozos sin fondo** ni caídas de más de 4 tiles; ningún puzle tiene enemigos dentro; las ventanas usan k = 3 salvo el pico del 3c (k ≈ 2); lo que sube es la **exigencia de combinación** (dos herramientas en secuencia, poses que cuestan) y la **gestión de energía** (el Debug compite con el láser). **Vidas:** 3, reglas vigentes. **Puntos de sincronización:** 2 (§2.3).

## 10. Requisitos técnicos y plan de implementación

**Alcance real del soporte vertical.** El grid ya admite cualquier alto (el esquema solo exige un mínimo de 12 filas), `build_level.py` genera los límites de cámara desde el grid y el validador trabaja sobre celdas sin suponer altura. **No hace falta cambiar la arquitectura.** Lo que sí falta: (a) la cámara, que hoy sigue cada salto en vertical; (b) los tramos (`sections`) solo tienen `x_from`/`x_to`; (c) el fondo es fijo en Y; (d) el **bot** solo camina a la derecha (su política es «avanzar y saltar»): en una torre hay que darle un recorrido; (e) el validador no sabe de objetivos del láser, de un Debug obtenible ni de tiempos.

| Paso | Qué | Tamaño | Depende de |
|---|---|---|---|
| 1 | **Hecho (2026-10-16).** Esquema y constructor: `sections` con `y_from`/`y_to` (pisos), `camera.vertical: "tower"`, campos `patterns`; probar `build_level.py` con 28 × 62. | S | |
| 2 | **Hecho (2026-10-16).** Cámara de torre (zona muerta vertical, anticipación al subir, ajuste al aterrizar) y capa de fondo de la torre con repetición vertical (por ahora las capas existentes, sin arte nuevo); revisar que Eco compañero, la Q («en pantalla») y la red de caída funcionan en vertical (red de caída y vórtices probados en la torre de prueba; Eco y la Q usan la pantalla de la cámara y no suponen altura). | M | 1 |
| 3 | **Hecho (2026-10-16).** Objetos del láser: `laser_receiver`, `relay_receiver` (ventana y cable), `ad_cover` sobre `popup_blocker` (grupo `laser_activatable`, ya preparado). | M | |
| 4 | **Hecho (2026-10-16).** Enemigo punto rojo (`notification_badge`: persecución con correa por piso, aturdido como plataforma, inmune despierto, vida y drops con `EnemyHealth`). | M | |
| 5 | **Hecho (2026-10-16).** Banner (`spam_banner`: barrido periódico con aviso de 9 cuadros). | S | |
| 6 | **Hecho (2026-10-16).** Recordatorio y botón Posponer (grupos, tiempo del mundo, aviso, caída y vuelta). | M | 3 |
| 7 | **Hecho (2026-10-16).** Pop-up translúcido (`overlay_popup`: capa por encima del mundo, pulso al botón, transparencia con el Debug). | M | |
| 8 | **Hecho (2026-10-16).** Barra de actualización y oleadas (`update_bar`, generador de enemigos con aviso). | M | 4 |
| 9 | **Hecho (2026-10-16)** salvo la ayuda `hidden_platform` (va con el arte y las ayudas, pasos 11-12). Obtención del Debug: `ability_pickup` de `debug` con `refill_energy`, línea de historia y aviso de control, `unless_ability`; ayuda `hidden_platform`. | S | |
| 10 | Validador: Debug obtenible (las `h` cuentan en la ruta solo tras el chip y con presupuesto de energía: casillas `h` del recorrido × tiempo ≤ energía disponible con margen); `laser_required` por nivel (hoy exige meta sin láser); objetivos del láser como puertas (horizontal a la altura del celular); grupos de recordatorios como puertas «con Posponer» con una estimación de tiempo (avisa si la ventana < k × recorrido); secretos A y C. Exportar el camino encontrado (para el bot). | L | 3, 6, 9 |
| 11 | Arte por script de todo lo nuevo + validador de paleta; fichas del álbum. | M | 3-8 |
| 12 | Ayudas Q (`data/help.json`, 10 tipos) y textos. | S | 11 |
| 13 | Datos del nivel `data/levels/1-2.json` + escena generada + `hub.json` (1-2 `playable: true`) + pruebas GUT del nivel (acertijo, Posponer, energía, Debug obligatorio, secretos). | L | 1-12 |
| 14 | Recuerdo coleccionable (guardado `memories`, pestaña del álbum) y encuentro con Calc (paso 15 de `propuesta-asistentes-y-vidas.md`). | M | 13, preguntas 4 y 5 |
| 15 | Bot vertical: sigue el camino exportado por el validador como lista de puntos y acciones (pulso, láser, Debug, esperar ventana), en vez de «caminar a la derecha»; recorre el 1-2 y llega al hub. Mantener el bot del 1-1. | L | 10, 13 |

Orden: 1 → 2; 3, 4, 5, 7 y 9 en paralelo; 6 y 8 después; 10 cuando existan 3, 6 y 9; 11-12; 13; 14 y 15.

**Hecho en los pasos 1 y 2 (2026-10-16):** `tools/validate_level_schema.py`: grid de cualquier alto (mínimo 12 filas), tramos con `x_from`/`x_to` e `y_from`/`y_to` opcionales (por defecto todo el ancho / todo el alto; `y_from` e `y_to` van juntos) que no se solapan (los horizontales, como los del 1-1, siguen yendo de izquierda a derecha), `patterns` (lista de textos), `camera` (`vertical`: `simple` | `tower`; `limits`: `grid`) e ids `<nombre>_test` para niveles de prueba. `tools/validate_level.py` acepta torres (tramos por fila en los mensajes; en un fallo dice de qué fila no sube Isak) sin reglas nuevas: las del láser, el Debug y los temporizadores son el paso 10. `tools/render_level_map.py` dibuja mapas altos (bandas de los pisos a la derecha y regla de filas). `tools/build_level.py` genera la escena con el alto del grid y, en modo torre, la cámara y el fondo verticales. El bot del 1-1 no cambia y se niega a recorrer un nivel con cámara de torre (paso 15). Pruebas: `tests/test_level_schema.py`, `test_validate_level.py` y `test_build_level.py` (torre sintética de 28 × 62, `tests/support/tower_level.py`), `tests/test_tower_camera.gd` (límites, zona muerta, salto en el sitio, subida por el zigzag sin sacudidas, fondo en Y y regresión del 1-1) y `tests/test_tower_test_level.gd` (vórtice abajo, terminal arriba, red de caída). Capturas: `tools/render_tower_test.gd`.

**Hecho en los pasos 3 y 9 (2026-10-16):** tipos nuevos del catálogo (`data/world1_objects.json`, con `help_id` y secciones de ajuste): **`laser_receiver`** (`LaserReceiver`, `scripts/levels/laser_receiver.gd`: Area2D en la capa world y en `laser_activatable`; diana a la altura del celular desde el suelo de su celda; un impacto da corriente `window_s` = 6 s de tiempo del mundo —el Debug la alarga ×2, la pausa la para— al `relay_receiver` con id = `target`; otro impacto con corriente rellena la ventana; al vencer se apaga y vuelve a estar listo, sin castigo; hecho cuando su receptor se activa: cable fijo y sin Q), su **cable** (`LaserCable`: recorrido `cable` en celdas, de la salida del lector a la entrada del receptor, tramos rectos o en L; apagado, encendido con un trazo que corre hacia el receptor y **se vacía** hacia él según el tiempo que queda, parpadeo los últimos 1,5 s), **`relay_receiver`** (`RelayReceiver`: receptor de pulso que solo se activa con corriente; sin ella, chispa gris y nada; activado extiende el `bridge_inactive` de su `target` —`PulseBridge` enlaza ahora cualquier nodo del grupo `pulse_receiver` con `target_id`, `is_active()` y `activated`— y deja hecho al lector) y **`ad_cover`** (`AdCover`: su x, y es la celda del botón de cerrar de su `popup_blocker`; en el juego se centra sobre el botón; entero, el pulso rebota (chispa gris) y el pop-up no se cierra —`PopupBlocker.add_cover`/`is_button_covered`—; un impacto del láser lo rompe para siempre, con una animación corta). Disparar pegado al lector o al anuncio cuenta (`LaserProjectile.strike`/`muzzle_crosses`: el celular ya está dentro de la pared o del objetivo). **Chip del Debug:** `ability_pickup` con `ability: "debug"` y `refill_energy: true`; ajustes por habilidad en `ability_pickup.by_ability.debug`: arte propio (`debug_chip_idle`), ayuda Q propia `debug_chip`, **línea de historia** de Eco (importante, con `{apodo}`; texto propuesto, por decidir) que sale **antes** del aviso de control existente («Debug: mantén K / Y (mando)», leído del Input Map, una vez por partida guardada) e **instalación** (anillo `debug_chip_collect` y destello del tinte cian a pantalla completa 0,5 s en tiempo real, `InstallEffect`). Llena la energía solo la primera vez (con el Debug obtenido el chip no aparece ni repite nada; tras un rollback sin él, vuelve). Esquema (`tools/validate_level_schema.py`): enlaces lector → receptor enlazado → puente y anuncio → pop-up (ids existentes y del tipo correcto; el anuncio en la celda del botón), `cable` dentro del grid, `window_s` > 0 y `refill_energy` booleano. `tools/validate_level.py` modela por ahora el receptor enlazado como un receptor del pulso (sin corriente ni tiempo) y no sabe del lector ni del anuncio: es el paso 10. Arte por script: `tools/gen_world1_puzzle.py` (validador `tools/validate_world1_puzzle.py`, en `tools/run_tests.sh`; `assets/sprites/puzzle_objects_frames.tres`); ayudas `laser_receiver`, `relay_receiver`, `ad_cover` y `debug_chip` en `data/help.json` y sus fichas del álbum (Mundo 1, Objetos; `tools/gen_album_cards.py`). Sala de prueba `data/levels/correo_test.json` (24 × 12; escena `scenes/levels/correo_test.tscn`, no enlazada desde el hub ni recorrida por el bot) con el acertijo de §4 (disparo desde el suelo, repisa alta a 4 tiles, puente de 6 tiles a la caja fuerte, anuncio sobre el botón del pop-up, chip en un túnel de 2 tiles, cargador junto al punto de disparo y terminal de salida). Pruebas: `tests/test_correo_objects.gd`, `tests/test_debug_chip.gd`, `tests/test_correo_test_level.gd` (de principio a fin: fallar la ventana sin daño, resolverla, Debug desbloqueado y energía llena, el chip no repite), `tests/test_help_inert.gd` (los cuatro tipos) y las de Python del esquema y el constructor. Capturas: `tools/render_correo_test.gd`.

**Hecho en los pasos 4 y 5 (2026-10-16):** **punto rojo** (`notification_badge`; `NotificationBadge`, `scripts/enemies/notification_badge.gd`, escena `scenes/enemies/notification_badge.tscn`; valores en `data/enemies/notification_badge.json`): dormido en su sitio hasta que el centro de Isak está a menos de 6 tiles (`wake_radius_px` 384) y dentro de su **correa** (rectángulo `leash_width_px` × `leash_height_px` centrado en su aparición, 24 × 11 tiles por defecto: el piso; nunca sale de él); vuela sin gravedad hacia el centro de Isak a 70 px/s (Isak camina a 220: se le deja atrás) y el terreno lo para; si Isak se aleja más de 10 tiles o sale de la correa, vuelve a su sitio y se duerme. A menos de `lunge_radius_px` (112) se para y **se infla 9 cuadros a 12 fps (0,75 s, aviso)** y después **se lanza** 0,3 s a 420 px/s hacia donde estaba Isak: **solo lanzado daña** (−10 de Sync Rate con la invulnerabilidad de Isak; desvío respecto a «contacto pasivo» de §3.1, para cumplir la regla de 6-12 cuadros de aviso antes de dañar); tras el lanzamiento, 0,6 s quieto. **Pulso:** aturdido 3 s, quieto en el aire, inofensivo y plataforma de una vía; los últimos 9 cuadros parpadea (aviso) y vuelve a perseguir. **Láser:** despierto es **inmune** (el disparo choca con él y se consume —su energía ya se gastó al disparar—, chispa gris, sin daño); aturdido, vida 2 (dos disparos) y al morir suelta energía +25 y Sync +10 (como la Burbuja) y no reaparece; al reaparecer Isak en un checkpoint, los vivos vuelven a su sitio dormidos y con la vida llena (`reset_patrol`, grupo `enemy`, como las Burbujas). Todo en tiempo del mundo (el Debug lo ralentiza ×0,5). **Banner** (`spam_banner`; `SpamBanner`, `scripts/enemies/spam_banner.gd`, `scenes/enemies/spam_banner.tscn`; `data/enemies/spam_banner.json`): la celda E es la **entrada** del pasillo (una ranura) y el pasillo son `corridor_tiles` celdas de esa fila hacia `direction`; ciclo de `interval_s` (3 s) en tiempo del mundo: reposo, **aviso** (9 cuadros a 12 fps: la ranura parpadea en rojo alerta con flechas y una línea discontinua marca el suelo del pasillo) y **barrido** (un banner blanco «¡OFERTA! / SOLO HOY» de 2 × 0,75 tiles a ras de suelo, a 640 px/s, con estela); `phase_s` desfasa dos banners. Solo daña barriendo (−10, invulnerabilidad de Isak; empuja hacia donde va); se salta por encima o se espera en un nicho. **No es un cuerpo físico:** el láser lo atraviesa y el pulso no le afecta (indestructible); sin `link_off`. Al reaparecer Isak, el ciclo vuelve a su inicio. **Esquema** (`tools/validate_level_schema.py`): los params por instancia de estos dos tipos se validan con su `level_params` (solo los listados y en su rango: p. ej. `chase_speed_px_s` 20-200, `direction` −1 o 1, `corridor_tiles` entero 3-40); el pasillo del banner cabe en el grid sin celdas sólidas y el ciclo deja reposo (`interval_s` ≥ aviso + barrido + 0,25 s). `tools/validate_level.py` no modela aún estos enemigos (paso 10). **Arte por script** (sin AutoSprite): `tools/gen_world1_enemies.py` (validador `tools/validate_world1_enemies.py`, en `tools/run_tests.sh` junto con `tools/validate_enemy_sprites.py`): punto rojo de 64 × 64 (círculo rojo alerta con «1» blanco: dormido, persecución con halo, aviso, lanzado, aturdido gris con chispas y canto de plataforma, despertando, chispa gris del láser y derrotado) y banner de 128 × 64 (ranura apagada y en aviso, banner y estela). **Ayudas Q** `notification_badge` («Punto rojo») y `spam_banner` («Banner») en `data/help.json` (categoría enemigo; ayuda disponible mientras exista y no esté derrotado: dormido, persiguiendo o aturdido sí; el banner siempre) y fichas del álbum (pestaña Enemigos del Mundo 1). Sala de prueba `data/levels/mensajes_test.json` (36 × 12; escena `scenes/levels/mensajes_test.tscn`, no enlazada desde el hub ni recorrida por el bot): dos puntos rojos en una sala alta («aturdir y rematar») y dos banners desfasados en un pasillo de 14 tiles con un nicho de una vía («carrera contra amenaza»). Pruebas: `tests/test_notification_badge.gd`, `tests/test_spam_banner.gd`, `tests/test_mensajes_test_level.gd`, `tests/test_help_inert.gd`, `tests/test_notas_album.gd` y las de Python del esquema. Capturas: `tools/render_mensajes_test.gd`.

**Hecho en los pasos 6, 7 y 8 (2026-10-16):** tipos nuevos del catálogo (`data/world1_objects.json`, con `help_id`, secciones de ajuste y **`level_params`**: rangos de sus params que valida el esquema). **Recordatorio** (`reminder_platform`; `ReminderPlatform`, `scripts/levels/reminder_platform.gd`): plataforma sólida (no de una vía) de 1-3 tiles con la tarjeta y su colisión en los 32 px de arriba de su celda; `group`: al pisar uno en reposo empieza la **cuenta compartida** de `timer_s` de todos los del grupo en reposo (un reloj común: van exactamente igual), con un indicador de 4 segmentos; los últimos `warn_s` (0,5-1,0 s = 6-12 cuadros a 12 fps; el esquema lo exige) el despertador suena, la tarjeta parpadea y tiembla; al vencer deja de ser sólido al instante (Isak cae al foso, sin daño), se parte y cae, y vuelve a los `respawn_s` (si Isak no ocupa su sitio) con una animación de reposición. **Botón Posponer** (`snooze_button`; `SnoozeButton`): objetivo del láser (grupo `laser_activatable`, diana cian a la altura del celular desde el suelo de su celda; disparar pegado cuenta); `targets` = grupos de recordatorios; un impacto con alguno **contando** suma `extend_s` (4) a la cuenta común sin pasar de `cap_s` (8), sale «Zzz» en el botón y «Zz» sobre los recordatorios y el botón se **enfría** `cooldown_s` (1 s; el anillo se rellena; enfriándose, el impacto no hace nada); sin cuenta (en reposo, caídos o volviendo), **chispa gris** «nada que posponer». Apagado (diana gris) cuando sus grupos no cuentan; el pulso no le hace nada. **Pop-up translúcido** (`overlay_popup`; `OverlayPopup`): ventana de nine-patch de `width_tiles` × `height_tiles` con su texto, dibujada **por encima del mundo** (z 50; por debajo de la interfaz) al 70 % de opacidad, **sin colisión** (no bloquea a Isak ni al láser); se cierra con el pulso a su botón de 24 px (`close_button_px`, dentro de la ventana; un pulso que solo toca la ventana no hace nada) y queda cerrada; con el **Debug** la opacidad baja con su intensidad hasta el 15 % y aparece un contorno cian discontinuo (la ventana «vista con Debug»); admite un `ad_cover` sobre su botón (el anuncio enlaza ahora con un `popup_blocker` o un `overlay_popup` y se dibuja encima). **Barra del 99 %** (`update_bar`; `UpdateBar`): puerta sólida de 1 × 3 tiles con indicador y cartel; se **arma** cuando Isak entra en su `zone`, sube a 99 % en `rise_s` y se **traba** `wait_s` (20) con textos de interfaz que cambian («Instalando… 99 %», «99,9 %», «Calculando tiempo restante…», «Casi listo»); `waves` (`[{t, type, x, params}]`, `type` Burbuja o punto rojo, `params` validados con los del enemigo): cada enemigo se anuncia 0,75 s antes (9 cuadros a 12 fps) con una **flecha roja** en el techo de la zona y una **sombra** en el suelo y cae en un **paquete** que al tocar el suelo se abre y lo suelta (el paquete no daña); al 100 % («Reiniciando…») los que quedan se apagan con su pop **sin drops** y la puerta se recoge hacia el techo para siempre; si Isak reaparece antes de abrirla, vuelve al principio (97 %, sin enemigos ni avisos). Los cuatro van en **tiempo del mundo** (el Debug los ralentiza ×0,5; la pausa los para) y vuelven a su estado inicial al reaparecer Isak (el pop-up cerrado y la barra abierta, no). **Esquema** (`tools/validate_level_schema.py`): `level_params` de objetos, recordatorio con `group` y `warn_s` < `timer_s` y celdas vacías, Posponer con `targets` existentes y `cap_s` ≥ `extend_s`, botón del pop-up dentro de la ventana (y anuncio en su celda), barra con `zone` dentro del grid y oleadas válidas. `tools/validate_level.py` trata por ahora los recordatorios como **tablas fijas** (sin cuenta ni caída) y la barra como abierta: los tiempos son el paso 10. **Arte por script** (sin AutoSprite): `tools/gen_world1_tower.py` (validador `tools/validate_world1_tower.py`, en `tools/run_tests.sh`; `assets/sprites/tower_objects_frames.tres`): recordatorio de 1-3 tiles (estable, aviso, cayendo, repuesto), segmentos y «Zz», botón Posponer (apagado, listo, golpeado, enfriamiento), ventana y contorno «con Debug» en nine-patch, botón de cerrar y campana, barra (progreso, trabada, llena, abriéndose), paquete, flecha roja (el único rojo: avisa de una amenaza) y sombra. **Ayudas Q** `reminder_platform` («Recordatorio»), `snooze_button` («Posponer»), `overlay_popup` («Pop-up translúcido», radio de 3,5 tiles por su tamaño) y `update_bar` («Actualización»), con `is_help_available` (recordatorio caído o volviendo, no; Posponer, siempre; pop-up cerrándose o cerrado, no; barra abierta, no) y sus fichas del álbum (Mundo 1, Objetos). Salas de prueba (no enlazadas desde el hub ni recorridas por el bot): `recordatorios_test` (30 × 12: dos recordatorios sueltos sobre un foso y el grupo `posponer_1` de 2 s que solo se cruza disparando al Posponer desde el segundo recordatorio), `overlay_test` (24 × 12: el pop-up tapa la plataforma de la subida; con el Debug se ve; el pulso desde el suelo lo cierra) y `actualizaciones_test` (28 × 12: la sala de espera con las tres oleadas de la propuesta). Pruebas: `tests/test_reminder_snooze.gd`, `tests/test_overlay_popup.gd`, `tests/test_overlay_test_level.gd`, `tests/test_update_bar.gd`, `tests/test_help_inert.gd`, `tests/test_notas_album.gd` y las de Python del esquema. Capturas: `tools/render_tower_rooms.gd` (y las fichas en `tools/render_hub.gd`).

**Riesgos:**

1. **Validador:** el estado crece (pulso, láser, Debug, puentes, ventanas, grupos con tiempo). Los tiempos no se pueden modelar del todo en un grafo de celdas: se aproximan con estimaciones y avisos, y se confirman con pruebas GUT y el bot. Riesgo de falsos «inalcanzable» con el láser horizontal en un nivel vertical (alturas exactas del celular).
2. **Bot:** el más caro. Un bot de recorrido por puntos es frágil ante cambios de geometría; hay que generar el recorrido desde el validador, no escribirlo a mano.
3. **Cámara:** mareo en vertical; probar con jugadores.
4. **Energía:** que un jugador gaste todo en el piso 1 y llegue al acertijo vacío: lo cubre `cargador_1`; hay que medirlo.
5. **Debug a medio cruzar:** se apaga a 0 y la plataforma deja de ser sólida: la caída debe acabar siempre en el suelo del acertijo (validador: regla de caída ≤ 4 tiles).
6. **Duración:** si el piso 2 se alarga, recortar 2a o el secreto A antes que el acertijo.

## 11. Preguntas (resueltas el 2026-10-16)

Todas aprobadas con su recomendación (ver «Decisiones aprobadas» al principio). Respuestas del usuario que precisan la recomendación: 4 (Calc, opción A) y 5 (los recuerdos son **correos y mensajes de texto recibidos de familiares y amigos**; su contenido, por decidir).

1. **¿Los temporizadores (recordatorios, ventana del cable, espera del 99 %) van en tiempo del mundo, de modo que el Debug los ralentiza?** *Recomendación:* sí, es coherente con «el tiempo se ralentiza» y abre el patrón futuro «Ralentizar la ventana».
2. **¿El punto rojo despierto es inmune al láser?** *Recomendación:* sí (chispa gris): obliga al patrón 1. Alternativa: el láser le hace daño pero lo «agita» (se acelera 2 s).
3. **¿Recoger el Debug llena la energía?** *Recomendación:* sí (`refill_energy`), solo la primera vez y en este chip.
4. **Encuentro con Calc:** ¿opción A, B o C (§8)? *Recomendación:* A (Calc colgada en la azotea; Q `calc_off` y pulso). Los textos los decides tú.
5. **Recuerdo coleccionable:** ¿qué es (texto, imagen), qué recuerdo de Isak es y dónde se ve? *Recomendación:* pestaña «Recuerdos» en la carpeta del Mundo 1 del álbum de Notas, guardado en `memories`; sin efecto en el juego (V16). El contenido es historia: decides tú.
6. **¿Power bank en el secreto C (vacío)?** *Recomendación:* sí, uno vacío: los power banks «llegan desde el 1-2, cuando se aprende el Debug» (§6 del 1-1 ampliado).
7. **¿Ancho de 28 tiles (algo de scroll horizontal) o de 20 (sin scroll horizontal)?** *Recomendación:* 28, para que el láser tenga recorrido y los pisos no sean pasillos.
8. **Puntos de sincronización al entrar a los pisos 2 y 4.** *Recomendación:* sí (cubren el acertijo y la sala de espera).
9. **Espera del piso 4: ¿20 s con tres oleadas?** *Recomendación:* sí; bajar a 15 s si en las pruebas aburre.
10. **¿Recordar al jugador el secreto D del 1-1?** *Recomendación:* no con una línea automática (Eco no lanza mensajes); basta la Q y la ficha de `glitch_wall`. Alternativa: que Calc lo mencione en la descripción de una mejora.
