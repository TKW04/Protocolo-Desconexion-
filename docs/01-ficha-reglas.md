# Ficha del juego y estructura de mundos

Origen: secciones 1 y 5 (y el encabezado del documento) del documento original (`docs/original/diseno.md`).

*The Horizon: Protocolo de Desconexión.*

*Documento de diseño del juego. Versión 2, rehecho desde cero. Se actualiza a medida que avanzamos.*

## 1. Ficha del juego

- **Tipo de juego:** plataformas 2D
- **Estilo:** pixel art 2D
- **Resolución:** base de 640x360, con el sprite de Isak en un canvas de 64x64 (ver [07-estilo-visual.md](07-estilo-visual.md)) — *cambio aprobado 2026-10-14: 1280x720, Isak en canvas de 128x128 (unos 96 px visibles) y tiles de 64x64*
- **Motor previsto:** Godot con GDScript. Se rehace desde cero, sin reutilizar el código anterior.
- **Tono:** mezcla de oscuro y reflexivo con humorístico y satírico. El humor está en la superficie del mundo y lo oscuro en lo que cada mundo le quitó a Isak.
- **Objetivos de diseño:** que se vea bien, que sea interesante y que la complejidad aumente a medida que avanza.
- **Nota creativa:** se evitan marcas reales. Todas las apps y redes tienen nombres inventados.

## 5. Estructura de mundos

El hub es la Pantalla de Inicio, un lugar seguro donde las carpetas son las puertas de cada mundo. Cada mundo tiene 3 niveles y 1 jefe, unos 18 niveles y 6 jefes en total.

| # | Mundo | Se llevó | Gesto | Mecánica propia |
|---|---|---|---|---|
| **1** | Notificaciones | Concentración | Deslizar | Puntos rojos que persiguen, pop-ups que bloquean el paso y la vista. |
| **2** | El Feed | Tiempo | Mantener presionado | Scroll vertical forzado, el nivel avanza solo. |
| **3** | La Vitrina | Imagen | Pellizcar | Plataformas que solo existen si tienes likes. Espejos y filtros que distorsionan. |
| **4** | El Chat | Amistades | ~~Agitar~~ (retirado el 2026-10-28, `propuesta-mundo-4.md` §8.1) | Burbujas de texto como plataformas. El "visto" te congela. |
| **5** | La Tienda | Voluntad | Combinación | Todo tiene un precio y los atajos tienen trampa. |
| **6** | La Nube | Todo | Todos | Todo lo anterior mezclado. Núcleo de Eco y jefe final. |

**Progresión:** cada mundo enseña una idea y el siguiente la combina con las anteriores. Esquivar, moverse bajo presión, razonar con el entorno, leer patrones, tomar decisiones y, al final, dominar todo a la vez.
