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
- Tutorial de guardado en el 1-1 (decidido el 2026-10-15: B + C, sin guardado dentro de los niveles): línea de Eco junto a la terminal de salida y primer hub guiado. Pendiente de rediseño por el usuario (2026-10-15: Eco se presentará en el hub y presentará a Notas; paso 10 de `propuesta-hub-y-guardado.md`). Ya implementada la confirmación al entrar a una carpeta con cambios sin guardar
- ~~Diseñar el hub tras cerrar el 1-1~~ Diseño aprobado el 2026-10-15 (`propuesta-hub-y-guardado.md`). Pendiente de implementar: pasos 4 a 12 de §6.2 (estaciones, escena del hub, copia local, carpetas, Calc dormida, flujo, tutorial y arte)
- Paleta del hub (hex del «gris azulado apagado»): decisión abierta del usuario
- Menú de pausa con ajustes (`pause`; ajustes en `user://settings.cfg`, al instante) y rollback (restaura puntos y objetos del mapa; conserva los secretos encontrados): decididos el 2026-10-15, sin implementar
