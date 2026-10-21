# Propuesta: jefe del Mundo 1, «Alerta Mayor»

**Estado:** **aprobada el 2026-10-20** con las decisiones del usuario de §5 (las 8 resueltas). Sin implementar: el plan está en §6. Es solo diseño: no cambia código ni datos. Lo que sigue marcado **PROPUESTA** son detalles que se ajustan al implementar y jugando, no decisiones abiertas. Los valores son orientativos: se ajustan jugando y con el validador. **Los textos de Eco, del jefe y del sistema están por escribir con el usuario**; la historia no se escribe aquí.

**Cambios del 2026-10-20 (aprobación):** **no hay rollback** al final de la pelea (se eliminan el «amago de rollback», las líneas «Restaurando copia anterior…» / «Error: copia incompleta», la señal `boss_rollback_attempted` y el uso de `sfx_boss_rollback_easy`; la fase 3 termina con el golpe final, §2.8); **energía rehecha con números reales** (§2.4): 4 cargadores de arena con 4 s de enfriamiento y el Debug a mitad de gasto dentro de la arena; plan de implementación por pasos (§6).

**Fuentes:** `mundo-1-notificaciones.md` §6.6 (ficha original del jefe), `propuesta-1-3.md` (§3.6 cierre, §4 patrones del dash, §5 objetos del 1-3, §7 plan), `propuesta-recuerdos.md` (§4, §5, §7 paso 5 y §8), `propuesta-asistentes-y-vidas.md` §5.3, `propuesta-hub-y-guardado.md` §3.3, `05-hub.md` §13.4, `04-personajes.md` §12.1, `07-estilo-visual.md` §15.5, `propuesta-mejoras.md` §4, `lista-sonidos.md` §4, `preguntas.md` (V10 punto débil, tres vueltas) y el código (`scripts/bosses/weak_point.gd`, `scripts/autoload/debug_mode.gd`, `scripts/levels/charger.gd`, `data/weak_point.json`, `data/isak_abilities.json`, `data/debug_mode.json`, `data/upgrades.json`, `data/passive_regen.json`, `data/enemies/*.json`, `data/levels/1-3.json`, `scripts/levels/*`, `data/hub.json`).

**Física y habilidades de referencia** (de los datos actuales): pulso gratis, radio 96 px, solo en el suelo, pose 0,33 s. Láser 10 de energía, 768 px, horizontal, solo en el suelo, enfriamiento 0,4 s, daño 1. Debug: mantener 1 s (la carga no gasta), después **gasto continuo de 20 por segundo real** mientras está activo, mundo ×0,5; se apaga con otra pulsación o al llegar a 0, y para volver a activarlo hay que cargar otra vez 1 s; el pulso y el láser **sí** funcionan con el Debug activo; el dash **no** (regla «no se combinan»). Dash 192 px en 0,2 s, invulnerable 0,3 s, 10 de energía, enfriamiento 0,5 s, uno en el aire. Golpe recibido −10 de Sync Rate, 1 s de invulnerabilidad. Energía 100 (110-120 con las mejoras de Caché). Andar 220 px/s (3,4 tiles/s), correr 360 px/s (5,6 tiles/s). Salto: subidas cómodas de 2 tiles.

---

## 0. Resumen

- **Acceso:** la terminal «Deslizar para desbloquear» del 1-3 devuelve al hub (decisión 2). En la carpeta del Mundo 1 aparece la fila **«Jefe: Alerta Mayor»**, disponible cuando el 1-3 está completado. Se entra como a cualquier subnivel: con la confirmación «¿Seguro? Aún no has guardado.» si hay cambios sin guardar, 3 vidas por intento y game over con rollback a la última copia, como en todo el juego.
- **El jefe:** un badge rojo enorme con «99+». Su contador baja con cada golpe al núcleo: **99+ → 66 → 33 → 0** (9 golpes en Caché). Tiene tres fases. **Fase 1:** lanza Burbujas y banners. **Fase 2:** pop-ups que tapan la vista y ráfagas de notificaciones. **Fase 3:** copias falsas, campanas al compás y plataformas que parpadean. Solo se le hace daño en el **núcleo**, que solo se ve con el Debug.
- **Cómo se vence:** se abre la ventana con la mecánica de cada fase (aturdir, cerrar, descubrir). Después se activa el Debug y se golpea el núcleo con el pulso o el láser. **El noveno golpe es el golpe final:** el contador llega a 0, el jefe se desarma en píxeles e Isak recibe la **capa Caché** del recuerdo del Mundo 1. **No hay rollback** en esta pelea (decisión 1).
- **Energía:** en la arena hay **4 cargadores** (+50, enfriamiento de **4 s**) repartidos por el suelo y el Debug gasta **la mitad** (10 por segundo). Con eso, hasta una pelea torpe cabe en una barra de 100 sin mejoras con al menos 25 de margen por ventana (§2.4).

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
| Punto débil | El componente `WeakPoint` ya existe: solo es visible con el Debug, se dibuja por encima del tinte en carmín pulsante y aún no recibe daño. | `preguntas.md` V10, `scripts/bosses/weak_point.gd` |

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
- **Debug a mitad de gasto en la arena (aprobado, §2.4):** campo de nivel `debug_drain_scale: 0.5`.
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
- **Solo cuenta un golpe al núcleo con el Debug activo** (la ficha: «obliga a gastar energía»). Fuera del núcleo, o sin el Debug, el pulso o el láser sacan una **chispa gris** sobre el cuerpo (la del láser sin energía) y no hacen daño. Valen el **pulso** (de cerca, 96 px, en el suelo o en una plataforma, gratis) y el **láser** (a distancia, horizontal, 10 de energía). Cada impacto es **1 golpe**. El Láser 4 (daño 2) no se alcanza en Caché; desde Kernel cuenta como 2.
- **El dash nunca hace daño** (`propuesta-1-3.md` §2.2: no aturde ni daña). Atraviesa el cuerpo del jefe (no es sólido), los banners, las ondas y los proyectiles, siempre que Isak sea invulnerable. No se combina con el Debug, y de ahí sale la tensión de la pelea: **esquivar** (dash) o **ver y golpear** (Debug), nunca las dos cosas a la vez. Es el patrón futuro «Deslizar el núcleo» de `propuesta-1-3.md` §4.
- **El Debug como ayuda:** todos los ataques del jefe van en **tiempo del mundo**, así que con el Debug activo van a la mitad de velocidad. Las ventanas también se alargan en tiempo real (y por eso pueden salir caras de energía: §2.4).
- **Isak:** cada golpe del jefe resta **−10 de Sync Rate** (como todos los enemigos del Mundo 1), con el retroceso y la invulnerabilidad de siempre. Con Sync 100 aguanta 10 golpes por vida.

### 2.4 Energía: números reales y solución (aprobado el 2026-10-20)

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

#### 2.4.5 Solución elegida

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

### 2.5 Fase 1 «99+»: notificaciones que llegan (99+ → 66)

**Qué enseña:** que el núcleo existe, que se ve con el Debug y que hay que gastar con cabeza. Repite los patrones 7 («Cortina») y 6 («Esquivar») del 1-3.

| Ataque | Telegrafiado | Cómo se responde | Mecánica reutilizada |
|---|---|---|---|
| **Lanzar Burbujas:** el jefe escupe 2 Burbujas que caen en las plataformas laterales y patrullan. Nunca hay más de 2 vivas. | El «99+» se infla y una flecha `alerta` marca dónde caerán, 9 cuadros antes. | Pulso (aturdidas 3 s) y, si se quiere energía, dos disparos de láser (+25, neto +5). | `alert_bubble` (vida 2, contacto −10) |
| **Barrido:** un banner barre el carril del suelo o el alto, uno cada vez, cada 3 s. | El aviso de 9 cuadros en la ranura del muro y en el suelo, como `spam_banner`. | Cambiar de carril (saltar a la plataforma o bajar) o atravesarlo con el dash. | `spam_banner` (640 px/s, −10) |

**Ventana:** cuando las **2 Burbujas están aturdidas o derrotadas a la vez**, el jefe se queda «sin notificaciones que enviar»: se desinfla y **baja al suelo** del centro (columnas 10-13) durante **5 s del mundo** (≈ 10 s reales con el Debug). Mientras está abajo no hay barridos. El núcleo queda a la altura del pecho de Isak, a 1 tile del suelo: se alcanza con el pulso desde las columnas 9 o 14 y con el láser desde cualquier punto del carril del suelo. Los cargadores 2 y 3 (columnas 8 y 15) quedan a un paso para entrar lleno. **Solución:** Debug (1 s), golpe y, si da tiempo, un segundo golpe; pasa a menudo con el pulso, que es gratis. Al cerrarse la ventana, el jefe sube y lanza 2 Burbujas nuevas. **3 golpes** para pasar de fase: 2 ventanas si se aprovechan bien, 3 si no.

### 2.6 Fase 2 «66»: no veas nada (66 → 33)

**Qué enseña:** el pop-up translúcido del 1-2 (pulso a su botón; el Debug ve a través) y el dash del 1-3 contra los proyectiles. La ficha original: «Cubre la pantalla con pop-ups que tapan la vista. Hay que cerrarlos con el pulso y esquivar con dash».

| Ataque | Telegrafiado | Cómo se responde | Mecánica reutilizada |
|---|---|---|---|
| **Lluvia de pop-ups:** cada 6 s aparece un pop-up translúcido (70 %) que tapa un cuarto de la arena durante 8 s. Hay como mucho 2 a la vez y nunca tapan el mismo cuarto que Isak cuando aparecen. | Contorno punteado `banner_blanco` 9 cuadros antes. | Pulso a su botón de 24 px (siempre a la altura de un carril) para cerrarlo, o el Debug para ver a través (baja al 15 %). | `overlay_popup` |
| **Ráfaga de notificaciones:** tres notificaciones pequeñas (proyectiles de 1 × 0,5 tiles) cruzan un carril a 640 px/s, separadas 0,5 s. | Flecha `alerta` en el muro de entrada y una línea discontinua por el carril, 9 cuadros antes. | Dash a través (invulnerable 0,3 s), o cambiar de carril. Con el Debug activo no hay dash: se salta. | Proyectil nuevo, `notification_shot` (familia del banner) |

**Ventana:** cada 12 s el jefe baja a una plataforma lateral (la que queda lejos de Isak). Allí se protege con un **pop-up escudo**: un `overlay_popup` opaco sobre el núcleo, con el botón de cerrar abajo, alcanzable con el pulso desde esa plataforma. **Solución:** subir a la plataforma (dash o salto para esquivar la ráfaga), **pulso** al botón (el escudo cae), **Debug** y **golpe** (pulso o láser) antes de 4 s del mundo. Si no da tiempo, el jefe se vuelve a cubrir y sube. **La decisión de la fase:** con el Debug activo se ve a través de los pop-ups y el jefe va más lento, pero no hay dash. **3 golpes**: 2-3 ventanas.

### 2.7 Fase 3 «33»: ¿cuál es la de verdad? (33 → 0)

**Qué enseña:** todo el 1-3 a la vez, con el ritmo como base. La ficha original: «Aparecen notificaciones falsas, copias del jefe. Solo la real tiene núcleo bajo el Debug».

- **Metrónomo de la fase:** al entrar en la fase 3 arranca un `rhythm_zone` en toda la arena (tiempo del mundo, ciclo de **2,0 s**, sin aceleración en Caché), con el icono de vibración en el fondo y el tic de accesibilidad (`sfx_metronome_tick`, activado por defecto).
- **Plataformas que parpadean:** las dos laterales pasan a ser `blink_platform`, grupos A y B alternos, con 4 segmentos y aviso de 9 cuadros. La central sigue fija: es el refugio en alto. Los cargadores están en el suelo: no les afecta el parpadeo.
- **Campanas:** 3 `alarm_bell` en el techo (columnas 5, 11 y 18). Cada una suena en su desfase del compás: aviso de 9 cuadros y una onda de 1 tile de ancho hasta el suelo durante 0,4 s. Nunca suenan dos campanas en el mismo tiempo del compás, así que siempre queda un hueco seguro.

| Ataque | Telegrafiado | Cómo se responde |
|---|---|---|
| **Copias:** el jefe se divide en 3 badges iguales (la real y 2 copias) que bajan a tres sitios: plataforma izquierda, suelo del centro y plataforma derecha. | Las tres se inflan 0,75 s antes de bajar y aterrizan en un compás. | Debug: solo la real muestra el núcleo carmín (`WeakPoint` ya funciona así). |
| **Lanzamiento:** las tres se lanzan contra Isak, una por compás, como el punto rojo (se inflan 9 cuadros y se lanzan 0,3 s). | El inflado y una línea `alerta` hacia Isak. | Dash a través (patrón 6, «Esquivar y contraatacar»), o saltar. |

**Ventana:** tras los tres lanzamientos, las copias se quedan quietas 5 s del mundo en sus sitios. **Solución:** Debug (el núcleo delata a la real; con el Debug también van más lentas las campanas), **ir hasta ella sin usar el dash** (pisando las plataformas encendidas o desde el suelo) y **golpe**. Quien prefiera ahorrar puede mirar, apagar el Debug, ir y volver a activarlo junto a la real (la carga no gasta). Si Isak golpea una copia, esta **se descarta con un «pop» y suelta una Burbuja** (decisión 6): cuesta tiempo y energía, no Sync. Después las tres vuelven a subir y se mezclan. **3 golpes**: 3 ventanas. **El tercero es el golpe final** (§2.8).

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
| `alert_major` | «Es la alerta de todas las alertas. Tiene un núcleo, pero solo se ve con el Debug. Golpéalo cuando baje.» |
| `boss_popup_shield` (Objeto) | «Se tapa con un pop-up. Ciérralo con el pulso y tendrás unos segundos.» |
| `alert_major_clone` | «Copias. Solo una tiene núcleo: mira con el Debug antes de golpear.» |
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
- **Ventanas:** se aplica la fórmula de `propuesta-1-2.md` §0.1 con k = 2 (dificultad 3). Ventana ≥ 2 × (recorrido hasta el núcleo + 1 s de carga del Debug + pose del golpe). Por ejemplo, en la fase 1: 2 × (1 s + 1 s + 0,33 s) ≈ 4,7 s ≤ 5 s del mundo.
- **Por acceso (PROPUESTA; se cierra al hacer Kernel y Raíz, como el resto de vueltas):** el jugador solo ve «Acceso: Kernel» o «Acceso: Raíz». Ningún texto dice vuelta ni dificultad. Lo decidido es que «los puntos débiles cambian en cada vuelta». La energía de cada acceso está en §2.4.6.

| | Caché | Kernel | Raíz |
|---|---|---|---|
| Golpes | 9 (3/3/3) | 12 (4/4/4) | 12 (4/4/4) |
| Núcleo | Abajo, de frente | **Detrás** (el «botón de descartar» de la espalda): hay que atravesar el lanzamiento con el dash para quedar detrás | Cambia de copia cuando se activa el Debug (una vez por ventana) |
| Fase 1 | 2 Burbujas | 2 Burbujas + 1 punto rojo | 2 Burbujas + 2 puntos rojos |
| Fase 2 | 2 pop-ups a la vez | 3 a la vez | 3, y la ráfaga en los dos carriles alternos |
| Fase 3 | Compás de 2,0 s fijo | 2,0 → 1,6 s | 2,0 → 1,6 → 1,4 s y 4 copias |
| Energía en la arena | Debug ×0,5; 4 cargadores de 4 s | Debug ×0,5; 4 cargadores de 5 s | Debug ×0,5; 4 cargadores de 6 s |
| Ocultarte | No existe | Sin efecto en el jefe (recomendado) | Sin efecto |

---

## 3. Cómo se vence

### 3.1 Solución ideal, paso a paso (Caché, sin mejoras)

1. **Llegada:** Isak llega por el vórtice. El «99+» se infla (`sfx_boss1_intro`) y sale la línea de intro (pausa). Al cerrarla empieza la fase 1.
2. **Fase 1, primera ventana:** el jefe escupe 2 Burbujas a las plataformas. Isak sube a la plataforma izquierda y aturde la Burbuja con el pulso. El banner barre el suelo y él sigue en lo alto. Baja con un dash que atraviesa el siguiente barrido, sube a la plataforma derecha y aturde la segunda Burbuja. Ventana: el jefe baja al centro. Isak se pone en la columna 9, mantiene el Debug (1 s), lanza un pulso (golpe 1 → 88) y otro pulso (golpe 2 → 77). Suelta el Debug (≈ 10 de energía con el gasto de la arena).
3. **Fase 1, segunda ventana:** esta vez remata una Burbuja con dos disparos (+25 de energía), aturde la otra y repite: Debug y pulso (golpe 3 → **66**). El jefe suelta las 2 recargas de cambio de fase.
4. **Fase 2:** aparece el primer pop-up. Isak lo cierra con el pulso si tapa su carril, o lo ignora. Llega la ráfaga por el suelo: dash a través. El jefe baja a la plataforma derecha con el escudo. Isak sube, lanza un pulso al botón (cae el escudo), activa el Debug y dispara el láser al núcleo (golpe 4 → 55); da tiempo a un pulso más (golpe 5 → 44). En la siguiente ventana, en la plataforma izquierda: pulso al botón, Debug y pulso (golpe 6 → **33**). No le hace falta recargar (le quedan unos 36).
5. **Fase 3:** arrancan el metrónomo, las campanas y las plataformas que parpadean. Bajan las 3 copias. Isak atraviesa con el dash los tres lanzamientos, uno por compás, desde el suelo del centro, entre ondas, y toca el cargador 2 o 3 de paso. Ventana: Debug. El núcleo está en la de la plataforma derecha. Sube cuando la plataforma B se enciende (con el Debug, el compás va a la mitad) y golpea con el pulso (golpe 7 → 22). Se repite dos veces, recargando de paso entre ventanas (golpe 8 → 11 y golpe 9 → **0**).
6. **Final:** el noveno golpe es el golpe final (§2.8): todo se detiene y el jefe se desarma en píxeles.

### 3.2 Errores típicos y cómo se recupera

| Error | Qué pasa | Recuperación |
|---|---|---|
| Activar el Debug antes de abrir la ventana | Gasta energía sin poder golpear (el núcleo no está a tiro). | Soltar el Debug; hay un cargador a ≤ 3,5 tiles. |
| Mantener el Debug toda la ventana | Gasta 10 por segundo; una ventana entera de la fase 1 cuesta hasta 100. | Golpear y apagarlo; la carga de 1 s para volver a activarlo no gasta. |
| Golpear el cuerpo, o el núcleo sin el Debug | Chispa gris, sin daño. La Q de `alert_major` lo explica. | Debug primero. |
| Intentar el dash con el Debug activo | No sale (chispa gris, `dash_denied`). | Soltar el Debug o saltar; con el Debug, el ataque va a la mitad de velocidad. |
| Quedarse sin energía | Sin Debug no hay daño. | Los 4 cargadores (4 s), las Burbujas (+25) y las recargas de cambio de fase. Al reaparecer, mínimo 50. |
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
| `WeakPoint` ampliado | Hurtbox que **solo recibe** pulso o láser con `is_revealed()` (Debug); señal `hit`; chispa gris si no está revelado. | Mantiene el aspecto y la capa actuales (`data/weak_point.json`). |
| `scripts/bosses/alert_major_clone.gd` | Copia de la fase 3 (lanzamiento como `notification_badge`; se descarta al golpearla y suelta una Burbuja). | |
| `scripts/bosses/notification_shot.gd` | Proyectil horizontal de la ráfaga (familia del banner: el dash lo atraviesa; el láser y el pulso no le afectan). | `help_id` `notification_shot`. |
| Pop-up escudo | `overlay_popup` con params nuevos `opaque`, `follow` (sigue al jefe) y `respawn_s`, o un tipo `boss_popup_shield`. | Mejor ampliar el existente. |
| Arena | `data/levels/1-boss.json` (24 × 12; `kind: "boss"`, `boss: "alert_major"`, **4 cargadores con `cooldown_s` 4**, **`debug_drain_scale` 0,5**, plataformas, campanas y `blink_platform` inactivas hasta la fase 3) y la escena `scenes/levels/1-boss.tscn` generada con `tools/build_level.py`. | Esquema: `kind`, `boss`, `debug_drain_scale` (0-1, por defecto 1) y objetos que se activan por fase (`active_in_phase`). |
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
| `sfx_boss_defeat` → `stg_boss_defeated` → `mus_memory` | Golpe final, desarme y recompensa |
| `mus_boss1` | Bucle de la pelea; sube una capa por fase. La sincronización con el metrónomo de la fase 3 queda como extra opcional (decisión 3 de audio). |
| `amb_boss1_lockscreen` | Ambiente de la arena |
| `vox_boss_eco_filter`, `mus_eco_motif` | Eco hablando por el jefe |
| `sfx_hub_wallpaper_piece` | Pieza cian del hub |
| Reutilizados | `sfx_charger` (suena a menudo en la arena), `sfx_banner_warn/sweep`, `sfx_popup_appear/close`, `sfx_alarm_bell_warn/wave`, `sfx_metronome_tick`, `sfx_blink_warn`, `sfx_dash_through`, `sfx_enemy_*`, `sfx_badge_lunge` |

`sfx_boss_rollback_easy` **no se usa** en este jefe (§1.2).

### 4.2 Validación y bot

- **Validador de arena** (`tools/validate_boss.py`, o un modo `--boss` de `tools/validate_level.py`): esquema de `1-boss.json`; subidas de 2 tiles medidas con el Isak real (`tools/level_climbs.py`); **alcance del núcleo** en cada posición de ventana (fase 1: centro del suelo; fase 2: las dos plataformas; fase 3: los tres sitios), con el pulso desde una celda de pie a ≤ 96 px o con el láser en la misma fila; **ventanas** con k = 2 (recorrido desde la peor posición + 1 s de Debug + pose); **avisos** de 6-12 cuadros en todos los ataques; **hueco seguro** en cada compás de la fase 3 (nunca dos campanas a la vez; siempre una celda sin onda ni barrido); `on_fraction` de las plataformas que parpadean (regla del 1-3); ningún ataque que barra los dos carriles a la vez; **energía (§2.4)**: con `debug_drain_scale`, la barra base (100), `--access-cap` y todo al máximo, el pico de la pelea torpe por ventana (`validation.boss_clumsy_debug_s`, por defecto 3,0 s de Debug más los dashes y láseres de la ventana) ≤ máximo − 20, cada celda de suelo con un cargador a ≤ 4 tiles y el presupuesto por fase (gasto frente a cargas, recargas de cambio de fase y drops).
- **Bot de jefe** (`tools/boss_bot.gd` + `tools/play_boss_bot.gd`): una pelea no es un camino, así que el bot **reacciona** con una política por fase leyendo la API de `BossBase` (como el bot del 1-3 lee `get_beat_phase()`). Solo usa acciones del Input Map, nunca Q ni Esc. Política: aturdir las Burbujas → esperar la ventana → Debug → pulso o láser → soltar el Debug; dash ante cada aviso de ráfaga o lanzamiento; cambiar de carril ante los barridos; recargar en el cargador más cercano por debajo de 40. Con `--fixed-fps 60` es determinista (semilla fija para los cuartos de los pop-ups y el orden de las copias). **Comprobaciones:** vence sin game over, 0 golpes en la solución ideal (o anota cuántos), duración frente a `target_duration_s`, energía mínima, la capa `boss_w1_l1` obtenida y la vuelta al hub con `1-boss` completado y el Mundo 2 desbloqueado. Modo **`--clumsy`**: mantiene el Debug 3 s por ventana y comprueba que la energía nunca llega a 0 en una ventana. **Negativos** (GUT): quedarse quieto pierde, golpear sin el Debug no baja el contador y el dash con el Debug no sale.
- **Pruebas GUT:** `tests/test_boss_base.gd` (fases, reaparición por fase con energía ≥ 50, contador, golpe final), `tests/test_alert_major.gd` (cada ataque con el tiempo avanzado a mano), `tests/test_weak_point_damage.gd`, `tests/test_debug_drain_scale.gd`, `tests/test_boss_reward.gd` (recuerdo sin guardar, red de seguridad, revancha sin entrega doble) y `tests/test_hub_boss_entry.gd`.

---

## 5. Decisiones del usuario (aprobadas el 2026-10-20)

| # | Pregunta | Resolución |
|---|---|---|
| 1 | ¿Qué es el «rollback de Easy» de Alerta Mayor? | **Ninguno.** No hay rollback tras el jefe de notificaciones, ni real ni simulado. Se eliminan el amago, sus líneas («Restaurando copia anterior…», «Error: copia incompleta»), la señal `boss_rollback_attempted` y el uso de `sfx_boss_rollback_easy` (retirado del jefe M1 y reservado para el jefe final en `lista-sonidos.md`). La fase 3 termina con el golpe final (§1.2, §2.8). |
| 2 | ¿La terminal del 1-3 lleva al jefe o al hub? | **Al hub** (aprobado). Se entra al jefe desde la carpeta del Mundo 1 (§1.3). |
| 3 | ¿Reaparición al morir? | **Al principio de la fase actual, con energía mínima de 50** (aprobado; §2.9). |
| 4 | ¿Cómo se hace daño? | **Aprobado:** solo golpes al núcleo con el Debug activo; pulso o láser, 1 golpe cada uno (Láser 4, 2 desde Kernel); el dash nunca daña. **Condición del usuario:** garantizar que haya energía para cargar, usar el Debug y seguir atacando. **Resuelto con números (§2.4):** 4 cargadores de arena (+50, 4 s) y el Debug a mitad de gasto en la arena (`debug_drain_scale` 0,5). Pico de la pelea torpe ≤ 75 en Caché (margen ≥ 25 con la barra de 100 sin mejoras); Kernel y Raíz con la misma regla (cargadores de 5 y 6 s, margen ≥ 20). Palanca de reserva: Debug sin gasto en la arena. |
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
| 3 | **`WeakPoint` dañable:** solo recibe pulso o láser con `is_revealed()`; señal `hit`; chispa gris sin Debug; Láser 4 = 2. Sala de prueba `boss_test` con un jefe «saco» (baja, se golpea y sube). **Hecho el 2026-10-21:** `WeakPoint` en la capa enemy y en `laser_activatable`; solo con `DebugMode.is_active()` (la carga y el revelado persistente no cuentan) el pulso (círculo contra círculo, 1 golpe) y el láser (su daño) emiten `hit`; sin el Debug, chispa gris (`gray_spark`) y `deflected`; `set_enabled(false)` lo apaga del todo; el dash no tiene ningún efecto. `BossBase.set_weak_point` / `get_core_target`. Saco `boss_dummy` (`BossDummy`, `data/bosses/boss_dummy.json`, 2 × 2 tiles; arte `_placeholder` de `tools/gen_boss_dummy_placeholder.py`) y sala `boss_test` (20 × 12, cargador de 4 s, terminal). Pruebas `tests/test_weak_point_damage.gd` (con el Isak real: pulso, láser y dash) y `tests/test_boss_data.py`. | `scripts/bosses/weak_point.gd`, `data/weak_point.json`, `data/levels/boss_test.json`, `tests/test_weak_point_damage.gd` | GUT: sin Debug no baja el contador; con Debug, pulso y láser restan 1; el dash nunca. `boss_test` jugable con `--start-level=boss_test`. | S | 2 (para el saco) | 1 |
| 4 | **Energía de la arena:** `debug_drain_scale` por nivel en `DebugMode` (lo fija `LevelRunner`; 1,0 por defecto y en el hub), esquema del campo, cargadores con `cooldown_s` 4 por instancia. | `scripts/autoload/debug_mode.gd`, `scripts/levels/level_runner.gd`, `tools/validate_level_schema.py`, `tests/test_debug_drain_scale.gd` | GUT: en un nivel con 0,5 el Debug gasta 10/s (7,5 con Debug 2) y en el 1-1/1-2/1-3 sigue en 20/s; salidas del validador del 1-1 al 1-3 idénticas. **Hecho el 2026-10-21:** `DebugMode.set_level_drain_scale` / `get_level_drain_scale` (0-1; `reset()` no lo toca) multiplica `get_drain_per_second()`. **Desvío:** lo fija `GeneratedLevel` al entrar en el árbol (propiedad `debug_drain_scale` que escribe `tools/build_level.py` solo si el JSON la tiene) y lo devuelve a 1 al salir, como `abilities_available`; `LevelRunner` solo lo asegura a 1 al mostrar el hub. Así vale también para escenas abiertas sin `LevelRunner`. Esquema (número 0-1) y plan del validador (`level_plan.py` gasta el Debug por el factor y la salida añade «gasto del Debug en este nivel» solo con el campo). Los cargadores ya tenían `cooldown_s` por instancia: sin código nuevo (4 s en `boss_test`; el 1-2 y el 1-3 siguen en 10 s). Salidas del validador (texto, `--json`, `--access-cap` y camino exportado) del 1-1, 1-2 y 1-3 idénticas byte a byte a las de antes del paso 1. Pruebas `tests/test_debug_drain_scale.gd` y `DebugDrainScaleTest` de `tests/test_level_plan.py`. | S | — | 1, 2, 3 |
| 5 | **Arena + build y validador de arenas:** `data/levels/1-boss.json` (24 × 12, `kind: "boss"`, `boss`, 4 cargadores, `debug_drain_scale` 0,5, plataformas, campanas y `blink_platform` con `active_in_phase`), escena generada, modo `--boss` del validador (alcance del núcleo, ventanas k = 2, avisos, hueco seguro, dos carriles, energía de §2.4 con `--access-cap`). | `data/levels/1-boss.json`, `scenes/levels/1-boss.tscn`, `tools/build_level.py`, `tools/validate_level_schema.py`, `tools/validate_level.py` (o `tools/validate_boss.py`), `tools/level_climbs.py`, `tests/fixtures/climbs_1-boss.json`, `tests/test_boss_validator.py` | `build_level.py --check` al día; el validador pasa la arena y falla con negativos sintéticos (cargador a > 4 tiles, pico > máximo − 20, dos carriles barridos a la vez). | M-L | 2, 4 | 6 (arte), 1 |
| 6 | **Fase 1:** Burbujas que caen a las plataformas (máx. 2), barridos alternos, ventana al aturdir las dos, bajada al centro 5 s del mundo. | `scripts/bosses/alert_major.gd`, `data/bosses/alert_major.json`, `tests/test_alert_major.gd` | GUT con el tiempo avanzado a mano: aviso de 9 cuadros, ventana solo con las 2 aturdidas, 3 golpes → fase 2 con +25 de energía y Sync. | M | 2, 3, 5 | 9, 11 |
| 7 | **Fase 2:** lluvia de pop-ups (máx. 2, nunca sobre Isak al salir), `notification_shot`, pop-up escudo (ampliar `overlay_popup`: `opaque`, `follow`, `respawn_s`). | `scripts/bosses/notification_shot.gd`, `scripts/levels/overlay_popup.gd`, `scripts/bosses/alert_major.gd`, `tests/test_alert_major.gd` | GUT: el dash atraviesa la ráfaga, el pulso al botón abre el escudo, golpe en 4 s del mundo; el `overlay_popup` del 1-2 no cambia. | M | 6 | 9, 10, 11 |
| 8 | **Fase 3:** copias (`alert_major_clone`, lanzamiento por compás, copia golpeada → «pop» y Burbuja), metrónomo de 2,0 s, campanas desfasadas y laterales como `blink_platform` activadas por fase. | `scripts/bosses/alert_major_clone.gd`, `scripts/bosses/alert_major.gd`, `scripts/levels/rhythm_zone.gd`, `tests/test_alert_major.gd` | GUT: solo la real muestra el núcleo con el Debug; nunca dos campanas en el mismo tiempo; la copia golpeada suelta una Burbuja. | L | 7 | 9, 10, 11 |
| 9 | **HUD: barra del jefe «99+»** con contador y tres muescas; R reinicia la pelea; game over normal. | `scripts/ui/boss_bar.gd`, `data/hud.json` (`boss_bar`), `scenes/ui/hud.tscn`, `tests/test_boss_bar.gd` | GUT: el contador sigue 99+ → 88 … → 0 y las muescas por fase; oculta fuera del jefe. | S | 2 | 6-8, 10, 11 |
| 10 | **Golpe final y `BossReward`:** congelación, detención de ataques, desarme; escena de recuerdo con la capa Caché `boss_w1_l1` (sin guardar, red de seguridad, revancha sin entrega doble), línea de derrota (pausa), vórtice al hub, `m2` desbloqueado con «Próximamente» y pieza cian. | `scripts/bosses/boss_reward.gd`, `scenes/bosses/boss_reward.tscn`, `scripts/bosses/alert_major.gd`, `data/hub.json`, `tests/test_boss_reward.gd` | GUT: tras el noveno golpe, `completed_levels` tiene `1-boss`, `has_memory(boss_w1_l1)` sin guardar, `m2` desbloqueado y la pieza encendida; ningún rollback ni cambio de `lap`. | M | 8, 9, 1 | 11, 12 |
| 11 | **Arte por script `_placeholder`:** badge 256 × 256 (estados de §4.1, sin «rebobinado»), copias, proyectil, pop-up escudo, barra del jefe y fondo de pantalla de bloqueo con relojes; validador de paleta (`carmin` solo en el núcleo). | `tools/gen_boss_alert_major.py`, `tools/validate_boss_alert_major.py`, `assets/sprites/bosses/alert_major_*_placeholder.png` | El validador pasa y está en la suite; las escenas usan los `.tres` generados. | M | 2 (tamaños) | 5-10 |
| 12 | **Textos, ayudas Q y sonidos:** intro (pausa), fases (sin pausa), derrota (pausa) marcados propuestos para el usuario; 4 tipos de ayuda y fichas del álbum; conexión en `data/audio.json` de los IDs de §4.1 (sin `sfx_boss_rollback_easy`). | `data/bosses/alert_major.json`, `data/help.json`, `tools/gen_album_cards.py`, `data/audio.json`, `tools/validate_audio.py` | `validate_audio.py` pasa con las señales nuevas; las fichas salen en el álbum; los textos marcados «por decidir». | S | 6-10 | 11 |
| 13 | **Jugable desde el hub:** `1-boss` `playable: true`; flujo hub → arena → hub con la confirmación de guardado y las 3 vidas. | `data/hub.json`, `tests/test_hub_boss_entry.gd` | Desde la carpeta del Mundo 1 se entra a la arena, se vence y se vuelve al hub; con `-- --start-level=1-boss` en depuración. | S | 10-12 | — |
| 14 | **Bot de jefe:** política por fase con la API de `BossBase`, solo acciones del Input Map; modos ideal y `--clumsy`. | `tools/boss_bot.gd`, `tools/play_boss_bot.gd`, `tests/test_boss_bot.gd` | Código 0: vence sin game over, energía mínima > 0 en todas las ventanas (también `--clumsy`), duración anotada frente a 240 s, capa obtenida y vuelta al hub. | L | 13 | 15 |
| 15 | **Pruebas de conjunto:** negativos (quieto pierde, golpe sin Debug, dash con Debug), salidas del validador del 1-1 al 1-3 idénticas, suite completa. | `tests/test_alert_major.gd`, `tests/test_boss_validator.py`, `tools/run_tests.sh` | `tools/run_tests.sh` en verde con el bot del jefe dentro. | S | 13 | 14 |
| 16 | **Capturas y docs:** intro, cada fase y su ventana, copias con el Debug, golpe final, recompensa y hub con la pieza; mapa de la arena; actualizar `CLAUDE.md`, `mundo-1` y `08-pendientes.md`. | `tools/render_boss_alert_major.gd`, `tools/render_level_map.py`, `CLAUDE.md` | Capturas en una carpeta revisadas por el usuario; ajuste jugando de los valores provisionales. | S | 14, 15 | — |

**Tandas en paralelo:** (A) pasos 1, 2 y 4 a la vez, y el 3 en cuanto exista `BossBase`; (B) el 5 tras el 2 y el 4, con el 11 (arte) empezando en paralelo; (C) las fases 6 → 7 → 8 van en serie (comparten `AlertMajor`), con el 9 (HUD) y el 11 (arte) al lado; (D) el 10 tras la fase 3, con el 12 (textos, ayudas y sonidos) en paralelo; (E) el 13 y después el 14 y el 15 a la vez; (F) el 16 al final.

**Tamaño total estimado:** del orden del 1-3 (unos 10-14 días de trabajo de agente, en tandas). Lo más caro son la fase 3, el validador de arenas y el bot.
