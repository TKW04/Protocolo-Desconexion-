# Preguntas abiertas sobre el documento de diseño

**Estado (2026-10-14):** resueltos C1, C6, C7, C9, V2, V3, V7, V10 (paleta), V11, A4, A8, A10. Aplazado: V15. Siguen abiertos: C2, C3, C4, C5, C8, V1, V4, V5, V6, V8, V9, V10 (tileset), V12, V13, V14, V16, A1, A2, A3, A5, A6, A7, A9, A11, A12, A13, A14, A15, A16.

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

### C4 [BLOQUEA SLICE (fin del 1-1)] Qué pasa al terminar un nivel: ¿hub o siguiente nivel?
- **Sección:** §13.5 ("Al terminar un nivel, Isak vuelve al hub") frente a §13.1 (el hub no existe hasta vencer a Alerta Mayor), §6.3 (Cierre: la puerta "da paso al siguiente nivel") y §7.4 (2-1: "entra en el siguiente nivel sin poder pararse").
- **Problema:** las reglas de transición se contradicen. En el Mundo 1 no puede haber vuelta al hub, y el 2-1 encadena con el siguiente nivel de forma explícita.
- **Propuesta:** los niveles de un mundo se encadenan y se vuelve al hub tras el jefe (y al salir de un mundo ya completado). En el slice, la puerta "Marcar como leído" lleva a una pantalla de "Fin del slice" que permite reiniciar el nivel.
- **Por qué:** es la única regla compatible con §6.3, §7.4 y §13.1. Para el slice basta con un final limpio.

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
- **Decisión (2026-10-14):** aprobada la propuesta.

### V3 [RESUELTO] El foso del Tramo 1 de un nivel "sin riesgo de muerte"
- **Sección:** §6.3 (Tramo 1: "un foso pequeño"; Dificultad: "Prácticamente sin riesgo de muerte").
- **Problema:** no se define qué ocurre al caer en un foso (muerte, daño o simple caída a un nivel inferior).
- **Propuesta:** el foso del Tramo 1 tiene fondo: se puede salir caminando o saltando. En general, caer fuera del nivel quita un 20% de Sync Rate y devuelve a Isak al último suelo seguro.
- **Por qué:** practicar el salto sin castigo encaja con la dificultad 1/5, y la regla general sirve para el resto de niveles.
- **Decisión (2026-10-14):** aprobada la propuesta.

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

### V12 [Fuera del slice] Revisitar secretos de niveles anteriores
- **Sección:** §6.3 (pared con glitch del 1-1), §8.4/§8.5 (marco del 3-1) y §13.2 (se pueden rejugar las carpetas de los mundos completados).
- **Problema:** no se dice si se pueden elegir niveles sueltos ni cómo volver al 1-1 antes de completar el Mundo 1.
- **Propuesta:** la carpeta de cada mundo completado permite elegir cualquiera de sus niveles. El secreto del 1-1 se recupera al rejugarlo desde el hub.
- **Por qué:** es lo mínimo para que los secretos "retomables" tengan sentido.

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
- **Decisión (2026-10-14):** aprobadas las propuestas.

### A11 [BLOQUEA SLICE] Representación del HUD
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
