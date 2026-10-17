# Encuentro con Calc: acertijo de la azotea del 1-2

**Estado:** diseño del usuario del **2026-10-17**. Sustituye la opción A de `propuesta-1-2.md` §8 (Calc apagada junto a la terminal, Q `calc_off` y un pulso). Es el paso 14 de `propuesta-1-2.md` §10, junto con el recuerdo. **Tanda H1 hecha (2026-10-17):** sistemas, piezas, arte, sala de prueba `calc_test` y este documento. Pendientes: **H2** (integrarlo en el 1-2 y en el validador y el bot) y **H3** (el encuentro en el hub). Los textos de Eco y de Calc son **propuestas** hasta que el usuario los decida.

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
| **H2** | Integrar el acertijo en la azotea del 1-2 (ancla de las columnas 18-20; ampliar la azotea si hace falta). Modelar las piezas en el validador de alcanzabilidad y en el camino exportado (pulso de espaldas, láser permanente, Debug para la pared y el panel, espera de la carga y terminal con corriente). Bot vertical (paso 15). Capturas del 1-2. | Pendiente |
| **H3** | Encuentro en el hub: Calc aparece al llegar tras `ally_teleported`, habla (líneas de §6), Eco se descuelga con su línea, `meet_ally("calc")` y se abre la tienda. Estilo LCD de Calc. | Pendiente |

## 8. Cambios en `propuesta-1-2.md` §paso 14

- Se elimina «Calc apagada en la azotea con la Q `calc_off`, se enciende con el pulso» (opción A de §8).
- En su lugar va este acertijo: terminal sin corriente, pared con glitch, cuarto a oscuras, tres piezas, Calc cargándose y teletransportándose.
- La azotea pasa de unos 20 s a unos 60-90 s y necesita espacio para el cuarto (decisión de H2).
- La línea de Eco del chip del Debug no cambia.
- El recuerdo (secreto A) sigue en el paso 14, sin relación con este acertijo.

## 9. Preguntas abiertas (con recomendación)

1. **¿Calc apagada se ve desde el principio en la azotea, al 3 %?** *Recomendación:* sí (H1 lo hace así), sin Q, porque es historia. Deja claro que hay que cargarla.
2. **¿Dónde va el cuarto en el 1-2 real?** *Recomendación:* a la derecha de la terminal, con la azotea ampliada 2-3 filas hacia arriba. La azotea mide hoy 7 filas: el cuarto con tres alturas de plataformas necesita unas 8.
3. **¿El panel oculto queda marcado tras verlo una vez con el Debug?** *Recomendación:* sí (H1). Pedir el Debug y el pulso a la vez sería injusto con dificultad 2.
4. **¿Debe Eco reaccionar a cada pulso del interruptor?** *Recomendación:* no. Bastan las luces del panel y del cuarto, para no llenar la pantalla de texto.
5. **Línea 7 de Eco («aplicación obsoleta»): ¿demasiado engreída?** *Recomendación:* mantenerla. Es coherente con §12.3 («Eco los llama aplicaciones obsoletas») y prepara la «Resta» de H3.
6. **Estilo LCD de Calc: ¿fuente nueva monoespaciada o los dígitos del HUD?** *Recomendación:* los dígitos del HUD (5x7) para las cifras y la fuente de textos con avance fijo para las letras. No hace falta una fuente nueva.
