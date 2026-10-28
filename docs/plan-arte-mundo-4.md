# Arte del Mundo 4 con AutoSprite (paso 24 de `propuesta-mundo-4.md`)

Presupuesto de `propuesta-mundo-4.md` §6.2 (68-71 créditos en una pasada, hasta ~142 con reintentos, de un saldo de 315), en tres etapas con **parada tras cada personaje base** (regla de los Mundos 2 y 3). Flujo y lecciones de la Curadora (`plan-arte-mundo-3.md`).

## 1. Etapa 1: base de El Visto (2026-10-28)

- `create_character` (`pixelArt`, `isHumanoid: false`): «El Visto» (`cmvs7e35n00frkuhtqdi5jpqf`), copia en `docs/capturas/arte-autosprite-2026-10-28/visto_base.png` (commit `d9c72d4`). Previsto: 3 créditos; **no apareció cobrado** (el saldo de la etapa 2 empezó en 315, como en Autoplay, el Comentarista y la Curadora).
- Aceptado por el usuario con tres defectos a arreglar al importar: **halo opaco** gris azulado alrededor, **check gris descentrado** (unos 45 px a la izquierda en el base de 1024) y **proporción** (los checks y el check gris de debajo, ~1,4:1, no caben tal cual en la caja de 2:1).

## 2. Etapa 2: animaciones e integración (2026-10-28)

Autorizado por el usuario: la opción completa, 8 animaciones (≈40 créditos; tope con reintentos 98).

### 2.1 Créditos

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| — | `get_account` | | 0 | **315** |
| — | `upload_character` (base sin halo y con el check gris centrado, ver 2.2) | «El Visto (sin halo)» (`cmvs7lw5p002k6judk44ntz5r`) | 0 | 315 |
| 1 | `generate_spritesheet` turbo (una llamada, 8 × 5; `custom`, `raw_prompt`, `first_frame`, 25 cuadros de 1024, vista de frente) | `idle`, `vanish`, `reappear`, `charge`, `shield`, `typing`, `stunned`, `defeat` | **40** | **275** (respuesta de la llamada) |
| | | **Esta etapa** | **40** (tope 98) | |

Sin reintentos: las 8 se aceptaron a la primera (los defectos se arreglan al importar, gratis). Total de El Visto: **40** (el base no se cobró).

### 2.2 Desvíos y decisiones

- **Base corregido antes de animar** (como el marco de la Curadora): el halo se quitó con un relleno desde el borde que para en el contorno oscuro (los checks y el check gris quedan intactos) y el check gris se movió 40 px a la derecha y 16 abajo (centrado bajo los checks, con hueco hasta el check derecho). Subido gratis como «El Visto (sin halo)»; copias en `hojas/seen/base_upload.png` y `docs/capturas/arte-autosprite-2026-10-28/visto_base_sin_halo.png`. **El aura pasa a SeenFx**: dos anillos elípticos translúcidos (`aura_color` al 22 % y 12 %) que laten alrededor del dibujo y se esfuman con él.
- **Prompts** (en inglés, describiendo solo lo que debe verse; todos empiezan por «Front view, flat 16-bit pixel art on a plain white background. A giant floating double check mark (two thick white check marks with dark navy outline) and a small grey check mark centered below them.»): `idle` (flota, el check gris se apaga y se enciende; bucle), `vanish` (se deshace en humo gris azulado hasta quedar vacío), `reappear` (glitch en franjas horizontales que se vuelven a juntar), `charge` (embiste hacia la derecha con estelas a la izquierda y vuelve a su forma), `shield` (se encoge y un brillo crema late en el contorno; bucle), `typing` (se mece al ritmo de escribir y el check gris parpadea; bucle), `stunned` (se tambalea con tres estrellas grises; bucle) y `defeat` (grietas, el blanco se apaga a gris y se queda caído).
- **Orden de las hojas**: como siempre, no seguía el del pedido; se identificaron mirándolas (`oscd` idle, `o7kl` vanish, `os90` reappear, `nxza` charge, `ojrf` shield, `oqwv` typing, `ohc8` stunned, `oa8t` defeat).
- **Rótulos inventados por la IA**: cinco hojas traían un rótulo pequeño bajo el check gris (cajitas «Read receipt», una barra de texto en `typing`, un bocadillo en `idle`). El importador los borra (`CLEANUP` de `tools/import_boss_seen.py`: manchas que caben enteras en un rectángulo; en `typing`, lo claro y lo de debajo de la punta del check).
- **Paleta**: `mundo4.gpl` sin rojos, ámbares ni coral, y también **sin cremas ni verdes** (salvo el brillo crema de `shield`) y sin los marinos medios: sin eso el humo gris azulado caía en `crema` y la derrota gris en `verde_apagado`, y el gris azulado del check gris en `marino_luz`. El Visto queda en la rampa `chat_noche` → `gris_oscuro` → `gris_medio` → `gris_claro` → `blanco_pantalla` (contorno `chat_noche`).
- **Hojas guardadas** reducidas a cuadros de 512 (alfa premultiplicado, 256 colores): `hojas/seen/<anim>/spritesheet.png`.

### 2.3 Integración

- `python3 -I tools/import_boss_seen.py` (210 PNG en `assets/sprites/bosses/`; `--check` en `tools/run_tests.sh`): **cuerpo** `seen_<anim>_NN.png`, misma escala en x e y (fit por alto), 72 × 52 píxeles de arte con 6 de margen, rejilla de 4: lienzo de 336 × 256 colocado en (24, −48) de la caja de 6 × 3 tiles (`Seen.ART_BODY_OFFSET`). El doble check mide ~280 × 148 px y sobresale 24 px por encima de la caja (la caja no cambia); el check gris cae en (190, 160) de la caja (`ART_CHECK_PX`: `perch_core_px` centrado, 2 px a la izquierda por la rejilla). **Silueta** de la fase 1 `seen_small_<anim>_NN.png` (`reappear` y `charge`): el mismo dibujo a 96 px de ancho (rejilla 2), lienzo de 112 × 86 con su check gris en el punto débil (`ART_SILHOUETTE_OFFSET`).
- Celdas: `idle`, `shield`, `typing` y `stunned` 0-23 (bucles), `vanish` 0-5 y 7-23 (la 6 era un destello oscuro), `reappear` y `defeat` 0-24, `charge` 3-7 y 12-14 (en las 8-11 la estela tapaba media celda).
- **Cuándo** (`Seen.get_art_frame()` / `get_silhouette_art_frame()`, `ART_ANIMS`): `idle` por defecto; fase 1: `vanish` por el progreso de `vanish_s` (el alfa del código baja más despacio para que se vea el humo), oculto entre medias, silueta con `reappear` durante el aviso (su último cuadro en la ventana) y `charge` en bucle al embestir (reflejada hacia la izquierda; se mantiene el contorno rojo de la embestida), y `reappear` en el cuerpo durante `return_s`; fase 2: `shield` con el escudo levantado y `stunned` en el suelo; fase 3: `typing` mientras se llenan los puntos y `stunned` aturdido; `defeat` desde el golpe final (empieza ya agrietado, `ART_DEFEAT_FROM` 8, porque la congelación pausa el árbol) y el **desarme en píxeles suelta el último cuadro** (gris y roto). Sin los cuadros vuelve al provisional por código.
- **Alineación con el punto débil**: en las ventanas de las fases 2 y 3 el dibujo se desliza con la caída o la bajada hasta que su check gris cae en el punto débil (`get_art_position()`; en la fase 3, a un lado, del lado de Isak). La caja (`get_body_rect`), el punto débil, los tiempos, el daño y `data/bosses/seen.json` no cambian.
- Pruebas: `test_final_art_follows_its_state` (`tests/test_seen_boss.gd`, 17/17) y `tests/test_import_boss_seen.py` (6: `--check` en verde y en rojo con un cuadro tocado, cuadros por animación frente a `ART_ANIMS`, lienzos, desplazamientos y check gris centrado, crema solo en el escudo). `test_seen_arena` 9/9, `test_seen_bot` 7/7 (los bots dan los mismos resultados), `test_boss_bar` 12/12.
- Capturas con el flujo real (`tools/render_level_4_x.gd -- --level 4-boss`): `docs/capturas/arte-autosprite-2026-10-28/juego_*.png`; hojas de contacto `visto_cuadros.png` (cuerpo, una de cada tres) y `visto_silueta_cuadros.png`.

### 2.4 Calidad y defectos vistos

- El doble check se reconoce y es coherente entre animaciones; sin rojos ni coral; el check gris queda centrado y cae en el punto débil en las ventanas. La derrota (grietas y gris) y el desarme se leen bien; la barra del jefe (a la derecha) no tapa el dibujo.
- **El check gris se pierde sobre el fondo oscuro de arriba** (gris sobre marino) cuando El Visto está en reposo; en las ventanas, abajo, se ve mejor.
- **`idle`**: el check gris parpadea hasta casi negro (`chat_noche`) en algunos cuadros: se confunde con el contorno.
- **`shield`**: el brillo crema tiñe los checks enteros en 2 de cada 8 cuadros: salto de tono (blanco → crema) dentro del bucle.
- **`typing`**: en algunos cuadros el check gris se deforma (un palito) y los checks se aplastan; el ritmo se lee, el gesto no tanto.
- **Silueta de la fase 1**: a 96 px de ancho, con el Debug el círculo rojo del punto débil tapa casi todo el doble check pequeño.
- **`charge`**: las estelas son bloques blancos y grises (sin las celdas peores), no un trazo fino.
- El dibujo sobresale 24 px por encima de la caja y en reposo pisa la franja del techo de la arena.
- **Captura 02** (`juego_02_fase1`): la toma cae al final del `vanish` y El Visto no se ve (es la temporización de la captura, no del arte). En la primera tanda de capturas el proceso dejó de guardar las 12-15 una vez; al repetir salieron las 15.

## 3. Etapa 3 (pendiente, sin gastar): Troll y pose de Agitar

Plan de §6.2, con parada tras el base del Troll:

| Pieza | Qué | Créditos | Con un reintento |
|---|---|---|---|
| Troll | Base (`create_character`, `pixelArt`, no humanoide: perfil anónimo con capucha y sonrisa) | 3 (puede no cobrarse) | 6 |
| Troll | Una pose (`Typing`: escribiendo con el bocadillo listo) | 3 | 6 |
| Troll | Animaciones turbo `idle`, `typing_shot` y `stunned` (una llamada, `first_frame`, `raw_prompt`) | 15 | 30 |
| Isak | Pose `shockwave` (sacudir el celular; `generate_spritesheet` turbo sobre «Isak», +3 si hace falta una pose) | 5-8 | 10-16 |
| **Total** | | **26-29** | 52-58 |

Saldo previsto al terminar el Mundo 4: **~246-249** (desde 275). Después: `tools/import_troll.py` (como `import_influencer_bot.py`: alto de la caja del Troll, pies abajo) y la pose en `tools/build_isak_frames.gd` con `tools/import_sheet.py` (sustituye la sacudida por código de `ShockwaveEffect`).
