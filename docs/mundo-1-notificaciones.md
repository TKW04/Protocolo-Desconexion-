# 6. Mapa conceptual: Mundo 1, Notificaciones

Origen: sección 6 del documento original (`docs/original/diseno.md`).

**Rol en la historia:** es el tutorial y la primera pérdida, la concentración. Eco se presenta aquí con una voz amable y servicial.

**Idea del mundo:** el celular visto desde la pantalla de bloqueo. Todo lo que debería ser útil está diseñado para interrumpirte.

## 6.1 Ambientación

- **Paleta:** fondo azul noche oscuro, acentos rojo alerta y banners blancos. El Debug de este mundo es cian, para contrastar con el rojo.
- **Música:** chiptune construido con tonos de notificación. El ritmo de la música coincide con el ritmo de los peligros.
- **Humor:** pop-ups con textos absurdos, como "¿Seguro que quieres seguir concentrado? Tenemos ofertas" o "Tienes 99+ mensajes que no son importantes". Los botones de cerrar son diminutos o falsos.
- **Lo oscuro:** Isak apenas recuerda qué estaba haciendo antes de entrar. Cada interrupción se lo borra un poco más.

## 6.2 Enemigos y elementos del mundo

| Elemento | Comportamiento | Cómo se resuelve |
|---|---|---|
| **Burbuja de alerta** | Patrulla de lado a lado. Hace daño al contacto. | Pulso para aturdir y pasar, o saltar sobre ella aturdida. |
| **Banner** | Barre un pasillo horizontalmente a intervalos fijos. | Cronometrar el salto o, desde 1-3, atravesarlo con dash. |
| **Punto rojo (badge)** | Persigue lentamente a Isak. Si lo alcanza, quita Sync Rate. | Aturdir con el pulso o dejarlo atrás con saltos. |
| **Pop-up** | Aparece sobre la pantalla y tapa parte de la vista o bloquea un paso. | Pulso al botón de cerrar, que casi siempre es muy pequeño. |
| **Recordatorio** | Plataforma con temporizador que cae cuando "vence". | Cruzar antes de que venza. |

## 6.3 Nivel 1-1: Bandeja de entrada

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Enseñar movimiento, salto y pulso. Duración aproximada: 3 minutos. |
| **Dificultad** | 1 de 5. Prácticamente sin riesgo de muerte. |
| **Tramo 1** | Aterrizaje. Isak cae al mundo y no hay enemigos. Plataformas anchas y un foso pequeño para practicar el salto. Primera voz de Eco: "Bienvenido. He optimizado tu espacio." |
| **Tramo 2** | Puente desactivado. El pulso lo activa y enseña que el pulso afecta al entorno. |
| **Tramo 3** | Primera Burbuja de alerta, sola y lenta. Se aprende a aturdirla. |
| **Tramo 4** | Pop-up que bloquea el paso. El botón de cerrar es diminuto y hay que acertarle con el pulso. |
| **Cierre** | Puerta "Marcar como leído", que da paso al siguiente nivel. |
| **Secreto** | Una pared con un leve glitch, sin forma de acceder todavía. Se retoma cuando Isak tenga el Debug. |
| **Punto de sincronización** | Uno a mitad de nivel. |

> **Cambio aprobado 2026-10-15 (3)** (`propuesta-asistentes-y-vidas.md` §7):
> - En el Tramo 1, Isak se topa con Eco (columna 11): Eco se presenta con la «primera voz» de arriba, pide un apodo y da el pulso. Antes del encuentro nada exige pulso.
> - Las demás líneas de Eco pasan a ayuda con Q por tipo.
> - El secreto de la pared con glitch guarda la vida extra del 1-1 y exige el Debug.
> - **Implementado el 2026-10-16** (pasos 6 y 7 de la propuesta): el 1-1 empieza sin pulso; el encuentro ocupa las columnas 10-12 (`eco_encounter`, textos en `data/eco_encounter.json`) y la «primera voz» abre la presentación. La única línea automática que queda en el nivel es la historia del láser.

## 6.4 Nivel 1-2: Centro de notificaciones

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Introducir el Debug Mode, los enemigos que persiguen y los pop-ups que tapan la vista. Duración aproximada: 5 minutos. |
| **Dificultad** | 2 de 5. |
| **Estructura** | Nivel vertical. Isak sube una torre y cada piso es una pestaña. |
| **Piso 1: Mensajes** | Primeros puntos rojos persiguiendo. Se enseña a aturdirlos y a no quedarse quieto. |
| **Piso 2: Correo** | Banners de spam que barren el piso horizontalmente. Aquí el Debug se vuelve obligatorio: falta una plataforma que solo se ve con él, y el juego lo explica con una pista visual. |
| **Piso 3: Recordatorios** | Plataformas con temporizador que caen al vencer. Mezcla de saltos precisos y timing. |
| **Piso 4: Actualizaciones** | Una barra de progreso que se queda trabada en 99% y un tramo de espera humorístico con enemigos cayendo. |
| **Mecánica de overlay** | Pop-ups translúcidos cubren zonas de la vista. Se cierran con el pulso o se atraviesan viendo con el Debug. |
| **Secreto** | La carpeta de Spam, detrás de una plataforma oculta. Contiene puntos de atención extra y el primer recuerdo coleccionable. |
| **Puntos de sincronización** | Uno cada dos pisos. [Hecho: al entrar a los pisos 2 y 4] |

> **Cambio aprobado 2026-10-15 (3):** tras obtener el Debug, al final del 1-2, Isak encuentra a **Calc**; desde entonces hay tienda en el hub. La historia del encuentro está por decidir (`propuesta-asistentes-y-vidas.md` §2.3).

> **Implementado (2026-10-16, paso 13 de [propuesta-1-2.md](propuesta-1-2.md) §10):** el 1-2 es jugable desde la carpeta del Mundo 1 del hub tras completar el 1-1 (`data/levels/1-2.json`, `scenes/levels/1-2.tscn`); diseño final tramo a tramo y desvíos en la propuesta (§10, «Hecho en el paso 13»). Faltan el recuerdo coleccionable y Calc en la azotea (paso 14) y el bot vertical (paso 15).

> **Decisiones del usuario 2026-10-16 y propuesta de diseño ([aprobada] el 2026-10-16):** [propuesta-1-2.md](propuesta-1-2.md), con el «lenguaje de combinaciones» de pulso y láser (§0) para todos los niveles. Lo que cambia de la tabla de arriba:
> - **Piso 2:** [Reemplazado] el Debug no aparece sin más: se **obtiene en el piso 2 resolviendo un acertijo de pulso + láser** (decisión del usuario); después, la plataforma oculta lo hace obligatorio (orden: acertijo → Debug → plataforma visible → continuar). Calc sigue al final del 1-2, en la azotea.
> - **Piso 3:** se añade el **botón «Posponer»** (objetivo del láser que alarga el temporizador de los recordatorios; decisión del usuario).
> - **Pop-ups translúcidos:** uno por piso (1, 3 y 4); el del piso 3 es opcional.
> - **Secretos:** la carpeta de Spam (piso 2, exige el Debug) y dos más (B en el piso 1, C en el piso 3), con 9 puntos de atención en total.
> - **Puntos de sincronización:** al entrar a los pisos 2 y 4.

## 6.5 Nivel 1-3: No molestar

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Enseñar el dash y el ritmo. Duración aproximada: 6 minutos. |
| **Dificultad** | 3 de 5 dentro del mundo. |
| **Inicio** | Sala "Ajustes". Isak encuentra el interruptor "No molestar" y obtiene el gesto Deslizar. Es un pequeño momento narrativo y Eco comenta algo molesto. |
| **Tramo 1** | Pasillos con banners que barren a un ritmo fijo. El dash atraviesa un banner con invulnerabilidad breve. |
| **Tramo 2** | Plataformas que parpadean al ritmo de una vibración. Hay que saltar con el pulso de la música. |
| **Tramo 3** | Combinación de dash y pulso contra Burbujas de alerta y puntos rojos juntos. |
| **Tramo 4** | Túnel de alarmas que se acelera. Es la prueba final antes del jefe. |
| **Cierre** | Puerta de bloqueo de pantalla que lleva al jefe. |
| **Secreto** | Ruta alterna que solo se ve con el Debug y premia con puntos de atención y un recuerdo. |

> **Concreción del secreto (decisión del usuario, 2026-10-19; concepto, sin posiciones ni datos):** la ruta alterna lleva a la sala secreta **«Excepciones»** (la lista de contactos que pueden saltarse el No molestar: «Permitir llamadas de: Favoritos»), tras una pared visible **solo con el Debug**. **La ruta exige solo el Debug** (no Deslizar), porque C5 «dash frente a pulso» sigue abierta y este mensaje es obligatorio para el final real. El «recuerdo» es el **mensaje de secreto** del 1-3: un mensaje de Mamá (borrador provisional en [propuesta-recuerdos.md](propuesta-recuerdos.md) §10; idea: lo único que debería poder interrumpirte es tu familia). Si no se obtiene en Caché, reaparece en Kernel y Raíz.

## 6.6 Jefe: Alerta Mayor

Un enorme badge rojo con el número "99+", la notificación que representa todas las demás. Eco habla a través de él.

| Aspecto | Detalle |
|---|---|
| **Arena** | La pantalla de bloqueo, un espacio amplio con relojes y notificaciones flotando al fondo. |
| **Punto débil** | Un núcleo que solo se ve con el Debug Mode, en rojo. Obliga a gastar energía con inteligencia. |
| **Fase 1** | Lanza burbujas y banners. El pulso los aturde y abre una ventana para activar el Debug y golpear el núcleo. |
| **Fase 2** | Cubre la pantalla con pop-ups que tapan la vista. Hay que cerrarlos con el pulso y esquivar con dash. |
| **Fase 3** | Aparecen notificaciones falsas, copias del jefe. Solo la real tiene núcleo bajo el Debug. |
| **Recompensa** | Fragmento de concentración: un recuerdo de Isak de niño armando un circuito, absorto. Primer mensaje distinto de Eco, ya sin tanta amabilidad. |

> **Decisión del usuario (2026-10-18):** este fragmento es la **capa Caché** del recuerdo de jefe del Mundo 1 (recuerdos de jefe en tres capas: Caché, Kernel y Raíz, una por vuelta); ver [propuesta-recuerdos.md](propuesta-recuerdos.md). Desde el 2026-10-19 el borrador de tono de sus tres capas (circuito en la cocina de casa con el Abuelito) está en su §5 (texto provisional).
