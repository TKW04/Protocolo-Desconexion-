# Isak Fix y sus habilidades

Origen: secciones 2 y 3 del documento original (`docs/original/diseno.md`).

## 2. Personaje: Isak Fix

- **Edad:** 17 años
> **Cambio aprobado 2026-10-14:** el diseño de Isak de la hoja de referencia `../Ejemplo/Idle.png` (fuera del repo, arte generado con IA) reemplaza la apariencia del documento original y sirve de guía: pelo castaño oscuro desordenado, sin lentes; chaqueta gris oscura tipo táctica con detalles cian luminosos en el cuello y un parche cian en el hombro; camiseta/chaleco negro con un logo claro en el pecho; mochila marrón; pantalón gris oscuro con bolsillos; botas grises con detalles naranja; celular en la mano. Detalle en [07-estilo-visual.md](07-estilo-visual.md) §15.4. La línea siguiente es la apariencia original, que se conserva como referencia histórica (`docs/original/diseno.md` queda intacto).

- **Apariencia (original, reemplazada):** t-shirt negro con logo en el centro, chaqueta de tela, jeans y lentes.
- **Perfil:** ingeniero por vocación. Pasa las noches haciendo scroll hasta que un celular lo traga.
- **El nombre:** "Fix" juega con arreglar y con fijación, estar fijo, enganchado. Isak Fix es el chico que se quedó fijo.

## 3. Habilidades

### 3.1 Movimiento

- **Caminar y correr:** Isak no es un atleta, así que el movimiento se siente un poco más pesado y realista. Lleva una mochila técnica que rebota ligeramente al correr.
- **Salto:** salto estándar. Para que el peso no frustre, se añaden coyote time y jump buffering, unos milisegundos de margen al saltar.
- **Idle (reposo):** tras unos segundos quieto, Isak saca una pequeña terminal holográfica de su muñeca para revisar datos o ajustar su visor. Refuerza su identidad de ingeniero.

### 3.2 Combate y utilidad

- **Pulso de datos (acción rápida):** no es un arma de fuego. Es un pulso a corta distancia. Si golpea a un enemigo (un programa de seguridad) lo aturde unos segundos. Si golpea un objeto del entorno (un puente desactivado) lo activa. El aturdimiento debe abrir algo: el enemigo aturdido se puede eliminar o usar como plataforma.
> **Cambio aprobado 2026-10-15 (decisión del usuario):** nueva habilidad **Láser**, desbloqueable (se obtiene con un objeto del nivel): dispara un proyectil horizontal hacia donde mira Isak que hace daño. Gasta la misma energía que el Debug Mode. Los enemigos tienen vida y el láser es lo que los elimina; el enemigo aturdido sigue sirviendo de plataforma, pero caer sobre él ya no lo elimina. El texto original de esta sección se conserva; valores y detalle en `docs/preguntas.md` («Láser, vida de enemigos y energía (2026-10-15)»).

> **Cambio aprobado 2026-10-15 (3), decisión del usuario:** el pulso ya no se tiene desde el inicio del 1-1: es un **regalo de Eco** en su presentación, en el primer tramo del 1-1 (columna 11). El tramo anterior no exige pulso. Detalle en [propuesta-asistentes-y-vidas.md](propuesta-asistentes-y-vidas.md) §7.1.

- **Debug Mode (modo especial):** el tiempo se ralentiza. Isak ve plataformas ocultas que son errores del sistema y el punto débil de los jefes, marcado en rojo. Consume la barra de energía. El color de la pantalla cambia según el mundo, para evitar el cliché del verde tipo matriz.

> **Propuesta 2026-10-16 (pendiente de revisión):** las mejoras de Calc pasan a ser cinco pistas de 5 niveles (Pulso, Láser, Debug, Sync Rate y Energía). El nivel 4 del Pulso da un estado nuevo, **Ocultarte** (acción `hide`: los enemigos que ven pierden a Isak; gasta Sync Rate y energía y se apaga al 10 %), y los niveles 5 de Sync Rate y Energía, regeneración pasiva. Detalle en [propuesta-mejoras.md](propuesta-mejoras.md).

### 3.3 Barras

| Barra | Función |
|---|---|
| **Sync Rate** | Es la vida. Representa cuánto está sincronizado Isak con su cuerpo. Por debajo del 20% la música se distorsiona y aparece ruido visual, con una opción de accesibilidad para reducirlo. |
| **Energía de Debug** | Barra secundaria. Se gasta con el Debug Mode y se recupera con puntos de atención. |

> **Cambio aprobado 2026-10-15 (3), vidas:** además de las barras hay **vidas (intentos)**, distintas del **Sync Rate (salud)**. Una vida se pierde cuando el Sync Rate llega a 0. Hay 3 de base (`lives_max`), que se reponen al empezar cada intento de nivel desde el hub; los puntos de sincronización no las reponen. Cada vida extra (una cada 3 mapas, que se coge una sola vez) sube el máximo de forma permanente y cuenta como secreto. Ver §3.4 y `propuesta-asistentes-y-vidas.md` §5.

> **Cambio aprobado 2026-10-15:** la energía también la gasta el láser y se recupera, además de con puntos de atención, con los drops de los enemigos, en el hub y con cargadores en los mapas.

### 3.4 Daño y muerte

- **Recibir daño:** en lugar de sangre, Isak desprende glitches, píxeles que parpadean y se desplazan aleatoriamente.
- **Muerte:** Isak cae y queda en el suelo mientras su cuerpo se pixela por completo y se desintegra en líneas de código que suben hacia el cielo del mundo virtual.

> **Cambio aprobado 2026-10-14:** la hoja de muerte entregada muestra a Isak tumbado.

> **Cambio aprobado 2026-10-15 (3):** cada muerte resta una vida (intento). Con vidas restantes, Isak reaparece en el último punto de sincronización, como hasta ahora. Con 0 vidas hay game over: Eco aplica un rollback a la última copia guardada en el hub, lo obtenido después se pierde y lo guardado (habilidades, power banks, puntos de atención y mejoras) aparece en la Papelera del hub, donde Isak lo recupera.

### 3.5 Gestos del celular (mejoras por mundo)

El kit base de hacker (pulso y Debug) se complementa con gestos táctiles que Isak desbloquea en cada mundo. Cada gesto modifica el pulso o el movimiento.

| Gesto | Se obtiene en | Efecto |
|---|---|---|
| **Deslizar** | Mundo 1 | El pulso se convierte en un dash de datos, con un instante de invulnerabilidad. |
| **Mantener presionado** | Mundo 2 | Golpe al suelo que rompe plataformas y aturde en área. |
| **Pellizcar** | Mundo 3 | Isak se comprime para pasar por huecos pequeños. |
| **Agitar** | Mundo 4 | ~~Onda que aturde a todos los enemigos cercanos.~~ **Retirado el 2026-10-28** (decisión del usuario tras probar el Mundo 4: «hace lo mismo que el pulso»); el Mundo 4 se juega con el kit anterior (`propuesta-mundo-4.md` §8.1). Pendiente: el Sismo del Mundo 5 (golpe al suelo con onda) partía de este gesto. |
| **Combinación** | Mundo 5 | Encadenar dos gestos en el aire da un súper movimiento: Embestida (dash y golpe al suelo), Filo (dash comprimido) y Sismo (golpe al suelo con onda). |

> **Cambio aprobado 2026-10-19 (decisión del usuario; resuelve C5 de `preguntas.md`):** **Deslizar** es un **gesto aparte**, una variante del pulso con su propia acción `gesture_swipe` (L / B del mando; reasignable en Ajustes > Controles): **el pulso normal sigue disponible** y los dos se combinan (Tramo 3 del 1-3, Fase 2 de Alerta Mayor). Se obtiene al inicio del 1-3, en el interruptor «No molestar». **No sube de nivel** (sin pista de Calc; los gestos progresan por las combinaciones del Mundo 5 y la pista de Energía lo abarata de forma indirecta). Cuesta energía y tiene un enfriamiento corto, se usa en el suelo y en el aire, Isak es invulnerable mientras dura, atraviesa banners y proyectiles (no el terreno ni los objetos sólidos) y no se combina con el Ocultarte ni con el Debug. **Valores provisionales** (propuesta, se ajustan jugando): 3 tiles en 0,2 s, invulnerable 0,3 s, 10 de energía, 0,5 s de enfriamiento, un dash en el aire por salto. Detalle en [propuesta-1-3.md](propuesta-1-3.md) §2. El texto de la tabla («el pulso se convierte en un dash») se conserva como el original.
