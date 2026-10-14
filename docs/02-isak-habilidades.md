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
- **Debug Mode (modo especial):** el tiempo se ralentiza. Isak ve plataformas ocultas que son errores del sistema y el punto débil de los jefes, marcado en rojo. Consume la barra de energía. El color de la pantalla cambia según el mundo, para evitar el cliché del verde tipo matriz.

### 3.3 Barras

| Barra | Función |
|---|---|
| **Sync Rate** | Es la vida. Representa cuánto está sincronizado Isak con su cuerpo. Por debajo del 20% la música se distorsiona y aparece ruido visual, con una opción de accesibilidad para reducirlo. |
| **Energía de Debug** | Barra secundaria. Se gasta con el Debug Mode y se recupera con puntos de atención. |

### 3.4 Daño y muerte

- **Recibir daño:** en lugar de sangre, Isak desprende glitches, píxeles que parpadean y se desplazan aleatoriamente.
- **Muerte:** Isak no cae al suelo. Su cuerpo se pixela por completo y se desintegra en líneas de código que suben hacia el cielo del mundo virtual.

### 3.5 Gestos del celular (mejoras por mundo)

El kit base de hacker (pulso y Debug) se complementa con gestos táctiles que Isak desbloquea en cada mundo. Cada gesto modifica el pulso o el movimiento.

| Gesto | Se obtiene en | Efecto |
|---|---|---|
| **Deslizar** | Mundo 1 | El pulso se convierte en un dash de datos, con un instante de invulnerabilidad. |
| **Mantener presionado** | Mundo 2 | Golpe al suelo que rompe plataformas y aturde en área. |
| **Pellizcar** | Mundo 3 | Isak se comprime para pasar por huecos pequeños. |
| **Agitar** | Mundo 4 | Onda que aturde a todos los enemigos cercanos. |
| **Combinación** | Mundo 5 | Encadenar dos gestos en el aire da un súper movimiento: Embestida (dash y golpe al suelo), Filo (dash comprimido) y Sismo (golpe al suelo con onda). |
