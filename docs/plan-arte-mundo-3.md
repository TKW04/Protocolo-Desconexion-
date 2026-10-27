# Arte del Mundo 3 con AutoSprite (paso 23 de `propuesta-mundo-3.md`)

Plan y presupuesto aprobados por el usuario el 2026-10-27 («continúa con el arte final»): `propuesta-mundo-3.md` §6.2, **68-71 créditos** en una pasada (hasta ~142 con reintentos), con **parada tras cada personaje base** para enseñarlo antes de seguir. El flujo y las lecciones son los de Autoplay y el Comentarista (`plan-arte-mundo-2.md`) y Alerta Mayor (`plan-arte-jefe-alerta-mayor.md` §7).

## 1. Bases (paso 23a, 2026-10-27)

### 1.1 Créditos

Saldo al empezar (`get_account`): **380**, el que da §6.2. Tope de esta pasada: 12 créditos (2 bases y hasta 2 reintentos de base); sin poses ni animaciones.

| # | Llamada | Pieza | Créditos | Saldo tras la llamada |
|---|---|---|---|---|
| 1 | `create_character` (`pixelArt`, `isHumanoid: false`) | Base «La Curadora» (`cmvqtdvrk0015ac1uejr87glv`) | 3 (previsto) | 377 (previsto) |
| 2 | `create_character` (`pixelArt`, `isHumanoid: false`) | Base «Influencer bot» (`cmvqte8i800i58mjne5h1yzu3`) | 3 (previsto) | **374** (previsto) |
| | | **Esta pasada** | **6** (tope 12) | |

Sin reintentos. El saldo final no se ha vuelto a consultar (la herramienta pide un solo `get_account` por sesión): en Autoplay y el Comentarista el base no apareció descontado, así que la próxima pasada empieza con `get_account` y se anota aquí si da 374 o 380.

### 1.2 Prompts

En inglés, describiendo solo lo que debe aparecer, con los hex de la paleta B (`assets/palettes/mundo3.gpl`) y las siluetas de los provisionales (`tools/gen_boss_curator.py`, `tools/gen_world3_enemies.py`).

**La Curadora** (`characterDescription`: «a giant floating gold picture frame boss with a camera for a head on its top edge and a filtered pink portrait inside»):

> A huge ornate picture frame floating in the air, seen from the front, wide landscape shape twice as wide as tall. Thick muted antique gold frame (#b0a064) with pale gold bevel (#d6c896), dark bronze shade (#54442a) and round corner rosettes. Inside, a soft pastel pink portrait (#f8d6e8) of a smooth doll-like face with a perfect sweet smile. On the middle of the top edge sits a boxy dark plum camera (#181020) as its head, with one big round pearl-grey lens and a small white flash. Clean 16-bit pixel art, flat colors, few shades, centered on a plain white background.

**Influencer bot** (`characterDescription`: «a small pink creature with a camera head that poses on a white pedestal and fires a camera flash»):

> A small cute creature posing on top of a tall pedestal, seen from the front. Round soft pastel pink body (#f8d6e8) with dusty rose shading (#a8809a), two short arms raised in a showy pose. Its head is a boxy dark plum camera (#181020) with one round pearl-grey lens (#c4b8cc) and a tiny white flash on top. The pedestal is a bright white column (#fcf8fc) with pearl-grey shade and muted antique gold bands (#b0a064) at top and bottom. Clean 16-bit pixel art, flat colors, few shades, centered on a plain white background.

### 1.3 Resultado y valoración

Copias en `docs/capturas/arte-autosprite-2026-10-27/`: `curadora_base.png`, `curadora_base_recorte.png` e `influencer_base.png` (1024 × 1024, 32-33 colores).

- **La Curadora:** el marco y la cámara son los del diseño: marco dorado grueso con bisel y cuatro rosetas, retrato rosa pastel con una cara sonriente y la cámara morada oscura con lente gris perla y flash blanco en el centro del lado de arriba (como la lente en (256, 24) del provisional). **Defectos:** `pixelArt` volvió a pintar un cuerpo chibi debajo (casaca morada con botones dorados, piernas y zapatos), como con Alerta Mayor y Autoplay; el marco sale a ~1,77:1 (816 × 460 sin la cámara) y no a 2:1; el dorado es más cálido y saturado que el `dorado` apagado de la paleta (se corrige al reducir, como el magenta de Autoplay); la cara es más «chibi mona» que «muñeca perfecta» y los mofletes son salmón (al reducir deben caer en `corazon_rosa`, nunca en `alerta`). **No se reintenta:** se recorta solo el marco con la cámara (x 104-919, y 64-647 del base; `curadora_base_recorte.png`, 816 × 584) como en Autoplay. Falta, antes de las poses: pasarlo a su rejilla nativa, estirar a 2:1 duplicando columnas lisas del retrato y del marco (las rosetas y la lente siguen redondas), reducir a `mundo3.gpl` sin `alerta`, `alerta_sombra` ni los ámbar y subirlo gratis con `upload_character` como «La Curadora (marco)».
- **Influencer bot:** fiel al provisional y a la ficha: criatura rosa pastel con sombra malva, brazos en alto posando, cabeza-cámara oscura con lente gris perla y flash blanco encima, sobre una columna blanca con anillos dorados. Silueta clara y legible a 64 × 128 (pedestal ~mitad inferior, criatura arriba). **Defectos menores:** la cámara es casi negra (cae bien en `galeria_noche`, pero hay que comprobar que no se funda con el contorno a 64 px); el dorado de los anillos, también más saturado que el de la paleta; la proporción del dibujo (~1:2,6) es algo más alta que la caja de 1 × 2 tiles, así que al importar la criatura se encoge un poco o el pedestal se acorta. Sin cuerpo añadido: no hace falta recorte ni `upload_character`.

## 2. Siguiente (pendiente del visto bueno de las bases)

Precios de §6.2: pose 3, animación turbo 5, `upload_character` y `regenerate_*` 0.

| Pieza | Qué | Créditos | Con un reintento |
|---|---|---|---|
| Curadora | Recorte + estirado + paleta + `upload_character` | 0 | 0 |
| Curadora | Poses `Shooting` (lente baja con el flash cargado), `Turned` (de espaldas: tablero de madera y alambre) y `Posing` (retrato con el filtro más fuerte) | 9 | 18 |
| Curadora | Animaciones turbo `idle`, `flash`, `frame_down`, `turn`, `x_reflection` y `defeat` (una llamada, `custom`, `raw_prompt`, `first_frame`, `frameSize` 1024, vista de frente) | 30 | 60 |
| Influencer bot | Una pose (`Flash`: brazos juntos y flash encendido) | 3 | 6 |
| Influencer bot | Animaciones turbo `idle`, `flash_charge` y `stunned` (una llamada) | 15 | 30 |
| Isak | Pose `compress` (comprimirse, andar comprimido y volver; `generate_spritesheet` turbo sobre «Isak», +3 si hace falta una pose) | 5-8 | 10-16 |
| **Total que queda** | | **62-65** | 124-130 |

Con los 6 de las bases, el total del Mundo 3 queda en los 68-71 de §6.2 (saldo final previsto ~309-312). Después: importadores (`tools/import_boss_curator.py`, `tools/reduce_palette.py`) que encajen el arte sin cambiar tiempos ni cajas (los bots deben dar los mismos resultados).
