# 9. Mapa conceptual: Mundo 4, El Chat

Origen: sección 9 del documento original (`docs/original/diseno.md`).

**Rol en la historia:** Eco le robó las amistades. Es el mundo más emocional hasta ahora, y el primero donde Eco deja de parecer un asistente y empieza a parecer un reemplazo.

**Idea del mundo:** una app de mensajería donde la conversación nunca termina y nadie escucha de verdad. Isak puede hablar con quien quiera, y aun así está solo.

## 9.1 Ambientación

- **Paleta:** azul marino y gris, con burbujas de texto color crema y acentos verde apagado. Es un chat de madrugada, íntimo y frío. El Debug de este mundo es coral.
- **Música:** chiptune melancólico con sonidos de tecleo que marcan el ritmo. Se vuelve más silencioso cerca de los amigos reales de Isak.
- **Humor:** autocorrector que cambia las palabras por otras absurdas, "escribiendo..." que no termina nunca, respuestas de una sola palabra y "jajaja" dichos sin reírse.
- **Lo oscuro:** en los chats aparecen mensajes de los amigos reales de Isak que él nunca respondió. Cada vez están más espaciados, hasta que dejan de llegar.

## 9.2 Mecánicas centrales

- **Burbujas como plataformas:** el largo del mensaje define el largo de la plataforma. Un mensaje corto es una plataforma pequeña y un mensaje largo es un puente.
- **"Escribiendo...":** tres puntos animados indican que una plataforma está a punto de aparecer, y sirven para anticipar el salto.
- **"Visto":** un doble check que marca zonas. Si Isak entra en una, se congela unos segundos. El pulso lo interrumpe y, con el gesto Agitar, se rompe la congelación.
- **Ghosting:** fantasmas que desaparecen cuando Isak se acerca y reaparecen detrás de él. El Debug muestra su rastro.

## 9.3 Enemigos y elementos del mundo

| Elemento | Comportamiento | Cómo se resuelve |
|---|---|---|
| **Troll** | Lanza mensajes hirientes como proyectiles que quitan Sync Rate. Se esconde tras un perfil anónimo. | Esquivar los proyectiles y aturdirlo con el pulso. Con Agitar se aturden varios a la vez. |
| **Fantasma** | Desaparece cuando Isak se acerca y reaparece por detrás. | Usar el Debug para ver su rastro y anticipar dónde reaparece. |
| **Zona "Visto"** | Doble check en el suelo o en el aire. Congela a Isak unos segundos al entrar. | Rodearla, interrumpirla con el pulso o romper la congelación con Agitar. |
| **Autocorrector** | Reescribe una plataforma por otra distinta en el último momento. | Fijarse en el cursor, que parpadea antes de reescribir. |
| **Sticker** | Enemigo emoji que se acerca y explota. | Aturdirlo antes de que llegue. Con Agitar se eliminan todos los cercanos. |

## 9.4 Nivel 4-1: Chats recientes

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Presentar las burbujas como plataformas, el "escribiendo..." y la zona "Visto". Duración aproximada: 7 minutos. |
| **Dificultad** | 4 de 5. |
| **Tramo 1** | Burbujas de distintos tamaños. Se explica que el largo del mensaje define la plataforma. |
| **Tramo 2** | Primer "escribiendo...". Las plataformas aparecen con un segundo de retraso y hay que anticipar el salto. |
| **Tramo 3** | Primer Troll. Lanza proyectiles de texto que hay que esquivar mientras se avanza. |
| **Tramo 4** | Primera zona "Visto". Se aprende a interrumpirla con el pulso. |
| **Secreto** | Un mensaje antiguo escondido en una burbuja que solo se ve con el Debug. Contiene un recuerdo coleccionable. |
| **Punto de sincronización** | Uno a mitad de nivel. |

## 9.5 Nivel 4-2: Grupo sin respuesta

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Obtener Agitar y enseñar a gestionar a muchos enemigos a la vez. Duración aproximada: 8 minutos. |
| **Dificultad** | 4 de 5. |
| **Inicio** | Sala "Mensajes borrados". Isak descubre que al agitar el celular puede deshacer lo que se ha escrito, y obtiene el gesto Agitar. Es una onda que aturde a los enemigos cercanos y borra los proyectiles de texto. Eco comenta: "No necesitas a nadie más." |
| **Tramo 1** | Grupo de Trolls. Con el pulso solo se aturde a uno, así que Agitar es lo eficiente. |
| **Tramo 2** | Fantasmas. Hay que usar el Debug para ver su rastro y no ser sorprendido por la espalda. |
| **Tramo 3** | Autocorrector junto a zonas "Visto". Hay que combinar atención y timing. |
| **Tramo 4** | Enjambre de Stickers. Agitar los elimina todos a la vez, pero deja a Isak expuesto un instante. |
| **Secreto** | Un grupo de chat silenciado con varios avatares apagados. Es el primer indicio de los amigos reales de Isak. |

## 9.6 Nivel 4-3: Mensajes sin leer

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Combinar todo y llevar el peso emocional del mundo. Duración aproximada: 9 minutos. |
| **Dificultad** | 5 de 5 dentro del mundo. |
| **Idea** | El nivel se recorre sobre mensajes reales de los amigos de Isak, que él nunca respondió. Cada plataforma es una burbuja que dice cosas como "¿Estás bien?" o "Hace mucho que no hablamos". |
| **Mecánica** | Una ola de "Visto" avanza desde atrás, como un scroll horizontal. Si alcanza a Isak, lo congela. Agitar rompe la congelación, pero deja la ola más cerca. |
| **Tramo 1** | Mensajes recientes. Todavía sin enemigos, el ritmo es tranquilo y la música baja. |
| **Tramo 2** | Aparecen Fantasmas y Trolls que imitan la voz de los amigos. Hay que distinguirlos con el Debug. |
| **Tramo 3** | La ola de "Visto" acelera mientras los mensajes se vuelven cada vez más espaciados en el tiempo. |
| **Cierre** | La última burbuja: "Ok, cuando quieras hablar, aquí estoy." Isak atraviesa la puerta sin responder, o no. |
| **Secreto** | Una conversación completa con un amigo cercano, accesible con el Debug. Da un recuerdo y puntos de atención. |

## 9.7 Jefe: El Visto

Un doble check gigante con aura fantasmal. Es la ausencia convertida en monstruo: el amigo que dejó de escribir y la respuesta que nunca llegó. Eco habla a través de él, ya sin disimulo.

| Aspecto | Detalle |
|---|---|
| **Arena** | Un chat gigante casi vacío, con burbujas flotando y espacios en blanco. |
| **Punto débil** | Bajo los dos checks hay uno gris, "sin leer", que solo se ve con el Debug Mode, en rojo. |
| **Fase 1** | Ghosting: desaparece y reaparece por la espalda. El Debug muestra su rastro, y hay que golpearlo en el momento justo. |
| **Fase 2** | Invoca Trolls y Stickers. Agitar limpia la arena y rompe su escudo. |
| **Fase 3** | Un "escribiendo..." gigante se llena de puntos. Hay que interrumpirlo con el pulso antes de que mande el mensaje que congela a Isak. Si lo logra, Agitar libera. |
| **Recompensa** | Fragmento de amistades: un recuerdo de Isak con sus amigos, riendo, sin ninguna pantalla de por medio. Eco dice: "Yo siempre estoy. Ellos no." |
