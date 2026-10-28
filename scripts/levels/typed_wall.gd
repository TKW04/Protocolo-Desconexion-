## Muro de texto (tipo `typed_wall` del catalogo del Mundo 4; 2026-10-28, paso 8 de
## docs/propuesta-mundo-4.md §8 y §3.7; nivel 4-2). Ajustes en la seccion typed_wall
## de data/world4_objects.json.
##
## Pared solida de 1 x height_tiles (3) sobre el suelo hecha de lineas de texto
## escrito («y entonces le dije que…»; `lines`, una por tile). Es el muro «Cargando
## mas…» del Mundo 2 (LoadingWall) con otra llave: el «¿DESHACER ESCRITURA?» del
## nivel (UndoPrompt; desde el 2026-10-28, al retirarse Agitar, que lo deshacia con
## su onda): al usarlo (EventBus.writing_undone) todos los muros de texto del nivel
## se DESHACEN PARA SIEMPRE (undo()): las letras se borran de atras adelante en
## erase_s (0,4 s de tiempo del mundo) y al terminar deja de ser solido; no vuelve
## al reaparecer Isak. El pulso y el laser rebotan (chispa gris; el disparo se
## consume). El origen del nodo es la esquina superior izquierda de su celda de
## arriba. Aspecto PROVISIONAL por codigo (paleta provisional del Mundo 4). Senal
## erased al empezar a borrarse (sonido sfx_w4_typed_wall_erase, paso 20).
class_name TypedWall
extends StaticBody2D

## Lo han deshecho (el «¿Deshacer escritura?»): empieza a borrarse.
signal erased
## Ya no queda texto: deja de ser solido.
signal cleared
## El pulso o el laser han rebotado (chispa gris).
signal deflected

const LAYER_WORLD: int = 1
const GROUP: StringName = &"typed_wall"

@export var object_id: StringName = &""
@export var height_tiles: int = 3
## Lineas de texto de arriba abajo (vacio = las de la seccion typed_wall).
@export var lines: Array = []

var _cfg: Dictionary = World4ObjectsConfig.section("typed_wall")
## -1 = entero; 0..erase_s = borrandose; >= erase_s = deshecho.
var _erase_time: float = -1.0
var _cleared: bool = false
var _deflect_left: float = 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = get_wall_size()
	_shape.shape = rect
	_shape.position = get_wall_size() * 0.5
	add_child(_shape)
	add_to_group(GROUP)
	EventBus.writing_undone.connect(_on_writing_undone)
	EventBus.pulse_fired.connect(_on_pulse_fired)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos del mundo. Publico para las pruebas.
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_deflect_left = maxf(_deflect_left - dt, 0.0)
	if _erase_time >= 0.0 and not _cleared:
		_erase_time += dt
		if _erase_time >= get_erase_s():
			_clear()
	queue_redraw()


# --- Consultas ---

func get_wall_size() -> Vector2:
	var t: float = World4ObjectsConfig.tile_size()
	return Vector2(t, t * float(height_tiles))


func get_wall_rect() -> Rect2:
	return Rect2(global_position, get_wall_size())


func get_erase_s() -> float:
	return maxf(float(_cfg.get("erase_s", 0.4)), 0.001)


## Lineas que muestra (las suyas o las de la seccion), una por tile.
func get_lines() -> Array[String]:
	var src: Array = lines if not lines.is_empty() else _cfg.get("lines", [])
	var out: Array[String] = []
	for i: int in height_tiles:
		out.append(String(src[i]) if i < src.size() else "")
	return out


## Fraccion de texto que queda (1 entero, 0 deshecho).
func get_text_left() -> float:
	if _erase_time < 0.0:
		return 1.0
	return clampf(1.0 - _erase_time / get_erase_s(), 0.0, 1.0)


func is_erasing() -> bool:
	return _erase_time >= 0.0 and not _cleared


func is_cleared() -> bool:
	return _cleared


func is_solid() -> bool:
	return not _cleared


## Ayuda de Eco: mientras no se haya empezado a borrar.
func is_help_available() -> bool:
	return _erase_time < 0.0


# --- Acciones ---

## Empieza a borrarlo (lo llama el «¿Deshacer escritura?»). Verdadero si empieza.
func undo() -> bool:
	if _erase_time >= 0.0:
		return false
	_erase_time = 0.0
	erased.emit()
	queue_redraw()
	return true


## Onda de Agitar (retirado el 2026-10-28; ya no se conecta a EventBus.shockwave_fired).
func receive_shockwave(center: Vector2, radius: float, _source: Node2D = null) -> bool:
	if not ShockwaveWave.reaches(center, radius, get_wall_rect()):
		return false
	return undo()


## Interfaz del laser: rebota (chispa gris; el disparo se consume).
func on_laser_hit(_damage: float, _source: Node) -> void:
	if not _cleared:
		_deflect()


# --- Interno ---

func _clear() -> void:
	_cleared = true
	collision_layer = 0
	_shape.set_deferred(&"disabled", true)
	cleared.emit()


func _deflect() -> void:
	_deflect_left = float(_cfg.get("deflect_s", 0.25))
	deflected.emit()
	queue_redraw()


func _on_writing_undone(_id: StringName) -> void:
	undo()


func _on_pulse_fired(area: Area2D) -> void:
	if not _cleared and PulseReceiver.pulse_reaches(area, get_wall_rect()):
		_deflect()


func _col(key: String, fallback: String) -> Color:
	return World4ObjectsConfig.color(String(_cfg.get(key, fallback)))


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 4) ---

func _draw() -> void:
	if _cleared:
		return
	var size: Vector2 = get_wall_size()
	var t: float = World4ObjectsConfig.tile_size()
	var left: float = get_text_left()
	# Bloque de texto: fondo crema con un borde y las lineas escritas encima.
	var alpha: float = 0.35 + 0.65 * left
	draw_rect(Rect2(Vector2.ZERO, size), Color(_col("fill", "crema"), alpha))
	draw_rect(Rect2(Vector2.ZERO, size), _col("edge", "crema_sombra"), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	var ink: Color = _col("ink", "marino_fondo")
	var rows: Array[String] = get_lines()
	for i: int in rows.size():
		var text: String = rows[i]
		# Se borran de atras adelante: queda el principio de cada linea.
		var keep: int = ceili(float(text.length()) * left) if left < 1.0 else text.length()
		var shown: String = text.substr(0, keep)
		draw_string(font, Vector2(4.0, t * float(i) + t * 0.5 + 4.0), shown, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 8.0, 10, ink)
		if is_erasing() and keep > 0:
			# Cursor de borrado al final de lo que queda.
			var w: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var x: float = minf(4.0 + w + 1.0, size.x - 4.0)
			draw_line(Vector2(x, t * float(i) + t * 0.5 - 6.0), Vector2(x, t * float(i) + t * 0.5 + 6.0), ink, 1.0)
	if _deflect_left > 0.0:
		var grey: Color = _col("spark", "gris_medio")
		var c := size * 0.5
		for a: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(14.0, 0.0).rotated(deg_to_rad(a))
			draw_line(c - d, c + d, grey, 2.0)
