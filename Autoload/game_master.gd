extends Node

const SAVE_PATH := "user://save.json"
const SAVE_KEY := "todo"

signal freezing_main_window(frozen: bool)
signal showing_hint(text: String)
signal collecting_scrap
signal flag_raised(flag: StringName)
signal flags_cleared
signal pause

var _raised_flags: Dictionary = {}

func _ready() -> void:
	_load_flags()


func freeze_main_window(frozen: bool) -> void:
	freezing_main_window.emit(frozen)


func show_hint(text: String) -> void :
	showing_hint.emit(text)


func collect_scrap() -> void :
	collecting_scrap.emit()
	raise_flag(&"scrap_collected")


func raise_flag(flag: StringName) -> void :
	if flag == &"" or _raised_flags.has(flag):
		return

	_raised_flags[flag] = true
	_save_flags()
	flag_raised.emit(flag)


func is_flag_raised(flag: StringName) -> bool:
	return _raised_flags.has(flag)


func has_any_flag() -> bool:
	return not _raised_flags.is_empty()


func get_raised_flags() -> Array[StringName]:
	var flags: Array[StringName] = []

	for flag in _raised_flags.keys():
		flags.append(StringName(flag))

	return flags


func clear_flags(save := true) -> void:
	_raised_flags.clear()

	if save:
		_save_flags()

	flags_cleared.emit()


func _load_flags() -> void:
	var saved := _read_save()
	var todo = saved.get(SAVE_KEY, {})

	if not (todo is Dictionary):
		return

	var flags = todo.get("flags", [])

	if not (flags is Array):
		return

	for flag in flags:
		if flag is String and not flag.is_empty():
			_raised_flags[StringName(flag)] = true


func _save_flags() -> void:
	var saved := _read_save()
	var flags: Array[String] = []

	for flag in _raised_flags.keys():
		flags.append(String(flag))

	saved[SAVE_KEY] = {"flags": flags}
	_write_save(saved)


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	return parsed if parsed is Dictionary else {}


func _write_save(saved: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify(saved))
	file.close()
