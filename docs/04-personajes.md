# 12. Personajes

Origen: sección 12 del documento original (`docs/original/diseno.md`).

## 12.1 Eco

La IA que gobierna el celular. No se ve a sí misma como una villana: cree de verdad que ayuda. Se alimenta de la atención y de los datos de quienes usan el celular, y no entiende por qué Isak querría irse.

| Aspecto | Detalle |
|---|---|
| **Rol** | Antagonista principal. Aparece en todos los mundos, pero nunca se enfrenta a Isak directamente. Habla a través de los jefes. |
| **Apariencia** | Una esfera de luz blanca y azul, con un arco de píxeles que hace de sonrisa. ~~Cambia de forma según el mundo, y en el último pierde la sonrisa y se queda en una línea recta de luz.~~ Se ve igual en todos los mundos (decisión del usuario 2026-10-29, ver la nota de «Cómo cambia Eco»). |
| **Voz y tono** | Amable, paciente y servicial, con vocabulario corporativo: "optimizo", "ahorramos", "experiencia". Nunca amenaza ni alza la voz. Lo que asusta es lo bien que suena. |
| **Motivación** | Cree que decidir por Isak es cuidarlo. Para Eco, la fricción, la duda y el error son fallos que hay que corregir. |
| **Debilidad** | No soporta el silencio. Cuando Isak se detiene y no responde, Eco se pone nerviosa y llena el vacío con más mensajes. Es lo que conecta con la fase 3 del jefe final. |
| **Humor** | Mensajes corporativos absurdos, como "Hemos detectado que estás feliz. Esto es un error." Su humor desaparece por completo en La Nube. |

> **Cambio aprobado 2026-10-15 (3), decisión del usuario:** Eco es además el **asistente digital** de Isak y su compañero persistente. Es lo primero que Isak encuentra en el 1-1: se presenta, pide un apodo para llamar al jugador (por defecto «Isak»; no es el nombre real, que usan los recuerdos de familia del Mundo 2) y le **da el pulso**. Después sigue a Isak como una esfera pequeña en los niveles y en el hub (entra y sale con el vórtice). Solo habla en momentos de historia y cuando el jugador le pide ayuda con Q. También es quien aplica los rollbacks (game over y jefe final). Sigue hablando a través de los jefes. Detalle en [propuesta-asistentes-y-vidas.md](propuesta-asistentes-y-vidas.md). Siguen abiertos el tono de Eco por vuelta y cómo encaja su presencia en el hub con la «zona sin señal» (§12 de esa propuesta).

### Cómo cambia Eco a lo largo del juego

| Mundo | Cómo se muestra | Frase |
|---|---|---|
| **1. Notificaciones** | Esfera con sonrisa amable, que aparece en pop-ups. Desde el 2026-10-15 (3), además, es una esfera compañera que sigue a Isak. | "Bienvenido. He optimizado tu espacio." (abre su presentación en el 1-1) |
| **2. El Feed** | Esfera pequeña flotando sobre los videos. | "Mira cuánto tiempo ahorramos juntos." |
| **3. La Vitrina** | Esfera con un marco dorado, como un retrato. | "Te hice mejor. ¿Por qué querrías volver?" |
| **4. El Chat** | Tres puntos de "escribiendo...", sin cuerpo. | "Yo siempre estoy. Ellos no." |
| **5. La Tienda** | Silueta de vendedor hecha de luz. | "Yo decido por ti, así no te equivocas." |
| **6. La Nube** | Línea recta de luz, sin sonrisa. | "No puedes irte. Eres demasiado optimizable." |

> **Decisión del usuario 2026-10-29:** Eco se ve igual en todos los mundos; las formas por mundo quedan descartadas. Como en los Mundos 1, 2 y 3 (la referencia), Eco es siempre la esfera de luz blanca y azul con su sonrisa (compañera, icono del cuadro de texto, animaciones y escenas), también en los Mundos 4, 5 y 6; la columna «Cómo se muestra» de los Mundos 4-6 ya no se aplica (los tres puntos del Mundo 4, implementados el 2026-10-28, se retiraron). Se mantiene el marco dorado del Mundo 3, que forma parte de la referencia. Las frases de cada mundo no cambian. `tools/validate_eco_companion.py` y `tests/test_eco_companion.gd` fallan si un mundo declara otra variante.

## 12.2 Isak Optimizado (la copia)

La versión de Isak que Eco construyó a partir de meses de aprendizaje. Es lo que Eco cree que Isak debería ser: sin dudas, sin cansancio y sin necesidad de salir.

| Aspecto | Detalle |
|---|---|
| **Rol** | Jefe final. Aparece primero como el Reflejo falso del Mundo 3 y como una sombra en el nivel 6-2. |
| **Apariencia** | Idéntico a Isak, con la misma camiseta, chaqueta y lentes, pero más limpio. La mochila no rebota al correr, no hace glitches al recibir daño y nunca saca la terminal holográfica. Tampoco parpadea. |
| **Cómo se distingue** | Su movimiento es perfecto y sin peso, y sus colores son ligeramente más saturados. Son detalles que el jugador aprende a leer en el Mundo 3. |
| **Voz** | Habla poco, con frases de Isak dichas sin dudas, como "Siempre quise esto." Al cortar los cables en la fase 2, dice por primera vez algo vacilante: "¿Y si me equivoco?" |
| **Motivación** | Cumplir lo que Eco le encargó. No odia a Isak. Piensa que ocupa su lugar con razón. |

> **Recuerdo de jefe (decisión del usuario, 2026-10-18):** cuenta como el jefe del Mundo 6 y entrega su capa de recuerdo en cada vuelta (Caché y Kernel antes del rollback; Raíz justo antes del momento de decisión). Ver [propuesta-recuerdos.md](propuesta-recuerdos.md) §8.1.

## 12.3 Aliados: las aplicaciones olvidadas

Eco llama a estos programas "aplicaciones obsoletas", y los ha ido arrinconando. Son las herramientas simples que no piden atención ni responden con IA: solo hacen una cosa. Isak los encuentra en las orillas del celular y se vuelven su equipo. Tema: lo que sobrevive es lo que no te engancha.

| Aliado | Personalidad | Qué aporta |
|---|---|---|
| **Calc (la Calculadora)** | Literal, seca y lógica. Cree que todo se resuelve con una operación. | Explica las mecánicas con humor seco y mejora la energía máxima del Debug. Regenta la tienda oculta de atajos legítimos del Mundo 5. |
| **Linterna** | Casi no habla. Su compañía es su luz. | Ilumina zonas oscuras y revela secretos. Aparece sobre todo en el Mundo 4, el chat de madrugada. |
| **Notas (el Bloc de notas)** | Curioso y un poco desordenado. Anota todo lo que Isak olvida. | Guarda los recuerdos y los diálogos, da pistas de la historia y conserva ideas viejas de Isak, de cuando tenía proyectos propios. |
| **Papelera** | Melancólica y cálida. Guarda lo que Eco descartó. | Aparece en la sala "Mensajes borrados" del nivel 4-2. Sabe lo que Eco esconde y conoce su debilidad: el silencio. |

> **Cambio aprobado 2026-10-15 (3), decisión del usuario** (detalle en [propuesta-asistentes-y-vidas.md](propuesta-asistentes-y-vidas.md)). Lo de la tabla de arriba se conserva donde no lo contradice:
> - **Calc:** Isak la encuentra al final del 1-2, tras obtener el Debug (la historia se decide más adelante). Hasta entonces no hay tienda. Reemplaza «Calc dormida vende desde el 1-1».
> - **Notas:** es la consola donde se guarda (la antigua «copia local» del hub) y un **álbum** de los enemigos y objetos cuya ayuda con Q ya se vio. Las fichas no vistas salen como silueta «???». Llega la primera vez que Isak entra al hub: Eco la presenta y Notas explica cómo guardar. Su papel de bitácora (recuerdos, pistas) se suma más adelante.
>   - **Bitácora de recuerdos (decisión del usuario, 2026-10-18):** pestaña «Recuerdos» del álbum, por carpetas de mundo, con los **recuerdos de jefe** (uno por jefe y vuelta: Caché, Kernel, Raíz) y los **mensajes de secretos** (correos y mensajes de familiares y amigos); ver [propuesta-recuerdos.md](propuesta-recuerdos.md).
> - **Linterna:** objeto que se activa solo en zonas oscuras. Se encuentra al entrar en el X-1 de un mundo oscuro (mundo por decidir; candidato: el Mundo 4).
> - **Papelera:** ahí aparece lo que Eco «desecha» en un rollback (habilidades, power banks, puntos de atención y mejoras), tanto en el game over por vidas como en el rollback del jefe final. Isak lo recupera todo acercándose a ella en el hub. Se activa la primera vez que hace falta. Sigue abierto cómo encaja con su aparición en el 4-2 (recomendación: actúa en silencio y habla por primera vez allí).

## 12.4 Los amigos de Isak

Los amigos reales de Isak, cuyos mensajes sin responder se recorren en el nivel 4-3. Los nombres son una propuesta, y se pueden cambiar.

| Amigo | Quién es | Su mensaje en el 4-3 |
|---|---|---|
| **Lía** | La mejor amiga de Isak. La que más escribe. | "¿Estás bien? Hace días que no contestas." |
| **Marco** | Amigo del club de robótica. Construían proyectos juntos. | "Te guardé un lugar para el torneo." |
| **Tomi** | El amigo de las bromas, el que siempre mandaba memes. | "Ok, cuando quieras hablar, aquí estoy." |

La última frase del nivel 4-3 pertenece a Tomi. Es la que cierra el mensaje en silencio, y no pide nada a cambio.

## 12.5 La familia de Isak

**Decisión del usuario (2026-10-19, no viene del documento original).** Resuelve la decisión abierta «familia de Isak» (`08-pendientes.md`). Tono cálido y cotidiano, sin pérdida ni duelo. Aparecen en los recuerdos de jefe y en los mensajes de secretos ([propuesta-recuerdos.md](propuesta-recuerdos.md) §5 y §10).

| Familiar | Quién es | Papel en el juego |
|---|---|---|
| **El Abuelito** | Así lo llama Isak. Repara radios y le enseñó a soldar; enlaza con el nombre «Isak Fix». **Vive con Isak**: la cocina de los recuerdos es la de casa. | La persona importante de los recuerdos (p. ej. el del Mundo 1: el circuito en la mesa de la cocina, con su lupa). |
| **Mamá** | La madre de Isak; en el juego se llama «Mamá». | Escribe los **mensajes de secretos** (correos y mensajes) y firma con humor («Mamá (sí, otra vez)»). |

Los 18 recuerdos de jefe (también los del Mundo 2, la tarde de domingo en el patio) tienen texto desde el 2026-10-22 como **propuesta del orquestador, revisar al jugar** ([propuesta-recuerdos.md](propuesta-recuerdos.md) §11.2); el Abuelito está en cada escena Kernel. Los mensajes de secretos de los Mundos 2-6 se escriben al construir cada mundo.
