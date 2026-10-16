# 13. Hub: la Pantalla de Inicio

Origen: sección 13 del documento original (`docs/original/diseno.md`).

El hub es el único lugar del celular al que Eco no llega. Es una zona sin señal, donde no hay notificaciones y nadie le pide nada a Isak. Ahí descansa, mejora sus habilidades, habla con sus aliados y elige a qué mundo ir.

## 13.1 Concepto

- **Zona sin señal:** un icono de Modo Avión, siempre encendido, marca que Eco no puede entrar. Explica por qué es un lugar seguro. **[Reemplazado en parte el 2026-10-15 (3)]:** Eco entra y sale con Isak como compañero (`propuesta-asistentes-y-vidas.md`). Cómo encaja con la zona sin señal sigue abierto (recomendación: Eco entra sin cobertura, con la esfera atenuada, y no guarda ni compra por Isak; el Modo Avión se mantiene).
- **Primera llegada:** el juego empieza directamente en el nivel 1-1, sin hub. **Cambio aprobado el 2026-10-15** (`propuesta-hub-y-guardado.md`, pregunta 1): el hub aparece ya al terminar el 1-1, como un hub mínimo al que se vuelve tras cada nivel del Mundo 1. ~~Con Calc dormida (13.3); la llegada narrativa sigue siendo después de vencer a Alerta Mayor: allí Calc despierta, Isak la conoce~~ **[Reemplazado el 2026-10-15 (3)]:** en la primera llegada Eco presenta a **Notas** (la consola de guardado), que explica cómo guardar. Calc está apagada hasta que Isak la encuentra al final del 1-2. Tras vencer a Alerta Mayor se sigue iluminando la pieza cian (13.4).
- **Los iconos son puertas:** cada carpeta de la pantalla es la entrada a un mundo. Las carpetas de los mundos completados se pueden rejugar. Desde la carpeta se elige también el subnivel (ver 13.6).
- **Tono:** el contraste con el resto del juego. El hub es silencioso y tranquilo, con una música minimalista con pausas largas. El silencio es parte del diseño, y es lo que Eco no soporta.

## 13.2 Distribución

El hub se organiza en páginas, como una pantalla de inicio de celular. Isak camina hasta el borde y la pantalla se desliza. Un indicador de páginas abajo muestra dónde está.

| Zona | Contenido |
|---|---|
| **Página 1** | Carpetas de los mundos 1, 2 y 3. |
| **Página 2** | Carpetas de los mundos 4 y 5. |
| **Página 3** | La Nube, con un candado. Solo se abre con los cinco recuerdos recuperados. |
| **Dock (barra inferior)** | Los aliados. Es el centro del hub, siempre visible. Es también el **suelo** de la sala: Isak camina sobre él y los aliados están de pie en él (aprobado el 2026-10-15). |
| **Esquina: Ajustes** | Opciones de accesibilidad, como reducir el ruido visual cuando el Sync Rate es bajo. Los ajustes viven en el menú de pausa (acción `pause`, también en los niveles); en el hub, el icono de la esquina lo abre. Se guardan al instante en `user://settings.cfg`, aparte del guardado manual (aprobado el 2026-10-15). Implementado el 2026-10-16: icono de engranaje en la esquina del HUD, delante del Modo Avión; hoy con «Ayudas de Eco: Mostrar / Ocultar». |

Selección de zona y subnivel, compra de mejoras y guardado: ver 13.6.

**Hub del Mundo 1 (aprobado el 2026-10-15):** una sola página, como sala 2D caminable de 20x11 tiles con paneles de menú en cada estación (copia local, carpetas, Calc y ajustes). **[2026-10-15 (3)]:** la copia local pasa a ser **Notas**, Calc está apagada hasta el final del 1-2 y la Papelera ocupa el hueco de la columna 10 del dock (`propuesta-asistentes-y-vidas.md` §8). **[2026-10-16]:** en la columna 16 del dock hay un **cargador de energía**, el mismo objeto `charger` de los niveles (50 de energía, reutilizable, 20 s de enfriamiento; se activa al tocarlo); no se guarda y se reinicia en cada visita. Mapa y detalle en `propuesta-hub-y-guardado.md` §2 y §3. Las páginas 2 y 3 llegan con los mundos 4 a 6.

## 13.3 Los aliados en el hub

| Aliado | Cuándo llega | Función en el hub |
|---|---|---|
| **Calc** | ~~Después del Mundo 1 (dormida desde el 1-1)~~ **Al final del 1-2, tras obtener el Debug** (2026-10-15 (3)) | Mejoras permanentes a cambio de puntos de atención, como más energía de Debug o más Sync Rate. Precios fijos y sin sorpresas, en contraste con La Tienda. **Cambio aprobado el 2026-10-15:** en el hub del Mundo 1 Calc está **dormida** (icono gris en el dock): su teclado vende las mejoras a precio fijo, pero no habla (solo texto de interfaz). Despierta tras vencer a Alerta Mayor, se presenta y desde entonces explica las mecánicas. **[Reemplazado el 2026-10-15 (3)]:** no hay tienda hasta conocer a Calc al final del 1-2; hasta entonces su hueco del dock está apagado e inactivo (sin panel). La implementación actual (Calc dormida vende) se cambiará (paso 10 de `propuesta-asistentes-y-vidas.md`). |
| **Notas** | ~~Después del Mundo 2~~ **La primera vez que Isak entra al hub** (2026-10-15 (3)) | **Consola de guardado** (la antigua «copia local») y **álbum** de enemigos y objetos con fichas que se desbloquean con la ayuda Q (las no vistas, silueta «???»), organizado en **carpetas por mundo** (2026-10-16: Mundo 1 a Mundo 6; las de mundos aún no alcanzados, cerradas con candado y «???»; dentro, Enemigos y Objetos), sin opción para borrar lo aprendido. Eco la presenta y Notas explica cómo guardar. Más adelante también bitácora: recuerdos, diálogos, pistas y coleccionables. |
| **Linterna** | ~~Después del Mundo 4~~ **Al entrar en el X-1 de un mundo oscuro** (mundo por decidir; 2026-10-15 (3)) | ~~Indica cuántos secretos tiene cada nivel y da pistas sobre cómo encontrarlos.~~ **[Reemplazado]:** objeto que se activa solo en zonas oscuras. En el hub, su hueco se enciende al conocerla. |
| **Papelera** | ~~Después del Mundo 4~~ **La primera vez que hace falta** (primer game over o rollback; 2026-10-15 (3)) | ~~Guarda parte de los puntos de atención que Isak pierde al morir, para recuperarlos al volver.~~ **[Reemplazado]:** en un rollback (game over por vidas o jefe final) Eco «desecha» lo guardado (habilidades, power banks, puntos de atención y mejoras) y aparece en la Papelera, que parpadea y se mueve. Al acercarse se recupera todo. Mientras tiene contenido, las carpetas avisan «Recupera tus archivos de la papelera». **Implementado el 2026-10-16** (`Papelera`, columna 10 del dock; paso 12 de `propuesta-asistentes-y-vidas.md`). |

## 13.4 Cómo cambia el hub durante el juego

El fondo de pantalla del hub es una foto rota en cinco piezas, una por cada fragmento. Al principio está en gris y desordenada, y con cada jefe vencido una pieza se recompone y se ilumina con el color del Debug de su mundo.

| Hito | Cambio en el hub |
|---|---|
| **Primera llegada (Mundo 1)** | Hub apagado y casi vacío. Se ilumina una pieza del fondo, en cian. |
| **Mundo 2 completado** | Segunda pieza, en ámbar. ~~Llega Notas~~ (Notas llega en la primera visita, 2026-10-15 (3)) y el hub tiene más vida. |
| **Mundo 3 completado** | Tercera pieza, en verde ácido. |
| **Mundo 4 completado** | Cuarta pieza, en coral. ~~Llegan Linterna y Papelera~~ (2026-10-15 (3): Linterna llega en el X-1 del mundo oscuro y Papelera en su primer uso) y el hub se llena de voces. |
| **Mundo 5 completado** | Quinta pieza, en blanco. El fondo está completo, y es la foto que Isak tenía antes de entrar al celular. |
| **La Nube abierta** | El silencio se rompe: Eco intenta entrar, y empiezan a aparecer notificaciones en el borde de la pantalla. |

## 13.5 Detalles de ambientación

- **Idle en el hub:** si Isak se queda quieto, saca su terminal holográfica y los aliados empiezan escenas breves entre ellos, con humor. Es una recompensa por detenerse.
- **Pasar de nivel:** entrar a una carpeta es entrar al mundo. Al terminar un nivel, Isak vuelve al hub con una breve animación de píxeles que lo deposita en la pantalla.
- **Contraste de humor:** el humor del hub es cálido, de equipo y sin sátira. Es distinto al de los mundos, que se ríen de Eco y de lo que ofrece.

## 13.6 Selección de nivel, mejoras y guardado (decisión del 2026-10-15)

No viene del documento original. Decisión del usuario; detalle y dudas abiertas en `preguntas.md` («Decisiones del 2026-10-15: tres vueltas, hub y guardado»).

- **Selección de nivel:** desde el hub se elige la zona (1 a 6) y el subnivel (p. ej. 1-1, 1-2, 1-3), con las carpetas. Como el hub aparece desde el final del 1-1 (13.1, cambio del 2026-10-15), la selección existe ya en el Mundo 1, limitada a los subniveles desbloqueados. Solo se juegan los subniveles de la vuelta actual: los de vueltas anteriores no se rejuegan (aprobado el 2026-10-15).
- **Puntos de atención:** al rejugar un nivel no se restauran los ya capturados. Solo vuelven con un rollback: al final de Easy lo hace el jefe final al escapar y al final de Normal lo hace Isak, engañado por el jefe. Hard termina el juego (final real).
- **Mejoras:** se compran en el hub, con Calc (13.3).
- **Guardado:** manual y solo en el hub, en la estación «copia local» (**Notas** desde el 2026-10-15 (3)). Si se cierra el juego sin haber guardado en el hub, el progreso no se salva. Al cerrar con cambios sin guardar sale un aviso; dentro de un nivel, sin opción de guardar. Se conserva la copia anterior como `save.json.bak`. Esquema y detalle en `propuesta-hub-y-guardado.md` §4.
- **Tutorial de guardado (cambio aprobado el 2026-10-15; [REEMPLAZADO el 2026-10-15 (3)]: Eco presenta a Notas en el primer hub y Notas explica cómo guardar; ya no hay línea de Eco en la terminal ni primer hub guiado, `propuesta-asistentes-y-vidas.md` §2.2):** ya no depende de un punto de guardado en el nivel: **no hay guardado dentro de los niveles**. Se enseña con (B) una línea importante de Eco junto a la terminal de salida del 1-1 («allí no tengo cobertura») y (C) un primer hub guiado, con texto de interfaz sin el nombre de Eco, que señala la copia local. Detalle en `propuesta-hub-y-guardado.md` §5.
- **Estado de la implementación (2026-10-15):** el guardado ya es manual (`GameState.save_game()`; capturar puntos, comprar o completar niveles solo marca «sin guardar») y el aviso al salir funciona. El hub real está en el flujo del juego (pasos 8 y 9 de `propuesta-hub-y-guardado.md`): al terminar un nivel Isak llega por el vórtice al hub, guarda en la copia local, compra mejoras a Calc dormida (sin voz ni diálogo, solo texto de interfaz; se cambiará: Calc apagada hasta el final del 1-2, 2026-10-15 (3)) y entra a los subniveles desde la carpeta. La pantalla provisional del hub se retiró. **Actualización 2026-10-16 (pasos 8-10 de `propuesta-asistentes-y-vidas.md`):** la copia local es ahora **Notas** (guardar, álbum de fichas y apodo), apagada hasta que Eco la presenta la primera vez que Isak entra al hub; **Calc está apagada** (sin prompt ni tienda) hasta conocerla al final del 1-2 (encuentro aún sin implementar; en depuración, `-- --meet-ally=calc`). El hueco apagado de Notas de la columna 10 se retiró: desde el 2026-10-16 lo ocupa la Papelera.
- **Diseño del hub:** aprobado el 2026-10-15 (`propuesta-hub-y-guardado.md`). La paleta del hub (hex del «gris azulado apagado») sigue siendo una decisión abierta del usuario.
- **Vidas y game over (decisión del 2026-10-15 (3); implementado el 2026-10-16, pasos 11 y 12 de `propuesta-asistentes-y-vidas.md`):** vidas desde la primera llegada al hub (antes, muertes ilimitadas), iconos de mini teléfono en el HUD de los niveles, game over con `GameState.apply_rollback` (la misma función servirá al rollback del jefe final), llegada al hub con las líneas de Eco (`data/game_over.json`), la Papelera de la columna 10 (dormida, parpadeando con contenido, vacía) que se recupera al acercarse, carpetas bloqueadas («Recupera tus archivos de la papelera») y Notas sin guardar mientras tenga contenido. Nunca se pierden Eco, Notas, Calc, el apodo, las ayudas aprendidas ni el pulso. Decisión original: 3 **vidas (intentos)**, distintas del **Sync Rate (salud)**. Se reponen al entrar a un nivel desde una carpeta; los puntos de sincronización no las reponen. Al perderlas todas, Eco aplica un rollback a la **última copia guardada en Notas**: lo obtenido después se pierde y lo guardado aparece en la Papelera del hub, donde se recupera. Detalle en `propuesta-asistentes-y-vidas.md` §5.
