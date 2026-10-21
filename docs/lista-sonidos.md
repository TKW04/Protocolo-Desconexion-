# Lista de sonidos: SFX, ambientes, música, voces y UI

**Estado:** propuesta (2026-10-20). Inventario completo de los sonidos que necesita el juego, para cuando se aborde la decisión abierta «Música y efectos de sonido» (`08-pendientes.md`: se trata al terminar el 1-1, el 1-2 y el 1-3). Los IDs, duraciones y prioridades son propuestas. **Desde el 2026-10-20 el sistema de audio está montado** (`AudioManager`, `data/audio.json`, seis buses, ajustes de volumen) con 24 sonidos **provisionales** generados por script; ver «Integración del sistema de audio (2026-10-20)» al final.

**Fuentes:** `01-ficha-reglas.md`, `02-isak-habilidades.md`, `05-hub.md`, `06-finales.md`, `mundo-1` a `mundo-6`, `propuesta-1-2.md`, `propuesta-1-3.md`, `propuesta-recuerdos.md`, `propuesta-asistentes-y-vidas.md`, `propuesta-mejoras.md`, `preguntas.md`, y el código (`scripts/autoload/event_bus.gd`, `scripts/player/`, `scripts/levels/`, `scripts/enemies/`, `scripts/hub/`, `scripts/ui/`).

## 0. Cómo leer las tablas

- **ID:** nombre propuesto del recurso y de la entrada del catálogo (`sfx_` efecto, `amb_` ambiente, `mus_` música, `stg_` stinger, `vox_` blip de voz, `ui_` interfaz).
- **Dónde / cuándo:** señal de `EventBus` (p. ej. `EventBus.pulse_fired`), señal local o estado del script, o «nuevo» si no hay disparador.
- **Prioridad:** **P1** imprescindible (sin él el juego se siente mudo o se pierde información), **P2** deseable, **P3** extra.
- **Estado** (ningún sonido existe todavía; `assets/audio/` solo tiene `.gitkeep`):
  - **E:** el evento ya existe en el código (señal o estado); solo falta el audio y conectarlo.
  - **N:** el objeto existe, pero hay que añadir el punto de disparo (estado o señal nueva).
  - **F:** futuro (mundo, jefe o pantalla aún sin construir; lo prevén los docs).
- **Tono general:** sobrio y cálido. Chiptune suave (pulsos y triángulos, poco ruido blanco), ataques cortos, sin agudos estridentes. Lo «molesto» del mundo (notificaciones, alarmas) se sugiere con el ritmo y el timbre, no con volumen ni frecuencias agresivas.
- **Tiempo:** los SFX del mundo siguen el tiempo del mundo (el Debug lo ralentiza ×0,5: bajar el tono/velocidad de reproducción o filtrar); los de UI, Eco y pausa van en tiempo real (`process_mode` siempre), como sus scripts.

## 1. SFX de Isak: movimiento y habilidades

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `sfx_isak_step` | Paso suave de zapatilla sobre superficie digital | `run_state.gd` (cuadros de contacto de la animación de andar/correr) | Todos + hub | P2 | N | 0,05-0,1 s; 4 variantes + tono aleatorio ±5 %; más espaciado andando, con un leve tintineo de mochila al correr |
| `sfx_isak_jump` | Impulso corto, «bip» ascendente suave | `jump_state.gd` al entrar | Todos | P1 | E | 0,1-0,15 s; 2-3 variantes; no debe cansar (se oye cientos de veces) |
| `sfx_isak_land` | Aterrizaje amortiguado | `fall_state.gd` al tocar suelo | Todos | P1 | E | 0,1 s; dos intensidades según velocidad de caída (suave / fuerte) |
| `sfx_isak_idle_terminal` | Terminal holográfica que se despliega (zumbido corto + clic) | `idle_state.gd` al sacar la terminal | Todos + hub | P3 | N | 0,4 s; muy bajo; refuerza el «ingeniero» |
| `sfx_isak_pulse` | Pulso de datos: onda corta y redonda | `pulse_state.gd` / `EventBus.pulse_fired` | Todos | P1 | E | 0,25-0,35 s (pose 0,33 s); 2 variantes; la acción más usada: cálida, nada agresiva |
| `sfx_pulse_hit_enemy` | Golpe del pulso que aturde (chispa + «tilín») | `alert_bubble.gd` / `notification_badge.gd` señal `stunned` | Todos | P1 | E | 0,2 s; confirma el acierto |
| `sfx_pulse_hit_object` | El pulso alcanza un objeto activable (contacto eléctrico) | `pulse_receiver.gd`, `pulse_bridge.gd`, `power_switch.gd`, `dnd_switch.gd` | Todos | P1 | E | 0,15 s; genérico; cada objeto añade su propio sonido de activación (§3) |
| `sfx_pulse_energy_return` | «+4» del Pulso de retorno (mejora) | `EventBus.pulse_energy_returned` / `upgrade_fx.gd` | Todos | P3 | E | 0,2 s; arpegio de 2 notas, emparentado con `sfx_recharge_pickup` |
| `sfx_isak_laser_fire` | Disparo del láser: haz fino y limpio | `EventBus.laser_fired` / `laser_muzzle.gd` | Todos (desde 1-1) | P1 | E | 0,2-0,3 s; 2 variantes |
| `sfx_laser_impact` | Proyectil que choca con pared, enemigo o lector | `laser_projectile.gd` al consumirse | Todos | P2 | N | 0,1 s; versión «rebote» para el badge que lo desvía (`notification_badge.gd` señal `deflected`) |
| `sfx_laser_pierce` | Destello del láser que perfora (mejora) | `upgrade_fx.gd` | Todos | P3 | E | 0,15 s; capa extra sobre el impacto |
| `sfx_laser_denied` | Intento sin energía o en enfriamiento: «clic» apagado | `EventBus.laser_denied` | Todos | P1 | E | 0,1 s; sordo, no de error estridente; compartir familia con `sfx_dash_denied` |
| `sfx_isak_dash` | Deslizar: barrido de datos rápido (whoosh digital) | `EventBus.dash_started` / `dash_state.gd` | Desde 1-3 | P1 | E | 0,2-0,25 s; variante aérea opcional |
| `sfx_dash_through` | Capa al atravesar un banner o proyectil con invulnerabilidad | `dash_state.gd` + contacto con `spam_banner` | Desde 1-3 | P2 | N | 0,15 s; «tela» que se rasga suave; refuerza la regla del gesto |
| `sfx_dash_denied` | Dash sin energía, en enfriamiento o bloqueado | `EventBus.dash_denied(reason)` | Desde 1-3 | P2 | E | 0,1 s; misma familia que `sfx_laser_denied` |
| `sfx_debug_charge` | Carga del Debug al mantener 1 s (subida de tono) | `EventBus.debug_activation_progress_changed` | Desde 1-2 | P1 | E | Bucle corto con tono que sube con el progreso; se corta al soltar |
| `sfx_debug_on` | Entrada al Debug Mode (filtro que se abre, campanita cian) | `EventBus.debug_mode_changed(true)` | Desde 1-2 | P1 | E | 0,4 s; arranca el efecto de bus «mundo lento» (§11) |
| `sfx_debug_off` | Salida del Debug (inverso) | `EventBus.debug_mode_changed(false)` | Desde 1-2 | P1 | E | 0,3 s |
| `sfx_debug_energy_empty` | El Debug se corta por falta de energía | `debug_mode.gd` (salida por energía 0) | Desde 1-2 | P2 | N | 0,3 s; distinto de la salida voluntaria |
| `sfx_debug_reveal` | Aparece una plataforma o pared oculta («glitch» que se ordena) | `EventBus.debug_reveal_changed` / `hidden_platform.gd` | Desde 1-2 | P2 | E | 0,2 s; pista sonora de secreto |
| `sfx_hide_on` | Ocultarte: Isak se apaga (mejora Pulso 4) | `EventBus.hide_changed(true)` | Todos | P2 | E | 0,3 s; sordo, como bajar el brillo |
| `sfx_hide_off` | Fin del Ocultarte; versión «corte» con glitch cuando se agota | `EventBus.hide_ended(reason)` | Todos | P2 | E | 0,2 s; `propuesta-mejoras.md` ya pide «destello del glitch y sonido corto» al cortarse |
| `sfx_enemy_lost_track` | «?» del perseguidor que pierde el rastro | `upgrade_fx.gd` / `notification_badge.gd` estado `lost` | Todos | P3 | E | 0,2 s; nota interrogativa |

## 2. SFX de daño, vidas y estados

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `sfx_isak_hurt` | Golpe recibido: glitch corto (píxeles que se desplazan) | `hurt_state.gd`; `hit_player` de enemigos; `spike_hazard.gd` | Todos | P1 | E | 0,25 s; 3 variantes; nunca un grito (Isak no tiene voz) |
| `sfx_isak_death` | Isak se pixela y sube en líneas de código | `dead_state.gd` / `EventBus.player_died` | Todos | P1 | E | 1,2-1,6 s (19 cuadros a 12 fps + pausa); descendente y triste, no dramático |
| `sfx_life_lost` | Se pierde una vida (icono de mini teléfono que se apaga) | `EventBus.life_lost` / HUD | Todos | P1 | E | 0,4 s |
| `sfx_respawn` | Reaparición en el punto de sincronización | `EventBus.player_respawned` | Todos | P1 | E | Puede reutilizar `sfx_vortex_arrive` en versión corta |
| `sfx_rollback` | Eco aplica el rollback: datos que se rebobinan | `EventBus.rollback_applied` / `game_over_intro.gd` | Hub (tras game over) | P1 | E | 1-1,5 s; cinta digital hacia atrás; lo sigue `stg_game_over` |
| `sfx_low_sync_alarm` | Entrada en Sync Rate bajo (<20 %): latido digital suave | `EventBus.low_sync_changed(true)` | Todos | P1 | E | Bucle lento (~1 Hz) mientras dure; con «Reducir efectos de Sync bajo» se oye solo una vez |
| `sfx_low_sync_recover` | Salida del Sync bajo | `EventBus.low_sync_changed(false)` | Todos | P3 | E | 0,3 s |
| `sfx_fall_out` | Caída fuera del nivel (red de seguridad) | `level_runner.gd` (`fall_limit_margin_px`) | Todos | P3 | N | Puede ser `sfx_isak_hurt` + `sfx_respawn` |

## 3. SFX de objetos e interacción del Mundo 1 (1-1, 1-2, 1-3)

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `sfx_vortex_arrive` | Vórtice de llegada: anillos cian que se abren y giran | `warp_vortex.gd` (ARRIVE, inicio de nivel y llegada al hub) | Todos + hub | P1 | E | 1-1,5 s; firma sonora del viaje |
| `sfx_vortex_depart` | Vórtice de salida | `warp_vortex.gd` (salida) | Todos | P1 | E | 1 s; inverso del de llegada |
| `sfx_checkpoint` | Punto de sincronización activado | `EventBus.checkpoint_activated` / `checkpoint.gd` | Todos | P1 | E | 0,5 s; acorde mayor suave, reconocible |
| `sfx_attention_point` | Recoger punto de atención | `attention_point.gd` / `EventBus.attention_points_changed` | Todos | P1 | E | 0,15 s; tono que sube si se recogen seguidos (escala de 5 notas) |
| `sfx_recharge_pickup` | Recoger drop de energía o Sync | `EventBus.recharge_collected(kind)` / `recharge_pickup.gd` | Todos | P1 | E | 0,2 s; 2 variantes por `kind` (energía / Sync) |
| `sfx_power_bank_pickup` | Recoger power bank | `power_bank_pickup.gd` / `EventBus.power_banks_changed` | Todos | P2 | E | 0,3 s |
| `sfx_power_bank_no_room` | Power bank sin hueco | `EventBus.power_bank_no_room` | Todos | P2 | E | 0,15 s; familia «denegado» |
| `sfx_charger` | Cargador de energía: carga mientras se toca | `EventBus.charger_used` / `charger.gd` | Todos + hub | P2 | E | Bucle corto con subida + «lleno» al acabar. En la arena de Alerta Mayor hay 4 cargadores con 4 s de enfriamiento (`propuesta-jefe-alerta-mayor.md` §2.4): suena a menudo, así que debe ser breve y no cansar |
| `sfx_ability_pickup` | Recoger el chip de una habilidad | `ability_pickup.gd` / `EventBus.ability_obtained` | 1-1 (láser), 1-2 (Debug), 1-3 (Deslizar) | P1 | E | 0,3 s; lo sigue `sfx_ability_install` y `stg_ability_obtained` |
| `sfx_ability_install` | Instalación: anillo cian que se expande + destello | `install_effect.gd` (0,5 s, tiempo real) | Ídem | P1 | E | 0,5 s, sincronizado con el anillo |
| `sfx_extra_life_pickup` | Vida extra (secreto D del 1-1) | `EventBus.extra_life_collected` / `extra_life_pickup.gd` | 1-1 y secretos | P1 | E | 0,6 s; especial, emparentado con `sfx_life_lost` en positivo |
| `sfx_memory_pickup` | Recoger un mensaje de secreto (Mamá) | `EventBus.memory_obtained` / `memory_pickup.gd` | 1-1, 1-2, 1-3 y futuros | P1 | E | 0,8 s; cálido (piano de juguete o caja de música); `propuesta-recuerdos.md` §2.5 dice «sin sonido propio» para el texto: este es el sonido del objeto, no una voz |
| `sfx_bridge_activate` | Puente desactivado que se enciende | `pulse_bridge.gd` | 1-1 | P1 | E | 0,6 s; segmentos que se encienden en cascada |
| `sfx_pulse_receiver_on` | Receptor de pulso activado | `pulse_receiver.gd` | 1-1, 1-2 | P2 | E | 0,3 s |
| `sfx_laser_receiver_on` | Lector láser activado | `laser_receiver.gd` | 1-2 | P2 | E | 0,3 s; timbre más agudo que el receptor de pulso |
| `sfx_relay_powered` | Receptor enlazado con corriente (zumbido) | `relay_receiver.gd` | 1-2 | P2 | E | Bucle bajo y localizado mientras tiene corriente |
| `sfx_laser_switch` | Interruptor láser / cable que se ilumina | `laser_switch.gd`, `laser_cable.gd` | 1-2 | P2 | E | 0,3 s; el cable puede llevar un «barrido» que recorre su longitud |
| `sfx_popup_appear` | Pop-up que aparece (bloqueante u overlay) | `popup_blocker.gd`, `overlay_popup.gd` | 1-1, 1-2 | P2 | N | 0,2 s; tono de notificación del mundo (motivo de §8) |
| `sfx_popup_close` | Cerrar pop-up con el pulso o el láser | `popup_blocker.gd`, `overlay_popup.gd` | 1-1, 1-2 | P1 | E | 0,2 s; «swoosh» de ventana + clic |
| `sfx_ad_cover_tick` | «Saltar anuncio en 5…» (cuenta falsa) | `ad_cover.gd` | 1-2 | P2 | E | Tic por segundo + «bloqueo» al llegar a 0 sin saltarse (humor) |
| `sfx_ad_cover_break` | Quitar el anuncio que tapa el botón | `ad_cover.gd` | 1-2 | P2 | E | 0,2 s |
| `sfx_reminder_tick` | Temporizador del recordatorio | `reminder_platform.gd` señal `countdown_started` | 1-2 | P1 | E | Tic suave cada segundo, más rápido en `warning_started`; **accesibilidad** (§12) |
| `sfx_reminder_fall` | El recordatorio vence y cae | `reminder_platform.gd` señal `fell` | 1-2 | P1 | E | 0,4 s |
| `sfx_reminder_respawn` | El recordatorio vuelve | `reminder_platform.gd` señal `respawned` | 1-2 | P3 | E | 0,2 s |
| `sfx_snooze` | Botón Posponer (láser): reinicia el recordatorio | `snooze_button.gd` / `reminder_platform.gd` señal `snoozed` | 1-2 | P2 | E | 0,3 s; «bostezo» de alarma de dos notas |
| `sfx_update_bar_stuck` | Barra de actualización trabada en 99 % | `update_bar.gd` | 1-2 piso 4 | P3 | N | Bucle de «procesando» que se atasca; humor |
| `sfx_power_switch` | Interruptor de pulso de la azotea | `power_switch.gd` | 1-2 azotea | P2 | E | 0,3 s; clic eléctrico grave |
| `sfx_debug_switch` | Panel oculto activado con el Debug | `power_switch.gd` (`debug_switch`) | 1-2 azotea | P2 | E | 0,3 s; timbre cian |
| `sfx_charge_dock_segment` | Medidor de Calc: un segmento (de 10) se llena | `charge_dock.gd` | 1-2 azotea | P2 | E | 0,1 s; tono que sube por segmento |
| `sfx_charge_dock_full` | Medidor lleno, Calc despierta | `charge_dock.gd` | 1-2 azotea | P2 | E | 0,8 s; enlaza con `stg_ally_met` |
| `sfx_glitch_wall_hum` | Pared con leve glitch (secreto): zumbido muy bajo | `glitch_wall.gd` | 1-1 (y secretos con Debug) | P2 | N | Bucle localizado, audible solo cerca: pista de secreto sin texto |
| `sfx_glitch_wall_pass` | Atravesar / revelar la pared del secreto | `glitch_wall.gd` | 1-1, 1-3 «Excepciones» | P2 | N | 0,4 s |
| `sfx_exit_terminal` | Terminal de salida activada con el pulso | `exit_terminal.gd` | Todos | P1 | E | 0,6 s; lo sigue `stg_level_complete` |
| `sfx_exit_door` | Puerta «Marcar como leído» (legado) | `exit_door.gd` | Salas de prueba | P3 | E | 0,4 s; solo si sigue en uso |
| `sfx_dnd_switch` | Interruptor «No molestar» activado | `dnd_switch.gd` | 1-3 sala «Ajustes» | P1 | E | 0,5 s; clic de ajuste + silencio breve (ironía: después llega más ruido) |
| `sfx_metronome_tick` | Pulso del metrónomo (vibración del celular) | `rhythm_zone.gd` señal `beat` | 1-3 Tramo 2 | P1 | E | 0,08 s; zumbido de vibración grave; **equivalente sonoro opcional** del ritmo visual (§12) |
| `sfx_metronome_speedup` | El compás se acelera | `rhythm_zone.gd` señal `tempo_changed` | 1-3 Tramos 2 y 4 | P2 | E | 0,3 s; doble vibración |
| `sfx_blink_warn` | Plataforma a punto de apagarse (parpadeo de 0,75 s) | `blink_platform.gd` señal `warning_started` | 1-3 Tramo 2 | P1 | E | 0,75 s; 3 pitidos descendentes muy suaves; **accesibilidad** (§12) |
| `sfx_blink_off` | La plataforma se apaga | `blink_platform.gd` señal `switched_off` | 1-3 | P2 | E | 0,1 s |
| `sfx_blink_on` | La plataforma se enciende | `blink_platform.gd` señal `switched_on` | 1-3 | P2 | E | 0,1 s |

## 4. SFX de enemigos del Mundo 1 y del jefe Alerta Mayor

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `sfx_bubble_patrol` | Burbuja de alerta: «pop» suave al girar | `alert_bubble.gd` estado `patrol` | 1-1 → 1-3 | P2 | E | 0,1 s; posicional; nada continuo |
| `sfx_bubble_anticipate` | Burbuja a punto de embestir | `alert_bubble.gd` estado `anticipate` | 1-1 → 1-3 | P1 | E | 0,3 s; aviso audible del ataque |
| `sfx_enemy_stunned_loop` | Aturdido (estrellas digitales) | Estado `stunned` de burbuja y badge | Mundo 1 | P2 | E | Bucle corto mientras dura + `sfx_enemy_recover` al acabar |
| `sfx_enemy_recover` | El enemigo se recupera del aturdimiento | Salida de `stunned` / badge `recover` | Mundo 1 | P2 | E | 0,2 s; avisa de que vuelve a ser peligroso |
| `sfx_enemy_hit` | Daño a un enemigo (láser) | señal `damaged` (`enemy_health.gd`) | Todos | P1 | E | 0,15 s |
| `sfx_enemy_popped` | Enemigo derrotado: notificación que se descarta | señal `popped` / `EventBus.enemy_defeated` | Todos | P1 | E | 0,3 s; «pop» satisfactorio; 2 variantes |
| `sfx_badge_wake` | Punto rojo se despierta y fija a Isak | `notification_badge.gd` estado `wake` | 1-2, 1-3 | P1 | E | 0,3 s; el clásico «tin» de notificación |
| `sfx_badge_chase` | Punto rojo persiguiendo | `notification_badge.gd` estado `chase` | 1-2, 1-3 | P2 | E | Bucle leve posicional; sube de tono al acercarse |
| `sfx_badge_lunge` | Embestida del punto rojo (tras `anticipate`) | estados `anticipate` / `lunge` | 1-2, 1-3 | P1 | E | Aviso 0,2 s + golpe 0,15 s |
| `sfx_banner_warn` | Banner de spam a punto de barrer | `spam_banner.gd` estado `warn` | 1-2, 1-3 | P1 | E | 0,4-0,6 s; **accesibilidad**: avisa del barrido fuera de pantalla |
| `sfx_banner_sweep` | Barrido del banner | `spam_banner.gd` estado `sweep` | 1-2, 1-3 | P1 | E | Duración del barrido; paneo de lado a lado |
| `sfx_alarm_bell_warn` | Campana de alarma a punto de sonar | `alarm_bell.gd` estado `warn` | 1-3 Tramo 4 | P1 | E | 0,3 s; temblor metálico suave |
| `sfx_alarm_bell_wave` | Onda de la campana (golpea) | `alarm_bell.gd` estado `wave` | 1-3 Tramo 4 | P1 | E | 0,5 s; campana amortiguada, no estridente; variación de tono por campana |
| `sfx_weak_point_hit` | Golpe al punto débil del jefe | `weak_point.gd` | Jefes | P1 | E | 0,3 s; satisfactorio; común a todos los jefes con capa propia por mundo |
| `sfx_boss1_intro` | Alerta Mayor aparece («99+» que se infla) | Jefe del Mundo 1 (por construir) | Jefe M1 | P1 | F | 1,5 s |
| `sfx_boss1_launch` | Lanza burbujas y banners (fase 1) | Ídem | Jefe M1 | P1 | F | Reutiliza familias de §4 con más cuerpo |
| `sfx_boss1_popup_storm` | Lluvia de pop-ups (fase 2) | Ídem | Jefe M1 | P2 | F | Ráfaga de `sfx_popup_appear` en cascada |
| `sfx_boss1_clones` | Copias falsas del jefe (fase 3) | Ídem | Jefe M1 | P2 | F | Las copias suenan «huecas»; la real, con cuerpo (pista sonora opcional) |
| `sfx_boss_phase_change` | Cambio de fase de un jefe | Común a jefes | Jefes | P1 | F | 1 s |
| `sfx_boss_defeat` | Jefe vencido: se desarma en píxeles | Común a jefes | Jefes | P1 | F | 2-3 s; enlaza con `stg_boss_defeated` y el recuerdo |
| `sfx_boss_rollback_easy` | **Retirado del jefe M1 (2026-10-20).** Alerta Mayor no hace ningún rollback (`propuesta-jefe-alerta-mayor.md` §1.2). Queda reservado para el rollback del **jefe final** al terminar Caché (Isak Optimizado escapa y Eco desecha todo) | Jefe final (por diseñar) | M6 | P3 | F | Reutiliza `sfx_rollback` en versión larga. Renombrar el ID al diseñar el jefe final (p. ej. `sfx_final_boss_rollback`); no conectarlo en el jefe M1 |

## 5. SFX de Eco y ayudas

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `sfx_eco_line` | Llega una línea normal de Eco (notificación suave) | `EventBus.eco_line_started` / `eco_text_box.gd` | Todos | P1 | E | 0,3 s; la «notificación» de Eco: amable y pulida, casi demasiado |
| `sfx_eco_line_important` | Línea importante (pausa el juego) | `eco_text_box.gd` (important) | Todos | P1 | E | 0,5 s; más presencia; baja la música (ducking) |
| `sfx_eco_line_close` | Cerrar la línea importante | `eco_text_box.gd` (confirmar) | Todos | P2 | E | Puede ser `ui_confirm` |
| `sfx_eco_encounter` | Eco se presenta y regala el pulso | `eco_encounter.gd` | 1-1 | P1 | E | 1-2 s; lo sigue `stg_ability_obtained` |
| `sfx_eco_companion_hover` | Eco flotando cerca de Isak | `eco_companion.gd` | Todos | P3 | E | Bucle casi inaudible; desactivable |
| `sfx_eco_teleport` | Eco/aliado se teletransporta | `EventBus.ally_teleported` | Hub, niveles | P2 | E | 0,4 s |
| `sfx_help_prompt` | Aparece el icono «Q» de ayuda | `EventBus.help_prompt_shown` / `help_prompt.gd` | Todos | P2 | E | 0,15 s; muy discreto |
| `sfx_help_q` | Ayuda con Q: Eco se acerca y brilla ámbar | `help_system.gd` | Todos | P1 | E | 0,4 s; en ámbar = timbre más cálido que `sfx_eco_line` |
| `sfx_help_learned` | Ficha nueva del álbum desbloqueada | `EventBus.help_learned` | Todos | P2 | E | 0,3 s; «página» + nota |

## 6. SFX del hub y aliados

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `sfx_hub_station_near` | Acercarse a una estación (aparece el indicador) | `hub_station.gd` | Hub | P2 | N | 0,1 s; muy suave |
| `sfx_hub_panel_open` | Abrir el panel de una estación | `hub_panel.gd` | Hub | P1 | E | 0,2 s |
| `sfx_hub_panel_close` | Cerrar el panel | `hub_panel.gd` | Hub | P1 | E | 0,15 s |
| `sfx_folder_open` | Abrir una carpeta de mundo | `folder_panel.gd` / `folder_station.gd` | Hub | P1 | E | 0,3 s; carpeta de celular que se expande |
| `sfx_level_select` | Elegir subnivel (entra al vórtice) | `folder_panel.gd` | Hub | P1 | E | 0,3 s; precede a `sfx_vortex_depart` |
| `sfx_level_locked` | Subnivel o mundo bloqueado | `folder_panel.gd`, `hub_worlds.gd` | Hub | P2 | E | Familia «denegado» |
| `sfx_save_game` | Guardar en Notas | `EventBus.game_saved` / `notas_panel.gd` | Hub | P1 | E | 0,6 s; tranquilizador, cálido |
| `sfx_unsaved_mark` | Aparece el aviso de cambios sin guardar | `EventBus.unsaved_changes_changed(true)` | Hub | P3 | E | 0,1 s; opcional |
| `sfx_notas_album_page` | Pasar página / carpeta del álbum | `notas_album.gd` | Hub | P2 | E | 0,15 s; 2 variantes |
| `sfx_memory_read` | Abrir un recuerdo en Notas | `EventBus.memory_read` | Hub | P2 | E | 0,4 s; mismo timbre que `sfx_memory_pickup`, más íntimo |
| `sfx_calc_wake` | Calc se enciende (escena «Resta») | `calc_intro.gd`, `calc_actor.gd` | 1-2 azotea / hub | P2 | E | 1 s; calculadora que arranca (pitidos de display) |
| `sfx_calc_step` | Calc caminando | `calc_actor.gd` | Hub, 1-2 | P3 | N | Clic de teclas; 2 variantes |
| `sfx_calc_purchase` | Compra de una mejora | `EventBus.upgrade_purchased` / `calc_panel.gd` | Hub | P1 | E | 0,5 s; «caja registradora» honesta (contraste con la Tienda del M5) |
| `sfx_calc_denied` | Sin puntos o tope de acceso | `calc_panel.gd` | Hub | P1 | E | Familia «denegado» |
| `sfx_trash_pending` | La papelera tiene algo que recuperar | `EventBus.trash_changed(true)` / `papelera.gd` | Hub | P3 | E | Bucle muy leve cerca de ella |
| `sfx_trash_recover` | Recuperar lo de la papelera | `EventBus.trash_recovered` | Hub | P1 | E | 0,8 s; «restaurar» inverso del rollback (cálido) |
| `sfx_ally_met` | Aliado nuevo (Calc, Notas, Papelera, Linterna) | `EventBus.ally_met` | Hub | P2 | E | Enlaza con `stg_ally_met` |
| `sfx_hub_page_slide` | Cambio de página del hub | Hub con páginas (por construir) | Hub | P3 | F | 0,3 s |
| `sfx_hub_wallpaper_piece` | Pieza del fondo que se recompone y se ilumina | Tras cada jefe | Hub | P2 | F | 1,5 s; una nota más del tema del hub cada vez |
| `sfx_hub_eco_intrusion` | La Nube abierta: notificaciones en el borde | Hub tras abrir la Nube | Hub | P2 | F | Rompe el silencio del hub a propósito |
| `sfx_linterna_on` / `sfx_linterna_off` | Linterna en zonas oscuras | Asistente Linterna (por construir) | Mundo oscuro | P2 | F | 0,2 s cada uno |

## 7. UI y menús

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `ui_move` | Mover el cursor en un menú | `pause_menu.gd`, paneles del hub | Todos | P1 | E | 0,05 s; muy corto; no debe saturar al mantener |
| `ui_confirm` | Confirmar | Ídem | Todos | P1 | E | 0,1 s |
| `ui_back` | Volver / cancelar | Ídem | Todos | P1 | E | 0,1 s |
| `ui_toggle` | Cambiar una opción (Sí/No, Mostrar/Ocultar) | `pause_menu.gd` | Todos | P2 | E | 0,08 s; dos tonos (activar/desactivar) |
| `ui_error` | Acción no permitida | Menús | Todos | P1 | E | Familia «denegado» (sordo) |
| `ui_pause_open` | Abrir la pausa | `EventBus.pause_menu_opened` | Todos | P1 | E | 0,2 s; junto con bajar la música (filtro paso bajo) |
| `ui_pause_close` | Cerrar la pausa | `EventBus.pause_menu_closed` | Todos | P1 | E | 0,2 s |
| `ui_rebind_wait` | Esperando la nueva tecla | `pause_menu.gd` (controles) | Todos | P3 | E | Bucle leve |
| `ui_rebind_done` | Tecla asignada | `EventBus.controls_changed` | Todos | P2 | E | 0,1 s |
| `ui_rebind_conflict` | Conflicto de asignación | `pause_menu.gd` | Todos | P3 | E | Familia «aviso» |
| `ui_quit_prompt` | Aviso de salir sin guardar | `quit_prompt.gd`, `quit_guard.gd` | Todos | P2 | E | 0,3 s; serio pero amable |
| `ui_nickname_key` | Teclear una letra del apodo | `nickname_entry.gd` | 1-1, Notas | P2 | E | 0,04 s; 3 variantes |
| `ui_nickname_confirm` | Confirmar el apodo | `nickname_entry.gd` / `EventBus.nickname_changed` | 1-1, Notas | P2 | E | 0,3 s |
| `ui_ability_notice` | Aviso de control («Láser: F / …») | `ability_notices.gd` | Todos | P2 | E | 0,2 s |
| `ui_system_notice` | Aviso del sistema («Recuerdo obtenido…», «Guarda en Notas…») | `memory_notice.gd` | Todos | P2 | E | 0,2 s; neutro, distinto de Eco |
| `ui_hud_attention_tick` | Contador de puntos que sube | `hud.gd` | Todos | P3 | E | Solo si el contador anima; si no, lo cubre `sfx_attention_point` |
| `ui_title_start` | Pantalla de título: empezar / continuar | No existe pantalla de título (el juego arranca en el 1-1 o en el hub) | — | P3 | F | Solo si se añade un título |

## 8. Voces y blips de texto

Los personajes hablan **solo con texto**; no hay voz. Se propone un **blip opcional** por carácter (o cada 2-3 caracteres) durante la máquina de escribir, distinto por personaje, como «voz» tímbrica. Los recuerdos y mensajes de Mamá no llevan blip (`propuesta-recuerdos.md` §2.5: «sin voz ni sonido propio»).

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `vox_eco_blip` | Eco: tono limpio, agudo y «perfecto» | `eco_text_box.gd` (máquina de escribir) | Todos | P2 | E | 0,03 s; 3-4 alturas al azar; variantes por vuelta (Caché servicial, Kernel insistente/más rápido, Raíz seco/grave) cuando se decida el tono por vuelta |
| `vox_calc_blip` | Calc: pitido de calculadora | Paneles y escena de Calc (`calc_intro.gd`, `calc_panel.gd`) | Hub, 1-2 | P2 | E | 0,03 s; cuadrado, dos alturas |
| `vox_notas_blip` | Notas: lápiz / papel suave | `notas_intro.gd`, `notas_panel.gd` | Hub | P2 | E | 0,03 s |
| `vox_papelera_blip` | Papelera: grave, melancólica y cálida | `papelera.gd` (habla desde el 4-2) | Hub, 4-2 | P3 | F | 0,04 s |
| `vox_linterna_blip` | Linterna | Asistente Linterna | Mundo oscuro | P3 | F | 0,03 s |
| `vox_boss_eco_filter` | Eco hablando a través de un jefe (su blip con filtro del jefe) | Jefes | Jefes | P3 | F | Mismo `vox_eco_blip` procesado por mundo |
| `vox_system_blip` | Textos del sistema y carteles del mundo | `memory_notice.gd`, carteles | Todos | P3 | E | Neutro o sin blip (recomendado: sin blip) |

## 9. Ambientes

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `amb_w1_lockscreen` | Pantalla de bloqueo: zumbido eléctrico bajo y notificaciones lejanas | 1-1 (`level_runner.gd` al cargar) | 1-1 | P2 | N | Bucle 30-60 s; muy bajo bajo la música |
| `amb_w1_tower` | Centro de notificaciones: más denso, ecos de «tin» lejanos | 1-2 | 1-2 | P2 | N | Bucle; densidad que sube por piso (opcional) |
| `amb_w1_dark_room` | Cuarto a oscuras de la azotea: casi silencio, servidor durmiendo | `dark_room.gd` | 1-2 azotea | P2 | E | Bucle; cambio al encender la luz |
| `amb_w1_settings` | Sala «Ajustes»: silencio limpio tras el No molestar | 1-3 inicio | 1-3 | P2 | N | Casi nada; el contraste es el chiste |
| `amb_w1_vibration` | Tramo «Vibración»: vibración de celular sobre mesa, lejana | 1-3 Tramo 2 | 1-3 | P3 | N | Si va, debe ir en compás con `rhythm_zone` |
| `amb_w1_alarm_tunnel` | Túnel de alarmas: zumbido que se acelera con el compás | `alarm_tunnel.gd` | 1-3 Tramo 4 | P2 | E | Bucle cuya velocidad sigue `tempo_changed` |
| `amb_w1_excepciones` | Sala secreta «Excepciones»: cálida, sin ruido | 1-3 secreto | 1-3 | P2 | N | Silencia la música del nivel (premio de calma) |
| `amb_boss1_lockscreen` | Arena de Alerta Mayor: relojes y notificaciones flotando | Jefe M1 | Jefe M1 | P2 | F | Tic-tac de relojes muy bajo |
| `amb_hub` | Hub sin señal: silencio con aire de cuarto y un zumbido mínimo | `hub_room.gd` | Hub | P2 | N | El silencio es diseño (`05-hub.md` §13.1): casi inaudible |
| `amb_debug_layer` | Capa del Debug: graves lentos y filtro sobre el mundo | `EventBus.debug_mode_changed` | Desde 1-2 | P2 | E | Más un efecto de bus (§11) que un archivo |
| `amb_low_sync_noise` | Estática ligera con Sync Rate bajo | `EventBus.low_sync_changed` | Todos | P2 | E | Respeta «Reducir efectos de Sync bajo» (lo apaga) |
| `amb_w2_feed` | Feed: rumor de videos superpuestos que avanzan | Mundo 2 | M2 | P2 | F | |
| `amb_w3_gallery` | Galería: brillo de cristal, flashes lejanos | Mundo 3 | M3 | P2 | F | |
| `amb_w4_chat_night` | Chat de madrugada: tecleo lejano, frío | Mundo 4 | M4 | P2 | F | Se apaga cerca de los amigos reales |
| `amb_w5_mall` | Centro comercial: megafonía ininteligible, carritos | Mundo 5 | M5 | P2 | F | Megafonía sin palabras (los personajes no tienen voz) |
| `amb_w6_cloud` | Nube: aire limpio, servidores, casi sin vida | Mundo 6 | M6 | P2 | F | |
| `amb_final_room` | Réplica del cuarto de Isak, solo la luz del celular | Jefe final | M6 | P2 | F | |

## 10. Música y stingers

| ID | Descripción | Dónde / cuándo | Mundo / nivel | Prio | Estado | Notas de diseño |
|---|---|---|---|---|---|---|
| `mus_hub` | Tema del hub: minimalista, pausas largas | `hub_room.gd` | Hub | P1 | N | Loop 2-3 min; mucho silencio; crece una voz por cada pieza del fondo recompuesta (por mundo vencido) |
| `mus_w1_level` | Tema del Mundo 1: chiptune con tonos de notificación | 1-1 (y base del mundo) | 1-1 | P1 | N | Loop 1,5-2 min; el ritmo coincide con el de los peligros (`mundo-1` §6.1) |
| `mus_w1_tower` | Variante del 1-2: más capas al subir de piso | 1-2 | 1-2 | P2 | N | Stems por piso (mezcla vertical) o reutilizar `mus_w1_level` |
| `mus_w1_dnd` | Variante del 1-3: tempo enlazado al metrónomo | 1-3 | 1-3 | P2 | N | Si la música sigue el compás de `rhythm_zone`, hace falta música adaptativa (o BPM fijo que coincida); ver pregunta 3 |
| `mus_calc_scene` | Escena de Calc («Resta») | `calc_intro.gd` | 1-2 / hub | P3 | E | 30-60 s; cálido, juguetón |
| `mus_memory` | Tema de los recuerdos (Abuelito, Mamá) | Lectura de recuerdos en Notas; entrega de recuerdo de jefe | Hub, jefes | P2 | N | Caja de música / piano de juguete; el tema más cálido del juego |
| `mus_eco_motif` | Leitmotiv de Eco | Presentación (1-1), jefes, final | Todos | P2 | N | 4-6 notas que se deforman por vuelta y por mundo |
| `mus_boss1` | Jefe Alerta Mayor | Jefe M1 | Jefe M1 | P1 | F | Loop; sube una capa por fase |
| `mus_w2_level` / `mus_boss2` | Feed: bucles de 15 s que se aceleran; jefe con fragmentos mezclados | M2 | M2 | P2 | F | |
| `mus_w3_level` / `mus_boss3` | Vitrina: alegre, de comercial, notas desafinadas cerca de peligros | M3 | M3 | P2 | F | Desafinado = pista de peligro (accesible si se acompaña de señal visual) |
| `mus_w4_level` / `mus_boss4` | Chat: melancólico, tecleo como ritmo; más silencioso cerca de amigos | M4 | M4 | P2 | F | |
| `mus_w5_level` / `mus_boss5` | Tienda: supermercado alegre y repetitivo, «voces de anuncio» | M5 | M5 | P2 | F | Voces como chops sin palabras |
| `mus_w6_level` | Nube: limpio, sin emoción, incorpora fragmentos de los temas recuperados | M6 | M6 | P2 | F | Stems de los mundos 1-5 |
| `mus_final_boss` | Isak Optimizado | Jefe final | M6 | P1 | F | Fase 3: la música se vacía para dejar que Isak «se detenga» |
| `mus_ending_disconnect` | Final «desconexión» (Eco se apaga) | `06-finales.md` | Final | P1 | F | Termina en silencio («hasta que el silencio gana») |
| `mus_ending_accept` | Final «aceptación», amanecer | `06-finales.md` | Final | P1 | F | Cálido; el parpadeo final, sin sonido |
| `mus_credits` | Créditos | Fin del juego | — | P2 | F | Puede ser el tema del hub completo |
| `mus_title` | Pantalla de título | Si se añade | — | P3 | F | |
| `stg_level_complete` | Nivel completado | `EventBus.level_completed` | Todos | P1 | E | 2-3 s |
| `stg_ability_obtained` | Habilidad o gesto obtenido | `EventBus.ability_obtained` | 1-1, 1-2, 1-3, gestos | P1 | E | 2 s; con ducking de la música |
| `stg_game_over` | Game over por vidas | `game_over_intro.gd` / `EventBus.rollback_applied` | Hub | P1 | E | 3 s; triste pero no punitivo |
| `stg_memory_obtained` | Mensaje de secreto obtenido | `EventBus.memory_obtained` | Secretos | P2 | E | 2 s; motivo de `mus_memory` |
| `stg_secret_found` | Entrar en una sala secreta | Paredes con glitch / zonas secretas | Secretos | P2 | N | 1,5 s |
| `stg_ally_met` | Aliado nuevo | `EventBus.ally_met` | Hub, 1-2 | P2 | E | 2 s |
| `stg_boss_defeated` | Jefe vencido y recuerdo entregado | Jefes | Jefes | P1 | F | 3-4 s; enlaza con `mus_memory` |

## 11. SFX de mundos futuros (2-6) y del final

Todos **F** (sin construir). Lista orientativa para no olvidar familias; se detallará al diseñar cada mundo.

| ID | Descripción | Mundo | Prio | Notas |
|---|---|---|---|---|
| `sfx_gesture_ground_pound` | Golpe al suelo (Mantener presionado) | M2 | P1 | Impacto + onda |
| `sfx_gesture_pinch` / `sfx_gesture_unpinch` | Pellizcar: comprimirse y recuperar el tamaño | M3 | P1 | |
| `sfx_gesture_shake` | Agitar: onda que aturde | M4 | P1 | |
| `sfx_combo_embestida` / `sfx_combo_filo` / `sfx_combo_sismo` | Combinaciones | M5 | P1 | Mezcla de las familias de cada gesto |
| `sfx_w2_autoplay_start` | Video en autoplay que arranca | M2 | P1 | Aviso del ataque |
| `sfx_w2_card_crack` / `sfx_w2_card_break` | Tarjeta frágil | M2 | P1 | |
| `sfx_w2_story_timer` | Historia: contador rápido | M2 | P1 | Accesibilidad como el recordatorio |
| `sfx_w2_clone_spawn` | «Un video más» se multiplica | M2 | P2 | |
| `sfx_w2_commenter_spit` | Comentarista escupe texto | M2 | P2 | |
| `sfx_w2_scroll_speed` | Cambio / inversión del scroll | M2 | P2 | |
| `sfx_w2_clock_skip` | El reloj del HUD salta horas | M2 | P2 | Inquietante, sutil |
| `sfx_w3_like_collect` / `sfx_w3_like_stolen` | Likes | M3 | P1 | |
| `sfx_w3_like_platform` | Plataforma de likes que aparece / desaparece | M3 | P1 | |
| `sfx_w3_flash_charge` / `sfx_w3_flash` | Influencer bot | M3 | P1 | Aviso previo obligatorio (ciega la pantalla) |
| `sfx_w3_mirror_bounce` | Rebote del pulso en espejo | M3 | P2 | |
| `sfx_w3_filter_shimmer` | Zona con filtro | M3 | P2 | |
| `sfx_w4_typing` | «Escribiendo…» (aviso de plataforma) | M4 | P1 | Accesibilidad: anticipa el salto |
| `sfx_w4_bubble_pop_in` | Burbuja-plataforma que aparece | M4 | P1 | |
| `sfx_w4_seen_freeze` / `sfx_w4_seen_break` | Zona «Visto»: congelar / romper | M4 | P1 | |
| `sfx_w4_troll_shot` | Proyectil de texto | M4 | P1 | |
| `sfx_w4_ghost_vanish` / `sfx_w4_ghost_appear` | Fantasma | M4 | P1 | Aparición posicional (detrás de Isak) |
| `sfx_w4_autocorrect` | Autocorrector reescribe | M4 | P2 | Cursor que parpadea antes |
| `sfx_w4_sticker_explode` | Sticker | M4 | P2 | |
| `sfx_w5_temptation_pull` | Tirón de la tentación | M5 | P1 | Bucle |
| `sfx_w5_box_open_good` / `sfx_w5_box_open_bad` | Caja sorpresa | M5 | P1 | |
| `sfx_w5_subscription_attach` / `sfx_w5_subscription_drain` / `sfx_w5_subscription_cancel` | Suscripción | M5 | P1 | Drenaje: tic por punto |
| `sfx_w5_pay` | Pagar un atajo | M5 | P1 | Caja registradora «trucada» frente a la honesta de Calc |
| `sfx_w5_countdown` | «¡Solo por hoy!» | M5 | P2 | |
| `sfx_w6_node_pulse` / `sfx_w6_node_disconnect` | Nodo de servidor | M6 | P1 | |
| `sfx_w6_memory_photo_on` | Foto de la galería que se enciende | M6 | P2 | Motivo de `mus_memory` |
| `sfx_w6_protocol_ready` | Protocolo de Desconexión listo | M6 | P1 | |
| `sfx_w6_copy_silent` | Copias optimizadas: **sin sonido a propósito** | M6 | — | Diseño: «no tiene señales sonoras»; necesita compensación visual (§12) |
| `sfx_final_cable_cut` | Cortar un cable de la copia | Jefe final | P1 | 4 variantes crecientes |
| `sfx_final_choice` | Momento de decisión (golpe o mano) | Jefe final | P1 | Casi silencio |
| `sfx_eco_fade_out` | Eco se apaga («Isak. Isak.») | Final desconexión | P1 | Blips de Eco cada vez más rápidos hasta el silencio |
| `sfx_ending_notification` | Notificación del celular en el cuarto real | Final aceptación | P2 | Un único tono, el más «real» del juego |

## 12. Accesibilidad

Hoy los ajustes de accesibilidad (`data/pause_menu.json`, `scripts/autoload/game_settings.gd`) son «Reducir efectos de Sync bajo» y «Contorno del Debug de alto contraste»; no hay ningún ajuste de audio porque no hay audio. Se propone:

1. **Volumen por bus** (General, Música, Efectos, Ambiente, Voces/blips, UI) en Ajustes, guardados en `settings.cfg` como los demás.
2. **«Señales sonoras de ritmo: Sí / No»** (o «Ayudas sonoras»): activa los equivalentes sonoros de lo que hoy es **solo visual**: `sfx_metronome_tick`, `sfx_metronome_speedup`, `sfx_blink_warn` (1-3 Tramo 2), `sfx_reminder_tick` (1-2), `sfx_banner_warn`, `sfx_alarm_bell_warn` (1-3 Tramo 4), y en el futuro `sfx_w2_story_timer` y `sfx_w4_typing`. El diseño del 1-3 se leyó en visual, así que deben ser **opcionales** y no sustituir el parpadeo. Recomendación: activadas por defecto en los avisos (warn) y opcional el tic de cada compás.
3. **«Reducir efectos de Sync bajo»** también apaga la distorsión de la música y `amb_low_sync_noise`, y deja `sfx_low_sync_alarm` en un solo aviso.
4. **Blips de texto: Sí / No.**
5. **Lo inverso (sordos o sin sonido):** ningún sonido debe ser la única pista. Casos a vigilar: `sfx_glitch_wall_hum` (ya hay glitch visual), las copias del Mundo 3 que se distinguen por sonido (`sfx_boss1_clones`, opcional) y las «notas desafinadas» del Mundo 3 (necesitan su señal visual). Las Copias silenciosas del Mundo 6 son el caso contrario por diseño y ya se leen visualmente.
6. **Sin agudos ni picos fuertes:** limitador en el bus Master; nada por encima de ~8 kHz con energía alta en sonidos repetidos.

## 13. Sistema de audio: qué hay hoy y qué falta

**Actualización (2026-10-20):** lo que sigue describe el estado ANTERIOR a la integración; el sistema ya existe (ver «Integración del sistema de audio (2026-10-20)», al final).

**Antes no existía nada de audio:** `assets/audio/` solo tenía `.gitkeep`; no hay `default_bus_layout.tres`, ni `AudioStreamPlayer` en escenas o scripts, ni `AudioServer`, ni autoload de audio (los autoloads son `EventBus`, `GameState` y `DebugMode`). `rhythm_zone.gd` y `data/eco_text_box.json` dicen explícitamente «solo visual / sin audio», y `event_bus.gd` deja «la música deformada» como pendiente.

**Lo que sí está listo:** casi todos los momentos ya emiten una señal en `EventBus` (≈50 señales: `pulse_fired`, `laser_fired`, `laser_denied`, `dash_started`, `dash_denied`, `debug_mode_changed`, `debug_activation_progress_changed`, `world_time_scale_changed`, `player_died`, `life_lost`, `player_respawned`, `checkpoint_activated`, `level_completed`, `ability_obtained`, `recharge_collected`, `charger_used`, `power_bank_no_room`, `extra_life_collected`, `memory_obtained`, `memory_read`, `game_saved`, `upgrade_purchased`, `trash_recovered`, `rollback_applied`, `eco_line_started`, `help_prompt_shown`, `help_learned`, `ally_met`, `ally_teleported`, `pause_menu_opened/closed`, `controls_changed`, `low_sync_changed`, `hide_changed`, `hide_ended`, `enemy_defeated`, `pulse_energy_returned`…), y los objetos con ritmo tienen señales locales (`rhythm_zone.beat/tempo_changed/started`, `blink_platform.warning_started/switched_on/switched_off`, `reminder_platform.countdown_started/snoozed/warning_started/fell/respawned`) y los enemigos `state_changed`, `stunned`, `popped`, `damaged`, `hit_player`, `deflected`. Esto permite conectar casi todo el audio **sin tocar la lógica del juego**.

**Propuesta de arquitectura** (a validar con la skill `godot-isak-fix`):

- **Autoload `AudioManager`** (`scripts/autoload/audio_manager.gd`) que se suscribe a `EventBus` y reproduce por ID desde un catálogo en datos (`data/audio.json`: ID → archivo(s), bus, volumen, variantes, tono aleatorio, tiempo real o del mundo, cooldown anti-spam), siguiendo la convención del proyecto de valores en `data/*.json` con `_notes`.
- **Sonidos posicionales** (enemigos, banners, campanas, paredes con glitch): un `AudioStreamPlayer2D` en la escena del objeto, alimentado por el mismo catálogo, o una llamada `AudioManager.play_at(id, position)` con un pool de reproductores.
- **Música:** dos reproductores con fundido cruzado; stems opcionales para el 1-2 (pisos) y el Mundo 6; ducking con stingers y líneas importantes de Eco.
- **Buses propuestos** (`default_bus_layout.tres`):

| Bus | Envía a | Contenido | Efectos |
|---|---|---|---|
| `Master` | — | Todo | Limitador |
| `Music` | Master | `mus_*`, `stg_*` | Paso bajo en pausa; distorsión/bitcrush con Sync bajo; ducking |
| `World` | Master | SFX del mundo (§1-4, §11) | Tono/velocidad ×0,5 o paso bajo con el Debug (`world_time_scale_changed`) |
| `Ambience` | Master | `amb_*` | Mismo tratamiento del Debug |
| `Voice` | Master | `vox_*`, `sfx_eco_*` | Tiempo real (no le afecta el Debug) |
| `UI` | Master | `ui_*`, hub y menús | Tiempo real; sigue sonando con el árbol en pausa |

- **Ajustes:** sección `audio` en `settings.cfg` (volumen por bus + los interruptores de §12), mostrada en el menú de pausa.
- **Formato:** `.ogg` para música y ambientes (loop), `.wav` cortos para SFX; 44,1 kHz; normalizar a una sonoridad común.

## 14. Resumen de conteos

Una fila de tabla = una entrada (las filas con «/» agrupan 2-3 variantes del mismo sonido y cuentan como una).

| Categoría | Total | P1 | P2 | P3 | Futuro (F) |
|---|---|---|---|---|---|
| §1 Isak: movimiento y habilidades | 23 | 11 | 8 | 4 | 0 |
| §2 Daño, vidas y estados | 8 | 6 | 0 | 2 | 0 |
| §3 Objetos Mundo 1 | 40 | 17 | 20 | 3 | 0 |
| §4 Enemigos M1 y jefe | 21 | 14 | 7 | 0 | 7 |
| §5 Eco y ayudas | 9 | 4 | 4 | 1 | 0 |
| §6 Hub y aliados | 21 | 8 | 9 | 4 | 4 |
| §7 UI y menús | 17 | 6 | 7 | 4 | 1 |
| §8 Voces y blips | 7 | 0 | 3 | 4 | 3 |
| §9 Ambientes | 17 | 0 | 16 | 1 | 7 |
| §10 Música y stingers | 25 | 10 | 13 | 2 | 12 |
| §11 Mundos futuros y final | 36 | 24 | 11 | 0 | 36 |
| **Total** | **224** | **100** | **98** | **25** | **70** |

(§11 incluye `sfx_w6_copy_silent`, que es una nota de diseño sin prioridad; por eso P1+P2+P3 suma 223.) Sin contar lo futuro: **154 entradas** para el Mundo 1, el hub y los sistemas.

**Mínimo para que el Mundo 1 y el hub dejen de ser mudos:** las 67 P1 con estado E o N: movimiento básico, pulso/láser/dash/Debug, daño/vidas, recogibles, objetos clave, enemigos con aviso, Eco, guardado, compras, UI básica, `mus_hub`, `mus_w1_level` y los stingers de nivel, habilidad y game over.

## 15. Preguntas abiertas para el usuario

1. **Origen del audio:** ¿compuesto/grabado a mano, librerías (CC0) o generado con IA? Afecta a coste, licencias y coherencia. Recomendación: SFX con un sintetizador chiptune (p. ej. sfxr/jsfxr) para que todo comparta timbre; música a encargar o componer aparte. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 1.
2. **Estilo musical exacto:** ¿chiptune «puro» (limitado a canales tipo consola) o chiptune con capas cálidas (piano, pads) para el hub y los recuerdos? Recomendación: chiptune en los mundos y capas cálidas solo en hub/recuerdos. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 2.
3. **Ritmo del 1-3:** ¿la música del 1-3 debe ir **en compás** con el metrónomo (música adaptativa, más trabajo) o basta con el tic opcional de `rhythm_zone` sobre una música libre? Recomendación: tic opcional ahora; música adaptativa solo si sobra tiempo. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 3.
4. **Señales sonoras de accesibilidad:** ¿activadas por defecto (solo los avisos «warn») o desactivadas? Recomendación: avisos activados, tic de compás desactivado. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 4.
5. **Blips de texto:** ¿se quieren (opcionales) o el texto queda totalmente mudo, como hasta ahora? Recomendación: sí, opcionales y sutiles; nunca en los recuerdos. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 5.
6. **Hub:** ¿música minimalista con pausas largas (docs) o solo ambiente/silencio? Recomendación: música con mucho silencio que gana una voz por mundo vencido. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 6.
7. **Eco por vuelta:** ¿su blip y su motivo cambian en Caché / Kernel / Raíz? Depende de la decisión abierta «tono de Eco por vuelta». **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 5.
8. **Pasos de Isak:** ¿se quieren pasos (pueden cansar) o solo salto/aterrizaje? Recomendación: pasos muy suaves con opción de volumen de Efectos. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 7.
9. **Pantalla de título y créditos:** hoy no existen; ¿se planean? (afecta a `mus_title`, `mus_credits`, `ui_title_start`).
10. **Orden de trabajo:** ¿primero el sistema (`AudioManager`, buses, ajustes de volumen) con sonidos provisionales, y después los definitivos? Recomendación: sí, con 15-20 sonidos provisionales P1 para probar la mezcla. **Resuelta (2026-10-20):** ver «Decisiones (2026-10-20)», punto 9.

## Decisiones (2026-10-20)

1. **Origen del audio:** lo crea a mano un amigo del usuario. No se usan librerías CC0 ni IA. Formatos sugeridos: `.ogg` para música y ambientes; `.wav` u `.ogg` para SFX. Los nombres de archivo son los IDs de la tabla.
2. **Estilo:** chiptune como base. Las capas más cálidas (pads y cuerdas suaves) solo en Recuerdos, en el hub (ambiente) y en los finales.
3. **Música del 1-3 y metrónomo:** la música **no** va sincronizada al compás. El metrónomo tiene su propio tic sonoro, independiente, para que la lectura del ritmo sea fiable y se eviten desfases. La sincronización musical queda como posible extra para el jefe Alerta Mayor.
4. **Señales sonoras de accesibilidad** (metrónomo, plataformas): vienen **activadas por defecto**.
5. **Blips de texto:** sí. El blip (motivo) de Eco cambia entre Caché, Kernel y Raíz. La UI nunca dice «vuelta», «Easy», «Normal» ni «Hard».
6. **Hub:** solo ambiente, sin música.
7. **Pasos de Isak:** se oyen, con variantes por superficie si procede.
8. **Créditos:** sí, al final de los finales. **Pantalla de título:** sin decidir (sigue abierta en la pregunta 9).
9. **Sistema de audio:** aprobado montar `AudioManager`, `data/audio.json` y los seis buses, con 15-20 sonidos provisionales. Se hará cuando termine el paso 10 del 1-3.

## Integración del sistema de audio (2026-10-20)

Montado según la propuesta de §13 y las decisiones de arriba. **Ningún script de juego cambió de lógica**: el audio escucha señales que ya existían (la única señal nueva es `PauseMenu.ui_feedback`, que solo informa de mover / aceptar / volver).

### Piezas

| Pieza | Dónde | Qué hace |
|---|---|---|
| Autoload `AudioManager` | `scripts/autoload/audio_manager.gd` (registrado en `project.godot`, tras `DebugMode`) | Lee el catálogo, reproduce por ID (`AudioManager.play(&"sfx_isak_jump")`, `play(id, posición)` para sonido posicional) con un grupo de reproductores, bucles (`play_loop` / `stop_loop`), variantes sin repetir la anterior, tono aleatorio, enfriamiento anti-saturación y tono más grave con el Debug (`time: world`). Conecta las señales del catálogo. |
| Catálogo | `data/audio.json` | **Fuente única**: ID → archivos, bus, volumen, variantes, bucle, tiempo, señal de accesibilidad; y qué señal dispara cada sonido. Sus `_notes` explican cada campo. |
| Buses | `default_bus_layout.tres` (raíz del proyecto; Godot lo carga solo) | `Master` (con limitador) y `Music`, `World`, `Ambience`, `Voice`, `UI`, que envían a `Master`. |
| Ajustes | `GameSettings` (`scripts/autoload/game_settings.gd`), sección `audio` de `settings.cfg`; datos en `data/settings.json` (`audio`) | Volumen de cada bus (0-100 % en pasos de 10 %, 0 % = silencio), guardado al instante y aplicado al `AudioServer`. «Señales sonoras de ritmo: Sí / No» (`rhythm_sound_cues`, sección `accessibility`, **Sí por defecto**). |
| Menú | Pausa > Ajustes (`scripts/ui/pause_menu.gd`, textos en `data/pause_menu.json`) | «Señales sonoras de ritmo» junto a los demás ajustes de accesibilidad y la subpágina **«Sonido»**: «General / Música / Efectos / Ambiente / Voces / Interfaz: 80 %» (izquierda/derecha bajan o suben; Intro sube y de 100 % pasa a 0 %). |
| Sonidos provisionales | `assets/audio/*.wav`, generados por `tools/gen_audio_placeholders.py` (numpy + wave, síntesis simple, sin IA) | 24 IDs P1 (27 archivos con las 4 variantes de pasos). |
| Validador | `tools/validate_audio.py` (en `tools/run_tests.sh`; `--missing` lista los IDs sin archivo) | Buses, campos, señales de `EventBus`, clases y señales de los nodos, sonidos referenciados. Pruebas: `tests/test_audio_catalog.py` (Python) y `tests/test_audio_manager.gd` (GUT). |

### Cómo se conecta (sin tocar la lógica)

- **`event_bus`:** señal de `EventBus` → sonido (pulso, láser, dash, Debug, muerte, vidas, punto de sincronización, recogidas, recuerdos, guardado, compras, pausa…). `when` filtra por argumentos (p. ej. `debug_mode_changed` con `true` → `sfx_debug_on`).
- **`nodes`:** al entrar en el árbol un nodo de la clase indicada (o de una que herede de ella: `AlarmTunnel` hereda el tic de `RhythmZone`), se conecta su señal: salto y aterrizaje (`Isak.state_changed`), daño (`Isak.hurt`), punto de atención, chip de habilidad, terminal, interruptor «No molestar», metrónomo (`RhythmZone.beat`), plataformas que parpadean (`BlinkPlatform.warning_started`), enemigos y campanas (posicionales) y la UI del menú de pausa.
- **`ambience`:** bucle mientras un nodo de la clase está en el árbol. El **hub lleva solo ambiente** (`amb_hub` con `HubRoom`; sin música, decisión 6).
- **`steps`:** pasos de Isak en los cuadros de contacto de `walk` y `run` (solo en el suelo; 4 variantes).
- **`text_blips`:** un blip cada 2 caracteres escritos (sin espacios) en los cuadros de texto (`EcoTextBox`): Eco, Notas y Calc tienen el suyo; **el de Eco cambia con el acceso** (`vox_eco_blip_cache` / `_kernel` / `_raiz`, según `GameState.lap`; la UI nunca dice vuelta, Easy, Normal ni Hard). Los recuerdos no llevan blip.
- **Señales de accesibilidad** (`"cue": true`): `sfx_metronome_tick`, `sfx_metronome_speedup` y `sfx_blink_warn`. El tic del metrónomo es **propio e independiente de la música** (decisión 3) y suena por `World` en tiempo del mundo. Con «Señales sonoras de ritmo: No» no suenan; el parpadeo visual no cambia.

### Cómo sustituir un sonido provisional por el definitivo

1. **Nombre = ID** del catálogo: `sfx_isak_jump.wav` u `sfx_isak_jump.ogg` en `assets/audio/`. Las variantes llevan sufijo (`sfx_isak_step_1` … `_4`) y se listan en `files` de su entrada.
2. **Formatos:** `.ogg` (Vorbis) para música y ambientes en bucle; `.wav` (16 bits) u `.ogg` para efectos cortos; 44,1 kHz, mono salvo música. Si en `files` no se pone extensión, el `AudioManager` prueba en orden `ogg`, `wav`, `mp3` (`extensions`): **basta con dejar un `.ogg` con el mismo nombre y borrar el `.wav` provisional**, sin tocar el JSON.
3. Abrir el proyecto en Godot (o `$GODOT --headless --path . --import`) para que importe el archivo (crea el `.import`, que se sube junto al audio). Los bucles los gestiona el `AudioManager` (vuelve a empezar al terminar): no hace falta marcar «loop» al importar.
4. **`data/audio.json` es la fuente**: ahí se ajusta el volumen (`volume_db`), el bus, la variación de tono, el enfriamiento o se añaden IDs nuevos (con su conexión en `event_bus`, `nodes`, `ambience`…). Después: `python3 tools/validate_audio.py --missing` (dice qué IDs siguen sin archivo).
5. **Archivo ausente = silencio**: una entrada sin archivo no suena ni da error. El catálogo ya trae huecos con su conexión hecha (p. ej. `sfx_isak_death`, `sfx_debug_on`, `sfx_banner_warn`, `stg_level_complete`): basta con añadir el archivo.
6. No volver a ejecutar `tools/gen_audio_placeholders.py` sobre los definitivos (reescribe los `.wav` con el mismo nombre); `--only <id>` regenera solo uno.

### Pendiente

- Música (`mus_*`) y la mayoría de los stingers: sin archivo; el hub no lleva música.
- Efectos de bus del §13 (paso bajo en pausa, bitcrush con Sync bajo, ducking): no montados; el Debug solo baja el tono de los sonidos `time: world` (hasta ×0,75).
- Blips: sin ajuste «Blips de texto: Sí / No» (§12.4); hoy se bajan con el volumen de Voces.
