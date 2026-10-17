# Propuesta: sistema de mejoras de Calc (cinco pistas de 5 niveles)

**Estado:** **APROBADA el 2026-10-17** con todas sus recomendaciones (§11) y los costes de 90 puntos por pista. **Tanda M1 hecha (2026-10-17):** pasos 1-4, 10 y 11 de §10 y la parte del validador y la economía del paso 9 (detalle en «Tanda M1», al final). **Pendiente, tanda M2:** pasos 5-8 (efectos complejos) y el resto del paso 9. Antes: PROPUESTA (2026-10-16), revisada en parte por el usuario el mismo día: **aprobadas** la regeneración pasiva de los niveles 5 de Sync y Energía, el corte del Ocultarte al 10 % del Sync o de la energía, que Ocultarte y Debug no se combinan, que Calc no vende power banks y la **economía de 90 puntos por pista (450 en total)**. Solo documentación: no cambia código, datos, escenas, arte ni pruebas. Los valores son orientativos y se ajustan jugando en `data/upgrades.json`. Lo no decidido va como pregunta (§11).

**Idea del usuario (aprobada en líneas generales):** la tienda de Calc pasa de una lista de mejoras sueltas a **cinco mejoras únicas**, una por acción: **Pulso, Láser, Debug, Sync Rate y Energía**. Cada una tiene un chip con el icono de la acción y **5 niveles** (5 barras): la primera llena de inicio y las otras cuatro se compran. El Debug solo sale en la tienda tras obtenerlo (piso 2 del 1-2); mientras, su chip aparece bloqueado con «?». Ejemplo del usuario para el Pulso: nivel 2 más distancia, nivel 3 más aturdimiento, nivel 4 te oculta temporalmente.

**Decisiones que respeta:**

- **Economía (opción 2):** todo se puede comprar **dentro de las tres vueltas** (Caché, Kernel, Raíz; internamente vueltas 1-3). Los puntos de atención solo vuelven con el rollback; ≈ 9 por mapa (6 en la ruta y 3 en secretos) × 18 mapas = 162 por vuelta como mucho.
- **Coste (decisión del usuario, 2026-10-16):** cada pista cuesta **90 puntos en total** (sus 4 compras, niveles 2-5): **450** entre las cinco, «para que los jugadores tengan que buscar». El nivel 1 es gratis y el nivel 5 pide además 1 power bank. Sustituye a la tabla anterior de 320 (10 / 15 / 15 / 20).
- **Tope por vuelta** (propuesta del orquestador, aprobada por silencio): Caché hasta el nivel 3, Kernel hasta el 4 y Raíz hasta el 5. Esto responde a la duda abierta «mejoras por vuelta» de `preguntas.md`.
- **Las mejoras se conservan entre vueltas**: el rollback (game over o jefe final) las manda a la Papelera junto con lo demás y se recuperan (`propuesta-asistentes-y-vidas.md` §5.3). Un game over sin guardar pierde las compras posteriores a la última copia, como hoy.
- **Ocultarte** (Pulso nivel 4) consume Sync Rate y energía mientras dura y se apaga solo cuando el Sync **o** la energía llegan al 10 %, el primero que llegue (aprobado el 2026-10-16). No se combina con el Debug (aprobado).
- **Regeneración pasiva** solo con Sync Rate 5 y Energía 5 (aprobado el 2026-10-16). **Calc no vende power banks** (aprobado): vienen de los mapas, tope de 3 a la vez, y el del nivel 5 se gasta al comprarlo.
- **Energía nivel 5:** no sube la capacidad; da **recarga pasiva**.
- La UI nunca dice vuelta, Easy, Normal ni Hard: usa Caché, Kernel y Raíz.
- El Pulso amplio (25 puntos, precio que se mantiene) pasa a ser el nivel 2 del Pulso, y «Debug eficiente», que se quedó sin secreto al cambiar el secreto D por la vida extra, pasa a ser el nivel 2 del Debug.

---

## 1. Concepto y UI de Calc

Calc es literal, seca y lógica (`04-personajes.md` §12.3): precios fijos y nada de sorpresas. La tienda es una pantalla de **cinco chips en fila**, uno por acción, cada uno con **5 barras** debajo. Sustituye a la lista actual de `CalcPanel` y usa la misma base (`HubPanel`): Isak está de espaldas a Calc y el panel se abre con el pulso.

```
 Puntos 37   Power banks 1 (+60 %)                    Sin guardar
 [PULSO]  [LÁSER]  [ ? ]   [SYNC]  [ENERGÍA]
  ■■□▣▣    ■■■▣▣   ▣▣▣▣▣   ■□□▣▣    ■■□▣▣
 ─────────────────────────────────────────────────
 Pulso · Nivel 2 de 5
 Siguiente, nivel 3: Aturdimiento 3,0 s a 4,5 s
 Coste: 15 puntos                         Disponible
```

| Estado de una barra | Aspecto (sin rojos) | Cuándo |
|---|---|---|
| **Llena** | Rellena en `acento_cian` | Nivel ya comprado; la 1.ª siempre está llena |
| **Siguiente** | Contorno ámbar (color de los puntos) que late suave | El próximo nivel que se puede comprar en este acceso |
| **Vacía** | Solo el contorno gris azulado | Comprable en este acceso, pero aún no es el siguiente |
| **Bloqueada por acceso** | Gris oscuro con un mini candado | Por encima del tope del acceso actual (nivel 4 en Caché, nivel 5 en Caché y Kernel) |
| **Chip «?»** | Silueta del chip con «?» y las 5 barras grises | Debug (o Láser) sin la habilidad obtenida (§7.4) |

**Controles:** `move_left` / `move_right` eligen chip, `pulse` compra y `jump` cierra (igual que hoy; `move_up` / `move_down` también eligen, por coherencia con los demás paneles). Al comprar sale una confirmación de dos opciones («¿Instalar nivel 3? Instalar / Volver»), porque la compra no se devuelve. Comprar solo marca «sin guardar»: se guarda en Notas.

**Detalle de la pista elegida** (bajo la fila de chips):

| Línea | Ejemplo |
|---|---|
| Nombre y nivel | «Pulso · Nivel 2 de 5» |
| Siguiente efecto | «Siguiente, nivel 3: Aturdimiento 3,0 s a 4,5 s» (formato actual `<label>: <base> a <value>`, con «a» y no flecha, por los glifos de la fuente) |
| Coste | «Coste: 15 puntos» o «Coste: 25 puntos + 1 power bank» |
| Estado | Disponible · Faltan puntos · Falta power bank · «Requiere acceso: Kernel» · «Completa» |
| Chip «?» | «???» sin nombre ni efecto, como las fichas del álbum |

**Mensajes de interfaz** (borrador; los textos con voz de Calc los decide el usuario): «Nivel 3 instalado.», «Faltan 8 puntos.», «Falta un power bank completo.», «Disponible con acceso Kernel.», «Esta mejora está completa.». En el HUD del hub, sin cambios: puntos, power banks y «Sin guardar».

---

## 2. Efectos por pista y nivel (propuesta, ajustable)

El nivel 1 es el valor base de hoy. Cada nivel **suma** su efecto a los anteriores: el nivel 4 del Pulso conserva el alcance del 2 y el aturdimiento del 3.

| Pista | Nivel 2 | Nivel 3 | Nivel 4 | Nivel 5 |
|---|---|---|---|---|
| **Pulso** (icono: onda del celular) | **Alcance:** radio 96 a 112 px (Pulso amplio, `wide_pulse`) | **Aturdimiento:** ×1,5 (Burbuja 3,0 a 4,5 s; el aviso final de 0,75 s no cambia) | **Ocultarte** (§4) | **Pulso de retorno:** aturdir a un enemigo da +4 de energía, una vez por enemigo y por intento; no desborda a los power banks |
| **Láser** (icono: haz) | **Enfriamiento:** 0,4 a 0,3 s | **Coste:** 10 a 8 de energía | **Daño:** 1 a 2 (la Burbuja cae de un disparo) | **Perfora:** atraviesa enemigos (no terreno ni objetos de puzle) |
| **Debug** (icono: ojo entre corchetes) | **Gasto:** 20 a 15/s (Debug eficiente, `efficient_debug`; 5,0 a 6,7 s con la barra a 100) | **Revelado persistente:** lo revelado sigue visible y sólido 1,5 s tras apagar el Debug (0 de base) | **Ralentización:** mundo ×0,5 a ×0,4 | **Arranque rápido:** carga 1,0 a 0,4 s (`quick_start`) |
| **Sync Rate** (icono: señal) | Máximo 100 a 110 | 110 a 120 | 120 a 130 | **Resincronización:** regeneración fuera de combate (§6) |
| **Energía** (icono: batería) | Máximo 100 a 110 | 110 a 120 | 120 a 130 | **Recarga pasiva:** 0,5 % del máximo por segundo (§5.2) |

**Notas por pista:**

- **Pulso 5 (Pulso de retorno):** une la herramienta gratuita y segura con la economía de energía, sin solaparse con Agitar (Mundo 4, aturde en área) ni con el dash de Deslizar (Mundo 1). No obliga a pulsar en el aire ni cambia lo que el pulso puede activar. «Una vez por enemigo y por intento» evita sacar energía sin fin de una Burbuja que se aturde una y otra vez.
- **Debug 3 (cambio sobre el borrador «más alcance de revelado»):** el Debug de hoy revela **toda la pantalla**: no hay radio que ampliar. Se propone la persistencia de 1,5 s, que da más margen al cruzar plataformas `h` (si se apaga encima, hoy se cae). Si el usuario prefiere un alcance de verdad, haría falta definir antes un radio de revelado (pregunta 5).
- **Debug 5:** reutiliza la mejora existente «Arranque rápido» (0,5 s hoy; se propone 0,4 s para el último nivel).
- **Láser 5 (perforación):** el haz atraviesa los cuerpos de la capa `enemy` y daña a cada enemigo que cruza (una vez por enemigo y disparo). Sigue chocando con el terreno y con los objetos del láser (lector, anuncio, botón «Posponer», receptor). Un enemigo **inmune** (el punto rojo despierto, si se aprueba esa regla del 1-2) detiene el haz con su chispa gris, para que se lea igual que hoy. Impacto en el 1-2 en §8.
- **Sync y Energía:** +10 por nivel (poco significativo; antes «Batería ampliada» daba +50 y «Sync reforzado» +20 de golpe). +10 de energía = un disparo más o 0,5 s más de Debug.
- **Se retira** «Recarga mejorada» (energía por punto 10 a 15): no encaja en ninguna pista y la Energía 5 ya da recarga. Migración en §7.

---

## 3. Economía

### 3.1 Presupuesto

| Concepto | Valor |
|---|---|
| Puntos por mapa | ≈ 9 (6 en la ruta y 3 en secretos) |
| Por vuelta (18 mapas) | 162 recogiéndolo todo; 108 solo con la ruta |
| Tres vueltas | 486 con todo; 324 solo con la ruta |
| Compras | 5 pistas × 4 niveles = **20** |

### 3.2 Costes (90 por pista; reparto propuesto)

Total aprobado: **90 por pista, 450 en total**. El reparto por nivel es propuesta (pregunta 6 de §11). Regla general: **15 / 20 / 30 / 25 + 1 power bank**; el nivel 5 cuesta menos puntos que el 4 porque además gasta un power bank, y así el acumulado de Kernel cabe en lo que se gana (§3.4). Excepción heredada: **Pulso 2 = 25** (el Pulso amplio de siempre), y el resto del Pulso se reparte en 15 / 25 / 25 para sumar 90.

| Pista | Nv 2 | Nv 3 | Nv 4 | Nv 5 | Total |
|---|---|---|---|---|---|
| Pulso | **25** | 15 | 25 | 25 + 1 PB | 90 |
| Láser | 15 | 20 | 30 | 25 + 1 PB | 90 |
| Debug | 15 | 20 | 30 | 25 + 1 PB | 90 |
| Sync Rate | 15 | 20 | 30 | 25 + 1 PB | 90 |
| Energía | 15 | 20 | 30 | 25 + 1 PB | 90 |
| **Total** | 85 | 95 | 145 | 125 + 5 PB | **450 puntos + 5 power banks** |

Debug 2 (el antiguo «Debug eficiente», 60 + 1 PB pensado para seis mejoras sueltas) cuesta 15, como los demás niveles 2.

### 3.3 Por vuelta (con el tope Caché 3 / Kernel 4 / Raíz 5)

| Acceso | Se abre | Coste de lo que se abre | Acumulado abierto | Ganable acumulado (100 %) |
|---|---|---|---|---|
| Caché | Niveles 2 y 3 | 180 | 180 | 162 |
| Kernel | Nivel 4 | 145 | 325 | 324 |
| Raíz | Nivel 5 | 125 + 5 PB | 450 | 486 |

Lo abierto en Caché y Kernel es siempre **al menos** lo que se puede ganar hasta ese momento: nunca sobran puntos sin nada que comprar antes de Raíz. Los puntos no gastados se conservan de una vuelta a otra. La compra más cara de los niveles 2-3 es de 25, muy por debajo de lo ganable al terminar Caché (162 con todo, ≈ 150 con el 93 %). Los topes aprobados se mantienen.

### 3.4 Comprobación numérica (script temporal, fuera del repo)

Puntos acumulados al terminar cada vuelta según el porcentaje recogido, frente al acumulado abierto de §3.3:

| Recogido | Fin de Caché (vs 180) | Fin de Kernel (vs 325) | Fin de Raíz (vs 450) | Margen final |
|---|---|---|---|---|
| 100 % | 162 | 324 | 486 | **+36 (8 %)** |
| 95 % | 154 | 308 | 462 | **+12 (3 %)** |
| **≈ 93 % (equilibrio)** | 150 | 300 | 450 | **0** |
| 90 % | 146 | 292 | 437 | −13 (no llega) |
| 85 % | 138 | 275 | 413 | −37 (no llega) |
| Solo la ruta (≈ 67 %) | 108 | 216 | 324 | −126 |

**Lectura:**

- **Exigente a propósito** (decisión del usuario): comprarlo todo pide recoger ≈ **93 %** de los 486 puntos de las tres vueltas (450 / 486). Con toda la ruta (324), hacen falta ≈ **78 %** de los puntos de secretos (126 de 162). El jugador tiene que buscar secretos; quien no los busca compra unas dos terceras partes.
- Con un 85-90 % faltan de 13 a 37 puntos: queda sin comprar uno o dos niveles altos (un nivel 5 cuesta 25). El margen con todo es de solo +36.
- En ninguna vuelta sobran puntos sin nada que comprar (con el 100 %, Kernel queda a 1 punto); en Caché siempre hay que elegir (se abren 180 y se ganan como mucho 162).
- **Comprobaciones de `tests/test_level_schema.py`** (hoy leen `data/upgrades.json`; cuando el catálogo pase a pistas, leerán sus niveles): un mapa (9) no paga ninguna compra (mínimo 15); tres mapas completos (27) pagan el Pulso 2 (25) y sobran menos de 5; la ruta de tres mapas (18) no llega a 25; la suma (450) supera una vuelta (162). Las cuatro siguen valiendo con 25 en el Pulso 2.
- **Ritmo:** al conocer a Calc al final del 1-2 (unos 18 puntos) ya se puede comprar un nivel 2 de 15 (Láser, Debug, Sync o Energía). El Pulso 2 sigue pagándose al terminar el 1-3.

**Alternativas:**

- **Reparto 15 / 20 / 25 / 30** (más «niveles altos, más caros»): Caché abre 180, Kernel 300 y Raíz 450. Con el 100 % quedarían 24 puntos sin nada que comprar al terminar Kernel (8 con el 95 %); para evitarlo habría que abrir algo más en Kernel (cambio de tope, no recomendado).
- **Pulso 2 a 15** (todo igual en las cinco pistas): rompe dos de las cuatro comprobaciones (tres mapas sobrarían 12; la ruta de tres mapas, 18, ya pagaría) y el texto del 1-1, del 1-2 y de `CLAUDE.md` («Pulso amplio cuesta 25 = tres mapas»). No se recomienda (§11, pregunta 7).

### 3.5 Power banks en la economía

Solo los pide el nivel 5 (5 power banks completos en toda la partida, todos en Raíz), además de sus puntos. Los niveles 2-4 ya no los piden (antes Sync reforzado, Debug eficiente y Batería ampliada pedían uno). Calc no los vende (aprobado). Detalle en §5.1.

---

## 4. Ocultarte (Pulso nivel 4)

| Aspecto | Propuesta |
|---|---|
| **Qué es** | Un estado activo: Isak se vuelve casi invisible para los enemigos que «ven». No es invulnerabilidad. |
| **Acción** | **Acción nueva `hide`**: **H** / **L3** (pulsar el stick izquierdo; están libres G, F, K, Q, L, I y U, y en el mando B, RB y LB son gestos). Va en la lista de `ControlBindings` (reasignable en Ajustes > Controles) y su aviso de control en `data/ability_notices.json` («Ocultarte: H / L3 (mando)»), leído del Input Map como los demás. Mantener el pulso se descarta porque chocaría con la pose del pulso y con `gesture_hold` (Mundo 2). |
| **Activar / desactivar** | Pulsación corta para activar, solo en el suelo y fuera de una pose, como el pulso; otra pulsación corta para desactivar (en el suelo o en el aire). Entrada y salida de 0,2 s. |
| **Coste** | **Energía 5/s** y **Sync Rate 1,5/s**, en tiempo real (como el Debug). Desde el máximo base: 18 s hasta el corte por energía y 60 s por Sync. Un uso típico de 6 s cuesta 30 de energía y 9 de Sync, casi un golpe de Burbuja (10). |
| **Corte automático (10 %)** | Se apaga solo cuando el **Sync Rate O la energía** llegan al **10 % de su máximo efectivo** (10 con 100, 13 con 130). Para activarlo hace falta más del 15 % de ambos (evita encender y apagar sin parar). Nunca puede matar: el gasto de Sync se detiene en el 10 %. **Aprobado (2026-10-16):** se corta con el primero de los dos que llegue al 10 %. |
| **Avisos** | Un icono pequeño de «oculto» junto a la batería del HUD mientras dura. Por debajo del 20 % de cualquiera de las dos barras el icono parpadea (la señal ya se pone roja por debajo del 20 % por el Sync bajo). Al cortarse solo: destello del glitch y sonido corto. |
| **Movimiento** | Camina y salta; **no corre** (la acción `run` se ignora mientras dure). |
| **Láser y pulso** | **Atacar te revela:** el pulso y el láser salen con normalidad, pero desactivan el Ocultarte al empezar la pose. Se descarta disparar oculto, porque convertiría a los jefes en tiro al blanco desde un sitio seguro. |
| **Debug** | **No se combinan:** activar uno apaga el otro. Los dos gastan la misma energía (20 + 5/s vaciarían la barra en 4 s) y así cada uno se lee por separado. **Aprobado (2026-10-16).** |
| **Recibir daño** | Te revela (se apaga) y se aplican el golpe y la invulnerabilidad de siempre. |
| **Recargas** | Se pueden recoger puntos, drops y cargadores. Ni la Energía 5 ni el Sync 5 recargan mientras dura. |

**Qué ven los enemigos:**

| Enemigo | Reacción |
|---|---|
| **Perseguidores** (punto rojo del 1-2 y los que vengan) | Pierden el rastro: se detienen 1 s con un «?» y vuelven a su punto de patrulla o de espera. Si Isak se revela a menos de su rango de detección, lo vuelven a ver. |
| **Burbuja de alerta** y patrullas | Nada cambia: siguen su ruta y dañan al contacto. No miran a Isak. |
| **Proyectiles y torretas** que apuntan a Isak | No disparan mientras dure; los ya lanzados siguen su trayectoria. |
| **Jefes** | Cada jefe decide (ideas abajo). Por defecto, sin efecto. |

**Ideas de uso en jefes (futuras, no implementar; solo mecánica):** el Ocultarte llega en Kernel (vuelta 2) como pronto, así que ningún jefe de Caché puede exigirlo.

1. **Jefes que solo atacan lo que ven** (*futura*): La Curadora (Mundo 3, fase 1) dispara flashes de foto contra Isak; oculto, el flash no lo «captura» y se abre el hueco para golpear.
2. **El núcleo que se revela al buscarte** (*futura*): el jefe pierde de vista a Isak, lo busca y se gira, y deja a la vista su punto débil trasero. Encaja con el botón «Cancelar» de la espalda de El Vendedor (Mundo 5).
3. **Ataque dirigido que se pierde** (*futura*): en la fase 3 de El Visto (Mundo 4), el «escribiendo…» apunta a Isak; ocultarse justo antes de que se envíe hace que falle. Con Isak Optimizado (Mundo 6) **no** debe sustituir a la fase 3 («detenerse»): conviene que el Ocultarte no tenga efecto en ese jefe.

**Efecto visual (por código, sin AutoSprite):** Isak al 45 % de opacidad con un glitch de filas horizontales que se desplazan 1-2 px y un contorno de 1 px en el cian de la chaqueta (`acento_cian`, `#3dfff5`), el mismo en todos los mundos para no confundirlo con el color del Debug del mundo. Sin rojos. Eco también se atenúa mientras dure.

---

## 5. Power banks y pista de Energía

### 5.1 Power banks: tope de 3

| Aspecto | Propuesta |
|---|---|
| **Tope** | **3 power banks en total** (completos + vacíos) a la vez, en toda la partida; no crece con las mejoras. |
| **Por qué 3** | La partida pide 5 completos, todos en Raíz (§3.5). Con 3 se llega a Raíz con 3 ya cargados de Caché y Kernel, y faltan 2, que se consiguen allí (el rollback devuelve los power banks de mapa). Con 4 se llegaría casi sin tener que cargar nada en Raíz. El HUD sigue con «x1-x3» pequeño. |
| **Pickup con el tope lleno** | El `power_bank_pickup` no se recoge: Isak lo atraviesa, sale «Sin espacio» y el objeto se queda en el mapa (no se apunta en `collected_pickups`), así que se puede volver a por él. Su Q lo explica. |
| **Capacidad** | Sigue en **200** de energía cada uno (dos barras base). |
| **Carga** | Sin cambios: solo el sobrante de los **drops** con la barra llena (los puntos de atención no desbordan). Sin power banks vacíos, el sobrante se pierde. |
| **Compra en Calc** | **No se venden** (aprobado el 2026-10-16). Llegan de los mapas: el 1-1 y el 1-2 ya tienen uno cada uno, y se propone al menos uno por mundo y vuelta. Al pagar un nivel 5, el power bank completo se gasta y desaparece (aprobado; resuelve la duda 2 de «power banks» de `preguntas.md`). |

### 5.2 Energía: máximo y recarga pasiva

Niveles 2-4: máximo 100 → 110 → 120 → 130. Nivel 5: **la capacidad no sube** (se queda en 130) y se gana la **recarga pasiva**.

**Valor:** el **0,005 %/s** del borrador sería imperceptible: con 100 de máximo son 0,005 de energía por segundo, **2000 s (33 min) para recuperar un disparo** de láser (10) y 5,6 h para llenar la barra. Se propone el **0,5 % del máximo por segundo**:

| Recarga | Por segundo (máx. 130) | Un disparo (10; 8 con el Láser 3) | Barra completa |
|---|---|---|---|
| 0,005 %/s (borrador) | 0,0065 | 1538 s | 5,6 h |
| 0,3 %/s | 0,39 | 26 s | 333 s |
| **0,5 %/s (propuesta)** | **0,65** | **15 s (12 s)** | **200 s** |
| 1 %/s | 1,3 | 8 s | 100 s |

Para comparar: el Debug gasta 20/s (30 veces más) y un cargador da 50 cada 20 s (2,5/s). La recarga solo ayuda entre zonas: no permite sostener el Debug ni disparar sin parar.

**Cuándo se aplica:** en tiempo del mundo, solo en los niveles (no en el hub, que ya llena las barras al entrar y tiene cargador) y **3 s después del último gasto** de energía (disparo, Debug u Ocultarte). No se aplica con el Debug o el Ocultarte activos, en pausa, en las líneas de historia, en la animación de muerte ni con la barra llena. **Nunca desborda** a los power banks. Se reinicia al reaparecer.

---

## 6. Sync Rate

Niveles 2-4: máximo 100 → 110 → 120 → 130. El HUD ya muestra más de 100 % (como con Sync reforzado) y el nivel llena la barra al máximo efectivo al empezar.

**Nivel 5, Resincronización (propuesta):** fuera de combate, el Sync Rate se regenera al **1 por segundo** hasta el **60 % del máximo** (78 con 130). «Fuera de combate» quiere decir 6 s sin recibir daño ni disparar ni lanzar el pulso, sin un jefe activo y sin un perseguidor en estado de persecución. No sube por encima del 60 %: las recargas de Sync de los drops y del checkpoint siguen siendo la curación de verdad.

- **Por qué la regeneración y no +10 de máximo:** los niveles 2-4 ya suben el máximo; el 5 tiene identidad propia y suaviza el final del juego sin quitar tensión (no cura durante un combate ni por encima del 60 %).
- **Choque con una decisión anterior:** en «Notas del paso 9» (`preguntas.md`, ~l. 320) quedó «no hay regeneración pasiva ni curación», con las recargas aún por decidir (después se decidieron los drops). Esta propuesta **la cambia solo para el nivel 5 del Sync y de la Energía**: sin esas mejoras, la regla sigue igual. **Aprobado por el usuario el 2026-10-16.**

---

## 7. Migración de lo existente

### 7.1 `data/upgrades.json` (catálogo nuevo, mismo archivo)

Cambia a **pistas** con niveles; las mejoras de hoy pasan a ser niveles o se retiran:

```json
{"tracks": [{"id": "pulse", "name": "Pulso", "requires_ability": "pulse", "icon": "pulse",
  "levels": [
    {"level": 2, "legacy_id": "wide_pulse", "min_lap": 1, "label": "Alcance", "unit": " px",
     "effects": [{"target": "isak_abilities.pulse_radius_px", "value": 112.0}],
     "cost": {"attention_points": 25, "power_banks": 0}}]}]}
```

- `min_lap`: 1 para los niveles 2-3, 2 para el 4 y 3 para el 5 (el tope por vuelta va en los datos, no en el código).
- `effects` admite varios destinos. Los valores efectivos siguen la regla de hoy (`effective_value`): gana el nivel comprado más alto que toque ese destino, sin tocar los JSON base.
- **Destinos nuevos:** `isak_abilities.pulse_stun_multiplier` (1,0), `isak_abilities.pulse_energy_on_stun` (0), `isak_abilities.laser_pierce` (0/1), `debug_mode.reveal_linger_s` (0), `game_state.energy_regen_pct_s` (0), `game_state.sync_regen_*` (0) y `ability.hide` (Ocultarte desbloqueado).
- `legacy_id` mantiene los ids que ya usan los niveles y las pruebas (`requires_upgrade: "wide_pulse"` del 1-1).

| Mejora de hoy | Pasa a ser | Valor de hoy → valor nuevo |
|---|---|---|
| `wide_pulse` Pulso amplio (25) | Pulso 2 (25) | 112 px → igual |
| `efficient_debug` Debug eficiente (60 + 1 PB) | Debug 2 (15) | 15/s → igual |
| `quick_start` Arranque rápido (20) | Debug 5 (25 + 1 PB) | 0,5 s → 0,4 s |
| `reinforced_sync` Sync reforzado (45 + 1 PB) | Sync 2-3 | 120 → 110 (nv 2) y 120 (nv 3) |
| `extended_battery` Batería ampliada (35 + 1 PB) | Energía 2-4 | 150 → 110 / 120 / 130 |
| `improved_recharge` Recarga mejorada (25) | **Se retira** | — |

### 7.2 `GameState`

- `purchased_upgrades` (id → true) pasa a ser **`upgrade_levels`** (pista → nivel, de 1 a 5).
- `purchase_upgrade(id)` pasa a ser `purchase_level(track)`. Compra el siguiente nivel y `check_purchase` añade los motivos `LAP_LOCKED` (por encima del tope del acceso, con `lap`) y `ABILITY_MISSING` (chip «?»).
- `is_upgrade_purchased(legacy_id)` se mantiene para los secretos.
- `get_debug_energy_max()` y `get_sync_rate_max()` no cambian de firma (`DEBUG_ENERGY_MAX` = 100 sigue siendo la base).
- Funciones nuevas: el tope de power banks (`can_take_power_bank()`), la recarga pasiva y el estado del Ocultarte.

### 7.3 Guardado v4

Campo **`upgrade_levels`**: `{"pulse": 2, "laser": 1, "debug": 1, "sync": 1, "energy": 1}`. Sustituye a `upgrades_purchased`.

**Migración v3 → v4** (sin perder nada pagado):

| Compra antigua | Se convierte en | Se devuelve |
|---|---|---|
| `wide_pulse` | Pulso 2 | 0 |
| `efficient_debug` | Debug 2 | 45 puntos + 1 PB completo |
| `reinforced_sync` | Sync 2 | 30 puntos + 1 PB |
| `extended_battery` | Energía 2 | 20 puntos + 1 PB |
| `quick_start` | (el Debug 5 exige los niveles 2-4 y Raíz) | 20 puntos |
| `improved_recharge` | (retirada) | 25 puntos |

Devolución = precio pagado − precio del nivel nuevo (con los costes de §3.2). Los power banks devueltos pueden superar el tope de 3 (el tope solo impide recoger más; no se borra nada). Hoy estas compras solo existen en guardados de prueba: Calc está apagada hasta el 1-2.

### 7.4 Rollback, Papelera y chip «?»

- **Papelera:** `TRASH_UPGRADES` guarda el diccionario de niveles en lugar de la lista de ids. «Eco desecha lo guardado» y la recuperación funcionan igual; las mejoras se conservan entre vueltas (el rollback de vuelta usa la misma regla, `apply_rollback`).
- **Al subir de vuelta**, `lap` sube y se abren los niveles del acceso siguiente. Nada se pierde.
- **Chip «?»:** la pista del Debug (y la del Láser) se muestra con «?» mientras la habilidad no esté **obtenida** en la partida actual. Pasa en la práctica si un game over devuelve a una copia sin el Debug pero con Calc conocida (Calc es registro y no se pierde). Los niveles ya comprados se conservan: vuelven a verse y a aplicarse al recuperar la habilidad.

---

## 8. Impacto en el 1-2, en el 1-1 y en los validadores y el bot

- **Regla general:** ninguna mejora es obligatoria en la ruta. La meta de todo nivel se alcanza con los valores base (como hoy). Las mejoras solo **facilitan**: más alcance, más tiempo, menos coste, más daño, más margen. Ningún nivel baja un valor.
- **1-1:** el secreto del power bank sigue exigiendo `wide_pulse` (= Pulso 2: 104 px entre 96 y 112). El Láser 3 (8 de energía) y la Energía 2-4 solo dan holgura. El Ocultarte no afecta a las Burbujas.
- **1-2 (vuelta Caché; la primera vez, sin mejoras, porque Calc llega al final):**
  - Al rejugarlo en Caché puede haber hasta el nivel 3: pulso de 112 px con 4,5 s de aturdimiento (más ventana en el patrón 1 y en las Burbujas escalón), láser de 0,3 s y 8 de energía (el acertijo pasa de 20 a 16 de energía mínima), Debug de 15/s con revelado persistente (más fácil cruzar 2c y el secreto A) y barras de hasta 120. Todo hace el nivel más fácil; nada lo rompe.
  - **Láser 5 (Raíz):** como no atraviesa ni el terreno ni los objetos del láser, el lector, el anuncio y el «Posponer» funcionan igual. Lo único que cambia es que un enemigo ya no tapa un objetivo. Los niveles de Raíz deben diseñarse sabiéndolo; en el 1-2 de Caché no aplica.
  - **Ocultarte (Kernel):** los puntos rojos pierden el rastro; los niveles de Kernel con perseguidores deben contar con él.
- **Validador (`tools/validate_level.py`):** ya usa los valores base y `--upgrades`. Se propone:
  1. Aceptar `--upgrades pulse:2,laser:3` (pista:nivel) además de los `legacy_id`, leyendo los valores de `data/upgrades.json`, la misma fuente que el juego.
  2. `requires_upgrade` admite `"pulse:2"` o el `legacy_id`.
  3. En cada pasada, comprobar con los valores base y con el **tope del acceso del nivel** (`lap` del JSON del nivel: Caché = todos los niveles 3). Un secreto con `requires_upgrade` no se alcanza sin la mejora y sí con ella; la meta, siempre con la base.
  4. Si el validador modela la energía (acertijos con coste obligatorio), usar `get_laser_energy_cost` y el gasto del Debug base para el mínimo y no contar con la recarga pasiva.
  5. Ignorar el Ocultarte.
- **Pruebas de economía (`tests/test_level_schema.py`):** las cuatro comprobaciones de hoy pasan a leer los niveles de las pistas. Se añaden tres: «cada pista suma 90 y el total, 450, cabe en 3 × 162 = 486», «hace falta más del 90 % de 486 para pagarlo todo» (exigente a propósito) y «en Caché y Kernel el acumulado abierto (180 y 325) no es menor que lo ganable (162 y 324)».
- **Bot (`tools/play_level_bot.gd`):** sin cambios (juega sin mejoras ni Ocultarte). Las pruebas de la tienda usan `EcoProgress.meet_calc()`.
- **Coordinación:** el validador, las pruebas del esquema y el 1-2 los está tocando otro agente ahora. Los pasos 1 y 9 de §10 deben ir después de que eso se cierre.

---

## 9. Arte necesario (por script, sin AutoSprite)

| Pieza | Herramienta propuesta | Detalle |
|---|---|---|
| 5 chips de acción + chip «?» | `tools/gen_calc_chips.py` (nuevo; validador `tools/validate_calc_chips.py`) | Chip de 32 × 32 px de arte, con iconos de onda, haz, ojo entre corchetes, señal (la del HUD) y batería (la del HUD, de `tools/gen_hud_assets.py`); estado normal y elegido (marco cian). «?» con la silueta del chip. |
| Barras de nivel | El mismo script | 6 × 10 px por barra en los estados llena, siguiente (dos cuadros del latido), vacía y bloqueada (mini candado 5 × 5). |
| Icono «oculto» del HUD | `tools/gen_hud_assets.py` (añadir) | Silueta de Isak discontinua en cian, con dos cuadros para el parpadeo por debajo del 20 %. |
| Efecto de Ocultarte | Por código (shader o `modulate`) | Opacidad del 45 %, desplazamiento de filas y contorno cian (§4). Sin hoja nueva de Isak. |
| «?» de un perseguidor que pierde el rastro | Por código o una textura pequeña del script de enemigos | Dos cuadros. |
| Panel de Calc | `CalcPanel` (código) | Fila de chips y detalle, con la fuente y la paleta del hub de siempre (la paleta del hub sigue abierta: valores provisionales). |

---

## 10. Plan de implementación (pasos pequeños)

| # | Paso | Tamaño | Depende de | Pruebas |
|---|---|---|---|---|
| 1 | Catálogo por pistas en `data/upgrades.json` + `UpgradeCatalog` (niveles, `min_lap`, `legacy_id`, efectos múltiples) + `effective_value` por nivel | M | Cierre del trabajo actual en el validador y las pruebas | GUT del catálogo; los valores efectivos de los niveles 1-5 |
| 2 | `GameState`: `upgrade_levels`, `purchase_level`, `LAP_LOCKED` / `ABILITY_MISSING`, coste de power bank en el nivel 5 | M | 1 | GUT de compras, del tope por acceso y del chip «?» |
| 3 | Guardado v4, migración v3 → v4 con devoluciones y Papelera con niveles | M | 2 | GUT de migración (cada caso de §7.3) y del ciclo rollback → Papelera → recuperar |
| 4 | Efectos simples por destinos existentes (radio, enfriamiento, coste, daño, gasto, escala y carga del Debug, máximos) | S | 1 | GUT por efecto |
| 5 | Efectos nuevos: multiplicador de aturdimiento, Pulso de retorno, perforación, revelado persistente | M | 4 | GUT; escena de la Burbuja con el láser que perfora |
| 6 | Tope de 3 power banks («Sin espacio», el pickup se queda) | S | 2 | GUT de `can_take_power_bank` y del pickup |
| 7 | Recarga pasiva de Energía 5 y Resincronización de Sync 5 | S | 4 | GUT con tiempos (3 s y 6 s de espera, el 60 %, sin Debug) |
| 8 | Ocultarte: acción `hide` (Input Map, `ControlBindings`, aviso), estado, costes, corte al 10 %, enemigos (`is_player_hidden()`), efecto e icono del HUD | L | 2 y 4 | GUT del estado y del corte; prueba del perseguidor cuando exista |
| 9 | Validador y economía: `--upgrades pista:nivel`, pasada con el tope del acceso, pruebas de §8 | S | 1 | `tools/run_tests.sh` |
| 10 | Arte: `gen_calc_chips.py` + validador e icono «oculto» | M | — | Su validador |
| 11 | `CalcPanel` con chips, barras, detalle, confirmación y mensajes | L | 2, 3 y 10 | GUT del panel; capturas con `tools/render_hub.gd` |
| 12 | Documentación (05, 02, CLAUDE.md «Cómo ejecutar») y capturas | S | 11 | — |

Orden sugerido: 1 → 2 → 3 → 4 → 6 → 7 → 5 → 9 → 10 → 11 → 8 → 12. El Ocultarte puede ir al final, porque no hace falta hasta Kernel.

---

## 11. Preguntas abiertas (con recomendación por defecto)

**Resueltas el 2026-10-16 (decisiones del usuario):** regeneración pasiva solo con Sync 5 y Energía 5; corte del Ocultarte con el Sync **o** la energía al 10 % (el primero que llegue); Ocultarte y Debug no se combinan; Calc no vende power banks (de los mapas, tope de 3, se gastan al comprar el nivel 5); 90 puntos por pista, 450 en total.

1. **Debug 3:** ¿revelado persistente (1,5 s tras apagar) o un radio de revelado nuevo? *Recomendación:* persistente (hoy el Debug revela toda la pantalla).
2. **Pulso 5 «Pulso de retorno»** (+4 de energía al aturdir, una vez por enemigo y por intento): ¿se acepta? *Recomendación:* sí.
3. **¿Confirmación al comprar?** *Recomendación:* sí («Instalar / Volver»), porque no hay devoluciones.
4. **Tecla del Ocultarte:** ¿H / L3? *Recomendación:* sí, reasignable.
5. **¿Atacar revela (el pulso y el láser apagan el Ocultarte)?** *Recomendación:* sí.
6. **Reparto de los 90 por nivel** (§3.2): ¿15 / 20 / 30 / 25 + 1 PB (Pulso 25 / 15 / 25 / 25), o 15 / 20 / 25 / 30 con unos puntos sin gastar al terminar Kernel? *Recomendación:* 15 / 20 / 30 / 25, y revisarlo tras un mundo completo.
7. **Precio del Pulso 2 (Pulso amplio):** ¿se mantiene en 25 o baja a 15 como los demás niveles 2? *Recomendación:* mantener 25: las cuatro comprobaciones de `tests/test_level_schema.py` y los textos del 1-1 siguen igual y el guardado no necesita devolución. Bajarlo a 15 obliga a cambiar dos comprobaciones (tres mapas completos sobrarían 12; la ruta de tres mapas ya pagaría), los textos del 1-1, del 1-2 y de `CLAUDE.md`, y a devolver 10 puntos en la migración a quien lo compró. Debug 2 a 15: sin pruebas afectadas; la migración devuelve 45 + 1 PB (§7.3).

---

## Tanda M1 (hecha el 2026-10-17)

Pasos 1-4, 10 y 11 de §10 y el validador y la economía del paso 9. Decisiones de la aprobación (2026-10-17): la tienda muestra cada pista como una **fila** (chip y 5 recuadros, el primero cargado); el selector va arriba/abajo como en los demás paneles; el detalle dice el **nombre y la descripción del siguiente nivel** y su coste; el pulso compra **sin confirmación** (cambia la recomendación 3 de §11); los recuadros por encima del tope salen con candado y «Requiere acceso Kernel / Raíz» (nunca vuelta ni Easy/Normal/Hard). Ids de pista (guardado y validador): `pulso`, `laser`, `debug`, `sync`, `energia`.

| Paso | Qué se hizo |
|---|---|
| 1. Catálogo | `data/upgrades.json` reescrito con `tracks` → `levels` (nivel 1-5, `name`, `description`, `cost` {puntos, power banks}, `min_lap` —tope por acceso en los datos: 1 para los niveles 1-3, 2 para el 4 y 3 para el 5—, `effects` [{target, value}], `implemented`, `legacy_id`) y la sección `migration`. `UpgradeCatalog` (`scripts/autoload/upgrade_catalog.gd`) lo carga y lo valida (5 niveles en orden, nivel 1 gratis, nombre, descripción, coste y efecto); `tools/upgrade_catalog.py` hace lo mismo para Python. Valor efectivo: cada nivel comprado **e implementado** suma su efecto; gana el más alto. Destino nuevo `game_state.pulse_stun_multiplier` (1,0). |
| 2. Compras | `GameState.purchase_upgrade(pista)` compra el siguiente nivel: `UNKNOWN`, `MAX_LEVEL`, `ABILITY_MISSING` (Debug o Láser sin obtener: chip «?»), `ACCESS_LOCKED` (`lap` 1 Caché, 2 Kernel, 3 Raíz), `NOT_IMPLEMENTED` («Próximamente»), `NOT_ENOUGH_POINTS`, `NOT_ENOUGH_POWER_BANKS` (el nivel 5 gasta un power bank completo); solo marca «sin guardar». `get_upgrade_level`, `get_upgrade_access_cap`, `is_upgrade_track_available`, `get_next_upgrade_level`; `is_upgrade_purchased` acepta un `legacy_id` (`wide_pulse`) o `pista:nivel`. |
| 3. Guardado v4 | `upgrade_levels` {pista: nivel} sustituye a `upgrades_purchased`. Migración v1-v3 → v4 con las devoluciones de §7.3 (Pulso amplio → Pulso 2 sin devolución; Debug eficiente → Debug 2 + 45 puntos + 1 PB; Sync reforzado → Sync 2 + 30 + 1 PB; Batería ampliada → Energía 2 + 20 + 1 PB; Arranque rápido, 20 puntos; Recarga mejorada, 25 puntos; sin tope de power banks). Versión desconocida se aparta como `.corrupt`; `.bak` y guardado manual sin cambios. La papelera guarda y devuelve los niveles (`TRASH_UPGRADES` es ahora un diccionario). Un guardado con algún nivel comprado da a Calc por conocida, como antes con las compras. |
| 4. Efectos simples | Pulso 2: radio 96 → 112 px. Pulso 3: aturdimiento ×1,5 (la Burbuja y el punto rojo, `stun(duration_scale)`; el aviso final no cambia). Láser 2: enfriamiento 0,4 → 0,3 s; Láser 3: coste 10 → 8 (el HUD usa `get_laser_energy_cost`: la batería se ve vacía por debajo de 8); Láser 4: daño 1 → 2. Debug 2: gasto 20 → 15/s. Sync y Energía 2-4: máximo 110 / 120 / 130 (el HUD por fracción del máximo, la papelera, el llenado al entrar al hub, los cargadores, los drops y su desborde a los power banks usan el máximo efectivo). |
| 9 (parte) | `tools/validate_level.py --upgrades pista:nivel[,…]` (y `wide_pulse` como alias de `pulso:2`: la salida del 1-1 y del 1-2 es idéntica byte a byte, con y sin él); el validador usa el alcance del pulso, el coste y el enfriamiento del láser, el gasto del Debug y los máximos de esos niveles; `requires_upgrade` admite `pista:nivel`. Economía en `tests/test_upgrade_economy.py` (90 por pista, 450 + 5 PB; Caché abre 180 ≥ 162 ganables, Kernel 325 ≥ 324, Raíz 450 ≤ 486; con el 93 % se compra todo y con el 90 % no) y `tests/test_level_schema.py` (Pulso 2 = 25: las cuatro comprobaciones del 1-1 y del 1-2 siguen igual). |
| 10. Arte | `tools/gen_calc_chips.py` (validador `tools/validate_calc_chips.py`, en `tools/run_tests.sh`): chips de 24 × 24 (onda del celular, haz, ojo entre corchetes, señal, batería y «?»; normal y elegido con marco cian) y recuadros de 10 × 14 (lleno, siguiente en dos cuadros, vacío, candado, «Próximamente», desconocido, carga en tres pasos y destello). Paleta del hub, sin rojos. El icono «oculto» del HUD queda para M2. |
| 11. Tienda | `CalcPanel` reescrito sobre `HubPanel` (que admite ahora filas más altas con sitio para dibujos y varias líneas de detalle con su color): saldo con el rombo de los puntos, power banks y «Sin guardar»; una fila por pista; detalle del siguiente nivel o «Nivel máximo» y el estado; mensajes de compra; el recuadro nuevo se carga (0,4 s). Capturas: `tools/render_calc_shop.gd`. |

**Pendiente (tanda M2):** Pulso 4 (Ocultarte) y 5 (Pulso de retorno), Láser 5 (perfora), Debug 3 (revelado persistente), 4 (ralentización) y 5 (Arranque rápido, 0,4 s), Sync 5 (Resincronización) y Energía 5 (recarga pasiva), tope de 3 power banks, icono «oculto» del HUD y el bot vertical. Sus niveles ya están en el catálogo con `implemented: false` (la tienda los muestra «Próximamente»). Del paso 9 queda la pasada con el tope del acceso del nivel.

