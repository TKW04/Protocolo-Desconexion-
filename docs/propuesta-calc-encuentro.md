# Encuentro con Calc: acertijo de la azotea del 1-2

**Estado:** diseño del usuario del **2026-10-17**. Sustituye la opción A de `propuesta-1-2.md` §8 (Calc apagada junto a la terminal, Q `calc_off` y un pulso). Es el paso 14 de `propuesta-1-2.md` §10, junto con el recuerdo. **Tanda H1 hecha (2026-10-17):** sistemas, piezas, arte, sala de prueba `calc_test` y este documento. **Tanda H2 hecha (2026-10-17):** el acertijo en la azotea del 1-2 real y en el validador, con el camino exportado (§10). Pendientes: **H3** (el encuentro en el hub) y el bot vertical (paso 15 del 1-2). Los textos de Eco y de Calc son **propuestas** hasta que el usuario los decida.

## 1. Idea

Calc está apagada, al **3 %** de batería, y hay que cargarla. En la azotea, la **terminal de salida está apagada**: no tiene corriente. Eco descubre de dónde viene la corriente y el jugador deduce el resto. Hay que encender tres cosas en un cuarto trasero (luz, energía y un panel oculto). Entonces Calc entra, se carga y se va al hub. La terminal recupera la corriente e Isak sale.

Los personajes hablan **solo con texto**. No hay voz ni sonido.

## 2. Secuencia (exacta)

| # | Qué pasa | Quién actúa | Piezas |
|---|---|---|---|
| 1 | Isak se acerca a la terminal. **Eco, por su cuenta** (no es una Q), vuela a la terminal y ve que no tiene corriente. Después vuela a la pared del fondo, que tiene un **glitch**, y dice: «La corriente que alimenta la terminal viene de detrás de esta pared». **Nunca dice «usa el Debug»**: el jugador lo deduce, como en el secreto D del 1-1. | Guion de Eco | `exit_terminal` con `requires_power`, `glitch_wall` |
| 2 | Con el **Debug** la pared se disuelve. Detrás hay un cuarto **a oscuras**. Eco encuentra un **interruptor** y lo señala con su **ayuda Q** (se acerca y brilla en dorado; pedirla pausa el juego): «necesita varios pulsos». Cada **pulso** pone a Isak **de espaldas** (`face_back`, como en las estaciones del hub) y enciende una luz. La luz del cuarto sube **por tercios**. Con 3 pulsos el cuarto se ilumina y la pared con glitch se **transforma en una puerta**. Eco: «Luz. Pero falta energía». | Jugador, Q de Eco | `power_switch`, `dark_room`, `glitch_wall` → puerta |
| 3 | Lejos, donde no se llega caminando, hay un **interruptor láser** (como el lector del acertijo del Debug). Un disparo desde la primera plataforma lo activa **para siempre**, sin ventana de tiempo. Eco vuela a la puerta: «Solo falta uno». | Jugador | `laser_switch` |
| 4 | Se sube por unas plataformas hasta un **panel oculto**, que solo se ve con el **Debug**. Se activa con pulso, de espaldas, como el del paso 2. | Jugador | `debug_switch` |
| 5 | **Calc entra por la puerta** y se coloca en el **punto de carga**. Se carga hasta el **100 %** (medidor por segmentos y chispas) y se **teletransporta** al hub (vórtice). Eco hace un comentario. | Calc | `charge_dock`, `calc_actor` |
| 6 | La terminal **ya tiene corriente** (Eco lo dice). Isak sale por ella y **encuentra a Calc en el hub** (tanda H3). | Jugador | `exit_terminal` |

### Reglas

- **Un solo uso.** La secuencia solo ocurre si Calc aún no es conocida (`allies_met` sin `"calc"`). Calc queda conocida cuando Isak la encuentra en el hub (H3), no al teletransportarse. Si ya es conocida (al rejugar el 1-2, o tras un game over, porque el rollback conserva `allies_met`):
  - todas las piezas con `done_if_ally: "calc"` arrancan resueltas e inertes, sin Q;
  - la pared ya es una puerta con sus tres luces, el cuarto tiene luz y Calc no está;
  - la terminal tiene corriente y el guion de Eco no sale.
- **Sin castigo.** El acertijo no tiene fallo ni muerte. La energía alcanza: hay un cargador en la azotea. Lo activado se queda activado durante el intento, también al morir y reaparecer. Un intento nuevo (R, la carpeta o un game over) empieza de cero mientras Calc no sea conocida.
- **Las líneas del guion de Eco no son importantes.** No pausan y van en cola. La única pausa es la **Q del interruptor** del paso 2, como cualquier Q.
- **El guion es historia.** Sale aunque el ajuste «Ayudas de Eco» esté en «Ocultar». Con las ayudas ocultas, o con el tipo ya aprendido, la Q del paso 2 no sale. En ese caso Eco vuela al interruptor y lo señala con una línea normal: «Ese interruptor quiere pulsos, {apodo}. Varios.».
- **Ayudas honestas.** Mientras la terminal no tiene corriente, no da Q (su texto, «Lanza un pulso al monitor…», mentiría).
- Decisiones aprobadas por silencio:
  - «Pulsaciones» son **3 pulsos** (`pulses`, entre 1 y 6). La luz sube por tercios.
  - La **carga es obligatoria** para que la terminal funcione.
  - El cuarto es una **zona de la azotea**, no una escena aparte.

## 3. Piezas (implementadas en H1)

Catálogo en `data/world1_objects.json` (tipos y secciones de ajuste, con `level_params` y `allowed`). Las piezas se enlazan por id (`CalcRoom`, grupo `calc_room_link`). «Hecho» significa `is_activated()`.

| Tipo | Clase | Qué hace |
|---|---|---|
| `power_switch` | `PowerSwitch` | Panel en la pared del fondo. Cada pulso cuenta uno: Isak se pone de espaldas `pose_s` y se enciende una luz. Con `pulses` pulsos se activa. Con Q. |
| `debug_switch` | `PowerSwitch` (`hidden_until_debug`) | No se ve ni responde hasta que el Debug activo lo descubre cerca. Desde entonces queda marcado (tenue) y responde al pulso aunque el Debug se apague. Por defecto 1 pulso. Con Q una vez visto. |
| `laser_switch` | `LaserSwitch` | Como el lector láser, pero un impacto lo activa para siempre. El pulso no le hace nada. Con Q. |
| `glitch_wall` + `door_when` | `GlitchWall` | Cuando el interruptor `door_when` se activa, la pared (disuelta o no) se convierte en una **puerta** de 1x2 que no es sólida. La puerta tiene `lamps` (hasta 3 luces en el dintel, una por pieza hecha); con todas se ve abierta. Sin `door_when`, la pared del 1-1 no cambia. |
| `dark_room` | `DarkRoom` | Velo oscuro por encima del mundo. Su luz sigue el progreso de `switch` en tercios. Hay halos escalonados alrededor de Eco (es una esfera de luz) y de los interruptores. Con el Debug el velo baja y se ven los contornos discontinuos de las piezas. |
| `charge_dock` | `ChargeDock` | Se arma cuando todas las piezas de `requires` están hechas. Carga a Calc en `charge_s` (del 3 % al 100 %), con medidor de 10 segmentos y chispas. Cuando Calc se va, tiene corriente (`is_power_on`). Con Q solo antes de armarse. |
| `calc_actor` | `CalcActor` | Calc apagada (3 %). Cuando el dock se arma, despierta, camina por `path` (cruza la puerta), se carga, pone cara despierta y se va por un vórtice. Emite `EventBus.ally_teleported("calc")`, que es el gancho de H3, y **no** llama a `meet_ally`. Sin Q. |
| `exit_terminal` + `requires_power` | `ExitTerminal` | Apagada hasta que `power_source` tiene corriente: pantalla negra, sin prompt ni Q, y el pulso no hace nada. Al recibir la corriente emite `powered`. Por defecto `false`: el 1-1 no cambia. |
| `eco_guide` | `EcoGuide` | El guion propio de Eco (§4). |

**Arte por script:** `tools/gen_calc_encounter.py`, validador `tools/validate_calc_encounter.py`.
- **Piezas:** Mundo 1, sin rojos ni ámbar. Archivos `calc_encounter_frames.tres` y `props/calc_room/`.
- **Calc:** paleta del hub, con el cuerpo de `gen_hub_objects.py`. Animaciones `calc_low`, `calc_wake`, `calc_walk`, `calc_charging`, `calc_charged` y `calc_teleport`, en `calc_actor_frames.tres`. Los anillos del vórtice son los de Isak.
- **Ayudas Q y fichas del álbum** (Mundo 1, Objetos): `power_switch`, `laser_switch`, `debug_switch` y `charge_dock`.

## 4. Guion propio de Eco (`EcoGuide`)

Es un sistema reutilizable y data-driven para las acciones de Eco que **no** son la ayuda Q. Los guiones están en `data/eco_guides.json`; la pieza `eco_guide` (parámetro `guide`) los arranca en el nivel. Los pasos se ejecutan en orden:

- **Esperas:**
  - `wait_near {object, radius_tiles}`: Isak cerca de la pieza.
  - `wait_inside {object}`: Isak dentro del cuarto.
  - `wait_done {object}`: la pieza está hecha.
  - `wait_ability {pulse|laser|debug}`: Isak usa esa habilidad.
  - `wait_s {seconds}`: pausa del guion.
  - `wait_quiet {max_s}`: espera a que el cuadro de texto quede libre (como mucho 15 s), para que las líneas no se amontonen y Eco no se vaya antes de que se lea lo que dice.
- **Acciones:**
  - `fly {object|cell, offset_px}`: Eco vuela allí y se queda (`EcoCompanion.set_guide_point`, sin brillo ni Q).
  - `back`: Eco vuelve con Isak.
  - `line {text, important}`: línea de Eco; por defecto **no importante**.
  - `point_help {object, radius_tiles, text}`: deja salir la Q de la pieza o, si no va a salir, vuela y dice `text`.

Comportamiento:
- **Q frente al guion.** La ayuda Q tiene prioridad sobre el punto del guion. Cuando termina, Eco vuelve a ese punto.
- **Muerte.** Las acciones esperan a que Isak tenga control. Si Isak muere o entra en un vórtice, Eco suelta el punto. Las esperas miran el estado del mundo, que no se pierde al reaparecer.
- **Pausa.** Con el árbol en pausa (menú, Q) el guion no avanza.
- **Distancia.** Si Isak se aleja más de `guide_release_px` del punto, Eco suelta el punto.
- **Guion inerte.** Si Eco no es conocido, o si `done_if_ally` ya es conocido, el guion no hace nada.
- **Ayudas ocultas.** Con «Ocultar» el guion sale igual.
- **Validación.** El esquema comprueba que el guion existe, que las acciones y sus campos son válidos y que cada `object` es un id del nivel.

### Textos propuestos de Eco (`calc_rooftop`, no importantes)

1. «Esta terminal no tiene corriente. Ni un píxel.»
2. «La corriente que alimenta la terminal viene de detrás de esta pared.»
3. Al entrar al cuarto: «Qué oscuro. Por suerte, yo brillo.»
4. Si no sale la Q: «Ese interruptor quiere pulsos, {apodo}. Varios.»
5. «Luz. Pero falta energía.»
6. En la puerta: «Solo falta uno.»
7. Cuando entra Calc: «Energía completa. Y ahí viene una aplicación obsoleta, con un 3 % de batería. Cómo no.»
8. «La terminal ya tiene corriente. Cuando quieras, {apodo}.»

Voz de Eco (servicial, algo engreída, corporativa): nunca miente, solo omite.

**Ayudas Q (propuesta):**

| Tipo | Texto |
|---|---|
| Interruptor de pulso | «Un interruptor de pulso. Con uno no basta: necesita varios. Cada luz encendida es un pulso; con todas, se activa.» |
| Interruptor láser | «Un interruptor a distancia. Un disparo de láser y se queda encendido. Para siempre. Sin prisas, por una vez.» |
| Panel oculto | «Un panel que no figura en ningún inventario. Ya que lo has visto, funciona como los otros: a pulsos.» |
| Punto de carga | «Un punto de carga para aplicaciones. Para ti no sirve. Se enciende cuando el cuarto tiene toda su energía.» |

## 5. Iconos y variables en los cuadros de texto (H1)

Marcadores de `data/eco_text_box.json` (`TextMarkers`), en el cuadro de Eco y en el del hub, que usan la misma escena:

- `{apodo}`: el apodo de la partida, como antes.
- `{puntos}`: el saldo **actual** de puntos de atención, tomado cuando la línea empieza a escribirse.
- `{icono:atencion}`: el rombo del punto de atención **dentro de la línea**.
  - La fuente tiene el glifo «◆» con el ancho del icono, regenerado con `tools/gen_text_font.py`.
  - El cuadro dibuja encima el sprite `eco_inline_attention.png`, de 8x8 y en ámbar, alineado con la altura de las mayúsculas.
  - El icono aparece cuando la máquina de escribir llega a él.
  - Un id desconocido se quita del texto.

## 6. Calc en el hub (tanda H3, propuesta)

**Historia «Resta» (aprobada):**
- Los puntos de atención son la atención de Isak que Eco guardó y fue dejando caer por los mapas.
- Calc la devuelve convertida en mejoras.
- Humor seco.

En las líneas, el número de puntos es dinámico (`{puntos}`) y lleva al lado el icono del punto. Borrador de líneas de Calc, importantes (pausan), para H3:

1. «3 %. 100 %. Resultado: estoy aquí.»
2. «Esos {icono:atencion} que recoges son atención tuya. Eco la guardó y la fue dejando caer por ahí.»
3. «Eco sabe sumar atención. Nunca ha sabido restarla.»
4. «Tienes {puntos} {icono:atencion}. Yo los convierto en mejoras. Sin intereses.»
5. Eco, descolgándose (línea suya): «Yo solo la estaba… guardando. Por ti.»

Después se abre la tienda.

**Estilo de texto propio por personaje.** Ahora solo se define lo necesario; se implementa en H3:

| Personaje | Estilo |
|---|---|
| Eco | Panel blanco-azul y escritura fluida (el actual). |
| Calc | Pantalla de **LCD** con texto monoespaciado y fondo verde apagado. Las **cifras aparecen de golpe** y el resto se escribe por caracteres. |
| Notas | Frases cortas con guiones. |
| Linterna | Casi sin palabras («…», «¡!»). |
| Papelera | Lenta, con puntos suspensivos. |

Pide un `speaker_style` por interlocutor en `speakers` (fuente, panel, velocidad y regla de cifras).

## 7. Plan de tandas

| Tanda | Contenido | Estado |
|---|---|---|
| **H1** | Documento. Iconos en línea y `{puntos}`. `EcoGuide`. Piezas, Calc y el punto de carga con arte y SpriteFrames. Ayudas Q y fichas. Esquema y constructor. Sala `calc_test` probada de principio a fin. | **Hecha (2026-10-17)** |
| **H2** | Integrar el acertijo en la azotea del 1-2 (ampliada a 11 filas). Modelar las piezas en el validador de alcanzabilidad y en el camino exportado (pulso de espaldas, láser permanente, Debug para la pared y el panel, espera de la carga y terminal con corriente), con Calc desconocida y conocida. Capturas del 1-2. El bot vertical queda en el paso 15. | **Hecha (2026-10-17)**, §10 |
| **H3** | Encuentro en el hub: Calc aparece al llegar tras `ally_teleported`, habla (líneas de §6), Eco se descuelga con su línea, `meet_ally("calc")` y se abre la tienda. Estilo LCD de Calc. | Pendiente |

## 8. Cambios en `propuesta-1-2.md` §paso 14

- Se elimina «Calc apagada en la azotea con la Q `calc_off`, se enciende con el pulso» (opción A de §8).
- En su lugar va este acertijo: terminal sin corriente, pared con glitch, cuarto a oscuras, tres piezas, Calc cargándose y teletransportándose.
- La azotea pasa de unos 20 s a unos 60-90 s y necesita espacio para el cuarto (decisión de H2).
- La línea de Eco del chip del Debug no cambia.
- El recuerdo (secreto A) sigue en el paso 14, sin relación con este acertijo.

## 9. Preguntas abiertas (con recomendación)

1. **¿Calc apagada se ve desde el principio en la azotea, al 3 %?** *Recomendación:* sí (H1 lo hace así), sin Q, porque es historia. Deja claro que hay que cargarla.
2. ~~**¿Dónde va el cuarto en el 1-2 real?**~~ **Resuelta en H2** con la recomendación: a la derecha de la terminal, con la azotea ampliada hacia arriba, pero **4 filas** (§10).
3. **¿El panel oculto queda marcado tras verlo una vez con el Debug?** *Recomendación:* sí (H1). Pedir el Debug y el pulso a la vez sería injusto con dificultad 2.
4. **¿Debe Eco reaccionar a cada pulso del interruptor?** *Recomendación:* no. Bastan las luces del panel y del cuarto, para no llenar la pantalla de texto.
5. **Línea 7 de Eco («aplicación obsoleta»): ¿demasiado engreída?** *Recomendación:* mantenerla. Es coherente con §12.3 («Eco los llama aplicaciones obsoletas») y prepara la «Resta» de H3.
6. **Estilo LCD de Calc: ¿fuente nueva monoespaciada o los dígitos del HUD?** *Recomendación:* los dígitos del HUD (5x7) para las cifras y la fuente de textos con avance fijo para las letras. No hace falta una fuente nueva.

## 10. Tanda H2 hecha (2026-10-17): la azotea del 1-2 y el validador

**Cómo creció la azotea.** Medía 7 filas (0-6) y el cuarto no cabía: con tres alturas de repisas (subidas de 2 tiles, el máximo del validador) y 16 px de holgura sobre la cabeza (`validation.ceiling_margin_px`), el techo tiene que quedar 4 filas por encima de la repisa alta. Opción de menor riesgo: **4 filas nuevas ENCIMA** de la azotea y todas las de debajo bajan 4 (un script desplaza el grid, los objetos, los enemigos, los puntos de sincronización, las bandas `y_from`/`y_to`, `zone` y `cable`; las notas del JSON también). Los pisos 1-4, sus objetos, la economía y `sync_1`/`sync_2` no cambian salvo el desplazamiento. La torre pasa de 28 × 62 a **28 × 66**; bandas: azotea 0-10, piso 4 11-21, piso 3 22-35, piso 2 36-47, piso 1 48-59 y vestíbulo 60-65. Con 11 filas (704 px) la azotea cabe entera en pantalla y la cámara de torre no se mueve dentro de ella; `camera.limits: grid` sigue el alto nuevo. La fachada no depende del alto (se repite en vertical y las pestañas siguen a los tramos): no hizo falta regenerarla y su validador pasa. Ampliar hacia un lado no era posible (28 columnas, paredes en la 0 y la 27).

**Diseño final** (`data/levels/1-2.json`; filas de pie 9, suelo 10):

| Pieza | Celda | Notas |
|---|---|---|
| Llegada | columnas 1-2 | el hueco de la izquierda sube del piso 4 a la azotea |
| Punto de atención | (4, 9) | el de la azotea de siempre |
| `cargador_3` | (6, 9) | +50, cada 10 s (el tercer cargador del 1-2) |
| `terminal_azotea` | (10, 8), G (10, 9) | `requires_power`, `power_source` `dock_calc` (antes `terminal_1_2`) |
| `calc` | (11, 9) | al 3 %, junto a la pared; `path` (11, 9) → (12, 9) → dock |
| Pared del fondo | columna 12 | maciza en las filas 0-7; `pared_glitch` en (12, 8-9), puerta con `interruptor_luz` |
| `cuarto` | columnas 13-26, filas 1-9 | 14 × 9 (en `calc_test`, 17 × 9) |
| `interruptor_luz` | (14, 9) | 3 pulsos de espaldas |
| `dock_calc` | (16-17, 9) | 3 s de carga |
| Repisas de una vía | fila 8 col. 19-21; fila 6 col. 23-24; fila 4 col. 25-26 | subidas con 312, 184 y 56 px de holgura medidos con el Isak real |
| `interruptor_laser` | (26, 7) | pared derecha, a la altura del celular solo desde la repisa baja |
| `panel_oculto` | (26, 3) | sobre la repisa alta; 1 pulso de espaldas |
| `guia_calc` | (1, 1) | guion `calc_rooftop` |

**Validador** (`tools/validate_level.py`, `tools/level_plan.py`; regla 9 de la skill `level-builder`): la terminal con `requires_power` solo cuenta como meta con su punto de carga hecho; la pared con glitch se cruza con el Debug (el plan espera su disolución: 1 s real) y es puerta con el interruptor; cada pulso al interruptor o al panel deja a Isak de espaldas `pose_s` (0,45 s); el panel oculto exige el Debug disponible y estar a 256 px (el plan lo enciende 0,2 s y lo apaga); el interruptor láser solo con el láser y **no puede alcanzarse andando** (error de diseño); el punto de carga se arma con sus tres piezas y la espera de Calc es fija (despertar 0,3 + caminar 4,9 + carga 3,0 + cara despierta 0,8 + vórtice 1,5 ≈ **10,6 s**, la misma que mide la prueba GUT); la energía cuenta el cargador de la azotea. Con Calc conocida (`--allies calc`, o el segundo pase automático) todo arranca hecho y el camino va directo a la terminal.

**Márgenes del camino validado** (Calc desconocida): el acertijo dura unos 21 s de plan (de los 139 s del camino, frente a 110,5 s con Calc conocida); 3 + 1 pulsos de espaldas, 1 disparo desde la repisa baja (fila 7, columna 19), Debug dos veces (pared 1,6 s activo, 32 de energía; panel 0,2 s, 4); energía en la azotea: 100 tras `cargador_3`, mínimo 54 (la mínima del camino sigue siendo 22, en el piso 2). Subidas de la azotea con 16 px o más de holgura y 8 px de esquina (`tests/test_level_climbs.gd`).

**Desvíos respecto a H1 y a §9:** azotea +4 filas (no 2-3); Calc junto a la pared (columna 11) para acortar su paseo; el cuarto mide 14 columnas (en `calc_test`, 17); la terminal se llama `terminal_azotea`; el tiempo de espaldas del interruptor es el `pose_s` del catálogo (0,45 s), por decidir si baja a 0,3 s. `calc_test` lleva ahora `validation` (láser y Debug exigidos) y valida con el acertijo completo.

**Pruebas y capturas:** `tests/test_level_1_2.py` (azotea, plan del acertijo, Calc conocida, camino exportado en los dos casos), `tests/test_validate_level.py` (`CalcPuzzleTest`: casos negativos de interruptor láser alcanzable andando o fuera de línea, panel sin Debug o lejos, sin energía, repisa sin holgura y terminal sin corriente), `tests/test_level_1_2_rooftop.gd` (la secuencia completa con el Isak real, cámara, muerte a mitad del acertijo, intento nuevo, terminal y nivel completado, Calc conocida, economía) y `tests/test_level_climbs.gd`. Capturas: `tools/render_level_1_2.gd` (pisos y azotea) y `tools/render_level_1_2_rooftop.gd` (cada paso del acertijo en el nivel real); mapa con las piezas nuevas en `tools/render_level_map.py`.

**Qué queda para H3:** Calc aparece en el hub al llegar tras `ally_teleported` (el gancho ya lo emite la azotea del 1-2), sus líneas de §6 con estilo LCD, la línea de Eco que se descuelga, `meet_ally("calc")` y la tienda abierta. Además, el bot vertical (paso 15 del 1-2) que seguirá el camino exportado con las acciones nuevas.
