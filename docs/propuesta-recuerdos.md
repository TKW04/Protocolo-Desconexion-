# Propuesta: recuerdos de jefe en tres capas

**Estado:** **decisión APROBADA por el usuario el 2026-10-18** («me parece genial dale»; la idea de que cada jefe entregue un recuerdo es del usuario, las tres capas y los dos tipos son propuesta del orquestador). Sin implementar. **Decisiones del 2026-10-18 (2.ª tanda, §8):** sexto jefe, final real con todos los recuerdos de jefe, ilustración, mensajes por mundo y capas perdidas. **Decisiones del 2026-10-19 (3.ª tanda, §9 y §10, del usuario):** las preguntas de §9 quedan cerradas (todas con su recomendación salvo la 4, que se decide al revés: los mensajes de secretos **sí** son requisito del final real y reaparecen en Kernel y Raíz si no se obtuvieron); familia de Isak decidida (el **Abuelito** y **Mamá**, `04-personajes.md` §12.5); esbozo del Mundo 1 (§5) y mensajes de los secretos del 1-1, 1-2 y 1-3 como **borradores de tono** (texto provisional). El plan (§7) sigue siendo **propuesta pendiente de aprobación**. Los textos de cada recuerdo son historia: se escriben mundo a mundo con el usuario.

**Decisiones que respeta:** tres vueltas Caché / Kernel / Raíz (Easy / Normal / Hard internos; el jugador no sabe que hay varias vueltas: `preguntas.md`, «Nombres externos»); guardado manual en Notas (lo obtenido sin guardar se pierde en un game over); el rollback conserva los registros (`found_secrets`, álbum); V16 (los coleccionables no desbloquean nada; el candado de La Nube usa los fragmentos de los jefes); todos los personajes hablan **solo con texto**.

## 1. La decisión

1. **Los recuerdos se obtienen al vencer a cada jefe.** En cada vuelta hay que vencer a los 6 jefes: los 5 de fragmento (Mundos 1-5) y, en La Nube, a Isak Optimizado, que cuenta como el **sexto jefe** (§8.1). Cada jefe entrega el recuerdo del mundo que cuida. Alerta Mayor ya lo hacía («Fragmento de concentración», `mundo-1-notificaciones.md` §6.6); ahora es regla de todo el juego.
2. **Tres capas, una por vuelta.** El recuerdo de cada jefe se entrega por partes:

| Capa | Vuelta (acceso) | Qué es |
|---|---|---|
| 1 | **Caché** (Easy interno) | Un fragmento borroso: una escena incompleta. |
| 2 | **Kernel** (Normal interno) | La escena completa. |
| 3 | **Raíz** (Hard interno) | La verdad detrás de la escena, incluida la parte que Eco ocultó. |

   Total: **6 jefes × 3 capas = 18 recuerdos de jefe.** No se escriben ahora: cada mundo escribe los suyos cuando se construya.
3. **Dos tipos que conviven en la pestaña «Recuerdos» de Notas:**
   - **Recuerdos de jefe:** escenas de Isak, grandes y emocionales; uno por jefe y capa.
   - **Mensajes de secretos:** correos y mensajes de texto de familiares y amigos que se hallan en los secretos de los niveles; pequeños. Ejemplo: la carpeta de Spam del 1-2. Los «recuerdos coleccionables» de los secretos de `mundo-1` … `mundo-6` pasan a ser de este tipo. **Desde el 2026-10-19 son requisito del final real** y, si no se obtienen en Caché, el mismo secreto los vuelve a ofrecer en Kernel y en Raíz (§10).
4. **Guardado y rollback:** son «cosas obtenidas»: si no se guardan en Notas antes de un game over, se pierden. **Una vez guardados se conservan como registro a través de los rollbacks** (como los secretos encontrados). La escena de recompensa del jefe avisa «Guarda en Notas para conservarlo» (**texto del sistema**, no de Eco; decidido el 2026-10-19).
5. **Solo texto**, sin voz ni sonido propio.

## 2. Relación con los fragmentos

El recuerdo de jefe **es** el fragmento que Eco robó (concentración, tiempo, imagen, amistades, voluntad; `03-historia.md`) visto por capas. El fragmento como pieza de la historia (lo que pide el candado de La Nube y lo que se enciende en la galería del 6-3) se obtiene ya con la capa Caché; las capas Kernel y Raíz no cambian la progresión, solo lo que se lee. El sexto, el de La Nube, lo entrega Isak Optimizado (§8.1).

## 3. Pestaña «Recuerdos» en Notas

- **Dónde:** en el álbum de Notas, junto a Enemigos y Objetos, **por carpetas de mundo** como el álbum (`propuesta-asistentes-y-vidas.md` §3.5): Notificaciones, El Feed, La Vitrina, El Chat, La Tienda, La Nube. Las carpetas de mundos no visitados siguen cerradas con «???».
- **Dentro de cada carpeta, dos secciones:** «Jefe» (arriba) y «Mensajes» (debajo).
- **Sección Jefe:** una fila con las capas del recuerdo de ese jefe. **Sin spoilear las vueltas:** solo se muestran las ranuras de las capas cuyo acceso ya se alcanzó (en Caché, una; en Kernel, dos; en Raíz, tres). Las capas de un acceso no alcanzado **no aparecen** (ni candado ni nombre). Una capa alcanzada y no obtenida sale como ficha «???».
- **Sección Mensajes:** una ficha por mensaje del mundo; las no halladas, «???» (el jugador ve cuántas le faltan, como en el álbum).
- **Contador:** «Recuerdos: n/N» por carpeta, contando solo lo visible (capas alcanzadas + mensajes).
- **Ficha abierta:** título, texto (con ilustración solo en las capas Kernel y Caché de jefe; §8.3) y, en los de jefe, la capa («Caché», «Kernel», «Raíz»). Los mensajes llevan remitente y asunto.
- **Nueva entrada:** el icono de Notas en el hub marca lo no leído; se lee en el hub, nunca en mitad de un nivel.

## 4. Guardado y rollback

| Situación | Qué pasa con los recuerdos |
|---|---|
| Se vence a un jefe o se recoge un mensaje | Queda **obtenido sin guardar** (como los puntos o una habilidad). Se puede leer en Notas desde ese momento. |
| Se guarda en Notas | Pasa a la lista `memories` del guardado: es **registro**. |
| Game over sin guardar | Lo obtenido después de la última copia **se pierde**; el jefe y el secreto se pueden repetir. |
| Rollback de fin de vuelta (jefe final) o game over con copia | Lo guardado **se conserva** (no va a la Papelera: es registro, como `found_secrets` y el álbum). |
| Siguiente vuelta | El jefe entrega la capa del nuevo acceso. Los mensajes de secretos ya guardados no se repiten; los mensajes **no obtenidos** en Caché reaparecen en el mismo secreto en Kernel y, si siguen sin obtenerse, en Raíz (§10); los mensajes propios de Kernel y Raíz se deciden al construir cada mundo (§8.4). |
| Game over que se lleva una capa (§8.5) | Sin regla especial: se vuelve al último guardado, el jefe vuelve a estar sin vencer y al derrotarlo de nuevo entrega otra vez la capa. **Red de seguridad:** al vencer a un jefe se entregan además las capas inferiores que falten en el registro (p. ej. guardados anteriores a este sistema). |

## 5. Esbozo del Mundo 1 (borrador de tono, decidido el 2026-10-19)

El «Fragmento de concentración» de Alerta Mayor se convierte en la **capa Caché** del recuerdo del Mundo 1. **Texto provisional:** es la plantilla de tono para los demás mundos con la regla **Caché = imagen, Kernel = contexto, Raíz = qué hizo Eco con ella** (§9.6). Sustituye al esbozo anterior, que usaba «alguien de su familia»: la familia ya está decidida (el Abuelito, que vive con Isak, y Mamá; `04-personajes.md` §12.5).

- **Caché (fragmento, ya en §6.6):** el circuito sobre la mesa de la cocina; se ven las manos de Isak, el soldador y un LED que no enciende; al lado, unas manos viejas sostienen una lupa. Eco: «Archivado».
- **Kernel (escena completa):** una tarde larga en la cocina de casa. El Abuelito no dice nada, solo acerca la lupa cuando Isak entrecierra los ojos. El LED enciende; Isak levanta la vista y el Abuelito ya estaba sonriendo.
- **Raíz (la verdad):** el celular vibra tres veces sobre la mesa; Isak no lo mira, el Abuelito tampoco. Eco lo guardó como «sesión improductiva: 3 h sin interacción» y recortó la sonrisa. Eco: «No era un recuerdo útil».

## 6. Qué cambia en los documentos

- `mundo-1-notificaciones.md` §6.6: la recompensa de Alerta Mayor es la capa Caché del recuerdo del Mundo 1 (nota).
- `mundo-2` … `mundo-6`, sección del jefe: nota «recompensa: recuerdo de jefe (tres capas)» sin cambiar su contenido. Los «recuerdos coleccionables» de sus secretos se leen como mensajes de secretos (sin marcar cada uno).
- `06-finales.md` §14.1: el final real exige los 18 recuerdos de jefe **y todos los mensajes de secretos** (2026-10-19) y muestra el ensamblaje (§8.2).
- `propuesta-1-2.md`: el recuerdo coleccionable de la carpeta de Spam es un **mensaje de secreto**, no un recuerdo de jefe.
- `04-personajes.md` (Notas), `propuesta-asistentes-y-vidas.md` §2.2, `preguntas.md`, `08-pendientes.md`, `INDEX.md` y `CLAUDE.md`: referencias a esta propuesta.

## 7. Plan de implementación (pasos pequeños)

| Paso | Qué | Tamaño | Depende de |
|---|---|---|---|
| 1 | **Datos:** `data/memories.json` con una entrada por recuerdo: `id`, `world` (1-6), `kind` (`boss` / `secret`), `layer` (1-3, solo jefe), `title`, `text`, `sender` (solo mensajes), `subject` (solo mensajes), `order`; en los mensajes, además, `level` y `secret` (el secreto que lo ofrece) y `first_lap` (vuelta en que aparece, 1 = Caché) con la regla **«reaparece si no se obtuvo»**: un mensaje con `first_lap` *n* se ofrece en esa vuelta y en todas las siguientes mientras no esté en el registro (§10). Textos provisionales «(por escribir)». Validador de esquema en `tools/` (ids únicos, capas 1-3 por jefe, mundo válido, cada mensaje enlazado a un secreto existente). | S | — |
| 2 | **Estado y guardado:** `GameState.memories` (ids obtenidos), `obtain_memory(id)` con señal en `EventBus`; guardado del campo `memories` (lista) con migración que lo crea vacío; se conserva en el rollback, no va a la Papelera; lo no guardado se pierde con el game over como lo demás. Pruebas GUT. | M | 1 |
| 3 | **Pestaña «Recuerdos» en Notas:** por carpetas de mundo, secciones Jefe y Mensajes, «???», capas ocultas por encima del acceso actual (`HubWorlds.access_name()`), contador y lectura de la ficha. Pruebas en `tests/test_notas_album.gd` o una nueva. | M | 2 |
| 4 | **Mensaje de secreto en niveles:** objeto `memory_pickup` (param `memory_id`, ayuda Q en `data/help.json`, ficha del álbum), arte por script. **Reaparece si no se obtuvo:** el objeto sale en cualquier vuelta mientras su `memory_id` no esté en el registro y no sale si ya está (no depende de `found_secrets` de esa vuelta). Nuevo tipo de recompensa **`memory`** en el array `secrets` de `data/levels/*.json` (`{"reward": "memory", "memory_id": …}`; puede convivir con la recompensa que ya da el secreto, p. ej. el punto del secreto A del 1-1). Ficha «???» en Notas (remitente oculto) y la Q de Eco marca el secreto (§10). Validador: cada mensaje debe ser alcanzable con lo que el jugador puede tener en ese acceso (sin exigir una mejora o habilidad que aún no pueda tener). Mensajes previstos: **1-1**, secreto A `secreto_puente_servicio` (x 96, sin mejoras); **1-2**, **carpeta de Spam**: el ancla del paso 14 es la celda **(26, 37)** de `data/levels/1-2.json` (secreto `secreto_spam` en (25, 36), piso 2; filas ya desplazadas 4 por la tanda H2; comprobado el 2026-10-18). Validador: el objeto cuenta como recogible del secreto. | M | 2, texto del mensaje |
| 5 | **Entrega al vencer a un jefe:** al morir el jefe, escena de recompensa con el texto de la capa del acceso actual y el aviso «Guarda en Notas para conservarlo»; entrega además las capas inferiores que falten (red de seguridad, §8.5). Isak Optimizado entrega la suya al terminar el combate y antes del rollback en Caché y Kernel, y en Raíz justo antes del momento de decisión (§8.1). | M | 2, **que exista el jefe** (Alerta Mayor primero) |
| 6 | **Textos por mundo:** los 3 de jefe y los 3 mensajes de Caché de cada mundo (uno por subnivel), con el usuario, al construir ese mundo; los de Kernel y Raíz, si los hay, también entonces. | S por mundo | historia |
| 7 | **Arte de las ilustraciones (decisión pendiente, §9.1):** una ilustración pixel-art por jefe para su capa Kernel (6 en total), **recomendado por script** con el estilo del juego (`tools/gen_memory_art.py` o similar, con validador como las demás herramientas de arte); la capa Caché usa la misma imagen con un filtro de baja resolución y dither (en el script o en un shader de la ficha). Se hace por mundo, con el texto de su capa Kernel ya escrito. | S por mundo | 6, decisión de §9.1 |
| 8 | **Condición del final real (§8.2, §10):** `GameState.has_all_memories()` (las 18 capas de jefe **y todos los mensajes de secretos** de `data/memories.json` en el registro; decisión del 2026-10-19); el momento de decisión del final real la comprueba y muestra el ensamblaje de los seis recuerdos ante Eco (`06-finales.md` §14.1). Comprobar al implementar que en Raíz se puede volver a entrar a los niveles completados de la vuelta actual (carpetas de mundos completados, `preguntas.md` §13.2) para buscar un mensaje pendiente antes del jefe final. Pruebas GUT. | M | 2, 4, 5 y el jefe final |

## 8. Decisiones del 2026-10-18 (2.ª tanda)

Antes eran las preguntas 1-5 de esta sección. Las del usuario se marcan como suyas; las demás son del orquestador.

1. **Sexto jefe (usuario):** Isak Optimizado cuenta como el jefe del Mundo 6 (La Nube) y entrega su capa de recuerdo. En **Caché** y **Kernel**, al terminar el combate y **antes del rollback**, aunque escape (Caché) o engañe a Isak (Kernel). En **Raíz**, **justo antes del momento de decisión** del final real (`06-finales.md` §14.1). Como los demás, se conserva si se guarda; si el rollback llega antes de guardar, rige §4.
2. **Final real (usuario: «sí»):** el final real **exige tener todos los recuerdos de jefe**: los 18 (6 jefes × 3 capas). Como se consiguen venciendo a cada jefe en cada vuelta, el camino normal ya los cumple; el requisito asegura el ensamblaje, no añade búsqueda. **Cómo se muestra (propuesta, sin texto de historia definitivo):** al llegar al momento de decisión con los 18, los seis recuerdos se ensamblan ante Eco, cada uno con sus tres capas, y a Eco se le desmorona la «versión optimizada» de Isak que había construido con ellos; el momento de decisión sigue igual después.
   - **Mensajes de secretos (cambiado por el usuario el 2026-10-19, §10):** también son requisito. Para que siga siendo justo aunque las vueltas anteriores no se rejueguen, un mensaje no obtenido reaparece en el mismo secreto en la vuelta siguiente (Kernel y Raíz).
3. **Ilustración (usuario):** una ilustración pixel-art **solo para la capa Kernel** de cada jefe (6 imágenes). La capa **Caché** muestra **la misma imagen borrosa** (filtro o dither de baja resolución). La capa **Raíz** y todo lo demás (mensajes), **solo texto**. Cómo se hacen las 6 imágenes: §9.1.
4. **Mensajes de secretos (usuario):** **3 por mundo en Caché, uno por subnivel.** Los de Kernel y Raíz se deciden al construir cada mundo; no se inventan ahora.
5. **Capas perdidas por un game over (orquestador):** sin regla especial. Un game over devuelve al último guardado, el jefe vuelve a estar sin vencer y hay que derrotarlo otra vez; el recuerdo se entrega de nuevo. **Red de seguridad:** al vencer a un jefe se entregan además las capas inferiores que falten (p. ej. guardados anteriores a este sistema). Así nunca falta una capa de jefe para el final real (§8.2).

## 9. Preguntas de la 2.ª tanda (cerradas el 2026-10-19)

Todas decididas por el usuario el 2026-10-19 con la recomendación, salvo la 4, que se decide **al revés** (§10).

1. **¿Ilustraciones por script o con AutoSprite?** **Por script**, con el estilo del juego (como el resto del arte de objetos y del hub), sin AutoSprite (sus créditos, ~470, están reservados a enemigos y jefes).
2. **Mensajes de Kernel y Raíz:** cuántos y dónde, se decide al construir cada mundo (¿solo si el mapa cambia?). Aparte de ellos, los de Caché no obtenidos reaparecen (§10).
3. **Texto de los recuerdos:** los 18 de jefe, los mensajes de secretos y la escena del ensamblaje del final real (§8.2) son historia: se escriben con el usuario, mundo a mundo. Borradores de tono ya decididos: §5 y §10.
4. **¿El final real exige también los mensajes de secretos?** **Sí** (contra la recomendación anterior, que decía que no). Reglas en §10.
5. **¿Quién dice «Guarda en Notas para conservarlo»?** **Texto del sistema** (Eco no tiene interés en que Isak recuerde).
6. **El esbozo del Mundo 1 (§5) como tono:** **sí**, con la regla «Caché = imagen, Kernel = contexto, Raíz = qué hizo Eco con ella».
7. **¿Eco reacciona en la Raíz?** **Sí**, con una línea breve tras leer la capa Raíz (en Raíz Eco ya no es amable), escrita con cada mundo.

## 10. Decisiones del 2026-10-19 (usuario)

1. **Mensajes de secretos, requisito del final real.** El final real exige los 18 recuerdos de jefe **y todos los mensajes de secretos** (`GameState.has_all_memories()`, §7 paso 8). Para que sea justo y encontrable:
   - Un mensaje **no obtenido en Caché se vuelve a ofrecer en el mismo secreto en Kernel** y, si sigue sin obtenerse, **en Raíz**. Ya obtenido (y guardado), no vuelve a salir.
   - Cada mensaje es **alcanzable con lo que el jugador tiene en ese acceso**: no exige una mejora o habilidad que aún no pueda tener.
   - En Notas, el mensaje no hallado sale como ficha **«???»** (remitente oculto) y la **Q de Eco marca el secreto** donde está.
   - Dentro de la vuelta actual se pueden volver a entrar los niveles completados (carpetas de mundos completados, `preguntas.md` §13.2) para buscar un mensaje pendiente antes del jefe final de Raíz. **Verificar y anotar al implementar.**
   - Consecuencias técnicas: `has_all_memories()` (el nombre anterior solo cubría las capas de jefe) cubre también los mensajes; el esquema de `data/memories.json` y `memory_pickup` soportan «reaparece si no se obtuvo» (§7, pasos 1 y 4); nuevo tipo de recompensa `memory` en el array `secrets` de los niveles (§7, paso 4).
2. **Familia de Isak** (`04-personajes.md` §12.5): el **Abuelito** (así lo llama Isak; repara radios, le enseñó a soldar; enlaza con el nombre «Isak Fix»; vive con Isak: la cocina del recuerdo es la de casa) y **Mamá**, que escribe los mensajes de secretos y firma con humor. Tono cálido y cotidiano, sin pérdida ni duelo.
3. **Esbozo del Mundo 1:** el de §5 (borrador de tono, texto provisional).
4. **Mensajes de secretos del Mundo 1 (borradores, texto provisional):**

| Nivel | Secreto | Mensaje |
|---|---|---|
| **1-1** | Secreto A `secreto_puente_servicio` (x 96), junto al punto que ya da; sin crear secreto nuevo; alcanzable sin mejoras. Requiere la recompensa `memory` en `secrets` de `data/levels/1-1.json` (sin hacer). | De: Mamá · Asunto: «Recado del Abuelito» · «Isak, el Abuelito dice que el circuito de ayer «solo necesita paciencia y un poquito de estaño». Te dejó la lupa en la mesa. Yo no entiendo nada, pero me pidió que te avisara.» — «Mamá (te escribo desde la cocina)». |
| **1-2** | Carpeta de Spam, ancla en la celda (26, 37), secreto `secreto_spam`. Eco desvió los mensajes de Mamá a Spam. | De: Mamá · Asunto: «¿Cenas con nosotros?» · «Isak, el Abuelito hizo sopa y dice que no empieza hasta que bajes. Ya se enfrió una vez. Avísame si te toca otra vez «solo cinco minutitos».» — «Mamá (sí, otra vez)». |
| **1-3** | Concepto, sin posiciones ni nivel en datos: sala secreta **«Excepciones»** (la lista de contactos que pueden saltarse el No molestar, «Permitir llamadas de: Favoritos») tras una pared visible **solo con el Debug**; la ruta exige **solo el Debug** (no Deslizar: C5 «dash frente a pulso» sigue abierta). Idea: lo único que debería poder interrumpirte es tu familia. | De: Mamá · «Vi que pusiste No molestar. Está bien. Aquí te dejo esto por si algún día lo miras.» — «Mamá (no te molesto, prometido)». |

   Los mensajes definitivos del 1-3 y los de los demás mundos se escriben al construir cada nivel.
