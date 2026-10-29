# Propuesta: Mundo 5 «La Tienda» (5-1, 5-2, 5-3 y jefe El Vendedor)

**Estado:** **PROPUESTA (2026-10-28), sin implementar.** Las decisiones de diseño las toma el orquestador con la autoridad que el usuario delegó en los Mundos 2-4 (§9, cada una marcada «Decisión tomada», con su razón; todas se pueden cambiar al probar). Solo quedan para el usuario las de **gusto personal o reservadas** (§10: el **blanco del Debug**, los **remitentes** de `msg_5_x` y el **gasto de AutoSprite** del paso 24), cada una con su recomendación por defecto. Desarrolla `mundo-5-tienda.md` sin contradecirlo. Lo que no viene de los docs va marcado **PROPUESTA**. Los valores son orientativos y se ajustan jugando y con el validador. **Todos los textos (Eco, Isak, Calc, carteles, El Vendedor, mensajes) son borradores marcados «propuesto»**. Como en los Mundos 2-4, este documento cubre **solo Caché**; Kernel y Raíz salen solo en el jefe y a alto nivel.

**Fuentes:** `mundo-5-tienda.md` (ficha original), `01-ficha-reglas.md` §5 (Mundo 5: Voluntad, Combinación, «todo tiene un precio y los atajos tienen trampa»), `02-isak-habilidades.md` §3.5 (Combinación: Embestida, Filo y Sismo; Agitar **retirado** el 2026-10-28), `04-personajes.md` §12.1 (Eco en el Mundo 5: «silueta de vendedor hecha de luz»; «Yo decido por ti, así no te equivocas.») y §12.3 (Calc «regenta la tienda oculta de atajos legítimos del Mundo 5»), `05-hub.md` §13.2 y §13.4 («Mundo 5 completado: quinta pieza, en blanco. El fondo está completo»), `07-estilo-visual.md` §15.3 (negro con neones, amarillo chillón, Debug blanco) y §15.5 (familia de formas: **carteles y cajas**), `preguntas.md` (C3: «por primera vez se gastan **dentro de un nivel**»; V13: valores de tienda, atajos y suscripción en `data/economy.json`; «Pendiente para el Mundo 5: Sismo partía de Agitar»), `propuesta-recuerdos.md` §11.2 (capas `boss_w5_l1`-`l3` ya escritas: las radios del barrio y el letrero «Se arreglan cosas»), `propuesta-hub-mundos-4-6.md` (M5 en la página 2, columna 14, `unlocked_by: ["4-boss"]`; M6 con `5-boss` y candado de 5 ranuras), `propuesta-mejoras.md` §4 (idea del Ocultarte con El Vendedor), `propuesta-mundo-4.md` (plantilla de este documento; §8.1 con las pruebas del usuario y las lecciones), `lista-sonidos.md` (IDs `*_w5_*`), `CLAUDE.md` y los datos actuales (`data/isak_abilities.json`, `scripts/player/isak.gd`, `data/hub.json`, `data/hud.json`, `data/memories.json`).

**Física de referencia** (datos actuales, la misma de `propuesta-mundo-4.md`): andar 220 px/s (3,4 tiles/s), correr 360 px/s; salto de unos 184 px (subidas cómodas de 2 tiles; 3 filas = 192 px **no** se suben), cumbre a 0,4 s. Caja de Isak 32 × 80 px (comprimido 32 × 40, anda a 160 px/s y salta 96 px). Pulso gratis, radio 96 px, solo en el suelo y sin comprimir. Láser 10 de energía, 768 px, horizontal, solo en el suelo. Debug: mantener 1 s, 20/s reales, mundo ×0,5; **con el Debug activo o cargando no hay dash**. Dash 192 px en 0,2 s, invulnerable 0,3 s, 10 de energía, 1 aéreo por salto. Golpe al suelo gratis (mantener abajo; en el aire, caída a 960 px/s). Pellizcar gratis, **también en el aire**. Golpe recibido −10 de Sync e invulnerabilidad 1 s. Energía 100 (110-130 con mejoras). Pantalla de **20 × 11,25 tiles**.

**Lo que ya existe y este mundo aprovecha:** la carpeta **M5** en la página 2 del hub (columna 14, `unlocked_by: ["4-boss"]`, `requires_upgrade`, `levels: []`), el candado de La Nube con la ranura `boss_w5_l1`, los textos de las tres capas del **«Fragmento de voluntad»** en `data/memories.json`, `debug_colors["5"]` en `data/hud.json` (hoy `#f4f4f4`, **provisional**), el estado **Congelado con daño al liberarse** del Mundo 4 (`FrozenState`), `BlinkPlatform`, `relay_receiver`, `glitch_wall`, `small_frame`, `exit_terminal` con `skin`, `calc_actor`, `DndSwitch` (objeto que da una habilidad), `BossBase` + `WeakPoint` + `BossReward`, y las tres restricciones actuales de Isak que la Combinación convierte en movimientos: **hoy no hay dash comprimido, ni golpe al suelo comprimido, ni golpe al suelo durante un dash** (`dash_denial` y `ground_pound_denial` de `scripts/player/isak.gd`).

---

## 0. Resumen

- **El mundo:** un centro comercial infinito, de madrugada y a todo neón, donde todo tiene precio y toda decisión ya viene tomada. Eco le robó a Isak la **voluntad** y aquí ya no la disimula: quiere **decidir por él**. La **mecánica central nueva** es que **querer cuesta**: por primera vez los **puntos de atención se gastan dentro de un nivel** (C3) en tiendas, cajas y atajos que siempre esconden algo, y la **tentación** se nota en el cuerpo: las Ofertas **tiran de Isak** y alejarse de ellas **pesa**. Ni prisa por temporizador (Mundo 1), ni scroll (Mundo 2), ni cifras que sostienen el suelo (Mundo 3), ni esperar a que te contesten (Mundo 4): aquí el reto es **decidir qué no coger** y **resistir un tirón** que el movimiento siente.
- **Gesto del mundo: la Combinación** (habilidad `combo`; **sin tecla nueva**): encadenar en el aire dos gestos que hoy no se pueden juntar da un súper movimiento. Son **exactamente los tres pares** de los gestos que quedan tras retirar Agitar: **Embestida** (Deslizar + golpe al suelo: diagonal hacia abajo que rompe persianas y limpia lo que hay debajo), **Filo** (Pellizcar + Deslizar: dash comprimido de 4 tiles que cruza ranuras en el aire y atraviesa a los enemigos pequeños) y **Sismo** (Pellizcar + golpe al suelo: onda que recorre todo el suelo de la pantalla, **aturde a todos** los enemigos del suelo y **rompe a la vez** lo que hay que romper a la vez). **Sismo queda redefinido** (partía de Agitar, §3.2.4). Se obtiene al principio del 5-2, en «Paquete completo»: «Esto no lo compré. Es mío.».
- **Niveles:** 5-1 «Oferta del día» (horizontal 200 × 14 por **plantas del centro comercial**: Ofertas, tienda, cajas sorpresa, primer atajo con trampa, secreto «Devoluciones»), 5-2 «Prueba gratis» (220 × 14: obtener la Combinación y aprender cada combo en su tramo; tienda oculta de Calc) y 5-3 «Última oportunidad» (250 × 14: cuentas regresivas encadenadas, cajas sorpresa en cadena sin energía para todas, examen final y la **lista de deseos** con la tentación más fuerte).
- **Jefe El Vendedor:** máquina expendedora gigante con brazos y sonrisa de neón; **siempre te atiende de frente**, y el punto débil, el botón **«Cancelar»**, está **en su espalda** (solo con el Debug, en rojo). Daño = **ponerse detrás → Debug revela «Cancelar» → pulso que marca → láser** (la regla de V14 de los tres jefes anteriores). Cada fase da su manera de llegar a la espalda: (1) **plataformas con precio** pagadas con fichas (el Debug marca las trampas); (2) **cajas sorpresa** lanzadas: las buenas se abren (la del «ticket de devolución» lo deja procesando y no se gira) y las malas se aturden y sirven de escalón; (3) **«Oferta por tiempo limitado»**: la tentación arrastra al centro y solo una **Embestida** (por encima) o un **Filo** (por la ranura de monedas) llegan a la espalda antes de que acabe la cuenta; si acaba, «Procesando pago…» congela y duele al liberarse. Arena 20 × 11, cámara fija, 9 golpes en Caché.
- **Recompensa:** `boss_w5_l1` «Fragmento de voluntad»; en el hub se enciende la **quinta pieza** (el fondo queda completo: la foto que Isak tenía antes de entrar al celular), la **quinta ranura** del candado (el candado de La Nube se abre) y **M6 «La Nube» queda disponible** («Próximamente»).
- **Arte:** todo por **placeholders por script** hasta tener niveles y jefe jugables (regla del usuario del 2026-10-28); el arte final con AutoSprite (El Vendedor y las tres poses de combo de Isak: **57-60 créditos** en una pasada, de un saldo de **249**) va **al final** y **no se gasta nada sin permiso** (§6.2, §10.3).
- **Tamaño:** **25 pasos** (0-24, §8), con una **prueba del usuario temprana** tras el 5-1 (lección del Mundo 4). ≈ **70-80 %** del esfuerzo del Mundo 1: tres movimientos nuevos de Isak, una fuerza nueva sobre el movimiento (la tentación), el primer gasto de puntos dentro de un nivel y unos catorce tipos nuevos, casi todos sobre piezas existentes.

---

## 1. Qué está decidido y qué es propuesta

| Tema | Decidido en los docs | PROPUESTA / decisión tomada en este documento |
|---|---|---|
| Tema | Eco robó la **voluntad**; quiere decidir por Isak «para que no se equivoque»; centro comercial infinito; atajos que cobran algo (`mundo-5` §10). | Querer cuesta: gastar puntos y resistir el tirón; la voluntad se juega en **lo que no se coge** (§2). |
| Paleta | **Negro y amarillo chillón de rebajas**, neones y carteles; **Debug blanco puro** (`mundo-5` §10.1, `07` §15.3, `CLAUDE.md`). | Reglas de contraste (el blanco frente al texto del HUD y al amarillo; **sin rojos ni naranjas en los carteles**) y **3 opciones de blanco** para el usuario (§6.1). |
| Música | Chiptune de supermercado alegre y repetitivo, voces de anuncio. | Capa de «megafonía» que **sube con la tentación** (accesibilidad: avisa del tirón, §6.4). |
| Humor y lo oscuro | «50 % de descuento (en algo que nunca pediste)», «¡Últimas 3 unidades! (hay 4000)», «Al continuar aceptas términos que nadie lee», botón de aceptar enorme y de rechazar diminuto; lista de deseos escrita por Eco. | Carteles propuestos (§2.2); el botón «Rechazar» diminuto como pieza (`terms_gate`, §3.7); la lista de deseos como tramo final del 5-3 (§4.3). |
| Moneda | Los puntos de atención **por primera vez se gastan** (C3: **dentro de un nivel**): Sync Rate, energía de Debug o atajos. | **Decisión tomada:** se gastan los **puntos reales** (el saldo del jugador), con cuatro protecciones: nada obligatorio cuesta, todo se puede pagar con lo cogido antes en el mismo nivel, nunca hay deuda y «Devoluciones» devuelve lo drenado (§3.1). Precios en `data/economy.json` (V13). |
| Tentación | Objetos que tiran de Isak como un imán; el movimiento pesa más al alejarse. | Fuerza horizontal con valores y reglas, modelable por el validador (§3.3). |
| Enemigos | Oferta, Caja sorpresa, Suscripción, Atajo con trampa, Cuenta regresiva (`mundo-5` §10.3). | Parámetros y qué se reutiliza; piezas nuevas solo para que **cada combo tenga un obstáculo propio** (§3.7). |
| Gesto | **Combinación** en el 5-2, sala «Paquete completo»: Embestida, Filo y Sismo; Eco: «Todo tiene un precio.»; Isak: «Esto no lo compré. Es mío.». | **Decisión tomada:** combos = los tres pares de gestos que hoy se excluyen; **Sismo redefinido** como Pellizcar + golpe al suelo (§3.2). |
| Aliados | Calc regenta la tienda oculta de atajos legítimos del Mundo 5 (`04` §12.3). | **Decisión tomada:** su **caja registradora con el LCD** en el secreto A del 5-2 (no el actor entero; Calc sigue en el hub) (§4.2.1). |
| Niveles | Objetivo, dificultad (4, 5, 5), duración (8, 9 y 10 min), tramos, cierre y secretos (`mundo-5` §10.4-§10.6). | Forma **por plantas desde el principio** (lección del Mundo 4), tamaños, columnas, presupuesto de camino, economía, secretos B y C (§4). |
| Jefe | El Vendedor: máquina expendedora con brazos y sonrisa de neón; Eco habla por ella; «Cancelar» en la espalda, solo con el Debug, en rojo; fases 1-3; recompensa «Fragmento de voluntad». | Daño (marca), arena, giro hacia Isak, fichas de la arena, ataques, energía y Kernel / Raíz (§5). |
| Recuerdo de jefe | Capas `boss_w5_l1`-`l3` ya escritas e ilustración `memory_art_w5` por script. | Entrega igual que en los Mundos 1-4 (§5.9). |
| Mensajes de secretos | 3 por mundo en Caché; reaparecen en Kernel y Raíz; requisito del final real. | **Decisión del usuario** (§10.2): remitente; recomendación, **el Abuelito** (el hilo de las radios). Borradores en §4.5. |
| Hub | Carpeta M5 en la página 2 (columna 14); **quinta pieza en blanco** al completar el mundo; M6 con `5-boss`. | Filas del panel, `available_text`, miniatura, línea de Calc, el momento del **fondo completo** (§4.6). |
| Vidas, power banks, puntos | Vida extra cada 3 mapas (1-1, 2-1, 3-1, 4-1): **la siguiente va en el 5-1**. ≈ 9 puntos por mapa. Al menos un power bank por mundo y vuelta. | **12 puntos por mapa** (9 + 3 «para tentar»), 3 power banks, vida extra en el 5-1 (§4). |
| Eco | ~~«Silueta de vendedor hecha de luz» (`04` §12.1).~~ **Decisión del usuario 2026-10-29: Eco se ve igual en todos los mundos** (la esfera de los Mundos 1-3). | ~~Variante del compañero en los niveles del Mundo 5~~ (descartada; §6.3). |

---

## 2. Tema y tono

### 2.1 Idea

Un centro comercial que no cierra nunca. Cada planta es un pasillo de ofertas, y para pasar a la siguiente hay que recorrerla entera: las escaleras mecánicas siempre están **en el otro extremo** (así funcionan los centros comerciales, y así funcionan estos niveles, §4). Los carteles **tiran** de Isak: si se queda quieto, la Oferta se lo lleva; si se aleja, cuesta. Hay tiendas que venden lo que de verdad hace falta (un poco de Sync Rate, energía), cajas que pueden traer cualquier cosa y **atajos que prometen saltarse un tramo y siempre cobran algo más** que su precio. El gesto del mundo no se compra: en «Paquete completo» Isak descubre que lo que la oferta «gratis» contiene son **sus propios gestos**, y que juntarlos es suyo. En el 5-3 Isak camina sobre una **lista de deseos** que escribió Eco, y el secreto es el único deseo que sí era de Isak.

### 2.2 Tono

- **Superficie (humor), PROPUESTA de estilo (textos revisables):** carteles con la voz de una tienda inventada (sin marcas): «50 % de descuento (en algo que nunca pediste)», «¡Últimas 3 unidades! (hay 4000)», «Al continuar aceptas términos que nadie lee», «Precio especial para ti, {apodo}», «Lleva 3, paga 3», «Envío gratis*» (el asterisco lleva a un cartel diminuto al fondo: «*no»), «Devoluciones: planta −1, al fondo, sin cartel». Nada hiriente: el humor es la insistencia.
- **Fondo (lo oscuro):** en el paralaje, escaparates con maniquíes que miran a Isak y precios que cambian cuando no los miras. En el 5-3 los objetos de la lista de deseos son cosas que Isak **nunca quiso** (un reloj que cuenta pasos, unos auriculares que «aprenden lo que te gusta», un curso de «productividad extrema»).
- **Eco:** amable y paciente, como un vendedor que ya sabe lo que vas a llevar. Su frase del mundo, **«Todo tiene un precio.»**, al obtener la Combinación (doc); la del recuerdo, **«Yo decido por ti, así no te equivocas.»**, en la recompensa. En el jefe, **sin disimulo**: habla a través de la máquina.
- **Isak habla por primera vez en un cuadro de texto:** «Esto no lo compré. Es mío.» (doc). **Decisión tomada:** interlocutor nuevo `isak` en `speaker_styles` (estilo `panel` con su icono), solo para esa línea en Caché (§4.2.2).
- **Calc:** seca y honesta, el contraste de la tienda: su caja registradora del 5-2 vende un atajo «sin letra pequeña» al precio que dice.

### 2.3 Gastar no es perder (PROPUESTA de presentación)

- **Nada obligatorio cuesta puntos.** Cada compra, cada caja y cada atajo es **opcional**: el camino largo siempre existe y siempre se puede recorrer con 0 puntos. Lo exige el validador (§7.1).
- **Las ayudas nunca mienten:** la Q de un atajo dice que **esconde algo** (sin decir qué); el Debug dice **qué**.
- **HUD:** el contador de puntos de atención ya existe; en el Mundo 5 **parpadea en amarillo al gastar** («−3») y en magenta al drenar una Suscripción. Sin HUD nuevo en los niveles; en el jefe, el contador de **fichas** va en la barra del jefe (§5.2).

---

## 3. Mecánicas

### 3.1 Puntos de atención como moneda (`data/economy.json`, `GameState.spend_attention`)

| Regla | Valor propuesto | Por qué |
|---|---|---|
| Qué se gasta | El **saldo real** de puntos de atención (`GameState.attention_points`), como en Calc. Gastar marca «sin guardar». | C3: «por primera vez se gastan dentro de un nivel». Un saldo aparte (como los likes del Mundo 3) contradiría la ficha. |
| Nada obligatorio | **Ninguna pieza del camino obligatorio cuesta puntos.** | Regla del validador; la voluntad es elegir, no pagar peaje. |
| Siempre pagable | Todo lo que se vende en un nivel cuesta **como mucho lo que hay en ese nivel antes de esa tienda** en la ruta (el validador lo cuenta desde un saldo de 0). | Un jugador que lo gastó todo en Calc puede comprar igual; nadie llega a una tienda sin poder pagar «por culpa de antes». |
| Sin deuda | El saldo nunca baja de 0. La Suscripción con saldo 0 no drena: muestra «Pago rechazado» y se suelta sola a los 3 s. | Sin trampas imposibles. |
| Rollback | Lo gastado sin guardar vuelve con un game over (rollback a la última copia), como todo. | Regla única ya implementada. |
| Puntos por mapa | **12** (9 del resto de mundos + 3 «para tentar»). Comprarlo **todo** en un nivel cuesta 9-11. | Un jugador frugal acaba el Mundo 5 con más puntos que en otros mundos; uno que compra todo, con menos. **Todo tiene un precio** sin romper la economía de Calc (`propuesta-mejoras.md`, 450 en tres vueltas). |
| Precios (Caché) | Tienda: **+25 de Sync Rate = 3**, **+40 de energía = 2**; atajo con trampa = **3**; atajo legítimo de Calc = **2**; plataformas del jefe: **fichas** de la arena, no puntos (§5.2). | Baratos a propósito: la tentación es pequeña y constante. |
| Dónde | `data/economy.json` (V13): precios, drenaje, devoluciones y máximos por nivel; el esquema rechaza un precio que no se pueda pagar. | V13 ya proponía ese archivo. |

### 3.2 La Combinación (habilidad `combo`; sin tecla nueva)

#### 3.2.1 Regla general

- **Encadenar en el aire** dos gestos que hoy se excluyen (`dash_denial` y `ground_pound_denial` niegan hoy el dash comprimido, el golpe comprimido y el golpe durante un dash): **con `combo` obtenido, esas tres combinaciones dejan de negarse y se convierten en un súper movimiento.** Sin `combo`, todo sigue igual (lo comprueba una prueba).
- **Solo en el aire** (el doc: «encadenar dos gestos en el aire»). En el suelo, Pellizcar + golpe sigue negado y el dash comprimido también.
- **Coste único: 15 de energía por combo** (una regla fácil de recordar; el dash solo cuesta 10). Sin energía: chispa gris y `EventBus.combo_denied`.
- **Con el Debug activo o cargando no hay combos** (como el dash). Apagan el Ocultarte. Sin pulso ni láser durante el combo.
- **Sin pista de Calc:** los gestos progresan con estas combinaciones (`02` §3.5, decisión del 2026-10-19).
- **Aviso** al obtenerla (entrada `combo` de `data/ability_notices.json`, una vez por partida guardada): «Combinación en el aire · Embestida: Deslizar + abajo · Filo: Pellizcar + Deslizar · Sismo: Pellizcar + abajo» (2026-10-29: sin «=», que la fuente de textos no tiene), con las teclas leídas del Input Map. Cada combo tiene además su **Q en el tramo** donde se enseña (§4.2).
- Valores en la sección `combo` de `data/isak_abilities.json` (provisionales, se ajustan jugando).

#### 3.2.2 Los tres combos

| Combo | Entrada | Movimiento | Efecto | Lo que **solo él** hace (anti-redundancia, §3.9) |
|---|---|---|---|---|
| **Embestida** (`combo_ram`) | Durante un **dash aéreo**, mantener **abajo** | Corta el dash y cae en **diagonal** (45°, 960 px/s) hacia donde iba, invulnerable hasta tocar suelo | Al aterrizar: onda de **2 tiles** a cada lado que aturde 3 s y hace **2** de daño (el golpe al suelo hace 1); **rompe persianas** (`shutter`) y suelos de «Cerrado por inventario» desde arriba | Romper una **persiana reforzada** (el golpe normal rebota) y llegar a **lo que hay debajo** en el mismo movimiento («rompe una barrera y limpia a los enemigos de debajo», doc). |
| **Filo** (`combo_edge`) | **Comprimido en el aire**, pulsar **Deslizar** | Dash **comprimido** de **4 tiles** (256 px) en 0,22 s, caja 32 × 40, gravedad 0 | **Atraviesa** a los enemigos pequeños (vida ≤ 1: Suscripción, caja aturdida) **derrotándolos**; cruza **ranuras de 1 tile en el aire** (`price_rail`) | Cruzar un **hueco de 4 tiles a través de una ranura de 1 tile** (comprimido solo salta 96 px y anda a 160; el dash normal no cabe por la ranura). |
| **Sismo** (`combo_quake`) | **Comprimido en el aire**, mantener **abajo** | Golpe al suelo comprimido: cae a 960 px/s; al aterrizar, la onda **recorre todo el suelo visible** a 1280 px/s hacia los dos lados (0,5 s) | **Aturde 3 s a todos** los enemigos **que tocan el suelo** en pantalla (los que vuelan no); **rompe a la vez** todas las estanterías de saldos (`clearance_shelf`) de esa planta en pantalla; 0 de daño | **Simultaneidad a distancia:** las estanterías de saldos solo caen si se rompen **todas en menos de 0,5 s** (si no, se «reponen»); nada del kit llega a la vez a sitios separados. |

#### 3.2.3 Reglas finas (PROPUESTA)

- **Orden:** el primer gesto se hace como hoy (dash aéreo, o Pellizcar en el aire); el segundo, mientras dura el primero (el dash) o mientras Isak sigue comprimido en el aire. Sin ventana extra: si el primero acaba, el segundo es un gesto normal (o se niega, como hoy).
- **Embestida y el dash aéreo:** gasta el dash aéreo del salto (no da otro). Si no hay suelo debajo, cae hasta el suelo (el foso mata como siempre: el validador no acepta Embestidas hacia un foso).
- **Filo y el tamaño:** al acabar, Isak **sigue comprimido** (hay que soltar Pellizcar donde quepa, como siempre).
- **Sismo y lo que vuela:** no afecta a Suscripciones en vuelo ni a Ofertas colgadas (están en la pared); sí a las Ofertas de pie, a las cajas en el suelo y a los enemigos de suelo de otros mundos.
- **Tiempo:** de Isak, tiempo real, como los demás gestos.
- **Pose provisional por script** (como las de los otros gestos antes de su hoja): Embestida = cuadro de dash girado 30° con estela; Filo = cuadro comprimido con la estela del dash; Sismo = cuadro comprimido de caída y anillo de onda a ras de suelo.

#### 3.2.4 Sismo redefinido (Agitar retirado)

El doc decía «Sismo (golpe al suelo con onda)», y la onda venía de Agitar, **retirado el 2026-10-28** porque «hace lo mismo que el pulso». **Decisión tomada:** Sismo = **Pellizcar + golpe al suelo**. Conserva lo que el doc pide («rompe plataformas a la vez y aturde a toda la pantalla») y evita repetir el error de Agitar: no es un aturdimiento en área cerca de Isak (eso ya lo hace el pulso), sino **a toda la planta a la vez**, con una pieza que solo él resuelve (§3.9). Se actualiza `02-isak-habilidades.md` §3.5 en el paso 22.

### 3.3 Tentación (`offer_sign`; fuerza `TemptationField`)

| Regla | Valor propuesto | Por qué |
|---|---|---|
| Qué es | Cada Oferta tiene un **radio de tentación** (por defecto **5 tiles**, horizontal; altura del radio 3 tiles) | «Objetos brillantes que tiran de Isak hacia ellos, como un imán.» |
| Quieto | Isak **deriva hacia la Oferta a 60 px/s** (en el suelo y en el aire) | Quedarse quieto es el riesgo. |
| Alejarse | Andar o correr **alejándose** va a **×0,6** (andar 132 px/s, correr 216) | «El movimiento se vuelve más pesado al alejarse.» Siempre se puede salir: 132 − 60 > 0. |
| Acercarse | **×1,15** | Lo que tienta es fácil. |
| Dash y combos | **Ignoran la tentación** mientras duran | La salida rápida que pide el doc («alejarse con dash»). |
| Pulso | **Aturde** la Oferta **3 s**: el tirón se apaga | «Aturdirlo con el pulso» (doc). |
| Láser | Con la Oferta aturdida, **la derrota** (vida 2, +15 de energía) | El láser elimina, como en todos los mundos. |
| Varias Ofertas | Las fuerzas **se suman** con tope de 90 px/s de deriva y ×0,45 al alejarse | El 5-3 (lista de deseos) usa el tope. |
| Qué hay junto a la Oferta | El peligro **no es la Oferta**: son pinchos («carrito abandonado»), un foso con salida o una Suscripción | La tentación «atrae a Isak hacia un peligro» (doc). |
| Regla de diseño (validador) | Ninguna Oferta arrastra a Isak quieto **a un foso mortal**; el peligro junto a ella hace −10 y tiene salida | La tentación engaña, no mata (la regla del autocorrector y la oscuridad del Mundo 4). |
| Aviso | El cartel **late** más deprisa al acercarse, partículas que van hacia él y el sonido `sfx_w5_temptation_pull` sube (accesibilidad) | Se ve y se oye antes de sentirse. |

### 3.4 Caja sorpresa (`surprise_box`)

- **Qué es:** caja de 1 × 1 tile en el suelo o en una repisa, sólida. Contenido fijo **en los datos** (`content`: `points` 1-2, `energy` +30, `subscription`, `offer` o `empty`). **Nunca aleatorio:** «sorpresa» para el jugador, determinista para el validador y los bots (las ayudas no mienten y el bot no juega a la lotería).
- **Abrir:** **golpe al suelo encima** (o Embestida) o **pulso de cara** desde el suelo. Sale el contenido con un «pop» de 9 cuadros.
- **Ver dentro:** con el **Debug activo**, la caja se vuelve translúcida y enseña el icono del contenido (con contorno negro de 1 px para que se lea sobre el blanco). **El Debug como dilema** (doc): cuesta energía mirar.
- **Destruir sin abrir:** láser (vida 1): el contenido se pierde (también lo malo).
- **Aturdida** (la del jefe, §5.5): con el pulso, una caja lanzada queda **inerte 3 s** y **sirve de escalón** (la regla del juego: «el enemigo aturdido se puede usar como plataforma»).
- **Regla del validador:** una caja que **tapa** el camino obligatorio no puede contener nada que dañe sin aviso; las de los tramos de «elegir» (5-3) tienen al menos un orden seguro con la energía disponible.

### 3.5 Suscripción (`subscription`, enemigo)

- **Qué es:** un bichito-tarjeta con una sonrisa (sin marcas) que **flota hacia Isak** a 90 px/s cuando está a ≤ 5 tiles (aviso: se ilumina y suena una campanita de «¡Bienvenido!» 9 cuadros antes de lanzarse) y **se le engancha** al tocarlo (sin daño). También sale de cajas y de atajos.
- **Enganchada:** se ve en la espalda de Isak; **drena 1 punto de atención cada 2 s** (tope **5 por Suscripción**); con saldo 0, «Pago rechazado» y se suelta a los 3 s (§3.1). Cada punto drenado va al **registro de Devoluciones** del nivel (§3.6).
- **Cancelar** (doc): **pulso** (Isak se la quita; la deja aturdida 3 s en el suelo) o **golpe al suelo** (la onda la suelta). Aturdida: el láser o un Filo la derrotan (vida 1, +5 de energía). Si no se derrota, vuelve a buscar a Isak al despertar.
- **No hace daño nunca** (cuesta puntos, no Sync): el contorno rojo no la marca (desde el cambio 5 del Mundo 4 ningún enemigo lleva contorno rojo); se delata por su brillo magenta y su aviso.
- **Reutiliza:** el **punto rojo** del 1-2 (persigue volando, aviso de 9 cuadros) y su aturdido.

### 3.6 Devoluciones (`refund_desk`)

- Mostrador del secreto A del 5-1 («Devoluciones», doc: «donde se recuperan puntos de atención»). Un pulso de espaldas **devuelve todo lo drenado por Suscripciones en el intento actual de ese nivel** y **lo gastado en atajos con trampa** del mismo intento, más **2 puntos** propios del secreto. Una vez por intento.
- **Decisión tomada:** solo devuelve lo del nivel en el que está (registro por nivel e intento; no toca lo gastado en Calc ni en otros niveles). *Razón:* simple de explicar y de validar; premia volver a buscar el secreto.

### 3.7 Enemigos y objetos (qué se reutiliza)

Todo en **tiempo del mundo**, con `help_id`, `level_params` con rangos validados por el esquema, aviso de 6-12 cuadros antes de dañar y vuelta al estado inicial al reaparecer. **Rojo solo para lo que daña** (pinchos y el «Cancelar» del jefe); **ningún enemigo lleva contorno rojo** (lección del Mundo 4).

| Tipo (id) | Comportamiento (doc) | Cómo se resuelve (doc) | Implementación (PROPUESTA) | Reutiliza |
|---|---|---|---|---|
| **Oferta** (`offer_sign`, enemigo) | Cartel con el precio tachado; atrae a Isak hacia un peligro | Alejarse con dash o aturdirla con el pulso | §3.3. De pie en el suelo o colgada en la pared (`mount: "floor" | "wall"`); el precio tachado en **magenta**, nunca en rojo | Detección de la Burbuja, aturdido y `EnemyHealth`; fuerza nueva en Isak (`TemptationField`) |
| **Caja sorpresa** (`surprise_box`, objeto) | Se puede abrir o no; puntos, energía o un enemigo | Debug para ver el contenido | §3.4 | `ability_pickup` (pop), revelado del Debug (`OverlayPopup` translúcido), `fragile_card` (golpe que rompe) |
| **Suscripción** (`subscription`, enemigo) | Parásito que se pega y drena puntos por segundo | Pulso o golpe al suelo para cancelarlo | §3.5 | **Punto rojo** del 1-2 |
| **Atajo con trampa** (`shortcut_door`, objeto) | Puerta que promete saltarse un tramo y esconde una trampa | Pagar y arriesgarse, o el camino largo | Puerta de 1 × 3 con cartel de precio («Atajo: 3 ◆»). **Pulso de espaldas** para pagar (sin saldo, «Saldo insuficiente», chispa gris). Lleva a un pasillo que **ahorra** una o dos pasadas de una planta. Su `trap`: `subscription` (te espera dentro), `offer` (tirón hacia pinchos al salir), `countdown` (la salida es una cuenta regresiva) o **`processing`** («Verificando pago…»: **congelado 1,5 s y golpe al liberarse**, el `FrozenState` del Mundo 4). **Con el Debug**, el icono de la trampa se ve en la puerta. Un uso por intento. | `relay_receiver` (pulso de espaldas), `glitch_wall` (revelado), `FrozenState` |
| **Cuenta regresiva** (`countdown_platform`, `countdown_door`) | «¡Solo por hoy!»: temporizador que **se reinicia mientras no se use** | Cruzarla antes de que llegue a cero | Plataforma (o puerta) con un **cartel de cuenta** (5 → 0 s del mundo): sólida (abierta) mientras cuenta; a 0 **se pliega 1 s** con aviso de 9 cuadros y **vuelve con otra cuenta** («¡Últimas horas!»). La urgencia es **falsa**: siempre vuelve; esperar el ciclo siguiente es legítimo (el validador espera el peor caso). | **`BlinkPlatform`** (ciclo, aviso, no se materializa con Isak dentro) |
| **Tienda** (`shop_item`) | Primera tienda: comprar Sync Rate con puntos | — | Producto en una estantería con su etiqueta de precio; **pulso de espaldas** compra (efecto al instante); uno por intento; con saldo insuficiente, «Saldo insuficiente». | `relay_receiver`, `recharge_pickup` |
| **Términos y condiciones** (`terms_gate`, objeto) | Humor del doc: botón de aceptar enorme, de rechazar diminuto | — | Puerta de 1 × 3 con dos botones: **«ACEPTAR»** (3 × 1 tiles, cualquier pulso cercano lo pulsa) abre **y engancha una Suscripción**; **«rechazar»** (8 px, en lo alto de la puerta) solo lo alcanza **el láser desde el suelo de enfrente** o un **Filo** que lo roza: abre sin coste. | `laser_receiver`, `relay_receiver` |
| **Persiana** (`shutter`, objeto; 5-2) | — (obstáculo de la Embestida) | — | «Cerrado por inventario»: suelo o pared de persiana metálica de 2-4 tiles. El golpe al suelo, el pulso y el láser **rebotan** (chispa gris); **solo una Embestida** la rompe para siempre (en el intento). | **Muro «Cargando más…»** del Mundo 2 |
| **Ranura de precios** (`price_rail`, objeto; 5-2) | — (obstáculo del Filo) | — | Hilera de etiquetas colgadas sobre un foso que deja **una ranura de 1 tile de alto**; tocar las etiquetas no daña, pero empuja hacia atrás (no se puede atravesar de pie). Se cruza con un **Filo**. | `small_frame` (ranura comprimida), empuje de la campana |
| **Estantería de saldos** (`clearance_shelf`, objeto; 5-2) | — (obstáculo del Sismo) | — | Columnas de cajas de saldo que bloquean el paso (grupo `group`); **un golpe las tumba, pero a los 0,5 s se «reponen»** si queda alguna del grupo en pie. **Solo un Sismo** tumba todo el grupo a la vez. | `clone_zone` (grupo), `fragile_card` |
| **«Prueba gratis»** (`free_trial_box`, objeto; 5-2) | Isak encuentra una oferta que dice gratis; contiene sus gestos; obtiene la Combinación | — | Caja grande con lazo en «Paquete completo»; **pulso de espaldas**: concede `combo`, la escena de historia (§4.2.2) y el aviso; un solo uso (`unless_ability`), vuelve tras un rollback sin el gesto. | **`DndSwitch`** / `PausePlayer` / `undo_prompt` |
| **Lista de deseos** (`wishlist_platform`, objeto; 5-3) | Plataformas con objetos que Isak nunca pidió; la tentación más fuerte | — | Plataforma de una vía con un objeto deseado encima y una **Oferta integrada** (radio 6, suma con las demás; §3.3, tope). El objeto **no se coge**: si Isak se queda 1,5 s sobre él, «Añadido al carrito» y una Suscripción. | `offer_sign` + plataforma de una vía |
| **Tachón** (`wish_strike`, objeto; secreto del 5-3) | Un tachón sobre un deseo que sí era de Isak; entrega un recuerdo | — | Línea de la lista tachada a mano, solo visible con el **Debug** (escrita por Isak, borrada por Eco); detrás, el `memory_pickup` `msg_5_3`. | `glitch_wall` `visible_only_with_debug` |
| **Caja registradora de Calc** (`calc_register`, objeto; 5-2) | Calc regenta la tienda oculta de atajos legítimos | — | Pantalla con el LCD de Calc; vende **un atajo sin trampa** (2 ◆) y lo dice tal cual: «Atajo: 2 ◆. Trampa: 0. Sin letra pequeña. Soy una calculadora, no un vendedor.» (**propuesto**). | `calc_actor` (estilo `lcd`), `shortcut_door` sin `trap` |
| **Puerta «Pagar»** (`exit_terminal`, `skin: "checkout"`) | Cierre de cada nivel; en el 5-3, «Pago realizado. Gracias por elegirnos.» | — | Terminal de salida con aspecto de caja de pago (pulso). El cartel del 5-3 dice además el saldo: «Saldo: {puntos} ◆». | `exit_terminal` (`skin`) |

Los tipos de los Mundos 1-4 **no aparecen** (cada mundo tiene su familia de formas, `07` §15.5). Los genéricos sí: cargador, punto de atención, power bank, vida extra, `memory_pickup`, pared con glitch, lector láser, receptor enlazado, `decor`, vórtices y pinchos. **Rejugar con la Combinación** los Mundos 1-4: el validador revisa con `abilities_available.combo` que no se trivialice ningún secreto (§7.1).

### 3.8 Lenguaje de combinaciones del Mundo 5 (amplía `propuesta-mundo-4.md` §3.8)

| Regla nueva | Consecuencia de diseño |
|---|---|
| Querer cuesta | Comprar ahorra tiempo o vida; no comprar ahorra puntos. Nada se paga para avanzar. |
| Lo que tienta pesa | Quedarse quieto cerca de una Oferta es moverse hacia ella; el dash y los combos son la salida. |
| El precio está dentro | Lo que esconde una caja o un atajo se ve con el Debug, que cuesta energía. |
| Dos gestos, una decisión | Embestida (romper y caer), Filo (cruzar y cortar), Sismo (todo a la vez). |

- **Patrón 23. Resistir:** Oferta de pie junto a un «carrito» con pinchos y una plataforma de una vía en lo alto: andar contra el tirón hasta la plataforma, o pulso y pasar tranquilo.
- **Patrón 24. Mirar o no:** tres cajas antes de un tramo largo sin cargador: abrir la de energía exige mirar (Debug) o arriesgarse con una Suscripción.
- **Patrón 25. Caer rompiendo:** persiana en el suelo de una banda con dos Suscripciones debajo: Embestida desde la banda de arriba.
- **Patrón 26. Ranura:** foso de 4 tiles con una ranura de precios a media altura: saltar, Pellizcar en el aire y Filo.
- **Patrón 27. A la vez:** tres estanterías de saldos repartidas por la planta en pantalla: un solo Sismo desde una repisa.
- **Patrón 28. Falsa urgencia:** cuenta regresiva sobre un foso con una Oferta al otro lado: cruzar con la cuenta o esperar a la siguiente, sin dejarse arrastrar.
- **Fórmula de ventana** (`propuesta-1-2.md` §0.1): ventana ≥ k × (recorrido + poses + 1,0 s por combo), con **k = 1,6 en dificultad 4 y k = 1,4 en dificultad 5**.

### 3.9 Anti-redundancia: lo que cada pieza nueva hace que nada más hace (lección de Agitar)

Agitar se retiró porque «hace lo mismo que el pulso». **Decisión tomada:** cada verbo nuevo entra con **un obstáculo que solo él resuelve** y **una prueba negativa** que lo demuestra (el validador falla el obstáculo sin ese verbo):

| Verbo nuevo | Obstáculo propio | Sin él… (negativo) | Lo que **no** debe sustituir |
|---|---|---|---|
| Embestida | Persiana (`shutter`) | Golpe, pulso y láser rebotan | El golpe al suelo normal sigue siendo el de las cajas y las Suscripciones |
| Filo | Ranura de precios (`price_rail`) sobre foso de 4 | Comprimido no salta el foso; de pie no cabe | El dash normal sigue siendo el de los fosos abiertos |
| Sismo | Estantería de saldos (`clearance_shelf`) en grupo | Cada golpe suelto se repone a los 0,5 s | El pulso sigue siendo lo que aturde **de uno en uno** a corta distancia |
| Tentación | — (es una amenaza, no un verbo) | — | No sustituye a ningún peligro: siempre lleva a uno |
| Gasto de puntos | — (opcional por regla) | El camino largo existe | No sustituye a ningún movimiento obligatorio |

---

## 4. Niveles, tramo a tramo

**Convención:** los tres niveles son **horizontales de 14 filas** (cámara del 1-1, que sigue a Isak) y se diseñan **por plantas desde el principio** (lección del Mundo 4, §11.1): cada tramo se recorre en **tres pasadas** (suelo en la fila 12, banda de una vía en la fila 9 y banda en la fila 6, con **3 filas entre ellas: sin atajos**, porque 192 px no se suben), y los tramos **alternan subir y bajar** como en el 4-2 (en los que suben, el suelo bajo la banda es llano; en los que bajan, las bandas no tienen huecos que sirvan de atajo). Temáticamente son las **plantas del centro comercial** y las **escaleras mecánicas** (decorado `decor`) que siempre están en el otro extremo. Filas desde arriba; columnas desde la izquierda. **Los mapas son orientativos**: las posiciones exactas las fija el validador en el paso de cada nivel.

**Duración (lecciones de los Mundos 3 y 4, decisión tomada §9.10):** el camino del validador y los bots deben quedar **entre el 40 y el 55 % del objetivo**.

| Mundo | Objetivos | Camino del validador | Bots | % del objetivo |
|---|---|---|---|---|
| 3 | 360 / 420 / 480 s | 67,5 / 83,8 / 124,6 s | 68,4 / 85,2 / 128,7 s | **19-27 %** (demasiado corto) |
| 4 | 420 / 480 / 480 s | 191,5 / 232,7 / 235,6 s | 180,6 / 204,3 / 197,2 s | **41-49 %** (tras rehacer en bandas) |
| **5 (propuesta)** | **480 / 540 / 600 s** | **~215 / ~250 / ~280 s** | 40-55 % | **45 / 46 / 47 %** |

**Presupuesto de camino** (nuevo, lección del Mundo 4: se calcula **antes** de dibujar): tiempo ≈ tiles recorridos / 3,4 + esperas obligatorias (cuentas, tirones, poses, Debug, combos). Cada nivel lo trae en su tabla y el validador lo compara en el paso del nivel; si sale por debajo del 40 %, se alarga con **otra pasada**, no con esperas vacías.

### 4.1 Nivel 5-1 «Oferta del día»

**Doc:** presentar la moneda, la tentación y las cajas sorpresa; unos 8 min; dificultad 4; tramos 1-4; secreto: sala de Devoluciones accesible con el Debug; un punto de sincronización a mitad.

- **Mapa: 200 × 14** (12 800 × 896 px). `target_duration_s` **480**; camino del validador de unos **200-230 s**. Dificultad `4`. `abilities_available`: pulso, láser, Debug, dash, golpe al suelo y Pellizcar (`combo`, **no**). La Linterna es conocida pero no hay zonas oscuras.

| Tramo | Columnas | Contenido | Pasadas | Presupuesto |
|---|---|---|---|---|
| Inicio «Entrada» | 0-19 | Vórtice (3, 11). Cartel «¡Bienvenido! Todo al 50 %». Eco (no importante, **propuesto**): «Aquí todo es para ti, {apodo}. Solo tienes que querer.». 1 punto. | 1 | 20 t · 8 s |
| Tramo 1 «Pasillo de ofertas» | 20-64 | **Primeras Ofertas** (doc): una de pie junto a un «carrito» con pinchos (patrón 23), dos colgadas que tiran hacia el borde de una banda (caída de 3 con salida). Q `offer_sign` («Cuanto más miras, más te acerca. Aléjate, o apágala con el pulso.», **propuesto**). Sube. 1 punto. | 3 | 135 t · 40 s + tirón 8 s |
| Tramo 2 «Primera tienda» | 65-104 | **Primera tienda** (doc): estantería con **+25 de Sync (3 ◆)** y **+40 de energía (2 ◆)**, a mitad de la banda del medio (se llega con 3-4 puntos cogidos en el nivel). Una Oferta enfrente de la tienda («Llévate dos»). `cargador_1`. Baja. 2 puntos. | 3 | 120 t · 35 s + compra 4 s |
| Pausa | 105-109 | **`sync_1`** (doc: a mitad). | — | — |
| Tramo 3 «Caja sorpresa» | 110-149 | **Primeras cajas** (doc): cuatro en la banda alta antes de una subida larga sin cargador (patrón 24): **energía**, **2 puntos**, **Suscripción** y **vacía**. Con el Debug se ve cuál es cuál; sin él, se arriesga. La primera Suscripción suelta del nivel (Q `subscription`). **Secreto A** (Devoluciones). Sube. 1 punto. | 3 | 120 t · 35 s + cajas 10 s |
| Tramo 4 «Atajo» | 150-189 | **Primer atajo con trampa** (doc): en la banda alta, una puerta «Atajo: 3 ◆ · ¡Ahórrate dos plantas!» que lleva directa al Cierre y **esconde una Suscripción** (doc). El camino largo baja las dos plantas y cruza la **primera cuenta regresiva** sobre un foso (patrón 28). `cargador_2`. **Secreto B**. Baja. 2 puntos. | 3 (1 con el atajo) | 120 t · 35 s + cuenta 6 s |
| Cierre «Caja de pago» | 190-199 | Terminal «Pagar» (`exit_terminal`, `skin: "checkout"`, pulso): «Total: 0 ◆. Gracias por mirar.» (**propuesto**), fundido y vuelta al hub. **Secreto C**. 1 punto. | 1 | 10 t · 5 s |
| **Total** | | | | **525 t ≈ 155 s + 63 s de esperas ≈ 215 s (45 %)** |

**Mapa de conjunto** (escala: 1 carácter = 4 columnas; 1 línea = 1 fila; Isak de pie ocupa las dos filas sobre su suelo):

```
col/4  0    5    10   15   20   25   30   35   40   45  49
fila0  ##################################################
  1    #                                                #
  2    #                       G?        ?            ? #   ? = A (Devoluciones), B, C
  3    #            o        $$          o   t          #   $ = tienda; t = cuenta regresiva
  4    #     O                     B B B B   D>>>>>>>>> #   O = Oferta; B = cajas; D = atajo
  5    #                                                #
  6    #   ----------  -----------  ----------- -------##   banda alta (fila 6)
  7    #                                                #
  8    #        O    o       O       s           O      #
  9    #  ------------  ---------- S ------------  ----##   banda del medio (fila 9)
 10    #                                                #
 11    # P   O ^^     C          o    o      C  t    E  #   ^ = carrito con pinchos; E = «Pagar»
 12    ##################################################   suelo (fila 12)
 13    ##################################################
       |Ini|  T1 ofertas (sube) | T2 tienda (baja) |S| T3 cajas (sube) | T4 atajo (baja) |Cie
```

**Detalle a escala 1:1 del Tramo 2 «Primera tienda»** (columnas 65-104; baja: entra por la banda alta a la izquierda y sale por el suelo a la derecha):

```
col    65        75        85        95       104
       0123456789012345678901234567890123456789
   5   ...                                         llega de T1 por la banda alta
   6   -----------------------------------  ###     banda alta; se recorre hacia la derecha
   7                           O                    Oferta colgada «Llévate dos» (col 92), tira hacia el borde
   8                                       |        caída a la banda del medio (col 100-101)
   9   ##  -------------$$---------------------     banda del medio hacia la izquierda; $$ = tienda (cols 81-82)
  10       |                                        pozo de 1 columna (col 67) al suelo
  11       o        C                    O  ^^      suelo hacia la derecha: cargador_1 (col 74), Oferta de pie + carrito (cols 98-101)
  12   ########################################
```

#### 4.1.1 Secretos y economía del 5-1

- **Secreto A «Devoluciones» (doc):** en el Tramo 3, una **pared con glitch** (`visible_only_with_debug`) en lo alto de la pared derecha del tramo, junto a las cajas; detrás, el mostrador **`refund_desk`** (§3.6: devuelve lo drenado y lo gastado en el atajo de este intento) con **2 puntos** y el **`memory_pickup` `msg_5_1`**. `forbid_abilities: ["dash"]` (que se busque con el Debug, no que se salte).
- **Secreto B «Oferta de verdad»:** en el Tramo 4, sobre la cuenta regresiva: si Isak **espera** al tercer ciclo sin cruzar, el cartel cambia a «Vale, esta vez es verdad» y la plataforma se queda **10 s**: da tiempo a un salto + dash aéreo a una repisa con el **power bank**. El tema en una mecánica: la urgencia falsa se vence esperando.
- **Secreto C «Vida extra»:** en el Cierre, una **Oferta colgada** sobre una repisa alta tira de Isak hacia un hueco de la pared (no hacia un peligro, la única «tentación buena» del nivel): dejándose llevar en el aire tras un salto se entra a la repisa con **`vida_extra_5_1`** (N = 3: la anterior fue la del 4-1). La quinta del juego.

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 1 | |
| Tramo 2 | 2 | |
| Tramo 3 | 1 | A: 2 + `msg_5_1` (+ devoluciones) |
| Tramo 4 | 2 | B: power bank |
| Cierre | 1 | C: vida extra |
| Cajas | 2 (caja de puntos) | |
| **Total** | **10** | **2 + mensaje + power bank + vida extra** |

- **12 puntos** (10 de ruta, contando la caja de 2, + 2 del secreto A). Comprar todo cuesta **8** (3 + 2 + 3 del atajo).
- **Cargadores:** 2 (+50, reutilizables, 10 s). **Power bank:** 1. **Puntos de sincronización:** 1.
- **Energía:** obligatoria ~20 (láser opcional a una Oferta aturdida); típica 50-80 (Debug en las cajas, en A y en la puerta del atajo).

### 4.2 Nivel 5-2 «Prueba gratis»

**Doc:** obtener la Combinación y enseñar a encadenar gestos; unos 9 min; dificultad 5; inicio en «Paquete completo»; Tramo 1 Embestida, Tramo 2 Filo, Tramo 3 Sismo, Tramo 4 Suscripciones pegadas mientras se resuelve un puzzle de combinaciones; secreto: tienda oculta con atajos legítimos, con el Debug.

- **Mapa: 220 × 14** (14 080 × 896 px). `target_duration_s` **540**; camino de unos **230-270 s**. Dificultad `5`. `abilities_available`: todo lo anterior; `combo` se obtiene en el inicio.

| Tramo | Columnas | Contenido | Pasadas | Presupuesto |
|---|---|---|---|---|
| Inicio «Paquete completo» | 0-24 | Vórtice (3, 11). Sala con cajas de regalo y el cartel «PRUEBA GRATIS · 30 días · Cancela cuando quieras*». **`free_trial_box`** (col. 12): pulso de espaldas → **momento de historia** (§4.2.2) y la Combinación. **La salida es una persiana en el suelo** (cols. 20-23) sobre la planta de abajo: **uso obligatorio de la Embestida a 8 tiles** de la obtención (el patrón del muro de texto del 4-2). 1 punto. | 1 | 25 t · 10 s + historia (pausa) |
| Tramo 1 «Embestida» | 25-70 | **Embestida** (doc): tres persianas en el suelo de las bandas con **Suscripciones y Ofertas de pie debajo** (patrón 25: «rompe una barrera y limpia a los enemigos de debajo»); la última, una persiana de pared en el suelo (de lado, se embiste desde el aire). Q `shutter` (**propuesto**: «Cerrado por inventario. Desde arriba y con todo: Deslizar y abajo.»). Baja. `cargador_1`. 1 punto. | 3 | 135 t · 40 s + 3 combos 6 s |
| Tramo 2 «Filo» | 71-115 | **Filo** (doc): tres ranuras de precios sobre fosos de 4 tiles (patrón 26), la última con dos Suscripciones flotando en la ranura (el Filo las atraviesa: «atraviesa a los enemigos pequeños»). Q `price_rail`. **Secreto B**. Sube. 1 punto. | 3 | 135 t · 40 s + 3 combos 6 s |
| Pausa | 116-120 | **`sync_1`**. `cargador_2`. | — | — |
| Tramo 3 «Sismo» | 121-165 | **Sismo** (doc): dos grupos de estanterías de saldos (3 y 4 columnas repartidas por la planta en pantalla; patrón 27) y una planta llena de Ofertas de pie que tiran hacia los bordes: un Sismo las aturde **a todas** a la vez («aturde a toda la pantalla»). Q `clearance_shelf`. **Secreto C**. Baja. 2 puntos. | 3 | 135 t · 40 s + 2 combos 4 s + tirón 6 s |
| Tramo 4 «Prueba terminada» | 166-210 | **Suscripciones + puzzle de combinaciones** (doc): dos Suscripciones salen de un cartel «Tu prueba gratis ha terminado» y persiguen a Isak por la planta mientras hay que hacer **persiana (Embestida) → ranura (Filo) → estanterías (Sismo)** en ese orden, sin cargador entre medias (cancelarlas o dejar que drenen: **decisión del jugador**). **Secreto A** (Calc). Sube. `cargador_3` al empezar. 1 punto. | 3 | 135 t · 40 s + 3 combos 6 s + Suscripciones 8 s |
| Cierre | 211-219 | Terminal «Pagar» (`checkout`): «Su prueba gratis se ha convertido en suscripción anual.» (**propuesto**) y vuelta al hub. 1 punto. | 1 | 10 t · 5 s |
| **Total** | | | | **575 t ≈ 170 s + 80 s ≈ 250 s (46 %)** |

**Mapa de conjunto** (1 carácter = 4 columnas):

```
col/4  0    5    10   15   20   25   30   35   40   45   50   55
fila0  ########################################################
  1    #                                                      #
  2    #                  ?                   ?            ?  #   ? = B (probador), C, A (Calc)
  3    #     ~G~                 ║║  ║║                 R     #   ~G~ = prueba gratis; ║ = ranura; R = registradora
  4    #   P  [G]  ===              o           K  K  K       #   K = estanterías de saldos
  5    #  #########                                           #
  6    #####HHHH-------HH----------  ---------- ---HH---------#   H = persiana (fila 6 y 9)
  7    #                                    O  O  O           #
  8    #       s s    O       ║║   ║║                s        #
  9    #   ------HH-----------  ----------S--------- ---------#   S = sync_1
 10    #                                K   K   K             #
 11    #       O  s    C    o           o         C    s    E #
 12    ########################################################
 13    ########################################################
       |Paquete| T1 Embestida (baja) | T2 Filo (sube) |S| T3 Sismo (baja) | T4 Prueba terminada (sube) |Cie
```

**Detalle a escala 1:1 de «Paquete completo»** (columnas 0-24, filas 0-13):

```
       0         1         2
       0123456789012345678901234
   0   #########################
   1   #                       #
   2   #  [PRUEBA GRATIS]      #   cartel (decorado)
   3   #       o               #
   4   #     ======            #   repisa de una vía (cols 6-11), 1 punto encima
   5   #                       #
   6   #  [regalo]   [regalo]  #   decorado: cajas de regalo vacías
   7   #                       #
   8   #           GG          #   GG = free_trial_box (cols 11-12, pulso de espaldas)
   9   #                       #
  10   #  P                    #   P = vórtice (col 3)
  11   #               ===     #   escalón (cols 15-17) para tomar altura: salto + dash aéreo + abajo
  12   ####################HHHH#   HHHH = persiana del suelo (cols 20-23): solo la Embestida la rompe
  13   ####################....#   debajo: el Tramo 1 empieza en la planta de abajo
```

#### 4.2.1 Secretos y economía del 5-2

- **Secreto A «Tienda de Calc» (doc: tienda oculta con atajos legítimos, con el Debug):** en el Tramo 4, una **pared con glitch** (`visible_only_with_debug`) da a un cuarto con la **`calc_register`**: vende **un atajo sin trampa (2 ◆)** que se salta la mitad del puzzle de combinaciones (sale a la banda alta tras la ranura), y en el mostrador están el **`memory_pickup` `msg_5_2`** y **1 punto**. Calc dice (LCD, no importante, **propuesto**): «Precio: 2. Trampa: 0. Eco llama a esto mal negocio.».
- **Secreto B «Probador»:** en el Tramo 2, una **ranura de precios** que no está en el camino lleva, con un **Filo**, a una cortina de probador (`small_frame` grande): dentro, el **power bank**. Pide el Filo (que el jugador acaba de aprender).
- **Secreto C «Saldo de saldos»:** en el Tramo 3, un tercer grupo de estanterías fuera del camino, **dos en pantalla y una justo fuera**: hay que colocarse para que entren las tres en la vista y hacer el Sismo; detrás, **2 puntos**.

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 1 | |
| Tramo 2 | 1 | B: power bank |
| Tramo 3 | 2 | C: 2 |
| Tramo 4 | 1 | A: 1 + `msg_5_2` |
| Cierre | 1 | |
| Cajas | 2 (una caja de puntos en el Tramo 1, bajo una persiana) | |
| **Total** | **9** | **3 + mensaje + power bank** |

- **12 puntos.** Comprar todo cuesta **2** (el atajo de Calc): en el 5-2 la tentación es el tiempo (las Suscripciones del Tramo 4), no la tienda.
- **Cargadores:** 3. **Power bank:** 1. **Vida extra:** no. **Puntos de sincronización:** 1.
- **Energía:** obligatoria ~180 en el nivel (12 combos obligatorios × 15: 1 en «Paquete completo», 3 + 3 + 2 en los tramos 1-3 y 3 en el 4), repartida con un cargador a pie de cada tramo (`cargador_3` al **empezar** el Tramo 4) para que la energía nunca baje de 25 en el camino (lo comprueba el validador); típica 220-260.

#### 4.2.2 Momento de historia: «Paquete completo» (PROPUESTA; textos «propuesto» salvo los del doc)

Pausa de principio a fin, como el encuentro con Eco del 1-1 y la Papelera del 4-2:

1. **Cartel de la caja** (texto del sistema): «Prueba gratis: todo lo que necesitas, ya elegido para ti.» (**propuesto**)
2. Isak pulsa la caja: dentro no hay nada nuevo: **sus tres gestos** (iconos de Deslizar, Mantener y Pellizcar) que se juntan por pares. Combinación obtenida.
3. **Eco** (importante): **«Todo tiene un precio.»** (doc)
4. **Isak** (importante, interlocutor nuevo `isak`): **«Esto no lo compré. Es mío.»** (doc)
5. Aviso de control de la Combinación (§3.2.1).
6. **Eco** (no importante, ya sin pausa): «Una prueba gratis siempre acaba, {apodo}.» (**propuesto**; anticipa el Tramo 4).

Un solo uso por partida guardada (`seen_notices` `combo_5_2`, sin subir la versión del guardado). Con `combo` ya obtenido (rollback guardado, rejugar), la caja arranca abierta e inerte.

### 4.3 Nivel 5-3 «Última oportunidad»

**Doc:** reunir todo y enfrentar la tentación al máximo; unos 10 min; dificultad 5; el tramo final sobre una lista de deseos con el tirón más fuerte; Tramo 1 cuentas regresivas encadenadas con Ofertas (moverse con los combos); Tramo 2 cajas sorpresa en cadena (no se puede pagar el Debug en todas); Tramo 3 suscripciones, atajos y tentación a la vez; cierre con la puerta «Pago realizado. Gracias por elegirnos.»; secreto: un tachón sobre un deseo que sí era de Isak, con un recuerdo.

- **Mapa: 250 × 14** (16 000 × 896 px). `target_duration_s` **600**; camino de unos **260-300 s**. Dificultad `5`. Todo el kit, con la Combinación.

| Tramo | Columnas | Contenido | Pasadas | Presupuesto |
|---|---|---|---|---|
| Inicio «Rebajas finales» | 0-19 | Vórtice, cartel «¡ÚLTIMA OPORTUNIDAD! (hasta mañana)». 1 punto. | 1 | 20 t · 8 s |
| Tramo 1 «Solo por hoy» | 20-69 | **Cuentas regresivas encadenadas** (doc): cuatro plataformas con cuentas desfasadas sobre fosos, con Ofertas al otro lado que tiran hacia el borde (patrón 28); la segunda pasada se hace mejor con **Filo** entre dos cuentas y la tercera con una **Embestida** que cae sobre la cuenta siguiente («moverse con los combos»). Sube. `cargador_1`. 2 puntos. | 3 | 150 t · 44 s + cuentas 12 s |
| Tramo 2 «Cajas en cadena» | 70-119 | **Cajas sorpresa en cadena** (doc): **ocho** cajas en tres grupos, **sin cargador** en el tramo y con **energía para mirar solo tres** (Debug); las que tapan el camino deben abrirse y una de cada grupo da energía. **Siempre hay un orden seguro** (el validador lo busca): «hay que elegir cuáles» (doc). Baja. 2 puntos (en cajas). | 3 | 150 t · 44 s + cajas 15 s |
| Pausa | 120-124 | **`sync_1`**. `cargador_2`. | — | — |
| Tramo 3 «Todo a la vez» | 125-189 | **Examen final** (doc): Suscripciones que salen de un **atajo con trampa `processing`**, una puerta de **Términos y condiciones** (Aceptar = Suscripción; rechazar = láser desde enfrente o un Filo), Ofertas en las tres plantas y un grupo de estanterías de saldos que solo cae con un Sismo hecho **contra el tirón** (las Ofertas empujan fuera de la repisa). Una **tienda** (+25 de Sync = 3 ◆, +40 de energía = 2 ◆) antes del examen. **Secreto B**. Sube. `cargador_3`. 2 puntos. | 3 | 195 t · 57 s + 15 s |
| Pausa | 190-194 | **`sync_2`**. | — | — |
| Tramo 4 «Lista de deseos» | 195-239 | **La lista de deseos** (doc): plataformas `wishlist_platform` con los objetos que Isak nunca quiso, **tirón al tope** (deriva 90 px/s, ×0,45 al alejarse) sobre un foso con salida a una planta baja con pinchos (−10 y vuelta a subir por una escalera mecánica). Se cruza con dash y combos sin pararse 1,5 s sobre ningún deseo. **Secreto A** (el tachón). Recto (la lista se lee de un tirón). 2 puntos. | 1 | 45 t · 13 s + 10 s |
| Cierre «Pago realizado» | 240-249 | Puerta (`checkout`) con el cartel gigante **«Pago realizado. Gracias por elegirnos.»** (doc) y debajo «Saldo: {puntos} ◆». Eco (no importante, **propuesto**): «¿Ves? Ya no tienes que elegir nada.». Vuelta al hub; desbloquea la fila del jefe. 1 punto. | 1 | 10 t · 5 s |
| **Total** | | | | **620 t ≈ 182 s + 85 s ≈ 270 s (45 %)** |

**Mapa de conjunto** (1 carácter = 4 columnas):

```
col/4  0    5    10   15   20   25   30   35   40   45   50   55   60  62
fila0  ###############################################################
  1    #                                                             #
  2    #                              ?                    ✕?        #   ✕? = A (tachón); ? = B
  3    #        t  t    t   t       D          [T&C]     ≈ ≈ ≈ ≈     #   ≈ = lista de deseos (fila 3-4)
  4    #      O             O    BB      O   K   K   K    ≈ ≈ ≈     E#   T&C = términos y condiciones
  5    #                                                             #
  6    #   ----------------  -------------  ---------------          #
  7    #           O               s      O      s                   #
  8    #       t     t    BBB     B                 O                #
  9    #  --------------------   S----------------- -S------         #   S = sync_1, sync_2
 10    #                                                  ^^^^^^^^   #   planta baja de la lista: pinchos con salida
 11    # P   O    C    BB  B        C   o     D     C   escalera   o #
 12    ###############################################################
 13    ###############################################################
       |Ini| T1 Solo por hoy (sube) | T2 cajas (baja) |S| T3 todo (sube) |S| T4 lista |Cie
```

**Detalle a escala 1:1 de la lista de deseos** (columnas 205-234; Isak va de izquierda a derecha por la fila 4; abajo, la planta de los pinchos):

```
col    205       215       225       234
       012345678901234567890123456789
   2                       ✕            tachón (col 228, solo con el Debug): «arreglar la radio del Abuelito»
   3     [reloj]   [curso]    [cascos]   objetos deseados (decorado) que tiran de Isak
   4   ====    ===     ====     ====     wishlist_platform: huecos de 3-4 tiles (dash / Filo / Embestida)
   5
   6
   7
   8
   9
  10   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^    pinchos de la planta baja (−10) con salida
  11                                 ⇗   escalera mecánica de vuelta a la fila 4
  12   ##############################
```

#### 4.3.1 Secretos y economía del 5-3

- **Secreto A «Tachón» (doc):** en la lista de deseos, una línea tachada solo visible con el **Debug** (`wish_strike`): «arreglar la radio del Abuelito» (**propuesto**; enlaza con el recuerdo del jefe, las radios del barrio). Hay que **pararse** sobre la plataforma de al lado (con la tentación al tope) para encender el Debug: el secreto es **resistir quieto**. Detrás, el **`memory_pickup` `msg_5_3`** y **1 punto**. `forbid_abilities: ["dash"]`.
- **Secreto B «Trastienda»:** en el Tramo 3, el atajo con trampa tiene **una puerta trasera** que solo se ve con la **Linterna**: un almacén a oscuras (`dark_zone` + `ink_only`, la única zona oscura del mundo) con el **power bank**. Reutiliza la Linterna del Mundo 4 para que no quede sin uso.
- **Secreto C:** **1 punto** en la última caja del Tramo 2, que solo se abre con energía de sobra (si se miró de más, no queda): el dilema del Debug como recompensa.

| Dónde | Ruta | Secretos |
|---|---|---|
| Inicio | 1 | |
| Tramo 1 | 2 | |
| Tramo 2 | 2 (en cajas) | C: 1 |
| Tramo 3 | 2 | B: power bank |
| Tramo 4 | 2 | A: 1 + `msg_5_3` |
| Cierre | 1 | |
| **Total** | **10** | **2 + mensaje + power bank** |

- **12 puntos.** **Mundo 5: 36 puntos** (12 + 12 + 12). Con los Mundos 1-4, unos **144** al terminar el Mundo 5 en Caché **si no se gasta nada**; comprarlo todo en el mundo cuesta unos **18** (8 + 2 + 8).
- **Cargadores:** 3 (ninguno en el Tramo 2). **Power banks:** 1 (el Mundo 5 suma 3). **Puntos de sincronización:** 2.
- **Energía:** obligatoria ~80 (combos de los tramos 1 y 3 y las cajas que tapan el camino); típica 120-170.

### 4.4 Duración, dificultad y progresión

| Nivel | Mapa | Dificultad | Camino (validador) | Objetivo | Enseña | Combina con |
|---|---|---|---|---|---|---|
| 5-1 | 200 × 14 | 4 | ~215 s | 480 s | Gastar puntos, tentación, cajas, Suscripción, atajo con trampa, cuenta regresiva | Pulso, láser, Debug, dash, golpe al suelo, Pellizcar |
| 5-2 | 220 × 14 | 5 | ~250 s | 540 s | Combinación: Embestida, Filo y Sismo; persianas, ranuras, estanterías | Todo lo anterior |
| 5-3 | 250 × 14 | 5 | ~270 s | 600 s | Cuentas encadenadas, cajas en cadena, Términos y condiciones, lista de deseos | Todo el kit (y la Linterna en un secreto) |
| Jefe | 20 × 11 | 5 | ~110-160 s (bot) | 240 s | Llegar a la espalda, fichas, cajas que se abren o se aturden, oferta con cuenta | Todo el kit |

**Curva:** el 5-1 vuelve a dificultad 4 porque cambia **lo que se decide** (gastar, mirar, resistir), no lo que se ejecuta; el 5-2 sube por la ejecución (combos), y el 5-3 junta las dos cosas con menos energía.

**Qué prepara cada nivel para el jefe:** Ofertas y tirón (5-1, 5-3) → fase 3; cajas y su lectura con el Debug (5-1, 5-3) → fase 2; atajos con precio y trampa (5-1) → fase 1; Embestida y Filo (5-2) → la espalda en la fase 3.

### 4.5 Mensajes recuperables `msg_5_x` (borradores de tono; PROPUESTA)

**Remitente: decisión del usuario (§10.2); recomendación por defecto, el Abuelito** (vive con Isak y le enseñó a soldar, `04` §12.5; el recuerdo del jefe es él: «Tú la abres, tú la cierras»). Tono cálido, cotidiano, con humor; siguen el hilo del recuerdo (las radios, el letrero «Se arreglan cosas») **sin contarlo**. En `data/memories.json` con `level`, `secret` y `first_lap: 1`; reaparecen en Kernel y Raíz si no se obtienen; ≤ 280 caracteres; solo glifos de la fuente.

| Id | Nivel · secreto | Remitente · asunto | Idea del texto (borrador, **propuesto**) |
|---|---|---|---|
| `msg_5_1` | 5-1 · `secreto_devoluciones` | Abuelito · «Devolución» | «Isak, la tienda quiso cambiarme la radio rota por una nueva. Les dije que no, que esta tiene arreglo. Me miraron raro. Tú sí me habrías entendido. — Abuelito» |
| `msg_5_2` | 5-2 · `secreto_tienda_calc` | Abuelito · «Herramientas» | «Encontré tu soldador debajo del sofá. No lo guardo: lo dejo en la mesa, por si vuelves con ganas. Las ganas no se compran, se encienden. — Abuelito» |
| `msg_5_3` | 5-3 · `secreto_tachon` | Abuelito · «El letrero» | «La vecina preguntó si sigue abierto lo de "Se arreglan cosas". Le dije que el encargado está de vacaciones, pero que vuelve. ¿Vuelve? — Abuelito» |

### 4.6 Hub y progresión

- **`data/hub.json`, mundo `m5`** (hoy `levels: []`): filas `5-1 «Oferta del día»`, `5-2 «Prueba gratis»`, `5-3 «Última oportunidad»` y `{"id": "5-boss", "name": "El Vendedor", "kind": "boss"}`, todas con `laps: [1]` y `playable: false` («Próximamente») hasta que existan; desbloqueo en cadena (`unlocks`); el 5-2 y el 5-3 con `available_text` **«Nueva oferta»** (propuesto, como «Nuevo mensaje» del Mundo 4). Iconos `menu_level_5_*` por script.
- **Carpeta M5** (página 2, columna 14, ya existe): se añade la **miniatura** (`world_icon_m5`: una etiqueta de precio con el rombo de los puntos).
- **Calc** (comentario de llegada `calc.remarks`, tras el 5-1; no importante): «Has gastado {gastado} ◆ en una tienda que no es la mía. No me ofendo. Lo apunto.» (**propuesto**; si no gastó nada: «Gastado fuera: 0. Bien.»).
- **Al vencer a El Vendedor:** **quinta pieza del fondo** (pasa de `off` a `on`, en el color del Debug del Mundo 5, §6.1) y, como es la última, **el fondo queda completo**: un destello recorre las cinco piezas y la foto se ve entera (`05` §13.4: «la foto que Isak tenía antes de entrar al celular»; sin texto nuevo en Caché: la foto habla sola). Placa «!» en Notas, **quinta ranura del candado de La Nube** encendida (`boss_w5_l1`; **el candado se abre**: animación de apertura en la página 3) y **Mundo 6 «La Nube» disponible** («Próximamente»; `m6.unlocked_by: ["5-boss"]`, ya en datos).

---

## 5. Jefe del Mundo 5: El Vendedor

### 5.1 Concepto y tono

- **Decidido:** «una máquina expendedora gigante con brazos mecánicos y una sonrisa de neón. Ofrece todo y cobra todo. Eco habla a través de ella con una voz amable y paciente». Arena: una tienda enorme con estantes, carteles de oferta y cajas flotando. Punto débil: un botón de «Cancelar» escondido en la parte trasera, solo con el Debug, en rojo. Fases: (1) plataformas con precio, algunas trampas, el Debug marca cuáles; (2) cajas sorpresa como proyectiles, unas dan y otras explotan, decidir cuáles abrir y cuáles aturdir; (3) oferta por tiempo limitado: la tentación arrastra al centro, resistir con combos y llegar al botón de Cancelar antes de que termine la cuenta. Recompensa: «Fragmento de voluntad»; Eco: «Yo decido por ti, así no te equivocas.».
- **Decisión tomada: El Vendedor siempre te atiende de frente.** Se gira hacia Isak **1,2 s del mundo** después de que Isak cambie de lado (aviso: sus brazos se recogen y la sonrisa parpadea 9 cuadros antes de girar). El «Cancelar» está siempre **en la espalda**: **cada fase es una forma de quedarse detrás el tiempo suficiente.** *Razón:* convierte «en la parte trasera» en la regla de la pelea y da a cada fase su llave (pagar, abrir, combinar).
- **Tono (PROPUESTA; textos «propuesto»):** amable, paciente, nunca enfadado; siempre ofrece algo. Líneas: **intro** (pausa), **cambios de fase** (sin pausa), **derrota** (pausa, tras la recompensa). Borradores: intro, «Bienvenido, {apodo}. Ya sé lo que vas a llevar.»; fase 2, «¿Una sorpresa? Todas son para ti.»; fase 3, «Oferta por tiempo limitado. Solo tienes que no hacer nada.».
- **Sin rollback** (solo el jefe final).

### 5.2 Arena «Gran almacén» (20 × 11 tiles)

- **1280 × 704 px:** cabe entera en pantalla, **cámara fija** (como los jefes de los Mundos 2-4). Muros en las columnas 0 y 19, techo en la fila 0, suelo en la 10.
- **El Vendedor:** máquina de **4 × 5 tiles** (columnas 8-11, filas 5-9), **sólida**; brazos que salen por los lados (alcance 3 tiles, no sólidos); la **bandeja de salida** al frente (fila 9). El «Cancelar» (`WeakPoint`), en la espalda, a la altura de la fila 7 (a tiro de pulso desde el suelo pegado a la máquina).
- **Estantes fijos** de una vía en la fila 8 (columnas 2-5 y 14-17): un escalón de 2 desde el suelo.
- **Fase 1:** cuatro **plataformas con precio** (`priced_platform`) en la fila 6 (columnas 6-7 y 12-13), de 2 tiles, que aparecen al pagarlas con un pulso a su etiqueta desde el estante; desde ellas se sube al **techo de la máquina** (fila 5) y se baja por detrás.
- **Fase 3:** un **escaparate** (persiana, `shutter`) cubre el techo de la máquina (solo una **Embestida** lo rompe, y se repone en cada cuenta) y la **ranura de monedas** (1 tile de alto, fila 7) atraviesa la máquina de lado a lado: 4 tiles = **un Filo exacto**.
- **Fichas («Saldo de regalo»):** la máquina regala **12 fichas** al empezar (contador en la barra del jefe, sin tocar los puntos de atención); cada plataforma cuesta **2**; las cajas buenas de la fase 2 dan **+2**. **Con 0 fichas, la máquina «te fía»:** la plataforma aparece igual y se engancha una Suscripción de la arena (drena **2 de energía/s** hasta cancelarla). *Razón:* sin atascos y con el tema intacto (la deuda).
- **Cargadores:** 4 en el suelo, columnas 2, 6, 13 y 17: +50, enfriamiento 4 / 5 / 6 s (Caché / Kernel / Raíz).
- **Debug en la arena:** `debug_drain_scale` **0,25** y `debug_world_scale` **0,7** (los de los otros jefes; los recalcula el validador de arenas).
- Vórtice de llegada en (3, 9). Sin puntos de atención, power banks ni vida extra.

```
      0         1
      01234567890123456789
   0  ####################   techo
   1  #                  #
   2  #  [OFERTA]   [%]  #   carteles (decorado)
   3  #                  #
   4  #       ^__^       #   sonrisa de neón (sobre la máquina, no sólida)
   5  #       ####       #   techo de la máquina (fila 5); fase 3: escaparate (persiana)
   6  #     ==####==     #   plataformas con precio (cols 6-7 y 12-13, fase 1)
   7  #       ====X      #   ==== = ranura de monedas (fila 7, fase 3) · X = «Cancelar» en la espalda (rojo con el Debug)
   8  # ====  ####  ==== #   estantes de una vía (cols 2-5 y 14-17) · máquina sólida (cols 8-11, filas 5-9)
   9  # CP  C #__# C   C #   C = cargadores (2, 6, 13, 17) · P = vórtice (3) · __ = bandeja de salida al frente
  10  ####################   suelo
```

### 5.3 Punto débil y daño: la marca «Cancelar» (decisión tomada)

La regla de Alerta Mayor, la Curadora y El Visto (V14): **Debug → pulso que marca → láser**.

1. **Oculto:** sin el Debug, el «Cancelar» no se ve; el láser rebota en la carcasa (chispa gris) y el pulso no hace nada.
2. **Revelado:** con el Debug activo y **Isak detrás**, el **«Cancelar»** se ve en **rojo pulsante** (`WeakPoint`, por encima del tinte blanco, con contorno negro de 1 px).
3. **Marcado:** un **pulso** que lo alcanza con el Debug activo lo marca `mark_duration_s` (**Caché 4 s, Kernel 3 s, Raíz 2,5 s**). Con la marca, **un láser** es **un golpe** (2 con el Láser 4) **sin necesidad del Debug**, y la marca termina (**un golpe por marca**).
4. **La marca no cae al girarse** (el láser se dispara a la espalda aunque ya esté girando: la marca es del botón). Se pierde al caducar, al cambiar de fase, en el golpe final y al reaparecer.
- **Nada más hace daño:** ni el dash, ni el golpe al suelo, ni los combos, ni Pellizcar.
- **Contador:** **9 golpes en Caché (3 por fase)**; **12 en Kernel y Raíz (4 por fase)**. `BossBar` con el estilo **«ticket»**: un ticket de compra que se va tachando línea a línea, con las fichas al lado.

### 5.4 Fase 1 «Plataformas con precio» (doc: plataformas con precio; algunas son trampas; el Debug marca cuáles)

| Ataque / pieza | Aviso | Respuesta | Reutiliza |
|---|---|---|---|
| **Plataformas con precio:** 4 etiquetas en la fila 6; **una de cada par es trampa** (se pliega 0,3 s después de pisarla y deja caer a la **bandeja**: −10 y empuje al frente) | **Con el Debug**, la etiqueta trampa lleva el icono de la trampa (blanco con contorno negro); sin él, no | Pagar la buena (2 fichas), subir, cruzar el techo de la máquina y bajar por detrás → la máquina tarda 1,2 s en girar | `shop_item` (pago), `reminder_platform` (se pliega), revelado del Debug |
| **Brazo que barre:** un brazo barre un estante (fila 8) | Brazo que se recoge 9 cuadros, sombra en el estante | Saltar o bajar del estante | Barrido del banner |
| **Monedas que caen:** 3 monedas en columnas | Sombra en el suelo 9 cuadros | Salir de la columna | Onda de `AlarmBell` con otra forma |

**Ventana:** los **1,2 s del mundo** entre bajar detrás y que se gire (unos 1,7 s reales con el Debug a ×0,7). Como en la fase 1 de El Visto, hay que **encender el Debug antes** (sobre el techo de la máquina, donde nada ataca 1 s) para que dé tiempo a pulso + láser. 3 golpes.

### 5.5 Fase 2 «Sorpresa» (doc: lanza cajas sorpresa; unas dan puntos y otras explotan; decidir cuáles abrir y cuáles aturdir)

- **Lanza cajas** en arco (tandas de 3 cada 5 s) que caen al suelo y a los estantes. Contenido fijo por tanda (en los datos, no aleatorio): **buena** (+2 fichas o +20 de energía), **bomba** (explota a los 2,5 s de caer: radio 1,5 tiles, −10, mecha que chisporrotea desde que cae: el aviso) y, una por tanda, el **«ticket de devolución»**.
- **Abrir** = golpe al suelo encima (o pulso de cara): la buena da su contenido; la bomba explota al momento (no se abre una bomba). **Aturdir** = pulso a una bomba: queda **inerte 3 s y sirve de escalón** (la regla del juego).
- **Con el Debug** se ve qué es cada caja (§3.4): el dilema de siempre, con la energía de la arena.
- **La llave:** abrir el **ticket de devolución** deja a la máquina **«Procesando devolución…» 4 s del mundo**: **no se gira**. Se llega a la espalda **por el suelo** si la bandeja está libre o **por encima** apilando dos bombas aturdidas junto a la máquina (escalones de 1 + salto). Detrás: Debug → pulso → láser. 3 golpes.
- **Entre medias:** el brazo sigue barriendo los estantes.

### 5.6 Fase 3 «Oferta por tiempo limitado» (doc: la tentación arrastra al centro; resistir con combos y llegar a Cancelar antes de que termine la cuenta)

- **El cartel «¡SOLO POR HOY!»** baja sobre la máquina con una **cuenta de 15 s del mundo** (Caché; 12 Kernel, 10 Raíz), visible y con `sfx_w5_countdown` en cada segundo (accesibilidad).
- **Tentación al tope** hacia la **bandeja** (el centro): deriva 90 px/s, ×0,45 al alejarse (§3.3). Tocar la bandeja = **«Compra realizada»** (abajo).
- **Dos caminos a la espalda (los combos, doc):** **Embestida** desde un estante sobre el **escaparate** del techo de la máquina (lo rompe; se baja por detrás) o **Filo** por la **ranura de monedas** (salto desde el estante, Pellizcar en el aire, Filo: sale justo por detrás). Durante la fase **la máquina no se gira** (está «ocupada vendiendo»). Detrás: Debug → pulso → láser **contra el tirón** (que tira hacia el frente, por encima de la máquina: detrás, la deriva es hacia la máquina, no hacia la bandeja: se puede estar quieto pegado a ella).
- **Si la cuenta llega a 0 o Isak toca la bandeja:** «Procesando pago…»: **congelado 2,0 s y golpe al liberarse** (el `FrozenState` del Mundo 4 con su regla: nada ataca a Isak congelado) y la cuenta vuelve a empezar con el escaparate repuesto.
- **Entre medias:** dos Ofertas de pie en los estantes suman su tirón (aturdirlas con el pulso lo baja); monedas que caen.
- **Golpe final:** el tercero; la sonrisa de neón **se apaga letra a letra**, la máquina devuelve todas las fichas en una lluvia sin valor y **se desarma en píxeles** (`BossDefeat`, `PixelBurst`). 3 golpes.

### 5.7 Energía (estimación; la valida `tools/validate_boss.py`)

Mismos supuestos que El Visto (pelea torpe: 3 s de Debug por ventana, un láser fallado por ventana y una ventana perdida por fase). Diferencia: la fase 3 gasta **un combo** (15) por ventana y las cajas buenas devuelven energía.

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Golpes (láseres mínimos) | 9 (90) | 12 (120) | 12 (120) |
| Combos mínimos (fase 3) | 3 (45) | 4 (60) | 4 (60) |
| Marca (`mark_duration_s`) | 4 s | 3 s | 2,5 s |
| Cuenta de la fase 3 | 15 s | 12 s | 10 s |
| Debug en la arena | ×0,25 (5/s), mundo ×0,7 | igual | igual |
| Cargadores | 4 de 4 s | 4 de 5 s | 4 de 6 s |
| Pico torpe estimado por ventana (margen sobre 100) | ~60 (≥ 30) | ~70 (≥ 25) | ~78 (≥ 20) |

**Palancas, solo en datos y por este orden:** `mark_duration_s`, tiempo de giro, duración de la cuenta, enfriamiento de los cargadores, coste del combo en la arena (`combo_cost_scale`) y `debug_drain_scale`. Las mejoras de Calc ayudan pero nunca son requisito.

### 5.8 Kernel y Raíz (PROPUESTA a alto nivel; se cierran al hacer esas vueltas)

Decidido: «los puntos débiles cambian en cada vuelta».

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Fase 1 | Una trampa por par; gira en 1,2 s | Las dos etiquetas de un par **cambian** al pagar (el Debug lo dice tarde: hay que mirar justo antes) | Gira en 0,9 s; el «Cancelar» cambia de altura cada ventana |
| Fase 2 | Un ticket por tanda | El ticket va **dentro de una bomba** (Debug: abrirla no, aturdirla y abrirla con un Filo) | Las bombas aturdidas explotan al terminar el aturdido si están juntas |
| Fase 3 | Escaparate o ranura | Solo la ranura (el escaparate no se rompe) | La ranura se **mueve** (dos alturas) y la cuenta es de 10 s |
| Ocultarte (Kernel+) | — | El Vendedor **te busca**: oculto, se gira de espaldas a Isak (idea de `propuesta-mejoras.md` §4) | Igual; **nunca es requisito** |

### 5.9 Recompensa, vidas y vuelta al hub

1. **Golpe final** → desarme → **`BossReward.grant(5, vuelta)`** (ya existe): entrega `boss_w5_l1` en Caché **sin guardar** (más las capas inferiores que falten). Panel «Recuerdo recuperado», título «Fragmento de voluntad», «Capa: Caché», texto (ya en datos: la caja de radios, el letrero «Se arreglan cosas», el pulgar con estaño; «Eco: «Yo decido por ti, así no te equivocas».») y «Guarda en Notas para conservarlo.». La ilustración `memory_art_w5` (borrosa en Caché) sale en Notas. Sin código nuevo.
2. **Eco** (línea de derrota, importante, **propuesto**): «Te lo dejé todo elegido. Y aun así eliges.».
3. **Hub:** quinta pieza (fondo completo), quinta ranura y candado abierto, Mundo 6 disponible, placa «!» en Notas (§4.6).
4. **Vidas y rollback (reglas vigentes, sin cambios):** 3 vidas por intento, se reponen al entrar desde la carpeta; **morir** reaparece al principio de la fase con energía ≥ 50 y **las fichas de esa fase** (las que tenía al empezarla); **game over** = `GameState.apply_rollback`: vuelta a la última copia guardada (lo no guardado se pierde, también la victoria, la capa del recuerdo, **los puntos gastados en los niveles** y la Combinación sin guardar), lo guardado a la **Papelera**, carpetas bloqueadas hasta recuperarlo. «Prueba gratis» vuelve a ofrecer la Combinación tras un rollback sin ella. **R:** reinicia la pelea. **Sin rollback de jefe** (solo el jefe final).

### 5.10 Ayuda con Q (tipos nuevos del jefe, `world: 5`; textos «propuesto»)

| Tipo | Idea del texto |
|---|---|
| `vendor_boss` | «Siempre te mira de frente. El botón de Cancelar está detrás. Con el Debug se ve: márcalo con el pulso y dispárale.» |
| `priced_platform` (Objeto) | «Se paga con fichas. Una de cada dos se dobla. El Debug sabe cuál.» |
| `vendor_ticket` (Objeto) | «Una devolución. Mientras la procesa, no se da la vuelta.» |
| `vendor_offer` (Objeto) | «No hagas nada y comprarás. Rompe el escaparate desde arriba o cuélate por la ranura.» |

---

## 6. Arte y sonido

### 6.1 Paleta del Mundo 5

- **Decidido:** negro con neones, **amarillo chillón** de rebajas, carteles de precio, **Debug blanco** (`mundo-5` §10.1, `07` §15.3, `CLAUDE.md`: «5 blanco»); unos 16 colores más el del Debug en `assets/palettes/mundo5.gpl` (`07` §15.2).
- **Hex:** cierre del usuario (`CLAUDE.md`, decisión abierta). Como en los Mundos 3 y 4: hex provisionales por script en el paso 0 y **3 variantes completas con maqueta** en el paso 9 (`tools/palette_mundo5_variants.py`). **El blanco se decide antes** porque ya se ve en el hub (quinta pieza; `debug_colors["5"]` es hoy `#f4f4f4` provisional) y la pieza 5 de `05` §13.4 es «en blanco».
- **Lo que de verdad hay que vigilar con un Debug blanco** (medido con ΔE76 en Lab, como en el Mundo 4): frente al **rojo de daño** (`alerta` `#ff4a2a`) y los otros colores reservados, **cualquier blanco está lejísimos** (ΔE ≥ 89): esa regla se cumple sola. Los riesgos son otros: (1) el **texto del HUD** (`banner_blanco` `#f2f4f8`) es casi el mismo color; (2) el **amarillo chillón** contrasta poco con el blanco (≈ 1,1-1,3:1), así que lo que el Debug revela encima de un cartel amarillo no se leería; (3) un tinte blanco **lava la pantalla**: el Debug del Mundo 5 **apaga los neones** (y eso es justo el tema: el Debug quita el color a la publicidad).
- **Opciones de blanco para el usuario** (ΔE76 frente a `alerta`, `ambar` `#ffa000` de los puntos, `carmin` `#e0004a`, el amarillo de rebajas propuesto `#ffe600`, el cian de Isak `#29defa` y el texto del HUD `#f2f4f8`; contraste sobre un negro de referencia `#0e0c14`):

| Opción | Hex | ΔE rojo | ΔE ámbar | ΔE amarillo | ΔE cian | ΔE texto HUD | Contraste sobre negro | Lectura |
|---|---|---|---|---|---|---|---|---|
| **A «Blanco puro»** (RECOMENDADA) | `#ffffff` | 97 | 87 | 91 | 46 | **4** | **19,4:1** | Lo que dice el doc, literal. El más brillante: el que más destaca «sobre tanto color». Casi igual que el texto del HUD, pero el HUD es otra capa con su panel y el Debug se ve como tinte y contorno, no como texto. |
| **B «Blanco tiza»** | `#e8f0ff` | 100 | 93 | 99 | 40 | 8 | 17,0:1 | Un blanco algo frío: se separa un poco del texto del HUD y del amarillo; parece «luz de fluorescente de almacén». |
| **C «Plata neón»** | `#d6e4ff` | 102 | 98 | 105 | **37** | **16** | 15,2:1 | La que más se separa del texto del HUD, pero ya no es «blanco puro» y se acerca al cian de Isak y al azul del Mundo 1. |

- **Reglas que toda variante debe cumplir** (las comprueba `--check`):
  1. **Blanco frente al rojo de daño** y al punto débil: ΔE ≥ 30, también con el tinte del Debug (se cumple de sobra; se deja la regla para que nadie lo rompa).
  2. **Lo que el Debug revela lleva contorno negro de 1 px** (cajas translúcidas, iconos de trampa, el «Cancelar» y la pared con glitch): contraste ≥ 3:1 sobre el amarillo y sobre el blanco del tinte.
  3. **Ningún color de la paleta del mundo por encima de L\* 92 salvo el Debug** (los carteles «blancos» son crema o gris claro): el blanco queda reservado al Debug.
  4. **Sin rojos ni naranjas en los carteles:** el precio tachado va en **magenta** (`#ff3df0`, ΔE 108 con el rojo de daño; un naranja de rebajas como `#ff6a3d` quedaría a ΔE 14 y **se prohíbe**); el rojo queda para los pinchos y el «Cancelar».
  5. **Amarillo de los carteles frente al ámbar de los puntos:** ΔE ≥ 30 (con `#ffe600`, 41) y los puntos de atención llevan el **contorno oscuro de 1 px** también en el Mundo 5 (`AttentionPoint.has_outline()` pasa a «mundos 2-5»).
  6. **Sin verde lima ni cian en los neones:** un lima como `#c8ff3d` queda a ΔE 13 del verde ácido del Mundo 3 y un turquesa a ΔE 48 del cian de Isak: el neón secundario es **magenta y violeta** (`#9b5cff`).
  7. **Cian de Isak y de la silueta de Eco sobre el negro:** ≥ 3:1 (medido en capturas).
- **Pieza 5 del hub:** en el blanco elegido (la regla de las piezas: el color del Debug de su mundo), con el contorno del marco del hub para que se distinga del fondo claro de la página 3.

### 6.2 Qué se hace con AutoSprite y qué por script

Precios: personaje 3, pose 3, animación turbo 5, `upload_character` y `regenerate_*` 0. **Saldo: 249** (2026-10-28). **No se gasta nada sin permiso del usuario**, que recibe el total antes y con **parada tras cada personaje base**; y, **por decisión del usuario del 2026-10-28, todo es placeholder por script hasta tener los niveles y el jefe jugables** (paso 24).

| Pieza | Vía | Créditos (una pasada) | Con un reintento por pieza |
|---|---|---|---|
| **El Vendedor** (máquina con brazos y sonrisa de neón): base (+ recorte y `upload_character` si la IA pinta un personaje, como Autoplay y El Visto), poses `Offering`, `Turning` y `Processing`, y animaciones turbo `idle`, `turn`, `throw`, `processing`, `offer` y `defeat` | AutoSprite | 3 + 9 + 30 = **42** | 84 |
| **Poses de combo de Isak** (Embestida, Filo y Sismo) | AutoSprite sobre el personaje «Isak» (precedentes: dash, golpe al suelo, `compress` y `shockwave`) | 3 × 5 = **15** (+3 si hace falta una pose) | 30-36 |
| **Total recomendado** | | **57-60** (saldo después: **~189-192**) | **114-120** (~129-135) |
| *Opcional:* **Suscripción** (la única criatura con cara): base, una pose y `idle`, `attach`, `stunned` | AutoSprite | 3 + 3 + 15 = 21 | 42 |
| Oferta, cajas, persianas, ranura de precios, estanterías de saldos, cuentas regresivas, tienda, Términos y condiciones, «Prueba gratis», lista de deseos, tachón, caja registradora de Calc, tileset y fondo del centro comercial, escaleras mecánicas, carteles, fichas del álbum, miniaturas, `world_icon_m5`, quinta pieza del hub, piezas de interfaz del jefe (plataformas con precio, escaparate, ranura, cartel de la cuenta, barra «ticket», fichas), variante de Eco | **Script** (`tools/gen_world5_*.py` con validador de paleta) | 0 | 0 |

- **Por qué así:** la familia de formas del Mundo 5 son **carteles y cajas** (`07` §15.5): rectángulos, etiquetas y texto, que el script resuelve bien. La IA aporta en el jefe (la máquina con gesto) y en las poses de Isak, que se ven en todo el mundo.
- **Margen para el Mundo 6:** tras el Mundo 5 quedarían **~190** en una pasada: Isak Optimizado (jefe final, ~45) y las copias (~20-40) caben con reserva.

### 6.3 Por script (detalle)

- `tools/gen_world5_tiles.py`: tileset del centro comercial (suelo de baldosa con brillo, paredes de escaparate, banda de una vía «estante con etiqueta»); `data/tileset_mundo5.json`.
- `tools/gen_world5_background.py`: fondo horizontal en capas (escaparates con maniquíes, precios que parpadean, escaleras mecánicas al fondo; sin costura).
- `tools/gen_world5_objects.py`: Oferta (de pie y colgada, precio tachado en magenta), cajas (cerradas, translúcidas con el Debug, abiertas, con sus iconos), tienda y productos con etiqueta, puerta de atajo con sus iconos de trampa, cuenta regresiva (cartel de 5 segmentos), Términos y condiciones (botón enorme y diminuto), persiana, ranura de precios, estanterías de saldos (en pie, tumbada, reponiéndose), «Prueba gratis», lista de deseos y sus objetos, tachón, caja registradora de Calc, mostrador de Devoluciones, puerta «Pagar», carteles, miniaturas de nivel, `world_icon_m5`.
- `tools/gen_world5_enemies.py`: Suscripción provisional, Oferta animada (latido y aturdida).
- ~~`tools/gen_eco_companion.py`: variante del Mundo 5 de Eco: silueta de vendedor hecha de luz (`04` §12.1), en el cian de Isak con el halo dorado de la Q (decisión del Mundo 4: los compañeros de Isak van en su cian), sin precio ni cartel: así no se confunde con una Oferta (amarilla, con cartel y precio).~~ **Descartada (decisión del usuario 2026-10-29: Eco se ve igual en todos los mundos, `04` §12.1):** en el Mundo 5 Eco es la esfera de los Mundos 1-3; `tools/validate_eco_companion.py` falla si un mundo declara otra variante.
- `tools/gen_boss_vendor.py`: piezas de interfaz del jefe y cuerpo provisional.
- `tools/gen_hub_update_art.py` / `tools/gen_hub_piece_w5.py`: la quinta pieza con el blanco elegido y el destello del fondo completo; `tools/gen_hub_objects.py`: la apertura del candado.
- **Poses de combo provisionales** (sin hoja): por transformación del sprite en `tools/build_isak_frames.gd`, como la pose `dash` antes de su hoja.

### 6.4 Sonido

IDs de `lista-sonidos.md` (los del Mundo 5 ya listados) y nuevos. Se conectan en `data/audio.json` a señales; archivo ausente = silencio; provisionales de `tools/gen_audio_placeholders.py`; los definitivos los hace el amigo del usuario con el mismo nombre (= ID).

| ID | Cuándo | Origen |
|---|---|---|
| `sfx_w5_temptation_pull` | Tirón de la tentación (bucle por nodo que **sube al acercarse**: **accesibilidad**) | `lista-sonidos.md` |
| `sfx_w5_box_open_good` / `sfx_w5_box_open_bad` | Caja sorpresa | idem |
| `sfx_w5_subscription_attach` / `_drain` / `_cancel` | Suscripción (drenaje: tic por punto) | idem |
| `sfx_w5_pay` | Pagar (caja registradora «trucada» frente a la honesta de Calc) | idem |
| `sfx_w5_countdown` | «¡Solo por hoy!» (cada segundo: **accesibilidad**) | idem |
| `amb_w5_mall`, `mus_w5_level`, `mus_boss5` | Ambiente, nivel (capa de megafonía que sube con la tentación) y jefe | idem |
| **Nuevos (PROPUESTA):** `sfx_combo_ram`, `sfx_combo_edge`, `sfx_combo_quake`, `sfx_combo_denied`, `sfx_w5_shutter_break`, `sfx_w5_shelf_restock`, `sfx_w5_shelf_fall`, `sfx_w5_terms_accept`, `sfx_w5_terms_reject`, `sfx_w5_free_trial`, `sfx_w5_refund`, `sfx_w5_wishlist_add`, `sfx_boss5_intro`, `sfx_boss5_turn` (posicional: **accesibilidad**, avisa del giro), `sfx_boss5_throw`, `sfx_boss5_processing`, `sfx_boss5_glass_break`, `sfx_hub_photo_complete`, `sfx_hub_lock_open` | — | nuevos |
| Reutilizados | `sfx_weak_point_mark` / `_warn` / `_end`, `sfx_weak_point_hit`, `sfx_boss_phase_change`, `sfx_boss_defeat` → `stg_boss_defeated` → `mus_memory`, `sfx_hub_wallpaper_piece`, `sfx_memory_pickup`, `sfx_w4_seen_freeze` (para «Procesando pago…»), `sfx_calc_purchase` (caja registradora de Calc) | — |

- **Accesibilidad:** «Señales sonoras de ritmo» (activada por defecto) cubre la cuenta regresiva, el giro de El Vendedor y la cuenta de la fase 3. El tirón **nunca es solo sonido**: el cartel late y las partículas van hacia él.

---

## 7. Validación: validador, bots y pruebas

### 7.1 Validador de niveles (`tools/validate_level.py` + `tools/level_plan.py` + `tools/world5_model.py` nuevo)

- **Economía:** saldo del plan **desde 0 al entrar** (peor caso: se gastó todo en Calc); **ninguna arista obligatoria cuesta**; cada `shop_item`, `shortcut_door` y `calc_register` tiene su precio **cubierto por los puntos de la ruta anteriores** en ese nivel; Suscripciones como pérdida de saldo acotada (tope 5) y nunca negativa; `refund_desk` devuelve lo registrado.
- **Tentación:** modificadores de velocidad por zona (deriva, ×0,6 / ×1,15, suma con tope) en las aristas de andar y en el control aéreo; el dash y los combos la ignoran. **Reglas:** quieto en cualquier celda de una zona de tentación nunca acaba en un foso mortal; siempre hay salida andando.
- **Cajas:** contenido fijo; abrir es una acción (pulso de cara o golpe encima); con el Debug se «conoce» el contenido (coste de energía); el plan solo abre a ciegas las que no dañan; en los tramos de «elegir» busca un **orden seguro con la energía disponible**.
- **Atajos:** el camino largo existe siempre y es el que exporta el plan por defecto; con `--buy` se exporta también el que paga (para el bot comprador); la trampa `processing` es congelación con golpe al liberarse (el modelo del Mundo 4).
- **Cuentas regresivas:** plataformas con ciclo (el modelo de `BlinkPlatform`), espera del peor caso; el secreto B del 5-1 como «tercer ciclo».
- **Combinación:** habilidad del grafo (`abilities_available.combo` o el `free_trial_box`, que es una puerta); aristas **`combo_ram`** (desde un dash aéreo: diagonal hasta el suelo, rompe `shutter`), **`combo_edge`** (desde una celda comprimida en el aire: 4 tiles a 1 tile de alto, cruza `price_rail`, derrota a los de vida ≤ 1 en su línea) y **`combo_quake`** (comprimido en el aire hasta el suelo: tumba el grupo de `clearance_shelf` si **todo el grupo está en la vista** desde la celda de aterrizaje; aturde a los de suelo en pantalla); 15 de energía; nunca con el Debug.
- **Anti-redundancia (§3.9):** cada `shutter`, `price_rail` y `clearance_shelf` del camino **falla sin su combo** (el validador lo prueba quitando `combo` y comprobando que esa arista desaparece y no hay otra).
- **Términos y condiciones:** «Aceptar» = arista con Suscripción; «rechazar» = arista por láser desde la celda de enfrente o por Filo; el plan elige rechazar.
- **Lista de deseos:** tirón al tope; ninguna parada de 1,5 s sobre un deseo en el camino (si no, Suscripción).
- **Secretos:** `forbid_abilities`, `requires_abilities` (Filo en el 5-2 B, Linterna en el 5-3 B, Debug en los tres A) y recompensa `memory`.
- **Camino exportado** (`isak-path/1`): pasos nuevos `buy`, `pay_door`, `open_box`, `wait_countdown`, `cancel_subscription`, `combo_ram`, `combo_edge`, `combo_quake`, `reject_terms` y `resist_pull` (andar contra la tentación con la velocidad reducida).
- **Presupuesto de camino:** el validador imprime la duración del camino y su **porcentaje del objetivo**, y **avisa fuera del 40-55 %** (en el paso de cada nivel es criterio de terminado).
- **Pasadas:** sin mejoras, con mejoras, `--access-cap` y todo al máximo. **La salida de los Mundos 1-4 y de las arenas tiene que ser idéntica byte a byte.**
- **Negativos sintéticos** (`tests/test_world5_validator.py`): tienda impagable con los puntos anteriores; arista obligatoria con precio; Oferta que arrastra a un foso mortal; caja que tapa el camino con una bomba sin aviso; cajas en cadena sin orden seguro; persiana que cae con un golpe normal; ranura que se cruza sin Filo; estantería que cae sin Sismo; Sismo con parte del grupo fuera de la vista; combo con el Debug activo.

### 7.2 Validador de arenas (`tools/validate_boss.py`)

Rama `validate_vendor_arena` (las otras no cambian): en la fase 1, que desde la plataforma buena se baje detrás con **≥ k × (Debug encendido antes + pulso + láser)** dentro de los 1,2 s de giro, y que **las fichas alcancen** para las ventanas mínimas (con el «te fío» como red, nunca como plan); en la fase 2, que cada tanda tenga un ticket alcanzable y un camino a la espalda en 4 s (por el suelo o con dos bombas aturdidas); en la fase 3, que Embestida y Filo lleguen a la espalda **contra el tirón** antes de la cuenta con k = 2, y que nada dañe a Isak congelado; avisos de 6-12 cuadros; **energía torpe por acceso** (pico ≤ máximo − 20) y cargador a ≤ 4 tiles.

### 7.3 Bots

- **Bot de la tienda** (`tools/mall_bot.gd` + `tools/play_mall_bot.gd`): **extiende `tools/chat_bot.gd`** (que ya recorre bandas, Pellizcar y la Linterna). Pasos nuevos de §7.1. Perfiles **`frugal`** (por defecto: no compra ni abre a ciegas; sigue el camino largo) y **`comprador`** (compra todo, paga el atajo y comprueba que el saldo baja lo esperado y que Devoluciones lo devuelve). Comprobaciones: completa el nivel y vuelve al hub con él en `completed_levels`; 0 muertes; 0 «Añadido al carrito»; saldo final = inicial + puntos cogidos − gastado (comprador); energía mínima frente al camino; duración **frente al 40-55 % del objetivo**. El 5-2 empieza sin la Combinación y la obtiene en «Prueba gratis» (cierra las líneas de la escena).
- **Bot del jefe** (`tools/vendor_bot.gd`, lanzador `tools/play_boss_bot.gd -- --boss vendor`): política por fase (fase 1: Debug sobre el techo de la máquina, pagar la buena, bajar detrás, pulso + láser; fase 2: Debug para leer la tanda, abrir el ticket con golpe al suelo, aturdir las bombas que estorban, ir detrás; fase 3: Embestida o Filo según el lado, Debug detrás, pulso + láser). Perfiles `ideal`, `clumsy` (`validation_model` de `data/bosses/vendor.json`) e `idle`, y `--lap 1|2|3`. Comprueba `boss_w5_l<n>` sin guardar y la vuelta al hub con el Mundo 6 disponible, la quinta pieza, el fondo completo y el candado abierto. Objetivo: ideal en Caché entre **100 y 160 s**.
- **En la suite** (`tools/run_tests.sh`), como los de los Mundos 2-4 (proceso aparte).

### 7.4 Pruebas GUT y de Python necesarias

| Prueba | Qué comprueba |
|---|---|
| `tests/test_combo.gd` | Sin `combo` las tres combinaciones siguen negadas; con él: Embestida (diagonal, onda de 2, daño 2), Filo (4 tiles comprimido, derrota vida ≤ 1), Sismo (onda de pantalla, solo suelo); 15 de energía; nada con el Debug; apagan el Ocultarte; aviso y teclas leídas del Input Map |
| `tests/test_temptation.gd` | Deriva, ×0,6 / ×1,15, suma con tope, dash y combos la ignoran, pulso la apaga 3 s, láser derrota aturdida |
| `tests/test_world5_economy.gd` | `spend_attention` (sin deuda, «sin guardar»), tienda, atajo y su trampa, Devoluciones (solo el nivel e intento), rollback devuelve lo gastado sin guardar |
| `tests/test_surprise_box.gd` | Contenido fijo, abrir con golpe o pulso, Debug lo enseña, láser lo destruye, aturdida como escalón |
| `tests/test_subscription.gd` | Persigue, se engancha, drena con tope, «Pago rechazado» a 0, pulso y golpe la cancelan, Filo la derrota |
| `tests/test_countdown.gd` / `tests/test_terms_gate.gd` | Ciclo y aviso, no se materializa con Isak dentro, «tercer ciclo»; Aceptar engancha y rechazar solo con láser o Filo |
| `tests/test_combo_obstacles.gd` | Persiana solo con Embestida; ranura solo con Filo; estanterías se reponen salvo con Sismo del grupo entero; «Prueba gratis» (un uso, guardado, Papelera y rollback, la escena) |
| `tests/test_world5_validator.py` | Modelos y negativos de §7.1 |
| `tests/test_level_5_1.py/.gd`, `5_2`, `5_3` | Estructura, secretos, economía, presupuesto de camino y flujo hub → nivel → hub |
| `tests/test_vendor_boss.gd` | Sin Debug no hay marca; detrás y con el Debug sí; giro de 1,2 s; un golpe por marca; fichas y «te fío»; ticket que lo deja sin girar; cuenta y «Procesando pago…» |
| `tests/test_boss_validator.py` (rama nueva) | §7.2 |
| `tests/test_mall_bot.gd`, `tests/test_vendor_bot.gd` | Bots en la suite |
| `tests/test_world5_negatives.gd` / `.py` | Quieto pierde; sin la Combinación no se sale de «Paquete completo»; con 0 puntos se completan los tres niveles; **rejugar los Mundos 1-4 con la Combinación** no trivializa ningún secreto ni cambia las salidas del validador |
| `tests/test_palette_mundo5.py` | Reglas de §6.1 |
| `tests/test_hub_world5_complete.gd` | Quinta pieza, fondo completo, quinta ranura, candado abierto y M6 disponible; un game over sin guardar lo deshace |

---

## 8. Plan de implementación

Pasos pequeños, como en los Mundos 2-4. Cada paso lleva sus pruebas y **termina con las pruebas focalizadas de lo que toca en verde** (las del paso y las de las piezas que reutiliza; **la suite completa solo cuando el usuario la pida**) y `graphify update .`. El arte es por script (`_placeholder` en El Vendedor y la Suscripción) hasta el paso 24. Los textos se marcan como propuestos. **Un commit local por paso, sin push** (`git add` por ruta, nunca `-A`), con mensaje «Mundo 5, paso N: …» y la línea de coautoría. Las decisiones que surjan se anotan en «Avance y desvíos» (§8.1, vacía hasta empezar).

| Paso | Qué | Archivos probables | Terminado cuando | Tamaño | Depende de | En paralelo con |
|---|---|---|---|---|---|---|
| 0 | **Paleta provisional** por script con el blanco elegido (§10.1; por defecto A `#ffffff`) y las reglas de §6.1 en `--check`; `data/world5_objects.json` y **`data/economy.json`** | `tools/palette_mundo5_provisional.py`, `assets/palettes/mundo5_provisional.gpl`, `data/hud.json` (`debug_colors["5"]`), `data/world5_objects.json`, `data/economy.json`, `tests/test_palette_mundo5.py` | `--check` pasa | S | §10.1 | 1, 2 |
| 1 | **Combinación en Isak:** estados `ComboRam`, `ComboEdge`, `ComboQuake`; habilidad `combo`; reglas con Debug, energía, Ocultarte, vórtices; aviso; poses provisionales; `test_arena` con `combo` | `scripts/player/states/combo_*_state.gd`, `scripts/player/isak.gd`, `data/isak_abilities.json`, `data/ability_notices.json`, `tests/test_combo.gd` | GUT de §7.4; sin `combo`, las salidas de `test_dash`, `test_ground_pound` y `test_compress` no cambian | **L** | — | 0, 2 |
| 2 | **Tentación:** `offer_sign` y `TemptationField` en Isak (deriva, multiplicadores, suma con tope, dash y combos la ignoran); sala `ofertas_test` | `scripts/enemies/offer_sign.gd`, `scripts/player/temptation_field.gd`, `data/enemies/offer_sign.json`, `tests/test_temptation.gd` | GUT de §7.4 | M | 0 | 1, 3 |
| 3 | **Economía en el nivel:** `GameState.spend_attention`, `shop_item`, `shortcut_door` (precio, trampas, Debug revela; `processing` con `FrozenState`), `refund_desk`; sala `tienda_test` | `scripts/autoload/game_state.gd`, `scripts/levels/shop_item.gd`, `scripts/levels/shortcut_door.gd`, `scripts/levels/refund_desk.gd`, `tests/test_world5_economy.gd` | GUT: sin deuda, rollback, Devoluciones por nivel | M | 0 | 2, 4 |
| 4 | **Caja sorpresa y Suscripción** (contenido fijo, abrir, Debug, láser, aturdida; persecución, drenaje con tope, cancelar); sala `cajas_test` | `scripts/levels/surprise_box.gd`, `scripts/enemies/subscription.gd`, `tests/test_surprise_box.gd`, `tests/test_subscription.gd` | GUT de §7.4 | M | 3 | 3, 5 |
| 5 | **Cuenta regresiva y Términos y condiciones**; sala `rebajas_test` | `scripts/levels/countdown_platform.gd`, `scripts/levels/terms_gate.gd`, `tests/test_countdown.gd`, `tests/test_terms_gate.gd` | GUT: ciclo, tercer ciclo, rechazar con láser o Filo | S-M | 1 | 4, 6 |
| 6 | **Obstáculos de los combos y «Prueba gratis»:** `shutter`, `price_rail`, `clearance_shelf`, `free_trial_box` (y la escena con el interlocutor `isak`); sala `combos_test` | `scripts/levels/shutter.gd`, `scripts/levels/price_rail.gd`, `scripts/levels/clearance_shelf.gd`, `scripts/levels/free_trial_box.gd`, `data/eco_text_box.json`, `tests/test_combo_obstacles.gd` | GUT: cada obstáculo solo con su combo (§3.9) | M | 1 | 5, 7 |
| 7 | **Lista de deseos, tachón y caja registradora de Calc**; sala `deseos_test` | `scripts/levels/wishlist_platform.gd`, `scripts/levels/wish_strike.gd`, `scripts/levels/calc_register.gd` | GUT: tirón al tope, «Añadido al carrito», atajo legítimo | S-M | 2, 3 | 6 |
| 8 | **Validador y camino exportado** (§7.1), en dos partes: 8a economía, tentación, cajas, atajos, cuentas; 8b combos y obstáculos, Términos, lista de deseos, presupuesto de camino; negativos | `tools/validate_level.py`, `tools/level_plan.py`, `tools/world5_model.py`, `tests/test_world5_validator.py` | Salas 2-7 validan; negativos fallan; salidas de los Mundos 1-4 idénticas | **XL** | 1-7 | 9 |
| 9 | **Arte por script del mundo** (§6.3), Eco de luz, ayudas Q (`world: 5`) y fichas del álbum; **3 variantes de paleta** con maqueta y aplicar la elegida | `tools/gen_world5_*.py` + validadores, `tools/palette_mundo5_variants.py`, `data/help.json`, `tools/gen_album_cards.py` | Validadores en la suite; contraste ≥ 3:1 en capturas | L | 0, 2-7 | 8 |
| 10 | **El 5-1 real** (§4.1, por plantas) + filas M5 en `data/hub.json` + `msg_5_1` + vida extra + miniatura M5 + línea de Calc | `data/levels/5-1.json`, `scenes/levels/5-1.tscn`, `data/hub.json`, `data/memories.json`, `tests/test_level_5_1.py/.gd`, `tests/fixtures/climbs_5-1.json` | Valida en todas las pasadas con camino en el **40-55 %**; jugable desde la carpeta M5 | L | 8, 9 | 11 |
| 11 | **Bot de la tienda** recorriendo el 5-1 (frugal y comprador) | `tools/mall_bot.gd`, `tools/play_mall_bot.gd`, `tests/test_mall_bot.gd` | Código 0; duración en el 40-55 % | M-L | 10 | 12 |
| 12 | **Prueba del usuario temprana** (nuevo, lección del Mundo 4): el usuario juega el 5-1 con placeholders; sus cambios se aplican aquí, **antes** de construir el 5-2 y el 5-3 | `docs/preguntas.md` (lista corta: tentación, precios, cajas, atajo), `propuesta-mundo-5.md` §8.1 | El usuario lo ha probado (o decide saltarlo) y los cambios están hechos | S-M | 11 | 15 |
| 13 | **El 5-2 real** (§4.2) + `msg_5_2` + bot (obtiene la Combinación) | `data/levels/5-2.json`, `tests/test_level_5_2.*` | Valida; el bot lo completa; cada obstáculo de combo falla sin combo | L | 12 | 15 |
| 14 | **El 5-3 real** (§4.3) + `msg_5_3` + bot | `data/levels/5-3.json`, `tests/test_level_5_3.*` | Valida (cajas en cadena con orden seguro, lista de deseos); el bot lo completa con 0 puntos de entrada; desbloquea la fila del jefe | L | 13 | 15-17 |
| 15 | **Datos y lógica de El Vendedor:** `data/bosses/vendor.json` (fases, giro, fichas, `laps` con `mark_hits`), `WeakPoint` en la espalda | `scripts/bosses/vendor.gd`, `tests/test_vendor_boss.gd` | GUT: sin Debug no hay marca; detrás sí; giro; un golpe por marca | M | 1-4 | 10-14 |
| 16 | **Arena `5-boss`** y **fases 1-3** (plataformas con precio, cajas lanzadas, ticket, oferta con cuenta, escaparate y ranura) | `data/levels/5-boss.json`, `scripts/bosses/vendor.gd` | GUT de cada fase con el tiempo avanzado a mano; cabe en pantalla | L | 15 | 10-14 |
| 17 | **Validador de arenas** para El Vendedor (§7.2) | `tools/validate_boss.py`, `tests/test_boss_validator.py` | Márgenes de energía torpe ≥ 20 en los tres accesos; fichas suficientes | M | 16 | 18 |
| 18 | **Barra «ticket», recompensa y hub:** `BossBar` con su estilo y fichas, `BossReward.grant(5, …)`, quinta pieza y fondo completo, quinta ranura y candado abierto, M6 disponible, fila «Jefe: El Vendedor» | `data/hud.json`, `data/hub.json`, `tools/gen_hub_piece_w5.py`, `tests/test_hub_world5_complete.gd` | Desde la carpeta M5 se entra, se vence, se recibe `boss_w5_l1` sin guardar y se vuelve con el fondo completo y M6 disponible | S-M | 16 | 17 |
| 19 | **Bot del jefe** (ideal / torpe / quieto, `--lap 1-3`) | `tools/vendor_bot.gd`, `tests/test_vendor_bot.gd` | Ideal y torpe vencen sin muertes; quieto pierde; ideal en Caché entre 100 y 160 s | M-L | 16-18 | 20 |
| 20 | **Textos, ayudas Q y audio:** líneas de Eco, Isak, Calc y El Vendedor, ayudas, carteles, IDs de §6.4 con provisionales | `data/bosses/vendor.json`, `data/help.json`, `data/audio.json`, `tools/gen_audio_placeholders.py` | `validate_audio.py` pasa; la Q explica cada tipo nuevo | S | 15-18 | 19 |
| 21 | **Pruebas de conjunto:** negativos de §7.4, salidas del validador de los Mundos 1-4 idénticas, rejugar M1-M4 con la Combinación, los tres niveles con 0 puntos | `tests/*` | Pruebas del Mundo 5 y negativos en verde (**suite completa solo si el usuario la pide**) | S | 10-20 | — |
| 22 | **Capturas, mapas y docs** (`mundo-5-tienda.md` §10.8, `02-isak-habilidades.md` §3.5 con Sismo redefinido, `08-pendientes.md`, `CLAUDE.md`, `INDEX.md`, `05-hub.md`) | `tools/render_level_5_x.gd`, `tools/render_level_map.py` | Capturas en `assets/levels_preview/5-x/`; mapas al día | S-M | 21 | 23 |
| 23 | **Lista de revisión del usuario** (§11) volcada a `preguntas.md` | `docs/preguntas.md` | Lista publicada | S | 22 | — |
| 24 | **Arte final con AutoSprite** (con permiso y total previo; parada tras cada base): El Vendedor y las tres poses de combo (§6.2; la Suscripción, opcional). Solo con los niveles (pasos 10-14) y el jefe (pasos 15-19) terminados y probados | `docs/plan-arte-mundo-5.md`, `tools/import_boss_vendor.py`, `tools/reduce_palette.py` | Integrado sin cambiar tiempos ni cajas; los bots dan los mismos resultados | M | 22 y permiso | — |

**Orden:** 0, 1 y 2 a la vez → 3, 5 y 6 (máximo 3-4 subagentes a la vez) → 4 y 7 → 8 y 9 en paralelo → 10 → 11 → **12 (el usuario prueba)** → 13 → 14. El jefe (15-20) puede empezar tras el 4, en paralelo con los niveles 10-14 → 21 → 22 → 23 → 24. **25 pasos en total (0-24).**

**Tamaño relativo (estimación):**

| | Mundo 4 | Mundo 5 |
|---|---|---|
| Habilidad nueva | Agitar (retirado) + estado Congelado | **Tres movimientos** (combos) sobre estados existentes |
| Fuerza nueva sobre Isak | — | **Tentación** (toca el control horizontal) |
| Economía | — | Primer gasto de puntos en un nivel, Devoluciones, fichas del jefe |
| Cámara | Ninguna nueva | Ninguna nueva (horizontal del 1-1) |
| Tipos nuevos | ~13 | ~14, casi todos sobre piezas existentes |
| Validador | Plataformas que llegan tarde, congelación, ola, oscuridad | Saldo desde 0, fuerzas por zona, orden seguro de cajas, tres combos, anti-redundancia, presupuesto de camino |
| Jefe | `BossBase`, `WeakPoint` | Igual, con giro hacia Isak y fichas |
| **Total** | ≈ 65-75 % del Mundo 1 | **≈ 70-80 %** del Mundo 1 |

### 8.1 Avance y desvíos

(Cada paso hecho se anota aquí con su fecha, lo que se hizo, los desvíos y, si hace falta decidir algo, la entrada «Decisión tomada» con su razón.)

**Decisiones del usuario (2026-10-29, §10):** blanco del Debug = **A «Blanco puro» `#ffffff`** (también la quinta pieza del hub); remitente de `msg_5_x` = **el Abuelito**; arte final con AutoSprite **al final**, con el mundo completo (paso 24; 0 créditos hasta entonces).

- **Paso 0 (2026-10-29):** `tools/palette_mundo5_provisional.py` (16 colores + `debug_blanco`; `--check` con las 7 reglas de §6.1 y el blanco igual que `debug_colors["5"]` de `data/hud.json`, que pasa de `#f4f4f4` a `#ffffff`), `assets/palettes/mundo5_provisional.gpl`, `data/world5_objects.json` (sin tipos; sección `palette`), `data/economy.json` (§3.1, §3.5, §3.6 y fichas de §5.2) y `tests/test_palette_mundo5.py` (también comprueba `data/economy.json`). Desvío: como en el Mundo 4, la regla 5 se cumple ya en este paso: `AttentionPoint.OUTLINE_WORLDS` incluye el 5 (contorno `tienda_noche`) y hay `World5ObjectsConfig` (`scripts/levels/world5_objects_config.gd`); caso nuevo en `tests/test_attention_point_outline.gd`. Medidas: blanco a ΔE 77 del rojo (63 con el tinte), contorno 15,3:1 sobre el amarillo, L\* máx. 90,7, amarillo-puntos ΔE 41, cian de Isak 7,6:1; blanco-texto del HUD ΔE 4 (se informa).
- **Paso 1 (2026-10-29):** habilidad `combo` (`GameState.ABILITY_COMBO`) y estados `ComboRam`, `ComboEdge` y `ComboQuake` (`scripts/player/states/combo_*_state.gd`); reglas en `Isak.combo_denial` / `_update_combo_request` (solo en el aire; 15 de energía; con el Debug activo o cargando o sin energía, chispa gris y `EventBus.combo_denied`; sin la habilidad, en el hub o sin los dos gestos que combina, el gesto se niega como antes, sin aviso); ondas y Filo en `scripts/player/combo_wave.gd` (`receive_combo` para los que deciden ellos) y `EventBus.combo_started` / `combo_landed` para los objetos de los pasos 5-6; valores en la sección `combo` de `data/isak_abilities.json`; aviso `combo` de `data/ability_notices.json` con la marca nueva `{key:<acción>}` (tecla leída del Input Map); `test_arena` con `combo`; `tests/test_combo.gd` (14 pruebas). Sin `combo`, `test_dash` (19), `test_ground_pound` (19) y `test_compress` (17) dan lo mismo. **Decisiones tomadas** (reglas finas no escritas en §3.2.3): (1) el **Filo gasta el dash aéreo** del salto (uno por estancia en el aire, como el dash; si no, encadenar Filos sería volar); (2) la Embestida y el Filo son **invulnerables** (el Filo atraviesa enemigos); el Sismo no; (3) tras un combo de abajo hay que **soltar abajo** antes de otro combo o golpe al suelo; (4) el **Sismo** aplica la onda a la vez a todo el ancho visible de la cámara (sin cámara, 640 px a cada lado = 1280 px/s × 0,5 s) en la franja a ras del suelo de Isak; la onda se dibuja creciendo. Desvío: las **poses provisionales** van por código en `Isak.update_combo_pose` (giro de la pose del dash, pose comprimida y las estelas del dash y del golpe al suelo), no como cuadros nuevos de `tools/build_isak_frames.gd`; `HideMode` tampoco deja ocultarse durante un combo; `tools/validate_level_schema.py` acepta `combo` en `abilities_available`.
- **Paso 2 (2026-10-29):** Oferta `offer_sign` (`scripts/enemies/offer_sign.gd`, `OfferSign`; `data/enemies/offer_sign.json`, escena `scenes/enemies/offer_sign.tscn`) y la fuerza `TemptationField` (`scripts/player/temptation_field.gd`; valores en la sección `field` del JSON de la Oferta) aplicada en `Isak.apply_horizontal` (objetivo = eje × velocidad × multiplicador + deriva); sala `ofertas_test` (patrón 23 y dos Ofertas, una colgada); `tests/test_temptation.gd` (15 pruebas). Sin cambios en `test_combo`, `test_dash`, `test_compress`, `test_player_states` ni `test_player_physics_sim`. **Decisiones tomadas** (reglas finas que §3.3 no fija): (1) la deriva **se suma también andando**: alejarse andando de una Oferta da 220 × 0,6 − 60 = **72 px/s** (la cuenta «132 − 60 > 0» de §3.3), correr 156 y acercarse andando 313; (2) **zona** = rectángulo de `radius_tiles` a cada lado del centro del cartel y `height_tiles` de alto centrado en él, contra el **centro del cuerpo** de Isak (un salto alto sale de ella); a menos de `dead_zone_px` (4) en horizontal no tira, así que Isak se queda **encima** de la Oferta, no la cruza; (3) **suma**: peso = Σ ±`strength` (las opuestas se restan); deriva = peso × 60 con tope 90; alejarse 1 − 0,4 × peso con suelo 0,45; acercarse 1 + 0,15 × peso con el peso topado a 1,5 (×1,225 como mucho; §3.3 no daba tope al acercarse); (4) tira en Idle, Run, Jump, Fall y Pulse (`Isak.TEMPTATION_STATES`); **no** en el dash, los combos, el golpe al suelo, Hurt, Dead, Frozen, la pose **de espaldas** (pagar en una tienda no arrastra) ni en un vórtice o el hub; el Ocultarte no la quita (es una fuerza, no una detección); (5) el **golpe al suelo y la Embestida** aturden y dañan a la Oferta como a cualquier enemigo; el **Sismo** solo a la de pie (`mount: "floor"`), y el **Filo** no la derrota (vida 2); (6) `level_params`: `mount` (texto; el esquema no admite `values` en textos, lo comprueba el script), `radius_tiles` 2-8, `height_tiles` 1-5, `strength` 0,5-2 y `health`. Desvío: sin `help_id` en el JSON hasta el paso 9 (el esquema exige que exista en `data/help.json`), como el Fantasma del Mundo 4; `tools/validate_level.py` aún no la modela (paso 8a).
- **Paso 3 (2026-10-29):** `GameState.can_afford` / **`spend_attention(cantidad, motivo, nivel, tipo_devoluble)`** (saldo real; **sin deuda**: si no llega no gasta nada y devuelve falso; marca «sin guardar»; no quita energía; `EventBus.attention_spent`) y el **registro de Devoluciones** por nivel e intento (`note_refundable`, `get_refundable`, `claim_refunds`, `EventBus.attention_refunded`; lo vacían `begin_attempt`, el rollback y `reset_progress`; no se guarda). Base común `PayPoint` (`scripts/levels/pay_point.gd`: pulso de espaldas como `LikeReset`, cartel temporal, chispa gris y lectura de `data/economy.json`) para **`shop_item`** (`ShopItem`: `product` `sync` +25 / `energy` +40, precio de `prices.shop_item` o `cost`), **`shortcut_door`** (`ShortcutDoor`: 1 × `height_tiles` sólida hasta pagar; `trap` `""` / `processing` / `subscription` / `offer` / `countdown`; el Debug enseña el icono de la trampa con contorno de 1 px) y **`refund_desk`** (`RefundDesk`); tipos y secciones en `data/world5_objects.json`; sala `tienda_test` (tienda, atajo con trampa y camino largo por encima del muro, Devoluciones y atajo legítimo con un nicho tras la terminal); `tests/test_world5_economy.gd` (14 pruebas). `test_game_over`, `test_frozen` y `test_palette_mundo5.py` siguen en verde. **Decisiones tomadas:** (1) «uno por intento» = **por instancia del objeto** (el nivel se crea de nuevo en cada intento; morir y reaparecer en un checkpoint no lo repone); (2) el atajo **se abre** (deja de ser sólido) en vez de teletransportar: «lleva a un pasillo» es el pasillo de detrás de la puerta; la trampa salta **la primera vez que Isak cruza** la puerta abierta; (3) `processing` usa `Isak.freeze(1,5 s, "shortcut_processing", hacia donde mira)`: sin la inmunidad de las zonas «Visto» y con el golpe al liberarse del Mundo 4; (4) solo lo pagado en una puerta **con** trampa es devoluble (el atajo legítimo de Calc, no); (5) los puntos devueltos **no dan energía** (es dinero devuelto); los **2 del secreto** sí (son puntos nuevos, `add_attention_points`) y se dan **una vez por partida guardada** (`mark_pickup_collected` con `refund_bonus:<id>`, para que rejugar el 5-1 no los multiplique); (6) la tienda vende aunque la barra esté llena (decide el jugador). **Desvíos:** las trampas `subscription`, `offer` y `countdown` de momento solo emiten `trap_sprung` (sus piezas llegan en los pasos 4-5; se conectan allí); sin `help_id` hasta el paso 9 (como la Oferta); `tools/validate_level.py` toma las puertas por objetos sin colisión (la economía se modela en el paso 8a); el «◆» del cartel se dibuja como rombo (la fuente por defecto no tiene el glifo).
- **Paso 4 (2026-10-29):** **caja sorpresa** `surprise_box` (`SurpriseBox`, `scripts/levels/surprise_box.gd`, escena `scenes/levels/surprise_box.tscn`; tipo y sección en `data/world5_objects.json`) y **Suscripción** `subscription` (`Subscription`, `scripts/enemies/subscription.gd`, `data/enemies/subscription.json`, escena `scenes/enemies/subscription.tscn`; drenaje de la sección `subscription` de `data/economy.json`); las trampas **`subscription`** y **`offer`** de `shortcut_door` ya sacan su pieza (`get_trap_spawn()`); sala `cajas_test` (cuatro cajas del patrón 24, una Suscripción dormida, cargador y atajo con trampa `subscription` con su camino largo); `tests/test_surprise_box.gd` (16 pruebas) y `tests/test_subscription.gd` (15). `test_world5_economy`, `test_temptation` y `test_palette_mundo5.py` siguen en verde. **Decisiones tomadas** (reglas finas que §3.4 y §3.5 no fijan): (1) caja **sólida** de 56 × 56 en su celda (se pisa; la Suscripción y la Oferta salen a sus pies); (2) **pulso de cara** = Isak en el suelo, no de espaldas y mirándola (a menos de 8 px en horizontal vale cualquier lado); **golpe encima** = los pies de Isak a ≤ 8 px de la tapa y sobre ella (la onda de un golpe al lado no la abre); la **Embestida** la abre si su onda la alcanza; el **Sismo no le hace nada** a una caja (§3.2.3 decía «sí a las cajas en el suelo»: aturdir una caja en reposo no significa nada y abrirlas todas a la vez trivializaría el patrón 24); (3) los **puntos** de una caja se capturan como un punto de atención del nivel (`box:<id>`, una vez por partida guardada, con su energía): ya capturados, la caja es vacía y el Debug lo enseña así; la energía (+30) se da al momento; (4) la caja **lanzada** (`launch()`, para el paso 16) vuela sin ser sólida; el pulso la aturde 3 s inerte y sólida (escalón) y después cae y queda como una caja normal; el **Filo** destruye a la aturdida (vida 1), no a la de reposo; (5) Suscripción: se engancha al **tocar el cuerpo** de Isak (sin daño ni invulnerabilidad), drena a los 2 s del enganche y luego cada 2 s; **al llegar al tope (5) se suelta «saciada»**: cae al suelo y no vuelve a perseguir (vulnerable al láser y al Filo); con saldo 0 al engancharse o en un drenaje, «Pago rechazado» y a los 3 s cae **aturdida** y al despertar vuelve a buscar a Isak (no drena: sin deuda); (6) cancelar: el **pulso** de Isak se la quita enganchada y aturde a la suelta que alcanza; el **golpe al suelo** la suelta enganchada y aturde a la suelta que alcanza, **sin daño** (§3.5: solo el láser y el Filo la derrotan); la **Embestida** la suelta enganchada y a la suelta le hace su daño 2 (la derrota); el **Sismo** suelta a la enganchada y aturde a las del suelo, no a las que vuelan; el **Filo** derrota también a la que vuela (vida ≤ 1, §3.2.2), no a la enganchada (va en la espalda de Isak); (7) vuela con `move_and_slide` contra el terreno (sin correa: se rinde a 12 tiles o con Isak oculto y vuelve a su sitio); al reaparecer vuelve dormida a su sitio y **lo drenado sigue contando para el tope**; (8) trampa `subscription`: la Suscripción sale avisando a `trap_distance_tiles` (2) tiles de la puerta, hacia donde cruza Isak, una fila por encima del suelo; trampa `offer`: una Oferta de pie a esa distancia (los pinchos los pone el nivel). **Desvíos:** sin `help_id` hasta el paso 9 (como la Oferta); el parpadeo magenta del HUD al drenar (§2.3) queda para el paso del HUD/arte; la trampa `countdown` sigue sin pieza hasta el paso 5; `tools/validate_level.py` no modela cajas ni Suscripciones (paso 8a): en `cajas_test` toma las cajas por objetos sin colisión.
- **Paso 5 (2026-10-29):** **cuenta regresiva** `countdown_platform` (`CountdownPlatform`, `scripts/levels/countdown_platform.gd`, escena `scenes/levels/countdown_platform.tscn`) y **Términos y condiciones** `terms_gate` (`TermsGate`, `scripts/levels/terms_gate.gd`, escena `scenes/levels/terms_gate.tscn`); tipos y secciones en `data/world5_objects.json`; la trampa **`countdown`** de `shortcut_door` ya pone en marcha su cuenta; sala `rebajas_test` (patrón 28 con una Oferta al otro lado, atajo con trampa `countdown` y su cuenta de salida, Términos y condiciones con la repisa de enfrente para el láser); `tests/test_countdown.gd` (8 pruebas) y `tests/test_terms_gate.gd` (8, con el láser y el Filo reales). `test_world5_economy`, `test_subscription`, `test_surprise_box` y `test_palette_mundo5.py` siguen en verde. **Decisiones tomadas:** (1) cuenta = **plataforma sólida** (tarjeta de 32 px arriba de su celda, como `BlinkPlatform`; `one_way` opcional) de 5 s con 5 segmentos y un tic por segundo (`second_ticked`, para `sfx_w5_countdown`), parpadeo de 9 cuadros antes de plegarse, plegada 1 s sin colisión (se cae sin daño), no se materializa con Isak dentro; carteles **propuestos**: primera cuenta «¡Solo por hoy!», las demás «¡Últimas horas!»; (2) **«tercer ciclo»** = si Isak espera **a ≤ 6 tiles** (horizontal) **dos cuentas seguidas sin ponerse encima**, la tercera es «Vale, esta vez es verdad» y dura 10 s; **una vez por intento**; usarla o estar lejos reinicia la racha; `truth_cycle` (3 por defecto; 0 = sin ella) porque no toda cuenta debe tener el secreto; (3) **«se reinicia mientras no se use»** se lee como el ciclo continuo de §3.7 (siempre vuelve), no como una cuenta que solo corre con Isak encima; (4) trampa `countdown`: «la salida es una cuenta regresiva» = las `countdown_platform` con `trigger` = id del atajo **esperan sólidas y sin cuenta** hasta que salta la trampa y entonces empiezan a contar (sin `trigger`, cuentan desde el principio); (5) Términos: botones en la cara de `side` (por donde se llega); «ACEPTAR» = 3 × 1 tiles junto al pie de la puerta, **cualquier pulso** que lo alcance (de cara o de espaldas) abre y **engancha** una Suscripción a Isak; «rechazar» = 8 px de dibujo y 8 × 16 de zona en lo alto de la cara de la puerta: un `Area2D` del láser (desde el suelo de la puerta el disparo choca con ella; desde un suelo de enfrente **una fila por debajo de lo alto de la puerta**, el celular queda a su altura) o un **Filo** que lo roza (la puerta está en el grupo `enemy` solo para recibir el barrido del Filo; la Embestida, el Sismo y el golpe al suelo no hacen nada); el pulso no pulsa «rechazar»; abierta se queda abierta el intento. **Desvíos:** `countdown_door` (la variante puerta de §3.7) no se hace en este paso (ningún nivel la pide aún; la trampa `countdown` usa la plataforma); sin `help_id` hasta el paso 9; `tools/validate_level.py` no modela cuentas ni Términos (paso 8): en `rebajas_test` toma las cuentas y la puerta por objetos sin colisión y los hoyos (una fila, sin daño) se saltan o se cruzan con el dash.
- **Paso 6 (2026-10-29):** **persiana** `shutter` (`Shutter`, `scripts/levels/shutter.gd`), **ranura de precios** `price_rail` (`PriceRail`, `scripts/levels/price_rail.gd`), **estantería de saldos** `clearance_shelf` (`ClearanceShelf`, `scripts/levels/clearance_shelf.gd`) y **«Prueba gratis»** `free_trial_box` (`FreeTrialBox`, `scripts/levels/free_trial_box.gd`, hereda de `DndSwitch` como el reproductor del Mundo 2), con sus escenas en `scenes/levels/` y sus tipos y secciones en `data/world5_objects.json`; **interlocutor `isak`** con **estilo de cuadro propio** `isak` en `data/eco_text_box.json` (icono y panel de 16 × 16 de `tools/gen_isak_text_box.py`, `eco_isak_icon.png` / `eco_isak_panel.png`, en la lista `assets` para `validate_ui_assets.py`; paleta del Mundo 1: chaqueta gris oscura con la línea cian del cuello como borde, indicación de cierre en cian, 30 caracteres/s; `--check` en la suite); sala `combos_test` (la «Prueba gratis» da la Combinación, persiana de suelo de salida, persiana de pared, ranura sobre un hoyo y tres estanterías de un grupo); `tests/test_combo_obstacles.gd` (17 pruebas, con el Isak real en la Embestida, el Filo, el Sismo, el golpe al suelo, el dash y el láser). `test_eco_text_box`, `test_eco_text_inline`, `test_undo_prompt`, `test_world5_economy`, `test_terms_gate`, `test_level_schema.py`, `test_build_level.py`, `test_palette_mundo5.py` y `validate_ui_assets.py` siguen en verde. **Decisiones tomadas** (reglas finas que §3.7 y §3.9 no fijan): (1) persiana: **rebotan** (chispa gris, señal `deflected`) el golpe al suelo, el pulso, el láser y el **Sismo**; la rompe una **Embestida cuya onda la alcanza** (`EventBus.combo_landed`), de suelo (aterrizando encima) o de pared (aterrizando a ≤ 2 tiles); rota no vuelve al reaparecer (el nivel se crea de nuevo en cada intento); (2) «limpia a los enemigos de debajo»: la persiana de suelo rota **prolonga la onda** de la Embestida `break_wave_depth_tiles` (3) por debajo de ella, con su ancho, su daño (2) y su aturdimiento (3 s); (3) ranura: las etiquetas **no son sólidas** (si lo fueran, comprimido se andaría por encima de las de abajo): llenan `height_tiles` filas menos la fila `slot_row` y se apartan `inset_px` (32) de cada borde, así un Filo de 4 tiles que empieza al borde del foso las deja atrás (hilera de 192 px); **tocarlas empuja**: Isak vuelve al borde de la hilera por el lado por donde llegó con 240 px/s hacia fuera y, si iba en un dash o un combo, se corta (pasa a Fall); el Filo alineado con la ranura (pies a 64-88 px de su suelo) no las toca; (4) estanterías: tumban una el golpe al suelo cuya onda la alcanza, la Embestida, el pulso y el láser; «caen para siempre» = **todas las del grupo tumbadas a la vez** (como cada una se repone a los 0,5 s, equivale a «todas en menos de 0,5 s»); **un grupo de una sola estantería solo cae con el Sismo** (si no, un golpe suelto bastaría); no se repone con Isak dentro (espera a que salga) y reaparecer repone las tumbadas; el validador (paso 8b) debe comprobar que ningún golpe suelto alcanza a dos del mismo grupo; (5) «Prueba gratis»: caja en la pared del fondo (pulso de espaldas, como «No molestar»); el «cartel de la caja» del paso 1 de §4.2.2 es un **cartel dibujado sobre la caja** (no una línea del cuadro); los tres gestos se juntan en `merge_s` (1,2 s) **en tiempo real** (corren durante la pausa de las líneas importantes); la escena sale **una vez por partida guardada** (`seen_notices` `combo_5_2`) y la Combinación se da siempre que no se tenga (tras un rollback sin ella y con la escena vista, la caja vuelve cerrada y la da sin escena); orden: Eco «Todo tiene un precio.» e Isak «Esto no lo compré. Es mío.» (importantes), el aviso de la Combinación (AbilityNotices al obtenerla) y Eco «Una prueba gratis siempre acaba, {apodo}.» (no importante). **Desvíos:** sin `help_id` hasta el paso 9 (la «Prueba gratis» es historia: sin Q); `tools/validate_level.py` no modela los combos ni estos obstáculos (paso 8b): en `combos_test` toma la persiana, la ranura, las estanterías y la caja por objetos sin colisión (la persiana de suelo es un hueco del grid); la sala tiene **dos** persianas (de suelo y de pared).
- **Paso 7 (2026-10-29):** **lista de deseos** `wishlist_platform` (`WishlistPlatform`, `scripts/levels/wishlist_platform.gd`), **tachón** `wish_strike` (`WishStrike`, `scripts/levels/wish_strike.gd`, hereda de `GlitchWall`) y **caja registradora de Calc** `calc_register` (`CalcRegister`, `scripts/levels/calc_register.gd`, hereda de `ShortcutDoor`), con sus escenas en `scenes/levels/` y sus tipos y secciones en `data/world5_objects.json`; sala `deseos_test` (tres deseos sobre un hoyo con una Oferta de pie, el tachón con un punto detrás y la caja de Calc con un nicho); `tests/test_wishlist.gd` (10 pruebas). `test_world5_economy`, `test_terms_gate` y `test_combo_obstacles` siguen en verde. **Decisiones tomadas:** (1) la **Oferta integrada** no es un `OfferSign` hijo: la plataforma entra en el grupo de `TemptationField` con su propio `get_pull_weight` (zona de `radius_tiles` 6 a cada lado del objeto y `height_tiles` 3 de alto centrada en él, `strength` 1, zona muerta de 4 px), así se **suma** con las Ofertas y los demás deseos con el tope de §3.3 (deriva 90 px/s, ×0,45 al alejarse); no tiene vida ni se derrota con el láser; el **pulso** que alcanza el objeto apaga el tirón 3 s (como a una Oferta) y pone a cero el tiempo sobre él; (2) «sobre el objeto» = Isak en el suelo de la tarjeta (±6 px) y a ≤ 24 px del objeto en horizontal, `add_s` (1,5 s del mundo) seguidos; la deriva lo deja encima (se para a 4 px), así que **quedarse quieto en la tarjeta es comprar**; (3) «Añadido al carrito»: cartel de 2 s, una **Suscripción enganchada** a Isak (`Subscription.spawn` con anfitrión, como «ACEPTAR») y el objeto pasa al carrito: **deja de tirar el resto del intento** (una vez por plataforma); (4) objetos de §2.2 sin marcas: `watch` «Reloj que cuenta pasos», `headphones` «Cascos que aprenden lo que te gusta» y `course` «Curso de productividad extrema» (**propuestos**); (5) tachón: siempre `visible_only_with_debug`; la línea «arreglar la radio del Abuelito» (**propuesta**, `text` la cambia) la dibuja un **hermano** (`StrikeLine`, porque la pared abierta se oculta), se lee solo con el Debug revelando y, abierta la pared, se queda a la vista; (6) caja de Calc: **nunca con trampa** (`has_trap()` siempre falso aunque se ponga `trap`), precio `prices.calc_register` (2), lo pagado **no va a Devoluciones**; pantalla LCD dibujada sobre la puerta («Atajo: 2 ◆ / Trampa: 0»); Calc habla con su estilo `lcd` (interlocutor `calc`, no importante) la primera vez que Isak se acerca a ≤ 3 tiles («Atajo: 2 ◆. Trampa: 0. Sin letra pequeña. Soy una calculadora, no un vendedor.», el texto de §3.7) y al pagar («Precio: 2. Trampa: 0. Eco llama a esto mal negocio.», el de §4.2.1). **Desvíos:** sin `help_id` hasta el paso 9; en `deseos_test` detrás del tachón hay **un punto, no `msg_5_3`** (el mensaje y su secreto llegan con el 5-3 real, paso 14: `memory_pickup` exige el mensaje en `data/memories.json`); `tools/validate_level.py` no modela la lista de deseos, el tachón ni la caja (paso 8b): los toma por objetos sin colisión; los hoyos de la sala son de una fila y sin daño (el foso con pinchos y la escalera mecánica de §4.3 son del 5-3).
- **Paso 8a (2026-10-29):** `tools/world5_model.py` (nuevo; `LevelModel.w5`, `None` sin nada del Mundo 5) enganchado a `tools/validate_level.py` y `tools/level_plan.py` como los modelos de los Mundos 3-4. `lower()`: tachón → `glitch_wall` con `visible_only_with_debug`; cuenta sin `trigger` → `blink_platform` con su metrónomo `_cd_<id>` (ciclo `count_s` + `fold_s`, encendida `count_s`, empieza siempre; la espera del plan sale como `wait_countdown`); cuenta con `trigger` → tabla fija de 32 px (el camino frugal no paga, la trampa no salta); lista de deseos → `-`; «Prueba gratis» → `dnd_switch` con `ability: combo`. **Economía:** atajos y caja de Calc son puertas `pay` (sólidas hasta el pulso de espaldas) **prohibidas en el camino principal** (como las de un secreto, `secret_gates`); si la meta solo se alcanza pagando, error «arista obligatoria con precio»; cada tienda, atajo y caja de Calc cuesta como mucho los puntos que hay **antes en la ruta** desde un saldo de 0; el total, como mucho `max_spend_per_level`; saldo del intento (frugal y comprador) con Suscripciones acotadas a `drain_cap`, nunca por debajo de `min_balance`, y Devoluciones (lo drenado + lo pagado en atajos con trampa + `bonus_points`); «rollback» = lo gastado (se informa). `--buy` (CLI y `validate(..., buy=True)`): camino del **comprador** con los atajos pagables (inserta `pay_door` antes de cruzarlos, la trampa `processing` como espera de 1,5 s, `buy` en las tiendas por las que pasa reservando lo de los atajos, `refund`); con `--export-path` se exporta ese. **Tentación:** fuentes = Ofertas y deseos (zona y peso de los pasos 2 y 7); en el plan, andar alejándose va a 220 × mult − deriva (paso `resist_pull`), acercándose a 220 × mult + deriva; un salto alejándose que no llega con esa velocidad pide un pulso a la Oferta (3 s sin tirón) o es error; el dash y los combos la ignoran; regla: quieto en cualquier celda alcanzable de una zona nunca acaba **fuera del nivel** (los pinchos sí valen: −10 con salida) y alejarse andando siempre avanza. **Cajas:** sólidas en su celda; las abre el pulso de cara (en su fila) o el láser (la destruye); una caja que tapa el camino con `subscription`/`offer` sin el Debug es error; orden seguro: mirar dentro cuesta `LOOK_S` (1 s) de Debug (+ el láser) y las de energía devuelven 30. **Suscripciones:** al entrar el camino en su `wake_radius_px`, espera a que llegue, `cancel_subscription` (pulso o golpe al suelo) y láser si lo hay. **Decisiones tomadas:** (1) «antes en la ruta» = puntos cuyas celdas toca Isak antes (por tiempo, búsqueda sin pagar nada) que la celda desde la que compra, con **una celda de tolerancia** (al borde de la celda de compra ya toca la del punto de al lado); las cajas de puntos no cuentan (conservador); (2) el plan **no usa el golpe al suelo encima** de una caja (en el grafo dejaría a Isak sin suelo; en el juego sí la abre); (3) el comprador no compra lo que le dejaría sin pagar un atajo de su camino; (4) el «orden seguro» de las cajas es optimista (las de energía primero, sin la geografía ni los cargadores); la energía real del camino la sigue comprobando el plan. **Desvíos:** `cajas_test` gana un punto (columna 5) y `rebajas_test` dos (columnas 4-5): con 2 y 1 puntos antes, su atajo de 3 era impagable desde 0 (la regla de §3.1); la variante puerta `countdown_door` sigue sin existir; los efectos del pulso a la Oferta en el plan se cuentan 3 s de tiempo del mundo sin repetirlo.
- **Paso 8b (2026-10-29):** **Combinación** en el grafo (`abilities_available.combo` o la «Prueba gratis»; nunca con el Debug; 15 de energía en el plan): **Filo** = arista nueva desde los nodos comprimidos (`pinched_combo_edges`: salto comprimido en el sitio o andando, tramo de `distance_px` en `duration_s` con la caja comprimida y gravedad 0 desde el arco, caída comprimida a `end_speed_px_s`; exportado como `combo_edge` con `rails`); **Embestida** y **Sismo** = acciones que abren puertas: persiana (`shutter`, sólida; la rompe la onda de una Embestida —salto vertical, dash aéreo y diagonal de 45° a 960 px/s, nunca hacia un foso ni a pinchos ni desde encima de la propia persiana—) y grupo de estanterías (`shelf`, todas sólidas; las tumba un Sismo desde una celda comprimida con hueco para saltar si **todo el grupo** toca la franja de la onda, ±640 px y a ras del suelo). La ranura de precios no es puerta: sus etiquetas son **peligros del grafo** (empujan) y solo el Filo pasa por la ranura. **Anti-redundancia (§3.9):** cada persiana y grupo que abre el camino y cada ranura que cruza con un Filo hacen falta (sin ellos la meta no se alcanza; si no, error); los que el camino no usa y no son de un secreto (`gates`), error («se rodea sin su combo»); obstáculo sin Combinación posible en el nivel, error. **Regla de las estanterías** (pendiente del paso 7): ningún golpe suelto alcanza a dos del mismo grupo (separación ≥ la onda de la Embestida, 256 px; la del golpe al suelo, 192, y 2 × el radio del pulso). **Términos y condiciones:** «rechazar» abre la puerta con el láser desde un suelo de enfrente o con un Filo que roza el botón (paso `reject_terms`); «ACEPTAR» es otra puerta con precio (Suscripción), prohibida en el camino principal. **Lista de deseos:** ninguna parada sobre la tarjeta de `add_s` + lo que tarda la deriva en llevar a Isak al objeto. **Presupuesto de camino:** con `target_duration_s`, el validador da la duración del plan y su porcentaje y **avisa fuera del 40-55 %** (las salas de prueba no lo tienen). Salidas del validador de los Mundos 1-4 y de las arenas idénticas byte a byte (comparadas antes/después en las cinco pasadas, `--json` y los caminos exportados). `tests/test_world5_validator.py` (en `tools/run_tests.sh`). **Desvíos:** `combos_test` rehecha (las tres estanterías se saltaban por encima y el piso de arriba cruzaba sobre la persiana: el camino las rodeaba todas): pared en la columna 18 del piso de arriba, estanterías en las columnas 31, 36 y 41 (separadas 4 tiles) bajo un techo en la fila 9 con un hueco en las columnas 33-34 por el que se baja desde el piso de arriba (al que se sube por la repisa de una vía de (29, 10)); el Sismo sale de las columnas 32-35; la Embestida desde el piso de arriba, tras romper la persiana de suelo, cae por el hueco y rompe también la de pared (es lo que pide el doc: «rompe una barrera y limpia lo de debajo»); el paso `combo_ram` sale desde la celda de despegue con `land_px` (el bot del paso 11 tiene que seguir desde el aterrizaje); 8a y 8b van en dos commits pero el módulo entra entero en el 8a (8b = la sala, los negativos de los combos y el doc).
- **Paso 9 (2026-10-29), arte por script, ayudas Q, fichas del álbum y paleta:** **`tools/gen_world5_objects.py`** (`--check`, con validador de paleta y de las reglas de §6.1 en el dibujo: sin rojo de daño ni ámbar de los puntos, el blanco del Debug solo en lo que él revela —el icono de la trampa del atajo— y en el brillo de la «Prueba gratis», siempre con contorno `tienda_noche` de 1 px) dibuja en PNG lo que el juego dibuja por código: tienda (Sync y energía), atajo (cerrado, con la trampa que enseña el Debug y abierto), Devoluciones, caja sorpresa (cerrada, translúcida con el Debug y abierta), cuenta regresiva, Términos y condiciones, persiana (suelo y pared), ranura de precios, estantería de saldos (en pie y tumbada), «Prueba gratis», lista de deseos, tachón, caja de Calc y un cartel de rebajas (`assets/sprites/props/world5/`), y Oferta (de pie y colgada) y Suscripción (`_placeholder`; `assets/sprites/enemies/world5/`). **Tileset** del centro comercial (`tools/gen_world5_tiles.py`: las piezas del Mundo 1 repintadas, baldosa `gris_escaparate` con el brillo del canto en `crema_sombra`; `data/tileset_mundo5.json`, `assets/tilesets/mundo5.tres` con `tools/build_tileset_mundo1.gd -- --map res://data/tileset_mundo5.json`) y **fondo** en tres capas sin costura (`tools/gen_world5_background.py`: galería con escaparates apagados, maniquíes, precios pequeños y la escalera mecánica en paralaje, neones tramados; `data/world5_background.json`, `scenes/levels/world5_background.tscn` con la clase nueva `World5Background`, que hereda de `World1Background` y queda para el audio del paso 20); validador **`tools/validate_world5_tiles.py`** (atlas, mapa, `validate_tileset`, capas en la paleta, costuras y contraste: Isak ≥ 3:1 en el 99,7 % del fondo y el 94,9 % de las baldosas, peor color dominante 8,1:1 y 6,1:1; Eco, 8,2:1 y 6,2:1). Las 6 salas del Mundo 5 se regeneran con ellos (los Mundos 1-4, idénticos: `build_level.py --check`). **Ayudas Q** (`world: 5`, textos **propuestos**) y `help_id` de 14 tipos: objetos `shop_item`, `surprise_box`, `refund_desk`, `shortcut_door`, `countdown_platform` (5-1), `shutter`, `price_rail`, `clearance_shelf`, `calc_register` (5-2), `terms_gate`, `wishlist_platform`, `wish_strike` (5-3); enemigos `offer_sign` y `subscription` (5-1), en `data/world5_objects.json` y `data/enemies/*.json`; las Ofertas y Suscripciones que salen en el juego (cajas, atajos con trampa, «ACEPTAR», lista de deseos) llevan la Q de su tipo (`OfferSign.spawn` nuevo, `Subscription.spawn`). «Lo destruido no ayuda» con los `is_help_available()` de los pasos 2-7 (tienda agotada, atajo o caja de Calc abiertos, Devoluciones cobradas, caja abierta, Términos abiertos, persiana rota, estantería caída para siempre, deseo en el carrito, tachón disuelto, Oferta o Suscripción derrotadas; siguen ayudando la ranura, la cuenta y las aturdidas); 13 casos nuevos en `tests/test_help_inert.gd`, el bucle del Mundo 5 en `tests/test_help.gd` y los del álbum en `tests/test_notas_album.gd`. **Fichas del álbum** de los 14 (`tools/gen_album_cards.py`; el atajo, con la trampa revelada). **Paleta:** `tools/palette_mundo5_variants.py` con **3 variantes** (A «Neón de madrugada», la provisional pulida; B «Cierre a medianoche»; C «Rebajas violeta»), las 7 reglas de §6.1 en `--check` para las tres y la comparativa con maqueta `docs/arte/mundo5_paleta_variantes.png`; `--apply` escribe `assets/palettes/mundo5.gpl` (se borra la provisional), la sección `palette` y regenera el arte, el tileset, el fondo y las fichas. **Decisión tomada (con la autoridad delegada; criterio: las reglas de contraste de §6.1): variante B «Cierre a medianoche»**: la de mayor margen mínimo de contraste (×2,70 frente a ×2,51 de A y ×2,34 de C; la regla más justa en las tres es Isak sobre el negro: 8,1:1 frente a 7,5 y 7,0), y también la de mayor contraste del contorno sobre el amarillo (15,8:1) y sobre el tinte del Debug (17,1:1); C, además, acerca el amarillo al ámbar de los puntos (ΔE 36 frente a 41). El blanco del Debug sigue en `#ffffff`. Se cambia con `--apply A|C`. **Contraste en capturas** (criterio del paso): `tools/render_world5_rooms.gd` (con ventana) captura las 6 salas con Isak y Eco en dos sitios y la misma vista sin ellos, y `tools/measure_world5_contrast.py` mide el cian de Isak y la esfera de Eco frente a lo que tienen detrás: las 24 cajas ≥ 3:1 (Isak ≥ 3:1 en el 96,7-100 % de su caja, peor color dominante 6,1:1; Eco, 100 %, 6,2:1); selección en `docs/capturas/mundo5-paso9-2026-10-29/`. Nuevas comprobaciones registradas en `tools/run_tests.sh` (las capturas no: necesitan ventana). **Decisiones tomadas** (el doc no lo decía): (1) **un solo generador** para objetos y enemigos (`gen_world5_objects.py`, no `gen_world5_enemies.py` aparte), como en el Mundo 4: comparten paleta y validador; (2) **en el juego los objetos siguen dibujándose por código** (como en los Mundos 3 y 4): los PNG son referencia, fuente de las fichas y de la maqueta; el tileset y el fondo sí son del juego; (3) **sin Q ni ficha la «Prueba gratis»** (es historia, como la Papelera del Mundo 4); (4) el tachón hereda de la pared con glitch: su Q sale aunque no se vea (como en «Excepciones»); (5) las ayudas dicen «puntos», no «◆». **Desvíos:** (1) **Eco se ve igual que en los Mundos 1-3** (cambio de requisito del usuario del 2026-10-29, por el orquestador): **no hay «Eco de luz» del Mundo 5** (§6.3 queda sin efecto en ese punto); la regla 7 de §6.1 mide la esfera de siempre (`ECO_COLORS` en `tools/palette_mundo5_provisional.py`); (2) las miniaturas de nivel, `world_icon_m5` y la puerta «Pagar» de §6.3 quedan para el paso 10 (con el 5-1 y las filas de M5); (3) el tinte del Debug es común a todos los mundos (`data/debug_mode.json`): el «Debug blanco que baja la saturación» de §11.2 no se ajusta aquí; (4) `tests/test_text_font.py` falla ya en `07ce2a0` por el aviso `combo` del paso 1 (`=`, `_`, `{`, `}` no están en la fuente): no es de este paso (**arreglado el 2026-10-29**: el aviso ya no usa «=» y la prueba quita las marcas `{key:<acción>}`, que el juego sustituye por la tecla); (5) `CLAUDE.md` no se toca (su línea de decisiones abiertas sobre los hex del Mundo 5 la actualiza el orquestador o el usuario).
- **Paso 10 (2026-10-29), el 5-1 «Oferta del día» real:** `data/levels/5-1.json` (escena `scenes/levels/5-1.tscn`, subidas `tests/fixtures/climbs_5-1.json`, 22) **por plantas desde el principio**: tres pasadas por tramo (suelo en la fila 12, B2 de una vía en la 9 y B3 en la 6, 3 filas entre ellas), los tramos 1 y 3 suben (escalones de una vía en las filas 10 y 7 en los extremos) y el 2 y el 4 bajan (B3 sin huecos, caída a B2 al final y pozo de 1 columna al suelo). Piezas: Oferta de pie con el carrito (patrón 23) y dos colgadas en el Tramo 1 (una tira hacia un hueco de B3 con caída de 3 a B2); tienda (+25 Sync por 3 y +40 energía por 2) a mitad de B2 del Tramo 2 con «Llévate dos» enfrente; `sync_1` en la Pausa; cuatro cajas en B3 del Tramo 3 (patrón 24) y la primera Suscripción suelta; atajo con trampa `subscription` «Atajo: 3» al final de B3 del Tramo 4 que se salta B2 y el suelo; la cuenta regresiva (3 tiles) sobre un foso mortal de 5 columnas (patrón 28); la puerta **«Pagar»** (`exit_terminal` con el aspecto nuevo **`checkout`**, `tools/gen_world5_exit_checkout.py --check`, y la placa `offline_text` «Total: 0. Gracias por mirar.»). **`msg_5_1`** del **Abuelito** («Devolución», firma «Abuelito (desde el taller)»; `tests/test_memories.py` acepta al Abuelito como remitente del Mundo 5) en el secreto A; **`vida_extra_5_1`** en el C. **Hub:** filas M5 (5-1 jugable; 5-2 y 5-3 «Nueva oferta» y El Vendedor, `playable: false`, «Próximamente»), **sin tocar el desbloqueo** (`unlocked_by: ["4-boss"]`, página 2, columna 14); miniatura **`world_icon_m5`** (etiqueta con el rombo) e iconos `menu_level_5_*` en `tools/gen_hub_objects.py`; **línea de Calc** `spent_5_1` con el marcador nuevo **`{gastado}`** y `text_if_zero` (`HubRoom.calc_remark_text`; `GameState.get_attempt_spent(nivel)`: lo gastado en el último intento del nivel menos lo devuelto, mismo ciclo de vida que el registro de Devoluciones, no se guarda). **Validador** (todas las pasadas: sin mejoras, `wide_pulse`, medias, máximo y `--access-cap`, OK sin avisos): camino frugal **207,5 s = 43 %** de 480 en las cinco; comprador (`--buy`) **183,8 s** (paga el atajo, compra la energía, saldo mínimo 0). Economía: 3 cosas con precio, 8 en total; tienda con 6 puntos antes en la ruta y atajo con 7; el frugal no gasta nada. Sin el dash el camino principal sigue (solo B y C lo piden). Pruebas: `tests/test_level_5_1.py` (11) y `tests/test_level_5_1.gd` (9), la subida del 5-1 en `tests/test_level_climbs.gd`, y ajustadas `tests/test_hub_boss_entry.gd` (M5 ya no está vacía) y `tests/test_memories.py`; registradas en `tools/run_tests.sh` (también el camino del comprador exportado). **Decisiones tomadas / desvíos:** (1) **260 × 14, no 200 × 14**: con 200 columnas el camino daba 157 s (33 %); se ensancharon los cuatro tramos (§4: «se alarga con otra pasada, no con esperas»), así que las columnas de §4.1 se desplazan (Inicio 0-13, T1 14-80, T2 81-135, Pausa 136-140, T3 141-195, T4 196-249, Cierre 250-259); (2) **bajo una banda no se salta un pincho** (la holgura de techo del validador frente a la banda de una vía) y **dos pinchos seguidos piden el dash** (hueco + ancho de Isak > 85 % del salto andando): el carrito del patrón 23 es **un pincho** y está al final del Inicio, antes de B2; la Oferta de pie del Tramo 2 no lleva carrito; (3) **secreto A en lo alto de la pared izquierda del Tramo 3** (encima de la Pausa, junto al escalón de B2 a B3 y antes de las cajas), no en la derecha: encima de B3 no cabe un cuarto al que se llegue saltando (el salto completo desde la fila 5 o más arriba choca con el techo del nivel con la holgura de 16 px) y debajo pasa el camino; (4) **los 2 puntos del secreto A son los de Devoluciones** (`bonus_points` de `data/economy.json`): 8 en la rejilla + la caja de 2 + esos 2 = 12; reparto de la ruta 1 / 2 / 3 / 0 (+ la caja) / 1 / 1 para que antes de la tienda haya 6 (el comprador del validador reserva el atajo antes de comprar); (5) **secreto B**: el validador no modela el «tercer ciclo» de 10 s, así que la repisa del power bank se alcanza con salto + dash aéreo desde un escalón de las columnas 242-243 (el tercer ciclo solo da más tiempo); el comprador, que llega por la repisa alta del atajo, lo tiene más fácil; (6) el atajo **no lleva «directa al Cierre»**: deja a Isak en una repisa alta antes de la cuenta regresiva (la cruza igual); (7) **sin cartel «¡Bienvenido! Todo al 50 %»** (no hay `decor` de texto en el Mundo 5; la bienvenida es la línea de Eco, propuesta) y **sin Oferta de pie al otro lado del foso** (su tirón llevaría a Isak quieto al foso mortal; la del otro lado es la colgada del secreto C, que solo tira en lo alto); (8) `HubWorlds.level_points_total` cuenta **cada caja de puntos como un punto del nivel** (se captura como `box:<id>`; el 5-1 da 9 en la carpeta); (9) `tools/level_climbs.py` baja también las piezas del Mundo 5 (`world5_model.lower`; los Mundos 1-4 no cambian, `--check` al día). Textos nuevos **propuestos**: la línea de Eco del Inicio, la placa de la puerta, el comentario de Calc y `msg_5_1`.


---

## 9. Decisiones tomadas (2026-10-28, por el orquestador con la autoridad delegada por el usuario)

Cada una se puede cambiar cuando el usuario pruebe el mundo.

1. **Decisión tomada: mecánica central = querer cuesta** (gastar puntos dentro del nivel, cajas que se miran con el Debug, atajos con trampa y la tentación como fuerza sobre el movimiento; §3). *Razón:* es lo que pide la ficha (`01` §5, `mundo-5` §10.2) y es distinta de los Mundos 1-4: el reto es **decidir y resistir**, no solo ejecutar.
2. **Decisión tomada: se gastan los puntos reales**, con cuatro protecciones (nada obligatorio cuesta, todo se puede pagar con lo cogido antes en el nivel, sin deuda, Devoluciones) y **12 puntos por mapa** (§3.1). *Razón:* C3 dice «por primera vez se gastan dentro de un nivel»; un saldo aparte lo contradiría. Los 3 puntos extra por mapa hacen que la economía de Calc no empeore para quien no compra.
3. **Decisión tomada: la Combinación son los tres pares de gestos que hoy se excluyen** (dash + golpe = Embestida, Pellizcar + dash = Filo, Pellizcar + golpe = Sismo), solo en el aire, 15 de energía, sin tecla nueva (§3.2). *Razón:* «encadenar dos gestos en el aire» (doc); no toca `project.godot` ni el mando; las restricciones de hoy (`dash_denial`, `ground_pound_denial`) marcan exactamente dónde cabe el súper movimiento.
4. **Decisión tomada: Sismo redefinido como Pellizcar + golpe al suelo**, onda que recorre toda la planta en pantalla y rompe «a la vez» (§3.2.4). *Razón:* Agitar se retiró; el doc pide «rompe plataformas a la vez y aturde a toda la pantalla», y eso es algo que el pulso **no** hace (lección de Agitar).
5. **Decisión tomada: cada verbo nuevo con un obstáculo propio y una prueba negativa** (§3.9). *Razón:* la lección de Agitar («hace lo mismo que el pulso»).
6. **Decisión tomada: tentación = fuerza horizontal con números fijos** (deriva 60 px/s, ×0,6 al alejarse, ×1,15 al acercarse, suma con tope), que el dash y los combos ignoran y el pulso apaga (§3.3). *Razón:* «se siente en el movimiento, que se vuelve más pesado al alejarse» (doc), y con números constantes el validador la modela exacta.
7. **Decisión tomada: cajas sorpresa con contenido fijo en los datos, nunca aleatorio** (§3.4). *Razón:* las ayudas nunca mienten, y el validador y los bots necesitan determinismo; la sorpresa es para el jugador.
8. **Decisión tomada: los tres niveles horizontales por plantas desde el principio** (tres pasadas por tramo, alternando subir y bajar) y **presupuesto de camino antes de dibujar** (§4). *Razón:* la lección del Mundo 4 (los mapas orientativos daban caminos de 60-100 s y hubo que rehacerlos en bandas); un centro comercial se recorre así de todos modos.
9. **Decisión tomada: daño a El Vendedor = ponerse detrás → Debug → pulso marca → láser**, un golpe por marca, 9 golpes en Caché y 12 en Kernel y Raíz; la máquina **siempre se gira hacia Isak** y cada fase es una forma de quedarse detrás (pagar, devolver, combinar) (§5). *Razón:* la regla de V14, ya probada en tres jefes, y «botón de Cancelar en la parte trasera» (doc) como regla de la pelea.
10. **Decisión tomada: duración** objetivos de **480 / 540 / 600 s** (los 8, 9 y 10 min del doc) y **camino del validador entre el 40 y el 55 %** (§4). *Razón:* el Mundo 3 se quedó en el 19-27 % y el Mundo 4, rehecho, en el 41-49 %.
11. **Decisión tomada: fichas en la arena del jefe**, no puntos de atención, con «te fío» a 0 (§5.2). *Razón:* un jefe no puede depender del saldo con que llega el jugador; la deuda como red de seguridad mantiene el tema.
12. **Decisión tomada: reutilizar la congelación con daño al liberarse** en la trampa `processing` y en la fase 3 («Procesando pago…»), y la Linterna en un secreto del 5-3 (§3.7, §4.3.1, §5.6). *Razón:* lo aprendido sigue en uso sin inventar piezas; ninguna de las dos es obligatoria en el camino.
13. **Decisión tomada: Isak habla por primera vez** en un cuadro de texto (interlocutor `isak`), solo la línea del doc (§4.2.2). *Razón:* el doc la escribe; sin ella la escena pierde el sentido del gesto.
14. **Decisión tomada: Calc aparece en el 5-2 como su caja registradora con LCD**, no como actor (§4.2.1). *Razón:* `04` §12.3 («regenta la tienda oculta de atajos legítimos»); Calc vive en el hub y el LCD ya es su voz.
15. **Decisión tomada: sin rojo en los enemigos ni en los carteles** (precio tachado en magenta; el rojo solo para los pinchos y el «Cancelar») (§3.7, §6.1). *Razón:* la petición del usuario del Mundo 4 (cambio 5) y la regla del rojo = daño.
16. **Decisión tomada: vida extra en el 5-1** (N = 3), **3 power banks** y **36 puntos** en el mundo (§4). *Razón:* la economía de los mundos anteriores más los 3 puntos «para tentar» por mapa.
17. **Decisión tomada: prueba del usuario temprana** tras el 5-1 (paso 12) (§8). *Razón:* en el Mundo 4 las peticiones del usuario al jugar (Modo oscuro casi negro, peligros ocultos, sin contorno rojo, Agitar retirado, daño al liberarse, ola más rápida) llegaron con los tres niveles hechos y obligaron a rehacer; probar el primero antes ahorra eso.
18. **Decisión tomada: Kernel y Raíz del jefe solo a alto nivel** (§5.8). *Razón:* plan de producción: primero los 18 niveles en Caché.

---

## 10. Decisiones para el usuario (con recomendación por defecto)

Solo las de gusto personal o las reservadas al usuario. Si no hay objeción, se aplica la recomendación.

1. **El blanco del Debug del Mundo 5** (§6.1; hoy `#f4f4f4` provisional en `debug_colors["5"]`; también es el color de la quinta pieza del hub). **Recomendación: A «Blanco puro» `#ffffff`**, lo que dice el doc: el que más destaca sobre el negro y los neones; el parecido con el texto del HUD no confunde (otra capa, otro papel) y las reglas 2-3 de §6.1 protegen la lectura. Las otras: **B «Blanco tiza» `#e8f0ff`** (algo frío, «fluorescente de almacén») y **C «Plata neón» `#d6e4ff`** (la que más se separa del texto del HUD, pero ya no es blanco puro y se acerca al cian de Isak). Comparativa con maqueta en el paso 9; el blanco se aplica en el paso 0.
2. **Remitente de los mensajes `msg_5_x`** (§4.5). **Recomendación: el Abuelito** (el Mundo 5 es el de la voluntad y su recuerdo de jefe es él y las radios; en el Mundo 4 fueron los amigos y en los Mundos 1-3, Mamá). Alternativa: Mamá, o uno de cada (Abuelito, Mamá y Abuelito).
3. **Créditos de AutoSprite** (§6.2) para el paso 24, **cuando los niveles y el jefe estén jugables**: **57-60** en una pasada (hasta ~120 con reintentos) de **249**, para El Vendedor y las tres poses de combo de Isak; la Suscripción (+21) es opcional. **Recomendación:** aprobarlo para el paso 24 sin la Suscripción, con parada tras el personaje base. Hasta entonces, **0 créditos**.

---

## 11. Riesgos y qué debe revisar el usuario al probar

### 11.1 Lecciones del Mundo 4 aplicadas desde el principio

| Lección | Qué pasó en el Mundo 4 | Qué cambia en el Mundo 5 |
|---|---|---|
| **El usuario pide cambios al jugar** | El Modo oscuro le pareció claro («que solo se pueda ver con la lámpara»: velo del 75 % al 93 %), pidió peligros ocultos en lo oscuro (acechadores), quitar el cuadro rojo de los enemigos, quitar Agitar y que la congelación dañe al liberarse; todo con los tres niveles ya hechos. | **Prueba temprana** tras el 5-1 (paso 12) y sus gustos ya aplicados: sin contorno rojo en enemigos, peligros que se anuncian por su aviso, congelación que duele al soltarse, nada redundante. |
| **Un verbo nuevo que repite otro se cae** | Agitar «hace lo mismo que el pulso». | Tabla de anti-redundancia (§3.9) y una prueba negativa por verbo; el Sismo, redefinido para no ser «un pulso grande». |
| **Caminos cortos** | Los mapas orientativos del 4-1, 4-2 y 4-3 daban caminos de 60, 80 y 100 s frente a 170-250 pedidos; se rehicieron en **bandas** (pasarelas que se recorren enteras, 3 filas entre ellas para que no haya atajos). | Plantas de tres pasadas desde el primer mapa y **presupuesto de camino** por tramo; el validador avisa fuera del 40-55 %. |
| **El validador y los bots tienen que modelarlo todo** | El paso 9 del Mundo 4 fue XL; varias piezas se movieron porque el validador o el bot no cuadraban con el juego (pinchos con otro hitbox, Trolls que veían al bot antes de tiempo). | Mecánicas diseñadas para ser modelables (fuerzas constantes, cajas fijas, nada aleatorio); cada sala de prueba de los pasos 2-7 entra en el validador en el paso 8 **antes** de dibujar un nivel; una pieza sin modelo no se coloca en un nivel. |

### 11.2 Riesgos

- **Tentación y sensación de control:** una fuerza sobre Isak puede sentirse como «el juego me mueve». Mitigación: números pequeños, siempre se sale andando, el dash la ignora y se ve antes de sentirse. **Revisar al jugar:** si 60 px/s y ×0,6 molestan o no se notan.
- **Gastar puntos reales:** un jugador puede gastar de más y no llegar al máximo de Calc en tres vueltas (450 puntos, exigente a propósito). Mitigación: precios bajos, 3 puntos extra por mapa y Devoluciones. **Revisar:** si los precios tientan o dan igual.
- **Entrada de los combos:** el Filo y el Sismo empiezan con Pellizcar en el aire; puede costar a la primera. Mitigación: Q en cada tramo, el patrón de la sala «Paquete completo» y el escalón de práctica. **Revisar:** si la secuencia es cómoda con teclado y con mando.
- **Debug blanco que lava la pantalla:** el tinte puede cansar. Mitigación: el tinte del Debug del Mundo 5 baja la saturación más que subir el brillo (se ajusta en el paso 9 con capturas). **Revisar** en la maqueta.
- **El Vendedor que se gira:** si gira demasiado rápido, la fase 1 frustra; si gira lento, no hay tensión. Palanca en datos (`turn_s`).
- **Isak habla:** primera vez; su estilo y su icono son nuevos. **Revisar** si se lee bien y si se quiere más (o nada) en Kernel y Raíz.
- **Textos propuestos:** todos (carteles, Eco, Isak, Calc, El Vendedor, ayudas Q, mensajes del Abuelito). La lista detallada irá a `preguntas.md` en el paso 23.
