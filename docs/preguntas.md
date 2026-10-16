# Preguntas abiertas sobre el documento de diseño

**Estado (2026-10-15):** resueltos C1, C4 (Mundo 1: hub tras cada nivel), C6, C7, C9, V2, V3, V7, V10 (paleta), V11, V12, A4, A8, A10, A11, y el hub y el guardado manual («Hub y guardado: propuesta aprobada (2026-10-15)», al final). Aplazado: V15. En C9 la dificultad ya no se elige: es una progresión por **tres vueltas** (Easy, Normal y Hard; engaño en Normal, final real en Hard), aprobada el 2026-10-15 a falta de detalle (ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado», al final; hay una sugerencia de dificultad pendiente de aprobar). Siguen abiertos: C2, C3, C5, C8, V1, V4, V5, V6, V8, V9, V10 (tileset), V13, V14, V16, A1, A2, A3, A5, A6, A7, A9, A12, A13, A14, A15, A16, y las dudas de las tres vueltas.

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
- **Decisión (2026-10-15):** el hub aparece desde el final del 1-1 y se vuelve a él tras cada nivel del Mundo 1 (hub mínimo con Calc dormida; `05-hub.md` §13.1 y `propuesta-hub-y-guardado.md`, pregunta 1). El encadenado explícito del 2-1 (§7.4) se revisará al diseñar el Mundo 2.

### C5 [Fuera del slice] El dash "convierte" el pulso frente al uso de pulso y dash por separado
- **Sección:** §3.5 (Deslizar: "El pulso se convierte en un dash de datos") frente a §6.5 (1-3, Tramo 3: "Combinación de dash y pulso") y §6.6 (Fase 2: "cerrarlos con el pulso y esquivar con dash").
- **Problema:** si el pulso se sustituye por el dash, ya no se pueden usar los dos en el mismo tramo.
- **Propuesta:** el dash es una variante del pulso que se activa con el gesto, y el pulso normal sigue disponible. El mapeo de controles queda pendiente, porque es una decisión abierta de `CLAUDE.md`.
- **Por qué:** es la única lectura compatible con los niveles y el jefe del Mundo 1.

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
- **Propuesta:** con Sync Rate = 0, animación de muerte y reaparición en el último punto de sincronización (o en `P`) con 100% de Sync Rate y la energía que tenía. Tocar un punto de sincronización lo activa y repone el Sync Rate al 100%. En el slice no se pierden puntos de atención; esa regla queda pendiente para cuando exista Papelera.
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
- **Decisión del usuario (2026-10-15):** los mensajes **importantes** (habilidad adquirida, historia, cosas relevantes) pausan el juego y se cierran con una acción del jugador; los menores (ayuda contextual) siguen sin pausar, en tiempo real y en cola. Motivo: si el jugador avanza rápido, un aviso pisaba a otro y no sabía a qué acción correspondía cada uno. Detalle en las notas del paso 14b.

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
- **Sección:** §8.2 (umbrales de likes), §10.2/§10.3/§13.3 (precios de tienda, atajos, Calc y drenaje de suscripción), §13.3 (cuánto guarda Papelera) y §12.3 (cuánto sube Calc la energía máxima).
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
- **Propuesta:** los recuerdos de los secretos son coleccionables que se ven en Notas y no desbloquean nada. El candado de La Nube usa los cinco fragmentos de los jefes.
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
- **Propuesta:** cada punto suma 1 al contador y repone 10 de energía (sobre 100). No hay regeneración pasiva. Al empezar, la energía está llena.
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
- **Recargas (pendiente):** la recarga de energía y de Sync Rate fuera de los puntos de atención se decidirá más adelante. Hay un gancho comentado en `GameState.add_attention_points()`; no hay regeneración pasiva ni curación.
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
- **Líneas importantes (decisión del usuario, 2026-10-15):** campo `important` (por defecto `false`) en el `eco_line` del nivel y en `EventBus.eco_line_requested`. Una línea importante pausa el árbol (`get_tree().paused`; el cuadro procesa siempre), no se cierra sola y espera a que el jugador pulse saltar o `ui_accept` (Espacio / A del mando / Intro): la primera pulsación durante la escritura completa el texto y la siguiente lo cierra. El juego se reanuda al terminar de desvanecerse (o sigue en pausa si la siguiente en cola también es importante) y siempre que el cuadro sale del árbol (cambio de escena, nivel quitado); si la pausa la puso otro, no la quita. Pasa delante de las normales en cola, y si hay una normal en pantalla la desplaza: esa vuelve a la cola, delante de las demás normales, así que no se pierde ninguna. En pausa no avanzan el mundo, las Burbujas, el Debug, los temporizadores de los nodos ni el retraso de los avisos de control. Marcadas como importantes: los avisos de control de habilidades (`AbilityNotices`), el texto de `ability_pickup` y, en el 1-1, `eco_bienvenida` (primera voz de Eco) y `eco_laser` («Herramienta nueva…»). El bot de recorrido las confirma solo.
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
- **Decisión 3, recargas y power banks:** los enemigos y jefes sueltan recargas de energía de Debug y de Sync Rate (`RechargePickup`; comportamiento y aspecto en `data/recharge_pickup.json`). Cuánto suelta cada enemigo va en su JSON, en la sección `drops`. Para la Burbuja de alerta se propone **energía +25** (1,25 s de Debug) y **Sync Rate +10** (lo que quita un golpe), solo al reventarla, no al aturdirla. Si la barra de Debug ya está llena, el sobrante carga el power bank (`GameState.add_debug_energy`). Cada **200 de energía** sobrante completan un power bank (`data/power_bank.json`, `capacity_energy`, equivale a dos barras llenas). Los power banks completos y la carga parcial se guardan. El HUD muestra un contador mínimo bajo la barra (icono de pila con la carga parcial y "x<n>"), creado por código sin tocar `hud.tscn` ni `data/hud.json`, y oculto si no hay power banks ni carga.
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

- **Decisión 1, el sobrante solo desborda desde los drops:** la energía de Debug sobrante (barra llena) solo carga el power bank cuando viene de los **drops** de enemigos y jefes. Los puntos de atención llenan la barra, pero no desbordan. `data/power_bank.json`: `attention_point_energy_overflows` pasa de `true` a `false` (si falta la clave, `GameState` también usa `false`). Prueba: `test_attention_point_energy_does_not_overflow`.
- **Decisión 2, un power bank llega vacío:** un power bank comprado u obtenido (p. ej. el `power_bank_pickup` de mapa) se recibe **vacío** (carga 0) y se llena con el sobrante de los drops. `GameState` separa ahora `power_banks` (completos; son los únicos que pagan mejoras), `empty_power_banks` (vacíos o cargándose) y `power_bank_charge` (carga del vacío que se está llenando). `add_empty_power_bank()` suma uno vacío; `collect_power_bank_pickup()` lo usa. Cada `capacity_energy` (200) de sobrante llena un vacío, que pasa a completo. El guardado añade `power_banks.empty` (sin cambiar la versión 1); un guardado antiguo con carga y sin `empty` conserva la carga en un power bank vacío. El HUD muestra el contador también si solo hay power banks vacíos.
- **Decisión 3, enemigos y farmeo:** los enemigos reaparecen al rejugar un nivel y sus drops se pueden farmear. Se deja así por ahora.
- **Decisión 4, dificultad:** la dificultad ya no se elige. C9 queda sustituida por una dificultad que evoluciona con el juego (el usuario lo confirma). **Concretada el 2026-10-15:** tres vueltas Easy, Normal y Hard (ver «Decisiones del 2026-10-15: tres vueltas, hub y guardado»).
- **Dudas abiertas (power banks):**
  1. **Resuelta (decisión del usuario, 2026-10-15):** sin ningún power bank vacío, el sobrante de los drops **se pierde**: no se acumula ni se devuelve al obtener después un power bank vacío. `GameState.add_power_bank_charge` ya lo hacía así; la prueba `test_overflow_is_lost_without_empty_power_banks` lo comprueba.
  2. Al pagar una mejora, el power bank completo se gasta y desaparece (no vuelve como vacío). ¿Es así, o se recarga y se reutiliza?
  3. Hoy no hay forma de **comprar** un power bank: el catálogo `data/upgrades.json` no tiene esa entrada. ¿Dónde se compra y cuánto cuesta?
  4. **Resuelta:** los textos de `power_bank_pickup` (`data/world1_objects.json` y `scripts/levels/power_bank_pickup.gd`) ya dicen "vacío".

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
- **Láser (valores PROPUESTA, `data/isak_abilities.json`, `laser_*`):** proyectil horizontal hacia donde mira Isak, desde el celular. Coste 10 de energía (la **misma** barra del Debug, `GameState.debug_energy`: 10 disparos con la barra llena), daño 1, enfriamiento 0,4 s, anticipación 0,05 s (3 cuadros a 60 fps, destello en el celular), 1200 px/s y 768 px de alcance (12 tiles). Se cobra al salir el disparo. Sin energía suficiente no dispara: chispa gris en el celular y `EventBus.laser_denied`. Vale en el suelo y en el aire, no durante el golpe (Hurt) ni muerto; no cambia la física de Isak ni tiene animación propia todavía. **Cambio (2026-10-15, pedido por el usuario):** al disparar Isak se detiene como con el pulso: mientras dura la pose del láser (anticipación 0,05 s + brazo extendido 0,25 s = 0,30 s; se alarga si se encadenan disparos) la dirección se ignora y frena con la fricción del suelo (o con `air_acceleration` en el aire), sin girarse; la gravedad no cambia. Antes se movía libre y se veía la pose deslizándose. `laser_locks_movement` en `data/isak_abilities.json` (false = comportamiento anterior). El salto no corta la pose (sube en vertical hasta que acaba); el golpe, la muerte, la pose de espaldas y la reaparición sí. Coste, daño, enfriamiento y alcance sin cambios. Choca con el terreno (capa world) y con los enemigos (capa enemy). Aspecto provisional dibujado por código (cian del Debug y banner_blanco).
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
  - Pulso: al empezar el 1-1 en una partida nueva, 1 s después de entrar, así que sale justo tras la bienvenida de Eco. Solo dice el control: el uso lo explican las líneas de Eco de la Burbuja y del receptor.
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
2. Tutorial de guardado B + C: línea importante de Eco junto a la terminal de salida del 1-1 y primer hub guiado. **No hay guardado dentro de los niveles.**
3. Hub = sala 2D caminable con paneles; una sola pantalla en el Mundo 1.
4. Calc dormida en el hub del Mundo 1: vende sin hablar.
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
- **Dudas para el usuario:** (1) ¿vale C / R3 como control provisional de guardar? (2) `play_time_s` cuenta el tiempo con el juego sin pausar, también en la pantalla del hub; ¿vale así? (3) Aún no hay nada que marque secretos encontrados (`GameState.mark_secret_found` existe, sin uso): se conectará con Linterna o con los secretos del 1-1.
