# Propuesta: hub del Mundo 1 y tutorial de guardado del 1-1

Estado: **APROBADO 2026-10-15.** El usuario aprobó las 10 preguntas de §7 con la recomendación del documento (respuestas en §7). Los cambios marcados como **[cambia 05-hub §x]** ya están aplicados en `05-hub.md`. Implementado: pasos 1 a 3 de §6.2 (guardado manual, esquema v2 con migración y `.bak`, aviso al salir) y, mientras no exista el hub real, una acción de guardar provisional en la pantalla provisional del hub (`save_game`, ver `CLAUDE.md`, «Cómo ejecutar»). El resto (pasos 4 a 12) sigue pendiente. Sigue abierta, como decisión del usuario, la paleta del hub (hex exactos del «gris azulado apagado», §6.1). Las decisiones ya tomadas por el usuario (`05-hub.md` §13.6 y `preguntas.md`, «Decisiones del 2026-10-15: tres vueltas, hub y guardado») se respetan. Donde esta propuesta cambia algo de `05-hub.md`, lo marca como **[cambia 05-hub §x]**. Las preguntas para el usuario están al final (§7), ya resueltas.

Decisiones que se respetan:

- Guardado **manual y solo en el hub**. Si se cierra el juego sin guardar en el hub, el progreso no se salva.
- El 1-1 **enseña a guardar**.
- En el hub se elige zona (1 a 6) y subnivel, y se compran mejoras (Calc).
- Los puntos de atención solo vuelven con el rollback del jefe final. No hay selector de dificultad: las tres vueltas (Easy, Normal y Hard) llegan por progresión.
- Isak tiene **una sola** pose de espaldas, estática (`back_idle`, con `face_back()`/`face_side()`). Más poses o animaciones de espaldas necesitarían créditos de AutoSprite y permiso del usuario.

---

## 1. Concepto y ambientación

El hub es la **pantalla de inicio del celular en Modo Avión**: el único sitio sin señal, donde Eco no llega (§13.1). Esta propuesta mantiene esa idea y la conecta con el guardado:

- **Guardar es hacer una copia local.** Eco no puede guardar por Isak, porque aquí no tiene señal. Fuera del hub, Eco «lo optimiza todo», también el progreso. En el hub, Isak decide cuándo guarda. El guardado manual refuerza el tema del juego, decidir por uno mismo, en lugar de ser solo una restricción técnica.
- **Qué se ve (estilo «circuito limpio», `estilizacion-energia.md`):**
  - Fondo gris azulado apagado (§15.3), con la foto rota en cinco piezas. Tras el Mundo 1 se ilumina la pieza en cian (§13.4). Con el hub del 1-1 (ver §2) la foto está entera en gris y la primera pieza solo tiene un contorno cian que parpadea débilmente: anuncia lo que falta.
  - Carpetas como iconos grandes de app (puertas a los mundos).
  - Un **dock** abajo, que es también el suelo por el que camina Isak.
  - Un icono de Modo Avión, siempre encendido.
  - Todo con contorno `noche_profunda`, bisel `borde_luz`/`tile_base`, trazas de 1 px en `resplandor` y acentos en el color del Debug del mundo. Sin rojo: en el hub nada hace daño.
- **HUD en el hub:** la señal (Sync Rate) se sustituye por el icono de Modo Avión, porque en el hub no hay daño. La batería y el contador de puntos se mantienen. Se añade el indicador «sin guardar» (§4.3).
- **Tono:** silencio y calma. La música está pendiente (es una decisión abierta del usuario).

## 2. Layout del hub provisional (Mundo 1)

### 2.1 ¿Plataformas 2D o pantalla de menús? Recomendación: **sala 2D caminable de una pantalla, con paneles de menú en cada estación**

| Opción | Pros | Contras |
|---|---|---|
| **A. Sala 2D caminable** (Isak camina y salta; cada estación abre un panel) | Es lo que describe §13.2 (Isak camina hasta el borde y la pantalla se desliza). Reutiliza a Isak, la cámara, el vórtice, el `ExitTerminal`, la pose de espaldas y el cuadro de Eco. Permite el idle con la terminal holográfica (§13.5). Da sensación de lugar seguro. | Cuesta algo más que un menú: hacen falta escena, colisiones y estaciones. Se tarda unos segundos en ir de una estación a otra. |
| B. Pantalla de menús (como el `hub_placeholder` actual) | Es barata y ya existe en parte. | Contradice §13.2 y §13.5. No hay sitio para la pose de espaldas, los aliados ni el idle. Se siente como un menú de pausa, no como un refugio. |
| C. Híbrido con cursor (Isak fijo; se elige la estación con izquierda/derecha) | Es rápido de usar. | Pierde el «caminar» del diseño y no ahorra mucho frente a A. |

**Recomendación: A.** Para que no sea lento:

- En el Mundo 1, una sola página de **20x11 tiles** (1280x720), con cámara fija y sin scroll. Las páginas 2 y 3 (§13.2) se añaden cuando haya mundos 4 a 6.
- Las estaciones quedan a 3–6 tiles unas de otras.
- Las estaciones se activan con el **pulso (G / X)**, igual que la terminal de salida del 1-1. Así no hace falta una acción nueva, y el jugador ya lo aprendió en el 1-1.

### 2.2 Mapa (página 1, hub del Mundo 1)

```
col   0    2    4    6    8   10   12   14   16   18 19
fila0 [HUD: ✈ Modo Avión ··········· batería  ◆ pts  ● sin guardar]
  1   |                fondo: foto rota (5 piezas, gris)          |
  2   |                                                            |
  3   |          [M1]        [M2]        [M3]                      |  carpetas (2x2 tiles) sobre
  4   |          ====        ====        ====                      |  repisas de una vía
  5   |                                                            |
  6   |                                                            |
  7   |  [COPIA]                                          [AJUSTES*]|
  8   |  [LOCAL]   P                                               |
  9   |=== DOCK (suelo) ===[Calc]===[ · ]===[ · ]===[ · ]==========|  Calc + 3 huecos vacíos
 10   |  ○ indicador de página (1 punto)                           |
```

| Elemento | Posición (col, fila) | Notas |
|---|---|---|
| **P** (llegada por vórtice) | (5, 8) | Junto a la copia local, así lo primero que se ve es dónde se guarda. |
| **Copia local** (guardar) | (1–2, 7–8) | Terminal de 1x2 tiles. Reutiliza el monitor de `exit_terminal` con otro icono. |
| **Carpetas M1, M2 y M3** | (4–5), (10–11) y (16–17), filas 3–4 | Repisas a 3 tiles del dock: se llega de un salto, así que no hay que enseñar nada. M2 y M3 se ven bloqueadas. |
| **Calc** | (7, 9), de pie sobre el dock | Abre el panel de mejoras. En el Mundo 1 está **dormida** (ver §3.2). |
| **Huecos del dock** | (10, 9), (13, 9) y (16, 9) | Siluetas apagadas para Notas, Linterna y Papelera. Anuncian aliados futuros. |
| **Ajustes** | Icono en la esquina (18–19, 7) que abre el menú de pausa | Pregunta 9: los ajustes viven en el menú de pausa. |
| **Paredes** | Bordes de la sala | Mientras haya una sola página, el borde no desliza la pantalla. |

**[cambia 05-hub §13.2]:** el dock pasa a ser el **suelo** del hub (los aliados están de pie en él). §13.2 lo describe como una «barra inferior» sin decir si se camina sobre ella.

## 3. Interacciones

Patrón común para todas las estaciones (`HubStation`):

1. Con Isak a menos de 1,5 tiles, sale la tecla del pulso sobre la estación, como en el prompt de `exit_terminal`.
2. Al pulsar G, Isak hace `face_back()` (de espaldas, mirando la estación) y se abre un panel. El panel usa el NinePatch del cuadro de Eco y la fuente `text_font`.
3. Dentro del panel: `move_up`/`move_down` (y `move_left`/`move_right` donde haga falta) eligen, `pulse` confirma y `jump` cierra.
4. Al cerrar el panel, Isak hace `face_side()` y recupera el control.

Mientras el panel está abierto, Isak no se mueve, así que usar `jump` para cerrar no le hace saltar. La pose de espaldas es estática y se mantiene mientras el panel está abierto. No hace falta otra animación: el panel tapa la acción, y el destello cian de la terminal (tinte con `modulate`) sirve como transición al abrir.

### 3.1 Tabla de estaciones

| Estación | Quién la da | Qué hace | Hub del Mundo 1 | Después |
|---|---|---|---|---|
| **Copia local** | Nadie: es un objeto del hub. Eco no llega y el aliado que la explique llega después. | Guarda (§4). Pide confirmación, muestra cuándo se guardó por última vez y qué ha cambiado («+9 puntos, 1-1 completado»). | **Sí** | Igual |
| **Carpetas** | Objeto (icono de app) | Eligen la zona y el subnivel, y entran por el vórtice (§3.3). | M1 activa; M2 y M3 bloqueadas | Página 2 (M4, M5) y página 3 (La Nube, con candado) |
| **Calc** | Calc | Mejoras de `data/upgrades.json`: nombre, coste, estado y detalle (`<label>: <base> a <value>`). Es lo que hace hoy `hub_placeholder`. | **Dormida** (§3.2) | Despierta tras Alerta Mayor y habla. Es la tienda de atajos del Mundo 5 (§12.3). |
| **Notas** | Notas | Bitácora: recuerdos, diálogos, pistas y coleccionables (§13.3). | No (hueco apagado) | Tras el Mundo 2 |
| **Linterna** | Linterna | Muestra los secretos por nivel («2/4») y da pistas (§13.3). Hace falta guardar ya los secretos encontrados (§4.1). | No | Tras el Mundo 4 |
| **Papelera** | Papelera | Guarda parte de los puntos perdidos al morir para recuperarlos (§13.3). **Hoy no se pierden puntos al morir** (V2), así que primero hay que decidir esa regla. Propuesta: Papelera guarda los puntos que se perdieron en la **última** muerte de cada nivel, y se recogen hablando con ella. | No | Tras el Mundo 4 |
| **Ajustes** | Menú | Accesibilidad (§13.2), por ejemplo reducir el ruido con Sync Rate bajo. Se guardan **al instante** (pregunta 6). | Sí (mínimo) | Igual |

### 3.2 Calc antes de vencer a Alerta Mayor **[cambia 05-hub §13.3]**

§13.3 dice que Calc llega «después del Mundo 1», pero las mejoras ya se compran tras el 1-1 (hoy en `hub_placeholder`). Propuesta: en el hub del Mundo 1, Calc aparece como **icono gris y dormido** en el dock (es una «aplicación obsoleta», §12.3). Su teclado funciona y vende las mejoras a precio fijo, pero ella no habla: solo hay texto de interfaz. Tras vencer a Alerta Mayor despierta, se presenta (la «primera llegada» de §13.1) y a partir de entonces explica las mecánicas con su humor seco. Así se mantiene el momento narrativo y las compras siguen disponibles desde el 1-1.

### 3.3 Selección de zona y subnivel (carpetas)

Panel de la carpeta, por ejemplo M1 en la 1.ª vuelta:

```
 Mundo 1 · Notificaciones          Vuelta 1 · Easy
 ▸ 1-1 Bandeja de entrada     ✓  ◆ 9/9   (secretos ?)
   1-2 Centro de notif.       ·  nuevo
   1-3 ···                    (bloq.)
   Jefe: Alerta Mayor         (bloq.)
```

- **Estados de la carpeta:**
  - Bloqueada: gris con candado; no abre el panel, solo muestra «Sin descargar».
  - Disponible: en el color del Debug del mundo.
  - Completada: con una marca y la pieza de la foto encendida.
- **Estados de cada subnivel:** completado (✓), disponible (nuevo) y bloqueado ((bloq.)). Salen de `completed_levels` y `unlocked_levels`, que ya están en el guardado. Cada subnivel muestra sus puntos capturados frente al total (`captured_points`). Los secretos solo se muestran cuando llegue Linterna; antes, «?».
- **Vuelta:** se ve la vuelta **actual** (Easy, Normal o Hard) arriba a la derecha del panel y como insignia en las carpetas. No se elige: la vuelta solo cambia con el rollback. En el panel solo aparecen los subniveles de la vuelta actual (pregunta 7).
- **Entrar:** al elegir un subnivel, el panel se cierra e Isak, de espaldas frente a la carpeta, es absorbido por el vórtice de salida (la misma secuencia que en la terminal del 1-1). Al terminar un nivel vuelve al hub con el vórtice de llegada en P (§13.5, «animación de píxeles»).
- **Antes de la primera copia:** si hay cambios sin guardar, entrar a una carpeta no se bloquea. Solo el primer hub muestra el recordatorio del tutorial (§5).

### 3.4 Otras acciones del hub

- **Energía:** se llena al llegar, como ya hace `hub_placeholder` (`refill_debug_energy`).
- **Idle:** si Isak se queda quieto, saca la terminal holográfica (ya existe). Las escenas entre aliados (§13.5) llegan con Notas y los demás.
- **Pose de espaldas:** se usa en la copia local, en las carpetas y en Calc. Siempre es la misma pose estática.

## 4. Sistema de guardado

### 4.1 Qué se guarda (esquema versión 2)

| Campo | Hoy (v1) | v2 | Notas |
|---|---|---|---|
| `attention_points` | Sí | Sí | |
| `captured_points` (nivel → ids) | Sí | Sí | El rollback lo vacía. No hace falta guardarlo por vuelta. |
| `collected_pickups` (power banks de mapa, cargadores de un solo uso) | Sí | Sí | El rollback los vacía: los objetos del mapa vuelven (pregunta 8). |
| `upgrades_purchased` | Sí | Sí | |
| `abilities_obtained` | Sí | Sí | El rollback **no** los toca: Isak mantiene sus habilidades. |
| `power_banks` (`full`, `empty`, `charge`) | Sí | Sí | |
| `completed_levels` / `unlocked_levels` | Sí | Sí | El rollback los reinicia para la nueva vuelta (por definir con el rollback). |
| `seen_notices` | Sí | Sí | |
| **`lap`** (1 Easy, 2 Normal, 3 Hard) | No | **Nuevo** | Vale 1 por defecto. |
| **`found_secrets`** (nivel → ids) | No | **Nuevo** | Hace falta para Linterna y Notas. El rollback no lo toca: es un registro (pregunta 8). |
| **`hub_tutorial_done`** | No | **Nuevo** | Primer hub guiado (§5). |
| **`saved_at`** (fecha) y **`play_time_s`** | No | **Nuevo** | Se muestran en la copia local. |
| Ajustes | No | **Aparte** | `user://settings.cfg`, guardado al cambiarlos. No es progreso (pregunta 6). |

No se guardan: Sync Rate, energía y checkpoints (el hub los repone), ni el enfriamiento de los cargadores.

### 4.2 Cuándo se guarda

- **Solo** con la acción explícita en la copia local:
  1. Pulso para abrir el panel.
  2. «¿Guardar copia local?», con el resumen de cambios.
  3. Confirmar con pulso.
  4. Mensaje «Copia guardada» y destello cian en el monitor.
- Si no hay cambios, el panel dice «Todo está guardado» (no hace falta confirmar).
- No se guarda al capturar puntos, comprar mejoras ni completar niveles. Todo eso queda **en memoria** y marca «sin guardar».
- La escritura sigue siendo atómica (`.tmp` y renombrado). Se propone además guardar la copia anterior como `save.json.bak` (pregunta 10).

### 4.3 Indicador «sin guardar»

- En el HUD del hub: un punto o icono junto al contador de puntos («● sin guardar»), en `banner_blanco`, cuando `GameState.has_unsaved_changes()`.
- En los niveles no se muestra, para no ensuciar el HUD. El aviso al salir (§4.4) cubre ese caso.

### 4.4 Cerrar sin guardar

- Regla decidida: lo que no se guardó en el hub se pierde. La próxima partida carga la última copia.
- **Aviso al salir (propuesta):** con cambios sin guardar, cerrar la ventana (`NOTIFICATION_WM_CLOSE_REQUEST`, con `auto_accept_quit = false`) muestra un diálogo:
  - En el hub: «Tienes cambios sin guardar. [Guardar y salir] [Salir sin guardar] [Volver]».
  - En un nivel: «Perderás lo hecho desde tu última copia en el hub. [Salir] [Volver]». No hay opción de guardar, porque fuera del hub no se guarda.
- Sin cambios pendientes, sale sin preguntar. El aviso no cambia la regla: solo evita perder progreso sin querer.

### 4.5 Migración del autoguardado actual

1. `request_save()` deja de escribir: pasa a marcar los cambios como pendientes (dirty) y emite `EventBus.unsaved_changes_changed(bool)`. Las llamadas que ya existen (capturar un punto, `obtain_ability`, `purchase_upgrade`, `mark_level_completed`…) no cambian.
2. `save_game()` solo lo llaman la copia local (y las pruebas). `autosave_enabled` ya existe: se usa como interruptor del modo, en `false` para el juego normal. Las pruebas que lo necesiten pueden activarlo. **Implementado (2026-10-15):** se quitó `autosave_enabled` (no queda modo automático); mientras no exista la copia local, `save_game()` lo llama la pantalla provisional del hub con la acción `save_game` (C / R3).
3. Un `save.json` v1 se carga igual que ahora (`apply_save_data` ya tolera campos que falten). `lap` vale 1, `found_secrets` empieza vacío y `hub_tutorial_done` vale `true` si el 1-1 ya está completado (un jugador veterano no repite el tutorial). La primera copia manual escribe la v2. Una v2 con un juego antiguo se aparta como `.corrupt`, como hoy.
4. Rutas y aislamiento sin cambios: `ISAK_SAVE_PATH`, `test_save.json`, `bot_save.json` y `tool_save.json`. `tools/run_tests.sh` sigue fallando si la suite toca el guardado real.

### 4.6 Riesgos

| Riesgo | Mitigación |
|---|---|
| Perder progreso al cerrar o por un fallo | Aviso al salir (§4.4), «sin guardar» visible en el hub, tutorial (§5) y `.bak` de la copia anterior. |
| Un fallo de Godot o del sistema durante un nivel largo | Es el coste aceptado de la regla. Los niveles duran pocos minutos (el 1-1, unos 100 s). |
| Pruebas que esperan el autoguardado | Ajustarlas (§6.2): `test_request_save_writes_once_at_end_of_frame` pasa a comprobar que solo se marca como pendiente. |
| El bot espera que el guardado persista | El bot no recarga el guardado entre partidas; solo hay que revisar si comprueba el disco. |
| Comprar una mejora, no guardar y repetir | No es un exploit: sin guardar, la compra también se pierde. |

## 5. Tutorial de guardado en el 1-1

Restricción: el hub aparece al terminar el 1-1 y el guardado solo existe allí. Además, **Eco no entra en el hub**, así que no puede explicar nada dentro de él.

| Opción | Cómo funciona | Pros | Contras |
|---|---|---|---|
| **A. Terminal de guardado dentro del 1-1** | Una «copia local» en el nivel (por ejemplo junto al checkpoint) donde se guarda por primera vez. | Se enseña en el nivel, con la mecánica real. | **Contradice «solo en el hub».** Además, sin hub no tiene sentido narrativo, porque en el nivel Eco tiene señal. |
| **B. Eco lo anuncia en la terminal de salida** | Línea importante de Eco (pausa) al acercarse a la terminal (zona en las columnas 286–289, antes del prompt). Texto propuesto: «Allí donde vas no tengo cobertura. No podré guardar nada por ti. Qué poco práctico.» | Coste mínimo: es una entrada `eco_line` con `important: true` en `data/levels/1-1.json`. Encaja con la voz de Eco (servicial y con ganas de decidir por Isak) y con el tema. Llega justo antes del hub. | Solo anuncia la idea: no enseña la acción. Se olvida si el hub no la refuerza. |
| **C. Primer hub guiado** | Al llegar por primera vez (`hub_tutorial_done = false`), la copia local parpadea en cian y sale un texto de interfaz (sin el nombre «Eco»): «Copia local: aquí se guarda tu progreso. Si cierras sin guardar, se pierde. Pulso (G) para guardar.» Si el jugador intenta entrar a una carpeta sin haber guardado, sale una vez: «¿Seguro? Aún no has guardado.» | Enseña la acción real en el lugar real. No contradice nada. | Es texto de interfaz, no un personaje: Calc está dormida hasta el Mundo 1 (§3.2). |

**Recomendación: B + C.** B prepara la idea con humor y con la voz de Eco, y C enseña la acción. Detalles:

- El texto de C **no** lleva el nombre «Eco», porque Eco no está en el hub. Esto conecta con la duda abierta de los avisos de control, que muestran «Eco» encima del texto de interfaz.
- El primer guardado **no es obligatorio**. Solo se insiste una vez, al ir a una carpeta. El aviso al salir (§4.4) cubre el resto.
- C se marca como hecho al guardar por primera vez. Si el jugador sale sin guardar, el tutorial vuelve a salir en la siguiente partida, porque el flag no se guardó. Es coherente con la regla.
- La línea de B sale una vez por partida guardada, igual que `seen_notices`.

**[cambia 05-hub §13.6]:** el tutorial de guardado deja de depender de «un punto de guardado en el nivel». Se hace con un aviso en el 1-1 y el primer hub guiado. No hay guardado dentro de los niveles.

## 6. Trabajo necesario

### 6.1 Arte

| Pieza | Tamaño (arte) | Cómo |
|---|---|---|
| Fondo del hub: foto rota en 5 piezas (gris; pieza 1 con contorno o encendida en cian) | 1280x720 (o 640x360 x2) | Script en Python (como `gen_energy_objects.py`) con un validador de paleta. Paleta del hub nueva («gris azulado apagado»): los hex exactos son una **decisión abierta del usuario**. |
| Tiles del dock y repisas de una vía | 64x64 | Script, variante del tileset del Mundo 1 en gris azulado. |
| Carpetas (bloqueada, disponible, completada; con miniaturas de los iconos del mundo) | 128x128 | Script |
| Copia local (monitor e icono de copia; apagado, prompt y activo) | 64x128 | Script. Se reutiliza `exit_terminal` y se cambia el icono. |
| Calc dormida y despierta (calculadora con cara en el visor; 2–4 cuadros de idle) | 64x96 aprox. | Script (pixel art a mano o generado). **No** hace falta AutoSprite: es un icono de app, no un personaje humano. |
| Huecos del dock (siluetas apagadas) | 64x96 | Script |
| Icono de Modo Avión (HUD del hub) e indicador «sin guardar» | 16x16 | Script, en `gen_hud_assets.py` |
| Indicador de página | 8x8 | Script |
| Paneles de menú | NinePatch | Se reutiliza `eco_text_panel.png` |
| Isak en el hub | | Ya existe: caminar, idle, terminal holográfica, `back_idle` y vórtices. |
| Opcional: Isak de espaldas tecleando o con más poses | | **AutoSprite**: solo con permiso del usuario. No hace falta para esta propuesta. |

### 6.2 Código y pruebas (pasos pequeños, en orden)

| # | Paso | Tamaño | Pruebas |
|---|---|---|---|
| 1 | `GameState`: modo manual (dirty, `has_unsaved_changes()`, señal); `request_save()` solo marca. | S | Cambiar `test_request_save_writes_once_at_end_of_frame`; prueba nueva para dirty y para limpiar al guardar. |
| 2 | Esquema v2: `lap`, `found_secrets`, `hub_tutorial_done`, `saved_at`, `play_time_s`; migración desde v1; `.bak`. | S | Ida y vuelta con v2, carga de v1, versión 3 desconocida apartada y `.bak`. |
| 3 | Aviso al salir con cambios pendientes (en el hub o en un nivel). | S | Prueba de la lógica de decisión (sin ventana). |
| 4 | `HubStation` (prompt, pulso, `face_back`/`face_side`, abrir y cerrar el panel), extraído del patrón de `ExitTerminal`. | M | Proximidad, activación, pose y devolución del control. |
| 5 | Escena del hub (`scenes/hub/hub.tscn`): sala de 20x11, P, vórtice de llegada, HUD con Modo Avión, energía llena y paredes. Datos en `data/hub.json`. | M | Prueba de humo: llegada, control y energía llena. |
| 6 | Estación de copia local y su panel (resumen, confirmación, «sin guardar»). | S | Guardar escribe en la ruta de pruebas y el indicador se apaga. |
| 7 | Carpetas y panel de subniveles (registro de mundos y subniveles en `data/hub.json`, estados y vuelta). | M | Estados según `completed_levels` y `unlocked_levels`; entrar carga el nivel. |
| 8 | Calc (dormida): se lleva la lógica de compra de `hub_placeholder` a su panel. | S | Se adaptan `test_upgrades.gd` y `test_energy_sources.gd`. |
| 9 | Flujo: `level_completed` lleva al hub real; la carpeta lleva al nivel. `hub_placeholder` se retira o se deja solo para escenas de prueba. | M | `test_popup_door_hub.gd`, `test_level_flow.gd` y `test_dev_keys.gd` (R en el hub); revisar `tools/level_bot.gd`. |
| 10 | Tutorial: línea B en `data/levels/1-1.json` (y regenerar la escena con `build_level.py`) y primer hub guiado (C). | S | La línea sale una vez; el tutorial se marca al guardar. Pasar los validadores del 1-1. |
| 11 | Arte con scripts (generador y validador del hub) y su integración. | M | El validador entra en `tools/run_tests.sh`. |
| 12 | Documentación: actualizar `05-hub.md` con lo aprobado, `CLAUDE.md` (cómo ejecutar y guardado) y `08-pendientes.md`. | S | |

S = menos de medio día; M = entre medio día y un día.

## 7. Preguntas (RESUELTAS el 2026-10-15)

**Decisión del usuario (2026-10-15):** las 10 preguntas se aprueban con la recomendación del documento. Además, el Debug conserva su regla (se activa con energía > 0; `preguntas.md`, «Batería vacía por debajo del coste del láser»).

| # | Respuesta |
|---|---|
| 1 | **Sí.** El hub aparece desde el final del 1-1: un hub mínimo tras cada nivel del Mundo 1, con Calc dormida. La llegada narrativa (Calc despierta y la pieza cian) sigue siendo tras Alerta Mayor. |
| 2 | **Sí, tutorial B + C:** aviso de Eco en la terminal de salida del 1-1 y primer hub guiado. No hay guardado dentro de los niveles. |
| 3 | **A:** sala 2D caminable con paneles, de una sola pantalla en el Mundo 1. |
| 4 | **Sí:** Calc dormida en el hub del Mundo 1; vende sin hablar. |
| 5 | **Sí:** aviso al cerrar con cambios sin guardar, también dentro de un nivel (allí sin opción de guardar). |
| 6 | **Sí:** los ajustes se guardan al instante en `user://settings.cfg`, aparte del guardado manual. |
| 7 | **No:** no se rejuegan subniveles de vueltas anteriores; solo los de la vuelta actual. |
| 8 | **Rollback:** se restauran los objetos del mapa (power banks de mapa y cargadores de un solo uso) además de los puntos; los secretos encontrados se conservan como registro. |
| 9 | **Menú de pausa** (acción `pause`), accesible también en los niveles; en el hub, un icono en la esquina lo abre. |
| 10 | **Sí:** se guarda `save.json.bak` con la copia anterior. |

Texto original de las preguntas (por prioridad):


1. **¿El hub aparece desde el final del 1-1?** Esto cambiaría §13.1 («primera llegada tras Alerta Mayor»), §13.6 («antes del hub no hay selección») y C4. *Recomendación: sí.* Un hub mínimo tras cada nivel del Mundo 1, con Calc dormida. La llegada narrativa (Calc despierta y la pieza cian) sigue siendo tras Alerta Mayor.
2. **¿Se aprueba el tutorial B + C** (Eco lo anuncia en la terminal de salida y el primer hub es guiado), sin guardado dentro de los niveles? *Recomendación: sí.*
3. **¿Sala 2D caminable con paneles** (opción A) en vez de una pantalla de menús? *Recomendación: A, en una sola pantalla en el Mundo 1.*
4. **¿Calc dormida en el hub del Mundo 1**, que vende sin hablar? *Recomendación: sí.*
5. **¿Aviso al cerrar con cambios sin guardar?** *Recomendación: sí, también dentro de un nivel, sin opción de guardar allí.*
6. **¿Los ajustes se guardan al instante y aparte** (`settings.cfg`), fuera del guardado manual? *Recomendación: sí; no son progreso.*
7. **¿Se pueden rejugar subniveles de vueltas anteriores?** *Recomendación: no. Solo la vuelta actual; la anterior desaparece con el rollback.*
8. **Rollback:** además de los puntos, ¿se restauran los power banks de mapa y los cargadores de un solo uso? ¿Se conservan los secretos encontrados (para Notas y Linterna)? *Recomendación: se restauran los objetos del mapa; los secretos se conservan como registro.*
9. **¿Ajustes como estación del hub o solo en el menú de pausa?** Aún no existe el menú de pausa. *Recomendación: en el menú de pausa (acción `pause`), accesible también en los niveles. En el hub, el icono de la esquina lo abre.*
10. **¿Se guarda una copia de respaldo (`save.json.bak`)** de la copia anterior? *Recomendación: sí; es barato y protege de un guardado corrupto.*
