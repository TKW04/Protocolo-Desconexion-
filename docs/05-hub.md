# 13. Hub: la Pantalla de Inicio

Origen: sección 13 del documento original (`docs/original/diseno.md`).

El hub es el único lugar del celular al que Eco no llega. Es una zona sin señal, donde no hay notificaciones y nadie le pide nada a Isak. Ahí descansa, mejora sus habilidades, habla con sus aliados y elige a qué mundo ir.

## 13.1 Concepto

- **Zona sin señal:** un icono de Modo Avión, siempre encendido, marca que Eco no puede entrar. Explica por qué es un lugar seguro.
- **Primera llegada:** el juego empieza directamente en el nivel 1-1, sin hub. Isak llega por primera vez después de vencer a Alerta Mayor, y allí conoce a Calc.
- **Los iconos son puertas:** cada carpeta de la pantalla es la entrada a un mundo. Las carpetas de los mundos completados se pueden rejugar. Desde la carpeta se elige también el subnivel (ver 13.6).
- **Tono:** el contraste con el resto del juego. El hub es silencioso y tranquilo, con una música minimalista con pausas largas. El silencio es parte del diseño, y es lo que Eco no soporta.

## 13.2 Distribución

El hub se organiza en páginas, como una pantalla de inicio de celular. Isak camina hasta el borde y la pantalla se desliza. Un indicador de páginas abajo muestra dónde está.

| Zona | Contenido |
|---|---|
| **Página 1** | Carpetas de los mundos 1, 2 y 3. |
| **Página 2** | Carpetas de los mundos 4 y 5. |
| **Página 3** | La Nube, con un candado. Solo se abre con los cinco recuerdos recuperados. |
| **Dock (barra inferior)** | Los aliados. Es el centro del hub, siempre visible. |
| **Esquina: Ajustes** | Opciones de accesibilidad, como reducir el ruido visual cuando el Sync Rate es bajo. |

Selección de zona y subnivel, compra de mejoras y guardado: ver 13.6.

## 13.3 Los aliados en el hub

| Aliado | Cuándo llega | Función en el hub |
|---|---|---|
| **Calc** | Después del Mundo 1 | Mejoras permanentes a cambio de puntos de atención, como más energía de Debug o más Sync Rate. Precios fijos y sin sorpresas, en contraste con La Tienda. |
| **Notas** | Después del Mundo 2 | Bitácora del juego: guarda los recuerdos recuperados, los diálogos, las pistas y los coleccionables. |
| **Linterna** | Después del Mundo 4 | Indica cuántos secretos tiene cada nivel y da pistas sobre cómo encontrarlos. |
| **Papelera** | Después del Mundo 4 | Guarda parte de los puntos de atención que Isak pierde al morir, para recuperarlos al volver. |

## 13.4 Cómo cambia el hub durante el juego

El fondo de pantalla del hub es una foto rota en cinco piezas, una por cada fragmento. Al principio está en gris y desordenada, y con cada jefe vencido una pieza se recompone y se ilumina con el color del Debug de su mundo.

| Hito | Cambio en el hub |
|---|---|
| **Primera llegada (Mundo 1)** | Hub apagado y casi vacío. Se ilumina una pieza del fondo, en cian. |
| **Mundo 2 completado** | Segunda pieza, en ámbar. Llega Notas y el hub tiene más vida. |
| **Mundo 3 completado** | Tercera pieza, en verde ácido. |
| **Mundo 4 completado** | Cuarta pieza, en coral. Llegan Linterna y Papelera, y el hub se llena de voces. |
| **Mundo 5 completado** | Quinta pieza, en blanco. El fondo está completo, y es la foto que Isak tenía antes de entrar al celular. |
| **La Nube abierta** | El silencio se rompe: Eco intenta entrar, y empiezan a aparecer notificaciones en el borde de la pantalla. |

## 13.5 Detalles de ambientación

- **Idle en el hub:** si Isak se queda quieto, saca su terminal holográfica y los aliados empiezan escenas breves entre ellos, con humor. Es una recompensa por detenerse.
- **Pasar de nivel:** entrar a una carpeta es entrar al mundo. Al terminar un nivel, Isak vuelve al hub con una breve animación de píxeles que lo deposita en la pantalla.
- **Contraste de humor:** el humor del hub es cálido, de equipo y sin sátira. Es distinto al de los mundos, que se ríen de Eco y de lo que ofrece.

## 13.6 Selección de nivel, mejoras y guardado (decisión del 2026-10-15)

No viene del documento original. Decisión del usuario; detalle y dudas abiertas en `preguntas.md` («Decisiones del 2026-10-15: tres vueltas, hub y guardado»).

- **Selección de nivel:** desde el hub se elige la zona (1 a 6) y el subnivel (p. ej. 1-1, 1-2, 1-3). Antes de que exista el hub (Mundo 1, hasta vencer a Alerta Mayor) no hay selección.
- **Puntos de atención:** al rejugar un nivel no se restauran los ya capturados. Solo vuelven con un rollback: al final de Easy lo hace el jefe final al escapar y al final de Normal lo hace Isak, engañado por el jefe. Hard termina el juego (final real).
- **Mejoras:** se compran en el hub, con Calc (13.3).
- **Guardado:** manual y solo en el hub. Si se cierra el juego sin haber guardado en el hub, el progreso no se salva. El 1-1 enseña a guardar (tutorial en el primer nivel); como el hub llega tras el Mundo 1, depende del hub o de un punto de guardado en el nivel (pendiente). El guardado automático actual en `user://save.json` es provisional: se migra al manual cuando exista el hub.
- **Diseño del hub:** se hace cuando termine el 1-1.
