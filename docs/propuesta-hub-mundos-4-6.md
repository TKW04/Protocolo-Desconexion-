# Propuesta: acertijo del hub y entrada a los Mundos 4-6 («Actualización del sistema»)

Estado: **PROPUESTA (2026-10-27), sin implementar.** Solo documento: no cambia código ni datos.

**Idea del usuario (se respeta tal cual):** al vencer a La Curadora (jefe del Mundo 3) se habilita en el hub un acertijo. Resolviéndolo con las habilidades que Isak tiene hasta ahora se hace un *upgrade* del hub y aparecen las entradas de los Mundos 4, 5 y 6, cada uno con sus subniveles.

**Corrección del usuario (2026-10-27) sobre el desbloqueo:** el acertijo hace **visibles** las tres carpetas (M4, M5 y M6), no jugables. El desbloqueo es **en orden**: el 4 está disponible nada más resolver el acertijo, el 5 al completar el Mundo 4 (jefe incluido) y el 6 al completar el Mundo 5 (jefe incluido).

Documentos con los que encaja (no se contradicen; lo nuevo va marcado **PROPUESTA**): `05-hub.md` (§13.2 páginas, §13.4 piezas del fondo), `propuesta-hub-y-guardado.md` (§2 mapa, §3 estaciones y carpetas, §4 guardado), `propuesta-asistentes-y-vidas.md` (vidas, Papelera, rollback), `propuesta-recuerdos.md` (capas por jefe, fragmentos del candado de La Nube), `propuesta-mundo-3.md` §4.6 (hoy `m4.unlocked_by: ["3-boss"]` sin carpeta física), `propuesta-1-2.md` §4 (acertijo «Correo certificado», el precedente) y `mundo-4-chat.md`, `mundo-5-tienda.md` y `mundo-6-nube.md`.

---

## 0. Resumen

- **Al volver de vencer a la Curadora** (tras encenderse la pieza verde ácido) el borde derecho de la página 1 del hub tiene un glitch, el indicador de páginas muestra un segundo punto que parpadea («Descargando…») y Calc lo comenta. El borde derecho deja pasar a una **página 2 «en instalación»**.
- **El acertijo «Actualización del sistema»** está en esa página 2: un instalador con **tres verificaciones**, una por cada pieza del fondo ya recuperada, en el color del Debug de su mundo. Cada una pide las habilidades de ese mundo: **cian** (Debug, láser y pulso, como el 1-2), **ámbar** (golpe al suelo, salto y dash aéreo) y **verde ácido** (láser con espejo y Pellizcar). Se hacen en cualquier orden. Con las tres, un pulso al instalador lo instala.
- **El upgrade:** la página 2 pasa a su forma final con las carpetas **M4 y M5**, y se abre la **página 3** con la carpeta **M6 (La Nube)**, como dice `05` §13.2. Las tres se ven a la vez: M4 **disponible** y M5 y M6 **bloqueadas** (candado y silueta, «Sin descargar»). La pieza 4 del fondo (coral) pasa a «contorno que parpadea».
- **Desbloqueo en orden:** `m4` con el acertijo (más `3-boss`), `m5` con `4-boss` y `m6` con `5-boss`. El candado de La Nube, con 5 ranuras de fragmento (`05` §13.2), se abre justo al vencer al quinto jefe.
- **Sin riesgo:** en el hub nada hace daño, así que no se gastan vidas, no hay muerte ni rollback dentro del acertijo y nada queda roto para siempre. Lo temporal vuelve solo y hay un cargador en la página.
- **Plan:** 11 pasos pequeños (§5.2). Primero los datos y el guardado, después el hub de varias páginas, el acertijo, el validador, la instalación, los textos, el arte, el bot y las pruebas de conjunto.

---

## 1. Qué ve el jugador al volver al hub tras vencer a La Curadora

Orden de la llegada (lo que ya existe no cambia: vórtice, pieza verde, Calc si toca):

1. **Llegada por el vórtice** en P, como siempre.
2. **Se enciende la pieza verde ácido** del fondo (`HubRoom.light_piece_world`, 3 destellos en 0,9 s; ya implementado).
3. **PROPUESTA: el «aviso de actualización»**, justo después de la pieza (así se entiende que una cosa trae la otra):
   - El **borde derecho de la página 1** (columna 19, filas 5-8) muestra un glitch en los tres colores de las piezas encendidas (cian, ámbar y verde ácido), que parpadea un cuadro cada 1,5 s. La pared invisible de ese borde se quita: Isak puede salir por la derecha.
   - El **indicador de páginas** (fila 10) pasa de 1 punto a 2. El segundo punto está apagado, con un relleno que «carga» en bucle.
   - **Calc** (comentario de llegada, el sistema `calc.remarks` que ya existe, con `after_level: "3-boss"`; no es importante, no pausa y sale una vez por partida guardada). Texto **PROPUESTO**: «Actualización detectada. Tamaño: 3 apps. Precio: 0. Sospechoso.». **Razón:** Calc ya comenta las llegadas con su humor seco (`likes_3_1`). Reutilizar `remarks` no cuesta código, y Calc es la aliada que ve los «precios» (anticipa La Tienda).
4. **Al cruzar a la página 2 por primera vez** (línea importante: pausa, una vez por partida guardada, `seen_notices hub_update_intro`):
   - **Eco** (atenuado, sin cobertura; solo habla en momentos de historia, como en la presentación de Notas). Texto **PROPUESTO**: «¿Una actualización? Instálala, {apodo}. Las actualizaciones siempre mejoran algo.». **Razón:** es la voz de Eco del Mundo 3 («te ofrece una versión mejor de ti») y la ironía queda para el jugador, sin inventar historia. Que el hub crezca es algo bueno (`05` §13.4: el hub se va llenando).
   - Pantalla del instalador, solo texto de interfaz: «Actualización del sistema · Verificaciones 0/3 · No apagues el dispositivo».

**PROPUESTA: el aviso aparece aunque se cargue una partida guardada** (§3.4). No depende de haber vivido la llegada: sale siempre que `3-boss` está en `completed_levels` y el upgrade no está instalado. El comentario de Calc sale solo si se llega desde el jefe. Quien carga la partida ve el glitch y el segundo punto. **Razón:** quien ya venció a la Curadora antes de este cambio tiene que encontrarse el acertijo al cargar (corrección del usuario).

---

## 2. El acertijo del hub

### 2.1 Opciones

| Opción | Qué es | Pros | Contras |
|---|---|---|---|
| **A. «Actualización del sistema»: tres verificaciones en la página 2 (RECOMENDADA)** | Un instalador con tres verificaciones, una por pieza del fondo encendida (cian, ámbar y verde), cada una con las habilidades de su mundo, en cualquier orden. Un pulso final instala. | Usa **todas** las habilidades conocidas (pulso, láser, Debug, Deslizar, golpe al suelo y Pellizcar), como pide la idea. Une el acertijo con las piezas del fondo (lo que ya cuenta el hub). Estrena la página 2 antes de que tenga carpetas, así que el sistema de páginas se prueba con contenido real. El orden libre evita los atascos. | Es la opción más grande: hace falta el hub de varias páginas y unas 4 piezas nuevas sencillas. |
| B. Una cadena en la página 1 (como «Correo certificado») | Un solo recorrido en orden por encima de las repisas: Debug → láser → pulso → dash → Pellizcar. | Más barata: no necesita páginas. | La página 1 está llena (carpetas en las columnas 4, 10 y 16, estaciones en el dock y la foto del fondo arriba). Mete ruido en la sala tranquila y el orden obligatorio castiga más. |
| C. «Recomponer la foto» | Mover o girar con el pulso las piezas del fondo. | Muy temática. | Solo usa el pulso: **no** cumple «con las habilidades que tiene hasta ahora». |
| D. Contrarreloj de instalación | Una barra que se vacía mientras se activan interruptores repartidos. | Tensión. | El hub es silencioso y tranquilo (`05` §13.1): la prisa no encaja. |

**Recomendación: A.** Es la única que cumple la idea completa (todas las habilidades), mantiene el hub tranquilo (sin enemigos, sin daño y sin prisa salvo ventanas cortas, como en el 1-2) y deja montadas las páginas que de todos modos hacen falta para las carpetas M4, M5 y M6.

### 2.2 Página 2 «en instalación» (PROPUESTA; 20 × 11 tiles, el mismo dock como suelo en la fila 9)

```
col   0    2    4    6    8   10   12   14   16   18 19
fila0 [HUD hub: ⚙ ✈ ··························· ◆ pts  ● sin guardar]
  1   |  «Actualización del sistema · Verificaciones 0/3»           |
  2   |                                                             |
  3   |                                           [espejo]           |
  4   |        [RE]                    [V2]                         |  V2 en repisa alta
  5   |        ====      [INSTALADOR]  ====                [lector3] |
  6   |  [glitch]          (2x3)                                     |
  7   |  [lector1]  [V1]                    ▓▓ (sale)   [marco]     |
  8   |        P←  [cargador]              [placa]      [  V3 ]     |  V3 en el nicho
  9   |=== DOCK (suelo) ============================================|
 10   |            ○ ● ○ (indicador: página 2)                      |
```

Las posiciones son orientativas y se fijan con las medidas de `data/isak_physics.json` (salto real de unos 184 px a 60 Hz, dash aéreo) en el paso 4 (validador). Se usan las piezas que ya existen: `charger`, `laser_receiver`, `relay_receiver`, `mirror`, `small_frame` y el contorno revelado por el Debug. Son nuevos el `hub_installer` y la `update_check` (la verificación), y una `pound_plate` sencilla.

| Id | Tipo | Qué hace |
|---|---|---|
| `instalador` | **nuevo** `hub_installer` (estación `HubStation`, 2 × 3, columnas 8-9) | Pantalla «Verificaciones n/3». Con 3/3, un pulso de espaldas instala (§3.1). Con menos, el pulso solo muestra en el panel qué falta, con los pictogramas. |
| `cargador_p2` | `charger` (existe; el del hub, 50 de energía, 20 s) | Junto a la llegada de la página. Energía para el Debug y los láseres. |
| `V1` cian «Integridad» | `update_check` (nuevo: terminal de 1 × 2 que se enciende y queda encendida) + `laser_receiver` oculto + `relay_receiver` | Ver §2.3, paso V1. |
| `V2` ámbar «Búfer» | `update_check` + `pound_plate` (nuevo: placa que responde a `EventBus.ground_pound_landed` dentro de su caja) + plataforma temporal | Ver §2.3, paso V2. |
| `V3` verde ácido «Recorte» | `update_check` dentro de un nicho + `mirror` + `laser_receiver` + `small_frame` (marco pequeño que da paso al nicho) | Ver §2.3, paso V3. |

Cada verificación lleva un **marco del color del Debug de su mundo** (cian `acento_cian` del hub, ámbar `#ffa858` y verde ácido `#a6ff2e`) y un **pictograma de las habilidades** que pide (los iconos de los chips de Calc para pulso, láser y Debug, y otros nuevos para Deslizar, golpe al suelo y Pellizcar). **Sin rojo:** en el hub nada hace daño.

### 2.3 Pasos de resolución

Las verificaciones **V1, V2 y V3 se hacen en cualquier orden**. Cada una queda encendida al completarla (durante la visita, §2.6).

- **V1 cian «Integridad»** (Mundo 1: Debug, láser y pulso; patrón 2 de `propuesta-1-2.md` §0.3, como «Correo certificado»):
  1. En la pared izquierda hay un glitch. **Con el Debug** se ve que esconde `lector1` (un `laser_receiver` que solo se ve con el Debug, como las plataformas ocultas del 1-2).
  2. **Láser** a `lector1` desde el suelo (el láser solo se dispara en el suelo). El cable que sube a `RE` (`relay_receiver` sobre la repisa de una vía de la columna 4, a 160 px) se enciende durante **6 s**.
  3. Un salto a la repisa y **pulso** a `RE` con el cable encendido. `V1` se enciende.
- **V2 ámbar «Búfer»** (Mundo 1-2: golpe al suelo, salto y dash aéreo):
  1. **Golpe al suelo** sobre la `placa` (columna 13). Del dock sube una plataforma «Cargando…» de 2 tiles (`▓▓`) durante **3 s**, con un aviso de 0,5 s antes de bajar.
  2. **Salto** a la plataforma y **salto con dash aéreo** hasta la repisa alta de `V2` (columnas 13-14, fila 4), que está más lejos de lo que llega un salto solo.
  3. **Pulso** de espaldas a `V2`. Se enciende.
- **V3 verde ácido «Recorte»** (Mundo 3: espejo, láser y Pellizcar):
  1. **Láser** desde el suelo (columna 14 o menos) al `espejo` de la esquina. Rebota hacia abajo, a `lector3`. El `marco` del nicho se ilumina (es el «recorte»). Esto es permanente durante la visita: no hay ventana.
  2. **Pellizcar** y entrar comprimido por el `marco` (hueco de 1 tile) al nicho, que mide 2 tiles de alto por dentro para poder volver al tamaño normal.
  3. **Volver al tamaño normal** dentro del nicho y **pulso** a `V3` (comprimido no hay pulso: lo enseñó el Mundo 3). Se enciende.
- **Instalar:** con 3/3, pulso de espaldas al `instalador` (§3.1).

Duración estimada: 60-90 s (unos 20-30 s por verificación). Energía mínima: Debug unos 2 s + 2 láseres. El cargador y el llenado al entrar al hub la cubren con margen; la cifra exacta la da el validador (paso 4).

**Habilidades:** todas están obtenidas al vencer a la Curadora (Debug en el 1-2, láser en el 1-1/1-2, Deslizar en el 1-3, golpe al suelo en el Mundo 2 y Pellizcar en el 3-2). **PROPUESTA:** en el hub se pueden usar todas las **obtenidas**. Hoy `HubRoom._enter_tree` respeta las obtenidas, pero llama a `DebugMode.reset()` al entrar. Hay que comprobar en el paso 2 que el Debug obtenido se puede usar en el hub; si no, se añade `abilities_available.debug: true` solo con el acertijo activo.

### 2.4 Pistas progresivas (PROPUESTA)

El hub no tiene ayuda con Q (`data/hub.json`, `charger._notes`), así que se dan sin la Q:

1. **Siempre (pista visual):** el marco de color y el pictograma de cada verificación, el cable que une `lector1` con `RE`, el glitch que tiembla donde está el lector oculto, la placa con el dibujo de la onda del golpe y el marco del nicho con unas tijeras (como «Recortar»).
2. **Notas lo apunta** (encaja con su voz: «lo apunta todo», `04` §12.3). Mientras el acertijo está activo, el resumen de Notas tiene una línea «Actualización: n/3» con los pictogramas de lo que falta. No es una línea de voz.
3. **Pista de Eco** (no importante, no pausa, una vez por partida guardada) a los 90 s en la página 2 sin ninguna verificación nueva: «Cada color es un sitio por el que ya pasaste. Usa lo que aprendiste allí.» (**PROPUESTA**).
4. **La tecla:** tras 2 intentos fallidos en una verificación (se acaba la ventana de V1, baja la plataforma de V2 sin que Isak llegue o choca contra el marco de V3 sin comprimirse), sale sobre ella la tecla de la acción que falta, leída del Input Map, con el estilo del prompt del pulso.

Con «Ayudas de Eco: Ocultar» (Ajustes) no salen las pistas 3 y 4. Las pistas 1 y 2 siempre están. **Razón:** se respeta el ajuste que ya existe y el acertijo se puede resolver solo con las pistas visuales.

### 2.5 Cómo se evitan los atascos (*soft-lock*)

- **Sin daño ni caídas:** en el hub nada hace daño y hay paredes y techo, así que no se muere, no se gastan vidas y no hay rollback dentro del acertijo.
- **Lo temporal vuelve solo:** la ventana de 6 s de V1 y la plataforma de 3 s de V2 se pueden repetir sin límite. Lo que ya está hecho (una verificación encendida, el marco iluminado) no se puede deshacer y no bloquea nada.
- **Energía:** el cargador de la página 2, más el llenado al entrar al hub. Las repisas de una vía siempre devuelven al suelo.
- **Pellizcar:** el nicho mide 2 tiles de alto, así que se puede volver al tamaño normal dentro. Si Isak sale comprimido, vuelve al tamaño en cuanto hay sitio (regla del estado `Compress`).
- **Papelera llena** (game over pendiente de recuperar): las habilidades están en la Papelera, así que **el acertijo está inerte**. El instalador muestra «Recupera tus archivos de la papelera» (el mismo texto que las carpetas). **Razón:** sin habilidades no se puede resolver, y además Notas no guarda en ese estado.
- **Salir a medias siempre se puede:** la página 1 y las carpetas M1-M3 funcionan igual. Lo único que espera es el upgrade.

### 2.6 Guardado, vidas y rollback (PROPUESTA)

| Situación | Qué pasa |
|---|---|
| Verificaciones a medias | **No se guardan** y se reinician en cada visita al hub, como el enfriamiento del cargador. **Razón:** el acertijo dura poco y así no hay un estado intermedio en el guardado. |
| Instalar | Se añade `"hub_update_4_6"` a una lista nueva del guardado, `hub_upgrades`. **Solo marca «sin guardar»**: se guarda en Notas, que está en la página 1 (la regla del guardado manual). Notas lo recuerda: «¡Apuntado! Guárdalo para que no se pierda.» (**PROPUESTA**, no es importante). |
| Entrar a M4 sin guardar | La confirmación que ya existe («¿Seguro? Aún no has guardado.» + «Si caes sin guardar, Eco te devolverá a tu última copia.»). |
| Game over con el upgrade sin guardar | Rollback a la última copia, como con todo lo obtenido: si la copia no tenía el upgrade, el hub vuelve a la página 2 «en instalación» y se repite el acertijo (dura un minuto). La Papelera **no** se lleva el upgrade: es estado del hub, no un objeto. |
| Vidas | No se gastan en el hub. |
| Rollback de fin de vuelta (Caché → Kernel, Kernel → Raíz) | El upgrade **se conserva**, como `found_secrets` y el álbum: el hub no «se desinstala». Ver §4.3 para lo que pasa con las carpetas. |

### 2.7 Cómo se valida (prueba y bot)

- **Pruebas GUT** (`tests/test_hub_update_puzzle.gd`): sin el Debug, `lector1` no se ve ni se le puede apuntar; sin cable, el pulso a `RE` no hace nada; la placa solo responde al golpe al suelo (no al pulso); la plataforma baja a los 3 s con aviso; no se entra al nicho sin comprimirse; comprimido no hay pulso; con 3/3 se instala y se marca «sin guardar»; con la Papelera llena todo está inerte; las verificaciones se reinician al recargar el hub; un game over sin guardar devuelve el estado «en instalación».
- **Validador:** la página 2 se describe en `data/hub_update.json` con la rejilla y los tipos de los niveles, para que `tools/validate_level.py` compruebe con `requires_abilities` (Debug, láser, dash, golpe al suelo y Pellizcar) que se llega a cada verificación, cuánta energía hace falta y el margen de las ventanas (k como en el 1-2). Negativos: sin dash, V2 no se alcanza; sin Pellizcar, V3 tampoco.
- **Bot** (`tools/hub_update_bot.gd`, que extiende `tools/dnd_bot.gd`): desde un guardado de quien acaba de vencer a la Curadora, solo con acciones del Input Map (nunca Q ni Esc), cruza a la página 2, resuelve V1, V2 y V3, instala, vuelve a la página 1, guarda en Notas, va a la página 2 y abre la carpeta M4 (disponible, «Próximamente» mientras no existan sus niveles). Sale con código 0.

---

## 3. El upgrade del hub

### 3.1 La instalación (momento de historia, PROPUESTA)

Con el pulso al instalador con 3/3, el juego se pausa:

1. Barra «Instalando… No apagues el dispositivo» que se llena en 3 s. Los tres marcos de las verificaciones mandan su color al instalador.
2. Destello. La página 2 cambia a su forma final: las piezas del acertijo se desvanecen y **aparecen las carpetas M4 y M5** sobre sus repisas.
3. El borde derecho de la página 2 se abre a la **página 3**, y el indicador pasa a 3 puntos.
4. Línea importante de Notas: «¡Tres carpetas nuevas! Las apunto. Una ya se puede abrir.» (**PROPUESTA**).
5. Se suelta el control, con Isak junto al instalador (que se queda como decorado apagado en la página 2: **PROPUESTA**, para que la página no parezca vacía).

### 3.2 Estructura: páginas (encaja con `05` §13.2)

| Página | Antes del upgrade | Después del upgrade |
|---|---|---|
| **1** | Igual que hoy (M1, M2, M3, dock y foto con las piezas). Tras la Curadora, el borde derecho con glitch deja pasar. | Igual. Las piezas 4 (coral) y 5 (blanco) siguen su regla actual (§3.3). |
| **2** | Antes de la Curadora no existe (la pared derecha está como hoy). Después, «en instalación» con el acertijo. | **Carpetas M4 «El Chat» y M5 «La Tienda»**, en las columnas **4 y 14** (**PROPUESTA**: lejos del instalador apagado de las columnas 8-9; repisas de 160 px como en la página 1). Dock sin estaciones (sitio para aliados futuros) y el cargador. |
| **3** | No existe. | **Carpeta M6 «La Nube»** en el centro (columnas 9-10), con su **candado de 5 ranuras** (`05` §13.2: «solo se abre con los cinco recuerdos recuperados»). Fondo más limpio, en plata y azul pálido, como anticipo de La Nube (con la paleta del hub mientras no se cierre la de M6). |

**Cambio de página (PROPUESTA de implementación):** una sola sala de 60 × 11 tiles. La cámara se queda fija en cada página de 20 × 11 y **se desliza** (tween de unos 0,35 s, con Isak en pausa) cuando Isak cruza el borde (`05` §13.2: «Isak camina hasta el borde y la pantalla se desliza»). Las paredes entre páginas dependen del estado. **Razón:** Isak, Eco, las piezas y el HUD siguen siendo los mismos y no hay que cambiar de escena. El hub de antes de la Curadora queda igual que hoy (una página, las mismas paredes), así que las pruebas actuales del hub siguen sirviendo.

**Llegada:** el vórtice sigue llegando a P en la página 1. **PROPUESTA:** al volver de un nivel de los Mundos 4-6, la llegada es en la página de su carpeta (un punto P2/P3 por página). **Razón:** volver andando dos páginas tras cada nivel cansa.

### 3.3 Estados de las carpetas M4, M5 y M6

| Estado | Cuándo | Qué se ve |
|---|---|---|
| **Oculta** | Sin `hub_update_4_6` | No hay carpeta (la página no existe o está «en instalación»). |
| **Visible y bloqueada** | Con el upgrade y sin su `unlocked_by` | Carpeta con el **candado y la silueta gris** de `folder_frames` (animación `locked`), el número del mundo apagado y **sin miniatura**, como ya pasa con las bloqueadas («no se adelanta el mundo»). Con Isak cerca: «Sin descargar» (`folders.texts.locked_text`). **PROPUESTA** para M5 y M6: una segunda línea con la condición, sin nombres, «Completa el mundo anterior». M6 además muestra el candado de 5 ranuras, con una encendida por cada fragmento obtenido (§4.2). |
| **Disponible** | `unlocked_by` cumplido | En el color del Debug de su mundo, con su miniatura y el panel de subniveles. Si el mundo aún no tiene niveles en la vuelta actual: «Próximamente» (`empty_world`; regla que ya existe). |
| **Completada / check** | Como en M1-M3 | `completed` (todos los subniveles) y `all_done` (todo obtenido). |

**Piezas del fondo** (no cambian; ya hay un mecanismo en `room.pieces`): la pieza 4 (coral) está `hidden` mientras M4 está bloqueado, pasa a `off` (contorno que parpadea) cuando M4 queda disponible, o sea, al instalar, y se enciende (`on`) al completar M4 (`05` §13.4 y `propuesta-mundo-3.md` §4.6: «cuarta pieza coral al completar el Mundo 4»). La pieza 5 (blanco) pasa a `off` cuando se desbloquea M5 y se enciende al completarlo («el fondo está completo»). La Nube no tiene pieza: su hito es «La Nube abierta» (`05` §13.4).

### 3.4 Compatibilidad con los datos y las partidas guardadas

- **`data/hub.json`** (lo que cambia, **PROPUESTA**):
  - `room.pages`: lista de páginas con su `camera_rect_px`, su punto de llegada y `requires_upgrade`. La página 1 no lleva requisito; la 2 lleva `"hub_update_4_6"` (sin él, y con `3-boss`, sale «en instalación»); la 3 también lleva `"hub_update_4_6"`.
  - Nuevo campo `page` en cada mundo (por defecto 1, así que M1-M3 no cambian) y `col` para m4 (4), m5 (14) y m6 (9, página 3). `HubWorlds.folder_worlds` filtra por página y por `requires_upgrade`.
  - `m4`: `"unlocked_by": ["3-boss"]` (se queda como está) + `"requires_upgrade": "hub_update_4_6"`. Como el acertijo solo aparece tras el `3-boss`, en la práctica **M4 queda disponible justo al instalar**. **Razón:** se mantiene la semántica actual de `unlocked_by` (subniveles completados de la vuelta) y el requisito de vuelta de §4.3 sale solo.
  - `m5`: `"unlocked_by": ["4-boss"]` + `requires_upgrade`. `m6`: `"unlocked_by": ["5-boss"]` + `requires_upgrade` (hoy `m5` y `m6` no tienen `unlocked_by`).
  - Sección nueva `update_puzzle` (o el archivo `data/hub_update.json`): piezas, ventanas, textos y pistas.
  - `calc.remarks`: se añade `{"id": "update_3_boss", "after_level": "3-boss", …}`.
- **Columnas:** la página 1 no cambia (4, 10 y 16 ocupadas, `propuesta-mundo-3.md` §4.6), y por eso M4 va a la página 2, como ya decía `05` §13.2.
- **Guardado:** esquema **v6** (hoy `SAVE_VERSION` 5) con `hub_upgrades: []`. La migración desde v5 y anteriores lo crea vacío. **No hace falta ninguna marca de «acertijo disponible»:** se calcula al cargar (`3-boss` en `completed_levels` y sin `hub_update_4_6`). Así **quien ya venció a la Curadora ve el acertijo al cargar** (el glitch y el segundo punto, §1). Su copia no tenía nada de los Mundos 4-6, así que no pierde nada.
- **Álbum de Notas:** hoy la carpeta «El Chat» del álbum se abre con `3-boss` (mundo desbloqueado). Con el cambio se abre **al instalar** (porque m4 pasa a necesitar el upgrade). En una partida que ya venció a la Curadora, esa carpeta (vacía) vuelve a salir cerrada hasta resolver el acertijo. **Aceptable:** no tiene fichas. «La Tienda» y «La Nube» se abren cuando se desbloquean sus mundos.

---

## 4. Reglas de desbloqueo de los Mundos 4, 5 y 6 (decisión del usuario, 2026-10-27)

### 4.1 Regla

| Mundo | Visible | Disponible |
|---|---|---|
| **M4 El Chat** | Al instalar el upgrade | **Al instalar** (`3-boss` + `hub_update_4_6`) |
| **M5 La Tienda** | Al instalar | Al completar el Mundo 4 con su jefe (`4-boss`, El Visto) |
| **M6 La Nube** | Al instalar | Al completar el Mundo 5 con su jefe (`5-boss`, El Vendedor) |

Va en orden, como M1 → M2 → M3. Un game over sin guardar vuelve a bloquear el mundo siguiente, como con el jefe (regla que ya existe de `unlocked_by`).

### 4.2 Cómo encaja con lo demás

- **Pieza coral:** se enciende al completar M4 (§3.3), y es el mismo momento en que M5 queda disponible. El hito «Mundo 4 completado» de `05` §13.4 trae las dos cosas.
- **Candado de La Nube (`05` §13.2, cinco recuerdos):** los fragmentos son la capa Caché de cada jefe (`propuesta-recuerdos.md` §2). Como M6 solo queda disponible tras el `5-boss`, en ese momento ya están los 5 fragmentos: **el candado y la regla de `05` dicen lo mismo**. **PROPUESTA:** el candado muestra 5 ranuras que se encienden con `boss_w1_l1` … `boss_w5_l1` (3 encendidas al instalar). Al vencer al Vendedor se enciende la quinta, el candado se abre (hito «La Nube abierta»: Eco intenta entrar y aparecen notificaciones en el borde, `05` §13.4) y la carpeta queda disponible. La comprobación se hace con `unlocked_by: ["5-boss"]`; las ranuras son solo visuales (cuentan las capas del registro, incluso con la red de seguridad de §4 de recuerdos).
- **Habilidades:** el orden 4 → 5 asegura que Isak tiene **Agitar** (4-2) antes de La Tienda y de La Nube (Isak Optimizado lo usa, `mundo-6-nube.md` §11.7). El validador de M5 y M6 puede contar con `shake`.
- **Recuerdos de jefe:** sin cambios. Cada jefe entrega la capa de su acceso.
- **Linterna (mundo oscuro por decidir):** este documento no la decide. Si es el Mundo 4, llega en el 4-1, después del upgrade, y el acertijo no la necesita.

### 4.3 Vueltas Caché, Kernel y Raíz (PROPUESTA)

- El upgrade **se conserva** a través del rollback de fin de vuelta (§2.6): en Kernel y Raíz las tres páginas existen desde el principio y **el acertijo no se repite**. **Razón:** es estado del hub, como el álbum, y repetirlo no aporta nada nuevo.
- La disponibilidad **sí depende de la vuelta**: M4 vuelve a pedir el `3-boss` de la vuelta actual, M5 el `4-boss` y M6 el `5-boss`, como hoy M2 pide el `1-boss`. Mientras tanto, las carpetas se ven bloqueadas con su candado. Depende de cómo quede `completed_levels` por vuelta (matiz pendiente de `propuesta-recuerdos.md` §10.1 / paso 16 de asistentes); si ese matiz cambia, esta regla lo sigue.
- La UI nunca dice vuelta, Easy, Normal ni Hard.

---

## 5. Impacto y plan

### 5.1 Qué cambia de lo ya implementado

| Área | Archivos | Cambio |
|---|---|---|
| Datos del hub | `data/hub.json` | `room.pages`, `page`/`col` de m4-m6, `requires_upgrade`, `unlocked_by` de m5 y m6, `update_puzzle`, comentario de Calc. Se actualizan los `_notes` de `worlds_notes` (m4 ya no queda «sin carpeta»). |
| Registro de mundos | `scripts/hub/hub_worlds.gd` | Visibilidad con `requires_upgrade`, carpetas por página, condición de bloqueo para la segunda línea. |
| Sala del hub | `scripts/hub/hub_room.gd`, `scenes/hub/hub.tscn` | Varias páginas, cámara que se desliza, paredes según el estado, llegada por página, indicador de 1-3 puntos y las piezas del acertijo. |
| Piezas nuevas | `scripts/hub/hub_installer.gd`, `scripts/levels/update_check.gd`, `scripts/levels/pound_plate.gd` | Instalador, verificación y placa. Reutilizan `HubStation`, `laser_receiver`, `relay_receiver`, `mirror`, `small_frame` y `charger`. |
| Guardado | `scripts/autoload/game_state.gd` | v6 con `hub_upgrades` y migración; `has_hub_upgrade()`, `install_hub_upgrade()` (marca «sin guardar»); el rollback de vuelta lo conserva. |
| Notas | `scripts/hub/notas_*.gd`, `data/hub.json` (`notas`) | Línea «Actualización: n/3». |
| Validación | `tools/validate_level.py` (+ `data/hub_update.json`), `tools/validate_memories.py` (`hub_levels`: m4-m6 aún sin niveles) | El validador recorre la página 2. |
| Arte por script | `tools/gen_hub_objects.py` | Instalador, verificaciones (3 marcos), placa, plataforma «Cargando…», glitch del borde, indicador de 3 puntos, carpetas `folder_m4/m5/m6` (`locked/available/completed/all_done`), candado de 5 ranuras y fondo de la página 3. |
| Audio | `data/audio.json` | IDs provisionales `sfx_hub_update_check`, `sfx_hub_install` y `sfx_hub_page_slide`. |
| Pruebas que cambian | `tests/test_hub_boss_entry.gd` | Con `3-boss`, «m4 desbloqueado» pasa a «acertijo disponible; m4 oculto hasta instalar». |
| | `tests/test_hub_room.gd`, `tests/test_hub_folders.gd` | Siguen con una página antes de la Curadora; casos nuevos de varias páginas. |
| | `tests/test_hub_legacy_unlocks.gd` | Un guardado v5 con `3-boss` ve el acertijo. |
| | Pruebas del álbum | La carpeta «El Chat» se abre al instalar. |
| Pruebas nuevas | `tests/test_hub_pages.gd`, `tests/test_hub_update_puzzle.gd`, `tests/test_hub_worlds_4_6.gd`, `tests/test_hub_update_bot.gd` | |
| Documentación | `05-hub.md` (§13.2 y §13.4), `CLAUDE.md`, `INDEX.md`, `08-pendientes.md`, `propuesta-mundo-3.md` §4.6 (nota de que M4 pasa a necesitar el upgrade) | Al terminar. |

### 5.2 Plan por pasos pequeños

Cada paso lleva sus pruebas y termina con la parte afectada de `tools/run_tests.sh` en verde y `graphify update .`. Un commit local por paso, sin push. Los textos van marcados como propuestos y el arte es por script.

| Paso | Qué | Archivos probables | Terminado cuando | Tamaño | Depende de |
|---|---|---|---|---|---|
| 0 | El usuario responde las preguntas de §6.2 | este documento | Respuestas volcadas aquí | S | — |
| 1 | **Datos y guardado:** v6 con `hub_upgrades` y migración; `requires_upgrade`, `page`, `col`, `unlocked_by` de m5/m6; `HubWorlds` (oculta / bloqueada / disponible); el rollback de vuelta conserva el upgrade | `data/hub.json`, `scripts/autoload/game_state.gd`, `scripts/hub/hub_worlds.gd`, `tests/test_hub_worlds_4_6.gd`, prueba de migración | GUT: sin upgrade m4-m6 ocultos; con el upgrade m4 disponible (con `3-boss`), m5 bloqueado hasta `4-boss` y m6 hasta `5-boss`; v5 → v6; game over sin guardar lo quita; el rollback de vuelta lo conserva | M | 0 |
| 2 | **Hub de varias páginas:** sala 60 × 11, cámara que se desliza, paredes según el estado, indicador de 1-3 puntos, llegada por página; hub idéntico antes de la Curadora; comprobar el Debug obtenido en el hub | `scripts/hub/hub_room.gd`, `scenes/hub/hub.tscn`, `tests/test_hub_pages.gd`, `tests/test_hub_room.gd` | GUT: sin `3-boss` una página y pruebas actuales iguales; con `3-boss` se cruza a la 2; con el upgrade, a la 3; la cámara no enseña dos páginas a la vez | M-L | 1 |
| 3 | **Acertijo:** `hub_installer`, `update_check`, `pound_plate`, plataforma temporal y el montaje de V1-V3 en la página 2; inerte con la Papelera llena; reinicio por visita | `scripts/hub/hub_installer.gd`, `scripts/levels/update_check.gd`, `scripts/levels/pound_plate.gd`, `data/hub_update.json`, `tests/test_hub_update_puzzle.gd` | GUT de §2.7 (positivos y negativos) | L | 2 |
| 4 | **Validador** de la página 2 (rejilla, `requires_abilities`, energía y ventanas) | `tools/validate_level.py`, `tools/level_plan.py`, `tests/test_hub_update_validator.py` | Valida con todas las habilidades; los negativos fallan (sin dash, sin Pellizcar, sin Debug); las salidas de los Mundos 1-3 son idénticas | M | 3 |
| 5 | **Instalación y upgrade:** secuencia de §3.1, página 2 final con M4/M5, página 3 con M6 y candado de 5 ranuras, carpetas bloqueadas con silueta y segunda línea, pieza 4 en `off`, álbum | `scripts/hub/hub_room.gd`, `scripts/hub/folder_station.gd`, `tests/test_hub_update_install.gd` | GUT: tras instalar, tres carpetas visibles en sus páginas, M4 se abre («Próximamente») y M5/M6 dicen «Sin descargar» + condición; se marca «sin guardar» | M | 3 |
| 6 | **Textos y pistas:** comentario de Calc, línea de Eco al entrar a la página 2, pista a los 90 s, tecla tras 2 fallos, línea de Notas y «Actualización: n/3»; respeto de «Ayudas de Eco» | `data/hub.json`, `scripts/hub/notas_station.gd` | GUT: cada línea sale una vez por partida guardada; con las ayudas ocultas no salen las 3 y 4 | S-M | 5 |
| 7 | **Arte por script** (§5.1) y audio provisional | `tools/gen_hub_objects.py`, `data/audio.json`, `tools/gen_audio_placeholders.py` | Validadores de arte y audio en la suite; sin rojo en el hub | M | 3, 5 |
| 8 | **Bot del hub** desde un guardado tras la Curadora | `tools/hub_update_bot.gd`, `tests/test_hub_update_bot.gd` | Código 0: resuelve, instala, guarda y abre M4; duración anotada (objetivo 60-90 s) | M | 5, 6 |
| 9 | **Pruebas de conjunto:** compatibilidad (guardado v5 con `3-boss` → acertijo), suite completa | `tests/*` | `tools/run_tests.sh` en verde | S | 1-8 |
| 10 | **Capturas y docs:** capturas del hub (página 1 con glitch, página 2 en instalación, instalación y páginas 2 y 3 finales); `05-hub.md`, `CLAUDE.md`, `INDEX.md`, `08-pendientes.md`; lista de revisión del usuario en `preguntas.md` | `docs/*`, `docs/capturas/hub-4-6-*/` | Docs al día y lista publicada | S-M | 9 |

**Orden:** 1 → 2 → 3 → (4 y 5 a la vez) → (6 y 7 a la vez) → 8 → 9 → 10.

**Tamaño total (estimación):** como uno de los acertijos del Mundo 1 más el sistema de páginas, unas 2-3 veces el encuentro con Calc. No hace falta AutoSprite.

---

## 6. Quién decide qué

### 6.1 Ya decidido

- **Del usuario** (no se cambia): el acertijo aparece al vencer a la Curadora y se resuelve con las habilidades conocidas; hace un upgrade del hub; las tres carpetas M4, M5 y M6 se vuelven **visibles** a la vez; la disponibilidad va **en orden** (M4 al resolver el acertijo, M5 al completar el Mundo 4, M6 al completar el Mundo 5); quien ya venció a la Curadora ve el acertijo al cargar; las bloqueadas se ven con candado y silueta.
- **Del orquestador** (diseño delegado; todo lo marcado PROPUESTA): la opción A y sus tres verificaciones; la página 2 «en instalación»; las posiciones (M4 y M5 en la página 2, columnas 4 y 14; M6 en la página 3, como `05` §13.2); las pistas; las reglas de guardado (las verificaciones no se guardan y el upgrade marca «sin guardar»); el esquema v6; el candado de 5 ranuras; los textos propuestos.

### 6.2 Preguntas abiertas (mínimas)

1. **Kernel y Raíz:** ¿el upgrade se conserva y el acertijo no se repite en las vueltas siguientes (recomendado, §4.3)? ¿O se repite en cada vuelta con otra variante?
2. **Game over sin guardar tras instalar:** ¿se pierde el upgrade y se repite el acertijo, como cualquier progreso sin guardar (recomendado, §2.6)? ¿O el upgrade se queda para siempre al instalarlo, como excepción al guardado manual?
3. **Nombre de cara al jugador:** ¿«Actualización del sistema» y las verificaciones «Integridad», «Búfer» y «Recorte» (propuestos; no «Caché», que es el nombre del primer acceso)? ¿Otro nombre?
