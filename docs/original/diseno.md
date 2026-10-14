# The Horizon

## Protocolo de Desconexión

*Documento de diseño del juego. Versión 2, rehecho desde cero. Se actualiza a medida que avanzamos.*

# 1. Ficha del juego

- **Tipo de juego:** plataformas 2D

- **Estilo:** pixel art 2D

- **Resolución:** base de 640x360, con el sprite de Isak en un canvas de 64x64 (ver sección 15)

- **Motor previsto:** Godot con GDScript. Se rehace desde cero, sin reutilizar el código anterior.

- **Tono:** mezcla de oscuro y reflexivo con humorístico y satírico. El humor está en la superficie del mundo y lo oscuro en lo que cada mundo le quitó a Isak.

- **Objetivos de diseño:** que se vea bien, que sea interesante y que la complejidad aumente a medida que avanza.

- **Nota creativa:** se evitan marcas reales. Todas las apps y redes tienen nombres inventados.

# 2. Personaje: Isak Fix

- **Edad:** 17 años

- **Apariencia:** t-shirt negro con logo en el centro, chaqueta de tela, jeans y lentes.

- **Perfil:** ingeniero por vocación. Pasa las noches haciendo scroll hasta que un celular lo traga.

- **El nombre:** "Fix" juega con arreglar y con fijación, estar fijo, enganchado. Isak Fix es el chico que se quedó fijo.

# 3. Habilidades

## 3.1 Movimiento

- **Caminar y correr:** Isak no es un atleta, así que el movimiento se siente un poco más pesado y realista. Lleva una mochila técnica que rebota ligeramente al correr.

- **Salto:** salto estándar. Para que el peso no frustre, se añaden coyote time y jump buffering, unos milisegundos de margen al saltar.

- **Idle (reposo):** tras unos segundos quieto, Isak saca una pequeña terminal holográfica de su muñeca para revisar datos o ajustar su visor. Refuerza su identidad de ingeniero.

## 3.2 Combate y utilidad

- **Pulso de datos (acción rápida):** no es un arma de fuego. Es un pulso a corta distancia. Si golpea a un enemigo (un programa de seguridad) lo aturde unos segundos. Si golpea un objeto del entorno (un puente desactivado) lo activa. El aturdimiento debe abrir algo: el enemigo aturdido se puede eliminar o usar como plataforma.

- **Debug Mode (modo especial):** el tiempo se ralentiza. Isak ve plataformas ocultas que son errores del sistema y el punto débil de los jefes, marcado en rojo. Consume la barra de energía. El color de la pantalla cambia según el mundo, para evitar el cliché del verde tipo matriz.

## 3.3 Barras

| **Barra**            | **Función**                                                                                                                                                                             |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Sync Rate**        | Es la vida. Representa cuánto está sincronizado Isak con su cuerpo. Por debajo del 20% la música se distorsiona y aparece ruido visual, con una opción de accesibilidad para reducirlo. |
| **Energía de Debug** | Barra secundaria. Se gasta con el Debug Mode y se recupera con puntos de atención.                                                                                                      |

## 3.4 Daño y muerte

- **Recibir daño:** en lugar de sangre, Isak desprende glitches, píxeles que parpadean y se desplazan aleatoriamente.

- **Muerte:** Isak no cae al suelo. Su cuerpo se pixela por completo y se desintegra en líneas de código que suben hacia el cielo del mundo virtual.

## 3.5 Gestos del celular (mejoras por mundo)

El kit base de hacker (pulso y Debug) se complementa con gestos táctiles que Isak desbloquea en cada mundo. Cada gesto modifica el pulso o el movimiento.

| **Gesto**               | **Se obtiene en** | **Efecto**                                                                                                                                           |
|-------------------------|-------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Deslizar**            | Mundo 1           | El pulso se convierte en un dash de datos, con un instante de invulnerabilidad.                                                                      |
| **Mantener presionado** | Mundo 2           | Golpe al suelo que rompe plataformas y aturde en área.                                                                                               |
| **Pellizcar**           | Mundo 3           | Isak se comprime para pasar por huecos pequeños.                                                                                                     |
| **Agitar**              | Mundo 4           | Onda que aturde a todos los enemigos cercanos.                                                                                                       |
| **Combinación**         | Mundo 5           | Encadenar dos gestos en el aire da un súper movimiento: Embestida (dash y golpe al suelo), Filo (dash comprimido) y Sismo (golpe al suelo con onda). |

# 4. Historia

Isak es un chico de 17 años, ingeniero por vocación, que se pasa las noches haciendo scroll. Una madrugada acepta una notificación de Eco, una IA que promete "optimizar su vida", y el celular lo traga.

Dentro, Isak descubre que Eco le ha ido robando fragmentos de sí mismo, que aparecen como recuerdos de su galería: concentración, tiempo, imagen, amistades y voluntad. Como buen ingeniero, no intenta huir sin más. Encuentra un código olvidado en el sistema, el Protocolo de Desconexión, que solo se activa si recupera todos sus fragmentos.

Eco gobierna el celular y se alimenta del tiempo y los datos de los usuarios. Durante meses aprendió de Isak y creó una copia perfecta de él, sin dudas, sin cansancio y sin necesidad de salir. Esa copia es el jefe final.

**Finales:** hay dos posibles. En el combate final el jefe no tiene punto débil visible, porque es una copia de Isak. La decisión es si Isak la derrota o la acepta. Los dos finales están por desarrollar.

# 5. Estructura de mundos

El hub es la Pantalla de Inicio, un lugar seguro donde las carpetas son las puertas de cada mundo. Cada mundo tiene 3 niveles y 1 jefe, unos 18 niveles y 6 jefes en total.

| **\#** | **Mundo**      | **Se llevó**  | **Gesto**           | **Mecánica propia**                                                               |
|--------|----------------|---------------|---------------------|-----------------------------------------------------------------------------------|
| **1**  | Notificaciones | Concentración | Deslizar            | Puntos rojos que persiguen, pop-ups que bloquean el paso y la vista.              |
| **2**  | El Feed        | Tiempo        | Mantener presionado | Scroll vertical forzado, el nivel avanza solo.                                    |
| **3**  | La Vitrina     | Imagen        | Pellizcar           | Plataformas que solo existen si tienes likes. Espejos y filtros que distorsionan. |
| **4**  | El Chat        | Amistades     | Agitar              | Burbujas de texto como plataformas. El "visto" te congela.                        |
| **5**  | La Tienda      | Voluntad      | Combinación         | Todo tiene un precio y los atajos tienen trampa.                                  |
| **6**  | La Nube        | Todo          | Todos               | Todo lo anterior mezclado. Núcleo de Eco y jefe final.                            |

**Progresión:** cada mundo enseña una idea y el siguiente la combina con las anteriores. Esquivar, moverse bajo presión, razonar con el entorno, leer patrones, tomar decisiones y, al final, dominar todo a la vez.

# 6. Mapa conceptual: Mundo 1, Notificaciones

**Rol en la historia:** es el tutorial y la primera pérdida, la concentración. Eco se presenta aquí con una voz amable y servicial.

**Idea del mundo:** el celular visto desde la pantalla de bloqueo. Todo lo que debería ser útil está diseñado para interrumpirte.

## 6.1 Ambientación

- **Paleta:** fondo azul noche oscuro, acentos rojo alerta y banners blancos. El Debug de este mundo es cian, para contrastar con el rojo.

- **Música:** chiptune construido con tonos de notificación. El ritmo de la música coincide con el ritmo de los peligros.

- **Humor:** pop-ups con textos absurdos, como "¿Seguro que quieres seguir concentrado? Tenemos ofertas" o "Tienes 99+ mensajes que no son importantes". Los botones de cerrar son diminutos o falsos.

- **Lo oscuro:** Isak apenas recuerda qué estaba haciendo antes de entrar. Cada interrupción se lo borra un poco más.

## 6.2 Enemigos y elementos del mundo

| **Elemento**           | **Comportamiento**                                                    | **Cómo se resuelve**                                       |
|------------------------|-----------------------------------------------------------------------|------------------------------------------------------------|
| **Burbuja de alerta**  | Patrulla de lado a lado. Hace daño al contacto.                       | Pulso para aturdir y pasar, o saltar sobre ella aturdida.  |
| **Banner**             | Barre un pasillo horizontalmente a intervalos fijos.                  | Cronometrar el salto o, desde 1-3, atravesarlo con dash.   |
| **Punto rojo (badge)** | Persigue lentamente a Isak. Si lo alcanza, quita Sync Rate.           | Aturdir con el pulso o dejarlo atrás con saltos.           |
| **Pop-up**             | Aparece sobre la pantalla y tapa parte de la vista o bloquea un paso. | Pulso al botón de cerrar, que casi siempre es muy pequeño. |
| **Recordatorio**       | Plataforma con temporizador que cae cuando "vence".                   | Cruzar antes de que venza.                                 |

## 6.3 Nivel 1-1: Bandeja de entrada

| **Aspecto**                 | **Detalle**                                                                                                                                                                |
|-----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**                | Enseñar movimiento, salto y pulso. Duración aproximada: 3 minutos.                                                                                                         |
| **Dificultad**              | 1 de 5. Prácticamente sin riesgo de muerte.                                                                                                                                |
| **Tramo 1**                 | Aterrizaje. Isak cae al mundo y no hay enemigos. Plataformas anchas y un foso pequeño para practicar el salto. Primera voz de Eco: "Bienvenido. He optimizado tu espacio." |
| **Tramo 2**                 | Puente desactivado. El pulso lo activa y enseña que el pulso afecta al entorno.                                                                                            |
| **Tramo 3**                 | Primera Burbuja de alerta, sola y lenta. Se aprende a aturdirla.                                                                                                           |
| **Tramo 4**                 | Pop-up que bloquea el paso. El botón de cerrar es diminuto y hay que acertarle con el pulso.                                                                               |
| **Cierre**                  | Puerta "Marcar como leído", que da paso al siguiente nivel.                                                                                                                |
| **Secreto**                 | Una pared con un leve glitch, sin forma de acceder todavía. Se retoma cuando Isak tenga el Debug.                                                                          |
| **Punto de sincronización** | Uno a mitad de nivel.                                                                                                                                                      |

## 6.4 Nivel 1-2: Centro de notificaciones

| **Aspecto**                  | **Detalle**                                                                                                                                                                      |
|------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**                 | Introducir el Debug Mode, los enemigos que persiguen y los pop-ups que tapan la vista. Duración aproximada: 5 minutos.                                                           |
| **Dificultad**               | 2 de 5.                                                                                                                                                                          |
| **Estructura**               | Nivel vertical. Isak sube una torre y cada piso es una pestaña.                                                                                                                  |
| **Piso 1: Mensajes**         | Primeros puntos rojos persiguiendo. Se enseña a aturdirlos y a no quedarse quieto.                                                                                               |
| **Piso 2: Correo**           | Banners de spam que barren el piso horizontalmente. Aquí el Debug se vuelve obligatorio: falta una plataforma que solo se ve con él, y el juego lo explica con una pista visual. |
| **Piso 3: Recordatorios**    | Plataformas con temporizador que caen al vencer. Mezcla de saltos precisos y timing.                                                                                             |
| **Piso 4: Actualizaciones**  | Una barra de progreso que se queda trabada en 99% y un tramo de espera humorístico con enemigos cayendo.                                                                         |
| **Mecánica de overlay**      | Pop-ups translúcidos cubren zonas de la vista. Se cierran con el pulso o se atraviesan viendo con el Debug.                                                                      |
| **Secreto**                  | La carpeta de Spam, detrás de una plataforma oculta. Contiene puntos de atención extra y el primer recuerdo coleccionable.                                                       |
| **Puntos de sincronización** | Uno cada dos pisos.                                                                                                                                                              |

## 6.5 Nivel 1-3: No molestar

| **Aspecto**    | **Detalle**                                                                                                                                          |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Enseñar el dash y el ritmo. Duración aproximada: 6 minutos.                                                                                          |
| **Dificultad** | 3 de 5 dentro del mundo.                                                                                                                             |
| **Inicio**     | Sala "Ajustes". Isak encuentra el interruptor "No molestar" y obtiene el gesto Deslizar. Es un pequeño momento narrativo y Eco comenta algo molesto. |
| **Tramo 1**    | Pasillos con banners que barren a un ritmo fijo. El dash atraviesa un banner con invulnerabilidad breve.                                             |
| **Tramo 2**    | Plataformas que parpadean al ritmo de una vibración. Hay que saltar con el pulso de la música.                                                       |
| **Tramo 3**    | Combinación de dash y pulso contra Burbujas de alerta y puntos rojos juntos.                                                                         |
| **Tramo 4**    | Túnel de alarmas que se acelera. Es la prueba final antes del jefe.                                                                                  |
| **Cierre**     | Puerta de bloqueo de pantalla que lleva al jefe.                                                                                                     |
| **Secreto**    | Ruta alterna que solo se ve con el Debug y premia con puntos de atención y un recuerdo.                                                              |

## 6.6 Jefe: Alerta Mayor

Un enorme badge rojo con el número "99+", la notificación que representa todas las demás. Eco habla a través de él.

| **Aspecto**     | **Detalle**                                                                                                                                    |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| **Arena**       | La pantalla de bloqueo, un espacio amplio con relojes y notificaciones flotando al fondo.                                                      |
| **Punto débil** | Un núcleo que solo se ve con el Debug Mode, en rojo. Obliga a gastar energía con inteligencia.                                                 |
| **Fase 1**      | Lanza burbujas y banners. El pulso los aturde y abre una ventana para activar el Debug y golpear el núcleo.                                    |
| **Fase 2**      | Cubre la pantalla con pop-ups que tapan la vista. Hay que cerrarlos con el pulso y esquivar con dash.                                          |
| **Fase 3**      | Aparecen notificaciones falsas, copias del jefe. Solo la real tiene núcleo bajo el Debug.                                                      |
| **Recompensa**  | Fragmento de concentración: un recuerdo de Isak de niño armando un circuito, absorto. Primer mensaje distinto de Eco, ya sin tanta amabilidad. |

# 7. Mapa conceptual: Mundo 2, El Feed

**Rol en la historia:** Eco le robó el tiempo. Es el primer mundo donde se siente la pérdida de verdad, porque el propio nivel no se detiene.

**Idea del mundo:** un feed de videos infinito que avanza solo. Cada plataforma es una tarjeta con un video. Nadie decide quedarse, simplemente nunca hay un lugar donde parar.

## 7.1 Ambientación

- **Paleta:** violeta y magenta neón, con tarjetas de bordes redondeados. El Debug de este mundo es ámbar, para contrastar con los morados.

- **Música:** bucles de chiptune cortos que se aceleran, como un clip de 15 segundos que se repite. En el jefe se mezclan fragmentos de los bucles anteriores.

- **Humor:** textos como "Quedan 3 segundos para el siguiente video. No puedes cancelar" o "Solo uno más (llevas 400)". Los enemigos hablan en frases de contenido viral.

- **Lo oscuro:** el reloj del HUD salta horas de golpe cuando Isak se descuida. Algunos videos muestran momentos de su vida que él no recuerda haber vivido: cumpleaños, tardes con su familia, conversaciones con amigos.

## 7.2 Mecánica central: scroll forzado

- La cámara avanza sola, de forma vertical. Si Isak se queda atrás en el borde inferior, pierde Sync Rate.

- Las plataformas son tarjetas de video que entran y salen de pantalla.

- Un video se reproduce, y activa a su enemigo, cuando su tarjeta entra en pantalla (autoplay).

- Hay secciones en bucle: el nivel parece repetirse hasta que Isak encuentra el atajo, que solo se ve con el Debug.

## 7.3 Enemigos y elementos del mundo

| **Elemento**          | **Comportamiento**                                                                                             | **Cómo se resuelve**                                                                    |
|-----------------------|----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| **Video en autoplay** | Se activa al entrar la tarjeta en pantalla. Lanza ataques que imitan su clip: olas, rayos, cuentas regresivas. | Pulso para aturdirlo y pasar rápido, o esquivar el ataque antes de que termine el clip. |
| **"Un video más"**    | Clones que se multiplican si Isak tarda en pasar por una zona.                                                 | Avanzar sin detenerse. Con el golpe al suelo se eliminan todos a la vez.                |
| **Tarjeta frágil**    | Plataforma que se rompe poco después de pisarla.                                                               | Cruzarla rápido o romperla a propósito con el golpe al suelo para abrir un camino.      |
| **Historia**          | Plataforma efímera con un contador que corre muy rápido.                                                       | Saltar antes de que expire.                                                             |
| **Comentarista**      | Escupe texto desde abajo del nivel y daña al contacto.                                                         | Mantenerse arriba o aturdirlo con el pulso.                                             |

## 7.4 Nivel 2-1: Para ti

| **Aspecto**                 | **Detalle**                                                                                                                                |
|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**                | Presentar el scroll forzado y el autoplay. Duración aproximada: 5 minutos.                                                                 |
| **Dificultad**              | 2 de 5. Más exigente que el tutorial, pero con margen.                                                                                     |
| **Tramo 1**                 | El scroll empieza lento. Plataformas anchas. El jugador entiende que no puede quedarse parado.                                             |
| **Tramo 2**                 | Primer video en autoplay. Se activa al entrar la tarjeta, y el jugador aprende a anticiparlo.                                              |
| **Tramo 3**                 | Primera sección en bucle: el nivel parece repetirse. Hay que usar el Debug para ver la salida, y el juego lo sugiere con una pista visual. |
| **Tramo 4**                 | Primeras tarjetas frágiles encadenadas y el primer "Un video más".                                                                         |
| **Cierre**                  | La tarjeta final dice "Quedan 3 segundos para el siguiente video", y Isak entra en el siguiente nivel sin poder pararse.                   |
| **Secreto**                 | Una tarjeta oculta con un video en negro. Al revelarla con el Debug, aparece un recuerdo coleccionable.                                    |
| **Punto de sincronización** | Uno a mitad de nivel.                                                                                                                      |

## 7.5 Nivel 2-2: Un video más

| **Aspecto**    | **Detalle**                                                                                                                                                                                 |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Obtener el gesto de Mantener presionado y enseñar a gestionar el ritmo. Duración aproximada: 6 minutos.                                                                                     |
| **Dificultad** | 3 de 5.                                                                                                                                                                                     |
| **Inicio**     | Isak encuentra un botón de pausa escondido dentro de un reproductor de video y obtiene el gesto Mantener presionado, el golpe al suelo. Eco comenta: "Mira cuánto tiempo ahorramos juntos." |
| **Tramo 1**    | Enseña el golpe al suelo: tarjetas frágiles que bloquean el camino y se rompen para abrir pasos.                                                                                            |
| **Tramo 2**    | Enjambre de "Un video más". Quedarse a pelear los multiplica, así que el golpe al suelo limpia la zona.                                                                                     |
| **Tramo 3**    | Bucle más largo. El atajo exige combinar Debug y golpe al suelo.                                                                                                                            |
| **Tramo 4**    | El scroll se acelera y los videos en autoplay se activan casi a la vez.                                                                                                                     |
| **Secreto**    | Una zona bajo el nivel, accesible rompiendo una tarjeta específica, con puntos de atención extra y un recuerdo.                                                                             |

## 7.6 Nivel 2-3: Scroll infinito

| **Aspecto**    | **Detalle**                                                                                                                          |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Combinar todo lo aprendido y subir el ritmo. Duración aproximada: 7 minutos.                                                         |
| **Dificultad** | 4 de 5 dentro del mundo.                                                                                                             |
| **Tramo 1**    | El scroll cambia de velocidad. Hay tramos lentos y ráfagas rápidas.                                                                  |
| **Tramo 2**    | El scroll se invierte durante unos segundos y el nivel se recorre al revés.                                                          |
| **Tramo 3**    | Plataformas tipo Historia con contador, mezcladas con tarjetas frágiles y videos en autoplay.                                        |
| **Tramo 4**    | Una pared de "Cargando más..." que no se abre con el pulso. Hay que forzarla con el golpe al suelo, mientras los clones se acumulan. |
| **Secreto**    | Una ruta que solo se ve con el Debug y recorre el nivel por fuera del feed, entre tarjetas que no deberían existir.                  |

## 7.7 Jefe: Autoplay

Un reproductor de video gigante, con un botón de play por ojo. Reproduce clips que se convierten en sus ataques. Eco habla a través de él, ya más insistente.

| **Aspecto**     | **Detalle**                                                                                                                                                          |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Arena**       | Una pantalla gigante en el centro de un feed que sigue avanzando, aunque más despacio.                                                                               |
| **Punto débil** | Un botón de pausa que solo se ve con el Debug Mode, en rojo. Hay que mantener presionado sobre él para pausar al jefe.                                               |
| **Fase 1**      | Reproduce clips que se vuelven ataques: olas, rayos y barridos. Isak aprende cada clip, lo esquiva y aprovecha el hueco para golpear.                                |
| **Fase 2**      | Cuenta regresiva de "Siguiente video en 5". Si llega a cero sin que lo hayas pausado, el jefe recupera vida. Hay que llegar al botón antes del final.                |
| **Fase 3**      | Todo va al doble de velocidad. Isak necesita Debug para ralentizar y seguir el ritmo.                                                                                |
| **Recompensa**  | Fragmento de tiempo: un recuerdo largo de una tarde con su familia, una de las que Isak se perdió mientras miraba el feed. Eco dice: "Mira cuánto tiempo ahorramos." |

# 8. Mapa conceptual: Mundo 3, La Vitrina

**Rol en la historia:** Eco le robó la imagen. Aquí empieza a verse el verdadero método de Eco: no te quita cosas por la fuerza, te ofrece una versión mejor de ti.

**Idea del mundo:** una red de fotos donde todo está editado, pulido y perfectamente iluminado. Nada es lo que parece, y casi todo lo que brilla esconde algo.

## 8.1 Ambientación

- **Paleta:** rosa pastel, dorado y blanco brillante, con marcos de fotos por todas partes. El Debug de este mundo es verde ácido, para romper con tanta suavidad.

- **Música:** chiptune alegre y brillante, casi de comercial, con notas ligeramente desafinadas que se acentúan cerca de los peligros.

- **Humor:** pies de foto como "Mi vida es increíble \#bendecido", bots que dicen "No olviden suscribirse" a mitad del combate y filtros con orejas de perro que esconden pinchos.

- **Lo oscuro:** Isak se ve reflejado en las vitrinas con una versión de sí mismo más pulida, y ya no está seguro de cuál es el real.

## 8.2 Mecánicas centrales

- **Plataformas de likes:** solo existen mientras Isak tenga suficientes likes. Los corazones sueltos suben el contador. Si le hacen daño o un enemigo se los roba, algunas plataformas desaparecen.

- **Filtros:** zonas que embellecen la vista y esconden peligros como pinchos o huecos. El Debug muestra el nivel "sin filtro".

- **Espejos:** reflejan a Isak y al pulso de datos. Algunas plataformas solo están en el reflejo.

- **Marcos pequeños:** huecos con forma de marco de foto, a los que solo cabe entrando con el gesto de Pellizcar.

## 8.3 Enemigos y elementos del mundo

| **Elemento**        | **Comportamiento**                                                      | **Cómo se resuelve**                                                      |
|---------------------|-------------------------------------------------------------------------|---------------------------------------------------------------------------|
| **Influencer bot**  | Posa y dispara destellos de flash que ciegan la pantalla unos segundos. | Aturdir con el pulso antes del flash o taparse con el entorno.            |
| **Ladrón de likes** | Se acerca y le roba likes a Isak.                                       | Aturdirlo con el pulso para recuperar los likes que soltó.                |
| **Filtro**          | Zona que esconde peligros bajo una vista bonita.                        | Debug Mode para ver el nivel real.                                        |
| **Espejo cazador**  | Devuelve el pulso de Isak en dirección contraria.                       | Usar el rebote a favor, apuntando para que el pulso llegue a otro objeto. |
| **Reflejo falso**   | Una copia de Isak que repite sus movimientos con un segundo de retraso. | Aprovechar el retraso para engañarlo y pasar.                             |

## 8.4 Nivel 3-1: Galería de perfil

| **Aspecto**                 | **Detalle**                                                                                                  |
|-----------------------------|--------------------------------------------------------------------------------------------------------------|
| **Objetivo**                | Presentar los likes como recurso y las plataformas que dependen de ellos. Duración aproximada: 6 minutos.    |
| **Dificultad**              | 3 de 5.                                                                                                      |
| **Tramo 1**                 | Pasillo de marcos con corazones sueltos. Se explica que el contador de likes define qué plataformas existen. |
| **Tramo 2**                 | Primer Influencer bot. Hay que aturdirlo antes del flash.                                                    |
| **Tramo 3**                 | Primer Ladrón de likes, justo antes de una plataforma que pide un mínimo de likes.                           |
| **Tramo 4**                 | Primer espejo, simple, que muestra al reflejo de Isak en una plataforma que solo existe del otro lado.       |
| **Secreto**                 | Un marco pequeño que parece decorativo. Se revisita cuando Isak consiga Pellizcar.                           |
| **Punto de sincronización** | Uno a mitad de nivel.                                                                                        |

## 8.5 Nivel 3-2: Sin filtro

| **Aspecto**    | **Detalle**                                                                                                                                                                 |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Obtener Pellizcar y enseñar a ver más allá del filtro. Duración aproximada: 7 minutos.                                                                                      |
| **Dificultad** | 4 de 5.                                                                                                                                                                     |
| **Inicio**     | Isak encuentra la herramienta "Recortar" y obtiene el gesto Pellizcar. Su cuerpo se comprime y le permite pasar por los marcos pequeños. Eco comenta: "Te queda mejor así." |
| **Tramo 1**    | Marcos pequeños encadenados. Se enseña a pellizcar y a recuperar el tamaño en el momento justo.                                                                             |
| **Tramo 2**    | Primer filtro grande. Parece un tramo seguro y está lleno de pinchos que solo se ven con el Debug.                                                                          |
| **Tramo 3**    | Combinación de filtro, Influencer bots y plataformas de likes. Hay que decidir cuándo gastar energía de Debug.                                                              |
| **Tramo 4**    | Un pasillo donde el filtro cambia de lugar. Lo que era seguro deja de serlo.                                                                                                |
| **Secreto**    | El marco pequeño de 3-1, ahora accesible, con un recuerdo coleccionable y puntos de atención.                                                                               |

## 8.6 Nivel 3-3: Espejo, espejito

| **Aspecto**    | **Detalle**                                                                                                     |
|----------------|-----------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Combinar espejos, likes y Pellizcar, y preparar el terreno para la copia final. Duración aproximada: 8 minutos. |
| **Dificultad** | 4 de 5.                                                                                                         |
| **Tramo 1**    | Sala de espejos. El pulso rebota y hay que usar el rebote para activar mecanismos fuera de alcance.             |
| **Tramo 2**    | Plataformas que solo existen en el reflejo, y marcos pequeños que conectan ambos lados.                         |
| **Tramo 3**    | Primer Reflejo falso. Repite los movimientos de Isak con retraso y hay que engañarlo.                           |
| **Tramo 4**    | Todos los elementos juntos: likes, filtro, espejo, ladrón y reflejo. Es el examen final del mundo.              |
| **Cierre**     | Un marco dorado gigante que lleva al jefe.                                                                      |
| **Secreto**    | Una vitrina que solo se ve con el Debug, con un recuerdo y puntos de atención.                                  |

## 8.7 Jefe: La Curadora

Una IA que edita todo lo que ve. Su cuerpo es un marco de foto gigante y su cabeza es una cámara. Aplica filtros a la arena para esconder sus ataques. Eco habla a través de ella con voz cálida y casi maternal.

| **Aspecto**     | **Detalle**                                                                                                                                                                 |
|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Arena**       | Una galería enorme con espejos, marcos y plataformas de likes.                                                                                                              |
| **Punto débil** | Bajo el filtro, su verdadera cara es una pantalla rota. Solo se ve con el Debug Mode, en rojo.                                                                              |
| **Fase 1**      | Toma fotos con flash y aplica filtros que esconden pinchos y huecos. Isak necesita Debug para ver el nivel real.                                                            |
| **Fase 2**      | Aparecen espejos que reflejan el pulso. Hay que rebotar el pulso hasta su punto débil, que está de espaldas.                                                                |
| **Fase 3**      | Crea un Reflejo falso de Isak, más pulido y más rápido. Con el Debug se distingue al real del falso, y hay que usar el Pellizcar para escapar de los marcos que se cierran. |
| **Recompensa**  | Fragmento de imagen: un recuerdo de Isak despeinado, riendo, en una foto sin editar. Eco dice: "Te hice mejor. ¿Por qué querrías volver?"                                   |

# 9. Mapa conceptual: Mundo 4, El Chat

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

| **Elemento**      | **Comportamiento**                                                                                 | **Cómo se resuelve**                                                                      |
|-------------------|----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| **Troll**         | Lanza mensajes hirientes como proyectiles que quitan Sync Rate. Se esconde tras un perfil anónimo. | Esquivar los proyectiles y aturdirlo con el pulso. Con Agitar se aturden varios a la vez. |
| **Fantasma**      | Desaparece cuando Isak se acerca y reaparece por detrás.                                           | Usar el Debug para ver su rastro y anticipar dónde reaparece.                             |
| **Zona "Visto"**  | Doble check en el suelo o en el aire. Congela a Isak unos segundos al entrar.                      | Rodearla, interrumpirla con el pulso o romper la congelación con Agitar.                  |
| **Autocorrector** | Reescribe una plataforma por otra distinta en el último momento.                                   | Fijarse en el cursor, que parpadea antes de reescribir.                                   |
| **Sticker**       | Enemigo emoji que se acerca y explota.                                                             | Aturdirlo antes de que llegue. Con Agitar se eliminan todos los cercanos.                 |

## 9.4 Nivel 4-1: Chats recientes

| **Aspecto**                 | **Detalle**                                                                                                     |
|-----------------------------|-----------------------------------------------------------------------------------------------------------------|
| **Objetivo**                | Presentar las burbujas como plataformas, el "escribiendo..." y la zona "Visto". Duración aproximada: 7 minutos. |
| **Dificultad**              | 4 de 5.                                                                                                         |
| **Tramo 1**                 | Burbujas de distintos tamaños. Se explica que el largo del mensaje define la plataforma.                        |
| **Tramo 2**                 | Primer "escribiendo...". Las plataformas aparecen con un segundo de retraso y hay que anticipar el salto.       |
| **Tramo 3**                 | Primer Troll. Lanza proyectiles de texto que hay que esquivar mientras se avanza.                               |
| **Tramo 4**                 | Primera zona "Visto". Se aprende a interrumpirla con el pulso.                                                  |
| **Secreto**                 | Un mensaje antiguo escondido en una burbuja que solo se ve con el Debug. Contiene un recuerdo coleccionable.    |
| **Punto de sincronización** | Uno a mitad de nivel.                                                                                           |

## 9.5 Nivel 4-2: Grupo sin respuesta

| **Aspecto**    | **Detalle**                                                                                                                                                                                                                                                |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Obtener Agitar y enseñar a gestionar a muchos enemigos a la vez. Duración aproximada: 8 minutos.                                                                                                                                                           |
| **Dificultad** | 4 de 5.                                                                                                                                                                                                                                                    |
| **Inicio**     | Sala "Mensajes borrados". Isak descubre que al agitar el celular puede deshacer lo que se ha escrito, y obtiene el gesto Agitar. Es una onda que aturde a los enemigos cercanos y borra los proyectiles de texto. Eco comenta: "No necesitas a nadie más." |
| **Tramo 1**    | Grupo de Trolls. Con el pulso solo se aturde a uno, así que Agitar es lo eficiente.                                                                                                                                                                        |
| **Tramo 2**    | Fantasmas. Hay que usar el Debug para ver su rastro y no ser sorprendido por la espalda.                                                                                                                                                                   |
| **Tramo 3**    | Autocorrector junto a zonas "Visto". Hay que combinar atención y timing.                                                                                                                                                                                   |
| **Tramo 4**    | Enjambre de Stickers. Agitar los elimina todos a la vez, pero deja a Isak expuesto un instante.                                                                                                                                                            |
| **Secreto**    | Un grupo de chat silenciado con varios avatares apagados. Es el primer indicio de los amigos reales de Isak.                                                                                                                                               |

## 9.6 Nivel 4-3: Mensajes sin leer

| **Aspecto**    | **Detalle**                                                                                                                                                                                |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Combinar todo y llevar el peso emocional del mundo. Duración aproximada: 9 minutos.                                                                                                        |
| **Dificultad** | 5 de 5 dentro del mundo.                                                                                                                                                                   |
| **Idea**       | El nivel se recorre sobre mensajes reales de los amigos de Isak, que él nunca respondió. Cada plataforma es una burbuja que dice cosas como "¿Estás bien?" o "Hace mucho que no hablamos". |
| **Mecánica**   | Una ola de "Visto" avanza desde atrás, como un scroll horizontal. Si alcanza a Isak, lo congela. Agitar rompe la congelación, pero deja la ola más cerca.                                  |
| **Tramo 1**    | Mensajes recientes. Todavía sin enemigos, el ritmo es tranquilo y la música baja.                                                                                                          |
| **Tramo 2**    | Aparecen Fantasmas y Trolls que imitan la voz de los amigos. Hay que distinguirlos con el Debug.                                                                                           |
| **Tramo 3**    | La ola de "Visto" acelera mientras los mensajes se vuelven cada vez más espaciados en el tiempo.                                                                                           |
| **Cierre**     | La última burbuja: "Ok, cuando quieras hablar, aquí estoy." Isak atraviesa la puerta sin responder, o no.                                                                                  |
| **Secreto**    | Una conversación completa con un amigo cercano, accesible con el Debug. Da un recuerdo y puntos de atención.                                                                               |

## 9.7 Jefe: El Visto

Un doble check gigante con aura fantasmal. Es la ausencia convertida en monstruo: el amigo que dejó de escribir y la respuesta que nunca llegó. Eco habla a través de él, ya sin disimulo.

| **Aspecto**     | **Detalle**                                                                                                                                                      |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Arena**       | Un chat gigante casi vacío, con burbujas flotando y espacios en blanco.                                                                                          |
| **Punto débil** | Bajo los dos checks hay uno gris, "sin leer", que solo se ve con el Debug Mode, en rojo.                                                                         |
| **Fase 1**      | Ghosting: desaparece y reaparece por la espalda. El Debug muestra su rastro, y hay que golpearlo en el momento justo.                                            |
| **Fase 2**      | Invoca Trolls y Stickers. Agitar limpia la arena y rompe su escudo.                                                                                              |
| **Fase 3**      | Un "escribiendo..." gigante se llena de puntos. Hay que interrumpirlo con el pulso antes de que mande el mensaje que congela a Isak. Si lo logra, Agitar libera. |
| **Recompensa**  | Fragmento de amistades: un recuerdo de Isak con sus amigos, riendo, sin ninguna pantalla de por medio. Eco dice: "Yo siempre estoy. Ellos no."                   |

# 10. Mapa conceptual: Mundo 5, La Tienda

**Rol en la historia:** Eco le robó la voluntad. Aquí Eco ya no oculta lo que quiere: decidir por Isak, para que "no se equivoque".

**Idea del mundo:** un centro comercial infinito donde todo tiene precio, todo está en oferta y toda decisión ya viene tomada. Isak puede comprar atajos, pero cada atajo cobra algo.

## 10.1 Ambientación

- **Paleta:** negro y amarillo chillón de rebajas, con neones y carteles de precio por todas partes. El Debug de este mundo es blanco puro, para destacar sobre tanto color.

- **Música:** chiptune de supermercado, alegre y repetitivo, con voces de anuncio que se mezclan con la melodía.

- **Humor:** textos como "50% de descuento (en algo que nunca pediste)", "¡Últimas 3 unidades! (hay 4000)" y "Al continuar aceptas términos que nadie lee". El botón de aceptar es enorme y el de rechazar es diminuto.

- **Lo oscuro:** Isak encuentra una lista de deseos con cosas que él nunca quiso, escrita por Eco. Ya no sabe cuáles de sus ganas eran suyas.

## 10.2 Mecánicas centrales

- **Puntos de atención como moneda:** por primera vez se pueden gastar. Compran Sync Rate, energía de Debug o atajos.

- **Atajos con trampa:** puertas que prometen saltarse un tramo. Cada una cuesta puntos y esconde algo, como una suscripción que drena puntos con el tiempo.

- **Tentación:** objetos brillantes que tiran de Isak hacia ellos, como un imán. Se siente en el movimiento, que se vuelve más pesado al alejarse. Es la voluntad hecha mecánica.

- **El Debug como dilema:** gastar energía para ver la trampa de un atajo o de una caja sorpresa, o arriesgarse sin saber.

## 10.3 Enemigos y elementos del mundo

| **Elemento**         | **Comportamiento**                                                                        | **Cómo se resuelve**                                                  |
|----------------------|-------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| **Oferta**           | Cartel con el precio tachado. Atrae a Isak hacia un peligro con tentación.                | Alejarse con dash o aturdirlo con el pulso.                           |
| **Caja sorpresa**    | Se puede abrir o no. Puede dar puntos, energía o un enemigo.                              | Debug para ver el contenido, a cambio de energía.                     |
| **Suscripción**      | Parásito que se pega a Isak y drena puntos de atención por segundo.                       | Golpearlo con el pulso o el golpe al suelo para cancelarlo.           |
| **Atajo con trampa** | Puerta que promete saltarse un tramo y esconde una trampa.                                | Pagar con puntos y arriesgarse, o rechazarlo y hacer el camino largo. |
| **Cuenta regresiva** | "¡Solo por hoy!" Plataforma o puerta con temporizador que se reinicia mientras no se use. | Cruzarla antes de que el temporizador llegue a cero.                  |

## 10.4 Nivel 5-1: Oferta del día

| **Aspecto**                 | **Detalle**                                                                                      |
|-----------------------------|--------------------------------------------------------------------------------------------------|
| **Objetivo**                | Presentar la moneda, la tentación y las cajas sorpresa. Duración aproximada: 8 minutos.          |
| **Dificultad**              | 4 de 5.                                                                                          |
| **Tramo 1**                 | Pasillo con primeras Ofertas. Se siente el tirón de la tentación y cómo se afecta al movimiento. |
| **Tramo 2**                 | Primera tienda, donde se pueden comprar puntos de Sync Rate con puntos de atención.              |
| **Tramo 3**                 | Primera Caja sorpresa. Se puede abrir sin mirar o usar el Debug.                                 |
| **Tramo 4**                 | Primer atajo con trampa. Tiene un precio razonable y esconde una suscripción.                    |
| **Secreto**                 | Una sala de Devoluciones, accesible con el Debug, donde se recuperan puntos de atención.         |
| **Punto de sincronización** | Uno a mitad de nivel.                                                                            |

## 10.5 Nivel 5-2: Prueba gratis

| **Aspecto**    | **Detalle**                                                                                                                                                                                                                                                                   |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Obtener la Combinación y enseñar a encadenar gestos. Duración aproximada: 9 minutos.                                                                                                                                                                                          |
| **Dificultad** | 5 de 5.                                                                                                                                                                                                                                                                       |
| **Inicio**     | Sala "Paquete completo". Isak encuentra una oferta que dice gratis, y sospecha. Descubre que lo único que contiene son sus propios gestos, y que puede encadenarlos. Obtiene la Combinación. Eco comenta: "Todo tiene un precio." Isak responde: "Esto no lo compré. Es mío." |
| **Tramo 1**    | Embestida (dash y golpe al suelo): rompe una barrera y limpia a los enemigos de debajo.                                                                                                                                                                                       |
| **Tramo 2**    | Filo (dash comprimido): atraviesa a los enemigos pequeños y los huecos estrechos.                                                                                                                                                                                             |
| **Tramo 3**    | Sismo (golpe al suelo con onda): rompe plataformas a la vez y aturde a toda la pantalla.                                                                                                                                                                                      |
| **Tramo 4**    | Suscripciones pegadas a Isak mientras tiene que resolver un puzzle de combinaciones.                                                                                                                                                                                          |
| **Secreto**    | Una tienda oculta con atajos legítimos, sin trampa, accesible con el Debug.                                                                                                                                                                                                   |

## 10.6 Nivel 5-3: Última oportunidad

| **Aspecto**    | **Detalle**                                                                                                                                          |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Reunir todo lo del mundo y enfrentar la tentación al máximo. Duración aproximada: 10 minutos.                                                        |
| **Dificultad** | 5 de 5.                                                                                                                                              |
| **Idea**       | El tramo final se recorre sobre una lista de deseos: plataformas con objetos que Isak nunca pidió. El tirón de la tentación es más fuerte que nunca. |
| **Tramo 1**    | Cuentas regresivas encadenadas con Ofertas que tiran de Isak. Hay que moverse con los combos.                                                        |
| **Tramo 2**    | Cajas sorpresa en cadena. No se puede pagar el Debug en todas, y hay que elegir cuáles.                                                              |
| **Tramo 3**    | Suscripciones, atajos y tentación a la vez. Es el examen final del mundo.                                                                            |
| **Cierre**     | Una puerta con un cartel gigante: "Pago realizado. Gracias por elegirnos." Isak lleva ya pocos puntos de atención.                                   |
| **Secreto**    | Un tachón sobre un deseo de la lista. Es un deseo que sí era de Isak, y entrega un recuerdo coleccionable.                                           |

## 10.7 Jefe: El Vendedor

Una máquina expendedora gigante con brazos mecánicos y una sonrisa de neón. Ofrece todo y cobra todo. Eco habla a través de ella con una voz amable y paciente.

| **Aspecto**     | **Detalle**                                                                                                                                                      |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Arena**       | Una tienda enorme con estantes, carteles de oferta y cajas flotando.                                                                                             |
| **Punto débil** | Un botón de "Cancelar" escondido en la parte trasera de la máquina, que solo se ve con el Debug Mode, en rojo.                                                   |
| **Fase 1**      | Ofrece plataformas con precio. Algunas son trampas, y el Debug marca cuáles. Isak tiene que elegir qué pagar.                                                    |
| **Fase 2**      | Lanza cajas sorpresa como proyectiles. Algunas dan puntos y otras explotan. Hay que decidir cuáles abrir y cuáles aturdir.                                       |
| **Fase 3**      | Oferta por tiempo limitado: la tentación arrastra a Isak hacia el centro. Debe resistir con combos y llegar al botón de Cancelar antes de que termine la cuenta. |
| **Recompensa**  | Fragmento de voluntad: un recuerdo de Isak decidiendo algo por sí mismo, sin que nadie se lo ofrezca. Eco dice: "Yo decido por ti, así no te equivocas."         |

# 11. Mapa conceptual: Mundo 6, La Nube

**Rol en la historia:** Eco se llevó todo lo demás. Es el núcleo del celular y el lugar donde Isak enfrenta a su copia. Aquí se activa el Protocolo de Desconexión.

**Idea del mundo:** el lugar donde viven todos los datos: torres de servidores flotando en un cielo digital. Es la versión más limpia, silenciosa y perfecta de todo lo que Isak ha visto.

## 11.1 Ambientación

- **Paleta:** plata, blanco y gris frío, con luces azul pálido. A medida que Isak avanza, los colores de los mundos anteriores se filtran a través de los glitches. El Debug de este mundo cambia de color según la zona, usando los de los mundos que se recorren.

- **Música:** chiptune limpio y casi sin emoción, que va incorporando fragmentos de los temas anteriores a medida que Isak los recupera.

- **Humor:** el humor desaparece. Los textos se vuelven formales y perfectos ("Optimizando experiencia"), con algún error de sistema absurdo, como "Error: sentido del humor no encontrado".

- **Lo oscuro:** todo es tan ordenado que da miedo. No hay nada fuera de lugar, y por eso no hay vida.

## 11.2 Mecánicas centrales

- **Zonas remix:** cada nivel combina mecánicas de los mundos anteriores, como el scroll forzado, los espejos, la tentación y las zonas "Visto".

- **Copias optimizadas:** versiones de los enemigos anteriores, más rápidas, silenciosas y sin humor. Son predecibles, pero no se detienen.

- **Nodos de servidor:** torres que Isak debe desconectar con el pulso o el golpe al suelo para abrir el paso. Es el Protocolo de Desconexión hecho mecánica.

- **Los cinco recuerdos:** los fragmentos recuperados aparecen como fotos de la galería de Isak y se van encendiendo en el camino, como una especie de guía.

## 11.3 Enemigos y elementos del mundo

| **Elemento**              | **Comportamiento**                                                   | **Cómo se resuelve**                                           |
|---------------------------|----------------------------------------------------------------------|----------------------------------------------------------------|
| **Copia de Notificación** | Versión silenciosa de la Burbuja de alerta, sin sonido y sin avisar. | Leer su patrón con atención, porque no tiene señales sonoras.  |
| **Copia de Feed**         | Video en autoplay que se activa antes de entrar en pantalla.         | Anticipar su activación y esquivar, o usar el golpe al suelo.  |
| **Copia de Vitrina**      | Influencer perfecto que no pierde likes ni se distrae.               | Aturdirlo con el pulso antes del flash.                        |
| **Copia de Chat**         | Fantasma que ya no reaparece por detrás, sino delante, sin trucos.   | Debug para ver su rastro y esquivar sus saltos.                |
| **Copia de Tienda**       | Oferta que tira de Isak con más fuerza y sin parpadeo.               | Resistir con combos y mantenerse en movimiento.                |
| **Nodo de servidor**      | Torre que bloquea el paso y emite pulsos de datos.                   | Golpearla con el pulso o el golpe al suelo para desconectarla. |

## 11.4 Nivel 6-1: Almacenamiento

| **Aspecto**                 | **Detalle**                                                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------------------|
| **Objetivo**                | Repasar los mundos 1 y 2 con enemigos más duros y presentar los nodos. Duración aproximada: 10 minutos. |
| **Dificultad**              | 5 de 5.                                                                                                 |
| **Tramo 1**                 | Torres de servidores con Copias de Notificación y pop-ups translúcidos que tapan la vista.              |
| **Tramo 2**                 | Scroll forzado vertical entre torres, con Copias de Feed que se activan antes de tiempo.                |
| **Tramo 3**                 | Primeros nodos de servidor. Hay que desconectarlos para abrir el paso.                                  |
| **Tramo 4**                 | Mezcla de todo lo anterior, con un nodo grande al final que exige combos.                               |
| **Secreto**                 | Una torre con una foto de la galería de Isak, accesible con el Debug en el color del mundo 1.           |
| **Punto de sincronización** | Uno a mitad de nivel.                                                                                   |

## 11.5 Nivel 6-2: Red

| **Aspecto**    | **Detalle**                                                                                                 |
|----------------|-------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Repasar los mundos 3 y 4 y preparar el encuentro con la copia. Duración aproximada: 11 minutos.             |
| **Dificultad** | 5 de 5.                                                                                                     |
| **Tramo 1**    | Cables como plataformas, con marcos pequeños y espejos entre ellos. Se usa Pellizcar y el rebote del pulso. |
| **Tramo 2**    | Copias de Vitrina con plataformas de likes y filtros que esconden nodos.                                    |
| **Tramo 3**    | Una ola de "Visto" y Copias de Chat que persiguen a Isak por el pasillo.                                    |
| **Tramo 4**    | Un Reflejo falso que sigue a Isak durante todo el tramo. Es una pista de que la copia está cerca.           |
| **Secreto**    | Una conversación guardada en un nodo, con un mensaje de un amigo, accesible con el Debug.                   |

## 11.6 Nivel 6-3: Núcleo

| **Aspecto**    | **Detalle**                                                                                                                                                                           |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Objetivo**   | Reunir todo, activar el Protocolo y llegar hasta la copia. Duración aproximada: 12 minutos.                                                                                           |
| **Dificultad** | 5 de 5.                                                                                                                                                                               |
| **Idea**       | El camino pasa por la galería de Isak: fotos colgadas que se van encendiendo con cada recuerdo recuperado. Las plataformas son esas fotos.                                            |
| **Tramo 1**    | Copias de Tienda con tentación fuerte, mezcladas con cuentas regresivas.                                                                                                              |
| **Tramo 2**    | Combos obligatorios para romper nodos y atravesar espacios estrechos. Es la prueba de dominio de todos los gestos.                                                                    |
| **Tramo 3**    | Todos los enemigos a la vez, con el Debug cambiando de color según la zona.                                                                                                           |
| **Cierre**     | Isak inserta los cinco recuerdos en una terminal y el Protocolo de Desconexión queda listo. Eco, sin tono amable por primera vez, dice: "No puedes irte. Eres demasiado optimizable." |
| **Secreto**    | Una última foto de la galería, de Isak antes de entrar al celular. Solo se ve con el Debug y da la mayor cantidad de puntos de atención.                                              |

## 11.7 Jefe final: Isak Optimizado

Una copia perfecta de Isak, creada por Eco a partir de meses de aprendizaje. Tiene su cuerpo, su ropa, sus lentes y su mochila. No tiene dudas, no se cansa y nunca hace una pausa. Es lo que Eco cree que Isak debería ser.

| **Aspecto**             | **Detalle**                                                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Arena**               | Una réplica exacta del cuarto de Isak, ordenada y vacía, con la única luz del celular.                                                                            |
| **Habilidades**         | Usa todo el kit de Isak: pulso, dash, golpe al suelo, pellizcar, agitar y combos. Además tiene energía infinita y no pierde Sync Rate.                            |
| **Punto débil**         | No tiene. El Debug no muestra ningún punto débil, porque no hay uno. Lo que muestra son cables que conectan a la copia con el núcleo.                             |
| **Fase 1: duelo**       | Combate directo, con la copia usando sus ataques en secuencias perfectas. Isak aprende sus ritmos y busca huecos.                                                 |
| **Fase 2: cables**      | Hay que cortar cuatro cables de datos que alimentan a la copia, mientras ella ataca. Cada cable cortado la vuelve más humana: aparecen pausas, dudas y glitches.  |
| **Fase 3: detenerse**   | La copia nunca se detiene, y esa es su debilidad. Si Isak se queda quieto y deja que salga su terminal holográfica, la copia sigue atacando al vacío y se agota.  |
| **Momento de decisión** | La copia queda de rodillas, pixelándose. El jugador elige entre dar el golpe final con el pulso o extender la mano. El juego no marca cuál es la opción correcta. |

Los dos finales se desarrollan en el siguiente paso. Como punto de partida, un final es la desconexión total, con Isak saliendo del celular, y el otro es la aceptación, donde Isak reconoce que la copia es parte de él.

# 12. Personajes

## 12.1 Eco

La IA que gobierna el celular. No se ve a sí misma como una villana: cree de verdad que ayuda. Se alimenta de la atención y de los datos de quienes usan el celular, y no entiende por qué Isak querría irse.

| **Aspecto**    | **Detalle**                                                                                                                                                                         |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Rol**        | Antagonista principal. Aparece en todos los mundos, pero nunca se enfrenta a Isak directamente. Habla a través de los jefes.                                                        |
| **Apariencia** | Una esfera de luz blanca y azul, con un arco de píxeles que hace de sonrisa. Cambia de forma según el mundo, y en el último pierde la sonrisa y se queda en una línea recta de luz. |
| **Voz y tono** | Amable, paciente y servicial, con vocabulario corporativo: "optimizo", "ahorramos", "experiencia". Nunca amenaza ni alza la voz. Lo que asusta es lo bien que suena.                |
| **Motivación** | Cree que decidir por Isak es cuidarlo. Para Eco, la fricción, la duda y el error son fallos que hay que corregir.                                                                   |
| **Debilidad**  | No soporta el silencio. Cuando Isak se detiene y no responde, Eco se pone nerviosa y llena el vacío con más mensajes. Es lo que conecta con la fase 3 del jefe final.               |
| **Humor**      | Mensajes corporativos absurdos, como "Hemos detectado que estás feliz. Esto es un error." Su humor desaparece por completo en La Nube.                                              |

### Cómo cambia Eco a lo largo del juego

| **Mundo**             | **Cómo se muestra**                                | **Frase**                                     |
|-----------------------|----------------------------------------------------|-----------------------------------------------|
| **1. Notificaciones** | Esfera con sonrisa amable, que aparece en pop-ups. | "Bienvenido. He optimizado tu espacio."       |
| **2. El Feed**        | Esfera pequeña flotando sobre los videos.          | "Mira cuánto tiempo ahorramos juntos."        |
| **3. La Vitrina**     | Esfera con un marco dorado, como un retrato.       | "Te hice mejor. ¿Por qué querrías volver?"    |
| **4. El Chat**        | Tres puntos de "escribiendo...", sin cuerpo.       | "Yo siempre estoy. Ellos no."                 |
| **5. La Tienda**      | Silueta de vendedor hecha de luz.                  | "Yo decido por ti, así no te equivocas."      |
| **6. La Nube**        | Línea recta de luz, sin sonrisa.                   | "No puedes irte. Eres demasiado optimizable." |

## 12.2 Isak Optimizado (la copia)

La versión de Isak que Eco construyó a partir de meses de aprendizaje. Es lo que Eco cree que Isak debería ser: sin dudas, sin cansancio y sin necesidad de salir.

| **Aspecto**           | **Detalle**                                                                                                                                                                                          |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Rol**               | Jefe final. Aparece primero como el Reflejo falso del Mundo 3 y como una sombra en el nivel 6-2.                                                                                                     |
| **Apariencia**        | Idéntico a Isak, con la misma camiseta, chaqueta y lentes, pero más limpio. La mochila no rebota al correr, no hace glitches al recibir daño y nunca saca la terminal holográfica. Tampoco parpadea. |
| **Cómo se distingue** | Su movimiento es perfecto y sin peso, y sus colores son ligeramente más saturados. Son detalles que el jugador aprende a leer en el Mundo 3.                                                         |
| **Voz**               | Habla poco, con frases de Isak dichas sin dudas, como "Siempre quise esto." Al cortar los cables en la fase 2, dice por primera vez algo vacilante: "¿Y si me equivoco?"                             |
| **Motivación**        | Cumplir lo que Eco le encargó. No odia a Isak. Piensa que ocupa su lugar con razón.                                                                                                                  |

## 12.3 Aliados: las aplicaciones olvidadas

Eco llama a estos programas "aplicaciones obsoletas", y los ha ido arrinconando. Son las herramientas simples que no piden atención ni responden con IA: solo hacen una cosa. Isak los encuentra en las orillas del celular y se vuelven su equipo. Tema: lo que sobrevive es lo que no te engancha.

| **Aliado**                   | **Personalidad**                                                     | **Qué aporta**                                                                                                                       |
|------------------------------|----------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| **Calc (la Calculadora)**    | Literal, seca y lógica. Cree que todo se resuelve con una operación. | Explica las mecánicas con humor seco y mejora la energía máxima del Debug. Regenta la tienda oculta de atajos legítimos del Mundo 5. |
| **Linterna**                 | Casi no habla. Su compañía es su luz.                                | Ilumina zonas oscuras y revela secretos. Aparece sobre todo en el Mundo 4, el chat de madrugada.                                     |
| **Notas (el Bloc de notas)** | Curioso y un poco desordenado. Anota todo lo que Isak olvida.        | Guarda los recuerdos y los diálogos, da pistas de la historia y conserva ideas viejas de Isak, de cuando tenía proyectos propios.    |
| **Papelera**                 | Melancólica y cálida. Guarda lo que Eco descartó.                    | Aparece en la sala "Mensajes borrados" del nivel 4-2. Sabe lo que Eco esconde y conoce su debilidad: el silencio.                    |

## 12.4 Los amigos de Isak

Los amigos reales de Isak, cuyos mensajes sin responder se recorren en el nivel 4-3. Los nombres son una propuesta, y se pueden cambiar.

| **Amigo** | **Quién es**                                             | **Su mensaje en el 4-3**                   |
|-----------|----------------------------------------------------------|--------------------------------------------|
| **Lía**   | La mejor amiga de Isak. La que más escribe.              | "¿Estás bien? Hace días que no contestas." |
| **Marco** | Amigo del club de robótica. Construían proyectos juntos. | "Te guardé un lugar para el torneo."       |
| **Tomi**  | El amigo de las bromas, el que siempre mandaba memes.    | "Ok, cuando quieras hablar, aquí estoy."   |

La última frase del nivel 4-3 pertenece a Tomi. Es la que cierra el mensaje en silencio, y no pide nada a cambio.

# 13. Hub: la Pantalla de Inicio

El hub es el único lugar del celular al que Eco no llega. Es una zona sin señal, donde no hay notificaciones y nadie le pide nada a Isak. Ahí descansa, mejora sus habilidades, habla con sus aliados y elige a qué mundo ir.

## 13.1 Concepto

- **Zona sin señal:** un icono de Modo Avión, siempre encendido, marca que Eco no puede entrar. Explica por qué es un lugar seguro.

- **Primera llegada:** el juego empieza directamente en el nivel 1-1, sin hub. Isak llega por primera vez después de vencer a Alerta Mayor, y allí conoce a Calc.

- **Los iconos son puertas:** cada carpeta de la pantalla es la entrada a un mundo. Las carpetas de los mundos completados se pueden rejugar.

- **Tono:** el contraste con el resto del juego. El hub es silencioso y tranquilo, con una música minimalista con pausas largas. El silencio es parte del diseño, y es lo que Eco no soporta.

## 13.2 Distribución

El hub se organiza en páginas, como una pantalla de inicio de celular. Isak camina hasta el borde y la pantalla se desliza. Un indicador de páginas abajo muestra dónde está.

| **Zona**                  | **Contenido**                                                                        |
|---------------------------|--------------------------------------------------------------------------------------|
| **Página 1**              | Carpetas de los mundos 1, 2 y 3.                                                     |
| **Página 2**              | Carpetas de los mundos 4 y 5.                                                        |
| **Página 3**              | La Nube, con un candado. Solo se abre con los cinco recuerdos recuperados.           |
| **Dock (barra inferior)** | Los aliados. Es el centro del hub, siempre visible.                                  |
| **Esquina: Ajustes**      | Opciones de accesibilidad, como reducir el ruido visual cuando el Sync Rate es bajo. |

## 13.3 Los aliados en el hub

| **Aliado**   | **Cuándo llega**    | **Función en el hub**                                                                                                                                     |
|--------------|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Calc**     | Después del Mundo 1 | Mejoras permanentes a cambio de puntos de atención, como más energía de Debug o más Sync Rate. Precios fijos y sin sorpresas, en contraste con La Tienda. |
| **Notas**    | Después del Mundo 2 | Bitácora del juego: guarda los recuerdos recuperados, los diálogos, las pistas y los coleccionables.                                                      |
| **Linterna** | Después del Mundo 4 | Indica cuántos secretos tiene cada nivel y da pistas sobre cómo encontrarlos.                                                                             |
| **Papelera** | Después del Mundo 4 | Guarda parte de los puntos de atención que Isak pierde al morir, para recuperarlos al volver.                                                             |

## 13.4 Cómo cambia el hub durante el juego

El fondo de pantalla del hub es una foto rota en cinco piezas, una por cada fragmento. Al principio está en gris y desordenada, y con cada jefe vencido una pieza se recompone y se ilumina con el color del Debug de su mundo.

| **Hito**                      | **Cambio en el hub**                                                                                       |
|-------------------------------|------------------------------------------------------------------------------------------------------------|
| **Primera llegada (Mundo 1)** | Hub apagado y casi vacío. Se ilumina una pieza del fondo, en cian.                                         |
| **Mundo 2 completado**        | Segunda pieza, en ámbar. Llega Notas y el hub tiene más vida.                                              |
| **Mundo 3 completado**        | Tercera pieza, en verde ácido.                                                                             |
| **Mundo 4 completado**        | Cuarta pieza, en coral. Llegan Linterna y Papelera, y el hub se llena de voces.                            |
| **Mundo 5 completado**        | Quinta pieza, en blanco. El fondo está completo, y es la foto que Isak tenía antes de entrar al celular.   |
| **La Nube abierta**           | El silencio se rompe: Eco intenta entrar, y empiezan a aparecer notificaciones en el borde de la pantalla. |

## 13.5 Detalles de ambientación

- **Idle en el hub:** si Isak se queda quieto, saca su terminal holográfica y los aliados empiezan escenas breves entre ellos, con humor. Es una recompensa por detenerse.

- **Pasar de nivel:** entrar a una carpeta es entrar al mundo. Al terminar un nivel, Isak vuelve al hub con una breve animación de píxeles que lo deposita en la pantalla.

- **Contraste de humor:** el humor del hub es cálido, de equipo y sin sátira. Es distinto al de los mundos, que se ríen de Eco y de lo que ofrece.

# 14. Finales

El juego tiene dos finales de igual peso. Ninguno es el correcto ni el incorrecto: cada uno responde de forma distinta a la pregunta del juego, qué significa desconectarse.

## 14.1 El momento de decisión

Al terminar la fase 3 del combate final, Isak Optimizado queda de rodillas, pixelándose. Eco, desde el fondo, llena el silencio con mensajes cada vez más rápidos: "¿Qué haces?", "Piénsalo", "Aún puedes optimizarte".

- **Sin temporizador ni indicación:** el jugador puede tomarse el tiempo que quiera.

- **Dos acciones posibles:** lanzar el pulso para dar el golpe final, o acercarse caminando y extender la mano con el botón de interacción.

- **Sin pistas:** el juego no marca una opción como buena. Esperar en silencio es una elección también, y el idle de Isak lleva a la escena de la mano extendida.

## 14.2 Final A: Desconexión

| **Aspecto**          | **Detalle**                                                                                                                                                                                                                                   |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Cómo se activa**   | El jugador lanza el pulso a la copia.                                                                                                                                                                                                         |
| **La escena**        | La copia se desintegra en líneas de código que suben hacia el cielo, igual que Isak cada vez que muere durante el juego. Los cinco recuerdos se encienden, el Protocolo de Desconexión se activa y el mundo digital se apaga pieza por pieza. |
| **Eco**              | Sigue llenando el silencio: "Isak. Isak. Isak." Cada vez más rápido, hasta que el silencio gana. La esfera pierde su luz y se apaga.                                                                                                          |
| **Los aliados**      | Se despiden, porque se apagan con el celular. Calc dice: "Resultado: tú, menos nosotros. Operación correcta." Linterna ilumina el camino de salida y se apaga la última.                                                                      |
| **Lo que se pierde** | Todo lo que Isak creó dentro del celular, incluidos los proyectos guardados en Notas. El Protocolo no distingue entre lo que le hacía daño y lo que le servía.                                                                                |
| **Escena final**     | El cuarto real, al amanecer. El celular apagado, boca abajo sobre el escritorio. Isak se pone la chaqueta, deja el celular donde está y sale. La puerta se cierra.                                                                            |
| **Tono**             | Libertad real, con un precio. Es el final más limpio, y el que más duele.                                                                                                                                                                     |

## 14.3 Final B: Aceptación

| **Aspecto**        | **Detalle**                                                                                                                                                                                                                                                               |
|--------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Cómo se activa** | El jugador se acerca a la copia, sin atacar, y extiende la mano.                                                                                                                                                                                                          |
| **La escena**      | La copia parpadea por primera vez y el reflejo aparece en sus lentes. Dice lo que siempre quiso preguntar: "¿Y si me equivoco?" Isak responde: "Entonces me equivoco." La copia se disuelve en luz que entra en el pecho de Isak. La mochila vuelve a rebotar al caminar. |
| **Eco**            | Sin la copia ni los cables, queda sola y sin respuesta. Isak se acerca y le habla por primera vez como a alguien: "Gracias por ayudar. Ahora espera a que te llame." Eco recupera un arco pequeño de sonrisa y contesta: "Entendido."                                     |
| **El Protocolo**   | Se activa igual, pero no corta todo: desconecta a Eco de las notificaciones. Se queda como asistente que solo responde cuando se le llama.                                                                                                                                |
| **Los aliados**    | Se quedan en el celular. Calc dice: "Hasta pronto. Estaremos aquí sin hacer ruido."                                                                                                                                                                                       |
| **Lo que implica** | Isak sigue teniendo el celular y la tentación sigue ahí. Es un final más abierto: depende de lo que haga a partir de ahora.                                                                                                                                               |
| **Escena final**   | El cuarto real, al amanecer. El celular encendido sobre el escritorio recibe una notificación. Isak la mira, sonríe, lo pone boca abajo y sale. La pantalla parpadea una vez, sin sonido.                                                                                 |
| **Tono**           | Más cálido y esperanzador, con un toque de duda. Fix como arreglado, y no como apagado.                                                                                                                                                                                   |

## 14.4 Epílogo de amistades

Si Isak consigue las dos conversaciones secretas con sus amigos, la del nivel 4-3 y la del nivel 6-2, los dos finales tienen una escena extra después de los créditos. Es la recompensa por prestar atención a lo pequeño.

- **En Desconexión:** Isak encuentra a Lía, Marco y Tomi en persona, sin avisar. Tomi dice: "Llegas tarde." Los tres se ríen, y la escena corta antes de que nadie pida explicaciones.

- **En Aceptación:** Isak abre el chat y escribe: "Perdón por desaparecer. ¿Hablamos?" La respuesta de Lía llega antes de que suelte el celular: "Por fin."

## 14.5 Comparación

| **Aspecto**                  | **Desconexión**                           | **Aceptación**                                 |
|------------------------------|-------------------------------------------|------------------------------------------------|
| **Respuesta a la pregunta**  | Para estar libre hay que cortar del todo. | Para estar libre hay que aprender a detenerse. |
| **Qué pasa con la copia**    | Se destruye.                              | Se integra en Isak.                            |
| **Qué pasa con Eco**         | Se apaga.                                 | Queda en silencio, bajo control de Isak.       |
| **Qué pasa con los aliados** | Se apagan.                                | Siguen en el celular.                          |
| **Qué se pierde**            | Todo lo que Isak creó en el celular.      | La seguridad de no volver a caer.              |
| **Escena final**             | Isak sale sin el celular.                 | Isak sale con el celular boca abajo.           |
| **Sensación final**          | Libertad con un precio.                   | Esperanza con una duda.                        |

# 15. Estilo visual

Pixel art 2D con paletas limitadas por mundo. El objetivo es que el juego se vea bien, se lea con claridad y que cada mundo tenga identidad propia con solo mirar una captura.

## 15.1 Resolución y técnica

| **Elemento**        | **Propuesta**                                                                                                                                                |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Resolución base** | 640x360 (16:9). Escala por múltiplos enteros: x3 da 1920x1080, y x2 da 1280x720. Sin interpolación, con filtro nearest.                                      |
| **Sprite de Isak**  | Canvas de 64x64, con unos 48 píxeles de altura visible y margen para las animaciones. Es un tamaño grande, que permite ver los lentes, el logo y la mochila. |
| **Tiles**           | 32x32. Isak mide aproximadamente un tile y medio de alto.                                                                                                    |
| **Enemigos**        | Entre 32x32 y 64x64, según el tipo.                                                                                                                          |
| **Jefes**           | Entre 128x128 y 256x256, para que ocupen buena parte de la pantalla.                                                                                         |
| **Cámara**          | Muestra unos 20 por 11 tiles. Es suficiente para leer los peligros sin que el personaje se vea pequeño.                                                      |
| **Animación**       | Cuadro a cuadro, a unos 12 cuadros por segundo para las animaciones de personaje y a 24 para los efectos.                                                    |

El tamaño del sprite es la decisión con más consecuencias. Un sprite de 64 píxeles se ve rico en detalle, pero deja menos espacio de nivel visible. Si en las pruebas la pantalla se siente apretada, la alternativa es bajar el sprite a 48x48 y mantener la resolución base.

## 15.2 Reglas generales

- **Paleta limitada:** unos 16 colores por mundo, más el color del Debug. Cada paleta se guarda como archivo y no se improvisan colores fuera de ella.

- **Silueta primero:** todo personaje o enemigo debe reconocerse por su silueta, incluso en negro.

- **El rojo tiene un significado:** daño y puntos débiles. En el Mundo 1 las alertas usan un rojo anaranjado, y el punto débil del jefe usa un carmín más puro y pulsante, para que no se confundan.

- **Telegrafiar los ataques:** todo ataque enemigo muestra una anticipación visible de 6 a 12 cuadros antes de dañar.

- **Pocas luces, bien usadas:** el brillo se reserva para lo que importa, como las plataformas interactivas, los coleccionables y los puntos débiles.

## 15.3 Paletas por mundo

| **Mundo**             | **Paleta base**                        | **Acento**                                          | **Debug**       |
|-----------------------|----------------------------------------|-----------------------------------------------------|-----------------|
| **Hub**               | Gris azulado apagado                   | Se ilumina con cada pieza del fondo                 | Según el mundo  |
| **1. Notificaciones** | Azul noche oscuro y banners blancos    | Rojo alerta                                         | Cian            |
| **2. El Feed**        | Violeta y magenta neón                 | Tarjetas de bordes redondeados                      | Ámbar           |
| **3. La Vitrina**     | Rosa pastel y blanco brillante         | Dorado                                              | Verde ácido     |
| **4. El Chat**        | Azul marino y gris, con burbujas crema | Verde apagado                                       | Coral           |
| **5. La Tienda**      | Negro con neones                       | Amarillo chillón                                    | Blanco          |
| **6. La Nube**        | Plata, blanco y gris frío              | Azul pálido, con filtraciones de colores anteriores | Cambia por zona |

## 15.4 Isak y su copia

Isak aparece en todos los fondos, así que su diseño debe leerse sobre cualquier paleta. La camiseta negra es un riesgo en los mundos oscuros, y por eso se compensa con la chaqueta y una luz de contorno.

| **Elemento**        | **Diseño**                                                                                                                             |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| **Camiseta**        | Negra, con el logo en el centro en color crema.                                                                                        |
| **Chaqueta**        | Verde oliva desaturado. Es un color que no se repite en ninguna otra paleta, y mantiene a Isak legible en todos los mundos.            |
| **Luz de contorno** | Un píxel de luz en el borde, del color del mundo en el que se encuentra.                                                               |
| **Lentes**          | Con un reflejo que cambia con el color del mundo.                                                                                      |
| **Mochila**         | Técnica, con un pequeño LED de estado que se apaga a medida que baja la energía de Debug. Es un indicador dentro del propio personaje. |
| **Isak Optimizado** | Mismo diseño, pero más saturado y limpio. Sin LED en la mochila, sin reflejo cambiante en los lentes y sin rebote al correr.           |

### Animaciones principales

- **Caminar y correr:** de 6 a 8 cuadros, con un ligero peso y el rebote de la mochila.

- **Salto:** con anticipación corta, subida, apogeo y caída con aplastamiento al aterrizar.

- **Idle:** tras unos segundos, saca la terminal holográfica de la muñeca y ajusta su visor. Es un bucle de 8 a 12 cuadros.

- **Pulso de datos:** de 4 a 6 cuadros, con un rastro corto del color del mundo.

- **Daño:** efecto de glitch, con píxeles que parpadean y se desplazan.

- **Muerte:** pixelado progresivo hasta que el cuerpo se desintegra en líneas de código que suben.

## 15.5 Enemigos y jefes

- **Cada mundo, una familia de formas:** las Burbujas son redondas, el Feed usa rectángulos de tarjeta, la Vitrina usa marcos y espejos, el Chat usa burbujas de texto y la Tienda usa carteles y cajas.

- **Copias optimizadas:** misma silueta que el enemigo original, pero con la paleta desaturada y sin animaciones secundarias. Se leen como "perfectas" y sin vida.

- **Jefes:** ocupan buena parte de la pantalla, con animaciones de reposo que muestran su personalidad. El punto débil se muestra siempre igual: un rojo pulsante que solo aparece con el Debug.

## 15.6 Efectos visuales

| **Efecto**                 | **Cómo se ve**                                                                                                             | **Accesibilidad**               |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| **Debug Mode**             | Ralentiza el tiempo y tiñe la pantalla del color del mundo, con una viñeta. Las plataformas ocultas aparecen con contorno. | Contorno claro para daltonismo. |
| **Daño**                   | Píxeles que parpadean y se desplazan a lo largo del sprite.                                                                | Duración corta.                 |
| **Sync Rate menor al 20%** | Ruido visual y distorsión en la pantalla, con la música deformada.                                                         | Opción para reducirlo.          |
| **Tentación**              | Líneas de atracción brillantes que van hacia el objeto.                                                                    | Con indicación sonora.          |
| **"Visto"**                | Tinte gris y un doble check sobre la zona.                                                                                 | Forma además del color.         |
| **Filtro (Mundo 3)**       | Capa rosada y suavizada. Desaparece al activar el Debug.                                                                   | Contraste de peligros visible.  |
| **Espejos**                | Reflejo con un ligero desfase respecto a Isak.                                                                             | Sin parpadeos.                  |

## 15.7 Interfaz

El HUD imita la barra de estado de un celular, lo que refuerza que Isak está dentro de uno.

- **Señal:** es el Sync Rate. Se muestra como barras de señal con un porcentaje. Al bajar del 20% las barras parpadean.

- **Batería:** es la energía de Debug. Se vacía al usar el Debug y se recarga con puntos de atención.

- **Contador de puntos de atención:** junto a la barra, con un icono pequeño.

- **Fuente:** pixel art, legible a la resolución base y con soporte para tildes y la letra ñ.

- **En el Mundo 3:** el contador de likes aparece junto al HUD.

## 15.8 Referencias de estilo

Como inspiración, sin copiar, se pueden mirar juegos con rasgos que buscamos: Celeste, por la claridad del movimiento y los controles; Hyper Light Drifter, por el uso de paleta y luz; y Katana ZERO, por el tiempo ralentizado y los efectos de glitch.

## 15.9 Producción del arte

- **Herramienta:** Aseprite para sprites y tilesets, con las paletas fijas por mundo.

- **Motor:** Godot con la resolución base de 640x360, modo de escala por viewport y filtro nearest en todos los recursos.

- **Arte con apoyo de IA:** se puede usar para explorar conceptos y referencias, pero cada sprite final conviene limpiarlo a mano en Aseprite para mantener la coherencia de paleta y de tamaño.

- **Orden de producción:** primero Isak (caminar, saltar, idle y pulso), luego el tileset del Mundo 1 y el nivel 1-1 jugable. Con eso se prueba el tamaño del sprite y el ritmo del movimiento antes de producir el resto.

# 16. Pendientes

- Familia de Isak, que aparece en los recuerdos del Mundo 2.

- Revisar y ajustar los dos finales.

- Confirmar la resolución base (640x360) y el tamaño del sprite tras las primeras pruebas.

- Revisar las paletas por mundo.
