# Propuesta: recuerdos de jefe en tres capas

**Estado:** **decisión APROBADA por el usuario el 2026-10-18** («me parece genial dale»; la idea de que cada jefe entregue un recuerdo es del usuario, las tres capas y los dos tipos son propuesta del orquestador). Sin implementar. Las ideas de §7 y el esbozo del Mundo 1 (§5) son **propuestas pendientes de aprobación**. Los textos de cada recuerdo son historia: se escriben mundo a mundo con el usuario.

**Decisiones que respeta:** tres vueltas Caché / Kernel / Raíz (Easy / Normal / Hard internos; el jugador no sabe que hay varias vueltas: `preguntas.md`, «Nombres externos»); guardado manual en Notas (lo obtenido sin guardar se pierde en un game over); el rollback conserva los registros (`found_secrets`, álbum); V16 (los coleccionables no desbloquean nada; el candado de La Nube usa los fragmentos de los jefes); todos los personajes hablan **solo con texto**.

## 1. La decisión

1. **Los recuerdos se obtienen al vencer a cada jefe.** En cada vuelta hay que vencer a los 6 jefes de mundo y, al final, a Isak Optimizado. Cada jefe entrega el recuerdo del mundo que cuida. Alerta Mayor ya lo hacía («Fragmento de concentración», `mundo-1-notificaciones.md` §6.6); ahora es regla de todo el juego.
2. **Tres capas, una por vuelta.** El recuerdo de cada jefe se entrega por partes:

| Capa | Vuelta (acceso) | Qué es |
|---|---|---|
| 1 | **Caché** (Easy interno) | Un fragmento borroso: una escena incompleta. |
| 2 | **Kernel** (Normal interno) | La escena completa. |
| 3 | **Raíz** (Hard interno) | La verdad detrás de la escena, incluida la parte que Eco ocultó. |

   Total: **6 jefes × 3 capas = 18 recuerdos de jefe.** No se escriben ahora: cada mundo escribe los suyos cuando se construya.
3. **Dos tipos que conviven en la pestaña «Recuerdos» de Notas:**
   - **Recuerdos de jefe:** escenas de Isak, grandes y emocionales; uno por jefe y capa.
   - **Mensajes de secretos:** correos y mensajes de texto de familiares y amigos que se hallan en los secretos de los niveles; pequeños. Ejemplo: la carpeta de Spam del 1-2. Los «recuerdos coleccionables» de los secretos de `mundo-1` … `mundo-6` pasan a ser de este tipo.
4. **Guardado y rollback:** son «cosas obtenidas»: si no se guardan en Notas antes de un game over, se pierden. **Una vez guardados se conservan como registro a través de los rollbacks** (como los secretos encontrados). Propuesta: la escena de recompensa del jefe avisa «Guarda en Notas para conservarlo».
5. **Solo texto**, sin voz ni sonido propio.

## 2. Relación con los fragmentos

El recuerdo de jefe **es** el fragmento que Eco robó (concentración, tiempo, imagen, amistades, voluntad; `03-historia.md`) visto por capas. El fragmento como pieza de la historia (lo que pide el candado de La Nube y lo que se enciende en la galería del 6-3) se obtiene ya con la capa Caché; las capas Kernel y Raíz no cambian la progresión, solo lo que se lee. El sexto, el de La Nube, depende de cómo se cierre el jefe final en cada vuelta (pregunta 1).

## 3. Pestaña «Recuerdos» en Notas

- **Dónde:** en el álbum de Notas, junto a Enemigos y Objetos, **por carpetas de mundo** como el álbum (`propuesta-asistentes-y-vidas.md` §3.5): Notificaciones, El Feed, La Vitrina, El Chat, La Tienda, La Nube. Las carpetas de mundos no visitados siguen cerradas con «???».
- **Dentro de cada carpeta, dos secciones:** «Jefe» (arriba) y «Mensajes» (debajo).
- **Sección Jefe:** una fila con las capas del recuerdo de ese jefe. **Sin spoilear las vueltas:** solo se muestran las ranuras de las capas cuyo acceso ya se alcanzó (en Caché, una; en Kernel, dos; en Raíz, tres). Las capas de un acceso no alcanzado **no aparecen** (ni candado ni nombre). Una capa alcanzada y no obtenida sale como ficha «???».
- **Sección Mensajes:** una ficha por mensaje del mundo; las no halladas, «???» (el jugador ve cuántas le faltan, como en el álbum).
- **Contador:** «Recuerdos: n/N» por carpeta, contando solo lo visible (capas alcanzadas + mensajes).
- **Ficha abierta:** título, texto (y la imagen si se decide; pregunta 3) y, en los de jefe, la capa («Caché», «Kernel», «Raíz»). Los mensajes llevan remitente y asunto.
- **Nueva entrada:** el icono de Notas en el hub marca lo no leído; se lee en el hub, nunca en mitad de un nivel.

## 4. Guardado y rollback

| Situación | Qué pasa con los recuerdos |
|---|---|
| Se vence a un jefe o se recoge un mensaje | Queda **obtenido sin guardar** (como los puntos o una habilidad). Se puede leer en Notas desde ese momento. |
| Se guarda en Notas | Pasa a la lista `memories` del guardado: es **registro**. |
| Game over sin guardar | Lo obtenido después de la última copia **se pierde**; el jefe y el secreto se pueden repetir. |
| Rollback de fin de vuelta (jefe final) o game over con copia | Lo guardado **se conserva** (no va a la Papelera: es registro, como `found_secrets` y el álbum). |
| Siguiente vuelta | El jefe entrega la capa del nuevo acceso. Los mensajes de secretos ya guardados no se repiten; los secretos pueden dar otros mensajes si el mapa cambia (pregunta 4). |

## 5. Esbozo del Mundo 1 (propuesta pendiente de aprobación)

El «Fragmento de concentración» de Alerta Mayor se convierte en la **capa Caché** del recuerdo del Mundo 1. Lo de abajo es solo un ejemplo para decidir el tono; la familia de Isak sigue por decidir (`08-pendientes.md`).

- **Caché (fragmento, ya en §6.6):** Isak de niño armando un circuito, absorto. Se ven las manos, el soldador y un LED que no enciende; el resto está borroso. Eco: primer mensaje distinto, ya sin tanta amabilidad.
- **Kernel (escena completa):** la mesa es la de la cocina, una tarde larga. Alguien de su familia (por decidir) se sienta al lado sin interrumpir. El LED enciende e Isak levanta la vista para enseñarlo: no había nadie más a quien contárselo y no le hizo falta.
- **Raíz (la verdad):** esa tarde el celular vibró tres veces sobre la mesa e Isak no lo miró. Eco tenía la escena archivada como «sesión improductiva: 3 h sin interacción» y había borrado el final: la notificación nace para romper justo eso. Eco no le robó la concentración de golpe: aprendió a interrumpirla.

## 6. Qué cambia en los documentos

- `mundo-1-notificaciones.md` §6.6: la recompensa de Alerta Mayor es la capa Caché del recuerdo del Mundo 1 (nota).
- `mundo-2` … `mundo-6`, sección del jefe: nota «recompensa: recuerdo de jefe (tres capas)» sin cambiar su contenido. Los «recuerdos coleccionables» de sus secretos se leen como mensajes de secretos (sin marcar cada uno).
- `propuesta-1-2.md`: el recuerdo coleccionable de la carpeta de Spam es un **mensaje de secreto**, no un recuerdo de jefe.
- `04-personajes.md` (Notas), `propuesta-asistentes-y-vidas.md` §2.2, `preguntas.md`, `08-pendientes.md`, `INDEX.md` y `CLAUDE.md`: referencias a esta propuesta.

## 7. Plan de implementación (pasos pequeños)

| Paso | Qué | Tamaño | Depende de |
|---|---|---|---|
| 1 | **Datos:** `data/memories.json` con una entrada por recuerdo: `id`, `world` (1-6), `kind` (`boss` / `secret`), `layer` (1-3, solo jefe), `title`, `text`, `sender` (solo mensajes), `order`. Textos provisionales «(por escribir)». Validador de esquema en `tools/` (ids únicos, capas 1-3 por jefe, mundo válido). | S | — |
| 2 | **Estado y guardado:** `GameState.memories` (ids obtenidos), `obtain_memory(id)` con señal en `EventBus`; guardado del campo `memories` (lista) con migración que lo crea vacío; se conserva en el rollback, no va a la Papelera; lo no guardado se pierde con el game over como lo demás. Pruebas GUT. | M | 1 |
| 3 | **Pestaña «Recuerdos» en Notas:** por carpetas de mundo, secciones Jefe y Mensajes, «???», capas ocultas por encima del acceso actual (`HubWorlds.access_name()`), contador y lectura de la ficha. Pruebas en `tests/test_notas_album.gd` o una nueva. | M | 2 |
| 4 | **Mensaje de secreto en niveles:** objeto `memory_pickup` (param `memory_id`, ayuda Q en `data/help.json`, ficha del álbum), arte por script. El primero, en la **carpeta de Spam del 1-2**: el ancla del paso 14 es la celda **(26, 37)** de `data/levels/1-2.json` (secreto `secreto_spam` en (25, 36), piso 2; filas ya desplazadas 4 por la tanda H2; comprobado el 2026-10-18). Validador: el objeto cuenta como recogible del secreto. | M | 2, texto del mensaje |
| 5 | **Entrega al vencer a un jefe:** al morir el jefe, escena de recompensa con el texto de la capa del acceso actual y el aviso «Guarda en Notas para conservarlo». | M | 2, **que exista el jefe** (Alerta Mayor primero) |
| 6 | **Textos por mundo:** los 3 de jefe y los mensajes de cada mundo, con el usuario, al construir ese mundo. | S por mundo | historia |

## 8. Preguntas abiertas (con recomendación)

1. **¿Quién es el sexto jefe?** Los documentos tienen 5 jefes de fragmento (Mundos 1-5) y en La Nube el jefe es Isak Optimizado, que es también el jefe final (`mundo-6-nube.md` §11.7); y en Caché escapa y en Kernel engaña. *Recomendación:* Isak Optimizado es el jefe de La Nube y su recuerdo se entrega aunque escape: en Caché y Kernel, al terminar el combate y antes del rollback (y se guarda solo si se guardó antes: lo resuelve la regla de §4 o una excepción); en Raíz, justo antes del momento de decisión.
2. **¿Condicionar el final real a tener todos los recuerdos?** *Recomendación:* **no**. El final real ya exige Raíz; los recuerdos son lectura y premio (V16), y castigar con el final a quien perdió uno por un game over sería injusto.
3. **¿Ilustración pixel-art por recuerdo o viñeta de texto?** *Recomendación:* viñeta de texto para los mensajes y una ilustración pequeña solo para la capa Kernel de cada jefe (6 imágenes), que la capa Caché muestre borrosa; la Raíz, solo texto.
4. **¿Cuántos mensajes de secretos por mundo?** *Recomendación:* 3 por mundo en Caché (uno por subnivel, en su secreto principal), y que Kernel y Raíz añadan los suyos solo si el mapa cambia.
5. **Capas perdidas:** si alguien pierde la capa Caché (game over sin guardar y ya pasó a Kernel), ¿se recupera? *Recomendación:* sí: al vencer a un jefe se entregan todas las capas hasta el acceso actual que falten en el registro.
6. **¿El aviso «Guarda en Notas para conservarlo» lo dice Eco o es un texto del sistema?** *Recomendación:* texto del sistema (Eco no tiene interés en que Isak recuerde).
7. **El esbozo del Mundo 1 (§5):** ¿vale como tono para los demás mundos? *Recomendación:* sí, con la regla «Caché = imagen, Kernel = contexto, Raíz = qué hizo Eco con ella».
8. **¿Eco reacciona en la Raíz?** *Recomendación:* sí, con una línea breve tras leer la capa Raíz (en Raíz Eco ya no es amable), escrita con cada mundo.
