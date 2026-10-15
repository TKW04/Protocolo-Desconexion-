## Lectura y escritura del archivo de guardado (JSON) para GameState.
## - Escritura atomica: se escribe <ruta>.tmp y se renombra sobre <ruta>, asi
##   un cierre a mitad nunca deja un guardado a medias.
## - Tolerante: si el archivo no existe devuelve {} (estado MISSING); si no es
##   un objeto JSON valido lo aparta como <ruta>.corrupt (para no perderlo ni
##   volver a leerlo) y devuelve {} (estado CORRUPT). Si falta <ruta> pero
##   quedo un <ruta>.tmp completo (cierre entre escribir y renombrar), lo usa.
## - Copia anterior (2026-10-15): write() con keep_backup copia el guardado que
##   habia a <ruta>.bak antes de sustituirlo (read_backup() lo lee).
## No sabe nada del contenido: la version del esquema y los campos los valida
## GameState.
class_name SaveFile
extends RefCounted

enum Status { OK, MISSING, CORRUPT }

const TMP_SUFFIX: String = ".tmp"
const CORRUPT_SUFFIX: String = ".corrupt"
const BACKUP_SUFFIX: String = ".bak"

## Resultado de la ultima lectura (pruebas y avisos).
static var last_status: Status = Status.MISSING


## Lee `path`. Devuelve el objeto JSON o {} si falta o esta corrupto.
static func read(path: String) -> Dictionary:
	var source: String = path
	if not FileAccess.file_exists(source):
		source = path + TMP_SUFFIX
		if not FileAccess.file_exists(source):
			last_status = Status.MISSING
			return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(source)) != OK or not json.data is Dictionary:
		push_warning("SaveFile: guardado corrupto en '%s'; se aparta como %s y se empieza de cero." % [source, CORRUPT_SUFFIX])
		quarantine(source)
		last_status = Status.CORRUPT
		return {}
	last_status = Status.OK
	return json.data


## Escribe `data` en `path` de forma atomica. Con `keep_backup`, el archivo que
## hubiera en `path` se copia antes a <ruta>.bak (sustituye al .bak anterior).
## Verdadero si todo fue bien (un fallo al copiar el .bak solo avisa).
static func write(path: String, data: Dictionary, keep_backup: bool = false) -> bool:
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp: String = path + TMP_SUFFIX
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("SaveFile: no se pudo escribir '%s' (%s)." % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if keep_backup and FileAccess.file_exists(path):
		var copy_err: Error = DirAccess.copy_absolute(_global(path), _global(path + BACKUP_SUFFIX))
		if copy_err != OK:
			push_warning("SaveFile: no se pudo copiar '%s' a %s (%s)." % [path, BACKUP_SUFFIX, error_string(copy_err)])
	var err: Error = DirAccess.rename_absolute(_global(tmp), _global(path))
	if err != OK:
		push_error("SaveFile: no se pudo renombrar '%s' a '%s' (%s)." % [tmp, path, error_string(err)])
		return false
	return true


## Aparta un archivo como <ruta>.corrupt (sustituye al anterior).
static func quarantine(path: String) -> void:
	var target: String = path.trim_suffix(TMP_SUFFIX) + CORRUPT_SUFFIX
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(_global(target))
	DirAccess.rename_absolute(_global(path), _global(target))


## Lee la copia anterior (<ruta>.bak). {} si no hay o no es un objeto JSON (no
## la aparta ni cambia last_status).
static func read_backup(path: String) -> Dictionary:
	var backup: String = path + BACKUP_SUFFIX
	if not FileAccess.file_exists(backup):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(backup)) != OK or not json.data is Dictionary:
		return {}
	return json.data


## Borra el guardado y sus restos (.tmp, .corrupt y .bak). Para pruebas y reinicios.
static func delete(path: String) -> void:
	for p: String in [path, path + TMP_SUFFIX, path + CORRUPT_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(_global(p))


static func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)
