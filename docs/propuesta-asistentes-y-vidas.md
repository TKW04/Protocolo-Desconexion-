# Propuesta: asistentes, ayuda con Q, vidas y papelera

Estado: **propuesta con las decisiones del usuario aprobadas** («decisiones del usuario 2026-10-15 (3)»), **a falta de las preguntas abiertas de §12.** El usuario aprobó también todas las propuestas que no contestó de forma explícita. Lo que sigue marcado como **propuesta** es solo lo que §12 deja abierto. Los valores marcados **ajustable jugando** son de partida y se afinan jugando. Al aprobarse era solo documentación; la implementación avanza según §10 (estado al final de la tabla). Donde contradice a otro documento, manda este; el otro lleva una marca de «reemplazado» (lista en §13).

Reemplaza:

- **Tutorial de guardado B + C** (`propuesta-hub-y-guardado.md` §5 y paso 10): no hay línea «sin cobertura» ni primer hub guiado. Ahora Eco presenta a Notas y Notas explica cómo guardar.
- **«Eco no entra en el hub»**: Eco entra y sale con Isak.
- **Calc dormida que vende desde el 1-1**: no hay tienda hasta conocer a Calc al final del 1-2.
- **Avisos automáticos de Eco del 1-1** (líneas `eco_line` no importantes): pasan a ayuda con Q o se eliminan (§4).
- **Papelera = puntos perdidos al morir** y **Linterna = indica secretos por nivel tras el Mundo 4** (`05-hub.md` §13.3).
- **Notas como bitácora a partir del Mundo 2**: Notas es la consola de guardado y el **álbum** desde el primer hub.

Se mantiene:

- Guardado manual solo en el hub.
- La confirmación «¿Seguro? Aún no has guardado.» al entrar a una carpeta con cambios pendientes (ya implementada).
- `QuitGuard`.
- El rollback de las tres vueltas: restaura puntos y objetos del mapa y conserva los secretos.
- Los nombres de cara al jugador: Caché, Kernel y Raíz. La UI nunca dice «vuelta», Easy, Normal ni Hard.

**Vocabulario fijo en todos los docs:** **vidas (intentos)** son los intentos antes del game over; **Sync Rate (salud)** es la barra de vida dentro de un intento. **Puntos** sin más son los **puntos de atención** (la moneda), no los puntos de sincronización (checkpoints).

---

## 1. Concepto

Isak no está solo: lo acompañan los **asistentes**, aplicaciones del celular que se van incorporando.

| Asistente | Qué es en el juego | Cuándo llega |
|---|---|---|
| **Eco** | Asistente digital y compañero persistente: una esfera pequeña que sigue a Isak en los niveles y en el hub. Da el pulso y responde a la ayuda con Q. | Lo primero del 1-1: tras el vórtice, Isak camina y se topa con Eco. |
| **Notas** | La consola donde se guarda (la estación «copia local» pasa a ser Notas) y el **álbum** de enemigos y objetos. | La primera vez que Isak entra al hub. |
| **Calc** | La tienda de mejoras. | Al final del 1-2, tras obtener el Debug. Antes no hay tienda. |
| **Linterna** | Objeto que se activa solo en zonas oscuras. | Al entrar en el X-1 del mundo oscuro (mundo por decidir, §12). |
| **Papelera** | Donde aparece lo que Eco «desecha» en un rollback, para recuperarlo. | La primera vez que hace falta: primer game over o primer rollback. |

Eco **no lanza mensajes a lo loco**. Habla solo en los momentos de historia (automáticos, con pausa) y cuando el jugador le pregunta (ayuda con Q, con pausa).

## 2. Los asistentes

### 2.1 Eco

| Aspecto | Detalle |
|---|---|
| **Rol** | Asistente digital. Acompaña a Isak en los niveles y en el hub, da el pulso la primera vez, explica lo que el jugador le pregunta (Q) y aplica los rollbacks (game over y jefe final). Sigue hablando a través de los jefes (`04-personajes.md` §12.1). |
| **Cuándo aparece** | 1-1, primer tramo (§7.1): Isak llega por el vórtice, camina y se topa con Eco. Desde entonces entra y sale con Isak (vórtices de llegada y salida, niveles y hub). |
| **Presentación** | Momento de historia (pausa). Eco se presenta, pide un nombre y da el pulso. |
| **Nombre (apodo)** | Eco pregunta cómo llamar al jugador. Se escribe un apodo o se deja el actual (por defecto «Isak»). Es el **apodo con el que Eco llama al jugador**, no el nombre real de Isak: los recuerdos de familia del Mundo 2 usan siempre «Isak». Los textos de Eco usan el marcador `{apodo}`. Se puede cambiar después desde Notas. |
| **El pulso** | Es un regalo de Eco en el encuentro (implementado el 2026-10-16): el 1-1 empieza sin pulso y el tramo anterior al encuentro no lo exige. |
| **Ayuda con Q** | §3. |
| **Momentos de historia** | Presentación (con el pulso), obtención del láser, obtención del Debug, primer game over o rollback, presentación de Notas en el primer hub y líneas de jefe (§4). |

**Comportamiento de compañero (decidido; valores ajustables jugando):**

- **Seguimiento suave:** Eco flota detrás de Isak, a la altura del hombro (unos 48 px detrás y 112 px sobre los pies), por el lado contrario al que mira. Se acerca con suavizado (amortiguación crítica, unos 0,25 s) y cruza por encima de Isak cuando este se gira.
- **Oscilación:** ±4 px en vertical a 0,8 Hz.
- **No tapa la acción:** se dibuja detrás de Isak, de los enemigos y de los proyectiles. No tiene colisión, no recibe daño y no bloquea el pulso ni el láser. Si se aleja más de 4 tiles (caídas largas o un vórtice), se recoloca con un destello.
- **Entra con el vórtice:** aparece unos 0,3 s después de Isak en el vórtice de llegada y se va justo después que él en el de salida. En la primera partida del 1-1 no viene en el vórtice, porque Isak aún no lo conoce (§7.1).
- **Al pedir ayuda:** el juego se pausa, Eco se dibuja junto al objeto y el objeto recibe un contorno cian.
- **En el Debug:** Eco usa tiempo real, como el cuadro de texto.

**Eco en las tres vueltas** (Caché, Kernel y Raíz; internamente Easy, Normal y Hard). Decidido: en Easy, Eco desecha todo en el rollback final; en Normal, el jefe engaña a Isak para que lo haga él; Hard es el final real. El tono por vuelta sigue abierto (pregunta 5).

| | Caché (Easy) | Kernel (Normal) | Raíz (Hard) |
|---|---|---|---|
| Tono | Servicial y corporativo (§12.1) | *Propuesta:* más insistente; ofrece atajos y decide antes de preguntar | *Propuesta:* seco y breve, como su forma de «línea recta de luz» |
| Ayudas con Q | Completas | *Propuesta:* nunca mienten, en ninguna vuelta; solo cambia el tono. Los tipos nuevos de cada vuelta tienen su Q y su ficha | Igual |
| Rollback | Eco desecha todo → papelera (§5.3) | Lo lanza Isak, engañado (papelera: pregunta 4) | No hay: es el final real |

### 2.2 Notas: consola de guardado y álbum

| Aspecto | Detalle |
|---|---|
| **Rol 1: guardar** | La estación «copia local» actual **pasa a ser Notas**: mismo sitio (columnas 1-2, filas 7-8 del hub), mismo panel y misma lógica de guardado (`CopyLocalStation`). Cambian el aspecto, el nombre y la presentación. |
| **Rol 2: álbum (códice)** | Decisión del usuario 2026-10-15 (3): Notas guarda la información de las ayudas con Q ya vistas y la muestra como un **álbum** de los enemigos (mobs) y los objetos del juego. Detalle en §3.5. |
| **Cuándo aparece** | La primera vez que Isak entra al hub, apagada. Eco la presenta, Notas se activa y explica cómo guardar (momento de historia, con pausa). Después funciona como hoy la copia local, con un menú: «Guardar», «Álbum» y «Apodo». |
| **Qué reemplaza** | El tutorial B + C. No hay línea «sin cobertura» en la terminal de salida ni primer hub guiado. |
| **Se mantiene** | La confirmación «¿Seguro? Aún no has guardado.» al entrar a una carpeta, el indicador «sin guardar» y el aviso al cerrar. |
| **Personalidad** | Curioso y un poco desordenado; anota lo que Isak olvida (`04-personajes.md` §12.3). |
| **Más adelante** | Recuerdos, diálogos, pistas y coleccionables (§13.3) se añaden al álbum o a la bitácora cuando haya contenido. |
| **Vueltas** | El álbum y el apodo se conservan tras el rollback, porque son registro (§5.4). Si cambia el tono de Notas entre vueltas está por decidir. |

Texto de la presentación (ajustable; no añade historia):

1. Eco: «Te presento a Notas. Ella guarda por ti.»
2. Notas: «¡Hola, {apodo}! Lo apunto todo. Si quieres conservar lo que has hecho, ven y guárdalo conmigo.»
3. Notas: «Si cierras sin guardar, se pierde. Y si Eco te devuelve a tu última copia, solo vuelve lo que guardaste aquí.»

### 2.3 Calc

| Aspecto | Detalle |
|---|---|
| **Rol** | La tienda de mejoras permanentes (`data/upgrades.json`), con su personalidad de `04-personajes.md` §12.3: literal, seca y lógica. |
| **Cuándo aparece** | Isak la encuentra **al final del 1-2, tras obtener el Debug**. Historia decidida el 2026-10-17 (`propuesta-calc-encuentro.md`): en la azotea está al 3 %; tras el acertijo de la terminal sin corriente se carga y se teletransporta al hub, donde Isak la encuentra (allí se da por conocida, habla —historia «Resta»— y se abre la tienda). Desde entonces su estación del hub está activa y habla. |
| **Antes** | **No hay tienda.** En el hub, el hueco de Calc (columna 7 del dock) está **apagado e inactivo**: sin panel, sin prompt y sin texto. Reemplaza «Calc dormida vende desde el 1-1». |
| **Impacto** | (1) El secreto del Pulso amplio del 1-1 (`popup_lejano`, power bank vacío) solo se abre después del 1-2: hay que volver al 1-1 tras conocer a Calc. (2) Las compras empiezan tras conocer a Calc. Al final del 1-2 hay unos 18 puntos y el Pulso amplio (25) se sigue pagando al terminar el 1-3, así que la economía no cambia. (3) Hay que cambiar la implementación actual, en la que Calc dormida vende (paso 10 de §10). |
| **Vueltas** | Tras un rollback, Calc sigue conocida (registro): su tienda sigue activa. |

### 2.4 Linterna

| Aspecto | Detalle |
|---|---|
| **Rol** | Objeto que acompaña a Isak y **se activa solo cuando está en una zona oscura** (ilumina a su alrededor). |
| **Cuándo aparece** | En uno de los mundos oscuros, al entrar en el **X-1** de ese mundo. **El mundo lo decide el usuario** (pregunta 2). |
| **Qué reemplaza** | «Indica cuántos secretos tiene cada nivel y da pistas, después del Mundo 4» (`05-hub.md` §13.3). **Contradicción señalada:** antes llegaba *tras* el Mundo 4; ahora llega al *entrar* en el X-1 del mundo oscuro. |
| **En el hub** | Sin panel. Su hueco del dock (columna 13) se enciende al conocerla. |
| **Vueltas** | Se conserva tras el rollback (registro). |

### 2.5 Papelera

| Aspecto | Detalle |
|---|---|
| **Rol** | Ahí aparece lo que Eco «desecha» en un rollback: **habilidades, ítems (de momento, power banks), puntos de atención y mejoras**. No se ha borrado: está en la papelera. Una sola regla para el game over y el rollback del jefe final (§5.3). |
| **Cuándo se activa** | **La primera vez que hace falta** (primer game over o primer rollback). Hasta entonces su hueco del dock es una silueta apagada, sin prompt. |
| **Cómo se recupera** | Se **parpadea y se mueve** mientras tenga contenido. Basta con acercarse (1,5 tiles, sin botón) para recuperarlo todo de una vez, con una animación de vaciado. Funciona sin pulso. Después se queda quieta y apagada. |
| **Bloqueo de carpetas** | Mientras tenga contenido, las carpetas no se abren y avisan «Recupera tus archivos de la papelera», para no jugar sin habilidades. |
| **Dónde** | En el dock, columna 10 (el hueco que era de Notas). Queda entre la llegada (P, columna 5) y Calc. |
| **Encaje con el 4-2** | `04-personajes.md` §12.3 la presenta en la sala «Mensajes borrados» del 4-2, donde sabe el secreto de Eco. Cómo encaja está abierto (pregunta 3). |

## 3. Sistema de ayuda con Q

### 3.1 Reglas (decididas)

1. **Acción `help`:** Q en el teclado y R3 en el mando (botón 8, libre desde que se retiró `save_game`). Se lee del Input Map.
2. **Cuándo sale la Q:** con Eco ya conocido, Isak cerca de un objeto o enemigo cuyo **tipo** aún no se ha aprendido, y el objeto en pantalla. **Eco lleva la Q** (decisión del usuario, 2026-10-16): Eco deja su sitio junto a Isak y vuela junto al objeto (encima, por el lado contrario a Isak, sin tapar el objeto ni a Isak y sin salirse de la pantalla; `help_offset_px` y siguientes de `data/eco_companion.json`), **brilla en dorado** (variante ámbar de la esfera con el `ambar` / `ambar_sombra` de `mundo1.gpl`: transición `glow_in` de 3 cuadros, animaciones `_amber` con un halo que late y `glow_out` al revés) y la Q, con el estilo de la tecla del pulso (`PulsePrompt`), se dibuja **sobre Eco** y lo sigue mientras vuela. `HelpSystem` sigue eligiendo el objeto candidato y se lo pasa a `EcoCompanion`; sin compañero visible (escenas de prueba), la Q va sobre el objeto. Si el objeto deja de ser candidato (aprendido, fuera de rango, «Ocultar»), desaparece o se oculta, Isak muere o entra en un vórtice, o el árbol se pausa sin estar explicando (menú de pausa), Eco vuelve a Isak con su color; con «Ocultar» ni se acerca ni brilla.
3. **Una Q a la vez:** la del objeto no aprendido más cercano.
4. **Radio:** 2,5 tiles desde el centro de Isak y 4 tiles para enemigos, para no tener que acercarse a algo que hace daño (ajustable jugando; por tipo en `data/help.json`).
5. **Al pulsar `help`:** el juego **se detiene** (igual que una línea importante: `get_tree().paused`). Eco explica en su cuadro y se cierra con la acción del jugador (saltar / `ui_accept`: Espacio, A o Intro). Mientras explica, Eco sigue junto al objeto y conserva el brillo dorado (usa tiempo real: se anima en pausa); al cerrar la ayuda vuelve suavemente a seguir a Isak con su color normal. **Cada vez que se pide ayuda, el juego se detiene.**
6. **Aprendizaje por tipo, no por instancia:** al cerrar la ayuda, el tipo queda aprendido. Ninguna otra instancia de ese tipo vuelve a mostrar la Q (si preguntas por una Burbuja, ninguna otra Burbuja la muestra). Además se desbloquea su **ficha del álbum** (§3.5).
7. **Funcionamiento normal:** los objetos funcionan siempre, con Q o sin ella; preguntar nunca es obligatorio. La Q es solo una capa encima. Si el objeto tiene su propio prompt (la tecla del pulso en la terminal o en una estación), la Q sale al lado mientras el tipo no esté aprendido.
8. **`help` sin Q visible:** no hace nada.
9. **Antes de conocer a Eco** no hay Q.

### 3.2 Estados por tipo

| Estado | Q | Ficha del álbum |
|---|---|---|
| `unknown` | Sí, al acercarse | Silueta «???» |
| `learned` | No, nunca más | Desbloqueada (dibujo, nombre y texto de Eco) |

Se guarda en `learned_help` (§6). Aprender una ayuda **no marca «sin guardar»** por sí solo, igual que `seen_notices`: se guarda con la siguiente copia. Si se cierra el juego (o hay un game over) sin guardar, esas ayudas vuelven a salir.

### 3.3 Datos

`data/help.json`: una entrada por tipo (`help_type`). Cada entrada lleva:

- Mundo (`world`, 1-6): la carpeta del álbum (2026-10-16; el Mundo 1 reúne todo lo de 1-1, 1-2 y 1-3). Obligatorio.
- Categoría del álbum: `enemy` u `object` (sección dentro de la carpeta).
- Nombre.
- Texto de Eco (admite `{apodo}`).
- Sprite de la ficha.
- Radio y desplazamiento de la Q.
- Orden en el álbum.

El tipo se deduce del tipo de objeto o enemigo (`receiver`, `alert_bubble`…), así que el JSON del nivel no necesita nada por instancia. Un objeto puede declarar `"help": false` para no mostrar Q.

### 3.4 Interfaz

- **Icono Q:** placa de tecla como la del pulso (placa, borde y bote), con la tecla leída del Input Map. Muestra Q o «R3» según el último dispositivo usado; el prompt del pulso puede usar la misma lógica. Se distingue por la forma (placa redonda frente a la cuadrada del pulso) y por la letra, no solo por el color.
- **Pausa:** el cuadro de Eco en modo importante, con la esfera, el nombre «Eco» y el texto. El objeto lleva un contorno cian y la cámara no se mueve.
- **Accesibilidad:** en Ajustes (`user://settings.cfg`), «Ayudas de Eco: Mostrar / Ocultar», que oculta las Q sin olvidarlas.
- **Relectura (2026-10-16, decisión del usuario):** además del álbum, cerca de un objeto de un tipo ya aprendido sale una Q pequeña y apagada sobre el objeto (Eco no vuela ni brilla), solo con Isak quieto 0,8 s (`reread.still_s`) en el radio del tipo y si no hay ningún candidato sin aprender; pulsarla repite la explicación sin aprender nada. Respeta «Ocultar».
- **Mando:** R3 es poco visible; si en las pruebas cuesta, se puede añadir un segundo botón cuando haya uno libre.

### 3.5 Álbum de Notas

Decisión del usuario 2026-10-15 (3); el detalle era propuesta del equipo y quedó aprobado.

- **Carpetas por mundo** (decisión del usuario, 2026-10-16): el álbum abre en una vista de carpetas, una por mundo (Mundo 1 a Mundo 6), con el contador global «Fichas: n/N» (tipos de los mundos visitados). La carpeta de un mundo visitado muestra «Mundo n», su nombre (`worlds` de `data/hub.json`) y su contador «n/N»; la elegida sale abierta. Las de mundos aún no alcanzados salen cerradas, con candado y «???»: sin nombre, sin contador y sin abrirse. **Regla de mundo visitado:** el mundo existe en `worlds` y `HubWorlds` lo da por desbloqueado (`unlocked` en los datos, o alguno de sus subniveles en `unlocked_levels` / `completed_levels`), o el jugador ha aprendido algún tipo de ese mundo. Iconos de carpeta (cerrada, abierta, bloqueada) de `tools/gen_hub_objects.py`. El pulso abre la carpeta y el salto vuelve (ficha → carpeta → carpetas → cerrar).
- **Qué es (dentro de cada carpeta):** un códice con una ficha por tipo, en dos pestañas: **Enemigos** (Burbuja de alerta, y después badge, banner…) y **Objetos** (punto de atención, receptor, pop-up, power bank, cargador, punto de sincronización, terminal de salida, pared con glitch, vida extra…).
- **Fichas:** se desbloquean al pedir ayuda con Q sobre ese tipo. Las no vistas salen como **silueta «???»**, como gancho de coleccionismo: el jugador ve cuántas le faltan. Solo se ven las fichas y siluetas de los mundos visitados (las carpetas de los demás no se abren), para no adelantar nada.
- **Contenido de una ficha desbloqueada:** el dibujo (primer cuadro del sprite, a x2), el nombre y el texto de la ayuda de Eco. Más adelante se pueden añadir datos como la vida o los drops.
- **Dónde se lee:** en el hub, desde Notas («Álbum»). Se maneja con arriba, abajo, izquierda y derecha; el pulso abre la ficha y el salto vuelve.
- **Contador:** «Fichas: 7/11» por pestaña dentro de la carpeta, «n/N» por carpeta y el global en la vista de carpetas.
- **Sin reinicio** (2026-10-16): el álbum no tiene opción para borrar lo aprendido.

## 4. Mensajes de Eco: historia, ayuda con Q o eliminar

Decidido. Son **momentos de historia** (automáticos, importantes, con pausa):

- La presentación de Eco (sustituye a `eco_bienvenida` y al aviso del pulso).
- La obtención del láser.
- La obtención del Debug.
- El primer game over o rollback.
- La presentación de Notas.
- Las líneas de jefe.

Todo lo demás pasa a **ayuda con Q por tipo** o se **elimina**.

### 4.1 Líneas de `data/levels/1-1.json`

| Id (columna) | Texto actual | Destino | Tipo de ayuda / notas |
|---|---|---|---|
| `eco_bienvenida` (3, importante) | «Bienvenido. He optimizado tu espacio.» | **Historia** | Abre la presentación de Eco; se mueve al encuentro (columna 11, §7.1). |
| `eco_punto` (6) | «Cada punto de atención cuenta. Yo también los cuento.» | **Q** | `attention_point`. Mismo texto. |
| `eco_foso` (19) | «Ese hueco no es un problema. Salta y seguimos.» | **Eliminar** | Un foso no es un objeto. |
| `eco_burbuja` (25) | «Una alerta. Un pulso y se queda en pausa unos segundos.» | **Q** | `alert_bubble` (ficha de enemigo). Texto: «Una alerta. Un pulso y se queda en pausa unos segundos; en pausa también sirve de escalón. Dos impactos de láser la cierran.» (absorbe `eco_escalon` y `eco_laser_disparo`). |
| `eco_receptor` (54) | «Ese receptor espera un pulso. Acércate y lanza el pulso. Te ahorro la búsqueda.» | **Q** | `receiver` (también explica el puente). |
| `eco_puente` (66) | «¿Ves? Todo funciona mejor cuando colaboras.» | **Eliminar** | Es una reacción. |
| `eco_techo_bajo` (122) | «Aquí no hay sitio para saltarla. Un pulso y la dejo en pausa por ti.» | **Eliminar** | Lo cubre la Q de `alert_bubble`; si aún no se ha pedido, la Q sale aquí. |
| `eco_power_bank` (124) | «Batería externa detectada. Guárdala, quizá te ahorre tiempo.» | **Q** | `power_bank_pickup`. Mismo texto. |
| `eco_pulso_amplio` (130) | «Ese botón queda un poco lejos. Con un pulso más amplio llegarías.» | **Eliminar** | Es la pista de un secreto. Calc la dará en la descripción del Pulso amplio. |
| `eco_sync` (147) | «Punto de sincronización. Guardo tu progreso. Para eso estoy.» | **Q** | `sync_point`. El texto contradice que no se guarda en los niveles. Nuevo: «Punto de sincronización. Si caes, vuelves aquí. Las vidas no se recargan, eso sí.» |
| `eco_sala_laser` (151) | «Ahí arriba guardo algo útil para ti. Los receptores conocen el camino.» | **Eliminar** | La historia llega al obtener el láser. |
| `eco_laser_disparo` (173, `laser_fired`) | «Dos impactos bastan para cerrar una alerta. Lo que suelta, recógelo: es tuyo.» | **Eliminar** | Se funde con la historia del láser y con la Q de la Burbuja. `trigger_event` puede seguir en el catálogo. |
| `eco_laser` (174, importante) | «Herramienta nueva. Dispara hacia donde miras; cada disparo gasta energía.» | **Historia** | Obtención del láser, junto con su aviso de control. Se añade: «Lo que sueltan las alertas, recógelo: es tuyo.» |
| `eco_escalon` (180) | «Una alerta en pausa también sirve de escalón. Nada se desperdicia.» | **Eliminar** | Fusionada en la Q de `alert_bubble`. |
| `eco_popup` (208) | «Un aviso importante. El botón de cerrar es pequeño, por tu bien. Pulso de cerca.» | **Q** | `popup_blocker`. Mismo texto. |
| `eco_puerta` (284) | «Marca todo como leído. Así no te preocupas de nada.» | **Q** | `exit_terminal`. «Marca todo como leído. Lanza un pulso al monitor y te llevo fuera.» |
| `eco_glitch` (293) | «Eso es un error de visualización. Ignóralo, por favor.» | **Q** | `glitch_wall`. Mismo texto. |

### 4.2 Avisos de `data/ability_notices.json`

| Id | Texto | Destino |
|---|---|---|
| `pulse` | «Pulso: G / X (mando)» | **Historia:** en la presentación, cuando Eco da el pulso (ya no 1 s después de empezar el 1-1). |
| `laser` | «Láser: F / gatillo izquierdo» | **Historia:** con la obtención del láser, como hoy. |
| `debug` | «Debug: mantén K / Y (mando)» | **Historia:** con la obtención del Debug (1-2). |

### 4.3 Tipos nuevos con Q (textos ajustables)

| Tipo | Álbum | Texto |
|---|---|---|
| `charger` | Objeto | «Un cargador. Repone energía; después tarda un rato en volver a cargar.» |
| `extra_life` | Objeto | «Una vida extra: sube tu máximo de vidas. Guárdala: si caes sin guardar, la pierdes.» (texto del paso 14, 2026-10-16; antes «Una vida de repuesto. Desde ahora empiezas cada intento con una más.») |
| `folder` (hub) | No | «Cada carpeta es un mundo. Elige a dónde vamos.» |
| `calc_off` (hub) | No | «Una aplicación apagada. Quizá la encontremos por ahí.» |

Notas, la papelera y Calc se presentan con momentos de historia, no con Q.

## 5. Vidas, game over, rollback y papelera

### 5.1 Vidas (decisiones del usuario 2026-10-15 (3))

- **Vidas (intentos):** máximo base **3** (`lives_max`). Una vida se pierde cuando el Sync Rate (salud) llega a 0.
- **Se reponen** al máximo al **empezar cada intento de nivel desde el hub** (entrar por la carpeta). La tecla de desarrollo R (`restart_level`) también las repone.
- **Los puntos de sincronización no reponen vidas.**
- **Al morir con vidas restantes:** se resta una y se reaparece en el último punto de sincronización, como hoy (V2).
- **Al llegar a 0 vidas:** game over (§5.2).
- **Vida extra:**
  - Cada vida extra encontrada sube **de forma permanente** el máximo base (3 → 4 → …) y se registra como **secreto encontrado** (`found_secrets`).
  - Al cogerla, también suma +1 a las vidas del intento en curso.
  - Solo se puede coger **una vez por mapa**.
  - No hay una en todos los mapas: hay **una cada N mapas, con N = 3** (una por mundo en cada vuelta: 1-1, 2-1, 3-1…). **N es ajustable jugando:** no está en el código; se decide al colocar `extra_life_pickup` en cada nivel (el esquema solo impide más de una por mapa).
  - La del 1-1 está en el **secreto D** (§7.3).
- **HUD:** iconos de vidas junto a la señal (Sync Rate). En el hub no se muestran.
- **Desde cuándo cuentan:** pregunta 1.

### 5.2 Flujo del game over (paso a paso)

1. Isak pierde la última vida: animación de muerte normal.
2. **Primera vez:** momento de historia (pausa). Eco anuncia el rollback. Texto ajustable: «Demasiados errores, {apodo}. Te devuelvo a tu última copia.» Las siguientes veces solo hay transición.
3. **Transición de rollback:** efecto glitch a pantalla completa y fundido.
4. **Rollback al último guardado:** el estado vuelve a la última copia guardada en Notas. **Todo lo obtenido después de esa copia se pierde** (puntos, power banks, habilidades, mejoras, niveles completados y desbloqueados, objetos de mapa recogidos). Ejemplo del usuario: si pasas el 1-2, no guardas, vas al 1-3 y mueres, tienes que hacer el 1-2 de nuevo.
5. **Lo guardado lo «desecha» Eco**, pero no lo borra. Habilidades, power banks, puntos de atención y mejoras de esa copia aparecen en la **papelera**; Isak llega sin ellos.
6. **Llegada al hub** por el vórtice, con Eco. Energía y Sync Rate llenos.
7. **Primera vez:** la papelera se activa (momento de historia; Eco: «Lo que guardaste está en la papelera. Acércate y es tuyo otra vez.»).
8. La papelera **parpadea y se mueve**. Las carpetas avisan **«Recupera tus archivos de la papelera»** y no se abren.
9. **Recuperar:** al acercarse se recupera todo de una vez. El estado queda igual que la última copia, así que **no hay cambios sin guardar**.
10. Las carpetas vuelven a abrirse. Desde aquí rige la confirmación de siempre: si después hay cambios sin guardar, entrar a una carpeta pregunta «¿Seguro? Aún no has guardado.».

**Primer game over sin ninguna copia previa:** la papelera se activa igualmente, vacía. Eco dice que no había nada guardado (texto ajustable: «No había ninguna copia, {apodo}. No tengo nada que devolverte. Guarda con Notas.»). Este momento enseña el valor de guardar. Qué pasa con el pulso y el registro en este caso: pregunta 6.

**Relación con los avisos de «sin guardar»:**

- La confirmación al entrar a una carpeta avisa justo del riesgo que castiga el game over: entrar con cambios sin guardar significa que, si se pierden las vidas, esos cambios se pierden.
- *Propuesta (ajustable):* que el texto lo diga: «¿Seguro? Aún no has guardado. Si pierdes todas las vidas, lo perderás.».
- Tras un game over no hay cambios pendientes; el bloqueo de la papelera va primero.
- `QuitGuard` no cambia.
- Si se cierra el juego con la papelera llena, al volver se carga la copia, que ya tiene todo, así que no se pierde nada. Por eso la papelera no se guarda en disco.

### 5.3 Una sola regla: rollback = Eco desecha, la papelera devuelve

El game over y el rollback del jefe final usan la **misma mecánica**:

| | Game over (0 vidas) | Rollback del jefe final (fin de Easy) |
|---|---|---|
| Quién lo lanza | Eco | El jefe escapa y Eco desecha todo (en Normal lo lanza Isak, engañado: pregunta 4) |
| Estado de partida | La última copia guardada | El estado al vencer al jefe, con la vuelta siguiente (`lap` + 1) |
| Qué vuelve a los mapas | Nada especial: los mapas quedan como en la copia | Los puntos y los objetos de mapa (`captured_points` y `collected_pickups` se vacían). Los secretos se conservan |
| Qué va a la papelera | Habilidades, power banks, puntos de atención y mejoras | Lo mismo |
| Dónde se recupera | En el hub, acercándose a la papelera, que parpadea y se mueve. Carpetas bloqueadas hasta recuperarla | Igual |

Por eso Isak mantiene sus habilidades tras el rollback. El pulso se lo dio Eco la primera vez.

### 5.4 Qué es registro (no lo toca un rollback)

El registro no son «cosas» que se desechan, aunque sí sigue la regla del guardado:

- `allies_met`, `nickname`, `learned_help` (álbum), `seen_notices`.
- `found_secrets`, `lives_max` y `lap`.

En el rollback del jefe final se conservan en memoria. En el game over vuelven a lo que había en la copia, como todo (pregunta 6).

## 6. Esquema de guardado v3

Sube la versión (v2 → v3), con migración desde v2, como de v1 a v2.

| Campo | Tipo | Por defecto | Notas |
|---|---|---|---|
| `nickname` | string | «Isak» | Apodo. Hasta 12 caracteres de la fuente `text_font`. |
| `allies_met` | lista | `[]` | `"eco"`, `"notas"`, `"calc"`, `"linterna"`, `"papelera"`. Sustituye a `eco_met` (= `"eco"` en la lista) y a `hub_tutorial_done` (= `"notas"`). `"papelera"` indica que ya se activó. |
| `learned_help` | lista de `help_type` | `[]` | Tipos aprendidos con Q = fichas del álbum desbloqueadas. |
| `lives_max` | int | 3 | Sube con cada vida extra. Las vidas actuales no se guardan (se reponen al entrar al nivel). |

La papelera no necesita campo: su contenido es la copia guardada (§5.2). Las vidas extra ya cogidas se saben por `found_secrets`.

**Migración v2 → v3:**

- `nickname` vale «Isak».
- `allies_met` vale `["eco", "notas"]` si el 1-1 está completado o `hub_tutorial_done` es verdadero; si no, `[]`.
- `learned_help` incluye los tipos del 1-1 si el 1-1 está completado (un veterano no repite las Q); si no, `[]`.
- `lives_max` vale 3.
- Una versión desconocida se aparta como `.corrupt`, como hoy.

## 7. Cambios en el 1-1

### 7.1 Nuevo inicio: encuentro con Eco

- Isak llega por el vórtice en P (4, 9) **sin pulso** y **sin Eco**. Camina hacia la derecha y recoge el punto de la columna 8 (sin Q, porque aún no conoce a Eco).
- **Encuentro en la columna 11:** suelo llano antes del escalón de las columnas 13-18 y lejos de la primera Burbuja (`burbuja_t1a`, columna 30). Es un objeto nuevo `eco_encounter`: una zona de toda la altura en las columnas 10-12, imposible de saltar, con Eco flotando en (12, 7).
- **Secuencia** (historia, en pausa; textos ajustables):
  1. «Bienvenido. He optimizado tu espacio.»
  2. «Soy Eco, tu asistente. ¿Cómo quieres que te llame?»
  3. Entrada del apodo, o «Dejar "Isak"».
  4. «Perfecto, {apodo}. Te regalo algo: un pulso.» Se obtiene el pulso y sale su aviso de control.
  5. «Si algo no lo conoces, acércate y pregúntame.»
- **El primer tramo no exige pulso:** antes de la columna 11 no hay receptores, Burbujas ni pop-ups.
- **Al rejugar:** con `"eco"` en `allies_met` y el pulso obtenido, no se repite. Eco entra con el vórtice.

### 7.2 Datos y herramientas afectados

- `data/levels/1-1.json`:
  - `abilities_available.pulse: false`; el pulso lo da `eco_encounter`.
  - Se quitan o convierten las líneas según §4.1.
  - Se añade la vida extra en el secreto D.
  - Se regenera la escena con `tools/build_level.py`.
- `data/world1_objects.json` y `tools/validate_level_schema.py`: tipos `eco_encounter` y `extra_life_pickup`.
- `tools/validate_level.py`:
  - El pulso es un estado del grafo que activa `eco_encounter` (como el láser con `ability_pickup`).
  - El encuentro es obligatorio y todo lo que exige pulso queda detrás.
  - La vida extra es un secreto opcional que exige Debug.
- Bot (`tools/play_level_bot.gd`, `tools/level_bot.gd`):
  - Confirma la presentación y deja el apodo.
  - No pide Q (o una vez, para probarla).
  - Cuenta vidas: la muerte forzada tras el checkpoint resta una sin llegar a game over.
- Pruebas: `test_level_flow.gd`, las de avisos de control (el pulso ya no sale al empezar), las del cuadro de Eco y las del guardado (v3).
- Capturas: `render_level_1_1.gd`, `render_ability_notices.gd` y `render_warp_terminal.gd`.

### 7.3 Vida extra del 1-1: secreto D

Decidido: la vida extra del 1-1 está en el **secreto D** (pared con glitch, columna 298, fila 8) y exige el Debug. El Debug se consigue en el 1-2, así que obliga a volver a un mapa ya jugado.

- Detrás de la columna 298 solo queda el borde del mapa (columna 299). Por eso la vida extra aparece **en la propia celda de la pared** al abrirla con el Debug. Así no hay que ampliar el mapa (ajustable: si se quiere un nicho, se añaden 2-3 columnas).
- La línea `eco_glitch` pasa a ser la Q de `glitch_wall`.
- **Hecho (2026-10-16, paso 14 de §10):** con el Debug activo e Isak a menos de 3 tiles, la pared se disuelve (parpadeo con líneas cian) y deja ver la vida extra en la celda de abajo (columna 298, fila 9). Detalle al final de §10.
- La idea anterior de esconderla «bajo un muro de los puentes» queda descartada para el 1-1.

### 7.4 Ayudas con Q del 1-1

`attention_point`, `alert_bubble`, `receiver`, `power_bank_pickup`, `sync_point`, `popup_blocker`, `exit_terminal`, `glitch_wall`, `charger` y `extra_life`. Son 10 fichas: 1 de enemigo y 9 de objeto.

## 8. Cambios en el hub

| Elemento | Hoy | Con esta propuesta |
|---|---|---|
| **Eco** | No está | Entra y sale con Isak por el vórtice. Cómo encaja con la «zona sin señal», en la pregunta 7. |
| **Copia local** (1-2, 7-8) | Estación sin personaje | **Notas.** Primera llegada: apagada; Eco la presenta y Notas explica cómo guardar. Menú: «Guardar», «Álbum» y «Apodo». |
| **Calc** (7, 9) | Dormida, vende sin hablar | **Apagada e inactiva** hasta conocerla al final del 1-2. Sin panel ni prompt, solo la Q `calc_off`. |
| **Papelera** | Hueco apagado (16, 9) | Pasa a la columna 10. Apagada hasta el primer game over o rollback. Con contenido parpadea, se mueve y bloquea las carpetas. |
| **Linterna** | Hueco apagado (13, 9) | Apagado; se enciende al conocerla. |
| **Carpetas** | Confirmación con cambios sin guardar | Igual, más el bloqueo «Recupera tus archivos de la papelera» mientras tenga contenido. |
| **Primer hub guiado** (`hub_tutorial_done`) | Pendiente | **Eliminado:** lo sustituye la presentación de Notas (`"notas"` en `allies_met`). |

## 9. Arte necesario

Todo con scripts en Python (generador y validador de paleta, como `gen_hub_objects.py`). **No se usa AutoSprite.**

| Pieza | Tamaño (arte) | Paleta | Notas |
|---|---|---|---|
| **Eco compañero** (esfera con arco de sonrisa): idle (4 cuadros), parpadeo de la sonrisa (2) y hablar (2) | 32x32 (esfera de unos 22 px) | `mundo1.gpl` (`banner_blanco`, `borde_luz`, `resplandor`, `cielo`; contorno `noche_profunda`) y variante del hub con `hub.gpl` (`texto_claro`, `borde`, `traza`, `fondo_profundo`) | La oscilación y el seguimiento van por código. Formas de los mundos 2 a 6 (§12.1): más adelante. |
| **Icono Q y variantes** | 16x16 (x2) | Las dos | Placa redonda con Q o «R3», normal y pulsada. Reutiliza el dibujo de `PulsePrompt`. |
| **HUD de vidas** | 12x16 por icono (x2) | `mundo1.gpl` (y la de cada mundo) | Mini teléfono de estilo circuito (contorno y pantalla con una traza de 1 px). Lleno: pantalla encendida. Vacío: apagado en `tile_luz`. Difieren en forma y color, por daltonismo. |
| **Vida extra (pickup)** | 32x32, 4 cuadros de bote y brillo | `mundo1.gpl` | El mismo teléfono, más grande y con halo. |
| **Papelera** | 64x96 | `hub.gpl` | Estados: dormida (silueta `gris_apagado`), con contenido (parpadeo en `acento_cian` y tambaleo de 4 cuadros), vaciándose (4 cuadros) y vacía. Sin rojo. |
| **Notas** | 64x128 | `hub.gpl` | **Reskin de la copia local:** monitor con un bloc de notas y una carita. Estados: apagada (antes de la presentación), off, prompt y active. |
| **Calc apagada** | 64x96 | `hub.gpl` | El arte de Calc dormida con la pantalla negra, sin animación. |
| **UI del álbum** | Panel NinePatch y celdas de 64x64 | `hub.gpl` | Pestañas «Enemigos» y «Objetos», rejilla de fichas, celda elegida con borde `acento_cian` y vista de ficha (dibujo x2, nombre y texto). |
| **Fichas por tipo** | 32x32 o el primer cuadro del sprite | La del mundo del tipo | Se generan con un script a partir del sprite que ya existe. La **silueta «???»** es el mismo dibujo relleno en `sombra` con «???» en `texto_tenue`. |
| **Entrada del apodo** | Panel NinePatch | `eco_text_panel.png` | Rejilla de letras de `text_font` (A–Z, a–z, tildes, ñ, dígitos) navegable con el mando, más «Borrar», «Aceptar» y «Dejar "Isak"». Con teclado se escribe directamente. |
| **Transición de rollback** | Shader | | Líneas desplazadas, como el cierre del pop-up. |

**AutoSprite no hace falta:** no hay personajes humanos ni animaciones nuevas de Isak.

## 10. Plan de implementación

S = menos de medio día; M = medio día a un día; L = más de un día. Cada paso termina con `tools/run_tests.sh` en verde, los validadores del 1-1 y el bot cuando toca el 1-1 o el hub.

| # | Paso | Tamaño | Depende de | Pruebas |
|---|---|---|---|---|
| 1 | **Hecho (2026-10-16).** Acción `help` (Q / R3) en el Input Map. | S | | Acción con Q y el botón 8. |
| 2 | **Hecho (2026-10-16).** Guardado v3 (`nickname`, `allies_met`, `learned_help`, `lives_max`) y migración desde v2. | S | | Ida y vuelta v3, carga de v2, versión desconocida apartada. |
| 3 | **Hecho (2026-10-16).** Sistema de ayuda: `data/help.json`, `HelpPrompt` (a partir de `PulsePrompt`), objeto no aprendido más cercano, pausa con el cuadro de Eco y aprender por tipo. | M | 1, 2 | Q solo con Eco conocido; un tipo aprendido no muestra Q en otra instancia; la pausa se cierra con la acción; no marca «sin guardar». |
| 4 | **Hecho (2026-10-16).** Eco compañero: arte (script y validador) y `EcoCompanion` (seguimiento, oscilación, vórtice, hub). | M | | Sigue sin colisión; entra y sale con el vórtice; paleta validada. |
| 5 | **Hecho (2026-10-16).** Entrada del apodo. | M | 2 | Escribir, borrar, dejar «Isak», límite y caracteres. |
| 6 | **Hecho (2026-10-16).** Encuentro con Eco en el 1-1 (`eco_encounter`): presentación, apodo, pulso y aviso; `pulse: false`; validador; bot. | L | 3, 4, 5 | Validadores; nada exige pulso antes de la columna 11; el bot completa el 1-1; al rejugar no se repite. |
| 7 | **Hecho (2026-10-16).** Retirar o convertir las líneas del 1-1 (§4.1) y regenerar la escena. | S | 3, 6 | `build_level.py --check`; ninguna `eco_line` normal en el 1-1. |
| 8 | **Hecho (2026-10-16).** Notas: reskin de la copia local, presentación en el primer hub y menú «Guardar / Álbum / Apodo». Sustituye el resto del paso 10 de la propuesta del hub. | M | 2, 4 | La presentación sale una vez; guardar igual que hoy; la confirmación de carpeta sin cambios. |
| 9 | **Hecho (2026-10-16).** Álbum de Notas: UI, fichas por tipo generadas por script, siluetas «???» y contador; desde el 2026-10-16, carpetas por mundo y sin opción de borrar lo aprendido. | M | 3, 8 | Una ficha se desbloquea con Q; las no vistas salen como silueta; solo se abren las carpetas de mundos visitados. |
| 10 | **Hecho (2026-10-16).** Calc apagada hasta conocerla (sin tienda ni prompt). | S | 2 | Ajustar `test_calc_station.gd` y `test_upgrades.gd`; la tienda solo con `"calc"`. |
| 11 | **Hecho (2026-10-16).** Vidas: contador, reposición al entrar desde el hub e iconos del HUD. | M | 2 | Morir resta una; el checkpoint no repone; entrar desde el hub repone hasta `lives_max`. |
| 12 | **Hecho (2026-10-16).** Game over: rollback a la copia, pérdida de lo no guardado, hub, papelera (estación, parpadeo, recuperación por cercanía, historia la primera vez, caso sin copia) y bloqueo de carpetas. | L | 8, 11 | Lo no guardado se pierde; lo guardado vuelve entero desde la papelera; carpetas bloqueadas hasta recuperarla; sin copia, papelera vacía con su línea; tras recuperar, sin cambios pendientes. |
| 13 | **Hecho (2026-10-16).** Ajuste «Ayudas de Eco: Mostrar / Ocultar» en el menú de pausa. | S | 3 | La acción `pause` sin choques; abrir y cerrar sin dejar el árbol en pausa; no pisa las pausas de Eco ni los paneles; guardado al instante en `settings.cfg` (rutas de prueba propias) y cargado al reiniciar; con «Ocultar» no hay Q; no marca «sin guardar» ni toca `save.json`; `play_time_s` no avanza; el icono del hub lo abre. |
| 14 | **Hecho (2026-10-16).** Pared con glitch que se abre con el Debug y vida extra en el secreto D (`lives_max` + 1, `found_secrets`, una vez por mapa). | M | 11, Debug jugable (1-2) | Validador (secreto opcional con Debug); el máximo sube una sola vez. |
| 15 | Calc: encuentro al final del 1-2 (`propuesta-calc-encuentro.md`; tanda H1 hecha el 2026-10-17: piezas, guion de Eco, iconos en línea y sala `calc_test`; faltan H2, en el 1-2, y H3, en el hub). | M | 1-2 jugable, 10 | |
| 16 | Rollback del jefe final con la misma papelera. | M | Mundo 6, 12 | |
| 17 | Linterna en el X-1 del mundo oscuro. | M | Mundo elegido | |

**Estado (2026-10-16):** pasos 1-3 implementados (tanda 1), pasos 4 y 5 (tanda 2), pasos 6 y 7 (tanda 3: encuentro con Eco y mensajes de Eco del 1-1), pasos 8, 9 y 10 (tanda 4: Notas, su presentación y el álbum; Calc apagada) pasos 11 y 12 (tanda 5: vidas, HUD de vidas, game over, rollback, papelera y carpetas bloqueadas) paso 14 (tanda 6: pared con glitch que se abre con el Debug y vida extra del secreto D) y paso 13 (tanda 7: menú de pausa con el ajuste de ayudas e icono de ajustes del hub; tanda 8, 2026-10-16: relectura con la Q apagada, «Salir al hub», Esc vuelve una página, ajustes de accesibilidad, pantalla y controles). Pendientes: 15-17 (esperan contenido). Detalles de la implementación:

- Paso 1: acción `help` con Q (teclado) y R3 (botón 8); `tests/test_help_action.gd` comprueba que ninguna otra acción las usa.
- Paso 2: `SAVE_VERSION` 3; `hub_tutorial_done` desaparece del guardado (la migración lo traduce a `allies_met`). Conocer un asistente (`GameState.meet_ally`) y aprender una ayuda (`learn_help`) no marcan «sin guardar». La migración da por aprendidos los tipos cuyo `first_level` es un nivel completado (hoy, los del 1-1).
- Paso 3: `HelpSystem` (`scripts/levels/help_system.gd`, nodo `Help` que `tools/build_level.py` añade a cada nivel), `HelpPrompt` (la Q, en un `CanvasLayer` que sigue a la cámara, capa 6, como el punto débil) y `HelpCatalog` (`data/help.json`). Cada objeto referencia su tipo con `help_id` en sus datos (§3.3 decía que se deduce del tipo de objeto: es lo mismo, pero explícito en `data/world1_objects.json`, `data/enemies/<tipo>.json` y `data/recharge_pickup.json`; un objeto del nivel puede sustituirlo y `""` lo deja sin Q, en lugar de `"help": false`). Tipos del 1-1 (13): `alert_bubble`, `attention_point`, `receiver`, `bridge`, `popup_blocker`, `power_bank_pickup`, `sync_point`, `ability_pickup`, `charger`, `energy_drop`, `sync_drop`, `exit_terminal` y `glitch_wall` (`extra_life` llegará con el paso 14). Se aprende al pulsar Q (no al cerrar la ayuda). Mientras el juego está en pausa no hay Q. Provisional hasta el paso 6: Eco contaba como conocido en cuanto hablaba por primera vez (la bienvenida del 1-1); el paso 6 retiró esa regla. El texto de `sync_point` omite de momento «Las vidas no se recargan» porque las vidas aún no existen (las ayudas no mienten); se añadirá con el paso 11. Sin implementar aún: los campos de álbum (sprite de la ficha), el contorno cian del objeto y la Q «R3» según el último dispositivo.

- Paso 4: `EcoCompanion` (`scripts/levels/eco_companion.gd`, `scenes/levels/eco_companion.tscn`, valores en `data/eco_companion.json`). Lo crean `LevelRunner` (en cada nivel) y `HubRoom` (variante atenuada). Sigue a Isak 48 px detrás y 112 px sobre los pies (amortiguación crítica de 0,25 s, cruza por encima al girarse, oscilación ±4 px a 0,8 Hz, se recoloca con un destello a más de 4 tiles), mira hacia donde mira Isak y se dibuja detrás de los enemigos y de Isak (también de espaldas), en el lienzo del mundo, por debajo de la Q. Sin colisión. Entra y sale con Isak: aparece 0,3 s después de que Isak se vea en el vórtice de llegada y se va cuando Isak ya fue absorbido en el de salida (señal nueva `Isak.warp_began`); si Eco pasa a conocido a mitad de nivel (hoy, en la bienvenida: `EventBus.ally_met`), aparece entonces. Reacciona (destello y boca abierta) al empezar a hablar Eco y al salir una Q (`EventBus.help_prompt_shown`), y anima la boca y unas ondas de eco mientras habla. Tiempo real (`PROCESS_MODE_ALWAYS`): anima mientras habla con el juego en pausa. En el hub, arte atenuado (grises de `hub.gpl`) y opacidad 0,8 (pregunta 7: sin cobertura); no es una estación. Arte: `tools/gen_eco_companion.py` (32x32 dibujado a x2 en el juego; idle 4 cuadros con «parpadeo» de la sonrisa, habla 3, reacción 2, aparecer 4 y desaparecer = aparecer al revés, y todo en variante `_dim`), validador `tools/validate_eco_companion.py` (en `tools/run_tests.sh`). Desviaciones: la variante del hub usa grises apagados (`texto_tenue`, `gris_foto`, `gris_apagado`, `panel`, `fondo_profundo`) en lugar de `texto_claro`/`borde`/`traza` (§9) para que se lea «sin cobertura»; aún sin hacer: Eco «junto al objeto» al pedir ayuda (§2.1) y el contorno cian del objeto.
- Paso 5: `NicknameEntry` (`scenes/ui/nickname_entry.tscn`, `scripts/ui/nickname_entry.gd`, `data/nickname_entry.json`): panel de Eco con el apodo actual, se escribe con el teclado (letras con tildes y ñ, números y espacio que tenga la fuente; máximo 12; sin caracteres de control ni símbolos), la primera tecla sustituye el apodo mostrado, Retroceso borra, Intro acepta, Esc o la opción «Dejar "Isak"» dejan el actual (la fuente no tiene comillas angulares). Mando mínimo: A acepta lo que hay y B deja el actual; sin teclado el apodo no cambia. **La rejilla de letras navegable con el mando (§9) queda para el port a móvil.** Pausa el juego y la libera siempre (al cerrar y al salir del árbol). Aceptar llama a `GameState.set_nickname` (limpia con `sanitize_nickname`: recorta y une espacios; vacío = deja el actual) y, si cambia, marca «sin guardar»; emite `nickname_chosen`. `GameState.get_nickname()` y `GameState.apply_nickname()` sustituyen el marcador `{apodo}` (el de este documento) en el cuadro de Eco (`EcoTextBox.show_line`) y en las ayudas (`HelpCatalog.text`); ningún texto existente lo usa todavía. Escena de prueba: `scenes/levels/eco_companion_test.tscn` (N abre la entrada, T hace hablar a Eco con `{apodo}`, V sale y vuelve por el vórtice). Capturas: `tools/render_eco_companion.gd`.

- Paso 6: `EcoEncounter` (`scripts/levels/eco_encounter.gd`, `scenes/levels/eco_encounter.tscn`, textos en `data/eco_encounter.json`), objeto `eco_encounter` del catálogo (`data/world1_objects.json`: `id`, `width_tiles`, `height_tiles`, `eco_offset_tiles`). En el 1-1, `eco_encuentro` ocupa las columnas 10-12 y las filas 0-9 (toda la altura sobre el suelo) con Eco flotando en (12, 7) y `abilities_available.pulse` es `false`. Con Eco desconocido, Eco flota allí (arte de Eco compañero) y al entrar Isak el encuentro pausa el juego de principio a fin: «Bienvenido. He optimizado tu espacio.» → «Soy Eco, tu asistente. Yo me ocupo de todo; tú solo dime cómo quieres que te llame.» → entrada del apodo (`NicknameEntry`) → «Perfecto, {apodo}. Te regalo algo: un pulso. Sabía que lo ibas a necesitar.» → el pulso (`GameState.obtain_ability`: obtenido para siempre, se guarda) y su aviso «Pulso: G / X (mando)» → «Si algo no lo conoces, acércate y pregúntame. Te ahorro el esfuerzo.» Todas son líneas importantes. Al cerrarse la última, Eco queda conocido (`meet_ally`) y la esfera pasa a ser el `EcoCompanion` (`appear_at`: vuela desde donde flotaba hasta Isak). Con Eco conocido (rejugar, guardado migrado) no hay esfera ni presentación. **Al cargar un guardado, Eco conocido implica el pulso obtenido** (y su aviso visto): así los guardados migrados con el 1-1 completado y los v3 de antes del encuentro conservan el pulso. Se retiró la regla provisional `meet_eco_on_first_line` de `HelpSystem`. El aviso del pulso sale del encuentro (sección `notice` de `data/eco_encounter.json`, con el formato de `AbilityNotices`); se quitó la entrada `pulse` de `data/ability_notices.json` (ya no sale al empezar el 1-1; quedan el láser y el Debug). `tools/validate_level.py` modela el pulso como un estado del grafo que da el encuentro (regla 6d): sin el encuentro no hay pulso, el encuentro tiene que ser obligatorio y ninguna puerta que exija el pulso (puente, pop-up, Burbuja que no se salta, terminal) puede quedar antes. `tools/validate_level_schema.py`: un solo encuentro por nivel, en un nivel con `pulse: false`, con Eco dentro de la zona y en una celda libre. El bot (`tools/level_bot.gd`) recorre el encuentro como el jugador (cierra las líneas, acepta el apodo por defecto), comprueba el pulso antes y después y que al volver al 1-1 no se repite: recorrido de unos **99 s** caminando y 67 s corriendo (antes 98 y 66). Capturas: `tools/render_eco_encounter.gd`.
- Paso 7: el 1-1 conserva una sola línea automática, la historia del láser (`eco_laser`, importante), con la frase añadida «Lo que sueltan las alertas, recógelo: es tuyo.». La bienvenida pasó al encuentro. Las líneas «Q» de §4.1 ya estaban en `data/help.json` (paso 3) y se quitaron del nivel; las «eliminar» se borraron (también `eco_laser_disparo`). El texto de `sync_point` es ahora «Punto de sincronización. Si caes, vuelves aquí.»: no dice que guarde; la frase de las vidas se añadirá con el paso 11 (las ayudas no mienten).

- Paso 8: la estación «copia local» pasa a ser **Notas** (`NotasStation`, `NotasPanel`, `scenes/hub/notas_station.tscn`, id `notas`; sección `notas` de `data/hub.json`). Misma lógica de guardado con confirmación («¿Guardar en Notas?»); menú «Guardar», «Álbum», «Apodo: <apodo>» (abre `NicknameEntry`; cambiarlo marca «sin guardar») y «Volver». Arte por script (`tools/gen_hub_objects.py`: el mismo monitor con un bloc de notas con carita; estados `powered_off`, `off`, `prompt` y `active`; `notas_frames.tres`) e icono de Notas para el cuadro de texto. Se retiró el hueco apagado de Notas de la columna 10 del dock (la papelera irá ahí, paso 12). **Apagada** hasta su presentación: `HubStation.set_powered(false)` (sin prompt ni tecla, el pulso no la abre, arte `powered_off`); `requires_ally` en `room.stations` de `data/hub.json` enciende cada estación cuando `GameState` conoce a su asistente (al momento, con `EventBus.ally_met`). Mientras está apagada el aviso al salir no ofrece guardar. **Presentación** (`NotasIntro`, textos en `notas_intro` de `data/hub.json`): la primera vez que se entra al hub, al terminar la llegada, pausa de principio a fin; Eco (atenuado) dice «Aquí no tengo cobertura, {apodo}, pero te presento a Notas. Ella guarda por ti.» (se añadió el principio para encajar con la pregunta 7; se omite si Eco no es conocido), Notas se enciende y dice las dos líneas de §2.2 con su nombre e icono; al cerrar la última, `meet_ally("notas")` (sin marcar «sin guardar») y no se repite. El hub tiene ahora su propio cuadro de texto (`EcoTextBox`, hijo `EcoTextBox` de `HubRoom`), que admite otros que hablan (`speakers` de `data/eco_text_box.json`; las líneas de Notas no pasan por `EventBus.eco_line_*`, así que Eco no «las dice»). La confirmación «¿Seguro? Aún no has guardado.» de las carpetas no cambia. Desviación: el texto del panel de Notas es solo interfaz (sin voz propia), salvo «Apuntado. Copia guardada».
- Paso 9: álbum (`NotasAlbum`, sección `album` de `data/hub.json`; categoría, orden, nombre y texto se leen de `data/help.json`). Pestañas Enemigos y Objetos con «Fichas: n/N», rejilla de 6 columnas (marco `album_cell` y `album_cell_selected` de `tools/gen_hub_objects.py`) y, debajo, el nombre de la elegida. Desde el 2026-10-16 todo eso va dentro de una carpeta por mundo (vista de carpetas al abrir, §3.5) y el álbum no tiene opción para borrar lo aprendido. Las fichas (`assets/sprites/ui/album/`) las genera `tools/gen_album_cards.py` a partir del primer cuadro del sprite de cada tipo (recortado y reducido por un factor entero sin colores nuevos; 64x64 px de pantalla, x2 en la vista de ficha) y las valida `tools/validate_album_cards.py` (en `tools/run_tests.sh`). La silueta es el dibujo relleno en `sombra` con un contorno de 1 px en `base` (desviación de §9: sin contorno no se leía sobre la celda oscura) y «???» en `texto_tenue`; un tipo no aprendido nunca muestra su nombre ni su texto. Cada tipo va en la carpeta de su `world` (`data/help.json`); solo se abren las carpetas de mundos visitados. El pulso abre la ficha (dibujo x2, nombre y texto de Eco); el salto vuelve. Los «Sprite de la ficha» de §3.3 no van en `help.json`: el álbum los busca por tipo (`card_pattern`).
- Paso 10: Calc **apagada** hasta conocerla (`requires_ally: "calc"`): arte `powered_off` (Calc dormida más oscura con la pantalla negra, sin animación; §9), sin prompt ni tienda. El encuentro del final del 1-2 (paso 15) no existe aún: se activa con `GameState.meet_ally("calc")`, con el argumento de las builds de depuración `-- --meet-ally=calc` (`GameState.apply_debug_meet_args`) o, en las pruebas, con `EcoProgress.meet_calc()` (`tests/support/eco_progress.gd`). Regla de migración: un guardado anterior a v3 con el 1-1 completado y cualquier guardado con mejoras ya compradas dan a Calc por conocida (nadie pierde una tienda que ya usó); las partidas nuevas empiezan con Calc apagada. Economía: sin cambios; el Pulso amplio solo se puede comprar tras conocer a Calc (§2.3). La Q `calc_off` (§4.3) no está: el hub no tiene `HelpSystem` todavía.

- Paso 11: **vidas** en `GameState` (`lives`, no se guarda; `lives_max` del guardado v3). Cuentan desde la primera llegada al hub (pregunta 1: `are_lives_active()` = Notas conocida); antes, en el primer recorrido del 1-1, las muertes son ilimitadas. `LevelRunner.start_level` las repone (`refill_lives`: entrar desde la carpeta, arrancar y la tecla R); los puntos de sincronización no. Cada muerte (`Isak.died`) resta una (`lose_life`, `EventBus.life_lost`) y reaparece como siempre; la última deja el game over pendiente (`LevelRunner.is_game_over_pending`). Hueco de la vida extra (paso 14, sin implementar): `GameState.add_max_life()` sube `lives_max` y suma una al intento. **HUD:** caja `Lives` a la izquierda de la señal (`Hud`, sección `lives` de `data/hud.json`): un mini teléfono por vida hasta `lives_max` (`hud_lives.png`, 2 cuadros de 16x16 con el teléfono de 12x16 de §9: lleno con la pantalla encendida en `resplandor` y una traza `banner_blanco`; vacío apagado en `tile_luz` con una grieta; generado por `tools/gen_hud_assets.py`, validado por `tools/validate_ui_assets.py`); con más de `max_icons` (8), un icono y «x<n>» (fuente del HUD). Al perder una, el icono que se apaga parpadea 3 veces en 0,6 s y da un bote. Oculto antes de que cuenten y en el hub (§5.1). La ayuda `sync_point` dice ya «Las vidas no se recargan, eso sí.».
- Paso 12: **game over y papelera.** Con la última vida, tras la animación de muerte `LevelRunner` funde, saca el nivel del árbol, llama a **`GameState.apply_rollback(ROLLBACK_GAME_OVER)`** (la regla única de §5.3; el rollback del jefe final, paso 16, añadirá su rama y reutilizará el resto), llena Sync Rate y energía y carga el hub con el informe (`HubRoom.rollback_report`; señal `LevelRunner.game_over`). `apply_rollback`: carga la última copia del disco (`load_game`, con el `.bak` si la copia está dañada; sin copia, partida nueva): lo obtenido después de guardar se pierde y los niveles completados después hay que rejugarlos; conserva siempre (decisión del usuario; pregunta 6) los asistentes conocidos (Eco, Notas, Calc…), el apodo, las ayudas aprendidas y el pulso; activa la papelera (`"papelera"` en `allies_met`, sin subir la versión del guardado) y repone las vidas; después `discard_to_trash()` saca habilidades (salvo el pulso), power banks (completos, vacíos y carga), puntos de atención y mejoras a la papelera (`get_trash`, en memoria: no se guarda) sin cambios pendientes. Devuelve y emite (`EventBus.rollback_applied`) el informe `{reason, had_copy, first, trash_has_content, trash}`. `recover_trash()` lo devuelve todo de golpe (`EventBus.trash_recovered`); el estado vuelve a ser el de la copia, sin cambios pendientes salvo los hechos después (un apodo nuevo). **Mientras la papelera tiene contenido** (`has_trash_pending`): `save_game()` no escribe y Notas avisa «Primero recupera tus archivos de la papelera» (su resumen dice «Tus archivos están en la papelera»); `HubWorlds.can_enter` es falso y las carpetas (`FolderStation`) no se abren y, con Isak cerca, avisan «Recupera tus archivos de la papelera»; `QuitGuard` sale sin aviso ni escritura (`decide(..., trash_pending)`); el hub no ofrece «Guardar y salir»; la tecla R no vuelve a un nivel desde el hub. **Hub:** `Papelera` (`scripts/hub/papelera.gd`, sección `papelera` de `data/hub.json`, columna 10 del dock): `dormant` (el hueco apagado de siempre) hasta el primer game over, `active` con contenido (4 cuadros: borde que parpadea `acento_cian`/`cian_tenue`, archivos asomando y tambaleo), `emptying` al recuperar (4 cuadros) y `empty` (activada y vacía); se recupera al acercarse (1,5 tiles en horizontal, sin botón ni pulso, con el juego sin pausa). Arte por script (`tools/gen_hub_objects.py`, `papelera_frames.tres`; `hub.gpl`, sin rojo). **Eco al llegar** (`GameOverIntro`, textos en `data/game_over.json` con `{apodo}`): al terminar la llegada, líneas importantes (pausa) de Eco (atenuado, pero habla): la primera vez tres líneas («Lo siento, {apodo}: he tenido que restaurar tu última copia…», lo posterior se pierde y lo guardado está en la papelera); las siguientes, una; sin copia, «no había nada guardado», el pulso se queda y «guarda con Notas»; con copia sin nada que desechar, la papelera vacía. La confirmación de las carpetas mantiene «¿Seguro? Aún no has guardado.» y añade «Si caes sin guardar, Eco te devolverá a tu última copia.». Desviaciones: Eco habla en el hub, no antes de la transición (§5.2, paso 2), para que salga también tras los siguientes game over; la transición es el fundido de siempre (el shader de glitch de §9 queda pendiente); la papelera no tiene animación de «recibir» (aparece ya llena). Bot: tras el recorrido principal (sin cambiar su duración: 99 s caminando), un recorrido corto de comprobación del game over (tres muertes, hub, papelera, recuperar y volver a entrar al 1-1). Capturas: `tools/render_game_over.gd`.
- Paso 14: **pared con glitch y vida extra del secreto D.** `GlitchWall` (interacción mínima, sin tocar el Debug ni la física): con el Debug **activo** (`DebugMode.is_active()`, solo posible con la habilidad desbloqueada) e Isak a menos de `reveal_radius_px` (192 px = 3 tiles) del bloque (una `Area2D` propia), se disuelve: cada celda parpadea (`dissolve_blink`) con la capa `glitch_dissolve` a `dissolve_fps` (tiempo del mundo; señales `dissolve_started` y `opened`), deja de ser sólida y se oculta; queda abierta hasta que se recarga el nivel. Sin Debug sigue sólida y su Q (`glitch_wall`) no cambia. **Vida extra:** objeto `extra_life_pickup` del catálogo (`data/world1_objects.json`; `ExtraLifePickup`, `scenes/levels/extra_life_pickup.tscn`; params `id` y `secret_id`), en el 1-1 `vida_extra_1_1` en (298, 9), la celda de abajo de la pared (Isak la toca de pie). Si una pared con glitch cubre su celda está oculta (sin dibujo, colisión ni Q) hasta `opened`, y entonces aparece con un bote. Al tocarla, **`GameState.collect_extra_life(level, secret_id)`**: apunta el secreto en `found_secrets` (registro por mapa e id: `"1-1": ["D"]`), llama a `add_max_life()` (`lives_max` + 1 para siempre y + 1 vida en el intento; marca «sin guardar») y emite `EventBus.extra_life_collected`; una sola vez por mapa e id. Si el secreto ya está encontrado no aparece (otra carga del mapa, guardado cargado). Como todo lo obtenido, un game over sin guardar vuelve a la copia (`apply_rollback`): `lives_max` y `found_secrets` vuelven a los de la copia y la vida extra reaparece. Recogida: animación `extra_life_collect` (destello, anillo, «+1» y chispas) subiendo 32 px. **HUD:** al subir `lives_max`, el icono nuevo aparece creciendo con un destello (`gained_*` de la sección `lives` de `data/hud.json`); con más de 8, «x<n>» (ya existía). **Datos:** ayuda `extra_life` en `data/help.json` (pestaña Objetos; texto de §4.3) y su ficha del álbum (`tools/gen_album_cards.py`). Arte por script: `tools/gen_extra_life.py` (pickup de 32x32 dibujado a x2 en el juego, con 4 cuadros idle, el mini teléfono del HUD más grande con «+1» y halo cian; recogida de 4 cuadros; capa de disolución de 64x64 con 6 cuadros; `assets/sprites/extra_life_frames.tres`; `mundo1.gpl` + `effects_pulse.gpl`, sin rojos ni ámbar) con su validador `tools/validate_extra_life.py` (en `tools/run_tests.sh`). **Validadores:** `validate_level_schema.py` admite como mucho una vida extra por nivel y exige `secret_id`; `validate_level.py` (regla 4b) trata la pared con glitch como sólida sin Debug y libre con Debug, y comprueba que la vida extra no se alcanza sin Debug, sí con Debug, y no es obligatoria. La entrada del secreto D en `secrets` lleva `needs_debug: true` y `reward: "extra_life"`. **Bot:** no tiene Debug, así que no la recoge (duración sin cambio); la comprobación con Debug está en `tests/test_extra_life.gd` (`EcoProgress.obtain_debug()`). Capturas: `tools/render_extra_life.gd`. En el 1-1 actual el Debug no se obtiene (llega al final del 1-2), así que la vida extra solo se coge al volver desde el hub con el Debug. **Ajustable:** N (mapas entre vidas extra, hoy 3), el radio de apertura y la animación.
- Paso 13: **menú de pausa y ajuste de ayudas.** `PauseMenu` (`scripts/ui/pause_menu.gd`, `data/pause_menu.json`; estilo del aviso al salir: `eco_text_panel.png`, fuente de textos, colores de `mundo1.gpl`): acción `pause` (Esc / Start, ya existía en el Input Map sin choques; Select/Back sigue siendo `restart_level`) en los niveles y en el hub; se cierra con `pause` o «Reanudar». Páginas: «Pausa» (Reanudar, Ajustes, Cerrar el juego) y «Ajustes» («Ayudas de Eco: Mostrar / Ocultar», Volver). Mando: cruceta o stick eligen, A acepta, B vuelve (en la principal, reanuda), Start cierra; para que A y B funcionen en los menús, `ui_accept` y `ui_cancel` del Input Map añaden el botón A (0) y el B (1) (antes solo teclado: el «A acepta / B deja el actual» de la entrada del apodo tampoco funcionaba con el mando). «Cerrar el juego» pasa por `QuitGuard` (mismo aviso con cambios sin guardar; «Volver» deja el menú abierto). ~~Sin «Salir al hub»~~ (tanda 8, ver abajo). **Pausa:** `get_tree().paused`; con el árbol en pausa no avanzan el mundo, los temporizadores ni `GameState.play_time_s` (todos pausables). **Convención de pausas anidadas** (la de `EcoTextBox`, `NicknameEntry`, `EcoEncounter`, `NotasIntro` y `GameOverIntro`, ahora escrita en la cabecera de `pause_menu.gd`): solo se pausa si el árbol no estaba en pausa, y solo quien la puso la quita (al cerrarse y siempre al salir del árbol); `QuitGuard` se pone encima de cualquiera y la deja como estaba. Por eso el menú no se abre con el árbol en pausa (líneas importantes, ayuda con Q, entrada del apodo, presentaciones del hub, aviso al salir) ni con un nodo del grupo `pause_menu_blocker` que lo impida: `LevelRunner` (fundidos, muerte, game over, Isak en un vórtice), `HubRoom` (llegada, salida, Isak de espaldas, panel de estación o carpeta abierto; los paneles del hub no pausan) y `EcoTextBox` (con una línea en pantalla o en cola: las normales corren en tiempo real). Lo crea `LevelRunner` (hijo `PauseMenu`) o `HubRoom` abierto solo. **Ajustes** (`GameSettings`, `scripts/autoload/game_settings.gd`, clase estática): `ConfigFile` en `user://settings.cfg`, guardado al instante y aparte de la partida (no marca «sin guardar», no va en `save.json`, no lo toca un rollback); `ISAK_SETTINGS_PATH` cambia la ruta, GUT usa `user://test_settings.cfg` y los scripts `-s` `user://tool_settings.cfg` (se borran al arrancar); `tools/run_tests.sh` sale con 5 si la suite crea o cambia el `settings.cfg` real. **«Ocultar»**: `HelpSystem` no muestra ninguna Q y `help` no hace nada, así que ninguna ficha se marca como aprendida sin pedirla; el álbum de Notas conserva lo aprendido y los momentos de historia de Eco (encuentro, láser, Debug, game over, presentación de Notas) salen igual. **Hub:** icono de ajustes (engranaje de 16x16 de `tools/gen_hub_objects.py`, `icon_settings_00.png`, paleta del hub, validado por `tools/validate_hub_objects.py`) en la esquina del HUD, delante del Modo Avión; un clic abre el menú (en el hub también sirve `pause`). Desviación: el icono va en el HUD y no como objeto de la sala en (18-19, 7) de §2.2 de la propuesta del hub. El bot comprueba que el menú existe y nunca se abre en su recorrido. Capturas: `tools/render_pause_menu.gd`.
- Tanda 8 (2026-10-16, decisiones del usuario tras probar el 1-1; detalle y decisiones del equipo en `docs/preguntas.md`, «Menú de pausa: Salir al hub, ajustes, pantalla, controles y relectura»): **relectura** (`HelpSystem`: segunda Q, `HelpPrompt` estilo `REREAD`, sección `reread` de `data/help.json`; quieto `still_s` con velocidad menor que `still_speed_px_s`; `help_reread`, sin `learn_help`); **«Salir al hub»** (`LevelRunner.can_exit_to_hub` / `request_exit_to_hub`, `PauseMenu.hub_exit`; solo en un nivel completado; confirmación; pierde el intento como R, sin vidas ni rollback ni escritura); **navegación**: `pause` y B vuelven una página; **Ajustes**: «Reducir efectos de Sync bajo» y «Contorno del Debug de alto contraste» (Sí / No; `GameSettings`, sección `accessibility`), **Pantalla** (modo y tamaño; sección `display`, presets de `data/settings.json`, escala entera con bordes) y **Controles** (`ControlBindings`, sección `controls`; reasignar, conflicto con intercambiar / cancelar, reservadas Esc / Start, «Restablecer valores»; los prompts de tecla se actualizan con `EventBus.controls_changed`). Capturas: `tools/render_help.gd` (04-05) y `tools/render_pause_menu.gd` (07-14).

Orden: los pasos 1 y 2 a la vez; después 3, 4 y 5 en paralelo; después 6 → 7; después 8, 10 y 11 en paralelo; después 9 y 12. Los pasos 14 a 17 esperan contenido (1-2 y mundos posteriores).

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Pedir ayuda junto a un enemigo | Radio de 4 tiles para enemigos y pausa inmediata. |
| Demasiadas pausas | Ayudas opcionales y por tipo; la historia se limita a pocos momentos. |
| R3 cuesta en el mando | Prompt visible con «R3»; se puede añadir un segundo botón. |
| Perder lo no guardado frustra | La confirmación al entrar a una carpeta lo avisa (con el texto propuesto en §5.2), el primer game over lo explica Eco y Notas lo dice al presentarse. |
| Jugar sin habilidades tras un game over | Carpetas bloqueadas hasta recuperar la papelera. |
| Game over sin copia deja a Isak sin pulso | Pregunta 6. |
| Validadores y bot dependen del pulso desde el inicio | Paso 6 dedicado; el pulso como estado del grafo. |
| Migración del guardado | v3 con migración probada y `.bak`. |
| Eco en el hub contradice la «zona sin señal» | Pregunta 7. |
| Apodo con caracteres que la fuente no tiene | Limitar al juego de `text_font`. |

## 12. Preguntas abiertas (con recomendación)

1. **¿Desde cuándo cuentan las vidas?** *Recomendación:* desde la primera llegada al hub. En el primer recorrido del 1-1, las muertes son ilimitadas como hoy (dificultad 1/5): no hay game over antes de conocer el hub y Notas.
2. **Mundo oscuro de Linterna** (decisión del usuario). *Recomendación:* el Mundo 4 (chat de madrugada), al entrar en el 4-1; `04-personajes.md` §12.3 ya la sitúa allí.
3. **Papelera y el 4-2:** `04-personajes.md` la presenta en «Mensajes borrados» del 4-2, donde sabe el secreto de Eco. *Recomendación:* actúa en silencio desde su primer uso y habla por primera vez en el 4-2.
4. **¿El rollback de Normal** (lo lanza Isak, engañado) **usa también la papelera?** *Recomendación:* sí, es la misma regla (§5.3); solo cambia quién lo lanza.
5. **Tono de Eco por vuelta.** *Recomendación:* servicial en Caché, insistente en Kernel y seco en Raíz; las ayudas con Q nunca mienten.
6. **Game over sin copia previa: ¿qué pasa con el pulso y el registro** (Eco conocido, apodo, álbum)? Volver a «nada guardado» quitaría el pulso, y el 1-1 lo exige desde el receptor de la columna 56. *Recomendación:* el registro (`allies_met`, `nickname`, `learned_help`) y el pulso no se pierden nunca en un game over. El pulso es el regalo de Eco: si no estaba guardado, Eco lo devuelve en la misma línea de «no había nada guardado».
7. **Eco en el hub frente a la «zona sin señal»** (`05-hub.md` §13.1: el único sitio al que Eco no llega). *Recomendación:* Eco entra sin cobertura, con la esfera atenuada; no guarda ni compra por Isak (lo hacen Notas y Calc); el Modo Avión se mantiene.

## 13. Documentos que cambian

- `04-personajes.md`: §12.1 y §12.3.
- `05-hub.md`: §13.1, §13.2, §13.3, §13.4 y §13.6.
- `02-isak-habilidades.md`: pulso concedido por Eco y vidas (intentos) frente a Sync Rate (salud).
- `propuesta-hub-y-guardado.md`: §3.1, §3.2, §3.3 (la «Vuelta» de la maqueta), §5 y paso 10.
- `preguntas.md`: sección «Decisiones del 2026-10-15 (3)» y marcas de reemplazo.
- `08-pendientes.md`, `INDEX.md`, `CLAUDE.md`, `mundo-1-notificaciones.md` (§6.3 y §6.4), `propuesta-1-1-ampliado.md` (§3) y `07-estilo-visual.md` (rol `gris_apagado`).
