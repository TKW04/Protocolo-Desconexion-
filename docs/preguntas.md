# Preguntas abiertas sobre el documento de diseño

**Estado (2026-10-15):** resueltos C1, C4 (Mundo 1: hub tras cada nivel), C6, C7, C9, V2, V3, V7, V10 (paleta), V11, V12, A4, A8, A10, A11, y el hub y el guardado manual («Hub y guardado: propuesta aprobada (2026-10-15)», al final). Decididos el 2026-10-15 (3), sin implementar: asistentes, ayuda con Q, vidas y Papelera («Decisiones del 2026-10-15 (3)», al final; `propuesta-asistentes-y-vidas.md`). Aplazado: V15. Resuelto el 2026-10-19: C5 (el dash es un gesto aparte, `gesture_swipe`). En C9 la dificultad ya no se elige: es una progresión por **tres vueltas** (Easy, Normal y Hard; engaño en Normal, final real en Hard), aprobada el 2026-10-15 a falta de detalle (ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado», al final; hay una sugerencia de dificultad pendiente de aprobar). Siguen abiertos: C2, C3, C8, V1, V4, V5, V6, V8, V9, V10 (tileset), V13, V14, V16, A1, A2, A3, A5, A6, A7, A9, A12, A13, A14, A15, A16, y las dudas de las tres vueltas.

**Nota (2026-10-14):** con C6 se aprobó también un cambio de diseño de Isak: el personaje de la hoja de referencia `../Ejemplo/Idle.png` (arte IA) reemplaza al del documento (sin lentes ni chaqueta verde oliva; chaqueta gris oscura táctica con detalles cian; celular en la mano). Ver `07-estilo-visual.md` §15.4. El texto creativo de `04-personajes.md` (Isak Optimizado), `06-finales.md` y `mundo-6-nube.md` todavía menciona los lentes de Isak; no se ha tocado y queda pendiente de decidir. Los valores en px de A5, A6, A7 y otras propuestas abiertas están escritos para 640x360; al aprobarlos hay que revisarlos para la nueva escala.

Análisis de `docs/original/diseno.md` (v2), contrastado con `CLAUDE.md` y los skills `godot-isak-fix`, `pixel-art-pipeline` y `level-builder`.

**Cómo leer este documento**

- Numeración: **C** = contradicciones, **V** = vacíos, **A** = ambigüedades técnicas.
- **[BLOQUEA SLICE]** = hay que resolverlo antes de cerrar el vertical slice (Isak caminar/correr/saltar/idle/pulso, Debug Mode básico, HUD con Sync Rate y energía, tileset del Mundo 1, nivel 1-1 completo con la Burbuja de alerta).
- **[Fuera del slice]** = puede esperar.
- Todas las **propuestas** son mínimas, provisionales y requieren aprobación. No añaden historia, personajes ni mecánicas nuevas; solo fijan valores o interpretaciones para poder implementar.

---

## 1. Contradicciones

### C1 [RESUELTO] Ruta del documento fuente
- **Sección:** `CLAUDE.md` ("Fuente de verdad"), skills `godot-isak-fix` y `level-builder` frente a la ubicación real `docs/original/diseno.md`.
- **Problema:** `CLAUDE.md` y los skills mandan leer `docs/diseno.md`, que no existe. Un agente que siga las reglas al pie de la letra no encuentra la fuente de verdad.
- **Propuesta:** actualizar las referencias en `CLAUDE.md` y en los skills a `docs/original/diseno.md` (o mover el archivo a `docs/diseno.md` y conservar una sola copia).
- **Por qué:** hay una sola fuente de verdad, y la ruta tiene que coincidir con lo que piden las reglas.
- **Decisión (2026-10-14):** ya corregido (CLAUDE.md y skills apuntan a la nueva estructura).

### C2 [BLOQUEA SLICE] ¿El Debug Mode forma parte del 1-1 y del vertical slice?
- **Sección:** §6.3 (1-1: "Enseñar movimiento, salto y pulso"; Secreto: "Se retoma cuando Isak tenga el Debug"), §6.4 (1-2: "Introducir el Debug Mode"), §15.9 y `CLAUDE.md` ("Isak jugable (caminar, saltar, idle, pulso)") frente al alcance del slice que se pidió (incluye Debug Mode básico y HUD con energía).
- **Problema:** según el diseño, Isak no tiene el Debug en el 1-1, y el slice de `CLAUDE.md`/§15.9 no incluye ni el Debug ni el HUD. El alcance pedido sí los incluye.
- **Propuesta:** implementar el sistema de Debug y el HUD completo, pero dejar el Debug **bloqueado en el 1-1** mediante el flag de habilidades de `GameState` (como en el diseño), y probarlo en una escena de prueba (`scenes/levels/sandbox`) o con un flag de desarrollo. El HUD muestra la batería desde el inicio.
- **Por qué:** respeta el diseño (el Debug se enseña en el 1-2) sin dejar el sistema fuera del slice. Hay que confirmar el alcance con el usuario.

### C3 [Fuera del slice; afecta a A10] ¿Cuándo se pueden gastar por primera vez los puntos de atención?
- **Sección:** §10.2 ("por primera vez se pueden gastar") frente a §13.3 (Calc, que llega después del Mundo 1, vende mejoras a cambio de puntos de atención) y §3.3/§15.7 (la energía de Debug "se recupera con puntos de atención").
- **Problema:** el Mundo 5 dice ser el primer sitio donde se gastan puntos, pero el hub ya los cobra desde el Mundo 1. Además no está claro si recargar energía consume puntos.
- **Propuesta:** leer §10.2 como "por primera vez se gastan **dentro de un nivel**". Recoger un punto suma al contador y recarga energía a la vez, sin descontar nada.
- **Por qué:** es la lectura que reconcilia las tres secciones sin cambiar ninguna mecánica.

### C4 [RESUELTO (Mundo 1)] Qué pasa al terminar un nivel: ¿hub o siguiente nivel?
- **Sección:** §13.5 ("Al terminar un nivel, Isak vuelve al hub") frente a §13.1 (el hub no existe hasta vencer a Alerta Mayor), §6.3 (Cierre: la puerta "da paso al siguiente nivel") y §7.4 (2-1: "entra en el siguiente nivel sin poder pararse").
- **Problema:** las reglas de transición se contradicen. En el Mundo 1 no puede haber vuelta al hub, y el 2-1 encadena con el siguiente nivel de forma explícita.
- **Propuesta:** los niveles de un mundo se encadenan y se vuelve al hub tras el jefe (y al salir de un mundo ya completado). En el slice, la puerta "Marcar como leído" lleva a una pantalla de "Fin del slice" que permite reiniciar el nivel.
- **Por qué:** es la única regla compatible con §6.3, §7.4 y §13.1. Para el slice basta con un final limpio.
- **Decisión (2026-10-15):** el hub aparece desde el final del 1-1 y se vuelve a él tras cada nivel del Mundo 1 (hub mínimo con Calc dormida, **[Reemplazado 2026-10-15 (3)]**: Calc apagada hasta el final del 1-2; `05-hub.md` §13.1 y `propuesta-hub-y-guardado.md`, pregunta 1). El encadenado explícito del 2-1 (§7.4) se revisará al diseñar el Mundo 2.

### C5 [RESUELTO] El dash "convierte" el pulso frente al uso de pulso y dash por separado
- **Sección:** §3.5 (Deslizar: "El pulso se convierte en un dash de datos") frente a §6.5 (1-3, Tramo 3: "Combinación de dash y pulso") y §6.6 (Fase 2: "cerrarlos con el pulso y esquivar con dash").
- **Problema:** si el pulso se sustituye por el dash, ya no se pueden usar los dos en el mismo tramo.
- **Propuesta:** el dash es una variante del pulso que se activa con el gesto, y el pulso normal sigue disponible. El mapeo de controles queda pendiente, porque es una decisión abierta de `CLAUDE.md`.
- **Por qué:** es la única lectura compatible con los niveles y el jefe del Mundo 1.
- **Decisión (2026-10-19, usuario):** el dash (gesto Deslizar) es un **gesto aparte**, variante del pulso con su **propia acción** `gesture_swipe` del Input Map (L / B del mando hoy; tecla y botón propios, reasignables en Ajustes > Controles); **el pulso normal sigue disponible**, así que el Tramo 3 del 1-3 y la Fase 2 de Alerta Mayor usan los dos. **El dash no sube de nivel** (sin pista de Calc; los gestos progresan por las combinaciones del Mundo 5; la pista de Energía lo abarata de forma indirecta). Por defecto (sin objeción del usuario): cuesta energía con enfriamiento corto, se usa en el suelo y en el aire, Isak es invulnerable mientras dura, atraviesa banners y proyectiles pero no el terreno ni los objetos sólidos, y no se combina con el Ocultarte ni con el Debug. Valores provisionales y detalle en `propuesta-1-3.md` §2.

### C6 [RESUELTO] Tamaño del sprite: ¿regla fija o decisión abierta?
- **Sección:** `CLAUDE.md` ("Reglas fijas": canvas de 64x64, y "Decisiones abiertas": 64x64 o 48x48), §15.1 (64x64, alternativa de 48x48) y §16.
- **Problema:** el mismo archivo declara el tamaño a la vez como regla fija y como decisión abierta. Si cambia, cambian la altura de Isak (§15.1: "un tile y medio") y la validación de niveles.
- **Propuesta:** usar 64x64 como provisional para el slice y desacoplar la hitbox del canvas (ver A5), de modo que pasar a 48x48 solo afecte al arte y no a la física ni a los niveles.
- **Por qué:** así el slice puede servir de prueba del tamaño, como pide §15.9, sin rehacer los niveles.
- **Decisión (2026-10-14):** resolución base 1280x720 (stretch `viewport`, escala `integer`); Isak a unos 96 px visibles en un canvas de 128x128 con los pies abajo-centro; tiles de 64x64. La física se duplica con los mismos tiempos (salto de 192 px, `jump_velocity` −960, gravedad 2400, caminar 220 px/s, correr 360 px/s). Además, el diseño de Isak de `../Ejemplo/Idle.png` reemplaza al del documento (ver `07-estilo-visual.md` §15.4).

### C7 [RESUELTO] ¿Saltar sobre un enemigo aturdido lo elimina o lo usa como plataforma?
- **Sección:** §3.2 ("el enemigo aturdido se puede eliminar o usar como plataforma") frente a §6.2 (Burbuja: "saltar sobre ella aturdida").
- **Problema:** no se dice qué acción elimina y cuál convierte al enemigo en plataforma, ni qué pasa si Isak salta sobre una Burbuja que **no** está aturdida.
- **Propuesta:** mientras está aturdida, la Burbuja es una plataforma sólida de una vía. Si Isak cae sobre ella con velocidad vertical positiva, la elimina (pop) y rebota. Si no está aturdida, siempre hace daño al contacto, también desde arriba.
- **Por qué:** cubre las dos opciones de §3.2 con una sola regla y respeta "Hace daño al contacto" de §6.2.
- **Decisión (2026-10-14):** aprobada la propuesta (aturdida = plataforma de una vía; caer encima con velocidad vertical positiva la elimina y rebota; sin aturdir siempre daña). El umbral entre pisar y caer se ajusta jugando.
- **Cambio (2026-10-15, decisión del usuario):** la caída **ya no** elimina a la Burbuja. Aturdida sigue siendo plataforma de una vía (escalón), pero solo muere cuando su vida llega a 0 con el láser. El pop por caída queda desactivado (`stomp_pop_enabled: false` en `data/enemies/alert_bubble.json`). Ver «Láser, vida de enemigos y energía (2026-10-15)».

### C8 [Fuera del slice] El reloj del HUD no figura en el HUD
- **Sección:** §7.1 ("el reloj del HUD salta horas de golpe") frente a §15.7 (el HUD solo incluye señal, batería y contador de puntos).
- **Problema:** el Mundo 2 depende de un reloj que la especificación del HUD no incluye.
- **Propuesta:** reservar en la barra de estado del HUD un hueco para la hora, oculto en el Mundo 1 y visible desde el Mundo 2.
- **Por qué:** una barra de estado de celular lleva hora, y reservar el hueco ahora evita rehacer el layout del HUD más adelante.

### C9 [RESUELTO] Estado de los finales y escala de dificultad
- **Sección:** §4 ("Los dos finales están por desarrollar") y §11.7 ("se desarrollan en el siguiente paso") frente a §14, que los desarrolla, y a §16 ("Revisar y ajustar"). Por otra parte, la dificultad aparece a veces como "X de 5" (1-1, 2-1, 4-1…) y a veces como "X de 5 dentro del mundo" (1-3, 2-3, 4-3), con 4-1 = 4/5 y 4-3 = 5/5 "dentro del mundo".
- **Problema:** las notas de estado de los finales están desfasadas, y la escala de dificultad mezcla una escala global con otra por mundo.
- **Propuesta:** considerar §14 como el estado vigente (pendiente de revisión) e interpretar toda la dificultad como escala global.
- **Por qué:** §14 es la sección más reciente y detallada, y una sola escala sirve de guía para la duración y la densidad de peligros.
- **Decisión (2026-10-14):** se dejan sin cambios; se mejorarán durante el desarrollo.
- **Decisión (2026-10-14, actualización):** la dificultad **ya no se elige**. C9 queda sustituida por una dificultad que evoluciona con el juego (confirmado por el usuario).
- **Decisión (2026-10-15):** la dificultad evoluciona por **tres vueltas** (Easy, Normal y Hard); no hay selector de dificultad. Aprobada a falta de detalle (ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado»). Cómo encaja con la escala «X de 5» de cada nivel tiene una sugerencia del equipo pendiente de aprobar (dos ejes: curva por nivel y perfil por vuelta).

---

## 2. Vacíos que impiden implementar

### V1 [BLOQUEA SLICE] Controles base
- **Sección:** §3.1, §3.2 y §14.1 (mencionan un "botón de interacción"). `CLAUDE.md` solo deja abiertos los gestos.
- **Problema:** no hay mapeo para moverse, saltar, correr, pulso, Debug ni interactuar. Tampoco se dice si correr se hace con un botón o por aceleración (el skill define caminar a 110 y correr a 180, pero no tiene estado `Walk`).
- **Propuesta:** teclado: flechas/A-D para moverse, Z/Espacio para saltar, X para el pulso, C para el Debug, mantener Shift para correr, flecha arriba para interactuar. Mando: stick o cruceta, A saltar, X pulso, RB Debug, mantener B para correr, arriba para interactuar. Todo a través del Input Map, para poder reasignarlo.
- **Por qué:** es un esquema estándar del género, y correr con un botón mantenido hace legible la diferencia 110/180 que exige el skill.

### V2 [RESUELTO] Muerte, reaparición y puntos de sincronización
- **Sección:** §3.4 (solo el efecto visual), §6.3 ("Punto de sincronización: uno a mitad de nivel") y §13.3 (Papelera "guarda parte de los puntos que Isak pierde al morir").
- **Problema:** no se define qué ocurre al morir (dónde reaparece, con cuánto Sync Rate, si pierde puntos de atención) ni qué hace un punto de sincronización además de servir de checkpoint.
- **Propuesta:** con Sync Rate = 0, animación de muerte y reaparición en el último punto de sincronización (o en `P`) con 100% de Sync Rate y la energía que tenía. Tocar un punto de sincronización lo activa y repone el Sync Rate al 100%. En el slice no se pierden puntos de atención; esa regla queda pendiente para cuando exista Papelera. **[Reemplazado 2026-10-15 (3)]**: morir con vidas restantes no quita nada; con 0 vidas hay game over y rollback a la última copia (lo no guardado se pierde y lo guardado vuelve desde la Papelera). Ver «Decisiones del 2026-10-15 (3)».
- **Por qué:** es lo mínimo para cerrar el ciclo de juego. "Sincronización" sugiere restaurar el Sync, y la pérdida de puntos depende de sistemas posteriores.
- **Decisión (2026-10-14):** aprobada la propuesta. La energía de Debug no se repone al reaparecer; se queda como está.

### V3 [RESUELTO] El foso del Tramo 1 de un nivel "sin riesgo de muerte"
- **Sección:** §6.3 (Tramo 1: "un foso pequeño"; Dificultad: "Prácticamente sin riesgo de muerte").
- **Problema:** no se define qué ocurre al caer en un foso (muerte, daño o simple caída a un nivel inferior).
- **Propuesta:** el foso del Tramo 1 tiene fondo: se puede salir caminando o saltando. En general, caer fuera del nivel quita un 20% de Sync Rate y devuelve a Isak al último suelo seguro.
- **Por qué:** practicar el salto sin castigo encaja con la dificultad 1/5, y la regla general sirve para el resto de niveles.
- **Decisión (2026-10-14):** la penalización del 20 % de Sync Rate se aplica desde el nivel 1-2. En el 1-1 la red de seguridad no quita nada (se queda así).

### V4 [BLOQUEA SLICE] El puente desactivado (Tramo 2 del 1-1)
- **Sección:** §3.2 y §6.3 (Tramo 2).
- **Problema:** no se dice dónde hay que golpear con el pulso (el propio puente o un receptor), cuánto dura activo ni qué aspecto tiene cada estado.
- **Propuesta:** un receptor visible (con brillo, según §15.2 "Pocas luces") en el extremo del puente. Un pulso lo activa **de forma permanente** y los tiles aparecen de izquierda a derecha. El foso bajo el puente tiene fondo, con salida (ver V3).
- **Por qué:** es un tutorial: un efecto permanente y un objetivo claro enseñan que "el pulso afecta al entorno" sin añadir presión de tiempo.

### V5 [BLOQUEA SLICE] El pop-up bloqueante y su botón de cerrar (Tramo 4 del 1-1)
- **Sección:** §6.2 (Pop-up: "Aparece sobre la pantalla") y §6.3 (Tramo 4).
- **Problema:** no se dice si el pop-up es un objeto del nivel (muro) o una capa sobre la pantalla, cuánto mide, dónde está el botón de cerrar ni qué pasa al cerrarlo. Además el pulso es "a corta distancia" y no tiene apuntado (ver A3).
- **Propuesta:** en el 1-1, un objeto sólido del nivel de 3x4 tiles con un texto de humor sacado de §6.1, y un botón de cerrar de unos 8x8 px a la altura del pulso de Isak, de pie o en el apogeo del salto. Al acertarle, el pop-up se cierra con una animación y desaparece de forma permanente. Los pop-ups de capa sobre la vista quedan para el 1-2.
- **Por qué:** "diminuto" sigue siendo un reto de puntería, pero alcanzable con un pulso horizontal y sin apuntado libre.

### V6 [BLOQUEA SLICE] Cómo se muestra la voz de Eco
- **Sección:** §6.3 (Tramo 1: "Primera voz de Eco") y §12.1 (en el Mundo 1, "aparece en pop-ups").
- **Problema:** no hay sistema de diálogo: no se sabe si es texto, si detiene el juego, cuánto dura ni si tiene voz. La música y el sonido son decisiones abiertas.
- **Propuesta:** una notificación con la esfera de Eco en la parte superior de la pantalla, solo texto, que no pausa el juego, se dispara al entrar en una zona y desaparece a los 4 s. Sin audio por ahora.
- **Por qué:** encaja con "aparece en pop-ups" y con el tema del Mundo 1 sin cortar el ritmo del tutorial.
- **Decisión del usuario (2026-10-15):** los mensajes **importantes** (habilidad adquirida, historia, cosas relevantes) pausan el juego y se cierran con una acción del jugador; los menores (ayuda contextual) siguen sin pausar, en tiempo real y en cola. **[Reemplazado 2026-10-15 (3)]**: ya no hay mensajes menores automáticos; la ayuda contextual se pide con Q (pausa) y se aprende por tipo. Motivo: si el jugador avanza rápido, un aviso pisaba a otro y no sabía a qué acción correspondía cada uno. Detalle en las notas del paso 14b.

### V7 [RESUELTO] Formato de nivel: elementos del 1-1 que el grid no soporta
- **Sección:** skill `level-builder` (leyenda) frente a §6.3 (puente desactivado, pop-up, puerta "Marcar como leído", pared con glitch, disparador de Eco).
- **Problema:** la leyenda no tiene caracteres para estos elementos, y el skill pide preguntar antes de improvisar. Además, la regla de validación 4 asume secretos con `h`, mientras que el secreto del 1-1 es una pared sin acceso.
- **Propuesta:** añadir al JSON una lista `objects` con `{type, x, y, params}` para `bridge_inactive`, `popup_blocker`, `exit_door`, `glitch_wall` y `eco_trigger`, sin tocar la leyenda del grid. El validador trata `bridge_inactive` como transitable solo después de su receptor y excluye `glitch_wall` de la regla 4.
- **Por qué:** es una extensión mínima y compatible con el formato, y deja las mecánicas en scripts propios, como pide el skill.
- **Decisión (2026-10-14):** aprobada (lista `objects` en el JSON del nivel).

### V8 [BLOQUEA SLICE] Puntos de atención en el 1-1 y su origen
- **Sección:** §3.3, §15.7 y §6.3 (la ficha no los menciona).
- **Problema:** el HUD del slice muestra el contador, pero no se dice si hay puntos en el 1-1, cuántos ni si los enemigos los sueltan.
- **Propuesta:** entre 10 y 20 puntos (`o`) repartidos por los tramos, en las rutas obvias. Los enemigos no sueltan puntos.
- **Por qué:** el contador tiene algo que mostrar, el jugador aprende el objeto antes de necesitarlo en el 1-2, y no se inventa ningún drop.

### V9 [BLOQUEA SLICE] Cómo se obtiene el Debug
- **Sección:** §3.5 ("kit base de hacker (pulso y Debug)"), §6.3 ("cuando Isak tenga el Debug") y §6.4.
- **Problema:** los gestos tienen un momento de obtención, pero el Debug no. Las secciones lo describen a la vez como parte del kit base y como algo que se consigue más tarde.
- **Propuesta:** el Debug se desbloquea al empezar el 1-2 (flag en `GameState`) con una pista visual, sin escena nueva. En el slice, ver C2.
- **Por qué:** coincide con "Introducir el Debug Mode" del 1-2 y no añade historia.

### V10 [RESUELTO: paleta] Contenido del tileset del Mundo 1 y paleta
- **Sección:** §6.1 y §15.3 (paleta solo descrita con palabras), §15.2, y `CLAUDE.md`/`pixel-art-pipeline` (hex pendientes de aprobación).
- **Problema:** no hay lista de tiles ni colores exactos, y el skill exige aprobar la paleta antes de usarla.
- **Propuesta:** un set mínimo: suelo/pared con autotile (bitmask 3x3), plataforma de una vía, puente en sus dos estados, receptor, pared con glitch, pinchos, fondo de pantalla de bloqueo con relojes en parallax, y una paleta de 16 colores (azul noche, blancos de banner, rojo anaranjado de alerta, carmín, cian) para aprobar como imagen.
- **Por qué:** cubre todo lo que pide la ficha del 1-1, y la aprobación de la paleta ya está prevista en el skill.
- **Decisión (2026-10-14), paleta:** aprobada la variante B del paso 10, definitiva en `assets/palettes/mundo1.gpl` (muestras `mundo1_paleta.png`, maqueta `mundo1_maqueta.png`; script `tools/palette_mundo1_preview.py`). Hex finales: noche_profunda `#0b0e1a`, cielo `#1c2a58`, fondo_medio `#2e4688`, resplandor `#4f71c4`, tile_sombra `#0c1022`, tile_base `#1a2138`, tile_luz `#343f66`, borde_luz `#9bb0e8`, banner_blanco `#f2f4f8`, banner_gris `#aeb8d2`, alerta `#ff4a2a`, alerta_sombra `#a3221c`, carmin `#e0004a`, carmin_brillo `#ff5a8c`, ambar `#ffa000`, ambar_sombra `#a85f00`; y debug_cian aparte.
- **Decisión (2026-10-14), cian del Debug del Mundo 1:** el usuario notó que `#4fe3ff` "se pierde un poco" (ΔE 3,8 con el cian de la ropa de Isak `#29defa`). Se eligió **`#3dfff5`** (tono 177°, más claro y algo más verdoso) entre `#00f5ff`, `#3dfff5` y `#00ffe1` (`assets/palettes/mundo1_debug_cian_comparativa.png`): ΔE76 con el cian de Isak 3,8 → 24,6, con resplandor 60 → 84, con borde_luz 38 → 61 y con banner_blanco 40 → 49; contraste con resplandor tenido 3,06 → 3,61:1. `#00ffe1` separa más (ΔE 36) pero tira a aguamarina/verde. Refuerzo sin cambiar la lógica: halo oscuro de 2 px (noche_profunda) por fuera del contorno de las plataformas ocultas y relleno 0,18 → 0,25 (`data/debug_mode.json`, `hidden_halo_*`, `hidden_fill_alpha`); el tinte se queda al 25 % (A14). Se aplica en `data/hud.json` (`debug_colors` 1 y 6: tinte, contorno, batería y anillo de carga) y en el valor por defecto de `debug_overlay.gdshader`. El cian del efecto del pulso (`effects_pulse.gpl`, `isak.gpl` world_cyan) no se ha tocado.
- **Decisión (2026-10-14), punto débil:** con el Debug activo el punto débil (carmín) se dibuja **por encima del tinte** (en una capa entre el efecto del Debug y el HUD) y pulsa de carmin a carmin_brillo; solo es visible con el Debug. Componente reutilizable `scenes/bosses/weak_point.tscn` (valores en `data/weak_point.json`); aún sin jefes.
- **Decisión (2026-10-14), puntos de atención:** icono y objeto en ámbar `#ffa000` (antes `#ffd34a`, que se volvía verdoso con el tinte).
- **Tileset básico (paso 11, 2026-10-14):** `assets/sprites/tiles/mundo1_tileset.png` (40 tiles de 64x64, solo colores de `mundo1.gpl`): 16 bloques sólidos por máscara de vecinos (interior, superficie, bordes, esquinas, bloque aislado, pared fina y repisa fina), interior alternativo, 15 esquinas interiores, plataforma de una vía (izquierda, centro, derecha, suelta), pinchos de suelo y de techo, y dos decorados de fondo (rejilla y ventana). Script `tools/gen_tileset_mundo1.py`, validador `tools/validate_tileset.py`, TileSet `assets/tilesets/mundo1.tres` (`tools/build_tileset_mundo1.gd`) y mapa para el generador de niveles `data/tileset_mundo1.json`. **Siguen pendientes** de la propuesta: puente en sus dos estados, receptor, pared con glitch y fondo de pantalla de bloqueo con relojes en parallax.

### V11 [RESUELTO] Framework de pruebas
- **Sección:** skill `godot-isak-fix` ("GUT o gdUnit4, pregunta cuál") y `CLAUDE.md` (punto 4).
- **Problema:** no se puede dar el nivel por terminado sin pruebas, y el framework no está elegido.
- **Propuesta:** GUT (versión para Godot 4), ejecutado con `godot --headless -s addons/gut/gut_cmdln.gd`.
- **Por qué:** está escrito en GDScript puro, tiene CLI headless estable y requiere menos configuración para un proyecto pequeño.
- **Decisión (2026-10-14):** GUT.

### V12 [RESUELTO] Revisitar secretos de niveles anteriores
- **Sección:** §6.3 (pared con glitch del 1-1), §8.4/§8.5 (marco del 3-1) y §13.2 (se pueden rejugar las carpetas de los mundos completados).
- **Problema:** no se dice si se pueden elegir niveles sueltos ni cómo volver al 1-1 antes de completar el Mundo 1.
- **Propuesta:** la carpeta de cada mundo completado permite elegir cualquiera de sus niveles. El secreto del 1-1 se recupera al rejugarlo desde el hub.
- **Por qué:** es lo mínimo para que los secretos "retomables" tengan sentido.
- **Decisión (2026-10-15):** sí. Cuando exista el hub, desde él se elige la zona (1 a 6) y el subnivel. Antes del hub (Mundo 1 hasta vencer a Alerta Mayor) no hay selección. Ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado» y `05-hub.md` §13.6.

### V13 [Fuera del slice] Valores de los sistemas de mundos posteriores
- **Sección:** §8.2 (umbrales de likes), §10.2/§10.3/§13.3 (precios de tienda, atajos, Calc y drenaje de suscripción), §13.3 (cuánto guarda Papelera; **[Reemplazado 2026-10-15 (3)]**: la Papelera devuelve todo lo guardado tras un rollback, sin valor que fijar) y §12.3 (cuánto sube Calc la energía máxima).
- **Problema:** no hay ninguna cifra.
- **Propuesta:** definirlos en `data/economy.json` cuando se aborde cada mundo, a partir de la cantidad de puntos por nivel que se fije en V8 y en los siguientes.
- **Por qué:** dependen de la economía real que salga del Mundo 1.

### V14 [Fuera del slice] Jefes: vida, golpes y ventanas
- **Sección:** §6.6, §7.7, §8.7, §9.7, §10.7 y §11.7.
- **Problema:** no se dice cuántos golpes aguanta cada fase, qué hace daño al punto débil (¿el pulso?) ni cuánto duran las ventanas.
- **Propuesta:** 3 golpes al punto débil por fase, siempre con el pulso, salvo que la ficha diga otra cosa (por ejemplo, el Mundo 2 usa "mantener presionado").
- **Por qué:** es una regla uniforme que se puede ajustar jugando.

### V15 [APLAZADO] Responder o no en el 4-3
- **Sección:** §9.6 (Cierre: "Isak atraviesa la puerta sin responder, o no") y §14.4 (el epílogo depende de las conversaciones secretas).
- **Problema:** "o no" sugiere una elección del jugador que no tiene mecánica ni consecuencias definidas.
- **Propuesta:** preguntar al usuario. No implementar nada hasta que se decida.
- **Por qué:** es una decisión narrativa, no técnica.
- **Decisión (2026-10-14):** [APLAZADO] "se decide al llegar al Mundo 4; probablemente cambie con el desarrollo".

### V16 [Fuera del slice] Recuerdos coleccionables frente a fragmentos
- **Sección:** §6.4, §7.4, §8.5 y otras ("recuerdo coleccionable"), frente a los fragmentos de los jefes y a Notas (§13.3).
- **Problema:** no se dice para qué sirven los recuerdos de los secretos ni si cuentan para algo (por ejemplo, para el candado de La Nube, que pide "los cinco recuerdos").
- **Propuesta:** los recuerdos de los secretos son coleccionables que se ven en Notas y no desbloquean nada. (2026-10-15 (3): Notas llega en el primer hub y ya tiene un álbum de enemigos y objetos; los recuerdos se sumarían a él.) El candado de La Nube usa los cinco fragmentos de los jefes.
- **Por qué:** §5 y §13.2 hablan de "cinco", que coincide con los fragmentos, no con los recuerdos.

---

## 3. Ambigüedades técnicas

### A1 [BLOQUEA SLICE] Aceleración, fricción, control aéreo y salto variable
- **Sección:** §3.1 ("un poco más pesado") y skill `godot-isak-fix` ("aceleración y fricción suaves").
- **Problema:** no hay valores de aceleración ni de fricción, no se dice si hay control en el aire, y no se dice si el salto es variable (soltar el botón corta la subida).
- **Propuesta:** aceleración en suelo de 900 px/s² (alcanza correr en unos 0,2 s), fricción de 1100 px/s², control aéreo del 65% de la aceleración, y salto variable que multiplica la velocidad vertical ×0,5 al soltar. Todo en `data/isak_physics.json`.
- **Por qué:** da peso sin que Isak resbale, y el salto variable es necesario para un control al estilo de Celeste (§15.8).

### A2 [BLOQUEA SLICE] Valores del pulso
- **Sección:** §3.2 ("corta distancia", "aturde unos segundos") y §15.4 (de 4 a 6 cuadros).
- **Problema:** no hay alcance, área, enfriamiento, coste ni duración del aturdimiento. Además, de 4 a 6 cuadros a 12 fps son entre 0,33 y 0,5 s, demasiado para una "acción rápida" si el golpe sale al final.
- **Propuesta:** hitbox de 48x24 px delante de Isak, activa en el cuadro 2 durante 0,1 s, enfriamiento de 0,35 s, sin coste de energía y aturdimiento de 3 s. La animación sigue sonando, pero el movimiento solo se bloquea durante 0,15 s.
- **Por qué:** 1,5 tiles es "corta distancia". §3.3 dice que solo el Debug gasta energía. 3 s cubre de sobra "unos segundos" en el tutorial.

### A3 [BLOQUEA SLICE] Dirección del pulso
- **Sección:** §3.2, §6.3 (Tramo 4: "acertarle") y §8.3 (Espejo: "apuntando").
- **Problema:** no se dice si el pulso solo sale hacia delante o si se puede apuntar.
- **Propuesta:** en el slice, solo horizontal y en la dirección en que mira Isak. El apuntado en el Mundo 3 queda pendiente.
- **Por qué:** es suficiente para el 1-1 si el botón del pop-up se coloca bien (V5), y no anticipa una mecánica no definida.

### A4 [RESUELTO] Valores del Debug Mode
- **Sección:** §3.2, §3.3, §15.6 y skill `godot-isak-fix` (usar `Engine.time_scale` o un factor propio).
- **Problema:** no se define el factor de ralentización, si afecta también a Isak, el consumo, el mínimo para activarlo ni si funciona como interruptor o mientras se mantiene el botón. Con `Engine.time_scale` Isak también se ralentizaría.
- **Propuesta:** factor propio de 0,5 para enemigos, plataformas y proyectiles, con Isak a velocidad normal. Funciona como interruptor, con 100 de energía máxima, un consumo de 20/s (5 s con la barra llena) y un mínimo de 10 para activarlo. Se apaga solo al llegar a 0.
- **Por qué:** la referencia de Katana ZERO (§15.8) implica que el jugador va más rápido que el mundo, y la escasez obliga a "gastar energía con inteligencia" (§6.6).
- **Decisión (2026-10-14):** aprobadas las propuestas.

### A5 [BLOQUEA SLICE] Hitboxes
- **Sección:** §15.1 (canvas de 64x64, unos 48 px visibles, Isak de 1,5 tiles) y §6.2.
- **Problema:** no hay tamaños de colisión para Isak ni para la Burbuja de alerta.
- **Propuesta:** cuerpo de Isak de 18x44 px y hurtbox de 14x38 px (más pequeña, para perdonar). Burbuja de 28x28 px de colisión y 22x22 px de daño.
- **Por qué:** una hurtbox menor que el sprite evita golpes injustos, y el cuerpo de 44 px cabe en huecos de 2 tiles.

### A6 [BLOQUEA SLICE] Daño, i-frames y empuje
- **Sección:** §3.3, §3.4, §6.2 y §15.6 (daño de "duración corta").
- **Problema:** no se define cuánto Sync Rate quita un golpe, cuánto dura la invulnerabilidad ni si hay empuje.
- **Propuesta:** la Burbuja quita un 10% por contacto, con 1,0 s de i-frames (parpadeo + shader glitch de 0,2 s) y un empuje de 120 px/s en horizontal y −200 px/s en vertical.
- **Por qué:** 10 golpes para morir encaja con "prácticamente sin riesgo de muerte" del 1-1.

### A7 [BLOQUEA SLICE] Comportamiento de la Burbuja de alerta
- **Sección:** §6.2 ("Patrulla de lado a lado") y §6.3 (Tramo 3: "sola y lenta").
- **Problema:** no se define la velocidad, el rango de patrulla, si gira en bordes o en paredes, ni si vuela o va por el suelo.
- **Propuesta:** va por el suelo a 40 px/s y gira al chocar con una pared o al llegar al borde de la plataforma. El rango se fija en el JSON del nivel (por ejemplo, 4 tiles).
- **Por qué:** 40 px/s es claramente "lenta" frente a los 110 de Isak, y el rango en datos permite ajustarla por nivel.

### A8 [RESUELTO] ¿En qué unidad son los "6 a 12 cuadros" de anticipación? ¿Aplica al daño por contacto?
- **Sección:** §15.2 ("Telegrafiar los ataques"), `CLAUDE.md` y `pixel-art-pipeline`.
- **Problema:** 6 a 12 cuadros a 12 fps son entre 0,5 y 1,0 s; a 60 fps son entre 0,1 y 0,2 s. Tampoco se dice si el daño por contacto (como el de la Burbuja) cuenta como "ataque".
- **Propuesta:** contarlos como cuadros de animación a 12 fps (entre 0,5 y 1,0 s). El contacto pasivo no necesita anticipación, pero el fin del aturdimiento sí: la Burbuja parpadea durante 0,75 s antes de volver a hacer daño.
- **Por qué:** la regla está en la sección de arte, donde todo se mide a 12 fps, y avisar del fin del aturdimiento evita el daño injusto de C7.
- **Decisión (2026-10-14):** aprobada la propuesta.

### A9 [BLOQUEA SLICE] Idle: tiempo hasta la terminal holográfica
- **Sección:** §3.1, §13.5, §15.4 ("tras unos segundos") y §11.7 (fase 3).
- **Problema:** no hay valor.
- **Propuesta:** 4 s sin input ni movimiento, configurable en `isak_physics.json`.
- **Por qué:** es lo bastante corto para que se descubra en el tutorial y no salta mientras se piensa un salto.

### A10 [RESUELTO] Puntos de atención: valor y recarga de energía
- **Sección:** §3.3 y §15.7 ("se recarga con puntos de atención").
- **Problema:** no se dice cuánta energía repone cada punto ni si se recarga sola con el tiempo.
- **Propuesta:** cada punto suma 1 al contador y repone 10 de energía (sobre 100). No hay regeneración pasiva (desde el 2026-10-17, salvo con las mejoras Sync Rate 5 y Energía 5 de Calc: ver «Notas del paso 9»). Al empezar, la energía está llena.
- **Por qué:** el diseño solo menciona los puntos como fuente de energía, y 10 por punto hace que la recolección importe.
- **Decisión (2026-10-14):** aprobadas las propuestas. Los puntos de atención se guardan entre partidas (hoy vuelven a 0; el guardado en disco sigue pendiente, fuera del vertical slice).

### A11 [RESUELTO] Representación del HUD
- **Sección:** §15.7.
- **Problema:** no se define cuántas barras de señal hay, cómo se segmenta la batería, ni la posición, la escala o la fuente concreta.
- **Propuesta:** barra de estado en la parte superior, de 16 px de alto, a resolución base. Señal con 4 barras (25% cada una) más el porcentaje, y parpadeo por debajo del 20%. Batería de 5 segmentos. Contador con icono de 8x8 px. Fuente pixel art libre con tildes y ñ (para aprobar).
- **Por qué:** imita una barra de estado real y cabe en 640x360 sin tapar el juego.

### A12 [BLOQUEA SLICE] Longitud y estructura del 1-1
- **Sección:** §6.3 (unos 3 minutos y 4 tramos) y skill `level-builder` ("Criterios por nivel").
- **Problema:** no se define la longitud en tiles ni dónde va exactamente el punto de sincronización.
- **Propuesta:** unos 150 tiles de ancho por 11–22 de alto, con tramos de unos 35 tiles. El punto de sincronización va entre el Tramo 2 y el 3, justo antes de la primera Burbuja.
- **Por qué:** a 110–180 px/s, 150 tiles se recorren en unos 30–45 s sin pausas. El resto de los 3 minutos son aprendizaje y Eco. El checkpoint antes del primer enemigo es "a mitad de nivel".

### A13 [BLOQUEA SLICE] Comportamiento de la cámara
- **Sección:** §15.1 (unos 20x11 tiles).
- **Problema:** no se define seguimiento, zona muerta, anticipación ni límites.
- **Propuesta:** `Camera2D` con zona muerta horizontal de 48 px, anticipación de 32 px en la dirección del movimiento, suavizado vertical solo al aterrizar, límites del nivel y posición ajustada a píxel.
- **Por qué:** es la configuración estándar para leer peligros por delante sin mareo con pixel art.

### A14 [BLOQUEA SLICE (aspecto del Debug)] Efecto visual del Debug
- **Sección:** §3.2, §15.6 y `CLAUDE.md` (Mundo 1 = cian).
- **Problema:** no se definen la intensidad del tinte, el tamaño de la viñeta ni cómo se ven las plataformas ocultas (`h`) cuando el Debug está apagado.
- **Propuesta:** tinte cian al 25%, viñeta de alrededor del 15% del borde y contorno de 1 px en las plataformas `h`, que con el Debug apagado son invisibles y no tienen colisión.
- **Por qué:** se lee bien, cumple el "contorno claro para daltonismo" de §15.6 y no tapa el rojo de las alertas.

### A15 [Fuera del slice] Variables de otros mundos
- **Sección:** §6.2 (Recordatorio, Banner), §7.2 (velocidad del scroll y daño por quedarse atrás), §9.2 ("Visto": "unos segundos"), §10.2 (fuerza de la tentación), §3.5 (dash: distancia e invulnerabilidad).
- **Problema:** ninguno tiene valores.
- **Propuesta:** fijarlos en el JSON de cada nivel cuando se aborde cada mundo, partiendo de los valores aprobados en el slice.
- **Por qué:** dependen del ritmo de movimiento que se apruebe en el slice.

### A16 [Fuera del slice] Color del Debug en el Mundo 6
- **Sección:** §11.1 y §11.4 (secreto "con el Debug en el color del mundo 1").
- **Problema:** no se dice si el color del Debug tiene efecto de juego (por ejemplo, si un secreto solo aparece con cierto color) o solo es estético.
- **Propuesta:** solo estético. El color lo fija cada zona del nivel.
- **Por qué:** es la lectura más simple y no añade ninguna mecánica.

---

## Notas del paso 8 (HUD funcional, 2026-10-14)

Propuestas adoptadas **de forma provisional** en el HUD (arte con primitivas; la interfaz definitiva se hace en el paso 12). Todos los valores están en `data/hud.json`:

- **A11 (sigue abierta):** barra de estado arriba, de 32 px de alto a 1280x720 (los 16 px de A11 a 640x360, ×2), alineada a la derecha. Señal = Sync Rate con 4 barras (25 % cada una, se llenan de forma parcial) más el porcentaje; batería = energía de Debug con 5 segmentos; contador de puntos de atención con un icono de 16 px (8 px de A11, ×2) junto a la batería. **Fuente pendiente:** se usa la fuente por defecto de Godot hasta aprobar una fuente pixel art con tildes y ñ.
- **Sync Rate bajo:** estado activo con Sync Rate **menor** que 20 (`low_sync_threshold`; justo 20 no cuenta). La señal y el porcentaje se ponen en rojo y parpadean (3 Hz). Con la opción de accesibilidad `GameState.reduce_low_sync_effects` se quedan en rojo sin parpadear. **Pendiente:** el ruido y la distorsión de pantalla (shader nuevo, sin propuesta concreta) y la música deformada; el gancho es `EventBus.low_sync_changed`. La opción aún no se guarda en disco (no hay menú de opciones).
- **Colores del Debug por mundo:** hex provisionales (los hex exactos son decisión abierta). Mundo 1 = `#4fe3ff` (el `world_cyan` de `isak.gpl`). Mundo 6 (A16, abierta) repite el cian hasta que cada zona fije el suyo. Rojo de daño/alerta `#ff4a2a` (rojo anaranjado del Mundo 1).
- **Animaciones:** al perder valor, la barra cae al instante y un rastro rojo se vacía tras 0,35 s (en 0,4 s); al ganar, pulso de escala ×1,25 durante 0,18 s.
- **C8 (sigue abierta):** hueco oculto `ClockSlot` a la izquierda de la barra de estado, reservado para la hora del Mundo 2.
- **A10 (resuelta):** `GameState.add_attention_points()` suma al contador y repone 10 de energía por punto.

## Notas del paso 9 (Debug Mode, 2026-10-14)

Decisiones aprobadas por el usuario en este paso y **propuestas** adoptadas de forma provisional. Los valores están en `data/debug_mode.json`.

- **Activación (aprobada; sustituye a "interruptor" y "mínimo de 10" de A4):** se activa **manteniendo** la acción `debug` (K / Y del mando) y solo entra con `GameState.abilities_unlocked["debug"]` y energía > 0. Se apaga al soltar, al llegar a 0 (salida suave), si Isak muere o si se bloquea la habilidad. **Propuesta:** tras agotarse la energía hay que soltar y volver a pulsar (si no, recoger un punto con la tecla mantenida lo encendería y apagaría solo).
- **Consumo y tiempo (A4, aprobada):** 20/s en tiempo real (no ralentizado); el mundo va a ×0,5 con un factor propio, `GameState.world_time_scale` (no `Engine.time_scale`). Isak y el HUD usan el delta real: la física de Isak no cambia. Los objetos del mundo usan `WorldTime.scaled_delta(delta)` (instrucciones en `scripts/autoload/world_time.gd`). Sin LED en la mochila: la energía se ve en la batería del HUD. Se pueden recoger puntos de atención durante el Debug.
- **Transición (propuesta):** entrada en 0,15 s y salida en 0,25 s (tinte, viñeta y escala de tiempo).
- **Efecto visual (A14, propuesta):** tinte del color del Debug del mundo (`data/hud.json`) al 25 %, viñeta en el 15 % del borde con 3 escalones (pixel art) y opacidad 0,4, en una capa entre el mundo y el HUD (el HUD no se tiñe). En las capturas, la viñeta al 0,55 apagaba demasiado los bordes; se bajó a 0,4. **A revisar jugando:** el tinte cian vuelve verdosos los puntos de atención amarillos.
- **Plataformas ocultas (`h`, propuesta):** solo visibles **y sólidas** mientras el Debug está activo, con contorno de 2 px del color del Debug (1 px de A14 a 640x360, ×2) y relleno al 18 %; si Isak está encima al apagarse, cae. **Alternativa:** siempre sólidas y solo visibles con el Debug; se cambia con `hidden_platforms_solid_only_in_debug: false`.
- **Accesibilidad (propuesta):** `GameState.debug_high_contrast_outline` hace el contorno más claro (60 % hacia blanco) y más grueso (4 px). Aún no se guarda en disco (no hay menú de opciones).
- **Recargas (pendiente):** la recarga de energía y de Sync Rate fuera de los puntos de atención se decidirá más adelante. Hay un gancho comentado en `GameState.add_attention_points()`; no hay regeneración pasiva ni curación. **[Actualizado el 2026-10-17, tanda M2 de `propuesta-mejoras.md`]:** sigue sin haber regeneración pasiva **salvo con dos mejoras de Calc**: Sync Rate 5 (Resincronización: 1 de Sync por segundo hasta el 60 % del máximo, solo fuera de combate) y Energía 5 (recarga pasiva del 0,5 % del máximo por segundo, 3 s después del último gasto; no con el Debug ni el Ocultarte). Las recargas se decidieron después (drops, cargadores, hub). Condiciones en `data/passive_regen.json`.
- **Desbloqueo (C2):** el Debug sigue bloqueado por defecto y en la arena; solo `scenes/levels/debug_sandbox.tscn` lo desbloquea (y lo restaura al salir). Las teclas de depuración del HUD se renombraron a `hud_debug_*` para no confundirlas con la acción `debug`.

## Debug: pulsación larga para activar, pulsar para desactivar (cambio 2026-10-14 pedido por el usuario)

Sustituye por completo el "mantener para usar" de la activación del paso 9 (el resto del paso 9 no cambia: ×0,5, tinte, viñeta, 20/s en tiempo real, bloqueo por nivel, plataformas ocultas).

- **Activar:** mantener la acción `debug` (K / Y del mando) durante `activation_hold_s` = **1,0 s (propuesta**; el usuario pidió "unos segundos", se ajusta jugando en `data/debug_mode.json`). Solo carga con la habilidad desbloqueada y energía > 0; si no, mantener no hace nada ni muestra carga. Soltar antes cancela sin coste ni efecto. La carga no gasta energía; el gasto empieza al activarse.
- **Activo:** se queda activo sin mantener nada. Ni seguir manteniendo ni soltar la pulsación que lo activó lo apaga.
- **Desactivar:** una pulsación nueva de `debug` (salida suave), o al llegar la energía a 0, si Isak muere o si se bloquea la habilidad. Para volver a entrar hay que repetir la pulsación larga (recargar energía no lo reactiva).
- **Indicador de carga (propuesta, arte provisional):** anillo pequeño a la izquierda de la batería del HUD, en el color del Debug del mundo, que se llena mientras se mantiene y desaparece al cancelar o activar. Lo alimenta `EventBus.debug_activation_progress_changed(progress)` (0-1); apariencia en `data/hud.json` (`charge_ring_*`).

## Notas del paso 10 (paleta del Mundo 1, 2026-10-14)

**V10 (paleta resuelta el 2026-10-14, ver V10 arriba): esta era la propuesta.** Los archivos `mundo1_propuesta*` se borraron; la variante B quedó en `assets/palettes/mundo1.gpl`. Generada con `tools/palette_mundo1_preview.py` (incluye la medición de contrastes y el tinte del Debug reproducido de `debug_overlay.gdshader`).

- **Variante B (recomendada), "noche con resplandor de pantalla":** `assets/palettes/mundo1_propuesta.gpl`, `mundo1_propuesta_paleta.png`, `mundo1_propuesta_maqueta.png`. Hex: noche_profunda `#0b0e1a`, cielo `#1c2a58`, fondo_medio `#2e4688`, resplandor `#4f71c4`, tile_sombra `#0c1022`, tile_base `#1a2138`, tile_luz `#343f66`, borde_luz `#9bb0e8`, banner_blanco `#f2f4f8`, banner_gris `#aeb8d2`, alerta `#ff4a2a`, alerta_sombra `#a3221c`, carmin `#e0004a`, carmin_brillo `#ff5a8c`, ambar `#ffa000`, ambar_sombra `#a85f00`; más debug_cian `#4fe3ff` aparte.
- **Variante A, "noche profunda":** `assets/palettes/mundo1_propuesta_a.gpl` (+ `_paleta.png`, `_maqueta.png`). Cambian cielo `#161f40`, fondo_medio `#23336a`, resplandor `#3a55a0`, tile_sombra `#0f1428`, tile_base `#1f2742`, tile_luz `#3a4670`, borde_luz `#8fa3d9`; el resto igual.
- **Contrastes clave (B):** Isak (luminancia mediana 0,02, muy oscuro) contra resplandor 3,2:1 y contra fondo_medio 1,7:1 (en A: 2,1:1 y 1,25:1); tile_base contra resplandor 3,4:1; alerta contra tile_base 4,75:1; texto contra fondo del HUD 17,5:1. Alerta y carmín: ΔE 34 (tono 9° vs 340°).
- **Amarillo de los puntos de atención:** el `#ffd34a` del HUD se vuelve verdoso con el tinte (tono 45° → 64°); se propone ámbar `#ffa000` (38° → 45°, sigue dorado).
- **Dudas para el usuario:** (1) el cian del Debug `#4fe3ff` es casi igual al cian de la ropa de Isak (`#29defa`, ΔE 3,8); la paleta del mundo no tiene otros cian, pero ¿se mantiene o se cambia el del Debug? (2) Con el tinte al 25 % el carmín del punto débil queda apagado (`#b01650`); quizá dibujarlo por encima del tinte o con pulso a carmin_brillo. (3) Si se aprueba, cambiar en `data/hud.json` el `attention_icon` a `#ffa000` (paso 12).

## Notas de los objetos del Mundo 1 (puente, receptor, pared con glitch y fondo; 2026-10-14)

Lo que dice el diseño (§3.2, §6.1, §6.3, §15.2): el pulso "si golpea un objeto del entorno (un puente desactivado) lo activa"; Tramo 2 del 1-1: "Puente desactivado. El pulso lo activa y enseña que el pulso afecta al entorno"; secreto: "una pared con un leve glitch, sin forma de acceder todavía. Se retoma cuando Isak tenga el Debug"; el brillo se reserva para lo interactivo; fondo azul noche (la pantalla de bloqueo con relojes de V10 es propuesta). No dice dónde se golpea, cuánto dura, ni si el puente es de una vía. **Todo lo siguiente es PROPUESTA** (valores en `data/world1_objects.json` y `data/world1_background.json`):

- **Puente y receptor (V4 sigue abierta; se usa su propuesta):** receptor visible (antena con pantalla e icono de señal; el punto parpadea mientras está apagado) en el extremo del puente. Lo activa el área real del pulso (círculo de `pulse_radius_px` en el celular, A2/A3 siguen abiertas) y se queda activado; el puente se extiende de forma permanente, un tile cada 0,08 s de izquierda a derecha (tiempo del mundo: más lento con el Debug). Retraído se ve solo un contorno discontinuo y no tiene colisión; extendido es una tabla **sólida** (no de una vía; el diseño no lo pide) de 12 px arriba de la celda. Enlace por id: `bridge_inactive.params.id` = `receiver.params.target`. **Duda:** ¿el puente debe ser de una vía, o volver a desactivarse tras un tiempo en niveles posteriores? (cambiar `one_way` / `stays_active`).
- **Pared con glitch:** bloque sólido con el aspecto del tileset y ráfagas cortas (cada 0,6-1,8 s) de líneas de píxeles desplazadas. Sin interacción; gancho para el Debug: grupo `debug_secret` y señal `debug_revealed(active)`. El contenido del secreto queda pendiente (V12). **Duda:** ¿el glitch debe verse siempre o solo de cerca / con el Debug?
- **Fondo de pantalla de bloqueo (V10):** tres capas con parallax (cielo con relojes, fondo medio con relojes y avisos, resplandor con edificios), 1280x720, repetibles sin costura, por debajo de la capa del Debug (que las tiñe).
- **Color del pulso:** el efecto usa ahora el cian del Debug `#3dfff5` (`effects_pulse.gpl`: core `#c2fffc`, mid `#3dfff5`, dim `#12857f`; `isak.gpl` world_cyan igual). El arte de Isak no cambia.

## A11 [RESUELTO] HUD definitivo del Mundo 1 (paso 12, 2026-10-14)

Sustituye el arte provisional con primitivas del paso 8. Todo el aspecto está en `data/hud.json` y en `assets/sprites/ui/`; los assets se rehacen con `tools/gen_hud_assets.py` y `tools/gen_hud_font.py` y se validan con `tools/validate_ui_assets.py` (paleta `mundo1.gpl` + debug_cian, alfa 0/255, tamaños múltiplos de 8, nombres `hud_*.png`, glifos de la fuente).

- **Pixel base:** el HUD se dibuja en píxeles de arte y se escala ×2 (`hud_pixel_scale`, entero) a 1280x720, como los tiles. Barra de estado de 16 px de arte (32 en pantalla) a todo lo ancho: `noche_profunda` con línea `borde_luz` abajo (opaca; antes era semitransparente). Iconos en cuadros de 16x16 (señal, punto de atención, anillo de carga) y batería de 32x16; márgenes 8 y separación 5 (px de arte).
- **Señal (Sync Rate):** 4 barras de 3 px (alturas 4, 7, 10, 13), encendidas por **tramos** (`signal_thresholds` = 0, 25, 50, 75): la barra *i* se enciende si el Sync Rate es **mayor** que el tramo *i* → 76–100 % = 4 barras, 51–75 = 3, 26–50 = 2, 1–25 = 1, 0 = ninguna. Con Sync Rate bajo (< 20 %) las barras encendidas y el porcentaje pasan a `alerta`/`alerta_sombra` y parpadean (sin parpadeo con `reduce_low_sync_effects`). Rastro de daño: las barras perdidas quedan en `alerta_sombra` y se apagan tras 0,35 s.
- **Batería (energía de Debug):** marco `banner_blanco`/`banner_gris` con polo y 5 segmentos de 4x8 (`battery_thresholds` = 0, 20, 40, 60, 80, mismo criterio): llenos en el color del Debug del mundo (dibujados en `#3dfff5`; el shader `assets/shaders/hud_key_swap.gdshader` cambia ese color clave por `debug_colors` de cada mundo), vacíos en `tile_luz`, rastro de consumo/daño en `alerta_sombra`.
- **Puntos de atención:** rombo de 13 px en ámbar `#ffa000` con borde inferior y punto central en `ambar_sombra` (misma forma que el objeto del nivel).
- **Anillo de carga del Debug:** anillo de 12 px de diámetro y 2 de grosor en 16 pasos discretos (`charge_ring_steps`), pista `tile_luz`, relleno en el color del Debug.
- **Fuente:** bitmap propia (`assets/sprites/ui/hud_font.png` + `hud_font.fnt`, BMFont que Godot importa como FontFile), glifos de 5x7 (dígitos monoespaciados, avance 6) en `banner_blanco`: `0-9`, `%`, `x`, `:` y espacio (`font_glyphs`). Tamaño 8 (sin escalado fraccionario). El color rojo del porcentaje con Sync Rate bajo sale del mismo shader de color clave.
- **Hueco del reloj (C8):** `ClockSlot` sigue oculto a la izquierda y ya usa la fuente (`:` incluido).
- **Propuesta (no implementada), letras para textos de interfaz en español:** mismo alto (7 px de mayúscula, 5x7) con A–Z y a–z (minúsculas con descendentes: alto de línea 10), tildes `á é í ó ú Á É Í Ó Ú`, `ñ Ñ`, `ü`, `¿ ? ¡ !`, `. , ; - / ( ) "` y `+`. Unos 75 glifos, en un atlas de 16 columnas. **Duda:** ¿hace falta ya (menús, diálogos) o se espera al hub?
- **Dudas:** (1) la barra es opaca y tapa 32 px del juego; ¿se prefiere solo un panel tras el grupo de la derecha? (2) ¿el rastro de consumo de la batería en rojo oscuro molesta durante el Debug (se ve a cada segmento gastado)?

## Notas del paso 13 (Burbuja de alerta, 2026-10-14)

Lo que dice el diseño (§6.2): "Patrulla de lado a lado. Hace daño al contacto. Pulso para aturdir y pasar, o saltar sobre ella aturdida." No persigue ni embiste, así que no tiene ataque activo: la anticipación de 6-12 cuadros se aplica al fin del aturdimiento (A8). Reglas C7 aplicadas tal cual. Valores en `data/enemies/alert_bubble.json`; los que vienen de puntos abiertos son **propuestas** (se ajustan jugando):

- **A7 (propuesta):** por el suelo a 80 px/s (40 × 2), gira en paredes, bordes y al límite del rango; rango por defecto 256 px (4 tiles en total centrados en el punto de aparición), configurable por nivel (`patrol_range_px`).
- **A6 (propuesta):** 10 % de Sync Rate por contacto; la invulnerabilidad de 1 s y el retroceso son los de Isak (`data/isak_abilities.json`).
- **A2 (propuesta):** aturdimiento de 3 s, que incluye el aviso final de 9 cuadros a 12 fps (0,75 s, A8): la Burbuja alterna su aspecto aturdido y el de alerta, se hincha y tiembla; sigue inofensiva y pisable hasta que termina.
- **A5 (propuesta, adaptada al sprite):** lienzo de 96x96 con burbuja visible de 78 px; cuerpo 64x76, zona de daño 56x56 (más pequeña que el dibujo), plataforma de una vía de 64 px a 74 px sobre los pies (el canto plano y claro del sprite aturdido).
- **C7, umbral (propuesta):** caer sobre ella aturdida a ≥ 300 px/s la revienta (≈ 14 px de caída libre) y Isak rebota a −720 px/s (≈ 108 px); por debajo del umbral la pisa. *Ajustado después a 1150 px/s (ver «C7: umbral de pop ajustado» más abajo).*
- **Capas de física (nuevas):** 1 world, 2 player, 3 enemy, 4 pulse. Isak pasó de la capa 1 a la 2 (su máscara no cambia: su física es la misma), su PulseArea a la 4 y los puntos de atención detectan la capa 2. La Burbuja (capa 3) no choca con Isak; su plataforma está en la capa 1.
- **Dudas:** ¿el pulso sobre una Burbuja ya aturdida debe reiniciar el aturdimiento (ahora sí)? ¿Una Burbuja reventada reaparece en el nivel (ahora no; solo en la escena de prueba)?

## C7: umbral de pop ajustado (Burbuja de alerta, 2026-10-14)

Con 300 px/s la Burbuja aturdida casi nunca servía de plataforma: solo la pisaba quien bajaba menos de unos 14 px. El umbral `pop_speed_threshold_px_s` de `data/enemies/alert_bubble.json` pasa de **300 a 1150 px/s** (≈ 212 px de caída libre sobre el canto, unos 3,3 tiles). La física de Isak no cambia (salto de 192 px, gravedad de caída 2400 × 1,3 = 3120 px/s²). Velocidades medidas con simulación headless (`tests/test_alert_bubble_threshold.gd`, pasos de 1/60 s, Burbuja aturdida en el suelo con el canto a 74 px): es la velocidad vertical con la que la Burbuja ve llegar a Isak (la de su último paso en el aire).

| Caso | Caída sobre el canto | Velocidad de aterrizaje | Resultado con 1150 |
|---|---|---|---|
| a) salto completo desde el suelo | 118 px | 780 px/s | pisa (32 % por debajo) |
| b) salto desde un escalón de 1 tile | 182 px | 988 px/s | pisa (14 % por debajo) |
| c) salto corriendo | 118 px | 780 px/s | pisa |
| d) caída desde repisa de 2 tiles | 54 px | 520 px/s | pisa |
| e) caída desde repisa de 3 tiles | 118 px | 780 px/s | pisa |
| f) caída desde repisa de 4 tiles | 182 px | 988 px/s | pisa (14 % por debajo) |
| caída desde repisa de 5 tiles | 246 px | 1196 px/s | revienta, pero solo un 4 % por encima (zona límite) |
| g) caída desde repisa de 6 tiles | 310 px | 1352 px/s | revienta (18 % por encima) |
| h) caída desde repisa de 7 tiles | 374 px | 1456 px/s | revienta |

Las alturas de repisa se miden desde el suelo donde está la Burbuja. Como el salto no tiene altura variable ni velocidad máxima de caída, la velocidad solo depende de cuánto cae Isak sobre el canto: un salto desde un escalón de 1 tile cae lo mismo que una repisa de 4 tiles, y una repisa de 3 tiles lo mismo que un salto desde el suelo. Por eso no se puede pedir que la repisa de 3 o 4 tiles la reviente sin que también la reviente un salto normal. Regla resultante: todo salto desde el suelo o desde un escalón la pisa; para reventarla hay que caer desde unos 5 tiles o más sobre el canto (repisa de 6 tiles). La repisa de 5 tiles queda en el límite y conviene no usarla en niveles. **Se afina jugando**; si se prefiere que reviente más a menudo, la otra opción es reventarla con una acción explícita (p. ej., pulsar abajo en el aire) en lugar de por velocidad.

## Decisiones del usuario sobre la Burbuja de alerta (2026-10-14)

- **Burbuja:** un pulso sobre una Burbuja ya aturdida reinicia el aturdimiento (aprobado).
- **Respawn de enemigos:** se decidirá más adelante; por ahora una Burbuja reventada no reaparece, salvo en la escena de prueba (aprobado provisional).

## Notas del paso 14b: fuente de textos y voz de Eco (2026-10-14)

Implementa la propuesta V6 (sigue abierta hasta que se apruebe jugando) y la parte de letras de A11. Valores en `data/text_font.json` y `data/eco_text_box.json`.

- **Fuente de textos (propuesta adoptada):** archivo aparte de la del HUD (`assets/sprites/ui/text_font.png` + `text_font.fnt`, generada por `tools/gen_text_font.py`; la fuente del HUD no cambia). 96 glifos propios en `banner_blanco`: A–Z, a–z, `á é í ó ú Á É Í Ó Ú ü Ü ñ Ñ`, dígitos (los mismos del HUD), `. , ; : ¿ ? ¡ ! - – — " ' ( ) / % + …` y espacio. Celda de 12 filas de arte: 3 de acentos de mayúscula, 7 de mayúscula, 2 de descendentes (base en la fila 10); altura x de 5; interlineado 13. Ancho proporcional (la mayoría 5 px; `i`, `l`, `!` 1–2 px). Tamaño 12, escalada ×2 entera en pantalla.
- **Cuadro de Eco (propuesta V6):** notificación arriba y centrada, debajo de la barra de estado (capa 11, por encima del HUD sin taparlo), con la esfera de Eco de 16×16 (blanca y azul con sonrisa de píxeles, §12.1), el nombre «Eco» y el texto. Panel `noche_profunda` con línea `borde_luz`, como la barra del HUD; ancho entre 320 y 560 px según el texto.
- **Color de Eco (propuesta):** el nombre va en `borde_luz` (#9bb0e8, azul claro). Los docs no fijan un color para Eco; se eligió por «esfera de luz blanca y azul» (§12.1).
- **Velocidad del texto (propuesta):** máquina de escribir a 40 caracteres por segundo, con una entrada en 0,12 s y una salida en 0,2 s.
- **Tiempos (propuesta):** el texto completo queda en pantalla al menos `duration_s` del disparador (4 s en el 1-1, V6) y más en textos largos: `max(duration_s, 1,5 + 0,06 × caracteres)`. Las líneas normales se cierran solas, no pausan el juego ni bloquean a Isak, y usan tiempo real (el Debug no las ralentiza). Si llega otra línea, se pone en cola.
- **Líneas importantes (decisión del usuario, 2026-10-15):** campo `important` (por defecto `false`) en el `eco_line` del nivel y en `EventBus.eco_line_requested`. Una línea importante pausa el árbol (`get_tree().paused`; el cuadro procesa siempre), no se cierra sola y espera a que el jugador pulse saltar o `ui_accept` (Espacio / A del mando / Intro): la primera pulsación durante la escritura completa el texto y la siguiente lo cierra. El juego se reanuda al terminar de desvanecerse (o sigue en pausa si la siguiente en cola también es importante) y siempre que el cuadro sale del árbol (cambio de escena, nivel quitado); si la pausa la puso otro, no la quita. Pasa delante de las normales en cola, y si hay una normal en pantalla la desplaza: esa vuelve a la cola, delante de las demás normales, así que no se pierde ninguna. En pausa no avanzan el mundo, las Burbujas, el Debug, los temporizadores de los nodos ni el retraso de los avisos de control. Marcadas como importantes: los avisos de control de habilidades (`AbilityNotices`), el texto de `ability_pickup` y, en el 1-1, `eco_bienvenida` (primera voz de Eco) y `eco_laser` («Herramienta nueva…»). **[Reemplazado 2026-10-15 (3)]**: `eco_bienvenida` pasa a ser la presentación de Eco en el encuentro; las demás líneas del 1-1 pasan a ayuda con Q o se eliminan (tabla en `propuesta-asistentes-y-vidas.md` §4). El bot de recorrido las confirma solo.
- **Dudas:** (1) Resuelta (2026-10-15): las líneas importantes se cierran con una acción; las normales, no. (2) ¿La esfera de Eco debe animarse (parpadeo, sonrisa) al hablar?

## Notas del paso 14b: techo del Tramo 3, pop-up, puerta y pantalla provisional del hub (2026-10-14)

Decisiones del usuario aplicadas: techo bajo en el Tramo 3 para obligar a usar el pulso, pared con glitch al final (pasada la puerta) y vuelta al hub al terminar (C4) con una pantalla provisional. Lo siguiente son **propuestas adoptadas** (se ajustan jugando):

- **Techo del Tramo 3:** columnas 80-89 con el techo a 2 tiles del suelo (128 px; filas 5-7), sobre toda la patrulla de la Burbuja (320 px) con más de 1 tile de margen a cada lado, y escalones de 3 tiles de hueco en las columnas 78-79 y 90-91 para que baje por pasos. Bajo el techo Isak solo eleva los pies 48 px (la Burbuja mide 76): no puede saltarla sin aturdirla; aturdida es de una vía y se cruza andando. La cara de arriba del techo queda a 320 px del suelo, fuera del salto. Comprobado con simulación (`tests/test_tramo3_ceiling.gd`: 41 intentos corriendo, 40 saltando en distintos puntos y uno sin saltar, ninguno pasa sin daño; aturdida se cruza sin daño).
- **Botón del pop-up:** 16x16 px (8 px de V5 ×2), rojo `alerta`, en el borde izquierdo del pop-up (`close_button_px` [4, 192]): su centro queda a 56 px del suelo, la altura del celular de Isak de pie. Solo lo cierra un pulso que toque el botón (no la ventana); con el radio de 96 px hay que ponerse a menos de ~1,75 tiles de la cara del pop-up, y un pulso desde el apogeo del salto no llega. Cierre por pasos (líneas desplazadas, aplastado, raya, restos, 12 fps de tiempo del mundo); después deja de ser sólido y no se reabre. El texto es el de §6.1 en `noche_profunda` sobre la ventana blanca. La ventana lleva un botón grande gris falso (no hace nada), por «los botones de cerrar son diminutos o falsos».
- **Puerta «Marcar como leído»:** Isak entra con solo tocarla (no se añade ninguna acción). Se bloquea su entrada, la puerta se abre por pasos mientras Isak se desvanece y al terminar se emite `EventBus.level_completed(level_id)` una sola vez. Etiqueta encima de la puerta con la fuente de textos en `banner_blanco` sobre placa `noche_profunda` con borde `borde_luz`; el borde de la puerta parpadea (brillo de lo interactivo) y la hoja lleva una doble marca de «leído».
- **Pantalla provisional de regreso al hub:** fondo `noche_profunda` y el panel del cuadro de Eco, con «Regreso al hub (provisional)», «Nivel completado: Bandeja de entrada», «Puntos de atención: N» y «Pulsa salto para volver a jugar» (acción `jump`, aceptada tras 0,5 s). No muestra contenido del hub ni de Eco. La conexión con el flujo de nivel queda para el paso 16.
- **Dudas:** (1) ¿el botón debería pedir más puntería (p. ej. más alto, solo alcanzable saltando) o está bien a la altura del celular? (2) ¿el botón grande falso del pop-up despista demasiado? (3) ¿se prefiere que la puerta pida una acción para entrar en lugar de tocarla?

## Notas del paso 15: generador del nivel y validador de alcanzabilidad (2026-10-14)

Propuestas adoptadas (se ajustan jugando):

- **Generador** (`python3 tools/build_level.py data/levels/1-1.json` → `scenes/levels/1-1.tscn`): escribe el `.tscn` como texto desde el JSON, sin abrir Godot, así que es reproducible byte a byte (las pruebas comparan el hash). La escena no se edita a mano. Al entrar, el nivel aplica `abilities_available` (1-1: pulso sí, Debug no) y lo restaura al salir. El checkpoint es un `Marker2D` mínimo; activarlo y reaparecer quedan para el paso 16.
- **Pinchos:** cada tramo de `^` lleva un Area de daño que quita 10 de Sync Rate (10 %) con el golpe normal de Isak (1 s de invulnerabilidad), en `data/hazards.json`. El 1-1 no tiene pinchos.
- **Validador** (`python3 tools/validate_level.py data/levels/1-1.json`): modelo por celdas con trayectorias simuladas a 60 Hz con la física de `data/isak_physics.json`. La altura real del salto es 192 × 0,92 = 177 px (`--jump-efficiency`, se toma el valor bajo de lo medido). No usa el coyote time. Con velocidad de caminar, el alcance horizontal es de 158 px y el límite está en el 85 %. Los saltos corriendo solo cuentan si el nivel declara `"allow_run": true`.
- **Resultado en el 1-1:** pasa sin errores ni avisos. La exigencia máxima del camino es del 72,5 % en vertical (subidas de 2 tiles, 128 px), con un margen mínimo de 12,5 puntos. El salto del foso del Tramo 1 (128 px) exige el 80,8 % en horizontal, pero no es obligatorio: el foso tiene fondo y se sale saltando. El puente, la Burbuja (bajo el techo Isak solo eleva los pies 48 px) y el pop-up son obligatorios, cada uno con su pulso: desde la columna 45 al receptor, desde la 79 a la Burbuja y desde la 109 al botón. No hay soft-locks (del foso del puente se sale por la izquierda gracias al escalón). No hizo falta tocar el JSON del nivel.
- **Duda:** el pulso alcanza el botón del pop-up con el centro de Isak hasta a 2 tiles de la cara del pop-up (el celular queda justo a 96 px del botón, en el borde del radio). ¿Está bien así o se prefiere que haya que acercarse más?

## Notas del paso 16: flujo del 1-1 (checkpoint, muerte, final y reinicio; 2026-10-14)

Decisiones aplicadas: V2 (reaparecer en el último punto de sincronización o en `P` con 100 % de Sync Rate; tocar el punto repone el Sync Rate), V3 (los fosos del 1-1 tienen fondo y no matan) y C4 (al terminar se va a la pantalla provisional del hub). Lo siguiente son **propuestas adoptadas** (valores en `data/flow.json` y `data/world1_objects.json`, sección `checkpoint`; se ajustan jugando):

- **Escena principal:** `scenes/main.tscn` (`LevelRunner`) carga el nivel actual (por defecto el 1-1) y empieza siempre de cero: Sync Rate 100 %, energía de Debug 100 (no se usa en el 1-1), 0 puntos de atención, sin punto de sincronización y Debug apagado.
- **Punto de sincronización:** baliza de 2 tiles con bandera gris a media asta que pasa a bandera cian izada y ondeando al tocarla (el cian del Debug se admite por ser interactivo). Se guarda una sola vez y solo hay uno activo por nivel (el más reciente). Sin texto.
- **Muerte:** animación `death` completa (19 cuadros a 12 fps, 1,58 s), pausa de 0,5 s, fundido a `noche_profunda` de 0,3 s, reaparición y fundido de entrada de 0,3 s. Al reaparecer: Sync Rate 100 %, Debug apagado, energía sin cambios, 1 s de invulnerabilidad con parpadeo (la misma del golpe).
- **Estado del nivel al reaparecer (cero castigo):** se conserva todo (puente extendido, receptor activado, pop-up cerrado, puntos recogidos, Burbuja reventada). La Burbuja que sigue viva vuelve a su sitio patrullando y sin aturdir. Los puntos de atención no se pierden.
- **Red de seguridad:** si Isak cae más de 64 px por debajo del borde inferior del nivel (un hueco sin fondo por error), reaparece en el último punto de sincronización (o en `P`) con el mismo fundido y **sin quitar Sync Rate** (`fall_sync_penalty` 0). No cuenta como muerte. El 1-1 no tiene huecos sin fondo, así que en el slice no debería saltar nunca.
- **Final:** al cruzar la puerta se marca el 1-1 como completado y se desbloquea el 1-2 (según `unlocks`; el 1-2 no existe y no se carga). Tras un fundido aparece la pantalla provisional del hub con los puntos recogidos; salto reinicia el 1-1 desde cero.
- **Dudas:** (1) V3 aprobó que caer fuera del nivel quita un 20 % y devuelve al último suelo seguro; aquí la red de seguridad no quita nada y devuelve al punto de sincronización. ¿Se mantiene así en el 1-1 y se aplica el 20 % desde el 1-2? (2) ¿Debe la energía de Debug reponerse también al reaparecer? (3) ¿Los puntos de atención deben guardarse entre partidas? **Resuelta el 2026-10-14:** sí. Se guardan en disco y ya no vuelven a 0 (ver «Decisiones del 2026-10-14: mejoras permanentes, guardado y recargas»).

## Decisiones del 2026-10-14: mejoras permanentes, guardado y recargas

Respuestas del usuario a las dudas 1, 2 y 4 de `docs/propuesta-1-1-ampliado.md` y decisiones nuevas. Implementado sin tocar el diseño del 1-1 (`data/levels/1-1.json` y `scenes/levels/1-1.tscn` siguen igual). Los valores son **propuestas** y se ajustan jugando. Los valores de movimiento no cambian.

- **Decisión 1, dónde se compran las mejoras:** en el hub, con puntos de atención. Mientras no exista el hub real se compran en la pantalla provisional (`scenes/hub/hub_placeholder.tscn`), que lista las mejoras con su coste y estado, los power banks y el detalle de la mejora elegida (valor base y valor nuevo). Se maneja con el Input Map: `move_up`/`move_down` eligen, `pulse` compra y `jump` vuelve a jugar. Los textos y colores están en `data/hub_placeholder.json`.
- **Decisión 2, catálogo:** se aprueban el power bank y "Pulso amplio", y se pueden añadir otras mejoras. El catálogo es `data/upgrades.json` (extensible: una entrada por mejora con `target`, `value` y `cost`). Una mejora comprada cambia el **valor efectivo** (`GameState.effective_value`, `apply_upgrades`, `DebugMode.get_drain_per_second`/`get_activation_hold_s`, `get_sync_rate_max`, `get_debug_energy_max`, `get_energy_per_attention_point`); los JSON base y las constantes no se modifican. Valores de la propuesta: Pulso amplio (radio 96 → 112 px, 15 puntos), Sync reforzado (máximo 100 → 120, 30 puntos + 1 power bank), Debug eficiente (gasto 20/s → 15/s, 50 puntos + 1 power bank), Batería ampliada (energía máxima 100 → 150, 30 puntos + 1 power bank), Arranque rápido (carga del Debug 1,0 → 0,5 s, 20 puntos) y Recarga mejorada (energía por punto 10 → 15, 25 puntos). El HUD muestra el Sync Rate real (puede pasar de 100 %) y, al empezar o reaparecer, el nivel llena la barra hasta el máximo efectivo (`start_state` de `data/flow.json` pasa a ser un porcentaje del máximo).
- **Decisión 3, recargas y power banks:** **Superada el 2026-10-25** (power bank coleccionable puro: ver «Decisiones del 2026-10-25: power bank coleccionable puro»). Los enemigos y jefes sueltan recargas de energía de Debug y de Sync Rate (`RechargePickup`; comportamiento y aspecto en `data/recharge_pickup.json`). Cuánto suelta cada enemigo va en su JSON, en la sección `drops`. Para la Burbuja de alerta se propone **energía +25** (1,25 s de Debug) y **Sync Rate +10** (lo que quita un golpe), solo al reventarla, no al aturdirla. Si la barra de Debug ya está llena, el sobrante carga el power bank (`GameState.add_debug_energy`). Cada **200 de energía** sobrante completan un power bank (`data/power_bank.json`, `capacity_energy`, equivale a dos barras llenas). Los power banks completos y la carga parcial se guardan. El HUD muestra un contador mínimo bajo la barra (icono de pila con la carga parcial y "x<n>"), creado por código sin tocar `hud.tscn` ni `data/hud.json`, y oculto si no hay power banks ni carga.
- **Decisión 4, puntos de atención:** no se pueden volver a capturar en el mismo mapa. Se guardan por nivel los ids de los puntos ya capturados (el nombre del nodo generado, p. ej. `Point_8_9`, o `point_id`), así que no reaparecen ni cuentan al rejugar. El total acumulado persiste entre partidas: el flujo de nivel ya no lo pone a 0 al empezar o reiniciar.
- **Decisión 5, guardado:** `user://save.json` (`GameState` + `SaveFile`), con esquema versión 1: `version`, `attention_points`, `captured_points` (nivel → ids), `upgrades_purchased`, `power_banks` (`full`, `charge`), `completed_levels` y `unlocked_levels`. La escritura es atómica: se escribe un `.tmp` y se renombra (si queda un `.tmp` huérfano, se recupera). Si el archivo no existe, se empieza de cero. Si está corrupto o tiene una versión desconocida, se aparta como `save.json.corrupt` y se empieza de cero. Los campos con tipos raros se ignoran. Se guarda al final del cuadro (agrupando cambios) al capturar un punto, cargar un power bank, comprar una mejora y completar o desbloquear un nivel. Las pruebas GUT usan `user://test_save.json` y el bot `user://bot_save.json`, así que nunca tocan el guardado real. La variable de entorno `ISAK_SAVE_PATH` cambia la ruta.
- **Dudas abiertas:**
  1. ¿La energía de los puntos de atención también debe desbordar al power bank? Ahora sí (`attention_point_energy_overflows: true`). Con el 1-1 actual y la barra llena, una partida da 17 × 10 + 25 = 195, casi un power bank. **Resuelta el 2026-10-14:** no; solo desbordan los drops (ver «Decisiones del 2026-10-14 (2)»).
  2. Los enemigos reaparecen al rejugar un nivel, así que sus drops se pueden farmear para conseguir power banks. ¿Se limita (drops una sola vez por enemigo, como los puntos) o se deja así? **Resuelta el 2026-10-14:** se deja así por ahora.
  3. ¿Las mejoras deben desbloquearse antes con un secreto, como sugería la propuesta, o basta con pagarlas, como ahora?
  4. Aspecto provisional: las recargas son dibujos simples (pila en el color del Debug y cruz blanca) y el contador del HUD usa un icono dibujado. ¿Se hacen sprites propios y se integra el contador en la barra del HUD definitivo?
  5. Con "Sync reforzado", el umbral de Sync Rate bajo sigue en 20 de Sync Rate absoluto, no en el 20 % del máximo. ¿Se prefiere en porcentaje?

## Decisiones del 2026-10-14 (2): power banks, enemigos, dificultad y propuesta de tres vueltas

Valores de movimiento: sin cambios.

- **Decisión 1, el sobrante solo desborda desde los drops:** **Superada el 2026-10-25** (power bank coleccionable puro: ver «Decisiones del 2026-10-25: power bank coleccionable puro»). la energía de Debug sobrante (barra llena) solo carga el power bank cuando viene de los **drops** de enemigos y jefes. Los puntos de atención llenan la barra, pero no desbordan. `data/power_bank.json`: `attention_point_energy_overflows` pasa de `true` a `false` (si falta la clave, `GameState` también usa `false`). Prueba: `test_attention_point_energy_does_not_overflow`.
- **Decisión 2, un power bank llega vacío:** **Superada el 2026-10-25** (power bank coleccionable puro: ver «Decisiones del 2026-10-25: power bank coleccionable puro»). un power bank comprado u obtenido (p. ej. el `power_bank_pickup` de mapa) se recibe **vacío** (carga 0) y se llena con el sobrante de los drops. `GameState` separa ahora `power_banks` (completos; son los únicos que pagan mejoras), `empty_power_banks` (vacíos o cargándose) y `power_bank_charge` (carga del vacío que se está llenando). `add_empty_power_bank()` suma uno vacío; `collect_power_bank_pickup()` lo usa. Cada `capacity_energy` (200) de sobrante llena un vacío, que pasa a completo. El guardado añade `power_banks.empty` (sin cambiar la versión 1); un guardado antiguo con carga y sin `empty` conserva la carga en un power bank vacío. El HUD muestra el contador también si solo hay power banks vacíos.
- **Decisión 3, enemigos y farmeo:** los enemigos reaparecen al rejugar un nivel y sus drops se pueden farmear. Se deja así por ahora.
- **Decisión 4, dificultad:** la dificultad ya no se elige. C9 queda sustituida por una dificultad que evoluciona con el juego (el usuario lo confirma). **Concretada el 2026-10-15:** tres vueltas Easy, Normal y Hard (ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado»).
- **Dudas abiertas (power banks):**
  1. **Resuelta (decisión del usuario, 2026-10-15):** sin ningún power bank vacío, el sobrante de los drops **se pierde**: no se acumula ni se devuelve al obtener después un power bank vacío. `GameState.add_power_bank_charge` ya lo hacía así; la prueba `test_overflow_is_lost_without_empty_power_banks` lo comprueba.
  2. Al pagar una mejora, el power bank completo se gasta y desaparece (no vuelve como vacío). ¿Es así, o se recarga y se reutiliza? **Resuelta (decisión del usuario, 2026-10-16):** se gasta y desaparece; solo lo pide el nivel 5 de cada pista de Calc (`propuesta-mejoras.md` §5.1).
  3. Hoy no hay forma de **comprar** un power bank: el catálogo `data/upgrades.json` no tiene esa entrada. ¿Dónde se compra y cuánto cuesta? **Resuelta (decisión del usuario, 2026-10-16):** no se compran; Calc no los vende. Vienen de los mapas, con un tope de 3 a la vez (el tope, superado el 2026-10-25: sin tope).
  4. **Resuelta:** los textos de `power_bank_pickup` (`data/world1_objects.json` y `scripts/levels/power_bank_pickup.gd`) ya dicen "vacío". (Desde el 2026-10-25 dicen "completo".)

## Notas del 1-1 ampliado (2026-10-14)

Implementa `docs/propuesta-1-1-ampliado.md` con las decisiones del usuario del 2026-10-14. Física, sprites y sistemas sin cambios.

- **Mapa:** 300x14 tiles (`data/levels/1-1.json`, generado por un script de trabajo; las notas del JSON resumen la geometría). Once secciones: Tramo 1 (1-52: foso de 2 tiles, escalón de 2, una vía y un segundo foso), 2a (puente a ras de suelo), 2b (receptor sobre una meseta de 1 tile y dos puentes de 5 tiles seguidos), 2c (secreto A), 3a (la Burbuja del 1-1 original bajo su techo bajo), 3b (Burbuja a 100 px/s sobre una meseta), 3c (dos Burbujas bajo el mismo techo), 4a (pop-up a ras de suelo), 4b (Burbuja bajo techo y pop-up sobre un escalón), 4c (receptor, puente y pop-up que se cierra de pie en el puente) y Cierre (puerta en la columna 290 y pared con glitch en la 298). Sin pinchos. Un solo punto de sincronización, en la columna 150 (mitad del mapa).
- **Cambios frente a la propuesta:** (1) 3b no usa la Burbuja aturdida como escalón ni 3c pinchos: el validador solo modela la Burbuja como puerta bajo un techo bajo, así que todas las Burbujas van bajo techo (la frase de Eco "también sirve de escalón" y la de los pinchos no se usan). (2) Los puentes de 2b miden 5 y 5 (con 4 tiles un salto corriendo con coyote time podría cruzar). (3) Los receptores quedan 2 tiles antes del foso: desde dentro del foso el pulso no los alcanza (si no, el puente se cerraba encima de Isak: soft-lock real, también en el 1-1 anterior). (4) Secreto B: se sube al techo de 3a por plataformas de una vía tras el techo, no desde 3b. (5) Secreto C: una vía hasta una repisa alta con un pop-up opcional, sin la Burbuja como escalón.
- **Puntos de atención (sustituido el 2026-10-15 por la economía de `docs/propuesta-1-1-ampliado.md` §6: 20 en la ruta, 10 en A, B y C, 5 en el secreto del Pulso amplio y sin power banks en el 1-1):** 79 en la ruta y 24 en los secretos A, B y C (8 cada uno) = **103**, suficiente para Pulso amplio (15), Sync reforzado (30) y Debug eficiente (50) = 95 sin farmear (no se recapturan).
- **Power banks:** uno **vacío** en cada secreto A, B y C (`power_bank_pickup`, nuevo en el catálogo). Solo los carga el sobrante de los drops, y las Burbujas bajo techo bajo no se pueden reventar, así que el 1-1 no da carga: **no se puede pagar el power bank de Sync reforzado ni de Debug eficiente solo con el 1-1** (duda abierta abajo).
- **Secretos:** A (repisa alta sobre el Tramo 2; receptor escondido al final del tramo con un puente de 8 tiles hacia la izquierda), B (encima del techo de 3a), C (nicho tras un pop-up en lo alto del Tramo 4) y D (pared con glitch; **pendiente**, se abre con el Debug, V12). Los secretos declaran sus puertas opcionales con el campo `gates` (sin avisos del validador).
- **Eco:** líneas de primera vez de la propuesta §3 con `eco_line` (`once`): punto, foso, receptor, puente, Burbuja, sincronización, pop-up, power bank, puerta y pared con glitch. `[pulso]` se cambió por "lanza el pulso" (el cuadro de Eco no sustituye teclas).
- **Validador:** el soft-lock usa ahora un grafo (nodo, puertas abiertas) restringido a lo alcanzable (antes probaba todas las combinaciones de puertas: con 14 puertas no terminaba). Los secretos con objeto recogible deben alcanzarse. Margen mínimo 12,5 puntos (igual que antes; peor salto 72,5 % en vertical).
- **Duración medida (bot):** 89,7 s caminando y 57,0 s corriendo por la ruta, sin secretos, 0 golpes. Con lectura de Eco, dudas y los tres secretos se estima unos 2-2,5 min. `target_duration_s` 150.
- **Dudas:** (1) Con los power banks vacíos y sin drops en el 1-1, ¿de dónde sale la carga para las mejoras que cuestan power bank? ¿Se deja una Burbuja al aire libre que se pueda reventar (su pulso no sería obligatorio) o se cargan en el 1-2? (2) ¿La duración (unos 90 s caminando la ruta) basta o se alarga el mapa?


### Propuesta de tres vueltas a los 18 mapas y "rollback" (histórico; aprobada el 2026-10-15)

**Estado: aprobada como decisión de diseño el 2026-10-15, a falta de detalle** (ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado», que manda sobre esta sección). Donde difieran, vale la decisión del 2026-10-15: en Easy el jefe final **escapa** y lanza el rollback; en **Normal** engaña a Isak para que lo lance él; en **Hard** vencerlo termina el juego (final real, con el momento de decisión de §14.1). Sin implementar. `06-finales.md` §14.1 lleva una nota de encaje; `03-historia.md` no se ha tocado.

- **Idea del usuario:** el juego se recorre **tres vueltas** de los 18 mapas (6 mundos × 3 niveles): Fácil, Normal y Difícil máxima.
- **Rollback:** al estar a punto de morir, el jefe final lanza un "rollback" que reinicia los mapas con enemigos más difíciles y puntos débiles distintos. ~~En la **tercera vuelta**, el jefe engaña al jugador para que sea él quien lance el rollback.~~ Superado: el engaño es en la **segunda vuelta** (Normal); ver la decisión del 2026-10-15.
- **Único final real:** terminar el juego en la dificultad máxima.
- **Qué se conserva:** el rollback "falla", así que Isak conserva sus habilidades. Los puntos de atención reaparecen para comprar las habilidades nuevas, pero solo en un ciclo de dificultad superior.
- **Mapas:** en cada rollback los mapas pueden fallar, cambiar o destruirse (por pensar).
- **Prioridad de producción:** primero los 18 mapas de la primera vuelta en modo fácil, sin que se puedan conseguir todas las mejoras en esa vuelta.
- **Preguntas abiertas** (histórico; la 2 queda resuelta por la decisión del 2026-10-15 y las demás siguen en sus dudas abiertas):
  1. ¿Qué cambia narrativamente en cada vuelta (Eco, aliados, amigos, recuerdos)? Lo piensan juntos el usuario y Claude.
  2. ~~¿Cómo encaja con §14.1?~~ Resuelta el 2026-10-15: el momento de decisión y los finales A y B llegan al vencer al jefe en Hard (tercera vuelta); el rollback engañado es en Normal.
  3. ¿Qué significa en el juego "fallar, cambiar o destruirse" para un mapa? ¿Cambia la geometría o solo los enemigos, los peligros y los puntos débiles?
  4. Puntos débiles distintos en cada vuelta: ¿siguen la regla de color (rojo/carmín) y el telegrafiado de 6 a 12 cuadros?
  5. Guardado: los puntos de atención capturados se apuntan por nivel; para que reaparezcan en una vuelta superior habría que guardar también la vuelta. ¿Pasa lo mismo con los power banks de mapa y los secretos?
  6. ¿Qué mejoras se pueden conseguir en cada vuelta y cuáles quedan para las siguientes?
  7. ¿Cómo convive esta progresión con la dificultad por nivel que dan los `mundo-N` ("X de 5")? ¿Es la base de la primera vuelta?

## Cambios del 1-1 tras jugarlo (2026-10-15)

Pedidos por el usuario tras jugar el 1-1. Detalle y tablas en `docs/propuesta-1-1-ampliado.md` §6.

- **Burbujas:** las cinco iban bajo techo bajo y no se podían pisar ni reventar. Ahora solo `burbuja_1` (3a) sigue bajo techo bajo, como puzle obligatorio del Tramo 3. Las otras cuatro (3b, dos en 3c y 4b) van en abierto (`"open": true`), con una patrulla de 128 px y una repisa de una vía 3 tiles por encima de su suelo. Aturdida, la Burbuja sirve de escalón para subir a la repisa, y saltando desde la repisa revienta (unos 1357 px/s frente al umbral de 1150) y suelta energía +25 y Sync +10. Así se resuelve la duda (1) de «Notas del 1-1 ampliado»: el 1-1 ya tiene drops para cargar power banks. No cambia ningún valor de `data/enemies/alert_bubble.json`. El nivel se completa sin reventar ninguna. **Nota:** una caída sin salto de 5 o 6 tiles no sirve, porque solo revienta aturdida y el aturdimiento (3 s) no da tiempo a subir tan alto. Saltar desde 3 tiles equivale a caer desde unos 5,8.
- **Puntos:** unos 9 por mapa, para que «Pulso amplio» (25) se pague justo al terminar el 1-3. El 1-1 pasa de 35 a 9 (6 en la ruta y 1 en cada secreto A, B y C). Costes (anterior → nuevo): Pulso amplio 25 → 25, Arranque rápido 60 → 20, Recarga mejorada 90 → 25, Batería ampliada 120 → 35, Sync reforzado 150 → 45 y Debug eficiente 200 → 60 (fórmula 9 × N mapas, redondeado a 5).
- **Nicho del Pulso amplio:** en vez de 5 puntos guarda el único power bank (vacío) del 1-1 (`power_bank_pulso_amplio`). Vuelve la línea de Eco del power bank.
- **Dudas:** (1) ¿Bastan las repisas de 3 tiles, o se quiere una caída mayor? Haría falta un aturdimiento más largo para esas Burbujas (`stun_duration_s` por enemigo). (2) El punto de la repisa del 3b solo se alcanza usando la Burbuja aturdida de escalón: ¿cuenta como punto de la ruta?

## Láser, vida de enemigos y energía (2026-10-15)

Decisiones del usuario del 2026-10-15. Esta fase es solo el núcleo (sistemas, datos y pruebas); el 1-1 no cambia todavía (ni `data/levels/1-1.json` ni su escena): su rediseño es la fase siguiente.

- **Teclas:** el pulso pasa de **J** a **G** (misma acción `pulse`; en el mando sigue en X, botón 2). Nueva acción `laser`: **F** y, en el mando, el **gatillo izquierdo** (eje 4; el derecho, eje 5, ya es correr; los botones libres que quedaban eran los clics de stick). En la pantalla provisional del hub la compra sigue con la acción `pulse` (ahora G).
- **Láser (valores PROPUESTA, `data/isak_abilities.json`, `laser_*`):** proyectil horizontal hacia donde mira Isak, desde el celular. Coste 10 de energía (la **misma** barra del Debug, `GameState.debug_energy`: 10 disparos con la barra llena), daño 1, enfriamiento 0,4 s, anticipación 0,05 s (3 cuadros a 60 fps, destello en el celular), 1200 px/s y 768 px de alcance (12 tiles). Se cobra al salir el disparo. Sin energía suficiente no dispara: chispa gris en el celular y `EventBus.laser_denied`. Vale en el suelo y en el aire (cambiado después, 2026-10-15: solo en el suelo, como el pulso; ver «Láser como el pulso, confirmación al entrar sin guardar y miniatura de carpeta»), no durante el golpe (Hurt) ni muerto; no cambia la física de Isak ni tiene animación propia todavía. **Cambio (2026-10-15, pedido por el usuario):** al disparar Isak se detiene como con el pulso: mientras dura la pose del láser (anticipación 0,05 s + brazo extendido 0,25 s = 0,30 s; se alarga si se encadenan disparos) la dirección se ignora y frena con la fricción del suelo (o con `air_acceleration` en el aire), sin girarse; la gravedad no cambia. Antes se movía libre y se veía la pose deslizándose. `laser_locks_movement` en `data/isak_abilities.json` (false = comportamiento anterior). El salto no corta la pose (sube en vertical hasta que acaba; cambiado después: durante la pose no se salta, como en el pulso); el golpe, la muerte, la pose de espaldas y la reaparición sí. Coste, daño, enfriamiento y alcance sin cambios. Choca con el terreno (capa world) y con los enemigos (capa enemy). Aspecto provisional dibujado por código (cian del Debug y banner_blanco).
- **Habilitación:** habilidad desbloqueable `laser` en `GameState.abilities_unlocked`, bloqueada hasta obtenerla con un objeto `ability_pickup` (param `ability`). La habilidad obtenida se guarda (`abilities_obtained` en `user://save.json`) y emite `EventBus.ability_obtained`; el cuadro de Eco muestra un aviso simple (texto de interfaz provisional, no es línea de guion). Los `abilities_available` de un nivel no bloquean una habilidad obtenida.
- **Idea anotada (sin implementar):** el láser podrá activar objetos del entorno. Interfaz preparada: el proyectil llama a `on_laser_hit(damage, source)` en el nodo alcanzado (o en un padre); una Area2D debe estar en el grupo `laser_activatable` para que el láser la toque. Ningún objeto la usa todavía.
- **Vida de enemigos:** todo enemigo tiene `health` en su JSON (sin valor estándar; `params.health` del nivel la sobrescribe por instancia, vía `GeneratedLevel` → `max_health`). Interfaz común `EnemyHealth` (`scripts/enemies/enemy_health.gd`), pensada también para los jefes. Burbuja: `health` 2 (dos disparos). Al recibir daño parpadea; a 0 muere (animación pop) y suelta sus `drops` (energía +25, Sync +10; el desborde de energía a un power bank vacío sigue siendo solo de los drops). El pulso sigue aturdiendo igual y no quita vida.
- **Pop por caída (cambio de C7):** anterior: caer sobre la Burbuja aturdida a ≥ 1150 px/s la reventaba → nuevo: pisarla nunca la mata, solo es plataforma/escalón. Constante `stomp_pop_enabled: false`; `pop_speed_threshold_px_s` queda solo como referencia. Pruebas adaptadas lo mínimo (`test_alert_bubble*.gd`, la prueba simulada de repisas de `test_level_1_1.gd`, `test_power_bank_and_drops.gd`). **Pendiente del rediseño:** `tools/validate_level.py` sigue buscando la "repisa de pop" de las Burbujas `open` (regla ya obsoleta) y las cuatro Burbujas en abierto del 1-1 ya no se pueden eliminar sin láser. **Resuelto el 2026-10-15** (ver «Rediseño del 1-1 para el láser»).
- **Energía:** la comparten el Debug y el láser. Todos los enemigos sueltan energía al morir (sección `drops` de su JSON, generalizada con `EnemyHealth.parse_drops`). En el hub se recarga: la pantalla provisional del hub llena la barra al entrar (`refill_debug_energy` en `data/hub_placeholder.json`). En los mapas habrá **cargadores** (`charger`).
- **Cargador (`charger`, PROPUESTA):** se activa **al tocarlo** (como el punto de sincronización y la puerta, sin acción nueva). Repone `amount` 50 (media barra = 5 disparos) sin desbordar a los power banks; con la barra llena no se gasta. Por defecto **reutilizable** con `cooldown_s` 20 (tiempo del mundo); con `reusable: false` es de un solo uso y queda gastado en el guardado por nivel (`collected_pickups`, como los power banks de mapa); el enfriamiento del reutilizable no se guarda. Gráfico provisional por código (poste con pantalla en la paleta del Mundo 1).
- **Generador y validador:** `charger` y `ability_pickup` están en el catálogo `data/world1_objects.json`, en `tools/validate_level_schema.py` (no pueden estar dentro de terreno; `ability` admitida: pulse, debug, laser; `amount` > 0, `cooldown_s` ≥ 0, `reusable` booleano; `laser` admitida en `abilities_available`) y en `tools/build_level.py` (`ability` como StringName). No se ha colocado ninguno en el 1-1.
- **Energía inicial del 1-1 (PROPUESTA):** 100 % (barra llena = 10 disparos), como ya hacía `start_state` de `data/flow.json` para todos los niveles; no cambia nada. Alternativa: 50 % por nivel para dar sentido a cargadores y drops.
- **Contradicciones con texto aprobado (no se reescribe; ver nota en `docs/02-isak-habilidades.md`):** (1) §3.3 dice que la energía de Debug «se gasta con el Debug Mode y se recupera con puntos de atención» y A2 se apoyaba en que «solo el Debug gasta energía»: ahora también la gastan el láser y la reponen drops, hub y cargadores. (2) C7 (arriba): la caída ya no elimina. (3) §3.2 «el enemigo aturdido se puede eliminar»: ahora se elimina con el láser, aturdido o no.
- **Dudas abiertas:**
  1. Cargador: ¿reutilizable con enfriamiento (propuesta, 20 s) o de un solo uso? ¿50 por uso?
  2. ¿La Burbuja recupera la vida al reaparecer Isak tras morir? Ahora conserva el daño recibido (solo vuelve a su sitio patrullando).
  3. ¿El láser necesita animación propia de Isak? Ahora dispara sin cambiar de animación (solo el destello).
  4. ¿Energía inicial del 1-1 al 100 % o menor?
  5. El aviso del `ability_pickup` sale en el cuadro de Eco: ¿lo dice Eco con su voz (texto de guion) o debe ser un aviso de interfaz aparte?

## Rediseño del 1-1 para el láser (2026-10-15)

Implementa las decisiones del usuario del 2026-10-15 (láser obligatorio a mitad del 1-1, más Burbujas al principio, cargadores, vida por instancia y Burbujas en abierto sin repisa). El detalle y las tablas están en `docs/propuesta-1-1-ampliado.md` §7. No cambian la física de Isak ni los valores del láser o de la Burbuja.

- **Sala del láser (3b):** está tras el checkpoint de la columna 150. Primero, el receptor del suelo extiende un puente en alto. Desde ese puente se activa el receptor de una repisa flotante, que extiende un segundo puente hasta un pop-up en alto. Su botón solo se alcanza desde el final de ese puente. Detrás hay un túnel bajo con el `ability_pickup` del láser. Recogerlo es obligatorio (la base de la sala corta el suelo) y la meta se alcanza sin disparar.
- **Burbujas:** pasan de 5 a 9:
  - Antes del láser, tres en abierto que se saltan o se aturden (Tramo 1 a 60 px/s, final del Tramo 1 a 80 y 2c a 100).
  - La del 3a, bajo techo bajo.
  - Después del láser, cinco en abierto que se pueden matar (3c ×2, 4a, 4b y Cierre). La del Cierre tiene vida 3.
- **Cargadores:** dos, con los valores por defecto. `cargador_1` va tras la sala, antes de la primera Burbuja que cuesta energía, y `cargador_2` al empezar el Cierre.
- **Repisas:** la del 4b se quita, porque solo servía para reventar la Burbuja. La del 3c se queda y guarda el punto de la ruta que antes estaba en la repisa del 3b. Siguen siendo 9 puntos (6 en la ruta y 3 en los secretos) y la economía no cambia.
- **Herramientas:**
  - `eco_line.trigger_event` (`laser_fired`): la línea del primer disparo.
  - Validador: puentes como tabla fina, `ability_pickup` como estado del grafo y láser como forma de abrir Burbujas; ya no busca la repisa de pop.
  - Bot: dispara a las Burbujas a su altura cuando tiene el láser.
  - Capturas nuevas en `tools/render_level_1_1.gd`.
- **Duración (bot):** 93,8 s caminando y 62,5 s corriendo (antes 89,7 y 57,0), matando las cinco Burbujas con 11 disparos y sin golpes.
- **Dudas abiertas:**
  1. **Energía demasiado holgada.** Se llega al láser con la barra llena (nada la gasta antes en el 1-1). Cada Burbuja de vida 2 cuesta 20 y suelta 25, así que sin fallar la energía nunca baja de verdad: el bot termina con 100 y los cargadores no llegan a usarse. ¿Se empieza el 1-1 con menos energía (p. ej. un 30 %; haría falta un `start_state` por nivel, que hoy no existe) o se bajan los drops? Es la duda 4 de «Láser, vida de enemigos y energía».
  2. El punto de la repisa del 3c solo se alcanza usando una Burbuja aturdida como escalón. Si el jugador mata antes las dos, pierde ese punto en esa partida (vuelve a estar al rejugar). ¿Vale así, o se mueve el punto?
  3. ¿Se aprueban las líneas de Eco nuevas (PROPUESTA)?
     - Techo bajo del 3a: «Aquí no hay sitio para saltarla. Un pulso y la dejo en pausa por ti.»
     - Antes de la sala: «Ahí arriba guardo algo útil para ti. Los receptores conocen el camino.»
     - En el túnel: «Herramienta nueva. Dispara hacia donde miras; cada disparo gasta energía.»
     - Primer disparo: «Dos impactos bastan para cerrar una alerta. Lo que suelta, recógelo: es tuyo.»
     - Texto del pop-up de la sala: «Función premium bloqueada. Mira este anuncio para continuar».
  4. La tercera Burbuja previa al láser va en el 2c, no al inicio del Tramo 2: el 2a y el 2b ya están ocupados por receptores y puentes, y una Burbuja junto a un puente podría subirse a él. ¿Vale?
  5. El segundo cargador no está «cerca del checkpoint» porque antes del láser la barra siempre está llena. Está al empezar el Cierre, antes de la Burbuja con vida 3. ¿Vale esa posición?
  6. Con 9 Burbujas (antes 5), ¿el 1-1 sigue siendo de dificultad 1/5? El bot no recibe golpes, pero un jugador nuevo puede recibir alguno en el Tramo 1.
  7. La línea del primer disparo sale la primera vez que se dispara en cada carga del nivel (`once` por nodo, como las demás líneas), no una vez por partida guardada.

## Avisos de control de las habilidades (2026-10-15)

Generaliza el aviso que salía al recoger el láser («Láser obtenido. F o gatillo izquierdo: dispara. Gasta energía.», escrito a mano en `data/world1_objects.json`) a todas las habilidades.

- **Datos:** `data/ability_notices.json`, una entrada por habilidad (`pulse`, `laser`, `debug`) con nombre, texto (`{name}: {control}`), acción del Input Map y `hold` para el Debug. Para una habilidad nueva basta con añadir su entrada.
- **Control leído del Input Map:** primera tecla y primer botón o eje de mando de la acción. Si se remapea, el aviso cambia. Textos finales: «Pulso: G / X (mando)», «Láser: F / gatillo izquierdo» y «Debug: mantén K / Y (mando)». Los nombres de los botones siguen la distribución tipo Xbox de la documentación.
- **Cuándo sale:**
  - Pulso: **[Reemplazado 2026-10-15 (3)]**: sale en la presentación de Eco, cuando Eco da el pulso (columna 11 del 1-1). Antes: al empezar el 1-1 en una partida nueva, 1 s después de entrar, así que salía justo tras la bienvenida de Eco. Solo dice el control: el uso lo explican las líneas de Eco de la Burbuja y del receptor.
  - Láser: al recogerlo, antes de la línea de Eco «Herramienta nueva…».
  - Debug: al desbloquearse durante un nivel o al empezar un nivel con él desbloqueado. Aún no ocurre en el 1-1; lo cubren las pruebas.
- **Una sola vez por partida guardada:** `seen_notices` en el guardado. En los guardados antiguos, las habilidades ya obtenidas cuentan como avisadas, así que el aviso del láser no se repite. Marcar un aviso no fuerza una escritura: se guarda con el siguiente cambio que guarde, como capturar un punto, obtener una habilidad o completar el nivel. Así, abrir el juego unos segundos no escribe el guardado.
- **Aspecto:** el mismo cuadro de Eco y la fuente `text_font` que el aviso anterior. Desde el 2026-10-15 (decisión del usuario) es una línea **importante**: pausa el juego y espera a que el jugador lo cierre (Espacio / A / Intro), y pasa delante de las líneas normales en cola (ver las notas del paso 14b). El HUD no cambia. Solo lo muestra el flujo de juego (`scenes/main.tscn`), no las escenas de prueba ni el bot.
- **Dudas abiertas:**
  1. El cuadro muestra el nombre «Eco» encima del aviso, igual que el aviso del láser de antes, aunque es texto de interfaz y no una línea de Eco. ¿Se quita el nombre en los avisos? Sería un cambio pequeño en el cuadro de Eco.
  2. Si un jugador ya tenía un guardado, verá una vez el aviso del pulso al volver a jugar el 1-1. ¿Vale así?

## Decisiones del 2026-10-15: tres vueltas, hub y guardado

Decisión de diseño del usuario. Sustituye el estado «pendiente de aprobar» de la «Propuesta de tres vueltas…» (arriba): queda **aprobada a falta de detalle**. Resuelve V12. Por ahora importa tener la idea; no se implementa nada.

**Corrección (2026-10-15):** el primer registro de esta decisión (commit 1e4c51c) invertía Normal y Hard: decía que el jefe final engañaba a Isak en Hard. Lo correcto es lo de abajo: el engaño es en **Normal** y **Hard** es el final real.

- **Tres vueltas:** el juego se recorre tres veces: **Easy** (1.ª), **Normal** (2.ª) y **Hard** (3.ª). No hay selector de dificultad: la vuelta se desbloquea por progresión (concreta C9).
- **Final de cada vuelta:**
  - **Easy:** el jefe final **escapa** y hace un **rollback**: el mundo vuelve atrás.
  - **Normal:** el jefe final **engaña** al jugador para que sea **él** quien haga el rollback.
  - **Hard:** al vencer al jefe final **termina el juego**. Es el **final real**: aquí llega el momento de decisión de `06-finales.md` §14.1 (Final A o B).
- **El rollback falla:** en cada rollback hay un fallo e Isak **mantiene sus habilidades**. En cada vuelta se añaden mejoras (duración, daño, capacidad, etc.). Qué mejoras da cada vuelta se define **vuelta por vuelta** más adelante (método aprobado por el usuario).
- **Puntos débiles:** los de los enemigos **cambian en cada vuelta**.
- **Qué cambia entre vueltas:** sube la dificultad, cambia el diseño visual de los mapas y se añaden rutas nuevas. Los enemigos y los subniveles (1-1, 1-2, 1-3, 2-1…) tienen contenido nuevo en cada vuelta. Ejemplo: el 1-1 Easy es el actual; en Normal, en vez de la misma ruta, el camino se bloquea y los activadores de puente fallan.
- **Plan de producción:** primero los 6 mundos con sus 3 subniveles en **Easy** (18 niveles); después se da forma a Normal y Hard.
- **Selección de nivel:** cuando exista el hub, desde él se elige la zona (1 a 6) y el subnivel (ver `05-hub.md` §13.6).
- **Puntos de atención:** no se restauran al rejugar un nivel; solo vuelven con un rollback, es decir, al pasar de Easy a Normal y de Normal a Hard (coherente con «Decisión 4, puntos de atención» del 2026-10-14). Da igual que lo haga el jefe (Easy) o Isak engañado (Normal).
- **Mejoras:** se compran en el hub (ya decidido el 2026-10-14, decisión 1).
- **Guardado: manual y solo en el hub.** El jugador guarda en el hub; si cierra el juego sin haber guardado en el hub, el progreso no se salva. Queda decidido y sustituye la duda de si se mantenía el guardado automático. El **1-1 debe enseñar a guardar** (tutorial en el primer nivel); como el hub llega después del Mundo 1, el tutorial necesita el hub o un punto de guardado en el nivel (dependencia abierta, ver `08-pendientes.md`).
- **Guardado actual, provisional:** hoy `user://save.json` se escribe **automáticamente** al capturar un punto, obtener una habilidad, comprar una mejora o completar un nivel (ver «Decisión 5, guardado»). Es provisional: hay que migrarlo al guardado manual cuando exista el hub. Sin cambios en el código todavía. **Actualización (2026-10-15):** migrado al guardado manual; ver «Hub y guardado: propuesta aprobada (2026-10-15)».
- **Hub:** se diseña cuando termine el 1-1, para dejarlo cuadrado.
- **Dificultad:** el usuario no recuerda por qué se decidió que «la dificultad ya no se elige» y pide una sugerencia. Queda abajo como **propuesta del equipo, pendiente de aprobar**. El rollback se verá más adelante.

### Nombres de las vueltas de cara al jugador (decisión del 2026-10-15)

El jugador no sabe que el juego tiene varias vueltas, así que la interfaz no puede decir «Vuelta 1 (Easy)».

- **Nombres externos (los que ve el jugador):** cada vuelta es un **nivel de acceso al sistema**: 1 **Caché**, 2 **Kernel** y 3 **Raíz**. En el hub (panel de la copia local y panel de subniveles de las carpetas) sale como «Acceso: Caché».
- **Nombres internos (código, datos y documentación):** siguen siendo vuelta 1, 2 y 3 (Easy, Normal y Hard; `GameState.lap`, `LAP_EASY`…). El número de vuelta y el esquema de guardado no cambian.
- **Regla:** la UI **nunca** dice «vuelta», «Easy», «Normal» ni «Hard».
- **Implementación:** `access_levels` de `data/hub.json` (`label` «Acceso: %s» y `names`, lista indexada por la vuelta 1-3) y `HubWorlds.access_name(lap)` / `access_label()`; una vuelta mayor que las definidas usa el último nombre.

### Sugerencia de dificultad (propuesta del equipo, pendiente de aprobar; no es decisión)

Dos ejes separados:

- **(a) Curva del nivel («X de 5»):** dificultad intrínseca de cada nivel dentro de la vuelta. Sube de forma autoral a lo largo de los mundos (del 1-1 al 6-3). No es adaptativa.
- **(b) La vuelta (Easy, Normal, Hard):** un conjunto de modificadores fijos sobre tres palancas:
  1. Vida y daño de los enemigos.
  2. Rutas y trampas nuevas (mapas alterados).
  3. Puntos débiles que cambian.

  Las ayudas del jugador (energía, drops) **no se ocultan** en ninguna vuelta.
- **Sin selector de dificultad:** la vuelta se desbloquea por progresión.
- **Sin dificultad dinámica oculta** dentro de una vuelta.
- **Ventajas:** es sencillo de probar (cada vuelta es un «perfil» de modificadores sobre la curva fija) y es coherente con las mejoras por vuelta.

### Dudas abiertas

Resueltas por la corrección (ya no son dudas): qué hace el jefe al final de Normal (engaña a Isak para que haga el rollback), si el rollback lanzado por Isak restaura los puntos (sí, como todo rollback), cómo se llega al final real (venciendo al jefe en Hard) y qué es guardar en el hub (guardado manual, solo allí).

1. **Mejoras por vuelta:** qué mejoras (duración, daño, capacidad…) se consiguen en Easy, Normal y Hard. Se define vuelta por vuelta.
2. **Dificultad:** aprobar, cambiar o rechazar la sugerencia de arriba (curva «X de 5» + perfil por vuelta).
3. **Rollback por mapa:** qué cambia en concreto en cada mapa (geometría, rutas, enemigos, peligros, puntos débiles, aspecto) y cómo se ve el paso de una vuelta a otra.
4. **Narrativa de cada vuelta:** qué cambia para Eco, los aliados, los amigos y los recuerdos; cómo se cuenta el escape (Easy) y el engaño (Normal).
5. **Avisos de puntos débiles nuevos:** si los puntos débiles de cada vuelta siguen la regla de color (rojo/carmín) y el telegrafiado de 6 a 12 cuadros, y cómo se avisa al jugador del cambio.
6. ~~**Guardado (detalle):** cómo es la acción de guardar en el hub (objeto o menú), cómo se enseña en el 1-1 sin hub (punto de guardado en el nivel u otra forma) y qué guarda además (vuelta actual, puntos capturados por vuelta, power banks de mapa, secretos).~~ **[RESUELTO el 2026-10-15]** con `docs/propuesta-hub-y-guardado.md`, aprobada: estación «copia local» en el hub, tutorial B + C sin guardado en los niveles y esquema v2 (`lap`, `found_secrets`, `hub_tutorial_done`, `saved_at`, `play_time_s`). Ver «Hub y guardado: propuesta aprobada (2026-10-15)».

## Llegada por vórtice, pausa de inicio y terminal de salida (2026-10-15)

- La bienvenida de Eco (importante, pausa) salía con el fundido de entrada aún en negro. Ahora Isak llega oculto y sin control; el vórtice de llegada espera a que acabe el fundido, se abre y, al empezar a cerrarse, Isak se muestra y salen las líneas de Eco de zona que esperaban: la pausa llega con el nivel y el vórtice en pantalla. El control vuelve al cerrarse el vórtice (unos 1,2 s tras el fundido). Lo mismo al reaparecer (sin línea de Eco).
- P del 1-1 pasa de (4, 3) a (4, 9), en el suelo: Isak ya no cae del cielo.
- Durante el vórtice (llegada y salida) Isak no recibe golpes (no puede moverse). Tras reaparecer siguen los 1 s de invulnerabilidad de siempre, que corren a la vez.
- La puerta de salida del 1-1 es ahora una terminal que se activa con el pulso (`exit_terminal`); `exit_door` sigue en el catálogo para las escenas de prueba. PROPUESTA para revisar jugando: zona de cercanía de 1,5 tiles a cada lado y el vórtice de salida centrado en Isak, no en la pantalla.

## Batería vacía por debajo del coste del láser (2026-10-15)

- Con el láser desbloqueado, el HUD muestra la batería vacía (sin segmentos, rayo apagado) si la energía es menor que el coste de un disparo (`laser_energy_cost`, 10). Antes, un resto de 0,01 a 9,99 dejaba 1 segmento encendido sin poder disparar. Solo cambia el dibujo: la energía real se conserva. Sin el láser se sigue viendo el resto (vacía solo con 0).
- **[RESUELTO] Duda:** el Debug se activa con cualquier energía > 0 (`DebugMode`, sin cambios). Cuando el jugador tenga láser y Debug a la vez (en el 1-1 el Debug está bloqueado), con un resto menor que 10 la batería se verá vacía pero el Debug aún se podrá activar unos instantes. ¿Se acepta así, se exige un mínimo de energía para activar el Debug, o la batería debe verse vacía solo cuando no se pueda usar ninguna de las dos?
  - **Decisión del usuario (2026-10-15):** se acepta así. El Debug **conserva su regla** (se activa con energía > 0) aunque la batería se vea vacía por debajo del coste del láser. No se cambia `DebugMode` ni el HUD.

## Hub y guardado: propuesta aprobada (2026-10-15)

Decisión del usuario: se aprueba `propuesta-hub-y-guardado.md` con la recomendación de sus 10 preguntas (§7). Resuelve la duda 6 de las tres vueltas («Guardado (detalle)») y C4 en el Mundo 1. Cambios aplicados en `05-hub.md` (§13.1, §13.2, §13.3 y §13.6).

1. El hub aparece desde el final del 1-1 (hub mínimo tras cada nivel del Mundo 1). La llegada narrativa sigue tras Alerta Mayor.
2. Tutorial de guardado B + C: línea importante de Eco junto a la terminal de salida del 1-1 y primer hub guiado. **No hay guardado dentro de los niveles.** **[Reemplazado 2026-10-15 (3)]**: Eco presenta a Notas en el primer hub y Notas explica cómo guardar.
3. Hub = sala 2D caminable con paneles; una sola pantalla en el Mundo 1.
4. Calc dormida en el hub del Mundo 1: vende sin hablar. **[Reemplazado 2026-10-15 (3)]**: no hay tienda hasta conocer a Calc al final del 1-2.
5. Aviso al cerrar con cambios sin guardar, también dentro de un nivel (allí sin opción de guardar).
6. Ajustes en `user://settings.cfg`, guardados al instante y aparte del guardado manual.
7. No se rejuegan subniveles de vueltas anteriores: solo los de la vuelta actual.
8. Rollback: se restauran los objetos del mapa (power banks de mapa y cargadores de un solo uso) además de los puntos; los secretos encontrados se conservan como registro.
9. Ajustes en el menú de pausa (acción `pause`) y accesibles desde un icono en el hub.
10. Se guarda `save.json.bak` con la copia anterior.

Además, el Debug conserva su regla (se activa con energía > 0; ver «Batería vacía por debajo del coste del láser»).

**Implementado (2026-10-15), pasos 1 a 3 de la propuesta (§6.2):**

- **Guardado manual:** `GameState.request_save()` ya no escribe: marca «sin guardar» (`has_unsaved_changes()`, señal `EventBus.unsaved_changes_changed`). Solo `GameState.save_game()` escribe, y limpia la marca. Capturar puntos, recoger objetos, comprar mejoras, obtener habilidades y completar o desbloquear niveles quedan en memoria hasta guardar. Marcar un aviso de control como visto no marca «sin guardar» (se guarda con la siguiente copia).
- **Esquema v2:** añade `lap` (1 Easy, 2 Normal, 3 Hard), `found_secrets` (nivel → ids), `hub_tutorial_done`, `saved_at` (fecha UTC) y `play_time_s`. Un guardado v1 se carga igual (`lap` 1, sin secretos, `hub_tutorial_done` verdadero si el 1-1 está completado) y la siguiente copia escribe la v2. Una versión desconocida se aparta como `.corrupt` y se empieza de cero. Al guardar, la copia anterior pasa a `save.json.bak`; si el guardado está corrupto y hay `.bak`, se carga el `.bak`.
- **Aviso al salir:** con cambios sin guardar, cerrar la ventana muestra un aviso (provisional, con el panel y la fuente de textos): en un sitio donde se puede guardar, «Guardar y salir / Salir sin guardar / Volver»; en un nivel, «Salir / Volver». Sin cambios, sale sin preguntar. Textos en `data/quit_prompt.json`. Las herramientas (`-s`) no lo usan.
- **Guardar mientras no exista el hub real (provisional):** la pantalla provisional del hub guarda con la acción nueva `save_game` (C / R3 del mando) y muestra «Guardar: …» y el indicador «sin guardar». Se sustituyó por la estación «copia local»; la acción `save_game` se retiró del Input Map el 2026-10-15 (C y R3 quedan libres).
- **Dudas para el usuario:** (1) ¿vale C / R3 como control provisional de guardar? (2) `play_time_s` cuenta el tiempo con el juego sin pausar, también en la pantalla del hub; ¿vale así? (3) Aún no hay nada que marque secretos encontrados (`GameState.mark_secret_found` existe, sin uso): se conectará con Linterna o con los secretos del 1-1. (2026-10-15 (3): la vida extra se registra como secreto encontrado; Linterna ya no cuenta secretos.)

## Láser como el pulso, confirmación al entrar sin guardar y miniatura de carpeta (2026-10-15)

- **Láser como el pulso (decisión del usuario):** el láser sigue la regla del pulso. Disparo en el aire: antes permitido, ahora bloqueado (en el aire la acción se ignora sin aviso, como el pulso: sin chispa, sin enfriamiento ni gasto). Salto durante la pose del láser: antes permitido (subía en vertical), ahora bloqueado como durante el pulso (el salto en buffer sale al acabar la pose). `laser_locks_movement`, coste, daño, enfriamiento y alcance sin cambios. El 1-1 no exige disparar en el aire (validadores y bot pasan).
- **Tutorial de guardado B + C:** **[Reemplazado 2026-10-15 (3)]** por «Decisiones del 2026-10-15 (3)» (Eco presenta a Notas en el primer hub). Antes: pendiente de rediseño por el usuario (Eco se presentará en el hub y presentará a Notas). No se implementan la línea de Eco «sin cobertura» ni el primer hub guiado. **Sí** queda decidido e implementado: **siempre** que se entra a una carpeta (subnivel disponible o completado) con cambios sin guardar sale «¿Seguro? Aún no has guardado.» (Entrar sin guardar / Volver); con todo guardado se entra directo.
- **Acción `save_game` retirada:** se guarda solo en la copia local del hub.
- **Miniatura del mundo en las carpetas (decisión del usuario):** icono pixel art de 16x16 por mundo junto al número; Mundo 1, una campana. Mundos bloqueados sin miniatura (no se adelanta nada). Sin insignia de vuelta ni dificultad (el jugador no sabe que hay vueltas).

## Decisiones del 2026-10-15 (3): asistentes, ayuda Q, vidas y papelera

Decisiones del usuario. Detalle, plan de implementación, arte y preguntas en `docs/propuesta-asistentes-y-vidas.md`. Sin implementar. El usuario aprobó también las propuestas del equipo que no contestó de forma explícita. Los valores numéricos son ajustables jugando.

**Vocabulario:** **vidas (intentos)** frente a **Sync Rate (salud)**. «Puntos» sin más son los puntos de atención (la moneda), no los puntos de sincronización.

**Eco**

1. Eco es un asistente digital que **no lanza mensajes a lo loco**.
2. En el 1-1 es lo primero que se obtiene: Isak llega por el vórtice, camina y se topa con Eco (columna 11). Eco se presenta y pide un **apodo**: el nombre con el que Eco llama al jugador, por defecto «Isak», distinto del nombre real que usan los recuerdos del Mundo 2. Después **da el pulso**: el pulso deja de tenerse desde el inicio y el tramo anterior no lo exige.
3. Eco **entra y sale con Isak** en los niveles y en el hub: una esfera que lo sigue con suavidad y oscilación, sin tapar la acción, y que entra con el vórtice.

**Ayuda con Q**

4. Acción `help` (Q / R3). Cerca de algo que no se conoce aparece una Q, como la G en la terminal. Al pulsarla el juego se detiene y Eco lo explica; se cierra con la acción del jugador. Cada ayuda pausa.
5. Se aprende **por tipo**: tras preguntar por una Burbuja, ninguna Burbuja vuelve a mostrar la Q.
6. Los objetos funcionan siempre, con Q o sin ella.

**Notas**

7. Notas es la **consola donde se guarda** (la «copia local» pasa a ser Notas). Llega en la primera visita al hub: Eco la presenta y Notas explica cómo guardar.
8. Notas es también un **álbum (códice)** de enemigos y objetos. Cada ficha se desbloquea al pedir ayuda con Q y las no vistas salen como silueta «???». Se lee en el hub, desde Notas.

**Calc y Linterna**

9. **Calc** se encuentra al final del 1-2, tras obtener el Debug (la historia, más adelante). Hasta entonces **no hay tienda** y su estación está apagada. Impacto: el secreto del Pulso amplio del 1-1 se abre tras el 1-2.
10. **Linterna** se encuentra al entrar en el X-1 de un mundo oscuro (mundo por decidir). Es un objeto que se activa solo en zonas oscuras.

**Vidas y rollback**

11. **Vidas:** 3 de base. Se reponen al empezar cada intento de nivel desde el hub; los puntos de sincronización no las reponen. Morir con vidas restantes hace reaparecer en el último punto de sincronización, como hoy.
12. **Vida extra:** se coge una sola vez por mapa y hay una cada 3 mapas (ajustable). Cada una sube **de forma permanente** el máximo base y se registra como secreto encontrado. La del 1-1 está en el **secreto D** (pared con glitch) y exige el Debug.
13. **Game over (0 vidas):** Isak vuelve al hub y Eco aplica un rollback a la **última copia guardada**.
    - Lo obtenido después de esa copia **se pierde**. Ejemplo: si pasas el 1-2, no guardas y mueres en el 1-3, repites el 1-2.
    - Lo guardado (habilidades, power banks, puntos de atención y mejoras) Eco lo «desecha» sin borrarlo: aparece en la **Papelera**, que parpadea y se mueve. Al acercarse se recupera todo.
    - Mientras la Papelera tenga contenido, las carpetas avisan «Recupera tus archivos de la papelera».
    - Si no había ninguna copia, la Papelera se activa igualmente y Eco dice que no había nada guardado.
14. **El rollback del jefe final es la misma mecánica:** Eco desecha todo y se recupera en la Papelera. Eso explica por qué Isak mantiene sus habilidades. La Papelera se activa la primera vez que hace falta.

**Mensajes de Eco**

15. Son **momentos de historia** (automáticos, con pausa) la presentación de Eco, el láser, el Debug, el primer game over o rollback, la presentación de Notas y las líneas de jefe. Las demás líneas del 1-1 pasan a ayuda con Q o se eliminan (tabla en la propuesta, §4).

**Notas anteriores que quedan reemplazadas** (marcadas en su sitio):

- Avisos automáticos de Eco en el 1-1 (V6, notas del paso 14b).
- El aviso del pulso al empezar el 1-1 («Avisos de control»).
- «Eco no entra en el hub» y el tutorial B + C (`propuesta-hub-y-guardado.md` §5).
- Calc dormida que vende desde el 1-1.
- Papelera que guarda puntos perdidos al morir (V2, §13.3).
- Notas tras el Mundo 2.
- Linterna que indica secretos tras el Mundo 4.

**Dudas abiertas** (con recomendación en la propuesta, §12):

1. Desde cuándo cuentan las vidas (recomendación: desde la primera llegada al hub). **Resuelta (2026-10-16): desde la primera llegada al hub**, implementada como «Notas conocida».
2. Mundo oscuro de Linterna (recomendación: el Mundo 4, en el 4-1).
3. Encaje de la Papelera con su aparición en el 4-2.
4. Si el rollback de Normal (lo lanza Isak, engañado) usa la Papelera (recomendación: sí).
5. Tono de Eco por vuelta.
6. Qué pasa con el pulso y el registro en un game over sin copia (recomendación: no se pierden). **Resuelta (2026-10-16): no se pierden nunca en un game over**, haya copia o no: Eco, Notas, Calc, el apodo, las ayudas aprendidas (álbum) y el pulso.
7. Eco en el hub frente a la «zona sin señal» (recomendación: Eco entra sin cobertura).

## Encuentro con Eco y mensajes de Eco del 1-1 (2026-10-16)

Implementados los pasos 6 y 7 de `docs/propuesta-asistentes-y-vidas.md` §10 (detalle en su «Estado»).

- **El 1-1 empieza sin pulso.** Isak llega por el vórtice, recoge el punto de la columna 8 y en las columnas 10-12 se topa con Eco (objeto `eco_encounter`, zona de toda la altura; Eco flota en la celda 12, 7). Nada antes exige el pulso: lo comprueba `tools/validate_level.py` (el pulso es un estado del grafo que da el encuentro).
- **Presentación (historia, con pausa):** bienvenida, Eco se presenta y pregunta cómo llamarte, entrada del apodo (por defecto «Isak»), Eco te llama por el apodo y te regala el pulso, aviso de control «Pulso: G / X (mando)» y una última línea («Si algo no lo conoces, acércate y pregúntame. Te ahorro el esfuerzo.»). Textos ajustables en `data/eco_encounter.json`, en la voz de Eco (servicial, algo engreída, con ganas de decidir por Isak).
- Al terminar, Eco es conocido (ayuda con Q y compañero) y la esfera vuela hasta Isak. Al rejugar, o con un guardado migrado con el 1-1 completado, no se repite.
- **Decisión técnica:** al cargar un guardado, Eco conocido implica el pulso obtenido. Así los guardados de antes del encuentro (el 1-1 daba el pulso al empezar) no se quedan sin pulso.
- **Mensajes de Eco del 1-1 (§4.1):** solo queda la historia del láser (`eco_laser`, con «Lo que sueltan las alertas, recógelo: es tuyo.»). Las líneas «Q» se quitaron del nivel (sus textos ya estaban en `data/help.json`) y las «eliminar» se borraron. El aviso del pulso al empezar desaparece de `data/ability_notices.json`: lo da el encuentro.
- **Texto de la ayuda del punto de sincronización:** «Punto de sincronización. Si caes, vuelves aquí.». No dice que guarde. La frase de la propuesta «Las vidas no se recargan, eso sí.» se añadirá con las vidas (paso 11), porque las ayudas no mienten. **Añadida el 2026-10-16** con las vidas.
- **Pruebas:** `tools/run_tests.sh` falla ahora (código 6) si GUT no puede cargar un script de prueba (un error de sintaxis hacía que GUT lo ignorara y saliera en verde) o si algún `tests/test_*.gd` no aparece entre los ejecutados (`tools/check_gut_log.sh`, con pruebas en `tests/test_run_tests_guard.py`).

## Vidas, game over, rollback y papelera (2026-10-16)

Implementados los pasos 11 y 12 de `docs/propuesta-asistentes-y-vidas.md` §10 (detalle en su «Estado»). Reglas aprobadas por el usuario:

- **Vidas (intentos), no Sync Rate (salud):** base 3 (`lives_max`). Se reponen a `lives_max` al empezar cada intento de nivel (entrar desde la carpeta, al arrancar y con la tecla R); los puntos de sincronización no las reponen. Morir con vidas restantes resta una y reaparece en el último punto de sincronización. Con 0, game over.
- **Desde cuándo cuentan:** desde la primera llegada al hub (Notas conocida, `GameState.are_lives_active()`). En el primer recorrido del 1-1 las muertes son ilimitadas y el HUD no muestra vidas.
- **HUD:** un mini teléfono de estilo circuito por vida (12x16 px de arte, `hud_lives.png` de `tools/gen_hud_assets.py`, colores de `mundo1.gpl`, sin rojo; lleno con la pantalla encendida y una traza, vacío apagado con una grieta), a la izquierda de la señal; con más de 8 vidas máximas, un icono y «x<n>». Al perder una, el icono que se apaga parpadea y da un bote. En el hub no se muestran.
- **Game over = rollback a la última copia:** `GameState.apply_rollback(reason)` es la **regla única** (también para el rollback del jefe final, paso 16, que añadirá su rama). Carga la última copia del disco: lo posterior se pierde (no va a la papelera) y los niveles completados después hay que rejugarlos. Lo guardado (habilidades salvo el pulso, power banks, puntos de atención y mejoras) Eco lo «desecha» a la **Papelera** (en memoria; el disco conserva la copia).
- **Nunca se pierde en un game over:** Eco, Notas, Calc y los demás asistentes conocidos, el apodo, las ayudas aprendidas (álbum) y el pulso. Sin ninguna copia previa, Eco dice que no había nada guardado y la papelera se activa vacía.
- **Hub tras el game over:** Isak llega por el vórtice con Sync Rate y energía llenos; Eco (atenuado) habla con líneas importantes (`data/game_over.json`: la primera vez, tres líneas; las siguientes, una; variantes con copia, copia sin nada que desechar y sin copia). La papelera (columna 10 del dock: dormida hasta que hace falta, parpadea y se tambalea con contenido, se vacía al recuperar y queda vacía) se recupera **acercándose** (1,5 tiles, sin botón ni pulso).
- **Mientras la papelera tiene contenido:** las carpetas no se abren y avisan «Recupera tus archivos de la papelera»; **Notas no guarda** («Primero recupera tus archivos de la papelera»; guardar sobrescribiría la copia buena); `QuitGuard` sale sin aviso y sin escribir; la tecla R no vuelve a un nivel. Tras recuperar, el estado es el de la copia: sin cambios pendientes (salvo un apodo cambiado después de guardar, que nunca se pierde).
- **Confirmación al entrar a una carpeta:** se mantiene el título «¿Seguro? Aún no has guardado.» y se añade «Si caes sin guardar, Eco te devolverá a tu última copia.».
- **Guardado:** sigue en v3; no hizo falta subir la versión. «Primera vez» se apunta con `"papelera"` en `allies_met`. La vida extra (secreto D, paso 14) no está: queda el hueco `GameState.add_max_life()`.
- **Desviaciones:** Eco habla en el hub al llegar (no antes de la transición, como decía §5.2): así sale siempre, la primera vez más larga; la transición es el fundido de siempre (sin shader de glitch todavía). El HUD de vidas usa 12x16 px dentro de un cuadro de 16x16 (el validador exige múltiplos de 8).

## Vida extra y pared con glitch del secreto D (2026-10-16)

Implementado el paso 14 de `docs/propuesta-asistentes-y-vidas.md` §10 (detalle en su «Estado»). Reglas aprobadas por el usuario:

- **La pared con glitch del 1-1 (secreto D, columna 298) solo se abre con el Debug.** Con el Debug activo e Isak a menos de 3 tiles se disuelve (parpadeo con líneas cian, ajustable) y deja de ser sólida hasta que se recarga el nivel. Sin Debug es sólida y su ayuda con Q («Eso es un error de visualización. Ignóralo, por favor.») no cambia. Es la interacción mínima: el Debug no cambia.
- **La vida extra aparece en la propia celda de la pared** (columna 298, fila 9): detrás solo queda el borde del mapa.
- **Recogerla** sube `lives_max` para siempre (3 → 4) y suma una vida al intento en curso; se registra en `found_secrets` con un id estable por mapa («1-1» / «D»). Se coge una sola vez por mapa y, si ya está encontrada, no vuelve a aparecer.
- **Como todo lo obtenido**, si no se guarda antes de un game over se pierde con el rollback: `lives_max` vuelve al de la copia y la vida extra vuelve a estar en el mapa.
- **Una vida extra cada N mapas, N = 3 (ajustable jugando).** N no está en el código: se decide al colocar `extra_life_pickup` en cada nivel; el esquema solo impide más de una por mapa.
- **En el 1-1 actual no se puede coger:** el Debug llega al final del 1-2, que aún no existe. El validador la trata como «alcanzable con Debug» y no obligatoria; el bot no la recoge (duración sin cambio).
- **Texto de la ayuda** (`extra_life`, pestaña Objetos del álbum): «Una vida extra: sube tu máximo de vidas. Guárdala: si caes sin guardar, la pierdes.» Sustituye al de la propuesta («Una vida de repuesto…»).
- **Reemplazado:** la recompensa anterior del secreto D en `docs/propuesta-1-1-ampliado.md` (1 power bank y la mejora «Debug eficiente»). **Duda para el usuario:** ¿la mejora «Debug eficiente» se desbloquea en otro secreto?

## Menú de pausa y ajuste de ayudas (2026-10-16)

Implementado el paso 13 de `docs/propuesta-asistentes-y-vidas.md` §10 (detalle en su «Estado») y la pregunta 9 de `docs/propuesta-hub-y-guardado.md`. Decisiones del equipo al implementarlo (ajustables):

- **Acción `pause`:** Esc / Start (ya estaba en el Input Map, sin choques). Abre el menú en los niveles y en el hub; lo cierran `pause` y «Reanudar». En el hub también lo abre un clic en el icono de ajustes (engranaje) de la esquina del HUD, delante del Modo Avión.
- **Opciones:** «Reanudar», «Ajustes» («Ayudas de Eco: Mostrar / Ocultar», por defecto Mostrar) y «Cerrar el juego» (con el aviso de siempre si hay cambios sin guardar). Los textos no dicen vuelta ni Easy/Normal/Hard.
- **Cuándo no se abre:** con el juego ya en pausa (líneas importantes de Eco, ayuda con Q, entrada del apodo, presentaciones del hub, aviso al salir), durante fundidos, muerte y game over, con Isak en un vórtice, con un panel del hub abierto y mientras el cuadro de Eco muestra una línea normal (corre en tiempo real: abrir el menú encima la dejaría avanzar). El menú nunca quita una pausa que no puso.
- **Ocultar las ayudas:** no sale ninguna Q y pedir ayuda no hace nada, así que no se aprende ningún tipo sin pedirlo. El álbum conserva lo aprendido y la historia de Eco no cambia.
- **Mando en los menús:** `ui_accept` y `ui_cancel` añaden los botones A y B (antes solo teclado). Afecta también al aviso al salir (A acepta) y a la entrada del apodo (A acepta, B deja el actual, como ya decía su documentación).
- **Desviación:** el icono de ajustes va en el HUD y no como objeto de la sala en (18-19, 7).

Dudas para el usuario:

- ~~**¿«Salir al hub» en el menú de pausa de los niveles?**~~ **Resuelta (2026-10-16, usuario):** sí, solo en un nivel ya completado en la partida actual, con confirmación. Ver «Menú de pausa: Salir al hub, ajustes, pantalla y controles», abajo.
- ~~**¿Qué más ajustes van al menú?**~~ **Resuelta (2026-10-16, usuario):** los dos ajustes de accesibilidad, más Pantalla (resolución) y Controles. Ver abajo.
- ~~**¿Esc en la página Ajustes** debe volver a la página principal?~~ **Resuelta (2026-10-16, usuario):** sí, Esc / Start vuelven una página atrás; en la principal reanudan.

## Eco lleva la Q y álbum por carpetas (2026-10-16)

Decisiones del usuario tras probar el juego (detalle en `docs/propuesta-asistentes-y-vidas.md` §3.1 y §3.5):

- **Eco lleva la Q:** con un objeto con ayuda en rango, Eco vuela junto a él (encima, por el lado contrario a Isak, sin taparlo ni a Isak), brilla en dorado (el ámbar de `mundo1.gpl`) y la Q se dibuja sobre Eco y lo sigue. Al pedir la ayuda conserva el brillo durante la pausa; al cerrarla, o si el jugador se aleja, vuelve a Isak con su color. Con «Ocultar» ni se acerca ni brilla. `HelpSystem` sigue eligiendo el objeto.
- **Álbum por carpetas de mundo:** Mundo 1 a Mundo 6; cada tipo de `data/help.json` lleva su `world`. Las carpetas de mundos no alcanzados salen cerradas, con candado y «???».
- **Sin «Olvidar ayudas»:** se retira del álbum (y `GameState.forget_help`).

Decisiones del equipo al implementarlo (ajustables jugando):

- **Regla de mundo visitado** (carpeta abierta): el mundo está en `worlds` de `data/hub.json` y `HubWorlds` lo da por desbloqueado (`unlocked`, o algún subnivel en `unlocked_levels` / `completed_levels`), o hay algún tipo de ese mundo aprendido. Hoy el Mundo 1 siempre lo está (`unlocked: true`); los Mundos 4-6 aún no están en `worlds`, así que salen cerrados.
- **Contador global** de la vista de carpetas: solo cuenta los tipos de los mundos visitados (no adelanta cuántos tienen los demás).
- **Durante el menú de pausa** Eco suelta el objeto y vuelve a Isak (en pausa no hay Q); al reanudar vuelve a señalarlo.
- **Las carpetas cerradas** muestran «Mundo n» (el número, no el nombre).

~~Pendiente de aclarar por el usuario: «ver la información de un objeto ya aprendido al acercarte de nuevo»~~ **Resuelta (2026-10-16, usuario):** relectura con una Q apagada; ver la sección siguiente.

## Menú de pausa: Salir al hub, ajustes, pantalla, controles y relectura (2026-10-16)

Decisiones del usuario tras probar el 1-1 (implementadas):

- **Relectura de ayudas:** además del álbum, cerca de un objeto de un tipo **ya aprendido** sale una **Q pequeña y apagada sobre el objeto** (no sobre Eco: Eco no vuela ni brilla, eso es solo del primer encuentro), solo si Isak está **quieto 0,8 s** (`reread.still_s` de `data/help.json`; **0,5 s** desde la corrección del 2026-10-16, abajo) dentro del radio del tipo; desaparece al moverse. Pulsarla abre la misma explicación (misma pausa, mismo cuadro de Eco) sin volver a aprender nada. Una sola (la del más cercano) y solo si no hay ningún candidato sin aprender en rango (la Q normal va primero). Respeta «Ayudas de Eco: Ocultar» y no sale en un vórtice, muerto, de espaldas ni en pausa. Se dibuja en la capa de la Q.
- **«Salir al hub»:** en el menú de pausa de un nivel **solo si ese nivel ya está completado** en la partida actual. Confirmación «¿Salir al hub? Perderás este intento.» (Salir / Volver). Vuelve al hub con la llegada normal (vórtice, energía y Sync Rate llenos). No aparece en el hub ni en niveles no completados.
- **Esc / Start / B en Ajustes y subpáginas** vuelven una página atrás; en la principal, reanudan.
- **Ajustes de accesibilidad** al menú, guardados en `settings.cfg` y aplicados al momento.
- **Pantalla:** modo Ventana / Pantalla completa y tamaño de ventana.
- **Controles:** reasignar teclado y mando, con conflictos (intercambiar o cancelar) y «Restablecer valores».

Decisiones del equipo al implementarlo (ajustables):

- **Qué se pierde al salir al hub:** lo mismo que al reiniciar con R: la posición, el punto de sincronización, el estado de enemigos y objetos del mapa. Lo **recogido en el intento** (puntos de atención, objetos, habilidades) **se queda en memoria**, igual que con R (R no lo devuelve), y se guarda con la siguiente copia en Notas; si se cierra sin guardar, se pierde como siempre. Salir no gasta vidas, no provoca game over, no escribe el guardado ni marca «sin guardar» por sí mismo. La confirmación empieza en «Volver».
- **Textos de accesibilidad** (sin la palabra «Normal», que es el nombre de una dificultad): «Reducir efectos de Sync bajo: Sí / No» (hoy solo hace que la señal y el porcentaje del HUD se queden en rojo sin parpadear; el ruido de pantalla aún no existe) y «Contorno del Debug de alto contraste: Sí / No» (plataformas ocultas con un contorno más claro y grueso). Por defecto, No.
- **Pantalla:** presets 1280x720, 1600x900, 1920x1080, 2560x1440 y 3840x2160 (`data/settings.json`); solo se ofrecen los que caben en el monitor (1280x720 siempre). El juego se dibuja a 1280x720 con **escala entera**: con 1600x900 y 1920x1080 se ve a x1 con **bordes negros**; con 2560x1440 a x2 sin bordes; en pantalla completa, el mayor factor entero que cabe y bordes si sobra (p. ej. 1920x1080: x1 con bordes; 2560x1600: x2 con bordes arriba y abajo). El detalle del menú lo dice («Píxeles a x1, con bordes negros.»). Por defecto, ventana de 1280x720 (no se toca la ventana al arrancar). Nunca se aplica en GUT, scripts `-s` ni `--headless`.
- **Controles:** acciones reasignables: mover izquierda / derecha, saltar, correr, pulso, láser, Debug, ayuda de Eco y pausa (no `restart_level`, las teclas de depuración ni las `ui_*`). Cada fila muestra la tecla principal y el botón o eje de mando principal; reasignar sustituye esa entrada y **conserva las demás** (flechas, cruceta). Una sola captura para los dos dispositivos: la primera tecla, botón o eje que se pulse. **Esc y Start** cancelan la captura y están **reservados**: siempre abren la pausa aunque se reasigne su fila y no se pueden dar a otra acción; R / Select, F9 y F1-F4 tampoco. Conflicto con otra acción reasignable: «Intercambiar» (la otra recibe la entrada anterior) o «Cancelar» (empieza en Cancelar); nunca queda una acción sin entrada de su dispositivo. Los menús siguen navegándose con las `ui_*` (Intro, Esc, flechas, A, B, cruceta), que no se reasignan. Nombres en español con glifos de la fuente (si faltara uno, «Tecla <código>»). Guardado como eventos serializados (tecla física, botón o eje) solo para las acciones que cambian; un `settings.cfg` con entradas inválidas o repetidas vuelve a los valores de `project.godot`.
- **Q apagada:** escala x1 (la normal es x2), sin bote, placa `noche_profunda`, borde `tile_luz` y glifo `resplandor` de `mundo1.gpl` (validador `tools/validate_help_prompt.py`).

Dudas para el usuario:

- **¿La Q apagada a x1 se lee bien?** Es la mitad que la normal (glifo de 12 px de arte a x1, junto al arte a x2). Si se prefiere, puede ir a x2 con los mismos colores apagados.
- **¿Pantalla completa sin bordes** aunque deforme o recorte un poco (escala no entera)? Hoy, con escala entera, en un monitor de 1920x1080 el juego se ve a 1280x720 con bordes negros.

## Fallos encontrados jugando el 1-1 (2026-10-16, corregidos)

Reglas nuevas (decisiones del usuario al informar de los fallos):

- **Lo destruido no ayuda.** Antes de tener el láser, tras cerrar un pop-up, Eco seguía junto a él con la Q. Causa: `HelpSystem` solo miraba si el nodo era visible y el pop-up cerrado oculta su ventana, no el nodo. Ahora ni la Q, ni la relectura, ni Eco van a un objeto destruido, reventado, recogido, oculto, liberado o ya inerte (`HelpCatalog.is_help_live` y `is_help_available()` de cada tipo): pop-up cerrándose o cerrado, Burbuja reventada, receptor activado, puente extendiéndose o extendido, pared con glitch disuelta, terminal activada, recogidas tomadas, vida extra tapada o recogida y cargador de un solo uso gastado. Si deja de ayudar mientras es el candidato, la Q desaparece y Eco vuelve a Isak. Siguen ayudando (su texto sigue siendo cierto): la Burbuja aturdida (sirve de escalón), el cargador reutilizable en espera y el punto de sincronización ya tocado.
- **Objetos de historia de un solo uso no se repiten con la habilidad ya obtenida.** Al volver al 1-1 desde el hub con el láser guardado, el chip ya no aparecía pero la línea `eco_laser` del túnel salía otra vez. Ahora el `ability_pickup` con la habilidad obtenida (o desbloqueada) no aparece (sin dibujo, colisión, Q ni aviso) y su línea de historia tampoco (`unless_ability` de `eco_line`; en el 1-1, `eco_laser` con `laser`): Isak pasa de largo. Es comportamiento de ejecución: el validador sigue tratando el chip como obligatorio en el diseño y una partida nueva lo recoge. Tras un game over sin el láser en la copia (rollback) vuelven chip y línea. Revisado el resto del 1-1: el encuentro con Eco ya no se repetía, los avisos de control van por `seen_notices`, los puntos de atención, el power bank y la vida extra no reaparecen y los cargadores del 1-1 son reutilizables.
- **Nombres de los mundos.** Las carpetas del álbum usan los nombres del diseño (`docs/INDEX.md`, `docs/mundo-N-*.md`): 1 Notificaciones, 2 El Feed, 3 La Vitrina, 4 El Chat, 5 La Tienda, 6 La Nube, todos en `worlds` de `data/hub.json` (los 4-6 sin carpeta en el hub). El título de la carpeta abierta usa el mismo formato que el panel de subniveles, «Mundo 1 - Notificaciones» (`folders.texts.title`, `HubWorlds.world_title`; una sola fuente). En la tarjeta de la carpeta, por ancho, van en dos líneas («Mundo 1» y «Notificaciones»). Los mundos no alcanzados siguen cerrados con candado y «???» sin filtrar el nombre; al alcanzarse muestran el suyo.
- **Relectura (Q apagada) fiable.** A veces no salía y costaba que reapareciera. Causas: el tiempo quieto se medía con la `velocity` pedida (vector, umbral 4 px/s) y volvía a 0 en cualquier cuadro por encima; contra un escalón del 1-1 (p. ej. la columna 71) la `velocity` se queda en 30 px/s aunque Isak no avanza, y el tiempo se reiniciaba cada cuadro; además, objetos sin aprender ya inertes (un pop-up cerrado, un receptor activado) contaban como candidatos y la tapaban. Regla nueva (`reread` de `data/help.json`): quieto = en el suelo y |velocidad horizontal real| < `still_speed_px_s` (**8**, antes 4 sobre el vector pedido); el tiempo solo vuelve a 0 al moverse de verdad (|velocidad real| > `move_speed_px_s`, **40**); entre los dos umbrales ni cuenta ni se reinicia (histéresis: frenar, aterrizar, pequeñas oscilaciones). Espera `still_s` **0,5 s** (antes 0,8). Tras leerla se rearma sola con otro rato quieto, sin salir del rango; el candidato es el tipo aprendido más cercano en rango y un tipo sin aprender fuera de rango no la bloquea.


## Arranque con partida guardada (2026-10-16, corregido)

Al abrir el juego con una partida guardada se caía en el 1-1. Regla del usuario: **con partida guardada se arranca en el hub; sin ella, en el 1-1** (encuentro con Eco). Hay partida si al arrancar se cargó `save.json` o su `.bak` (principal corrupto); un archivo inexistente, vacío o de versión desconocida empieza de cero. No se exigen niveles completados (solo se guarda en el hub). Regla elegida para la tecla R al arrancar en el hub sin nivel jugado en la sesión: el subnivel más avanzado al que se puede entrar en la vuelta actual, o el 1-1. F9 lleva siempre a una partida nueva en el 1-1. Opciones de arranque: `start_level_id` (`"1-1"` / `"hub"`) en pruebas y herramientas, y `-- --start-level=<id|hub>` en builds de depuración.

## Propuesta del 1-2 «Centro de notificaciones» (2026-10-16)

Diseño completo en `docs/propuesta-1-2.md`. **APROBADA el 2026-10-16** con todas sus recomendaciones (ver «Aprobación del 1-2», abajo); pasos 1-10 de su §10 implementados el 2026-10-16 (ver «Aprobación del 1-2»).

**Decisiones del usuario (2026-10-16):**

- El 1-2 es una **torre vertical**: Isak sube 4 pisos = pestañas (Mensajes, Correo, Recordatorios, Actualizaciones). Dificultad 2 de 5 «subida un poco» (más combinación y gestión de energía, no más castigo); unos 5 min.
- El jugador **combina pulso y láser** para avanzar, en este nivel y en los siguientes; el diseño deja preparado añadir el **Debug** a esas combinaciones (`propuesta-1-2.md` §0, «lenguaje de combinaciones»: aturdir y rematar, desbloquear a distancia y activar de cerca, Posponer, quitar la protección y cerrar, carrera contra amenaza; cuatro ideas con Debug marcadas como futuras).
- El **Debug se obtiene en el piso 2 (Correo)** resolviendo un acertijo de pulso + láser y es obligatorio para seguir en ese piso (falta una plataforma que solo se ve con él). **Cambia V9** (proponía desbloquearlo al empezar el 1-2) y precisa las menciones a «el Debug llega al final del 1-2» de otros documentos: lo que llega al final del 1-2 es **Calc**, tras obtener el Debug.
- Los **recordatorios** tienen un botón **«Posponer»**: el láser lo golpea a distancia para alargar el temporizador mientras el pulso resuelve otra cosa cerca.
- Elementos nuevos de §6.2 en el 1-2: punto rojo, banner, recordatorio y pop-up translúcido; cada uno con ayuda Q, ficha del álbum, arte por script (sin AutoSprite salvo permiso), datos JSON y validación.

**Desvíos y precisiones de la propuesta (aprobados el 2026-10-16):** el punto rojo despierto no recibe daño del láser; objetos nuevos del láser (lector, receptor enlazado con ventana, anuncio sobre un pop-up); el chip del Debug llena la energía; mapa de 28 × 62 tiles; puntos de sincronización al entrar a los pisos 2 y 4; dos cargadores (el del acertijo con 10 s de enfriamiento); 9 puntos de atención (6 + 3) y un power bank vacío en el secreto C; **sin vida extra en el 1-2** (N = 3: la siguiente iría en el 2-1, ajustable); el secreto D del 1-1 ya se puede abrir con el Debug, sin línea automática de Eco. El validador debe aceptar niveles donde el láser y el Debug son obligatorios (hoy exige la meta sin láser y un camino sin Debug).

**Dudas** (detalle en `propuesta-1-2.md` §11; **resueltas el 2026-10-16**: todas con su recomendación, ver «Aprobación del 1-2»):

1. ¿Temporizadores en tiempo del mundo (el Debug los ralentiza)? *Recomendación:* sí.
2. ¿Punto rojo despierto inmune al láser? *Recomendación:* sí.
3. ¿El chip del Debug llena la energía? *Recomendación:* sí.
4. Encuentro con Calc: opción A (Calc colgada en la azotea, se enciende con el pulso), B (tras una pared con glitch) o C (en el hub). *Recomendación:* A; los textos los decide el usuario.
5. Recuerdo coleccionable de la carpeta de Spam: qué es, qué recuerdo de Isak y dónde se ve. *Recomendación:* pestaña «Recuerdos» del álbum de Notas (lista `memories` en el guardado), sin efecto en el juego (V16); el contenido lo decide el usuario.
6. ¿Power bank vacío en el secreto C? *Recomendación:* sí.
7. ¿Ancho de 28 tiles o de 20? *Recomendación:* 28.
8. ¿Puntos de sincronización al entrar a los pisos 2 y 4? *Recomendación:* sí.
9. ¿Espera del piso 4 de 20 s con tres oleadas? *Recomendación:* sí, 15 s si aburre.
10. ¿Recordar el secreto D del 1-1? *Recomendación:* sin línea automática; basta la Q y la ficha.

**Aprobación del 1-2 (2026-10-16, decisiones del usuario):**

- **Calc: opción A.** Apagada en la azotea junto a la terminal (arte `powered_off`, Q `calc_off`); el pulso la enciende y se va con Isak. Textos de Calc: por decidir.
- **Recuerdos:** pestaña «Recuerdos» en el álbum de Notas (`memories` en el guardado), sin efecto en el juego. **Contenido: correos y mensajes de texto recibidos de familiares y amigos** (el Mundo 1 es el de las notificaciones). El texto de cada recuerdo es historia: **por decidir**.
- **El punto rojo despierto es inmune al láser**: hay que aturdirlo con el pulso antes de rematarlo.
- **Temporizadores en tiempo del mundo**: el Debug los ralentiza.
- **El chip del Debug llena la energía** al recogerlo.
- Se confirman el acertijo «Correo certificado» del piso 2 (pulso + láser), la dificultad 2 de 5 «un poco más», **sin vida extra en el 1-2** y las recomendaciones de las preguntas 6-10 (power bank vacío en el secreto C, 28 tiles de ancho, puntos de sincronización en los pisos 2 y 4, espera de 20 s, sin línea automática para el secreto D).
- **Hecho (pasos 1 y 2 de §10):** esquema y constructor verticales (tramos con `y_from`/`y_to`, `camera.vertical: "tower"`, `patterns`), cámara de torre (`data/camera_tower.json`: ancla al suelo, zona muerta, encaje en el piso, sin seguir cada salto), fondo con desplazamiento en Y (mismas capas, sin arte nuevo; se ve la costura al repetirse en vertical) y nivel de prueba `tower_test` (28 × 40). El 1-1 y su cámara no cambian.
- **Hechos los pasos 3 y 9 (2026-10-16):** lector láser, receptor enlazado y anuncio, y la obtención del Debug (chip que llena la energía, línea de historia de Eco y aviso de control), con la sala de prueba `correo_test` (detalle en `propuesta-1-2.md` §10). Decisiones de implementación (ajustables): un segundo disparo al lector con corriente **vuelve a llenar la ventana**; con su receptor ya activado el lector queda hecho (sin Q); disparar **pegado** al lector o al anuncio cuenta (el celular queda dentro de la pared o del objetivo); el chip del Debug tiene **ayuda Q propia** (`debug_chip`, aunque §7 decía que no hacía falta). **Por decidir:** el texto de la línea de historia de Eco del Debug (propuesta: «Una herramienta de diagnóstico, {apodo}. Te deja ver los errores del sistema… y gasta la misma energía que el láser.»).
- **Hechos los pasos 4 y 5 (2026-10-16):** punto rojo (`notification_badge`) y banner (`spam_banner`), con arte por script, ayudas Q, fichas del álbum y la sala de prueba `mensajes_test` (detalle en `propuesta-1-2.md` §10). Decisiones de implementación (ajustables jugando): el punto rojo **solo daña lanzado**, tras un aviso de 9 cuadros en que se infla (la propuesta decía contacto pasivo sin anticipación, como la Burbuja; el encargo pedía anticipación antes de dañar); el láser contra un punto rojo despierto **choca y se consume** (los 10 de energía ya se gastaron al disparar; no gasta más), con chispa gris; derrotado no reaparece y, al reaparecer Isak, los vivos vuelven a su sitio dormidos y con la vida llena; el banner **no es un cuerpo**: el láser lo atraviesa y el pulso no le afecta; sin `link_off`. El tipo se llama `notification_badge` (no `red_dot`), como en la propuesta y su ayuda.
- **Hechos los pasos 6, 7 y 8 (2026-10-16):** recordatorio y botón Posponer, pop-up translúcido y barra del 99 % con oleadas, con arte por script, ayudas Q, fichas del álbum y las salas de prueba `recordatorios_test`, `overlay_test` y `actualizaciones_test` (detalle en `propuesta-1-2.md` §10). Decisiones de implementación (ajustables jugando): el Posponer usa **`extend_s`** (la propuesta decía `add_s`) y enlaza **grupos** de recordatorios (`targets`, validados por el esquema); su **tope** es la cuenta que queda (`cap_s`: nunca pasa de 8 s) y tiene **enfriamiento** (`cooldown_s` 1 s; enfriándose, un impacto no hace nada: chispa gris); sin cuenta que posponer (en reposo, caídos o volviendo) también chispa gris y no se enfría; el recordatorio caído **no vuelve dentro de Isak** (espera a que se aparte) y su tarjeta y colisión ocupan los 32 px de arriba de la celda; el pop-up translúcido tiene **botón de 24 px** de color cian (lo interactivo; no el rojo del pop-up del 1-1: el rojo queda para el daño) y admite el anuncio encima como el pop-up bloqueante; en la barra del 99 % los enemigos **caen en paquetes** que no hacen daño (el aviso es una flecha roja en el techo y una sombra en el suelo), los que quedan al 100 % se apagan **sin drops**, y si Isak reaparece antes de abrirla **vuelve al principio** (97 %, sin enemigos); la condición de salida es la del documento (sobrevivir la espera de `wait_s`). El validador de alcanzabilidad trata por ahora los recordatorios como tablas fijas y la barra como abierta (paso 10).
- **Hecho el paso 10 (2026-10-16):** validador con láser, Debug, energía, temporizadores y torre, y exportación del camino para el bot vertical (detalle y límites en `propuesta-1-2.md` §10). Decisiones de implementación (ajustables): margen de tiempo por defecto **1,5 s** (`validation.time_margin_s` del nivel o `--time-margin`) en la ventana del lector y al salir de un grupo de recordatorios; encima de un recordatorio basta con que siga ahí (el mínimo se informa y, si el disparo al Posponer llega dentro de su aviso, sale un aviso); tolerancia de techo con salida desde parado + **8 px**; parámetros del diseño en un bloque nuevo `validation` del nivel (esquema: `time_margin_s`, `snooze_required`, `laser_required`, `debug_required`, `start_energy`, `sync_damage_budget`); los puntos rojos se esquivan **aturdiéndolos con el pulso** (el plan no los mata) y el presupuesto de Sync por defecto es 0; las oleadas de la barra no se modelan. **Sala `recordatorios_test` cambiada:** su foso tenía una repisa de una vía a la derecha que dejaba llegar a la meta sin cruzar el grupo del Posponer; ahora un túnel bajo la entrada lleva al foso de los sueltos y su repisa devuelve al inicio (el Posponer es obligatorio, como pide la sala); su prueba GUT no cambia.
- **Hecho el paso 13 (2026-10-16):** el 1-2 real, jugable desde la carpeta del Mundo 1 tras completar el 1-1, con la fachada de la torre (detalle tramo a tramo y desvíos en `propuesta-1-2.md` §10). Decisiones de implementación (ajustables jugando): bandas reajustadas (azotea 0-6, piso 4 7-17, piso 3 18-31) para que quepan tres niveles de recordatorios; hueco del piso 3 a la derecha (`sync_2` en la columna 23, no en la 4); Posponer del 3b **detrás** de Isak (hay que girarse) y grupos de 2,3 s y 2,4 s; secreto C con un grupo de 1 s que desde su entrada necesita dos Posponer (cayendo desde 3b sobre su mitad derecha basta uno); secreto B alcanzable también con un salto de 2 tiles (el validador no modela el punto rojo aturdido como escalón); las capas lejanas del fondo quedan fijas en Y en la torre y la fachada se mueve con el nivel. **Pendiente de jugar:** ritmo y tiempos de los recordatorios, posición de los puntos rojos del rellano y legibilidad de la fachada detrás del juego.
- **Hecho el paso 15 (2026-10-18):** bot vertical (`tools/tower_bot.gd`, lanzador `tools/play_tower_bot.gd`; resultados y hallazgos en `propuesta-1-2.md` §10). Decisiones de implementación (ajustables): el bot exporta él mismo el camino con el validador (o lo lee con `--path`); el estado de partida es el de un jugador que acaba de completar el 1-1 (Eco, Notas, pulso y láser; sin Debug), y con Calc conocida igual más Calc (el chip del Debug sigue en el camino exportado); se aparta del camino donde la física real lo pide (frena hacia la celda de llegada en vez de soltar en el borde, se coloca donde el pulso alcanza de verdad, no espera a los puntos rojos sino que los aturde cuando se inflan y remata con el láser los aturdidos, cruza corriendo los pasillos largos de banner); tolerancia de duración frente al camino ±25 s; prueba GUT siempre activa (~1 min de pared los dos casos). Sin cambios en el nivel: nada resultó imposible.
- **Pregunta abierta (hallazgo del bot, 2026-10-18): pasillo de `banner_2` (piso 4, fila 20).** El camino lo recorre andando (16 tiles, 4,7 s, tras esperar la fase 1,63 s del ciclo de 3 s) y el validador lo da por seguro, pero con la física real el barrido siguiente alcanza a Isak hacia la columna 8 (−10 de Sync medido). Corriendo (2,9 s) o saltando el banner no hay golpe; el bot corre. Opciones: corregir el modelo de banners del validador (*recomendación*: para que el camino exportado ya diga «corriendo» o espere en un sitio seguro), acortar el pasillo o dejarlo como reto. Sin decidir no se toca el nivel. **Decidido el 2026-10-19 (usuario):** corregir el modelo del validador (hecho: la búsqueda por fase anda a `walk_speed` y no acumula redondeos; el camino ya no anda el pasillo de una vez, salta el banner) y refugio a medio pasillo (ya existía: repisa 13-14 de la fila 19 con el techo abierto 12-15, como los nichos de `banner_1`; no se añadió otro).
- **Pendiente:** del paso 14, el recuerdo; de los pasos 11-12, la ayuda `hidden_platform`.

## Propuesta del sistema de mejoras de Calc (2026-10-16)

Diseño completo en `docs/propuesta-mejoras.md` (revisada en parte el 2026-10-16: ver «Decisiones del usuario», abajo; solo documentación).

**Idea del usuario (aprobada en líneas generales):** cinco mejoras únicas en la tienda de Calc, una por acción (Pulso, Láser, Debug, Sync Rate y Energía), cada una con su chip y **5 niveles** (la 1.ª barra llena de inicio, las otras 4 se compran). El Debug solo sale tras obtenerlo; mientras, su chip es «?». Pulso: 2 alcance, 3 aturdimiento, 4 **Ocultarte**.

**Decisiones del orquestador recogidas:** economía «opción 2» (todo alcanzable en las tres vueltas; puntos solo con el rollback); tope por acceso Caché 3 / Kernel 4 / Raíz 5 (aprobado por silencio; responde a la duda «mejoras por vuelta» de «Decisiones del 2026-10-15: tres vueltas, hub y guardado»); Ocultarte consume Sync Rate y energía y se apaga al 10 %; Energía 5 = recarga pasiva sin subir la capacidad; tope de power banks a decidir en la propuesta.

**Valores propuestos:** ~~costes 10 / 15 / 15 / 20 + 1 power bank por nivel; total 320 puntos + 5 power banks~~ [Reemplazado el 2026-10-16 por la decisión 5, abajo]. Debug 2 = 15, el antiguo «Debug eficiente», que deja de estar huérfano: ya no necesita secreto. Tope de **3 power banks** (completos + vacíos), 200 de capacidad, sin venta en Calc. Energía 2-4 = 110 / 120 / 130 y 5 = recarga del 0,5 % del máximo por segundo (el 0,005 %/s del borrador tardaría 33 min en dar un disparo). Ocultarte: acción nueva `hide` (H / L3), 5 de energía/s y 1,5 de Sync/s, se apaga al 10 % de cualquiera de las dos, atacar o recibir daño lo apaga, no combina con el Debug. Se retira «Recarga mejorada»; guardado v4 con `upgrade_levels` y migración con devoluciones.

**Choques con decisiones anteriores:** (1) la regeneración pasiva de Sync (nivel 5, hasta el 60 % fuera de combate) y de Energía (nivel 5) cambia «no hay regeneración pasiva ni curación» de «Notas del paso 9», solo con esas mejoras (**aprobado el 2026-10-16**, decisión 1); (2) y (3), pendientes de aprobación: (2) el Debug 3 «más alcance de revelado» no tiene base hoy (el Debug revela toda la pantalla): se propone «revelado persistente» de 1,5 s; (3) Batería ampliada (150) y Sync reforzado (120) pasan a subir de 10 en 10 hasta 130.

**Decisiones del usuario (2026-10-16):**

1. **Regeneración pasiva** en Sync Rate 5 y Energía 5, solo con esas mejoras: **APROBADO**.
2. **Corte del Ocultarte:** se apaga cuando el Sync **o** la energía llegan al 10 %, el primero que llegue: **APROBADO**.
3. **Ocultarte y Debug no se combinan** (activar uno apaga el otro): **APROBADO**.
4. **Calc no vende power banks:** vienen de los mapas (tope de 3 a la vez) y se gastan al comprar el nivel 5: **APROBADO**.
5. **Costes:** cada una de las 5 mejoras cuesta **90 puntos en total** (sus 4 compras, niveles 2-5): **450** entre todas, «para que los jugadores tengan que buscar». Sustituye a la tabla de 320. Se mantienen el nivel 1 gratis, el power bank del nivel 5 y el tope Caché 3 / Kernel 4 / Raíz 5. Reparto propuesto (`propuesta-mejoras.md` §3.2): 15 / 20 / 30 / 25 + 1 PB y Pulso 25 / 15 / 25 / 25 + 1 PB (Caché abre 180, Kernel 145, Raíz 125). Comprarlo todo pide ≈ 93 % de los 486 puntos de las tres vueltas (≈ 78 % de los secretos con toda la ruta): exigente a propósito.

**Dudas abiertas** (detalle y recomendación en `propuesta-mejoras.md` §11):

1. ¿Debug 3 = revelado persistente o radio nuevo? *Recomendación:* persistente.
2. ¿Pulso 5 «Pulso de retorno» (+4 de energía al aturdir, una vez por enemigo e intento)? *Recomendación:* sí.
3. ¿Confirmación al comprar? *Recomendación:* sí.
4. ¿Tecla del Ocultarte H / L3? *Recomendación:* sí, reasignable.
5. ¿Atacar revela? *Recomendación:* sí.
6. ¿Reparto de los 90 por nivel: 15 / 20 / 30 / 25 + 1 PB o 15 / 20 / 25 / 30? *Recomendación:* 15 / 20 / 30 / 25 (con 15 / 20 / 25 / 30 sobrarían hasta 24 puntos sin nada que comprar al terminar Kernel).
7. ¿Pulso 2 (Pulso amplio) sigue en 25 o baja a 15? *Recomendación:* 25 (las comprobaciones de economía del 1-1 en `tests/test_level_schema.py` no cambian; con 15 fallarían dos y habría que devolver 10 puntos en la migración).

**Aprobación (decisión del usuario, 2026-10-17):** se aprueba `propuesta-mejoras.md` con **todas sus recomendaciones** (Debug 3 = revelado persistente; Pulso de retorno; H / L3 para el Ocultarte; atacar revela; reparto 15 / 20 / 30 / 25 + 1 PB y Pulso 25 / 15 / 25 / 25; Pulso amplio sigue en 25) y con **90 puntos por pista**. Cambia la recomendación 3: **sin confirmación al comprar** (el pulso compra el siguiente nivel). La tienda muestra cada pista como una fila con su chip y 5 recuadros (el primero cargado); con el selector sobre una fila, el detalle dice el nombre y la descripción del siguiente nivel y su coste; los recuadros por encima del tope salen con candado y «Requiere acceso Kernel / Raíz». **Tanda M1 hecha el mismo día** (catálogo, compras, guardado v4 con migración, efectos simples, arte y tienda; detalle en `propuesta-mejoras.md`, «Tanda M1»); los efectos complejos son la tanda M2.

## Ajuste del 1-2 tras probarlo: techos y contraste del fondo (2026-10-17)

**Qué contó el usuario:** en algunos tramos del 1-2 cuesta mucho saltar porque Isak se da con la cabeza en el borde de la losa, y la fachada de la torre hace que se pierdan las plataformas. Le gustó el mapa completo: se ajustó lo mínimo (detalle y números en `propuesta-1-2.md` §10, «Ajustes tras la prueba»).

**Techos (hecho):** `tests/test_level_climbs.gd` mide con el Isak real (física del juego a 60 Hz) cada subida que acepta el validador (`tools/level_climbs.py` → `tests/fixtures/climbs_1-2.json`): andando y corriendo, desde la x de despegue, llegando con dos tiles de carrera y con coyote. Fallaban 11 subidas: los nichos de 2a y 4a, la escalera de la sala del acertijo bajo el forjado del piso 3 (y el salto a la oculta de 2c y la salida del pozo del secreto A) con 8 px de choque (les faltaban 24 px para tener 16 de holgura), y la entrada al piso 3 y el inicio del secreto C con 72 px de choque (faltaban 88). Arreglo: celdas de forjado que pasan a ser de una vía (dan altura por encima de la cabeza; ninguna se alcanza desde abajo porque harían falta 192 px de salto y Isak sube 184) y tres repisas movidas un tile; el validador acepta ahora solo subidas con 16 px de holgura (`validation.ceiling_margin_px`).

**Duda nueva (decide el usuario):** esas celdas de una vía dentro de los forjados se ven como «huecos» por los que no se puede subir (desde la repisa de debajo faltan 8 px). ¿Se dejan así, se dibujan con otro tile (p. ej. una rejilla de ventilación sin borde claro) o prefieres que esos tramos ganen una fila de altura (más cambios en el mapa)? *Recomendación:* un tile propio «rejilla» en una ronda de arte, sin tocar la colisión.

**Duda abierta: saltos en los pasillos de 3 tiles (2a y 4a).** No son subidas y no se tocaron: en un pasillo de 3 tiles de alto un salto en el sitio (p. ej. para pasar por encima del banner) sigue dándose con el techo (sube 112 de sus 184 px; el banner mide 64, así que se salta igual). El texto del diseño («el salto da 2,8 tiles y hay 3 libres») no contaba la cabeza. ¿Lo dejamos (el techo bajo es parte de la presión del banner) o subimos esos pasillos una fila? *Recomendación:* dejarlo y decidirlo jugando.

**Propuesta, sin implementar: corrección de esquina (corner correction).** Muchos juegos de plataformas (Celeste, Hollow Knight…) empujan al personaje unos píxeles hacia un lado cuando, al subir, solo roza con la esquina de la cabeza el borde de un techo, en vez de cortarle el salto.
- *A favor:* acaba con los «cabezazos» injustos de raíz, también en niveles futuros; el jugador no lo nota; con la cápsula de Isak (32 × 80) bastaría un empuje de hasta 8-12 px.
- *En contra:* cambia la física (hay que volver a medir el validador, el bot del 1-1 y las pruebas de salto); puede colar a Isak por huecos que el diseño quería cerrados (el techo bajo del 3a del 1-1, que obliga a usar el pulso); si el empuje es grande se nota como un «teletransporte»; no arregla los techos planos (la falta de altura de verdad), que es lo que más fallaba en el 1-2.
- *Recomendación:* no hacerla por ahora; con la holgura medida en el validador ya no hacen falta. Si se hace, solo en la subida, hasta 8 px y con su prueba GUT.

**Contraste del fondo (hecho, ajustable):** la fachada baja un escalón de la paleta (tarjetas en noche_profunda con contornos en cielo, sin resplandor ni borde_luz) y tiene una tarjeta por columna y periodo; en la torre las capas del fondo llevan un velo hacia noche_profunda (`tower_dim` de `data/world1_background.json`: 0,45; la banda de edificios 0,7; la fachada 0,2); las pestañas no llevan velo. Contraste del borde claro de las plataformas con el fondo de al lado (`tools/measure_tower_contrast.py`, 8 capturas): mediana 4,3:1 → 8,1:1; bordes con mediana ≥ 3:1, 83,5 % → 94,2 % (el resto está bajo un pop-up u otro objeto); percentil 10 ≥ 3:1, 62,9 % → 92,4 %. El 1-1 no cambia. *Pregunta:* ¿el velo te parece bien o lo quieres más suave (0,3) para que la torre se vea más «encendida»?

## Encuentro con Calc en la azotea del 1-2 (2026-10-17)

**Decisión del usuario (2026-10-17):** el encuentro con Calc es un acertijo final en la azotea del 1-2 (sustituye la opción A de `propuesta-1-2.md` §8). Calc al 3 %, terminal sin corriente, Eco descubre la pared con glitch con su guion propio (no es Q), Debug, cuarto a oscuras con interruptor de pulso (Q de Eco, de espaldas), interruptor láser lejano, panel oculto con el Debug, Calc entra, se carga y se teletransporta, la terminal recupera la corriente y Calc se encuentra en el hub. Historia «Resta» aprobada para las líneas de Calc (los puntos de atención son atención de Isak que Eco guardó y dejó caer; Calc la devuelve en mejoras). Detalle en `propuesta-calc-encuentro.md`.

**Aprobado por silencio:** 3 pulsos (`pulses`, luz por tercios); la carga es obligatoria para la terminal; el cuarto es una zona de la azotea. **Decidido en la tanda H1:** el guion de Eco es historia y sale con «Ayudas de Eco: Ocultar» (la Q no; si no sale, Eco señala con una línea); `meet_ally("calc")` al encontrarla en el hub, no al teletransportarse (gancho `EventBus.ally_teleported`).

**Abiertas (con recomendación, `propuesta-calc-encuentro.md` §9):** Calc visible al 3 % desde el principio (sí); dónde va el cuarto en el 1-2 (a la derecha de la terminal, azotea +2-3 filas); el panel oculto queda marcado tras verlo (sí); Eco no comenta cada pulso; la línea «aplicación obsoleta» (mantener); estilo LCD de Calc con los dígitos del HUD.

**Tanda H2 (2026-10-17), decisiones técnicas a revisar jugando:** la pregunta 2 (dónde va el cuarto) se resolvió con la recomendación, pero con **4 filas** y no 2-3: el cuarto con tres alturas de repisas (subidas de 2 tiles) y 16 px de holgura sobre la cabeza necesita el techo 4 filas por encima de la repisa alta. La azotea pasa de 7 a 11 filas (0-10; la torre, de 28 × 62 a 28 × 66) añadiendo filas **encima** y bajando 4 todas las de los pisos con un script (pisos, objetos, economía y puntos de sincronización iguales); la azotea de 11 filas cabe entera en pantalla, así que la cámara de torre no se mueve dentro de ella. Calc va junto a la pared (columna 11) para que su paseo hasta el punto de carga sea más corto (espera total de unos 10,6 s). La terminal pasa a llamarse `terminal_azotea` (los ids del guion de Eco). **Pendiente de decidir:** el tiempo de espaldas de cada pulso al interruptor es `pose_s` 0,45 s (sección `power_switch` del catálogo, de H1), no los 0,3 s que se mencionaron; el validador usa el del catálogo.

**Tanda H3 (2026-10-17), decisiones del usuario aplicadas y decisiones técnicas a revisar:** todos los personajes hablan **solo con texto**. Al llegar al hub tras el 1-2 con Calc teletransportada, Calc está despierta en su estación; el juego se pausa y Calc habla en su cuadro LCD (líneas «Resta» con `{puntos}` y el icono), Eco (atenuado) se descuelga entre medias y al terminar `meet_ally("calc")`. Textos finales en `propuesta-calc-encuentro.md` §6 (**propuesta**, por decidir). Decisiones técnicas: nada nuevo en `save.json` (la llegada es de sesión; un game over la pierde); conocer a Calc marca «sin guardar»; la tienda no se abre sola (se abre con el pulso); el LCD usa `cian_tenue` del hub en lugar de un verde que la paleta no tiene; Calc conocida se ve despierta (antes dormida). Por decidir: los textos y si la tienda debe abrirse sola.

## Tanda M2 de las mejoras de Calc (2026-10-17)

Efectos complejos de `propuesta-mejoras.md` implementados con las decisiones del usuario (detalle en su sección «Tanda M2»). **Regeneración pasiva:** la regla «no hay regeneración pasiva ni curación» de las «Notas del paso 9» cambia **solo** con Sync Rate 5 y Energía 5 (aprobado el 2026-10-16); sin esas mejoras, igual que antes.

**Decisiones técnicas tomadas (a revisar jugando; los valores están en datos):**

1. **«Fuera de combate» (Sync 5):** 6 s sin recibir daño (el Sync baja: golpe, caída u Ocultarte), sin disparar el láser y sin lanzar el pulso; sin un perseguidor persiguiendo (punto rojo en persecución, aviso, lanzamiento o recuperación, en cualquier sitio) y sin un enemigo activo a menos de 384 px del centro de Isak (Burbuja patrullando sin aturdir, punto rojo despierto, banner avisando o barriendo; los aturdidos, dormidos y derrotados no cuentan). Un jefe activo contará (grupo `boss`, sin jefes todavía). `data/passive_regen.json`.
2. **Tiempos:** la regeneración pasiva va en tiempo del mundo y solo en los niveles (no en el hub); el gasto del Ocultarte y la persistencia del Debug 3, en tiempo real (como el Debug).
3. **Debug 3 (revelado persistente):** persiste lo que el Debug revela: plataformas ocultas `h` (visibles y sólidas) y la vista a través de los pop-ups translúcidos; en el último medio segundo parpadea. No persiste al morir, al reaparecer ni al cambiar de escena. Persiste también si el Debug se apaga por falta de energía.
4. **Debug 4:** mundo ×0,4 (antes ×0,5). El gasto no cambia (tiempo real: 20/s o 15/s con el Debug 2); cada segundo de Debug da 2,5 s del mundo en vez de 2.
5. **Debug 5 «Arranque rápido»:** la antigua mejora `quick_start` (0,5 s) reencuadrada por el documento: carga de 1,0 a 0,4 s.
6. **Pulso de retorno:** +4 a la barra (sin desbordar; con la barra llena se gasta igual), una vez por enemigo (ruta del nodo) y por intento de nivel (`GameState.begin_attempt`, en `LevelRunner.start_level`: carpeta, arranque y R); reaparecer en un checkpoint no lo reinicia.
7. **Láser 5:** atraviesa todo lo del grupo `enemy` que el láser daña ahora (también la plataforma de una Burbuja aturdida); un enemigo inmune (punto rojo despierto) lo para. Lo comprueban las salas `correo_test`, `recordatorios_test` y `calc_test` repetidas con el láser que perfora.
8. **Ocultarte:** se activa solo en un nivel; en el hub no. No corre (la acción `run` se ignora). El perseguidor que pierde el rastro se para 1 s (`lost_s` de su JSON) con un «?» y vuelve a su sitio; dormido o volviendo no ve a Isak oculto. Eco se atenúa al 45 %. Su aviso de control («Ocultarte: H / L3 (mando)») sale la primera vez que se empieza un nivel con el Pulso 4 comprado.
9. **Power banks:** el aviso «Sin espacio» se ve mientras Isak está encima y 1,5 s después, sobre su cabeza (como todo el mundo, se dibuja por debajo de Isak); las devoluciones de la migración y la papelera pueden superar el tope (no se borra nada). **Desvío:** la propuesta decía que la Q del power bank explicaría el tope; su texto es la línea original de Eco y debe seguir igual (decisión «mismo texto» del paso 7 de `propuesta-asistentes-y-vidas.md`), así que no se cambió: el aviso «Sin espacio» lo explica en el momento. Si quieres que la Q lo diga, propongo añadir «Solo caben tres a la vez.».
10. **Validador:** `--access-cap` (todas las pistas en el tope del acceso del nivel) y `run_tests.sh` valida además con todo al máximo y exporta el camino del 1-2 así; el modelo usa la ralentización y la carga del Debug mejoradas e ignora el Ocultarte y la regeneración pasiva.

**Jefes y Ocultarte (ideas futuras, sin implementar):** La Curadora (flash que no «captura» a Isak oculto), El Vendedor (el jefe lo busca y deja a la vista el «Cancelar» de su espalda) y El Visto (el «escribiendo…» de la fase 3 falla si Isak se oculta justo antes); con Isak Optimizado, sin efecto. Detalle en `propuesta-mejoras.md` §4.

## Recuerdos de jefe en tres capas (2026-10-18)

**Decisión del usuario** («me parece genial dale»; la primera idea es suya, el resto propuesta del orquestador). Detalle en `propuesta-recuerdos.md`.

1. Los **recuerdos se obtienen al vencer a cada jefe**: en cada vuelta se vence a los 6 jefes de mundo (y al final a Isak Optimizado) y cada uno entrega el recuerdo del mundo que cuida. Alerta Mayor ya lo hacía (su «Fragmento de concentración» es la capa Caché del Mundo 1).
2. **Tres capas, una por vuelta:** Caché, un fragmento borroso; Kernel, la escena completa; Raíz, la verdad detrás de la escena, con lo que Eco ocultó. 6 × 3 = 18 recuerdos de jefe, escritos mundo a mundo.
3. **Dos tipos en la pestaña «Recuerdos» de Notas** (por carpetas de mundo, como el álbum): recuerdos de jefe y **mensajes de secretos** (correos y mensajes de familiares y amigos; p. ej. la carpeta de Spam del 1-2, que deja de ser «recuerdo coleccionable» y pasa a mensaje). Precisa V16: siguen sin desbloquear nada.
4. **Guardado:** lo obtenido sin guardar en Notas se pierde en un game over; lo guardado es registro y se conserva en los rollbacks (como los secretos encontrados). Propuesta: la recompensa del jefe avisa «Guarda en Notas para conservarlo».
5. Solo texto.

**Decisiones del 2026-10-18 (2.ª tanda, `propuesta-recuerdos.md` §8):**

1. **Sexto jefe (usuario):** Isak Optimizado es el jefe del Mundo 6 (La Nube) y entrega su capa: en Caché y Kernel antes del rollback (aunque escape o engañe a Isak); en Raíz justo antes del momento de decisión.
2. **Final real (usuario: «sí»):** exige los **18 recuerdos de jefe** (6 × 3). El camino normal los cumple; al reunirse se ensamblan ante Eco en el momento de decisión (propuesta de escena, sin texto definitivo: los seis recuerdos se ensamblan y a Eco se le desmorona la «versión optimizada»; `06-finales.md` §14.1).
   - ~~Los mensajes de secretos no son requisito (propuesta del orquestador).~~ **Cambiado por el usuario el 2026-10-19:** sí lo son (abajo).
3. **Ilustración (usuario):** pixel-art solo para la capa Kernel de cada jefe (6 imágenes); Caché muestra la misma imagen borrosa (filtro o dither de baja resolución); Raíz y los mensajes, solo texto.
4. **Mensajes de secretos (usuario):** 3 por mundo en Caché, uno por subnivel; los de Kernel y Raíz, al construir cada mundo.
5. **Capas perdidas (orquestador):** sin regla especial: un game over devuelve al último guardado, el jefe vuelve a estar sin vencer y al derrotarlo entrega de nuevo el recuerdo. Red de seguridad: al vencer a un jefe se entregan además las capas inferiores que falten.

**Decisiones del 2026-10-19 (usuario; `propuesta-recuerdos.md` §9 y §10):**

1. **§9 cerrado** con la recomendación de cada punto: ilustraciones **por script**; el aviso «Guarda en Notas para conservarlo» es **texto del sistema**; el esbozo del Mundo 1 es la plantilla de tono (Caché = imagen, Kernel = contexto, Raíz = qué hizo Eco); **Eco reacciona** con una línea breve tras la capa Raíz; los mensajes propios de Kernel y Raíz se deciden al construir cada mundo. La pregunta 4 se cierra **al revés** que la recomendación (punto 2).
2. **Los mensajes de secretos sí son requisito del final real** (`GameState.has_all_memories()`: 18 capas de jefe + todos los mensajes). Para que sea justo: un mensaje no obtenido en Caché reaparece en el mismo secreto en Kernel y, si no, en Raíz; cada uno alcanzable con lo que se tiene en ese acceso; ficha «???» en Notas (remitente oculto) y la Q de Eco marca el secreto. Dentro de la vuelta actual se pueden volver a entrar los niveles completados (§13.2) para buscar uno pendiente antes del jefe final de Raíz (verificar al implementar). `data/memories.json` y `memory_pickup` soportan «reaparece si no se obtuvo»; nuevo tipo de recompensa `memory` en `secrets` de los niveles.
3. **Familia de Isak decidida** (`04-personajes.md` §12.5): el **Abuelito** (así lo llama Isak; repara radios, le enseñó a soldar; enlaza con «Isak Fix»; vive con Isak, la cocina del recuerdo es la de casa) y **Mamá** (escribe los mensajes de secretos y firma con humor). Tono cálido y cotidiano, sin pérdida ni duelo. Cierra la decisión abierta de `CLAUDE.md` y `08-pendientes.md`; el Mundo 2 sigue sin texto.
4. **Esbozo del Mundo 1** nuevo (borrador de tono; `propuesta-recuerdos.md` §5): circuito en la mesa de la cocina con el Abuelito y su lupa; en Raíz, Eco recortó la sonrisa («No era un recuerdo útil»).
5. **Mensajes del Mundo 1 (borradores):** 1-1 en el secreto A `secreto_puente_servicio` (x 96, junto a su punto, sin mejoras; «Recado del Abuelito»); 1-2 en la carpeta de Spam (`secreto_spam`, ancla (26, 37); «¿Cenas con nosotros?»); 1-3, concepto de la sala secreta **«Excepciones»** tras una pared visible solo con el Debug y ruta que exige solo el Debug (no Deslizar; C5 se resolvió después, el mismo día, y la ruta sigue sin exigir el dash: `propuesta-1-3.md` §3.3). Textos en `propuesta-recuerdos.md` §10.

**Siguen abiertos:** mensajes propios de Kernel y Raíz; los mensajes de los Mundos 2-6 y el texto del ensamblaje del final real. **2026-10-22:** los 18 recuerdos de jefe y los mensajes del Mundo 1 tienen texto definitivo en datos como **propuesta del orquestador, revisar al jugar** (el usuario delegó la redacción; `propuesta-recuerdos.md` §11.2).

## Dash (Deslizar) y diseño del 1-3 (2026-10-19)

**Decisiones del usuario.** Detalle y valores en `propuesta-1-3.md` (propuesta, pendiente de revisión).

1. **C5 resuelto:** el dash es un gesto aparte con su acción `gesture_swipe` (L / B del mando, reasignable en Ajustes > Controles); el pulso normal sigue disponible.
2. **El dash no sube de nivel** (sin pista de Calc); progresa con las combinaciones del Mundo 5 y la pista de Energía lo abarata de forma indirecta.
3. **Reglas por defecto (sin objeción):** cuesta energía con enfriamiento corto; suelo y aire; invulnerable mientras dura; atraviesa banners y proyectiles, no el terreno ni los objetos sólidos; no se combina con el Ocultarte ni con el Debug. Valores provisionales.
4. **Diseño del 1-3:** sala «Ajustes» con el interruptor «No molestar» (se obtiene Deslizar; Eco comenta algo molesto; aviso de control); unos 6 min, dificultad 3 de 5; Tramo 1 con el **primer banner obligatorio con el dash** (sin nicho ni alternativa) y los siguientes con dash o nicho; Tramo 2 con plataformas que parpadean al ritmo **solo con señales visuales** (parpadeo que se acelera cada pocos ciclos); Tramo 3 con Burbujas y puntos rojos juntos (pulso + dash); Tramo 4 con el túnel de alarmas que se acelera; cierre en la pantalla de bloqueo hacia Alerta Mayor.
5. **Secreto «Excepciones»:** pared visible solo con el Debug, ruta sin dash, en el Tramo 2 o 3, con `msg_1_3` (`secreto_excepciones`); alcanzable en Caché.
6. **Música y efectos de sonido:** se tratan al terminar el 1-1, el 1-2 y el 1-3 (siguen siendo decisión abierta).

**Preguntas abiertas** (con recomendación): `propuesta-1-3.md` §8.

## Mundo 2: lo que el usuario debe revisar al probar (2026-10-23)

El Mundo 2 se hizo con las decisiones delegadas al orquestador (`propuesta-mundo-2.md` §8.1). Lista corta para la primera prueba; ninguna bloquea, todas se ajustan en datos.

**Valores a ajustar jugando**
- Velocidad del scroll por tramo (sección `scroll` de `data/levels/2-x.json`; 2-1 0,5-0,7, 2-2 0,5-0,9, 2-3 0,4-1,2 tiles/s) y el daño del borde (−10, `data/camera_scroll.json`).
- Golpe al suelo: tiempo de mantener (0,12 s en el aire, 0,35 s en el suelo) y onda de 1,5 tiles (`data/isak_abilities.json`, `ground_pound`). ¿Se dispara sin querer al bajar de una plataforma de una vía?
- Frágil 0,6 s, Historia 1,6 s de 3,2 s, clones cada 1,5 s con tope 6, videos cada 2,5 s (`data/world2_objects.json`, `data/enemies/*.json`).
- Duración del jefe Autoplay: ideal 105 s en Caché; si se hace largo, la primera palanca es `phase1.clips_per_cycle` 2 → 1 (unos −10 s) en `data/bosses/autoplay.json`.

**Textos propuestos (todos marcados como propuesta)**
- Ayudas Q de los 17 tipos del Mundo 2 (`data/help.json`, `world: 2`).
- Líneas de Eco: la del reproductor «Mira cuánto tiempo ahorramos juntos.» (`story_lines.pausa_2_2`) y las del jefe (intro, fases, cura, derrota; `texts` de `data/bosses/autoplay.json`).
- Mensajes de secreto `msg_2_1`, `msg_2_2` y `msg_2_3` (`data/memories.json`) y la capa Caché `boss_w2_l1`.
- Carteles (`feed_sign`): «Para ti», «Desliza hacia arriba», «Reproducción automática: siempre», «Te podría gustar: esto», «Ya lo has visto todo. (Mentira.)», «Quedan 3 segundos para el siguiente video. No puedes cancelar» y variantes.

**Limitaciones conocidas (no son fallos; decidir si importan)**
- Validador: la activación de los videos se modela con una cámara centrada en Isak, no con la vista real del scroll; un video puede empezar algo antes o después que en el modelo (el bot del feed lo compensa esperando la fase real).
- Validador: en las zonas de «Un video más» no se exige ningún golpe (los clones se simulan como amenaza y el camino los evita o los limpia con el golpe al suelo cuando le conviene).
- Sonido: `AudioManager` engancha las señales por la clase de cada nodo, así que una pieza que hereda de otra del Mundo 1 (la frágil del recordatorio, la Historia de la plataforma que parpadea, el reproductor del interruptor «No molestar») puede sonar como su clase base; los 21 IDs del Mundo 2 son provisionales hasta los sonidos del amigo del usuario.
- Arte del jefe Autoplay, del Comentarista y pose del golpe al suelo: provisionales por script hasta el paso 23 (AutoSprite, con permiso y total de créditos antes).
- La salida del validador del 1-2 tiene desde el paso 12 una línea más (el cruce de recordatorios `suelto_b`, que antes se saltaba); el resultado y el camino del Mundo 1 no cambian (comprobado el 2026-10-23 frente a 72d16f7: 1-1, 1-3 y 1-boss idénticos byte a byte).

## Pie de teclas en los menús del hub (2026-10-23)

Petición del usuario: «cuando abres cualquier menú en el hub quiero que sea claro de que el botón G es el botón de acción para acceder a las opciones de los menús». Decidido por el orquestador (con autoridad del usuario), a revisar al jugar:

- Un único componente `MenuHints` (`scripts/ui/menu_hints.gd`, textos en `data/menu_hints.json`) al pie de cada panel: Notas (menú y confirmación de guardar), álbum (carpetas, pestañas y ficha), tienda de Calc, carpetas de mundo (subniveles, «¿Seguro? Aún no has guardado.» y mundo sin subniveles) y la entrada del apodo. Sustituye a las líneas de ayuda sueltas («Arriba/abajo: elegir. Pulso: aceptar. Salto: volver»).
- Formato: «[G] Aceptar · W/S Elegir · Espacio Volver»; la acción principal lleva su tecla en una cajita (cian en el hub, como la placa «G» de las estaciones; ámbar en el apodo). El verbo cambia por menú (Comprar, Entrar, Abrir); en la ficha del álbum la acción principal es Volver; en un mundo sin subniveles, «[G] o [Espacio] Volver».
- Teclas leídas del Input Map con las tablas de Ajustes > Controles (cambian al reasignar). Con mando (el último dispositivo usado) se ven los botones (X, A, B) y la navegación dice «Cruceta».
- La entrada del apodo acepta con `ui_accept`: muestra «Intro» (o A con mando), no G.
- La primera vez de la sesión que se abre cada menú, la cajita late 3 s (alterna cian y blanco); sin pausa ni pasos extra. Con «Reducir efectos de Sync bajo» (el único ajuste de reducir efectos) no late, pero sigue resaltada. No se guarda nada: en cada sesión vuelve a latir una vez por menú.
- El menú de pausa y Ajustes no cambian: no aceptan con G sino con Intro / A y ya dicen «Intro: aceptar».
- El álbum pasa de 6 a 8 columnas (ancho 372 px de arte): con 31 objetos del Mundo 1 el panel ya se salía de los 720 px y tapaba la ayuda.

## Decisiones del 2026-10-25: power bank coleccionable puro

Decisión del usuario, aprobada el 2026-10-25. **Sustituye** a la «Decisión 3» del 2026-10-14, a las decisiones 1 y 2 del 2026-10-14 (2) y al tope de 3 de la tanda M2 (`docs/propuesta-mejoras.md` §5.1, que lleva el detalle).

- **Qué es:** el power bank es un coleccionable puro. El `power_bank_pickup` se encuentra **ya completo** en el mapa (sprite `power_bank_full`) y se recoge siempre.
- **Se elimina:** power banks vacíos, carga con el sobrante de drops y jefes (`capacity_energy`, `add_power_bank_charge`), `attention_point_energy_overflows`, tope de 3 (`max_total`, `can_take_power_bank`), aviso «Sin espacio» (`no_room`, `EventBus.power_bank_no_room`) y cualquier estación de carga. Con la barra llena, el sobrante de energía **se pierde** (`GameState.add_debug_energy` devuelve lo que no cupo).
- **Uso:** solo se gasta al comprar el nivel 5 de una pista en Calc (`cost.power_banks` de `data/upgrades.json`; «Falta un power bank completo» se mantiene). Calc sigue sin venderlos.
- **Indicador por nivel** (como los puntos de atención): HUD del nivel con la pila y «recogidos/total» del mapa (solo en niveles con power banks, nunca en el hub; fuente de textos, porque la del HUD no tiene «/») y la carpeta del hub, en los subniveles completados, con « - Power bank 0/1» (`GameState.get_level_power_bank_progress`, que lee los `power_bank_pickup` de `data/levels/<id>.json`).
- **Totales:** Calc («Power banks: N (encontrados E, gastados G)») y Notas en el hub («Power banks: E encontrados, G gastados»). Gastados = suma de `cost.power_banks` de los niveles comprados; encontrados = los que se tienen + gastados.
- **Rollback y guardado:** misma regla que antes (el rollback devuelve los de mapa no guardados; la Papelera guarda los que se tenían). Se guarda `power_banks.full`; los vacíos de un guardado anterior pasan a completos al cargar y la carga parcial se ignora (sin subir la versión).
- **Niveles y validador:** sin cambios (1-1, 1-2, 1-3, 2-2 y 2-3 conservan su power bank; el validador no modelaba la carga). Las notas de algunos niveles aún dicen «power bank vacío» (texto histórico, sin efecto).
- **Pruebas:** `tests/test_power_bank_collectible.gd` sustituye a `test_power_bank_cap.gd`; actualizadas las de guardado, papelera, Calc, Notas, carpetas, cargadores, regeneración y Pulso de retorno. La captura 11 «Sin espacio» de `tools/render_upgrades_m2.gd` se retira.
- **Dudas abiertas:** (1) ¿Se quiere un arte propio para el contador del HUD o basta la pila dibujada con «0/1»? (2) ¿El contador de la carpeta debe salir también en los subniveles no completados?
