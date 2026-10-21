# Propuesta: jefe del Mundo 1, «Alerta Mayor»

**Estado:** **aprobada el 2026-10-20** con las decisiones del usuario de §5 (las 8 resueltas). Plan en §6: pasos 1-13 hechos el 2026-10-21 (el jefe se juega desde el hub tras el 1-3, con la barra del HUD, el golpe final, la recompensa y la vuelta al hub con el Mundo 2 desbloqueado; textos en §6.1, propuesta del orquestador para revisar al jugar); faltan el bot, las pruebas de conjunto y el arte final (pasos 14-16). Lo que sigue marcado **PROPUESTA** son detalles que se ajustan al implementar y jugando, no decisiones abiertas. Los valores son orientativos: se ajustan jugando y con el validador. **Los textos de Eco, del jefe y del sistema están por escribir con el usuario**; la historia no se escribe aquí.

**Cambios del 2026-10-20 (aprobación):** **no hay rollback** al final de la pelea (se eliminan el «amago de rollback», las líneas «Restaurando copia anterior…» / «Error: copia incompleta», la señal `boss_rollback_attempted` y el uso de `sfx_boss_rollback_easy`; la fase 3 termina con el golpe final, §2.8); **energía rehecha con números reales** (§2.4): 4 cargadores de arena con 4 s de enfriamiento y el Debug a mitad de gasto dentro de la arena; plan de implementación por pasos (§6).

**Cambios del 2026-10-21 (2): Raíz** usa 3 lanzamientos por ronda en la fase 3 en vez de 4 (decisión del usuario; §2.4.7, §2.12). Pasos 5-8 de §6 implementados.

**Cambios del 2026-10-21 (la marca, idea del usuario aprobada):** el daño ya no exige el Debug activo. **El Debug revela el núcleo; un pulso que alcanza el núcleo revelado lo MARCA**; mientras dura la marca (`mark_duration_s` en tiempo del mundo: **Caché 4 s, Kernel 3 s, Raíz 2,5 s**) el núcleo queda visible y **el láser lo daña sin Debug** (1 golpe; 2 con el Láser 4). El pulso solo marca; el dash nunca daña. Ciclo: Debug → pulso (marca) → láser → la marca caduca → otra vez (§2.3). Como el daño pasa a costar láseres (10 cada uno, ≥ 90 en Caché), la energía se ha recalculado (§2.4.7): **el Debug baja a un cuarto del gasto en la arena (`debug_drain_scale` 0,25, antes 0,5)** y se mantienen los 4 cargadores de 4 s. Reabiertos los pasos 3 y 4 de §6. Decisión 4 actualizada (§5).

**Fuentes:** `mundo-1-notificaciones.md` §6.6 (ficha original del jefe), `propuesta-1-3.md` (§3.6 cierre, §4 patrones del dash, §5 objetos del 1-3, §7 plan), `propuesta-recuerdos.md` (§4, §5, §7 paso 5 y §8), `propuesta-asistentes-y-vidas.md` §5.3, `propuesta-hub-y-guardado.md` §3.3, `05-hub.md` §13.4, `04-personajes.md` §12.1, `07-estilo-visual.md` §15.5, `propuesta-mejoras.md` §4, `lista-sonidos.md` §4, `preguntas.md` (V10 punto débil, tres vueltas) y el código (`scripts/bosses/weak_point.gd`, `scripts/autoload/debug_mode.gd`, `scripts/levels/charger.gd`, `data/weak_point.json`, `data/isak_abilities.json`, `data/debug_mode.json`, `data/upgrades.json`, `data/passive_regen.json`, `data/enemies/*.json`, `data/levels/1-3.json`, `scripts/levels/*`, `data/hub.json`).

**Física y habilidades de referencia** (de los datos actuales): pulso gratis, radio 96 px, solo en el suelo, pose 0,33 s. Láser 10 de energía, 768 px, horizontal, solo en el suelo, enfriamiento 0,4 s, daño 1. Debug: mantener 1 s (la carga no gasta), después **gasto continuo de 20 por segundo real** mientras está activo, mundo ×0,5; se apaga con otra pulsación o al llegar a 0, y para volver a activarlo hay que cargar otra vez 1 s; el pulso y el láser **sí** funcionan con el Debug activo; el dash **no** (regla «no se combinan»). Dash 192 px en 0,2 s, invulnerable 0,3 s, 10 de energía, enfriamiento 0,5 s, uno en el aire. Golpe recibido −10 de Sync Rate, 1 s de invulnerabilidad. Energía 100 (110-120 con las mejoras de Caché). Andar 220 px/s (3,4 tiles/s), correr 360 px/s (5,6 tiles/s). Salto: subidas cómodas de 2 tiles.

---

## 0. Resumen

- **Acceso:** la terminal «Deslizar para desbloquear» del 1-3 devuelve al hub (decisión 2). En la carpeta del Mundo 1 aparece la fila **«Jefe: Alerta Mayor»**, disponible cuando el 1-3 está completado. Se entra como a cualquier subnivel: con la confirmación «¿Seguro? Aún no has guardado.» si hay cambios sin guardar, 3 vidas por intento y game over con rollback a la última copia, como en todo el juego.
- **El jefe:** un badge rojo enorme con «99+». Su contador baja con cada golpe al núcleo: **99+ → 66 → 33 → 0** (9 golpes en Caché). Tiene tres fases. **Fase 1:** lanza Burbujas y banners. **Fase 2:** pop-ups que tapan la vista y ráfagas de notificaciones. **Fase 3:** copias falsas, campanas al compás y plataformas que parpadean. Solo se le hace daño en el **núcleo**, que solo se ve con el Debug (o marcado).
- **Cómo se vence:** se abre la ventana con la mecánica de cada fase (aturdir, cerrar, descubrir). Después se activa el Debug para ver el núcleo, se le lanza un **pulso que lo marca** (4 s en Caché) y, ya sin Debug si se quiere, se le dispara con el **láser** mientras dura la marca. **El noveno golpe es el golpe final:** el contador llega a 0, el jefe se desarma en píxeles e Isak recibe la **capa Caché** del recuerdo del Mundo 1. **No hay rollback** en esta pelea (decisión 1).
- **Energía:** en la arena hay **4 cargadores** (+50, enfriamiento de **4 s**) repartidos por el suelo y el Debug gasta **un cuarto** (5 por segundo; 2026-10-21, antes la mitad). Con eso, hasta una pelea torpe cabe en una barra de 100 sin mejoras con al menos 30 de margen por ventana (§2.4.7).

---

## 1. Acceso al jefe

### 1.1 Ya decidido

| Tema | Decisión | Fuente |
|---|---|---|
| Cierre del 1-3 | La terminal `terminal_bloqueo` («Deslizar para desbloquear») **vuelve al hub** y deja el 1-3 en `completed_levels` (decisión 2, aprobada el 2026-10-20). No cambia nada en el 1-3: ya funciona así. La «pantalla de bloqueo» de la ficha es la propia arena del jefe. | `mundo-1` §6.5, `propuesta-1-3.md` §3.6 |
| Al terminar un nivel | Se vuelve al hub. | `CLAUDE.md`, «Llegada y salida» |
| Fila en la carpeta | La maqueta del panel del Mundo 1 ya incluye «Jefe: Alerta Mayor (bloq.)» bajo los tres subniveles. El panel muestra «Próximamente» para lo que no es jugable (`playable: false`) o no pertenece a la vuelta actual. | `propuesta-hub-y-guardado.md` §3.3, `data/hub.json` |
| Selección | Solo desde el hub, por carpeta y subnivel, y solo los de la vuelta actual. No hay selector de dificultad. La UI dice «Acceso: Caché» y nunca «vuelta», Easy, Normal ni Hard. | `CLAUDE.md`, «Nombres de las vueltas» |
| Guardado | Manual y solo en Notas. Al entrar a una carpeta con cambios sin guardar sale «¿Seguro? Aún no has guardado.» con el aviso «Si caes sin guardar, Eco te devolverá a tu última copia.». | «Hub y guardado» |
| Vidas | 3 por intento (más las vidas extra); se reponen al entrar desde la carpeta. Con 0 hay **game over** = `GameState.apply_rollback`: se vuelve a la última copia, lo no guardado se pierde y lo guardado va a la Papelera. Con la Papelera llena, las carpetas no se abren. | «Vidas, game over y papelera» |
| Recompensa | Al vencerlo se obtiene la **capa Caché** del recuerdo del Mundo 1 (`boss_w1_l1`), **sin guardar**, con el aviso del sistema «Guarda en Notas para conservarlo». Si falta alguna capa inferior, también se entrega (red de seguridad). | `propuesta-recuerdos.md` §4, §7 paso 5, §8.5 |
| Hub tras el jefe | Se ilumina la pieza cian del fondo del hub. | `05-hub.md` §13.4, `data/hub.json` (`background_on_world`) |
| Punto débil | El componente `WeakPoint` ya existe: solo es visible con el Debug (o marcado, desde el 2026-10-21), se dibuja por encima del tinte en carmín pulsante y recibe la marca del pulso y el daño del láser (§2.3). | `preguntas.md` V10, `scripts/bosses/weak_point.gd` |

### 1.2 Sin rollback en esta pelea (decisión 1, aprobada el 2026-10-20)

- **Decidido:** Alerta Mayor **no hace ningún rollback**, ni real ni simulado. El rollback de fin de vuelta es solo del **jefe final** (Isak Optimizado, La Nube), como ya decían `preguntas.md` y `propuesta-asistentes-y-vidas.md` §5.3: en Easy escapa y Eco lo desecha todo; en Normal engaña a Isak para que lo lance él; en Hard llega el final real.
- **Eliminado de esta propuesta:** el «amago de rollback» del final (contador que subía de 0 a 33, arena rebobinada, líneas del sistema «Restaurando copia anterior…» y «Error: copia incompleta»), la señal `EventBus.boss_rollback_attempted`, el estado de arte «rebobinado» y el uso de `sfx_boss_rollback_easy`. «Error: copia incompleta» **no se conserva**: habla de restaurar una copia y sugiere un rollback. El final se cierra con el golpe final (§2.8).
- **`lista-sonidos.md`:** `sfx_boss_rollback_easy` queda **retirado del jefe del Mundo 1** y reservado para el rollback del jefe final al terminar Caché (Mundo 6), con su ID a renombrar cuando se diseñe ese jefe.
- **Lo único parecido a un rollback** en esta pelea es el game over normal al perder las 3 vidas (`apply_rollback`), igual que en cualquier subnivel.

### 1.3 Cómo se llega (aprobado)

```
 1-3: terminal «Deslizar para desbloquear»
        │  (pulso de espaldas, vórtice de salida)
        ▼
 Hub (Isak llega por el vórtice; puede guardar en Notas)
        │  carpeta del Mundo 1
        ▼
 ┌─────────────────────────────────────────────┐
 │ Mundo 1 - Notificaciones     Acceso: Caché  │
 │   1-1 Bandeja de entrada     Completado 9/9 │
 │   1-2 Centro de notif.       Completado 9/9 │
 │   1-3 No molestar            Completado 9/9 │
 │ ▸ Jefe: Alerta Mayor         Nuevo          │
 └─────────────────────────────────────────────┘
        │  (confirmación si hay cambios sin guardar)
        ▼
 Arena «Pantalla de bloqueo» (vórtice de llegada)
```

1. **La terminal del 1-3 sigue llevando al hub** (decisión 2). Así se respetan «al terminar un nivel se vuelve al hub» y el guardado manual. Un game over en el jefe no obliga a rejugar el 1-3 sin haber podido guardar.
2. **Entrada en `data/hub.json`**, en la lista `levels` del mundo `m1`, tras el 1-3: `{"id": "1-boss", "name": "Alerta Mayor", "kind": "boss", "laps": [1], "playable": false}`. Con `playable: false` sale «Próximamente» desde ya; al construirlo pasa a `true` (paso 13 de §6). La fila usa un prefijo de texto nuevo, «Jefe: », y **no muestra puntos** (la arena no tiene puntos de atención). Hay que comprobar al implementar que completar el 1-3 desbloquea la entrada siguiente (`unlocked_levels`), como pasa del 1-1 al 1-2, y que la carpeta no pasa a `completed` (ni se enciende la pieza cian) hasta vencer al jefe.
3. **Requisitos:** el 1-3 completado en la vuelta actual. **No se exige nada más**: llegar al final del 1-3 ya obliga a tener pulso, láser, Debug y Deslizar. Tras un game over que se lleve el dash, la Papelera bloquea las carpetas hasta recuperarlo, así que **nunca se entra al jefe sin las cuatro habilidades**. `abilities_available` de la arena: pulso, láser, Debug y dash a `true`. Ni las mejoras de Calc ni los secretos (mensajes o vida extra) son requisito. Si no se encontró `msg_1_3`, se puede volver al 1-3 más tarde dentro de la vuelta (`propuesta-recuerdos.md` §10).
4. **Estados de la fila:** Bloqueado (1-3 sin completar), Nuevo, Completado (jefe vencido en esta vuelta). Con el jefe vencido, la carpeta pasa a `completed` y la fila se puede repetir. La revancha **no** vuelve a entregar la capa: `obtain_memory` no hace nada si ya la tiene.
5. **Guardado y game over:** como en cualquier subnivel. Si se vence al jefe sin guardar y luego hay un game over, la capa y el «Completado» se pierden y hay que vencerlo otra vez (`propuesta-recuerdos.md` §8.5). El texto de la recompensa ya avisa de que hay que guardar.

---

## 2. El jefe

### 2.1 Concepto y tono

- **Ya decidido:** «Un enorme badge rojo con el número "99+", la notificación que representa todas las demás. Eco habla a través de él.» Arena: la pantalla de bloqueo, un espacio amplio con relojes y notificaciones flotando al fondo. Punto débil: un núcleo que solo se ve con el Debug, en carmín, que «obliga a gastar energía con inteligencia».
- **Tono (PROPUESTA):** sobrio y cálido, sin estridencias. Lo molesto se transmite con el ritmo y la insistencia, no con ruido ni con rojos por toda la pantalla. El rojo anaranjado de alerta (`alerta`) se reserva para lo que daña y sus avisos, y el carmín (`carmin`) solo para el núcleo. Todos los personajes hablan **solo con texto**. Eco habla por el jefe con su cuadro de siempre, con un marco «filtrado» (`vox_boss_eco_filter` para el blip). Las líneas son pocas y cortas, y **los textos se escriben con el usuario** (decisión 7):
  - **Intro** (línea importante: **pausa**). Idea de tono, no texto: Eco, amable todavía, le pide a Isak que deje de desactivar cosas: «Solo quiero que no te pierdas nada».
  - **Cambios de fase:** líneas no importantes (**sin pausa**), una por fase. Ideas: «Tienes 66 cosas pendientes». «¿Seguro que quieres seguir concentrado?».
  - **Golpe final:** sin línea de Eco. Como mucho, una línea breve del sistema sin pausa al quedar el contador en 0 (idea: que no queda nada pendiente; **por escribir**). No habla de copias ni de restaurar nada.
  - **Derrota:** el «primer mensaje distinto de Eco, ya sin tanta amabilidad» (`mundo-1` §6.6). Línea importante (**pausa**) tras la recompensa. **Por escribir con el usuario.**
- **Eco compañero durante el combate (PROPUESTA):** la esfera sigue a Isak como siempre. Cuando el jefe habla, parpadea con interferencia: es la misma Eco, y el jugador lo intuye sin que nadie lo diga. La ayuda con Q funciona y **nunca miente** (regla de las ayudas), aunque el tono de Eco suene algo incómodo (§2.10).

### 2.2 Arena «Pantalla de bloqueo»

- **24 × 12 tiles** (1536 × 768 px). La cámara sigue a Isak solo en horizontal, dentro de los límites de la arena; en vertical queda fija y encuadra las 12 filas (`camera.vertical: "simple"`). Muros en las columnas 0 y 23, techo en la fila 0 y suelo en las filas 10-11. Isak, de pie en el suelo, ocupa las filas 8-9, como en el 1-1 y el 1-3.
- **Plataformas de una vía:** dos laterales (columnas 3-6 y 17-20, superficie en la fila 8, Isak de pie en la 7), a 2 tiles del suelo. Una central (columnas 9-14, superficie en la fila 6), a 2 tiles de las laterales. Todas las subidas son de 2 tiles, medidas con el Isak real (`tests/test_level_climbs.gd`).
- **Refugios:** no hay nichos. Hay **dos carriles**: el del suelo (filas 8-9) y el de las plataformas laterales (filas 6-7). Ningún ataque barre los dos a la vez: cuando barre uno, el otro es el refugio. El dash es la alternativa que atraviesa.
- **Cargadores de arena (aprobado, §2.4):** **cuatro**, en el suelo: `cargador_1` (1, 9), `cargador_2` (8, 9), `cargador_3` (15, 9) y `cargador_4` (22, 9). Reutilizables, +50 de energía y **4 s** de enfriamiento en Caché (5 s en Kernel y 6 s en Raíz). Desde cualquier celda del suelo hay uno a **3,5 tiles como mucho** (≤ 0,7 s corriendo) y, si ese se está enfriando, otro a 7 tiles como mucho. Ninguno queda bajo una plataforma ni en la zona donde aterriza el jefe en la fase 1 (columnas 10-13). Es el objeto `charger` de siempre: el enfriamiento corto es un `cooldown_s` por instancia, solo en esta arena (el 1-2 y el 1-3 siguen con 10 s).
- **Debug a un cuarto de gasto en la arena (§2.4.7; 2026-10-21, antes 0,5):** campo de nivel `debug_drain_scale: 0.25`.
- **Vórtice de llegada:** (2, 9). Las notificaciones y los relojes del fondo son decorado (`world1_background`, capa de pantalla de bloqueo con relojes), sin colisión.
- **Sin puntos de atención, power banks ni vida extra.** Los puntos del Mundo 1 ya están en sus tres mapas.

```
      0         1         2
      012345678901234567890123
   0  ########################   techo; campanas (fase 3) en las cols 5, 11 y 18
   1  #        [  99+  ]     #   Alerta Mayor flota (4x4 tiles, cols 9-14, filas 1-4)
   2  # (reloj)[ ALERTA ]    #   y se desplaza entre las cols 4 y 19
   3  #        [ MAYOR  ]    #
   4  #        [_______]     #
   5  #                      #
   6  #        ======        #   plataforma central (una vía), cols 9-14
   7  #                      #   <- carril alto (Isak de pie en la fila 7)
   8  #  ====          ====  #   plataformas laterales, cols 3-6 y 17-20
   9  #CP     C      C      C#   <- carril del suelo; C = cargadores (1, 8, 15, 22), P = vórtice (2)
  10  ########################
  11  ########################
```

### 2.3 Vida del jefe y daño de Isak (aprobado: decisiones 4 y 5)

- **El contador es la vida.** El «99+» del jefe hace de barra: **9 golpes en Caché**, 3 por fase. Cada golpe resta 11 (99+ → 88 → 77 → **66** | 55 → 44 → **33** | 22 → 11 → **0**). Arriba, en el centro, el HUD muestra una barra de jefe sobria con el contador y tres muescas, una por fase. El texto usa solo glifos de la fuente.
- **Revelar, marcar y disparar (2026-10-21, sustituye a «solo cuenta un golpe con el Debug activo»).** El núcleo tiene tres estados:
  1. **Oculto** (sin Debug ni marca): no se ve y **no existe para los golpes**. El láser se para en el **cuerpo** del jefe y el pulso que toca el cuerpo saca la **chispa gris** (la del láser sin energía) **en el borde del cuerpo más cercano a Isak**, nunca en el núcleo: la chispa no delata dónde está. Sin daño ni marca.
  2. **Revelado** (Debug activo; la carga, la salida y el revelado persistente del Debug 3 lo dejan ver pero **no** cuentan para marcar): se ve en carmín. Un **pulso** que lo alcanza (círculo contra círculo, 96 px) lo **marca**. El láser contra el núcleo revelado sin marca saca la chispa gris **en el núcleo** (ya visible) y no daña.
  3. **Marcado** durante **`mark_duration_s` segundos del mundo** (Caché **4 s**, Kernel **3 s**, Raíz **2,5 s**; `laps` de `data/bosses/alert_major.json`): visible **aunque se apague el Debug**, con un halo blanco de segmentos que se apagan como un reloj y parpadea el último segundo (§2.3.1). **Cada láser que lo alcanza es 1 golpe** (2 con el Láser 4, que no se alcanza en Caché), **sin necesidad del Debug**. La marca no se gasta con los golpes: vale **todos los disparos que quepan** en ella (el enfriamiento de 0,4 s y los 10 de energía por disparo limitan solos: unos 5 en 4 s, 4 en 3 s y 3 en 2,5 s).
- **El pulso solo marca:** no quita contador. Un pulso con el Debug activo sobre un núcleo **ya marcado refresca la marca** a su duración entera (no se acumula). **Sin el Debug no la refresca** (chispa gris en el núcleo, marca intacta): así cada marca exige volver a revelar, y el ciclo se repite: **Debug → pulso (marca) → láser (daño) → la marca caduca → otra vez**.
- **La marca se pierde** al caducar, al cerrarse la ventana o desactivarse el núcleo (el jefe sube), al cambiar de fase, en el golpe final y al reaparecer Isak (reaparición por fase). Con el Debug activo la cuenta atrás va a la mitad en tiempo real (es tiempo del mundo): mantener el Debug alarga la marca, pero cuesta energía y quita el dash.
- **El dash nunca hace daño** (`propuesta-1-3.md` §2.2: no aturde ni daña). Atraviesa el cuerpo del jefe (no es sólido), los banners, las ondas y los proyectiles, siempre que Isak sea invulnerable. No se combina con el Debug, y de ahí sale la tensión de la pelea: **esquivar** (dash) o **ver y marcar** (Debug), nunca las dos cosas a la vez. Con la marca, la tensión se reparte: tras marcar se puede soltar el Debug y volver a tener el dash mientras se dispara. Es el patrón futuro «Deslizar el núcleo» de `propuesta-1-3.md` §4.
- **El Debug como ayuda:** todos los ataques del jefe van en **tiempo del mundo**, así que con el Debug activo van a la mitad de velocidad. Las ventanas y la marca también se alargan en tiempo real (y por eso pueden salir caras de energía: §2.4).
- **Isak:** cada golpe del jefe resta **−10 de Sync Rate** (como todos los enemigos del Mundo 1), con el retroceso y la invulnerabilidad de siempre. Con Sync 100 aguanta 10 golpes por vida.

#### 2.3.1 Telegrafía y sonido de la marca (2026-10-21)

- **Halo de la marca** (arte provisional por script, dibujado por `WeakPoint`, valores en `data/weak_point.json`): con la marca, el núcleo se dibuja **a plena intensidad aunque el Debug esté apagado**, con un **anillo exterior de 8 segmentos** en `banner_blanco` separado del núcleo por el contorno oscuro. Los segmentos se **apagan uno a uno en sentido horario** según el tiempo que queda (cuenta atrás legible por la forma, no por el color) y, en el **último segundo** del mundo, el halo **parpadea** (rítmico, como el aviso de las plataformas del 1-3). Al marcar, un destello breve del halo; al caducar, el halo desaparece y el núcleo vuelve a estar oculto (o revelado si el Debug sigue activo).
- **Sonidos propuestos** (`lista-sonidos.md` §4; sin audio todavía, señales ya emitidas por `WeakPoint`): `sfx_weak_point_mark` (marca y refresco, señal `marked`), `sfx_weak_point_mark_warn` (último segundo, señal `mark_warning`; **accesibilidad**: avisa de que la marca se acaba sin mirar el halo) y `sfx_weak_point_mark_end` (caduca, señal `mark_expired`). El golpe sigue siendo `sfx_weak_point_hit`.

### 2.4 Energía: números reales y solución (aprobado el 2026-10-20)

> **Actualizado el 2026-10-21 (la marca):** §2.4.1-§2.4.6 son el análisis del 2026-10-20 con la regla anterior (daño solo con el Debug activo, pulso gratis como daño). **Los números vigentes están en §2.4.7**: con la marca el daño cuesta láseres, el Debug baja a `debug_drain_scale` **0,25** y los 4 cargadores de 4 s se mantienen. Lo que sigue se conserva como historia del razonamiento.

El usuario temía que la regla «solo daña el núcleo con el Debug activo» hiciera la pelea imposible por falta de energía. Se ha comprobado con los valores del código y una simulación por fases. **Conclusión: con los dos cargadores de esquina (10 s) y el gasto normal del Debug, una pelea torpe no cabe en la barra en la fase 2 y obliga a pasar casi un tercio del combate corriendo a recargar. Se resuelve con 4 cargadores de arena (4 s) y el Debug a mitad de gasto dentro de la arena.**

#### 2.4.1 Valores de partida (del código y los datos)

| Concepto | Valor | Fuente |
|---|---|---|
| Energía máxima | **100** sin mejoras. Caché: 110 / 120 (Energía 2-3). Kernel: 130 (Energía 4). Raíz: 130 + Energía 5 (0,5 % del máximo por segundo, 3 s después del último gasto y **nunca con el Debug activo**) | `data/upgrades.json`, `data/passive_regen.json` |
| Debug: activación | Mantener 1,0 s (0,4 s con Debug 5, Raíz). **La carga no gasta**; soltar antes cancela sin coste | `data/debug_mode.json`, `debug_mode.gd` |
| Debug: gasto | **Continuo, 20 por segundo real** (15 con Debug 2) mientras está activo. Se apaga con otra pulsación o al llegar a 0. Volver a activarlo exige otra carga de 1 s | `debug_mode.gd` (`step`) |
| Debug: tiempo | Mundo ×0,5 (×0,4 con Debug 4). **Una ventana de 5 s del mundo dura 10 s reales con el Debug: 200 de energía si se mantiene entera** | `data/debug_mode.json` |
| Pulso | 0 | `data/isak_abilities.json` |
| Láser | 10 por disparo (8 con Láser 3), daño 1 (2 con Láser 4) | `data/isak_abilities.json` |
| Dash | 10 por dash, enfriamiento 0,5 s | `data/isak_abilities.json` (`dash`) |
| Cargador | +50 al tocarlo, reutilizable; `cooldown_s` por instancia (10 s en el 1-2 y el 1-3; 20 s por defecto y en el hub) | `scripts/levels/charger.gd`, `data/levels/1-3.json` |
| Burbuja | Vida 2: dos láseres (−20) para soltar +25 → **neto +5** (+15 con Láser 4, un disparo) | `data/enemies/alert_bubble.json` |
| Cambio de fase | El jefe suelta +25 de energía y +25 de Sync | esta propuesta |
| Reaparición | Energía = la que tenía o 50, lo que sea mayor (decisión 3) | esta propuesta |

#### 2.4.2 Supuestos de la simulación (Caché, sin mejoras)

- **Pelea ideal (bot):** el Debug se activa ya con el núcleo a tiro y se apaga tras golpear. Activo ≈ 0,15 s de entrada + 0,33 s por pulso + 0,2 s de reacción: **1,0 s** para 2 golpes y **0,7 s** para 1. En la fase 3 hay que mirar cuál es la real y llegar hasta ella sin dash (plataformas al compás, que con el Debug va a la mitad): **2,0 s** por ventana. Fase 1: 2 ventanas, 2 dashes, una Burbuja rematada (2 láseres, +25). Fase 2: 2 ventanas, 3 dashes, 1 láser. Fase 3: 3 ventanas, 9 dashes (tres lanzamientos por ronda).
- **Pelea torpe:** activa el Debug al abrirse la ventana y lo mantiene hasta acertar y un poco más: **3,0 s** por ventana (3,5 s en la fase 3), una activación antes de tiempo en la fase 1 (2 s), una ventana perdida por fase (4 ventanas en las fases 2 y 3), 3 s de Debug para ver a través de los pop-ups en la fase 2, una copia equivocada en la fase 3 (su Burbuja, rematada), y 1,5 veces los dashes de la ideal. Duración: 70 / 80 / 90 s.
- **Pico por ventana:** lo que se gasta seguido entre dos ocasiones de recargar (Debug de la ventana + dashes y láseres alrededor). Con la barra base llena tiene que quedar **margen ≥ 20**: pico ≤ 80.
- **Desvío:** tiempo extra yendo y volviendo de un cargador. Esquinas (1 y 22): ~10 tiles desde el centro, **3,6 s** ida y vuelta corriendo. Cuatro en el suelo (1, 8, 15, 22): **1,3 s** como mucho.

#### 2.4.3 Resultado con el diseño anterior (Debug 20/s, 2 cargadores de esquina, 10 s)

| | Fase 1 | Fase 2 | Fase 3 | Total |
|---|---|---|---|---|
| **Ideal:** Debug activo (s reales) | 1,7 | 1,7 | 6,0 | 9,4 |
| Ideal: gasto (Debug + dash + láser) | 74 | 74 | 210 | 358 |
| Ideal: cargas de 50 necesarias | 0 | 1 | 3 | 4 |
| Ideal: pico por ventana | 40 | 50 | 70 | — |
| Ideal: desvío a las esquinas | 0 s | 3,6 s | **10,8 s** (31 % de la fase) | 14,4 s |
| **Torpe:** Debug activo (s reales) | 11 | 15 | 14 | 40 |
| Torpe: gasto | 310 | 390 | 420 | 1120 |
| Torpe: cargas de 50 necesarias | 4 | 7 | 8 | **19** |
| Torpe: pico por ventana | **100** | **120** | **100** | — |
| Torpe: desvío a las esquinas | 14 s | 25 s | 29 s | **68 s** (28 % de la pelea) |

**Diagnóstico:** (1) el pico torpe de la fase 2 (120) **no cabe en la barra de 100**: aun saliendo lleno del cargador, el Debug se corta a mitad de la ventana. Esa es la sensación de «imposible». En las fases 1 y 3 el margen es 0. (2) Incluso la pelea ideal pasa un tercio de la fase 3 corriendo a las esquinas. (3) La pelea torpe necesita 19 recargas y más de un minuto de carreras.

#### 2.4.4 Opciones comparadas (pelea torpe, Caché, barra de 100)

| Opción | Pico F1 / F2 / F3 | Cargas | Desvío total | Veredicto |
|---|---|---|---|---|
| Diseño anterior (2 esquinas, 10 s, Debug 20/s) | 100 / 120 / 100 | 19 | 68 s | Injusto: la fase 2 no cabe |
| Solo cargadores: 4 en el suelo, 4 s, Debug 20/s | 100 / 120 / 100 | 19 | 25 s | Arregla las carreras, **no el pico** |
| Solo Debug a mitad (10/s), 2 esquinas, 10 s | 70 / 75 / 65 | 11 | 40 s | Arregla el pico, sigue corriendo mucho |
| **4 cargadores en el suelo, 4 s + Debug a mitad (10/s)** | **70 / 75 / 65** | **11** | **14 s** | **Elegida**: margen ≥ 25 y carreras cortas |
| Debug sin gasto en la arena | 40 / 30 / 30 | ~3 | ~4 s | Sobra margen, pero se pierde «gastar con inteligencia»; queda de reserva |

Más cargadores no bastan: el problema de fondo es que el Debug, con el mundo a ×0,5, cuesta el doble por segundo de ventana. Y quitar el gasto del todo borra la idea de la ficha. La solución mínima que garantiza el margen es **las dos medidas juntas**.

#### 2.4.5 Solución elegida el 2026-10-20 (con la marca, el Debug pasa a 0,25: §2.4.7)

1. **Cuatro cargadores de arena** en el suelo, columnas 1, 8, 15 y 22 (§2.2): +50, reutilizables y con un **enfriamiento de 4 s** solo en esta arena. Es `cooldown_s` por instancia: no hace falta código nuevo.
2. **El Debug gasta la mitad dentro de la arena:** campo de nivel **`debug_drain_scale: 0.5`** en `data/levels/1-boss.json`, que multiplica `DebugMode.get_drain_per_second()` (20 → **10/s**; con Debug 2, 15 → 7,5/s). Solo lo tiene el nivel del jefe (por defecto 1,0 en todos los demás). Sin texto ni aviso: la barra simplemente baja más despacio. La activación (1 s) y la regla «Debug y dash no se combinan» no cambian.
3. **Se mantienen:** las recargas de +25 de cada cambio de fase, los drops de las Burbujas y la reaparición con ≥ 50 de energía.
4. **Palanca de reserva (solo datos):** si al jugar sigue siendo injusto, primero `debug_drain_scale` 0,25 y, como último recurso, 0 (Debug sin gasto en la arena).

**Resultado (Caché, sin mejoras, Debug a 10/s y 4 cargadores de 4 s):**

| | Fase 1 | Fase 2 | Fase 3 | Total |
|---|---|---|---|---|
| Ideal: gasto | 57 | 57 | 150 | 264 |
| Ideal: cargas / energía al terminar la fase | 0 / 68 | 0 / 36 | 3 / 61 | 3 |
| Ideal: pico por ventana (margen) | 30 (70) | 40 (60) | 50 (50) | — |
| Ideal: desvío | 0 s | 0 s | 3,9 s | 3,9 s |
| Torpe: gasto | 200 | 240 | 280 | 720 |
| Torpe: cargas / energía al terminar la fase | 2 / 50 | 4 / 35 | 5 / 55 | 11 |
| Torpe: pico por ventana (margen) | 70 (30) | **75 (25)** | 65 (35) | — |
| Torpe: desvío | 2,6 s | 5,2 s | 6,5 s | **14 s** (6 % de la pelea) |

La ideal solo recarga en la fase 3 y la torpe tiene siempre al menos 25 de margen. Los cargadores nunca limitan: cuatro con 4 s dan hasta 50 de energía por segundo y la pelea torpe gasta unos 3 por segundo.

#### 2.4.6 Kernel y Raíz (misma lógica)

La base garantizada sigue siendo **100 sin mejoras**: las mejoras ayudan, pero nunca son requisito. La dificultad sube por los patrones (§2.12), no por la energía.

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Golpes | 9 (3/3/3) | 12 (4/4/4) | 12 (4/4/4) |
| Tope de energía con las mejoras del acceso | 120 | 130 | 130 + Energía 5 (0,65/s, nunca con el Debug) |
| Debug en la arena | 10/s (×0,5) | 10/s (×0,5) | 10/s (×0,5) |
| Cargadores | 4 en el suelo, 4 s | 4 en el suelo, 5 s | 4 en el suelo, 6 s |
| Ventana torpe | 3,0-4,5 s de Debug | 3,0-3,5 s (el núcleo está detrás: el dash va antes de activar el Debug) | 4,0 s (el núcleo cambia de copia al activar el Debug) |
| Pico torpe por ventana (margen sobre 100) | 75 (25) | 70 (30) | 80 (**20**, el mínimo aceptado) |
| Gasto torpe total / cargas de 50 | 720 / 11 | ~930 / ~14 | ~1110 / ~17 |
| Duración torpe aproximada | 4 min | 5 min | 5,5 min |

En Raíz el margen queda justo en 20: es el acceso más exigente, a propósito. Si al jugar el margen no basta, se baja `debug_drain_scale` de ese acceso (por `laps`) antes de tocar los patrones. El enfriamiento más largo de Kernel y Raíz solo obliga a ir al segundo cargador más cercano (≤ 7 tiles) si el primero se acaba de usar.

**Validador (§4.2):** comprueba con la barra base (100), con `--access-cap` y con todo al máximo que el pico de la pelea torpe por ventana sea ≤ máximo − 20, que cada celda del suelo tenga un cargador a ≤ 4 tiles, y el presupuesto por fase con cargas, recargas y drops.

#### 2.4.7 Energía con la marca (2026-10-21, vigente)

**Qué cambia:** el Debug solo sirve para **localizar y marcar** (activo ≈ 0,7 s por marca en la pelea ideal), pero el pulso ya no hace daño: **todo el daño es láser**, 10 de energía por golpe. En Caché eso son **9 láseres como mínimo (90)**, y la pelea torpe falla disparos (láser antes de marcar, contra el cuerpo o con la marca ya caducada). El gasto se mueve del Debug al láser, y el láser va **dentro de la ventana**, donde no se puede recargar (en la fase 2 el núcleo está en una plataforma; en la fase 3, tras los lanzamientos). Por eso el pico por ventana **sube** aunque el Debug se use menos.

**Supuestos (Caché, sin mejoras; simulación por segmentos «entre dos ocasiones de recargar», con recarga al cargador si la energía no cubre el segmento + 20, desvío de 1,3 s por carga):**

- **Ideal:** fase 1, una ventana (Debug 0,7 s, 3 láseres; antes 2 dashes y remata una Burbuja con 2 láseres, +25). Fase 2, dos ventanas (2 + 1 golpes; Debug 0,7 s cada una; 3 dashes). Fase 3, dos rondas (2 + 1 golpes; Debug 2,0 s por ronda para mirar, subir al compás y marcar; 3 dashes por ronda de lanzamientos).
- **Torpe:** Debug **3,0 s por ventana** (3,5 s en la fase 3: lo mantiene mientras dispara), **un fallo de láser por ventana** además de los golpes, **una ventana perdida por fase** (la marca caduca o el Debug se activa antes de tiempo: +2 s en la fase 1; +3 s de Debug para ver a través de los pop-ups en la fase 2; la copia equivocada en la fase 3, con su Burbuja rematada), 1 dash antes de cada ventana de las fases 1 y 2 y los 3 lanzamientos esquivados con dash antes de cada ronda de la fase 3. Ventanas: 4 / 4 / 4 (fase 1: 1 perdida + 2 + 1 golpes; fase 2: 1 perdida + 1 + 1 + 1; fase 3: 1 perdida + 1 + 1 + 1).

**Resultado (pico por ventana y margen sobre 100; gasto total y cargas de 50):**

| Opción (4 cargadores de 4 s) | Ideal: picos F1 / F2 / F3 | Torpe: picos F1 / F2 / F3 (margen mínimo) | Torpe: gasto / cargas / desvío | Veredicto |
|---|---|---|---|---|
| Debug a gasto normal (20/s) | 44 / 54 / 90 | 120 / 150 / 120 (**−50**) | 1250 / 26 / 34 s | Imposible |
| **Debug a mitad (10/s), lo aprobado el 2026-10-20** | 40 / 47 / 70 | 70 / **90** / 85 (**10**) | 850 / 16 / 21 s | **Ya no basta**: la fase 2 torpe queda con 10 |
| **Debug a un cuarto (5/s)** | 40 / 44 / 60 | 55 / 60 / 68 (**33**) | 650 / 12 / 16 s | **Elegida**: margen ≥ 25 en todas las fases |
| Debug sin gasto (0/s) | 40 / 40 / 50 | 40 / 30 / 50 (50) | 450 / 6 / 8 s | Sobra margen; el Debug deja de costar. Reserva |

**Decisión:** **`debug_drain_scale` baja de 0,5 a 0,25** en la arena (20 → **5/s**; con Debug 2, 15 → 3,75/s). Es el primer escalón de la «palanca de reserva» que ya preveía §2.4.5, ahora necesario. El Debug sigue costando (y quita el dash), pero lo caro pasa a ser fallar láseres. Parámetro: `debug_drain_scale` del nivel (`data/levels/1-boss.json` al construir la arena; la sala `boss_test` ya lo lleva).

**Cargadores: no se relajan.** La pelea torpe necesita **12 cargas de 50** en Caché (antes 11) porque los 90 de láser son obligatorios. Con 2 cargadores de esquina de 10 s el desvío volvería a ~43 s (12 × 3,6 s); con 4 de 4 s se queda en **16 s** (7 % de la pelea). Se mantienen los 4 en el suelo con 4 s (5 s Kernel, 6 s Raíz).

**Kernel y Raíz (misma simulación, 12 golpes, base 100 sin mejoras):**

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Marca | 4 s (≈ 5 disparos) | 3 s (≈ 4) | 2,5 s (≈ 3) |
| Debug en la arena | 5/s (×0,25) | 5/s (×0,25) | 5/s (×0,25) |
| Lanzamientos por ronda en la fase 3 | 3 | 3 | **3** (4 copias; decisión del usuario del 2026-10-21) |
| Pico torpe por ventana (margen) | 68 (**33**) | 78 (**22**, ≥ 20) | ~~93 (8) con 4 lanzamientos~~ **80 (20)** con 3 |
| Gasto torpe / cargas | 650 / 12 | ~785 / ~15 | ~885 / ~18 |

**Raíz (decisión del usuario del 2026-10-21):** la fase 3 usa **3 lanzamientos por ronda en vez de 4** (sigue habiendo 4 copias; la cuarta no se lanza), con `debug_drain_scale` 0,25 como en los otros accesos. El resto de decisiones de energía (4 cargadores, 0,25, la marca) no cambia. **Recalculado con el validador de arenas** (`tools/validate_boss.py`, paso 5; picos torpes F1 / F2 / F3 con la barra base): Caché 55 / 60 / 67,5 (margen 32,5), Kernel 55 / 70 / 77,5 (22,5) y Raíz 55 / 70 / **80 (20, justo el mínimo)**; con 4 lanzamientos Raíz daba 90 (10). El validador usa 4,0 s de Debug por ventana en la fase 3 de Raíz (§2.4.6); la estimación anterior de 93 con 4 lanzamientos incluía algo más de Debug, así que con 3 la cifra coincide con el mínimo aceptado. Kernel cumple el margen de 20 de su acceso. El Láser 4 (2 golpes por disparo, desde Kernel) reduce mucho el gasto, pero nunca es requisito.

**Duración:** como la marca vale varios disparos, la pelea ideal necesita menos ventanas (fase 1: una; fases 2 y 3: dos), unos 20-30 s menos que la estimación de §2.12. Si al jugar la pelea se queda corta, la palanca es por datos y sin tocar la regla: bajar `mark_duration_s` (con 2,5 s caben unos 3 disparos) o alargar los ataques entre ventanas. **No** se limita el número de golpes por marca.

### 2.5 Fase 1 «99+»: notificaciones que llegan (99+ → 66)

**Qué enseña:** que el núcleo existe, que se ve con el Debug y que hay que gastar con cabeza. Repite los patrones 7 («Cortina») y 6 («Esquivar») del 1-3.

| Ataque | Telegrafiado | Cómo se responde | Mecánica reutilizada |
|---|---|---|---|
| **Lanzar Burbujas:** el jefe escupe 2 Burbujas que caen en las plataformas laterales y patrullan. Nunca hay más de 2 vivas. | El «99+» se infla y una flecha `alerta` marca dónde caerán, 9 cuadros antes. | Pulso (aturdidas 3 s) y, si se quiere energía, dos disparos de láser (+25, neto +5). | `alert_bubble` (vida 2, contacto −10) |
| **Barrido:** un banner barre el carril del suelo o el alto, uno cada vez, cada 3 s. | El aviso de 9 cuadros en la ranura del muro y en el suelo, como `spam_banner`. | Cambiar de carril (saltar a la plataforma o bajar) o atravesarlo con el dash. | `spam_banner` (640 px/s, −10) |

**Ventana:** cuando las **2 Burbujas están aturdidas o derrotadas a la vez**, el jefe se queda «sin notificaciones que enviar»: se desinfla y **baja al suelo** del centro (columnas 10-13) durante **5 s del mundo** (≈ 10 s reales con el Debug). Mientras está abajo no hay barridos. El núcleo queda a la altura del pecho de Isak, a 1 tile del suelo: se alcanza con el pulso desde las columnas 9 o 14 y con el láser desde cualquier punto del carril del suelo. Los cargadores 2 y 3 (columnas 8 y 15) quedan a un paso para entrar lleno. **Solución (con la marca, 2026-10-21):** Debug (1 s de carga), **pulso** desde la columna 9 o 14 (marca 4 s), soltar el Debug y **láser** desde el suelo, uno tras otro, mientras dura la marca (caben unos 5 disparos; los 3 golpes de la fase caben en una ventana bien aprovechada). Si la marca caduca y la ventana sigue abierta, otra vez Debug y pulso. Al cerrarse la ventana (la marca se pierde), el jefe sube y lanza 2 Burbujas nuevas. **3 golpes** para pasar de fase: 1 ventana si se aprovecha bien, 2-3 si no.

### 2.6 Fase 2 «66»: no veas nada (66 → 33)

**Qué enseña:** el pop-up translúcido del 1-2 (pulso a su botón; el Debug ve a través) y el dash del 1-3 contra los proyectiles. La ficha original: «Cubre la pantalla con pop-ups que tapan la vista. Hay que cerrarlos con el pulso y esquivar con dash».

| Ataque | Telegrafiado | Cómo se responde | Mecánica reutilizada |
|---|---|---|---|
| **Lluvia de pop-ups:** cada 6 s aparece un pop-up translúcido (70 %) que tapa un cuarto de la arena durante 8 s. Hay como mucho 2 a la vez y nunca tapan el mismo cuarto que Isak cuando aparecen. | Contorno punteado `banner_blanco` 9 cuadros antes. | Pulso a su botón de 24 px (siempre a la altura de un carril) para cerrarlo, o el Debug para ver a través (baja al 15 %). | `overlay_popup` |
| **Ráfaga de notificaciones:** tres notificaciones pequeñas (proyectiles de 1 × 0,5 tiles) cruzan un carril a 640 px/s, separadas 0,5 s. | Flecha `alerta` en el muro de entrada y una línea discontinua por el carril, 9 cuadros antes. | Dash a través (invulnerable 0,3 s), o cambiar de carril. Con el Debug activo no hay dash: se salta. | Proyectil nuevo, `notification_shot` (familia del banner) |

**Ventana:** cada 12 s el jefe baja a una plataforma lateral (la que queda lejos de Isak). Allí se protege con un **pop-up escudo**: un `overlay_popup` opaco sobre el núcleo, con el botón de cerrar abajo, alcanzable con el pulso desde esa plataforma. **Solución (con la marca):** subir a la plataforma (dash o salto para esquivar la ráfaga), **pulso** al botón (el escudo cae), **Debug**, **pulso** al núcleo (marca) y **láser** desde la misma plataforma, antes de que acabe la ventana de 4 s del mundo. Si no da tiempo, el jefe se vuelve a cubrir, sube y la marca se pierde. **La decisión de la fase:** con el Debug activo se ve a través de los pop-ups y el jefe (y la marca) van más lentos, pero no hay dash; tras marcar se puede soltar el Debug para recuperar el dash. **3 golpes**: 2 ventanas (2 + 1), 3-4 si no.

### 2.7 Fase 3 «33»: ¿cuál es la de verdad? (33 → 0)

**Qué enseña:** todo el 1-3 a la vez, con el ritmo como base. La ficha original: «Aparecen notificaciones falsas, copias del jefe. Solo la real tiene núcleo bajo el Debug».

- **Metrónomo de la fase:** al entrar en la fase 3 arranca un `rhythm_zone` en toda la arena (tiempo del mundo, ciclo de **2,0 s**, sin aceleración en Caché), con el icono de vibración en el fondo y el tic de accesibilidad (`sfx_metronome_tick`, activado por defecto).
- **Plataformas que parpadean:** las dos laterales pasan a ser `blink_platform`, grupos A y B alternos, con 4 segmentos y aviso de 9 cuadros. La central sigue fija: es el refugio en alto. Los cargadores están en el suelo: no les afecta el parpadeo.
- **Campanas:** 3 `alarm_bell` en el techo (columnas 5, 11 y 18). Cada una suena en su desfase del compás: aviso de 9 cuadros y una onda de 1 tile de ancho hasta el suelo durante 0,4 s. Nunca suenan dos campanas en el mismo tiempo del compás, así que siempre queda un hueco seguro.

| Ataque | Telegrafiado | Cómo se responde |
|---|---|---|
| **Copias:** el jefe se divide en 3 badges iguales (la real y 2 copias) que bajan a tres sitios: plataforma izquierda, suelo del centro y plataforma derecha. | Las tres se inflan 0,75 s antes de bajar y aterrizan en un compás. | Debug: solo la real muestra el núcleo carmín (`WeakPoint` ya funciona así). |
| **Lanzamiento:** las tres se lanzan contra Isak, una por compás, como el punto rojo (se inflan 9 cuadros y se lanzan 0,3 s). | El inflado y una línea `alerta` hacia Isak. | Dash a través (patrón 6, «Esquivar y contraatacar»), o saltar. |

**Ventana:** tras los tres lanzamientos, las copias se quedan quietas 5 s del mundo en sus sitios. **Solución (con la marca):** Debug (el núcleo delata a la real; con el Debug también van más lentas las campanas), **ir hasta ella sin usar el dash** (pisando las plataformas encendidas o desde el suelo), **pulso** (marca) y **láser** desde su mismo carril. Quien prefiera ahorrar puede mirar, apagar el Debug, ir y volver a activarlo junto a la real (la carga no gasta). La marca solo se pone en la real: las copias no tienen núcleo. Si Isak golpea una copia (pulso o láser), esta **se descarta con un «pop» y suelta una Burbuja** (decisión 6): cuesta tiempo y energía, no Sync. Después las tres vuelven a subir y se mezclan (la marca se pierde). **3 golpes**: 2 rondas (2 + 1), 3-4 si no. **El último es el golpe final** (§2.8).

### 2.8 Final: el golpe final (decisión 1, aprobada: sin rollback)

El noveno golpe (11 → **0**) cierra la pelea. No hay escena de rollback ni de copia: la última fase termina con el golpe final.

1. **Impacto:** congelación breve de 0,3 s (tiempo real) sobre el golpe y el contador queda en **0**. La barra del jefe se vacía.
2. **Todo se detiene:** las copias que queden se descartan con su «pop» (sin soltar Burbujas), las campanas callan, el metrónomo se para y las plataformas que parpadean quedan encendidas. Se borran los proyectiles y los pop-ups en pantalla. Desde aquí Isak ya no puede recibir daño.
3. **Desarme:** el badge se desinfla, el «0» se apaga y el jefe se desarma en píxeles (`sfx_boss_defeat`). Opcional, una línea breve del sistema sin pausa (por escribir, §2.1).
4. **Recompensa** (§3.3): escena de recuerdo, línea de Eco «ya sin tanta amabilidad» y vórtice de salida al hub.

No toca `GameState`, el guardado ni la Papelera más allá de lo que hace cualquier final de nivel (`completed_levels`, la capa del recuerdo sin guardar).

### 2.9 Muerte, reaparición y game over (decisión 3, aprobada)

- **Reaparición por fase:** morir con vidas resta una e Isak reaparece por el vórtice de llegada (2, 9), con Sync al 100 % y **la energía que tenía o 50, lo que sea mayor** (anti-atasco: la fase exige el Debug). El jefe vuelve al **principio de la fase actual**: el contador queda en 99+, 66 o 33 y desaparecen sus Burbujas, pop-ups y copias. Los cargadores vuelven a estar listos. Equivale a un punto de sincronización por fase, sin objeto en el mapa.
- **Game over (0 vidas):** el de siempre (`apply_rollback`). No hay regla especial para el jefe.
- **R (reiniciar):** reinicia la pelea entera desde la fase 1, como en cualquier mapa.

### 2.10 Ayuda de Eco con Q (PROPUESTA)

Tipos nuevos de `data/help.json` (`world: 1`, categoría Enemigo salvo que se diga), con ficha del álbum. **Textos de Eco por escribir con el usuario**, breves y sin teclas:

| Tipo | Idea del texto (no definitivo) |
|---|---|
| `alert_major` | «Es la alerta de todas las alertas. Tiene un núcleo, pero solo se ve con el Debug. Márcalo con el pulso y dispárale mientras brille.» |
| `boss_popup_shield` (Objeto) | «Se tapa con un pop-up. Ciérralo con el pulso y tendrás unos segundos.» |
| `alert_major_clone` | «Copias. Solo una tiene núcleo: mira con el Debug antes de marcar.» |
| `notification_shot` | «Notificaciones en ráfaga. Deslízate a través o cambia de altura.» |

Los tipos reutilizados (Burbuja, banner, pop-up translúcido, campana, plataforma que parpadea, cargador) ya están aprendidos desde el 1-1, el 1-2 y el 1-3: no sale Q, solo la relectura. La Q pausa el juego como siempre, así que preguntar en mitad de la pelea es seguro. Con «Ayudas de Eco: Ocultar» no sale ninguna.

### 2.11 Cómo lo prepara el 1-3 (y el 1-2)

| Lo que pide el jefe | Dónde se aprendió |
|---|---|
| Cambiar de carril o atravesar un banner con el dash | 1-3, Tramo 1 (banner obligatorio, nichos) |
| Aturdir Burbujas y luego dash a través del barrido | 1-3, Tramo 3, patrón 7 «Cortina» |
| Dash a través de un lanzamiento y contraatacar | 1-3, Tramo 3, patrón 6 (punto rojo) |
| Pisar plataformas que parpadean al compás | 1-3, Tramo 2 (metrónomo) |
| Leer el aviso de una campana y esquivar su onda | 1-3, Tramo 4 (túnel de alarmas) |
| «Lo que importa solo se ve con el Debug» | 1-3, secreto «Excepciones» (pared visible solo con el Debug); 1-2, plataforma oculta |
| Cerrar un pop-up con el pulso y ver a través con el Debug | 1-2, pop-ups translúcidos (pisos 1, 3 y 4) |
| Gestionar la energía con cargadores y drops | 1-2 y 1-3 (cargadores, drops de +25) |
| Debug y dash no se combinan | 1-3 (chispa gris al intentar el dash con el Debug) |

### 2.12 Duración y dificultad

- **Objetivo:** unos **3-4 minutos** el primer intento que se gana (`target_duration_s` **240**). La solución ideal (bot) dura unos **100-130 s**: intro de 10 s, fase 1 de 30 s, fase 2 de 35 s, fase 3 de 35 s y final de 10 s. Dificultad **3,5 de 5** dentro del mundo: la cima del Mundo 1, un poco por encima del 1-3.
- **Ventanas:** se aplica la fórmula de `propuesta-1-2.md` §0.1 con k = 2 (dificultad 3). Ventana ≥ 2 × (recorrido hasta el núcleo + 1 s de carga del Debug + pose del pulso que marca + primer láser). Por ejemplo, en la fase 1: 2 × (1 s + 1 s + 0,33 s + 0,35 s) ≈ 5,4 s; con el Debug activo durante la marca la ventana de 5 s del mundo dura más en tiempo real, así que cabe (PROPUESTA: si el validador lo pide, ventana de 5,5 s). La marca, a su vez, debe permitir al menos 2 disparos: ≥ 0,33 + 2 × 0,7 ≈ 1,8 s (Raíz 2,5 s cumple).
- **Por acceso (PROPUESTA; se cierra al hacer Kernel y Raíz, como el resto de vueltas):** el jugador solo ve «Acceso: Kernel» o «Acceso: Raíz». Ningún texto dice vuelta ni dificultad. Lo decidido es que «los puntos débiles cambian en cada vuelta». La energía de cada acceso está en §2.4.6.

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Golpes | 9 (3/3/3) | 12 (4/4/4) | 12 (4/4/4) |
| Núcleo | Abajo, de frente | **Detrás** (el «botón de descartar» de la espalda): hay que atravesar el lanzamiento con el dash para quedar detrás | Cambia de copia cuando se activa el Debug (una vez por ventana) |
| Fase 1 | 2 Burbujas | 2 Burbujas + 1 punto rojo | 2 Burbujas + 2 puntos rojos |
| Fase 2 | 2 pop-ups a la vez | 3 a la vez | 3, y la ráfaga en los dos carriles alternos |
| Fase 3 | Compás de 2,0 s fijo | 2,0 → 1,6 s | 2,0 → 1,6 → 1,4 s y 4 copias, **3 lanzamientos por ronda** (decisión del 2026-10-21) |
| Energía en la arena (§2.4.7) | Debug ×0,25; 4 cargadores de 4 s | Debug ×0,25; 4 cargadores de 5 s | Debug ×0,25; 4 cargadores de 6 s |
| Marca (`mark_duration_s`) | 4 s | 3 s | 2,5 s |
| Ocultarte | No existe | Sin efecto en el jefe (recomendado) | Sin efecto |

---

## 3. Cómo se vence

### 3.1 Solución ideal, paso a paso (Caché, sin mejoras)

1. **Llegada:** Isak llega por el vórtice. El «99+» se infla (`sfx_boss1_intro`) y sale la línea de intro (pausa). Al cerrarla empieza la fase 1.
2. **Fase 1, primera ventana:** el jefe escupe 2 Burbujas a las plataformas. Isak sube a la plataforma izquierda y aturde la Burbuja con el pulso. El banner barre el suelo y él sigue en lo alto. Baja con un dash que atraviesa el siguiente barrido, sube a la plataforma derecha y aturde la segunda Burbuja. Ventana: el jefe baja al centro. Isak se pone en la columna 9, mantiene el Debug (1 s), lanza un pulso que **marca** el núcleo y suelta el Debug (≈ 4 de energía con el gasto de la arena). Con la marca (4 s), tres láseres seguidos: golpe 1 → 88, golpe 2 → 77, golpe 3 → **66** (30 de energía). El jefe suelta las 2 recargas de cambio de fase.
3. **Energía de la fase 1:** antes de la ventana remató una Burbuja con dos disparos (+25 de energía) y aturdió la otra; si la marca caduca antes del tercer golpe, vuelve a revelar y marcar en la misma ventana (o en la siguiente).
4. **Fase 2:** aparece el primer pop-up. Isak lo cierra con el pulso si tapa su carril, o lo ignora. Llega la ráfaga por el suelo: dash a través. El jefe baja a la plataforma derecha con el escudo. Isak sube, lanza un pulso al botón (cae el escudo), activa el Debug, marca el núcleo con otro pulso y dispara el láser (golpe 4 → 55; golpe 5 → 44) antes de que suba. En la siguiente ventana, en la plataforma izquierda: pulso al botón, Debug, pulso (marca) y láser (golpe 6 → **33**). Recarga una vez entre ventanas en un cargador del suelo.
5. **Fase 3:** arrancan el metrónomo, las campanas y las plataformas que parpadean. Bajan las 3 copias. Isak atraviesa con el dash los tres lanzamientos, uno por compás, desde el suelo del centro, entre ondas, y toca el cargador 2 o 3 de paso. Ventana: Debug. El núcleo está en la de la plataforma derecha. Sube cuando la plataforma B se enciende (con el Debug, el compás va a la mitad), la marca con el pulso y le dispara dos láseres (golpe 7 → 22, golpe 8 → 11). En la ronda siguiente, recargando de paso, otra vez Debug, pulso y láser (golpe 9 → **0**).
6. **Final:** el noveno golpe es el golpe final (§2.8): todo se detiene y el jefe se desarma en píxeles.

### 3.2 Errores típicos y cómo se recupera

| Error | Qué pasa | Recuperación |
|---|---|---|
| Activar el Debug antes de abrir la ventana | Gasta energía sin poder golpear (el núcleo no está a tiro). | Soltar el Debug; hay un cargador a ≤ 3,5 tiles. |
| Mantener el Debug toda la ventana | Gasta 5 por segundo y quita el dash; la marca dura más en tiempo real, pero no hace falta para disparar. | Marcar y apagarlo; la carga de 1 s para volver a activarlo no gasta. |
| Golpear el cuerpo, o el núcleo oculto | Chispa gris en el borde del cuerpo, sin daño (no delata el núcleo). La Q de `alert_major` lo explica. | Debug primero. |
| Disparar el láser al núcleo revelado sin marcarlo | Chispa gris en el núcleo, 10 de energía perdidos. | Pulso primero (marca); después, láser. |
| Esperar a que el pulso haga daño | El pulso solo marca: el contador no baja. | Láser mientras brilla el halo. |
| Dejar caducar la marca | El halo parpadea el último segundo y se apaga; el láser vuelve a sacar chispa gris. Un pulso sin el Debug no la refresca. | Volver a revelar (Debug) y marcar; o mantener el Debug, que alarga la marca. |
| Intentar el dash con el Debug activo | No sale (chispa gris, `dash_denied`). | Soltar el Debug o saltar; con el Debug, el ataque va a la mitad de velocidad. |
| Quedarse sin energía | Sin láser no hay daño (y sin Debug no se marca). | Los 4 cargadores (4 s), las Burbujas (+25) y las recargas de cambio de fase. Al reaparecer, mínimo 50. |
| Aturdir una Burbuja y tardar en la otra | La primera despierta (3 s) y la ventana no se abre. | Aturdirlas seguidas, o derrotar una con el láser y aturdir la otra. |
| Golpear una copia (fase 3) | Se descarta y suelta una Burbuja. | Volver a mirar con el Debug; esa ronda queda una copia menos. |
| Caer de una plataforma que parpadea | Sin daño (no hay pozos). | Volver a subir al compás. |
| Morir | Se pierde una vida y se reaparece al principio de la fase actual. | Con 0 vidas, game over: rollback a la última copia y Papelera. |

### 3.3 Qué pasa al vencerlo

1. **Recompensa** (paso 5 de `propuesta-recuerdos.md` §7): escena de recuerdo con el texto de la **capa Caché** del Mundo 1 (`boss_w1_l1`; borrador de tono en `propuesta-recuerdos.md` §5: el circuito en la cocina, las manos del Abuelito con la lupa, «Archivado»). Música `mus_memory`, stinger `stg_boss_defeated` y el aviso del sistema «Guarda en Notas para conservarlo». `GameState.obtain_memory(&"boss_w1_l1")` deja el recuerdo **sin guardar**, junto con las capas inferiores que falten.
2. **Eco**, ya sin tanta amabilidad: una línea importante (pausa). **Texto por escribir con el usuario.**
3. **Cierre del mundo:** `1-boss` entra en `completed_levels`. La carpeta del Mundo 1 queda `completed` (todos sus subniveles de la vuelta, jefe incluido). Isak sale por un vórtice (no hay terminal) y llega al hub.
4. **Hub:** al llegar, la **pieza cian del fondo** se recompone y se ilumina (`05-hub.md` §13.4; `sfx_hub_wallpaper_piece`). Notas lleva la placa «!» porque hay un recuerdo sin leer.
5. **Calc (PROPUESTA, opcional):** una línea LCD breve en la siguiente visita a su estación (idea: Calc nota que Eco ha perdido «un 1 %»). Sin cambios en la tienda.
6. **Siguiente mundo (decisión 8, aprobada):** el Mundo 2 se desbloquea (`m2.unlocked`). Mientras no exista el 2-1, su carpeta abre y lista «Próximamente».
7. **Revancha:** el jefe se puede repetir desde la carpeta dentro de la vuelta. Sin recompensa nueva (el recuerdo ya está).

---

## 4. Implementación: piezas

### 4.1 Piezas nuevas

| Pieza | Qué es | Notas |
|---|---|---|
| `scripts/bosses/boss_base.gd` (`BossBase`) | Base reutilizable para los 6 jefes: fases, contador (vida), golpes al núcleo, ventanas, reaparición por fase, línea de intro y de derrota, golpe final, `is_combat_active()` (la regeneración pasiva de Sync 5 se detiene) y una API de consulta para el bot (`get_phase()`, `get_window_time_left()`, `get_attack_state()`, `get_core_target()`). | Tiempo del mundo; vuelve al principio de la fase al reaparecer. |
| `scripts/bosses/alert_major.gd` (`AlertMajor`) | Máquina de estados de las fases 1-3 y el golpe final. | Valores en `data/bosses/alert_major.json` (con `_notes`, por acceso: `laps`). |
| `WeakPoint` ampliado | Oculto / revelado / **marcado** (§2.3): el pulso con el Debug activo marca (`marked`); el láser con la marca daña (`hit`), sin ella chispa gris (`deflected`); oculto no es objetivo y la chispa sale en el **cuerpo** (`set_shell_rect`). Marca en tiempo del mundo (`set_mark_duration`, `mark_warning`, `mark_expired`, `clear_mark`). | Mantiene el aspecto y la capa actuales (`data/weak_point.json`) y añade el halo de la marca. |
| `scripts/bosses/alert_major_clone.gd` | Copia de la fase 3 (lanzamiento como `notification_badge`; se descarta al golpearla y suelta una Burbuja). | |
| `scripts/bosses/notification_shot.gd` | Proyectil horizontal de la ráfaga (familia del banner: el dash lo atraviesa; el láser y el pulso no le afectan). | `help_id` `notification_shot`. |
| Pop-up escudo | `overlay_popup` con params nuevos `opaque`, `follow` (sigue al jefe) y `respawn_s`, o un tipo `boss_popup_shield`. | Mejor ampliar el existente. |
| Arena | `data/levels/1-boss.json` (24 × 12; `kind: "boss"`, `boss: "alert_major"`, **4 cargadores con `cooldown_s` 4**, **`debug_drain_scale` 0,25** (§2.4.7; antes 0,5), plataformas, campanas y `blink_platform` inactivas hasta la fase 3) y la escena `scenes/levels/1-boss.tscn` generada con `tools/build_level.py`. | Esquema: `kind`, `boss`, `debug_drain_scale` (0-1, por defecto 1) y objetos que se activan por fase (`active_in_phase`). |
| Gasto del Debug por nivel | `DebugMode.get_drain_per_second()` multiplica por el `debug_drain_scale` del nivel actual (lo fija `LevelRunner` al empezar el nivel y lo devuelve a 1,0 al salir y en el hub). | Único cambio de código fuera de los jefes. |
| HUD del jefe | Barra con el contador «99+» y las muescas de fase (`scripts/ui/boss_bar.gd`, sección `boss_bar` de `data/hud.json`). | Solo glifos de la fuente. |
| Recompensa | `BossReward` (escena de recuerdo con el texto de la capa y el aviso del sistema), compartida por todos los jefes. | Paso 5 de `propuesta-recuerdos.md`. |
| Señales | `EventBus.boss_started(id)`, `boss_phase_changed(id, phase)`, `boss_weak_point_hit(id, remaining)`, `boss_defeated(id)`. **Sin** `boss_rollback_attempted`. | El audio y el bot se enganchan aquí. |
| Hub | Entrada `1-boss` en `data/hub.json` (prefijo «Jefe: », sin puntos), desbloqueo del Mundo 2 al vencer y la pieza cian del fondo. | `HubWorlds`, `FolderPanel`. |
| Ayudas y álbum | 4 tipos de §2.10 en `data/help.json` y sus fichas (`tools/gen_album_cards.py`). | Textos propuestos. |
| Arte (por script, **sin AutoSprite**) | `tools/gen_boss_alert_major.py` (validador `tools/validate_boss_alert_major.py`): badge de 256 × 256 con los estados reposo, inflarse, escupir, bajar, desinflado, escudo, dividirse, golpeado y desarme en píxeles; las copias (la misma hoja con otro contorno); la notificación-proyectil; el pop-up escudo; la barra del jefe; el fondo de pantalla de bloqueo con relojes grandes. Paleta `mundo1.gpl`, con `carmin` solo en el núcleo. | Sufijo `_placeholder` (regla 3 de `CLAUDE.md`), salvo que el usuario aporte arte o autorice AutoSprite. |

**Sonidos** (IDs de `lista-sonidos.md`; se conectan en `data/audio.json` a las señales nuevas, y si falta el archivo hay silencio):

| ID | Cuándo |
|---|---|
| `sfx_boss1_intro` | `boss_started` (el 99+ se infla) |
| `sfx_boss1_launch` | Escupir Burbujas y lanzar barridos (fase 1) |
| `sfx_boss1_popup_storm` | Lluvia de pop-ups (fase 2) |
| `sfx_boss1_clones` | Dividirse en copias (fase 3). Pista sonora **opcional**: la señal visual (el núcleo con el Debug) es la que manda (`lista-sonidos.md` §12) |
| `sfx_boss_phase_change` | `boss_phase_changed` |
| `sfx_weak_point_hit` | `boss_weak_point_hit` |
| `sfx_weak_point_mark` / `sfx_weak_point_mark_warn` / `sfx_weak_point_mark_end` | Señales `marked`, `mark_warning` y `mark_expired` de `WeakPoint` (§2.3.1; nuevos, sin audio) |
| `sfx_boss_defeat` → `stg_boss_defeated` → `mus_memory` | Golpe final, desarme y recompensa |
| `mus_boss1` | Bucle de la pelea; sube una capa por fase. La sincronización con el metrónomo de la fase 3 queda como extra opcional (decisión 3 de audio). |
| `amb_boss1_lockscreen` | Ambiente de la arena |
| `vox_boss_eco_filter`, `mus_eco_motif` | Eco hablando por el jefe |
| `sfx_hub_wallpaper_piece` | Pieza cian del hub |
| Reutilizados | `sfx_charger` (suena a menudo en la arena), `sfx_banner_warn/sweep`, `sfx_popup_appear/close`, `sfx_alarm_bell_warn/wave`, `sfx_metronome_tick`, `sfx_blink_warn`, `sfx_dash_through`, `sfx_enemy_*`, `sfx_badge_lunge` |

`sfx_boss_rollback_easy` **no se usa** en este jefe (§1.2).

### 4.2 Validación y bot

- **Validador de arena** (`tools/validate_boss.py`, o un modo `--boss` de `tools/validate_level.py`): esquema de `1-boss.json`; subidas de 2 tiles medidas con el Isak real (`tools/level_climbs.py`); **alcance del núcleo** en cada posición de ventana (fase 1: centro del suelo; fase 2: las dos plataformas; fase 3: los tres sitios), con el pulso desde una celda de pie a ≤ 96 px o con el láser en la misma fila; **ventanas** con k = 2 (recorrido desde la peor posición + 1 s de Debug + pose); **avisos** de 6-12 cuadros en todos los ataques; **hueco seguro** en cada compás de la fase 3 (nunca dos campanas a la vez; siempre una celda sin onda ni barrido); `on_fraction` de las plataformas que parpadean (regla del 1-3); ningún ataque que barra los dos carriles a la vez; **energía (§2.4)**: con `debug_drain_scale`, la barra base (100), `--access-cap` y todo al máximo, el pico de la pelea torpe por ventana (`validation.boss_clumsy_debug_s`, por defecto 3,0 s de Debug más los dashes y láseres de la ventana) ≤ máximo − 20, cada celda de suelo con un cargador a ≤ 4 tiles y el presupuesto por fase (gasto frente a cargas, recargas de cambio de fase y drops).
- **Bot de jefe** (`tools/boss_bot.gd` + `tools/play_boss_bot.gd`): una pelea no es un camino, así que el bot **reacciona** con una política por fase leyendo la API de `BossBase` (como el bot del 1-3 lee `get_beat_phase()`). Solo usa acciones del Input Map, nunca Q ni Esc. Política: aturdir las Burbujas → esperar la ventana → Debug → pulso (marca) → soltar el Debug → láser mientras dure la marca (`WeakPoint.get_mark_time_left()`); dash ante cada aviso de ráfaga o lanzamiento; cambiar de carril ante los barridos; recargar en el cargador más cercano por debajo de 40. Con `--fixed-fps 60` es determinista (semilla fija para los cuartos de los pop-ups y el orden de las copias). **Comprobaciones:** vence sin game over, 0 golpes en la solución ideal (o anota cuántos), duración frente a `target_duration_s`, energía mínima, la capa `boss_w1_l1` obtenida y la vuelta al hub con `1-boss` completado y el Mundo 2 desbloqueado. Modo **`--clumsy`**: mantiene el Debug 3 s por ventana, falla un láser por ventana y comprueba que la energía nunca llega a 0 en una ventana. **Negativos** (GUT): quedarse quieto pierde, el pulso no baja el contador, el láser sin marca no lo baja y el dash con el Debug no sale.
- **Pruebas GUT:** `tests/test_boss_base.gd` (fases, reaparición por fase con energía ≥ 50, contador, golpe final), `tests/test_alert_major.gd` (cada ataque con el tiempo avanzado a mano), `tests/test_weak_point_damage.gd`, `tests/test_debug_drain_scale.gd`, `tests/test_boss_reward.gd` (recuerdo sin guardar, red de seguridad, revancha sin entrega doble) y `tests/test_hub_boss_entry.gd`.

---

## 5. Decisiones del usuario (aprobadas el 2026-10-20)

| # | Pregunta | Resolución |
|---|---|---|
| 1 | ¿Qué es el «rollback de Easy» de Alerta Mayor? | **Ninguno.** No hay rollback tras el jefe de notificaciones, ni real ni simulado. Se eliminan el amago, sus líneas («Restaurando copia anterior…», «Error: copia incompleta»), la señal `boss_rollback_attempted` y el uso de `sfx_boss_rollback_easy` (retirado del jefe M1 y reservado para el jefe final en `lista-sonidos.md`). La fase 3 termina con el golpe final (§1.2, §2.8). |
| 2 | ¿La terminal del 1-3 lleva al jefe o al hub? | **Al hub** (aprobado). Se entra al jefe desde la carpeta del Mundo 1 (§1.3). |
| 3 | ¿Reaparición al morir? | **Al principio de la fase actual, con energía mínima de 50** (aprobado; §2.9). |
| 4 | ¿Cómo se hace daño? | **Cambiada el 2026-10-21 (idea del usuario, «la marca»):** ~~solo golpes al núcleo con el Debug activo; pulso o láser, 1 golpe cada uno~~. Ahora: **el Debug revela el núcleo, el pulso lo marca** (`mark_duration_s`: Caché 4 s, Kernel 3 s, Raíz 2,5 s, tiempo del mundo) y **el láser lo daña mientras está marcado, sin Debug** (1 golpe; 2 con el Láser 4, desde Kernel); todos los disparos que quepan en la marca; el pulso no quita contador y solo refresca la marca con el Debug activo; el dash nunca daña; sin marca ni Debug, chispa gris en el cuerpo sin delatar el núcleo (§2.3). **Condición del usuario** (energía para cargar, usar el Debug y seguir atacando) **recalculada (§2.4.7):** 4 cargadores de arena (+50, 4 s) y el Debug a **un cuarto** de gasto en la arena (`debug_drain_scale` 0,25; antes 0,5, que con la marca deja la fase 2 torpe con 10 de margen). Pico de la pelea torpe ≤ 68 en Caché (margen ≥ 30 con la barra de 100 sin mejoras); Kernel margen 22 (≥ 20); Raíz margen 20 con **3 lanzamientos por ronda en la fase 3** (decisión del usuario del 2026-10-21; recalculado con el validador de arenas). Palanca de reserva: Debug sin gasto en la arena. |
| 5 | ¿Vida del jefe en Caché? | **9 golpes (3 por fase)** con el contador «99+ → 66 → 33 → 0» como barra (aprobado). |
| 6 | ¿Qué pasa al golpear una copia en la fase 3? | **Se descarta y suelta una Burbuja** (aprobado). |
| 7 | ¿Las líneas del jefe pausan? | **Intro y derrota pausan; los cambios de fase no** (aprobado). Los textos se escriben con el usuario. |
| 8 | ¿Qué pasa con el Mundo 2 al vencer? | **Se desbloquea su carpeta con «Próximamente» y se enciende la pieza cian del hub** (aprobado). |

---

## 6. Plan de implementación

Pasos pequeños, como los del 1-3 (`propuesta-1-3.md` §7). Cada paso lleva sus pruebas y termina con `tools/run_tests.sh` en verde y `graphify update .`. El arte es por script con sufijo `_placeholder` (sin AutoSprite salvo permiso). Los textos de Eco, del jefe y del sistema van marcados como propuestos hasta escribirlos con el usuario.

| Paso | Qué | Archivos probables | Terminado cuando | Tamaño | Depende de | En paralelo con |
|---|---|---|---|---|---|---|
| 1 | **Entrada del hub:** fila `1-boss` en `m1` (`kind: "boss"`, `playable: false`, sin puntos, prefijo «Jefe: »), desbloqueo tras completar el 1-3, carpeta `completed` y pieza cian solo con el jefe vencido. **Hecho el 2026-10-21:** fila «Jefe: Alerta Mayor - Próximamente» (`kind: "boss"`, `HubWorlds.is_boss`, texto `folders.texts.boss_level`, sin id ni puntos); la terminal del 1-3 la desbloquea (`unlocks` del 1-3); antes, completar el 1-3 completaba la carpeta y encendía la pieza: ahora la fila `1-boss`, aunque no sea jugable, lo impide. Pruebas `tests/test_hub_boss_entry.gd` (y ajustes en `test_hub_folders.gd`, `test_hub_room.gd`, `test_level_1_3.gd/.py`). | `data/hub.json`, `scripts/hub/hub_worlds.gd`, `scripts/hub/folder_panel.gd`, `tests/test_hub_boss_entry.gd` | El panel muestra «Jefe: Alerta Mayor — Próximamente» tras el 1-3; la carpeta no pasa a `completed` ni se enciende la pieza sin el jefe; los 1-1 a 1-3 siguen igual. | S | — | 2, 3 |
| 2 | **`BossBase` y señales:** fases, contador, ventanas, reaparición por fase (energía ≥ 50), golpe final, API para el bot; `boss_started`, `boss_phase_changed`, `boss_weak_point_hit` y `boss_defeated` en `EventBus` (sin `boss_rollback_attempted`); `data/bosses/alert_major.json` con `laps`. **Hecho el 2026-10-21:** `BossBase` (`scripts/bosses/boss_base.gd`, grupo `boss`) con contador `round(99 × quedan / total)` y «99+» con la vida entera, fases por `hits_per_phase` de la vuelta (3/3/3; 4/4/4 en Kernel y Raíz), +25/+25 al cambiar de fase, un golpe sobrante no cruza de fase, ventanas en tiempo del mundo, reaparición por fase con `EventBus.player_respawned` (solo tras morir) y golpe final (`DEFEATED`, sin rollback); cuatro señales en `EventBus`. Pruebas `tests/test_boss_base.gd` y `tests/test_boss_data.py` (en `tools/run_tests.sh`). | `scripts/bosses/boss_base.gd`, `scripts/autoload/event_bus.gd`, `data/bosses/alert_major.json`, `tests/test_boss_base.gd` | GUT: cambio de fase al llegar a 66/33, reaparición al principio de la fase con energía max(actual, 50), golpe final al llegar a 0. | M | — | 1, 3 |
| 3 | **`WeakPoint` dañable:** solo recibe pulso o láser con `is_revealed()`; señal `hit`; chispa gris sin Debug; Láser 4 = 2. Sala de prueba `boss_test` con un jefe «saco» (baja, se golpea y sube). **Hecho el 2026-10-21:** `WeakPoint` en la capa enemy y en `laser_activatable`; solo con `DebugMode.is_active()` (la carga y el revelado persistente no cuentan) el pulso (círculo contra círculo, 1 golpe) y el láser (su daño) emiten `hit`; sin el Debug, chispa gris (`gray_spark`) y `deflected`; `set_enabled(false)` lo apaga del todo; el dash no tiene ningún efecto. `BossBase.set_weak_point` / `get_core_target`. Saco `boss_dummy` (`BossDummy`, `data/bosses/boss_dummy.json`, 2 × 2 tiles; arte `_placeholder` de `tools/gen_boss_dummy_placeholder.py`) y sala `boss_test` (20 × 12, cargador de 4 s, terminal). Pruebas `tests/test_weak_point_damage.gd` (con el Isak real: pulso, láser y dash) y `tests/test_boss_data.py`. **Reabierto y ajustado el 2026-10-21 (la marca, §2.3):** el núcleo pasa a tres estados (oculto, revelado, marcado). El pulso con el Debug activo lo marca `mark_duration_s` s del mundo (`set_mark_duration`; `BossBase` la toma de `laps.<vuelta>.mark_duration_s` del jefe: 4 / 3 / 2,5 s; por defecto la de `data/weak_point.json`) y refresca la marca con el Debug; el láser solo daña con la marca, sin Debug; el pulso no daña; oculto no es objetivo del láser y la chispa gris sale en el borde del cuerpo (`set_shell_rect`, el saco usa su cuerpo de 2 × 2 tiles); la marca se pierde al caducar, al desactivarse el núcleo, al cambiar de fase, en el golpe final y al reaparecer. Halo de 8 segmentos por script con parpadeo el último segundo; señales `marked`, `mark_warning`, `mark_expired`. Pruebas ampliadas en `tests/test_weak_point_damage.gd` (Isak real: pulso sin Debug no marca, Debug + pulso marca, láser sin marca no daña, con marca 1 y 2 con el Láser 4, caducidad en tiempo del mundo y a medio ritmo con el Debug, dash, reaparición y duración por acceso). | `scripts/bosses/weak_point.gd`, `data/weak_point.json`, `data/levels/boss_test.json`, `tests/test_weak_point_damage.gd` | GUT: sin Debug no baja el contador; con Debug, pulso y láser restan 1; el dash nunca. `boss_test` jugable con `--start-level=boss_test`. | S | 2 (para el saco) | 1 |
| 4 | **Energía de la arena:** `debug_drain_scale` por nivel en `DebugMode` (lo fija `LevelRunner`; 1,0 por defecto y en el hub), esquema del campo, cargadores con `cooldown_s` 4 por instancia. | `scripts/autoload/debug_mode.gd`, `scripts/levels/level_runner.gd`, `tools/validate_level_schema.py`, `tests/test_debug_drain_scale.gd` | GUT: en un nivel con 0,5 el Debug gasta 10/s (7,5 con Debug 2) y en el 1-1/1-2/1-3 sigue en 20/s; salidas del validador del 1-1 al 1-3 idénticas. **Hecho el 2026-10-21:** `DebugMode.set_level_drain_scale` / `get_level_drain_scale` (0-1; `reset()` no lo toca) multiplica `get_drain_per_second()`. **Desvío:** lo fija `GeneratedLevel` al entrar en el árbol (propiedad `debug_drain_scale` que escribe `tools/build_level.py` solo si el JSON la tiene) y lo devuelve a 1 al salir, como `abilities_available`; `LevelRunner` solo lo asegura a 1 al mostrar el hub. Así vale también para escenas abiertas sin `LevelRunner`. Esquema (número 0-1) y plan del validador (`level_plan.py` gasta el Debug por el factor y la salida añade «gasto del Debug en este nivel» solo con el campo). Los cargadores ya tenían `cooldown_s` por instancia: sin código nuevo (4 s en `boss_test`; el 1-2 y el 1-3 siguen en 10 s). Salidas del validador (texto, `--json`, `--access-cap` y camino exportado) del 1-1, 1-2 y 1-3 idénticas byte a byte a las de antes del paso 1. Pruebas `tests/test_debug_drain_scale.gd` y `DebugDrainScaleTest` de `tests/test_level_plan.py`. **Ajustado el 2026-10-21 (la marca, §2.4.7):** el valor de la arena baja de 0,5 a **0,25** (sin cambio de código: es dato del nivel); `boss_test` lo lleva ya (`debug_drain_scale: 0.25`). Los cargadores siguen en 4 s. | S | — | 1, 2, 3 |
| 5 | **Arena + build y validador de arenas:** `data/levels/1-boss.json` (24 × 12, `kind: "boss"`, `boss`, 4 cargadores, `debug_drain_scale` 0,25, plataformas, campanas y `blink_platform` con `active_in_phase`), escena generada, modo `--boss` del validador (alcance del núcleo, ventanas k = 2, avisos, hueco seguro, dos carriles, energía de §2.4 con `--access-cap`). | `data/levels/1-boss.json`, `scenes/levels/1-boss.tscn`, `tools/build_level.py`, `tools/validate_level_schema.py`, `tools/validate_level.py` (o `tools/validate_boss.py`), `tools/level_climbs.py`, `tests/fixtures/climbs_1-boss.json`, `tests/test_boss_validator.py` | `build_level.py --check` al día; el validador pasa la arena y falla con negativos sintéticos (cargador a > 4 tiles, pico > máximo − 20, dos carriles barridos a la vez). **Hecho el 2026-10-21:** arena `data/levels/1-boss.json` (24 × 12, `kind: "boss"`, `boss: "alert_major"`, sin G, P en (2, 9), 4 cargadores de 4 s, `debug_drain_scale` 0,25; metrónomo `ritmo_jefe`, 4 `blink_platform` —A a la izquierda, B a la derecha, de 2 tiles— y 3 campanas con `active_in_phase: [3]`) y escena generada; objeto `alert_major` (`AlertMajor`, `scenes/bosses/alert_major.tscn`) con intro al terminar la llegada, cuerpo inflado / desinflado, contador encima y núcleo solo en las ventanas; posiciones, ataques, textos y modelo de energía en `data/bosses/alert_major.json` (`arena`, `phase1-3`, `laps`, `texts`, `validation_model`). Esquema: `kind`, `boss`, id `<mundo>-boss`, arena sin G y con su jefe, `active_in_phase` (solo en arenas) y plataformas que parpadean con `active_in_phase` sobre celdas `-` (las reemplazan: `BossBase.apply_phase_nodes` las desactiva al cargar —sin proceso, invisibles y sin capa— y el jefe las activa en su fase borrando y devolviendo esas celdas del `TileMapLayer`). Validador de arenas `tools/validate_boss.py` (al que delega `tools/validate_level.py` con `kind: "boss"`): carriles alcanzables y con refugio, barridos y ráfagas que nunca cubren los dos carriles a la vez, cargador a ≤ 4 tiles (y otro a ≤ 7) de cada celda del suelo, avisos de 6-12 cuadros, alcance del núcleo (pulso y láser) y ventanas con k = 2 en cada sitio, compás de la fase 3 por acceso (hueco seguro, campanas y parpadeo) y la energía de la pelea torpe por acceso con la barra base, el tope del acceso y todo al máximo. **Márgenes confirmados** (picos torpes F1 / F2 / F3 con la barra base de 100): Caché 55 / 60 / 67,5 (margen mínimo 32,5), Kernel 55 / 70 / 77,5 (22,5), Raíz 55 / 70 / **80 (20)** con 3 lanzamientos por ronda (con 4, 90: margen 10). Subidas con el Isak real: `tests/fixtures/climbs_1-boss.json` (las 4 de 2 tiles). Pruebas `tests/test_boss_validator.py` (con negativos), `tests/test_alert_major.gd` (arena) y el arte en `tests/test_boss_data.py`. **Desvíos:** el modelo de la pelea torpe va en `validation_model` del JSON del jefe (por acceso y fase: golpes por ventana, Debug, dashes, fallos, Burbujas rematadas), no en `validation.boss_clumsy_debug_s` del nivel; el núcleo de la fase 1 se alcanza con el pulso desde las columnas 10-13 (el cuerpo desinflado es de 2 × 2 en las 11-12), no desde la 9 o la 14; el escudo espera `perch_s` 7 s (el validador pedía 6,4 desde la esquina más lejana); el vuelo va de la columna 4 a la 20; el arte se comprueba con `tools/gen_boss_alert_major.py --check` (sin validador aparte); `Charger.make_ready()` para la reaparición; `tests/test_level_climbs.gd` ignora los cuerpos sin capa (objetos de fase inactivos). | M-L | 2, 4 | 6 (arte), 1 |
| 6 | **Fase 1:** Burbujas que caen a las plataformas (máx. 2), barridos alternos, ventana al aturdir las dos, bajada al centro 5 s del mundo. | `scripts/bosses/alert_major.gd`, `data/bosses/alert_major.json`, `tests/test_alert_major.gd` | GUT con el tiempo avanzado a mano: aviso de 9 cuadros, ventana solo con las 2 aturdidas, 3 golpes → fase 2 con +25 de energía y Sync. **Hecho el 2026-10-21:** `AlertMajor` flota (columnas 4-20), se infla 9 cuadros con una flecha `alerta` sobre cada lateral libre y escupe Burbujas (`alert_bubble`, patrulla de 4 tiles) hasta tener 2 vivas; dos `spam_banner` en **modo disparo** (`manual`, `trigger()`, `is_busy()`: sin ciclo propio; el del 1-2 y el 1-3 no cambia) barren el carril del suelo (entra por la columna 1) y el alto (por la 22) alternos cada 3 s; cuando el escupitajo de la ronda ha terminado, ninguna Burbuja viva patrulla y ningún barrido está en curso, baja desinflado al suelo del centro (núcleo en (768, 584)) 5 s del mundo sin barridos; al subir empieza otra ronda (las aturdidas de la ronda anterior no cuentan: hay que volver a aturdirlas) y escupe las que falten. Señal `attack_started` (`spit`, `sweep`) para el audio y el bot. Pruebas en `tests/test_alert_major.gd` (aviso de 9 cuadros, 2 Burbujas como mucho, barridos alternos que nunca coinciden, el carril alto es refugio del barrido del suelo y el alto quita 10 al Isak real, dash a través del barrido sin daño, ventana solo con las dos neutralizadas —aturdida o derrotada—, 3 golpes → fase 2 con +25/+25 y se borran Burbujas y banners, la marca se pierde al subir). **Desvíos:** la Burbuja derrotada también cuenta como neutralizada (§2.5 lo dice así); una Burbuja aturdida en la ronda anterior no abre otra ventana (evita encadenar ventanas con un solo pulso). | M | 2, 3, 5 | 9, 11 |
| 7 | **Fase 2:** lluvia de pop-ups (máx. 2, nunca sobre Isak al salir), `notification_shot`, pop-up escudo (ampliar `overlay_popup`: `opaque`, `follow`, `respawn_s`). | `scripts/bosses/notification_shot.gd`, `scripts/levels/overlay_popup.gd`, `scripts/bosses/alert_major.gd`, `tests/test_alert_major.gd` | GUT: el dash atraviesa la ráfaga, el pulso al botón abre el escudo, golpe en 4 s del mundo; el `overlay_popup` del 1-2 no cambia. **Hecho el 2026-10-21:** lluvia de pop-ups (`overlay_popup` al 70 %, contorno punteado `banner_blanco` 9 cuadros antes, uno cada 6 s, 8 s de vida, como mucho `laps.<n>.phase2.popup_max` —2 en Caché—, en un cuarto de `popup_quarters` que no sea el de Isak ni uno tapado; botón de 24 px a la altura del celular de un carril, alternando suelo y alto; textos marcados PROPUESTA); ráfaga cada 4,5 s (`NotificationShot`, `scripts/bosses/notification_shot.gd`: flecha `alerta` en el muro más lejano de Isak y línea discontinua por su carril 9 cuadros antes, 3 notificaciones de 64 × 32 a 640 px/s separadas 0,5 s, −10; el dash las atraviesa, el láser y el pulso no les afectan; sin ráfagas nuevas con la ventana abierta); cada 12 s baja a la lateral más lejana de Isak tapado por el **pop-up escudo** (`overlay_popup` ampliado con `opaque`, `follow_target`/`follow_offset`, `icon_texture`, `respawn_s` y `reopen()`; por defecto el del 1-2 no cambia) y espera 7 s; el pulso a su botón abre la ventana de 4 s del mundo (núcleo a la altura del celular en la plataforma); al acabar, el escudo vuelve y sube. Semilla fija (`phase2.seed`). Pruebas en `tests/test_alert_major.gd` (pop-ups lejos de Isak y 2 a la vez como mucho, cierre con el pulso y por tiempo, ráfaga con aviso que golpea al Isak real en su carril, el otro carril es refugio, dash a través de una notificación, escudo opaco también con el Debug abierto por el pulso real de Isak y dos golpes en su ventana, subida sin abrirlo, reaparición que borra los ataques). **Desvíos:** la ráfaga va al carril donde está Isak y entra por el muro más lejano; el jefe espera a que termine una ráfaga antes de bajar al escudo; `perch_s` 7 s (paso 5); el pop-up escudo se amplía del `overlay_popup` (no hay tipo `boss_popup_shield`). | M | 6 | 9, 10, 11 |
| 8 | **Fase 3:** copias (`alert_major_clone`, lanzamiento por compás, copia golpeada → «pop» y Burbuja), metrónomo de 2,0 s, campanas desfasadas y laterales como `blink_platform` activadas por fase. | `scripts/bosses/alert_major_clone.gd`, `scripts/bosses/alert_major.gd`, `scripts/levels/rhythm_zone.gd`, `tests/test_alert_major.gd` | GUT: solo la real muestra el núcleo con el Debug; nunca dos campanas en el mismo tiempo; la copia golpeada suelta una Burbuja. **Hecho el 2026-10-21:** al empezar la fase 3 se activan el metrónomo (2,0 s en Caché; el compás de cada acceso sale de `laps.<n>.phase3.tempo_steps_s`), las laterales como plataformas que parpadean (A / B alternas, `blink_on_fraction` por acceso) y las 3 campanas (desfases 0, 1/3 y 2/3: nunca dos ondas a la vez). Ronda: se infla 9 cuadros, se divide en la real y 2 copias (`AlertMajorClone`, `scripts/bosses/alert_major_clone.gd`, iguales a la real; 4 en Raíz con la central como cuarto sitio) que bajan a la lateral izquierda, el suelo del centro y la lateral derecha (orden y real de la semilla `phase3.seed`) y aterrizan; al empezar cada compás una se infla 9 cuadros con una línea `alerta` que sigue a Isak y se lanza (0,3 s a 1280 px/s, como mucho 384 px; −10; vuelve en 0,6 s); tras `launches_per_round` lanzamientos (3; también en Raíz, decisión del usuario) se quedan quietas 5 s del mundo con el núcleo solo en la real; una copia golpeada por el pulso o el láser se descarta con un «pop» y suelta una Burbuja; después suben y se mezclan (la marca se pierde). **Golpe final:** las copias se descartan sin Burbujas, se borran los ataques, se paran el metrónomo y las campanas, las plataformas quedan encendidas (`BlinkPlatform.hold_on()`) y se emite `final_blow` (gancho del paso 10; sin rollback ni cambio de vuelta). **Sonidos enganchados** en `data/audio.json` (sin archivos: silencio): `sfx_boss1_intro` (`boss_started`), `sfx_boss_phase_change`, `sfx_weak_point_hit`, `sfx_boss_defeat` (señales de `EventBus`), `sfx_boss1_launch` / `sfx_boss1_popup_storm` / `sfx_boss1_clones` (`AlertMajor.attack_started`), `sfx_weak_point_mark` / `_mark_warn` / `_mark_end` (`WeakPoint`) y el ambiente `amb_boss1_lockscreen`; los reutilizados (banner, pop-up, campana, metrónomo, parpadeo, cargador) ya estaban conectados por clase; sin `sfx_boss_rollback_easy`. Pruebas en `tests/test_alert_major.gd` (división con aviso y aterrizaje al compás, un lanzamiento por compás y ventana con el núcleo solo en la real que el Debug revela, el lanzamiento golpea al Isak real y el dash lo atraviesa, copia descartada con Burbuja por el pulso y el láser sin quitar contador, campanas que nunca suenan a la vez y laterales alternas, golpe final, Raíz con 4 copias y 3 lanzamientos) y la **pelea completa** en el flujo real con `tools/smoke_boss_arena.gd` (jugador mínimo que aturde, abre el escudo y golpea solo en las ventanas: 3 golpes en ventana por fase hasta el golpe final, unos 32 s de juego). **Desvíos:** el núcleo solo existe en la ventana (no durante los lanzamientos); las copias usan el mismo dibujo que la real (§4.1 hablaba de «otro contorno», pero eso delataría la real sin el Debug); lo propio de Kernel y Raíz (núcleo detrás, núcleo que cambia de copia, puntos rojos en la fase 1) queda para cuando se diseñen esos accesos; las ayudas Q de los tipos nuevos (`alert_major`, `alert_major_clone`, `notification_shot`, escudo) son del paso 12 (sus nodos aún no llevan Q). | L | 7 | 9, 10, 11 |
| 9 | **HUD: barra del jefe «99+»** con contador y tres muescas; R reinicia la pelea; game over normal. | `scripts/ui/boss_bar.gd`, `data/hud.json` (`boss_bar`), `scenes/ui/hud.tscn`, `tests/test_boss_bar.gd` | GUT: el contador sigue 99+ → 88 … → 0 y las muescas por fase; oculta fuera del jefe. **Hecho el 2026-10-21:** `BossBar` (`scripts/ui/boss_bar.gd`), hija del `Hud` creada por código, arriba en el centro bajo la barra de estado: icono y nombre del jefe, contador (`BossBase.get_counter_label`) y un segmento por golpe agrupado por fase con muescas. **Legible sin color:** golpes que quedan = segmentos llenos, dados = huecos (solo contorno), muesca de una fase pasada hueca y el número. Destello del segmento perdido, parpadeo de la barra y bote del contador al cambiar de fase; vuelve al principio de la fase al reaparecer (`phase_restarted`); tras el golpe final enseña el «0» y se oculta sola (1,2 s); se oculta si el jefe sale del árbol. Aparece con `EventBus.boss_started` (el jefe del grupo `boss` que pelea). Sin «vuelta»/Easy/Normal/Hard. Aspecto en `boss_bar` de `data/hud.json`; arte provisional (icono y marco nine-patch) en `tools/gen_boss_alert_major.py`. R y el game over ya funcionaban (no cambian). Pruebas `tests/test_boss_bar.gd` (Caché 9 y Kernel 12 segmentos). **Desvíos:** no toca `scenes/ui/hud.tscn` (la barra se crea por código como las vidas y el Ocultarte); el arte de la barra llega en este paso (no en el 11). | S | 2 | 6-8, 10, 11 |
| 10 | **Golpe final y `BossReward`:** congelación, detención de ataques, desarme; escena de recuerdo con la capa Caché `boss_w1_l1` (sin guardar, red de seguridad, revancha sin entrega doble), línea de derrota (pausa), vórtice al hub, `m2` desbloqueado con «Próximamente» y pieza cian. | `scripts/bosses/boss_reward.gd`, `scenes/bosses/boss_reward.tscn`, `scripts/bosses/alert_major.gd`, `data/hub.json`, `tests/test_boss_reward.gd` | GUT: tras el noveno golpe, `completed_levels` tiene `1-boss`, `has_memory(boss_w1_l1)` sin guardar, `m2` desbloqueado y la pieza encendida; ningún rollback ni cambio de `lap`.  **Hecho el 2026-10-21:** tras `final_blow`, `AlertMajor` (con `defeat_sequence`) crea **`BossDefeat`** (`scripts/bosses/boss_defeat.gd`, hija del nivel; valores en `defeat` de `data/bosses/alert_major.json`): **congelación** de 0,3 s reales (pausa el árbol si no lo estaba), **desarme en píxeles** (`play_disarm`: el cuerpo y el contador se apagan y `PixelBurst`, `scripts/bosses/pixel_burst.gd`, suelta los píxeles de su textura con semilla fija y se apagan por escalones; señal `disarmed`), **recompensa** (`BossReward`, `scripts/bosses/boss_reward.gd`, compartida por los jefes; textos y aspecto en `data/boss_reward.json`: `grant(mundo, vuelta)` entrega la capa del acceso actual —`boss_w1_l1` en Caché— y las inferiores que falten, **sin guardar**; panel con la línea del sistema del jefe, «Recuerdo recuperado», el título, «Capa: Caché», el texto y «Guarda en Notas para conservarlo.»; pausa y se cierra con saltar / aceptar; en una revancha no sale), **línea de derrota** (importante, `say_line`) y **vórtice de salida** (con Isak en el suelo) que emite `EventBus.level_completed("1-boss")`: `LevelRunner` lo apunta en `completed_levels` y vuelve al hub. **Mundo 2:** `unlocked_by: ["1-boss"]` en `data/hub.json` (`HubWorlds.is_world_unlocked`), sin subniveles: su carpeta abre con «Próximamente» (`folders.texts.empty_world`). **Pieza cian:** si la carpeta del Mundo 1 se completa por primera vez, `LevelRunner` pasa `light_piece_on_arrival` y el hub la deja apagada hasta terminar la llegada; entonces destella (`piece_flashes` en `piece_light_s`) y se enciende (`HubRoom.wallpaper_piece_lit`). Notas lleva la placa «!» (recuerdo sin leer). Pruebas `tests/test_boss_reward.gd` (capa sin guardar y sin entrega doble, red de seguridad, guardar y cargar, game over sin guardar que la pierde y vuelve a bloquear el Mundo 2, textos del panel sin «vuelta», secuencia en la arena hasta `level_completed` sin cambio de vuelta, revancha sin panel y flujo real arena → hub con la carpeta completa, la pieza encendida y el Mundo 2 «Próximamente»). **Desvíos:** sin escena `boss_reward.tscn` (el panel se crea por código); el desbloqueo del Mundo 2 sale de `completed_levels` (`unlocked_by`) en lugar de un campo nuevo del guardado (sin subir la versión; el rollback lo trata igual que al jefe); la línea breve del sistema del golpe final va arriba del panel de la recompensa (no como línea suelta); las líneas del jefe usan aún el cuadro de Eco (el estilo «filtrado» llega en el paso 12). | M | 8, 9, 1 | 11, 12 |
| 11 | **Arte por script `_placeholder`:** badge 256 × 256 (estados de §4.1, sin «rebobinado»), copias, proyectil, pop-up escudo, barra del jefe y fondo de pantalla de bloqueo con relojes; validador de paleta (`carmin` solo en el núcleo). | `tools/gen_boss_alert_major.py`, `tools/validate_boss_alert_major.py`, `assets/sprites/bosses/alert_major_*_placeholder.png` | El validador pasa y está en la suite; las escenas usan los `.tres` generados.  **Hecho el 2026-10-21 (arte restante):** el badge, las copias, la notificación, el escudo y el «pop» ya estaban (pasos 5-8). Añadidos a `tools/gen_boss_alert_major.py`: icono y marco nine-patch de la barra del jefe (paso 9), marco nine-patch del panel de la recompensa (`boss_reward_panel_placeholder.png`, sin rojos: es un recuerdo) y la ficha del álbum del núcleo marcado (`alert_major_core_card_placeholder.png`, la única pieza con carmín: `CARMIN_OK`). El desarme en píxeles no necesita arte: `PixelBurst` usa los píxeles de la textura del cuerpo. El hub usa el arte que ya tenía (pieza cian `on`/`off`; carpeta del Mundo 2 en estado disponible). Pruebas `BossUiArtTest` de `tests/test_boss_data.py` (texturas citadas por `data/hud.json` y `data/boss_reward.json`, sufijo `_placeholder`, carmín solo en el núcleo) y `--check` del generador (ya en la suite). **Desvíos:** sin validador aparte (`--check` comprueba paleta, alfa y que esté al día, como en el paso 5); sin `.tres` (las texturas se cargan sueltas); **pendiente:** el fondo de «pantalla de bloqueo» con relojes grandes (la arena sigue con el fondo del Mundo 1) y los estados de arte del badge «escupir», «bajar» y «golpeado» (se ven con el inflado y el desinflado): quedan para el arte final (paso 16). | M | 2 (tamaños) | 5-10 |
| 12 | **Textos, ayudas Q y sonidos:** intro (pausa), fases (sin pausa), derrota (pausa) marcados propuestos para el usuario; 4 tipos de ayuda y fichas del álbum; conexión en `data/audio.json` de los IDs de §4.1 (sin `sfx_boss_rollback_easy`). | `data/bosses/alert_major.json`, `data/help.json`, `tools/gen_album_cards.py`, `data/audio.json`, `tools/validate_audio.py` | `validate_audio.py` pasa con las señales nuevas; las fichas salen en el álbum; los textos marcados «por decidir».  **Hecho el 2026-10-21:** textos redactados por el orquestador (el usuario delegó la decisión) en `texts` de `data/bosses/alert_major.json`, marcados **«propuesta del orquestador, revisar al jugar»** (`texts_status`; lista en §6.1). Eco habla por el jefe en el cuadro del nivel como interlocutor **`eco_boss`** (`data/eco_text_box.json`: nombre «Eco», icono de Eco con interferencia `eco_boss_icon_placeholder.png`, blip `vox_boss_eco_filter`): intro y derrota importantes (pausa; `AlertMajor.say_line` espera a que se cierre esa línea), cambios de fase sin pausa. **7 ayudas Q** nuevas en `data/help.json` (Mundo 1, `first_level` 1-boss, con ficha del álbum de `tools/gen_album_cards.py`): `alert_major` (el cuerpo), `alert_major_core` (núcleo y marca; solo ayuda mientras se ve: no delata el núcleo oculto), `alert_major_bubble` (Burbujas del jefe), `alert_major_popup` (pop-ups de la fase 2: también se van solos), `boss_popup_shield`, `notification_shot` y `alert_major_clone`; las piezas las llevan por la sección `help` del JSON del jefe. **Sonidos** en `data/audio.json` con los IDs de `lista-sonidos.md`: `mus_boss1` (bucle mientras existe `BossMusic`, de la fase 1 al golpe final), `mus_eco_motif` (`line_said` de la intro y la derrota), `stg_boss_defeated` y `mus_memory` (`BossReward`), `vox_boss_eco_filter` y `sfx_hub_wallpaper_piece` (`HubRoom.wallpaper_piece_lit`), además de los del paso 8; sin `sfx_boss_rollback_easy`. Pulido del texto de la capa `boss_w1_l1` (sin rollback). Pruebas `tests/test_alert_major_help.gd` (ayudas y fichas, piezas marcadas, núcleo solo visible, líneas de fase con `eco_boss` sin pausa, blip, música), 7 casos nuevos de «lo destruido no ayuda» en `tests/test_help_inert.gd`, `test_help.gd` lee la sección `help` de los jefes, `test_notas_album.gd` cuenta los tipos nuevos y `tests/test_boss_data.py` comprueba la marca de propuesta, la ausencia de vueltas y de rollback y los glifos. **Desvíos:** 7 tipos en lugar de 4 (marca/núcleo, Burbuja y pop-up del jefe aparte porque se comportan distinto: las Burbujas abren la ventana y los pop-ups se cierran solos); sin validador de audio nuevo (`validate_audio.py` ya cubre las señales); `mus_boss1` no sube una capa por fase (un solo bucle hasta tener los archivos). | S | 6-10 | 11 |
| 13 | **Jugable desde el hub:** `1-boss` `playable: true`; flujo hub → arena → hub con la confirmación de guardado y las 3 vidas. | `data/hub.json`, `tests/test_hub_boss_entry.gd` | Desde la carpeta del Mundo 1 se entra a la arena, se vence y se vuelve al hub; con `-- --start-level=1-boss` en depuración.  **Hecho el 2026-10-21:** la fila `1-boss` es `playable: true`: «Jefe: Alerta Mayor - Bloqueado» sin el 1-3, «Nuevo» tras él y «Completado» al vencerlo (se repite sin recompensa nueva). Se entra como a cualquier subnivel: confirmación «¿Seguro? Aún no has guardado.» con cambios sin guardar, 3 vidas por intento, morir reaparece al principio de la fase con energía ≥ 50, game over = rollback a la última copia (el jefe y el Mundo 2 vuelven a estar sin vencer si no se guardó); R en el hub reanuda el jefe (`most_advanced_level`). Tras vencerlo, el vórtice lleva al hub (Caché). Pruebas en `tests/test_hub_boss_entry.gd` (fila jugable y sus estados, entrada desde la carpeta con la confirmación y 3 vidas, muerte en la fase 2 que vuelve a «66» con energía ≥ 50, game over en la arena con rollback y el **flujo completo** hub → arena → pelea con la barra → recompensa → hub con el Mundo 2 y la pieza, con `tools/smoke_boss_arena.gd -- --full`). **Desvíos:** la fila sigue solo en Caché (`laps: [1]`, como los 1-1 a 1-3): las de Kernel y Raíz se añaden al construir esas vueltas (el jefe ya lee `laps.2` y `laps.3`; lo propio de esos accesos no se implementa aún, por decisión del usuario); no hay cambio de vuelta al vencerlo (sin rollback: el paso a Kernel es del jefe final). | S | 10-12 | — |
| 14 | **Bot de jefe:** política por fase con la API de `BossBase`, solo acciones del Input Map; modos ideal y `--clumsy`. | `tools/boss_bot.gd`, `tools/play_boss_bot.gd`, `tests/test_boss_bot.gd` | Código 0: vence sin game over, energía mínima > 0 en todas las ventanas (también `--clumsy`), duración anotada frente a 240 s, capa obtenida y vuelta al hub.  **Hecho el 2026-10-21:** `tools/boss_bot.gd` (lanzador `tools/play_boss_bot.gd`, `-- --profile ideal|clumsy|idle --lap 1|2|3`): bot **reactivo** (no sigue un camino) que pelea con el Isak real en la arena real y solo pulsa acciones del Input Map; cada cuadro lee la API del jefe. Reflejos (dash a través de barridos, notificaciones y lanzamientos —salto si el dash no estará listo a tiempo—, cambio de carril ante las ráfagas, fuera de las columnas de las campanas) y política por fase (fase 1: aturde desde el suelo, remata una Burbuja con dos láseres desde su plataforma y mantiene aturdida la otra; fase 2: sube a la plataforma del escudo y pulso a su botón; fase 3: espera junto a los cargadores del suelo y va a la real; en cada ventana Debug → pulso que marca → soltar el Debug → láser mientras dura la marca, volviendo a marcar si caduca). Perfil **ideal**, perfil **torpe** (`clumsy`: sigue `validation_model` del JSON del jefe —golpes por ventana con las perdidas, segundos de Debug, el Debug antes de tiempo y para los pop-ups, un láser fallado por ventana, la copia equivocada y su Burbuja—) y **quieto** (`idle`, negativo). Kernel y Raíz por `GameState.lap` (la fila del hub sigue solo en Caché). Resultados en §6.2. Prueba `tests/test_boss_bot.gd` (ideal y torpe en los tres accesos y el quieto; unos 50 s de pared) en la suite. **Desvíos:** sin `--clumsy` (es `--profile clumsy`); el torpe recarga, como el ideal, por debajo de 40; la pieza cian solo se comprueba en Caché (en Kernel y Raíz la carpeta del acceso aún no tiene la fila del jefe). | L | 13 | 15 |
| 15 | **Pruebas de conjunto:** negativos (quieto pierde, golpe sin Debug, dash con Debug), salidas del validador del 1-1 al 1-3 idénticas, suite completa. | `tests/test_alert_major.gd`, `tests/test_boss_validator.py`, `tools/run_tests.sh` | `tools/run_tests.sh` en verde con el bot del jefe dentro.  **Hecho el 2026-10-21:** negativos con el Isak real: quieto pierde (perfil `idle` del bot: game over a los 183 s sin vencer, en `tests/test_boss_bot.gd`), el pulso sin Debug no marca y el láser sin marca no daña (`tests/test_weak_point_damage.gd`, ya del paso 3) y el dash no sale con el Debug activo o cargando (`tests/test_dash.gd`). Flujo de conjunto nuevo en `tests/test_boss_save_flow.gd`: la victoria en la arena real vuelve al hub, se guarda con el panel de Notas y, al arrancar otra vez con esa partida (hub), siguen la capa `boss_w1_l1` sin leer (placa de Notas), el 1-boss completado, el Mundo 2 desbloqueado con «Próximamente», la carpeta del Mundo 1 completada y la pieza cian encendida sin volver a animarse; un game over en la revancha (rollback a esa copia) no quita nada de lo guardado ni cambia la vuelta. El flujo hub → arena → recompensa → hub sin guardar (`tests/test_hub_boss_entry.gd`, con `tools/smoke_boss_arena.gd --full`) y el game over sin guardar (`tests/test_hub_boss_entry.gd`, `tests/test_boss_reward.gd`) ya estaban. `tools/validate_boss.py` ya iba en la suite (paso 5, por `tools/validate_level.py` y `tests/test_boss_validator.py`); el bot del jefe entra por GUT (`tests/test_boss_bot.gd`, unos **50 s** de pared) y la prueba de conjunto añade unos 10 s. Salidas del validador del 1-1 al 1-3 idénticas (sin cambios en el validador ni en esos niveles desde el paso 9) y bot del 1-3 en 0 golpes (`tests/test_dnd_bot.gd`). | S | 13 | 14 |
| 16 | **Capturas y docs:** intro, cada fase y su ventana, copias con el Debug, golpe final, recompensa y hub con la pieza; mapa de la arena; actualizar `CLAUDE.md`, `mundo-1` y `08-pendientes.md`. | `tools/render_boss_alert_major.gd`, `tools/render_level_map.py`, `CLAUDE.md` | Capturas en una carpeta revisadas por el usuario; ajuste jugando de los valores provisionales. | S | 14, 15 | — |

### 6.1 Textos del jefe (paso 12; propuesta del orquestador, revisar al jugar)

Escritos el 2026-10-21 por delegación del usuario; están en los datos (`texts` de `data/bosses/alert_major.json`, `data/boss_reward.json`, `data/help.json` y `boss_w1_l1` de `data/memories.json`). `{apodo}` es el apodo de Isak.

| Momento | Quién | Texto |
|---|---|---|
| Intro (pausa) | Eco por el jefe | «{apodo}, otra vez lo estás silenciando todo. Yo solo quiero que no te pierdas nada.» |
| Fase 2 «66» (sin pausa) | Eco por el jefe | «Tienes 66 cosas pendientes. Déjame enseñártelas.» |
| Fase 3 «33» (sin pausa) | Eco por el jefe | «¿Seguro que quieres seguir concentrado? Afuera todo sigue pasando.» |
| Pop-ups de la fase 2 | — | «66 mensajes sin leer» · «¿Sigues ahí?» · «Te estás perdiendo algo» · «Recordatorio: mira esto» |
| Golpe final | Sistema (arriba del panel) | «0 notificaciones pendientes.» |
| Recompensa | Sistema | «Recuerdo recuperado» · «Capa: Caché» · «Guarda en Notas para conservarlo.» |
| Capa Caché `boss_w1_l1` | Recuerdo | «Huele a estaño. El circuito sobre la mesa de la cocina: las manos de Isak, el soldador y un LED que no enciende. Al lado, unas manos viejas sostienen una lupa, sin prisa. Eco: «Archivado».» |
| Derrota (pausa) | Eco por el jefe, ya sin tanta amabilidad | «Como quieras, {apodo}. Lo dejo todo para luego. Siempre hay un luego.» |

### 6.2 Bot del jefe: resultados medidos (paso 14, 2026-10-21)

Barra base (100, sin mejoras), `--fixed-fps 60`, deterministas (dos ejecuciones seguidas dan lo mismo). Duración = tiempo de juego real sin pausas desde el inicio de la pelea hasta el golpe final (objetivo del nivel, `target_duration_s`: 240 s). Energía mínima = lo más bajo de toda la pelea (con la barra llena al empezar, es el margen que queda en el peor momento); el margen del validador es 100 − pico por ventana de la pelea torpe (`tools/validate_boss.py`).

| Acceso | Perfil | Pelea | Golpes / muertes | Energía mínima (F1 / F2 / F3) | Margen del validador | Ventanas (F1 / F2 / F3) | Dashes / láseres / Debug | Cargas de 50 |
|---|---|---|---|---|---|---|---|---|
| Caché | ideal | **57,5 s** | 0 / 0 | **66** (67 / 70 / 66) | 32,5 | 1 / 1 / 2 | 4 / 11 / 4,0 s | 7 |
| Kernel | ideal | **63,8 s** | 0 / 0 | **57** (57 / 60 / 66) | 22,5 | 1 / 1 / 2 | 4 / 14 / 5,7 s | 6 |
| Raíz | ideal | **44,1 s** | 0 / 0 | **50** (57 / 60 / 50) | 20 | 1 / 1 / 1 | 2 / 14 / 0,7 s | 4 |
| Caché | torpe | **196 s** | 0 / 0 | **32** (55 / 54 / 32) | 32,5 | 3 / 4 / 4 | 14 / 18 / 45 s | 21 |
| Kernel | torpe | **217 s** | 0 / 0 | **32** (55 / 44 / 32) | 22,5 | 4 / 4 / 4 | 12 / 21 / 50 s | 22 |
| Raíz | torpe | **229 s** | 0 / 0 | **44** (55 / 44 / 60) | 20 | 4 / 4 / 5 | 14 / 22 / 53 s | 23 |
| Caché | quieto | game over a los 183 s | 30 / 3 | — | — | 0 | — | — |

En ningún caso el Debug se corta por falta de energía dentro de una ventana ni la energía llega a 0. La energía mínima del torpe queda **por encima del margen del validador** (Caché 32 frente a 32,5, prácticamente igual: el validador acierta; Kernel 32 frente a 22,5; Raíz 44 frente a 20): el modelo es conservador y la palanca de energía (`debug_drain_scale` 0,25, 4 cargadores) basta.

**Lo que el bot ha encontrado (para decidir con el usuario; nada aplicado):**

1. **La pelea limpia dura un cuarto del objetivo.** Ideal 44-64 s frente a 240 s; el torpe 196-229 s se acerca. La marca vale varios disparos y cada fase cabe en 1-2 ventanas (ya lo anticipaba §2.4.7). Si se quiere más pelea para quien juega bien, las palancas por datos son `mark_duration_s` (menos disparos por marca), `window_every_s` / `perch_s` de la fase 2 o más rondas en la fase 3; o dejarlo así (el objetivo de 240 s es el del jugador medio).
2. **La ráfaga no se puede atravesar entera con el dash.** Tres notificaciones a 0,5 s y 640 px/s; el dash tarda 0,7 s en volver a estar listo (0,2 + 0,5 de enfriamiento), así que un dash cubre una (dos solo con un cuadro exacto). §2.6 dice «Dash a través, o cambiar de carril»: lo que funciona es **cambiar de carril** (el bot lo hace) o combinar dash, salto y dash aéreo. Propuesta: separar las notificaciones 0,75 s si se quiere que el dash baste, o reescribir la ayuda `notification_shot` para que hable de cambiar de altura primero.
3. **Las laterales de la fase 3 son macizas.** En las fases 1 y 2 son plataformas de una vía (`-`) que se suben saltando desde debajo; en la fase 3 pasan a `blink_platform`, que es una caja sólida: saltar desde debajo es un cabezazo. Además las campanas de las columnas 5 y 18 caen en medio de esas plataformas, así que el sitio para subir y para disparar al núcleo es estrecho. Propuesta: que las `blink_platform` de la arena sean de una vía (un parámetro `one_way`, por defecto falso para no cambiar el 1-3) o mover las campanas laterales a las columnas 2 y 21.
4. **La plataforma central (cuarta copia en Raíz) es el sitio más difícil.** Está a 256 px del suelo (el salto llega a 192) y a 2 tiles de hueco de las laterales, que en la fase 3 parpadean (en Raíz, compás de 1,4 s) y tienen una campana encima. El bot sube a una lateral encendida y salta a la central desde su borde interior con el **dash aéreo, soltando el Debug** (no se combinan) y volviéndolo a activar arriba, como permite §2.7; con el Debug mantenido no lo consigue. El validador de arenas la da por alcanzable con la rejilla estática (laterales de una vía y siempre presentes), sin el parpadeo, lo macizo de las laterales ni las campanas. Propuesta: que el validador modele la subida de la fase 3 con las `blink_platform` y que la ayuda de las copias sugiera soltar el Debug para subir.
5. **Sin errores del jefe.** El bot no encontró ataques injustos (todo se esquiva con el aviso de 9 cuadros), ni ventanas imposibles, ni bugs del jefe; ningún arreglo aplicado. Detalle de entrada para quien escriba bots: soltar y volver a pulsar una acción en el mismo cuadro no cuenta como pulsación nueva (el bot espera 3 cuadros entre toques).

**Tandas en paralelo:** (A) pasos 1, 2 y 4 a la vez, y el 3 en cuanto exista `BossBase`; (B) el 5 tras el 2 y el 4, con el 11 (arte) empezando en paralelo; (C) las fases 6 → 7 → 8 van en serie (comparten `AlertMajor`), con el 9 (HUD) y el 11 (arte) al lado; (D) el 10 tras la fase 3, con el 12 (textos, ayudas y sonidos) en paralelo; (E) el 13 y después el 14 y el 15 a la vez; (F) el 16 al final.

**Tamaño total estimado:** del orden del 1-3 (unos 10-14 días de trabajo de agente, en tandas). Lo más caro son la fase 3, el validador de arenas y el bot.

### 6.3 Rendimiento y ritmo tras la primera prueba (2026-10-21)

El usuario jugó la pelea y la sintió «muy torpe y lenta… un poco lenta y pesada». Se midió primero el rendimiento y después se reafinó el ritmo, sin tocar el diseño (3 fases, golpes 3/3/3 y 4/4/4, marca de 4 / 3 / 2,5 s, energía).

**Rendimiento (medido con ventana, monitor de 120 Hz, pelea completa del humo con y sin el Debug mantenido):** la pelea va a 118-120 FPS en todas las fases y ventanas (p95 del cuadro 8,3 ms), con y sin Debug; no hay costes por cuadro como el del 1-3 (`load()` en `_draw`). Solo había **un tirón de 75-142 ms al salir el primer pop-up de la fase 2** (o el escudo): `OverlayPopup` cargaba `tower_objects_frames.tres` (toda la hoja de los objetos de la torre) en su `_ready`, y la caché de recursos la soltaba al liberarse el último pop-up. Arreglo: caché estática de las SpriteFrames en `OverlayPopup` (`frames_for`, `preload_frames`) y `AlertMajor` la precarga al montar la arena. Después: máximo de la fase 2 16,5 ms (sin Debug) y 8,3 ms (con Debug), 0 cuadros de más de 34 ms. El rendimiento no explicaba la sensación de lentitud: era ritmo.

**Ritmo: valores cambiados (antes → después), todos en `data/bosses/alert_major.json`:**

| Valor | Antes | Después | Por qué |
|---|---|---|---|
| `arena.hover.speed_tiles_s` | 1,5 | **2,5** | El vuelo de lado a lado (16 tiles) tardaba 10,7 s: se veía flotar a cámara lenta. Ahora 6,4 s. |
| `arena.move_s` (bajar y subir, lineal) | 0,6 s | **`descend_s` 0,4 s con `descend_ease` `out_cubic`; `ascend_s` 0,45 s con `ascend_ease` `in_out_cubic`** | La bajada lineal se sentía pesada; ahora cae rápido y frena al llegar (como un golpe) y sube con arranque y frenada suaves. También las copias de la fase 3. |
| `phase1.spit_warn_frames` | 9 | **7** (0,58 s) | Escupir no daña: aviso nítido pero más corto (dentro de 6-12). |
| `phase1.spit_cooldown_s` | 1,0 s | **0,4 s** | Tiempo muerto tras subir antes de escupir otra vez. |
| `phase1.hold_sweeps_for_window` (nuevo) | — (no existía) | **`true`** | Antes, con las dos Burbujas neutralizadas, el jefe solo bajaba en el hueco de 0,25 s entre dos barridos (cada barrido ocupa 2,75 s de cada 3 s) y el aturdimiento de 3 s podía caducar. Ahora no empieza barridos nuevos y baja en cuanto acaba el que está en curso. |
| `phase2.popup_first_s` | 1,5 s | **1,0 s** | Arranque de la fase menos vacío. |
| `phase2.popup_warn_frames` | 9 | **7** (0,58 s) | El pop-up no daña. |
| `phase2.burst_first_s` | 3,0 s | **2,0 s** | Arranque de la fase menos vacío. |
| `phase2.window_every_s` | 12 s | **9 s** | Era el mayor tiempo muerto de la pelea (12 s flotando entre ventanas). Con 7-8 s el bot torpe acababa recibiendo golpes o con la energía en 13 (menos tiempo para recargar entre ventanas); 9 s mantiene su energía mínima. |
| `phase3.split_warn_frames` | 9 | **7** (0,58 s) | Dividirse no daña. |
| `phase3.return_s` | 0,6 s | **0,4 s** | La vuelta de la copia tras el lanzamiento. |

**Sin cambiar:** los avisos de lo que daña (ráfaga 9, lanzamiento 9; barrido, campana y plataforma que parpadea son objetos compartidos con el 1-2 y el 1-3 y siguen en 9), las ventanas (fase 1 5 s, fase 2 4 s, fase 3 5 s: el validador pide 4,23 / 2,63 / 4,86 s con k = 2), `perch_s` 7 s (pide 6,36 s), los intervalos de barridos (3 s) y ráfagas (4,5 s), el compás y el parpadeo de la fase 3 (2,0 / 1,6 / 1,4 s; 0,55 / 0,65 / 0,72: los fijan las campanas y la regla «encendida ≥ aviso + 0,25 s») y la energía. **Márgenes del validador sin cambios:** Caché 32,5 (≥ 25), Kernel 22,5 (≥ 20), Raíz 20 (≥ 20). Los avisos acortados siguen dentro de 6-12 cuadros.

**Duración medida (antes → después):** humo `tools/smoke_boss_arena.gd` (jugador instantáneo) 36,3 → 29,5 s de pelea (`--full` de vuelta en el hub a los 35,9 s). Bot del jefe (`tools/play_boss_bot.gd`, barra base): ideal Caché 57,5 → **52,8 s**, Kernel 63,8 → 54,2 s, Raíz 44,1 → 39,4 s; torpe Caché 196 → **169 s**, Kernel 217 → 179 s, Raíz 229 → 207 s; 0 golpes y 0 muertes; energía mínima del torpe igual (32 / 32 / 43). La fase 3 del ideal no cambia (25,2 s): va al compás y lo ahorrado se lo come la espera al siguiente tiempo.

**Para decidir con el usuario:**

1. **Duración frente al objetivo.** La pelea limpia ya estaba por debajo de los 90-120 s (y de los 100-130 s de §2.12): el bot ideal es casi perfecto, y quitar tiempo muerto la acorta más. Para alargarla sin tiempo muerto, las palancas son las del bot (§6.2): marca más corta, más golpes por fase o ventanas que se cierran al caducar la marca.
2. **El Debug pone el mundo a ×0,5.** Con el Debug activo todo el jefe va a la mitad (ataques, vuelo, ventanas y compás), y cargarlo pide 1 s quieto (`activation_hold_s`). Con la marca basta mantenerlo ≈ 1 s y soltarlo tras el pulso; quien lo deja puesto siente la pelea lenta. Son valores globales del Debug (afectan al 1-2 y al 1-3, cuyos validadores y bots no deben cambiar), así que no se han tocado. Opciones: dejarlo (el Debug es «ver y marcar»), o una escala propia de la arena (p. ej. ×0,7) como el `debug_drain_scale` del nivel.
3. **«Peso» que depende del arte (paso 16, sin tocar):** el cuerpo solo tiene tres poses fijas (`rest`, `inflate`, `down`) que cambian de golpe; faltan cuadros de anticipación y aplastamiento al bajar y al aterrizar, de estiramiento al subir, un leve balanceo al flotar y una estela en el lanzamiento de las copias (hoy una sola imagen `lunge`). Con esos cuadros el movimiento se leerá más ágil sin cambiar los tiempos.

### 6.4 Ajustes tras la primera prueba y los bots (2026-10-21)

Cuatro decisiones del orquestador tras la prueba del usuario («torpe, lento y pesado») y los hallazgos 2-4 de §6.2 y 2 de §6.3. Sin tocar: la duración objetivo (`target_duration_s` 240), las ventanas (5 / 4 / 5 s), el escudo (`perch_s` 7 s), el compás y el parpadeo de la fase 3, la marca (4 / 3 / 2,5 s) ni el arte (paso 16). Todo en datos. Un commit por cambio.

**Valores cambiados (antes → después):**

| Valor | Antes | Después | Dónde |
|---|---|---|---|
| Mundo con el Debug en la arena | ×0,5 (global, `data/debug_mode.json`) | **×0,7** (`debug_world_scale` del nivel; ×0,56 con Debug 4: conserva la proporción 0,4 / 0,5) | `data/levels/1-boss.json` |
| Mundo con el Debug en el 1-1, 1-2, 1-3, hub y salas de prueba | ×0,5 | ×0,5 (sin el campo: sin cambios; la salida del validador de 1-1 / 1-2 / 1-3 es idéntica byte a byte) | — |
| `phase2.burst_spacing_s` | 0,5 s | **0,9 s** | `data/bosses/alert_major.json` |
| `phase2.burst_every_s` | 4,5 s | **4,75 s** (la ráfaga dura ahora 0,75 + 2 × 0,9 + 2,2 = 4,75 s y el validador exige que quepa) | `data/bosses/alert_major.json` |
| Laterales de la fase 3 (`blink_platform`) | macizas (cabezazo desde debajo) | **de una vía** (`one_way: true`, param nuevo; por defecto `false`: el 1-3 no cambia) | `data/levels/1-boss.json`, `data/world1_objects.json`, `scripts/levels/blink_platform.gd` |
| Campanas `campana_1` / `campana_3` | columnas 5 y 18 (caían encima de las laterales) | **columnas 2 y 21** (mismos desfases 0 y 2/3) | `data/levels/1-boss.json` |
| Ayuda Q `notification_shot` | «… deslízate a través o cambia de altura.» | «… deslízate a través de cada una, retrocediendo un paso entre una y otra, o cambia de altura.» | `data/help.json` |
| Ayuda Q `alert_major_clone` | (sin frase de la central) | + «Si una se posa en la plataforma del centro y no llegas, suelta el Debug: en el aire podrás deslizarte.» | `data/help.json` |
| `debug_drain_scale`, cargadores, marca | 0,25; 4 de +50 (4 / 5 / 6 s); 4 / 3 / 2,5 s | **sin cambios** (ver energía) | — |

**1) Escala propia del Debug (×0,7).** Campo de nivel `debug_world_scale` (0 < x ≤ 1; sin él, la global). `GeneratedLevel` lo aplica al entrar (`DebugMode.set_level_world_scale`) y lo quita al salir (también al volver al hub); si el Debug está activo, el mundo cambia al instante. Esquema, `tools/build_level.py` (solo lo escribe si está en el JSON), el plan del validador (`Rules.set_level_debug_world_scale`; línea «mundo con el Debug en este nivel» solo si el nivel lo tiene) y el validador de arenas lo usan. La carga del Debug no cambia (1 s): no para a Isak (solo impide el dash), así que el validador añade la estrategia **«Debug cargado en marcha»** (corre mientras carga). **Ventanas con ×0,7 (k = 2):** fase 1 3,73 s de 5 (antes 4,23 con ×0,5 y sin la estrategia nueva), fase 2 2,89 de 4 (2,63), escudo 6,36 de 7 (igual: sin Debug), fase 3 laterales 4,61 de 5 (4,86), centro del suelo 2,89 y central 3,49. Sin la carga en marcha, ×0,7 dejaba las laterales de la fase 3 en 6,0 > 5. **Avisos:** se cuentan en cuadros del mundo (6-12); con el Debug a ×0,7 duran ×1,43 en tiempo real (antes ×2), nunca menos que sin el Debug. **Marca:** el validador comprueba que en la marca, en el caso peor (sin el Debug, a ×1), caben los láseres de la peor ventana torpe (2 golpes + 1 fallado = 3): Caché 6, Kernel 4, Raíz 4 (con el Debug a ×0,7: 8 / 6 / 5; con ×0,5 eran 12 / 9 / 7).

**Energía recalculada.** El gasto del Debug va en tiempo real (5/s en la arena) y el modelo torpe cuenta segundos reales de Debug por ventana: el mundo más rápido no lo sube (lo que el torpe hace con el Debug esperando al mundo —subir al compás, esperar a la copia— dura menos en tiempo real, así que los segundos del modelo quedan por encima). La marca sigue dando para todos los disparos (arriba). **Márgenes del validador (barra base 100), antes → después:** Caché **32,5 → 32,5**, Kernel **22,5 → 22,5**, Raíz **20 → 20** (picos torpes 55 / 60 / 67,5, 55 / 70 / 77,5 y 55 / 70 / 80). No hizo falta tocar `debug_drain_scale` ni la marca.

**2) Ráfaga.** Con 0,75 s (lo propuesto) el dash **no** basta: medido con el Isak real, el dash (192 px) acerca a Isak 0,3 s a la siguiente notificación y la velocidad de salida del dash (360 px/s hacia ellas) apenas deja retroceder en el enfriamiento; 0,8 y 0,85 s tampoco; **0,9 s sí**, si entre dash y dash Isak vuelve corriendo hacia atrás (`tests/test_alert_major.gd`, `test_dash_goes_through_the_whole_burst`). El validador lo comprueba: separación ≥ duración + enfriamiento del dash + (distancia del dash − retroceso) / velocidad de la notificación (0,86 s; retroceso = la mitad del enfriamiento a `run_speed`, calibrado con esa prueba) y cada notificación pasa por Isak en 0,15 s, dentro de los 0,3 s invulnerables. `burst_every_s` sube a 4,75 s para que la ráfaga (4,75 s) quepa en su intervalo (regla «nunca dos ráfagas a la vez»). La ayuda se ajustó para decir cómo se hace.

**3) Laterales de una vía y campanas.** `blink_platform.one_way` (colisión de una vía de su tarjeta; con Isak dentro sigue sin materializarse hasta que salga). Las campanas de las columnas 5 y 18 caían encima de las laterales (3-6 y 17-20): ahora en la 2 y la 21. El validador da error si la onda de una campana (48 px) cae sobre una plataforma que parpadea; el compás sigue sin dos ondas a la vez.

**4) Plataforma central en Raíz.** El validador de arenas (regla 7c) monta la geometría de la fase 3 (laterales de una vía o macizas) y busca el camino desde el suelo de `window_from` a la central: **sin dash** (con el Debug activo: suelo → lateral saltando desde debajo → central saltando corriendo desde el borde, (7, 9) → (6, 7) → (9, 5)) y **con salto + dash aéreo** (soltando el Debug); los dos existen. La lateral encendida (Raíz, compás 1,4 s × 0,72 = 1,01 s, sin el Debug) da para aterrizar y despegar (0,2 s) antes de su aviso (0,75 s): **margen 0,06 s** (con el Debug activo, a ×0,7, 0,17 s); la ventana cubre además la espera a que la lateral se encienda (0,39 s): hacen falta 4,03 s de 5. En la central hay 3 celdas desde las que el pulso llega al núcleo fuera de la onda de la campana de la columna 11, y la de llegada (9, 5) también. No hizo falta tocar la arena. La ayuda de las copias sugiere soltar el Debug para subir con el dash aéreo.

**Bot del jefe tras los cuatro cambios** (barra base, `--fixed-fps 60`): ideal Caché / Kernel / Raíz **67,5 / 67,3 / 53,8 s** (antes 52,8 / 54,2 / 39,4: la fase 2 dura más por la ráfaga de 4,75 s), energía mínima 66 / 57 / 50; torpe **183 / 175 / 203 s** (antes 169 / 179 / 207), energía mínima **53 / 32 / 51** (márgenes 32,5 / 22,5 / 20); **0 golpes y 0 muertes** en los seis; quieto pierde (game over a los 182 s). Dos arreglos del bot (no del juego): con la ráfaga más larga volvía a subir al escudo en mitad de las notificaciones (ahora espera en el otro carril también desde el suelo) y el Debug «de más» del torpe para ver los pop-ups no contaba mientras esquivaba (se quedaba encendido toda la ráfaga). Humo: pelea 29,5 s, `--full` en el hub a los 35,9 s. Bot del 1-3: 0 golpes.

**Para decidir con el usuario:** (1) la ráfaga a 0,9 s alarga la fase 2 unos 15 s en la pelea limpia; si se prefiere 0,75 s, el dash solo atraviesa una notificación (dash + cambio de altura). (2) El margen de la lateral en Raíz sin el Debug (0,06 s) es justo: es el acceso más exigente; si al jugar se queda corto, la palanca es `blink_on_fraction` de Raíz (0,72) o el compás más rápido (1,4 s).
