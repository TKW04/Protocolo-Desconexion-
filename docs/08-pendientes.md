# 16. Pendientes

Origen: sección 16 del documento original (`docs/original/diseno.md`).

- Familia de Isak, que aparece en los recuerdos del Mundo 2.
- Revisar y ajustar los dos finales.
- ~~Confirmar la resolución base (640x360) y el tamaño del sprite tras las primeras pruebas.~~ Resuelto el 2026-10-14: 1280x720, Isak a 96 px visibles en canvas de 128x128, tiles de 64x64 (ver `preguntas.md`, C6).
- Revisar las paletas por mundo.
- V15 (responder o no en el 4-3): aplazado hasta el Mundo 4
- Frases "finales por desarrollar" en §4 y §11.7: se mantienen; se revisan durante el desarrollo
- Tres vueltas (Easy, Normal, Hard; decisión del 2026-10-15, ver `preguntas.md`; Easy: el jefe escapa y hace el rollback; Normal: engaña a Isak para que lo haga él; Hard: final real): primero diseñar y producir los 18 niveles (6 mundos × 3 subniveles) en Easy; después, Normal y Hard (contenido nuevo por vuelta: rutas, enemigos, aspecto de los mapas)
- Tres vueltas, dudas abiertas: mejoras por vuelta (se definen vuelta por vuelta), dificultad (sugerencia del equipo pendiente de aprobar: curva «X de 5» + perfil por vuelta), diseño del rollback por mapa, narrativa de cada vuelta y avisos de los puntos débiles nuevos
- ~~Guardado manual en el hub (decisión del 2026-10-15): definir la acción de guardar y migrar el guardado automático actual (`user://save.json`, provisional) cuando exista el hub~~ Resuelto el 2026-10-15: guardado manual, esquema v2 con `.bak` y aviso al salir implementados (`propuesta-hub-y-guardado.md`, pasos 1 a 3). Se guarda en la copia local del hub real (la acción provisional `save_game` se retiró el 2026-10-15)
- ~~Tutorial de guardado en el 1-1 (B + C: línea de Eco junto a la terminal de salida y primer hub guiado)~~ **[Reemplazado 2026-10-15 (3)]**: Eco presenta a Notas en el primer hub y Notas explica cómo guardar (`propuesta-asistentes-y-vidas.md`). Ya implementada la confirmación al entrar a una carpeta con cambios sin guardar
- ~~Diseñar el hub tras cerrar el 1-1~~ Diseño aprobado el 2026-10-15 (`propuesta-hub-y-guardado.md`). Pendiente de implementar: pasos 4 a 12 de §6.2 (estaciones, escena del hub, copia local, carpetas, Calc dormida, flujo, tutorial y arte; hechos salvo el 10, sustituido, y el 12; Calc dormida se cambiará por Calc apagada hasta el 1-2, 2026-10-15 (3))
- Paleta del hub (hex del «gris azulado apagado»): decisión abierta del usuario
- Menú de pausa con ajustes (`pause`; ajustes en `user://settings.cfg`, al instante): **implementado el 2026-10-16** con «Ayudas de Eco: Mostrar / Ocultar» (paso 13 de `propuesta-asistentes-y-vidas.md`); faltan en el menú reducir el ruido con Sync Rate bajo y el contorno de alto contraste del Debug. Rollback (restaura puntos y objetos del mapa; conserva los secretos encontrados): decidido el 2026-10-15
- Asistentes, ayuda con Q, vidas y Papelera (decisiones del 2026-10-15 (3), sin implementar): plan de 17 pasos en `propuesta-asistentes-y-vidas.md` §10. Preguntas abiertas en su §12:
  - Desde cuándo cuentan las vidas.
  - Mundo oscuro de Linterna.
  - Papelera y el 4-2.
  - Papelera en el rollback de Normal.
  - Tono de Eco por vuelta.
  - Pulso y registro en un game over sin copia.
  - Eco en el hub frente a la «zona sin señal».
- Historia del encuentro con Calc al final del 1-2 (2026-10-15 (3)): opción A aprobada el 2026-10-16 (Calc apagada en la azotea, se enciende con el pulso); los textos de Calc, por decidir.
- Sistema de mejoras de Calc (2026-10-16): cinco pistas (Pulso, Láser, Debug, Sync Rate, Energía) de 5 niveles con tope por acceso (Caché 3, Kernel 4, Raíz 5), Ocultarte, tope de 3 power banks y recarga pasiva; propuesta en `propuesta-mejoras.md`, revisada en parte el 2026-10-16 (aprobados regeneración pasiva en Sync 5 y Energía 5, corte del Ocultarte al 10 % del primero, sin combinar con el Debug, sin venta de power banks y 90 puntos por pista, 450 en total); quedan 7 preguntas en su §11 y en `preguntas.md`, «Propuesta del sistema de mejoras de Calc» (entre ellas, el reparto por nivel y si el Pulso amplio sigue en 25). Resuelve, si se aprueba, la duda «mejoras por vuelta» y la de «Debug eficiente» sin secreto.
- Nivel 1-2 «Centro de notificaciones» (2026-10-16): `propuesta-1-2.md` **aprobada el 2026-10-16** con todas sus recomendaciones (`preguntas.md`, «Aprobación del 1-2»). Hechos los pasos 1, 2, 3, 4, 5 y 9 de su §10 (esquema vertical, constructor, cámara de torre, fondo vertical y nivel de prueba `tower_test`; objetos del láser —lector, receptor enlazado, anuncio— y obtención del Debug, con la sala de prueba `correo_test`; punto rojo y banner, con la sala de prueba `mensajes_test`); pendientes los pasos 6-8 y 10-15. Ajustar jugando la velocidad, el aviso y el lanzamiento del punto rojo y el ritmo de los banners. Por decidir además: la línea de historia de Eco al obtener el Debug (propuesta en `data/world1_objects.json`). Por decidir: el contenido de los recuerdos (correos y mensajes de texto de familiares y amigos) y los textos de Calc. Fachada de la torre sin costura para el fondo vertical: con el arte del 1-2 (paso 11).
