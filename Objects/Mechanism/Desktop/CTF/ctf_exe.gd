extends GameWindow

const FLAGS_PATH := "res://Resources/Data/CTF/ctf_flags.json"
const SAVE_PATH := "user://save.json"
const FLAG_FORMAT := "{%s}"

@export var _flag_input: LineEdit
@export var _submit:     Button
@export var _status:     Label
@export var _progress:   Label
@export var _scream_mp3: AudioStreamPlayer

var _flags: Array = []
var _flag_index := 0


func _window_ready() -> void:
	_flags = _load_flags()
	var flag_example := _format_flag("...")
	_flag_input.placeholder_text = flag_example

	var saved_data := _load_save_data()
	_flag_index = clampi(int(saved_data.get("ctf_flag_index", 0)), 0, _flags.size())

	_status.text = "Awaiting flag."
	_refresh_ui()
	_sync_save_progress()

	_submit.pressed.connect(_on_submit_pressed)
	_flag_input.text_submitted.connect(_on_flag_submitted)

	if _flag_input.editable:
		_flag_input.grab_focus()


func _on_submit_pressed() -> void:
	_check_flag(_flag_input.text)


func _on_flag_submitted(text: String) -> void:
	_check_flag(text)


func _check_flag(text: String) -> void:
	if _flags.is_empty() or _flag_index >= _flags.size():
		return

	if _normalize_flag(text) == _normalize_flag(_format_flag(_flags[_flag_index])):
		_flag_index += 1
		_save_progress()
		_flag_input.clear()
		_refresh_ui()

		if _flag_index < _flags.size():
			_status.text = "FLAG ACCEPTED"
			_status.add_theme_color_override("font_color", Color(0.35, 0.85, 0.4, 1))
			_flag_input.grab_focus()
	else:
		_status.text = "INVALID FLAG"
		_status.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
		_flag_input.select_all()
		_flag_input.grab_focus()


func _refresh_ui() -> void:
	if _flags.is_empty():
		_progress.text = "NO FLAGS CONFIGURED"
		_status.text = "Add flags to ctf_flags.json."
		_status.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
		_flag_input.editable = false
		_submit.disabled = true
		return

	if _flag_index >= _flags.size():
		_progress.text = "FLAG %d / %d" % [_flags.size(), _flags.size()]
		_status.text = "CHAIN COMPLETE"
		_status.add_theme_color_override("font_color", Color(0.35, 0.85, 0.4, 1))
		_flag_input.editable = false
		_submit.disabled = true
		
		handle_demo_end()

	else:
		_progress.text = "FLAG %d / %d" % [_flag_index + 1, _flags.size()]
		_flag_input.editable = true
		_submit.disabled = false


func _save_progress() -> void:
	var saved_data := _load_save_data()
	saved_data["ctf_flag_index"] = _flag_index
	saved_data["ctf_complete"] = not _flags.is_empty() and _flag_index >= _flags.size()
	_save_save_data(saved_data)
	get_tree().call_group("desktop_icon", "refresh_visibility")


func _sync_save_progress() -> void:
	var saved_data := _load_save_data()
	var should_complete := not _flags.is_empty() and _flag_index >= _flags.size()
	var saved_index := int(saved_data.get("ctf_flag_index", 0))
	var saved_complete := bool(saved_data.get("ctf_complete", false))

	if saved_index == _flag_index and saved_complete == should_complete:
		return

	saved_data["ctf_flag_index"] = _flag_index
	saved_data["ctf_complete"] = should_complete
	_save_save_data(saved_data)
	get_tree().call_group("desktop_icon", "refresh_visibility")
	


func _load_flags() -> Array:
	var flags: Array = []
	if not FileAccess.file_exists(FLAGS_PATH):
		return flags

	var file := FileAccess.open(FLAGS_PATH, FileAccess.READ)
	if file == null:
		return flags

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Array:
		for entry in parsed:
			if entry is String and not entry.strip_edges().is_empty():
				flags.append(entry)

	return flags


func _load_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _save_save_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(data))
	file.close()


func _format_flag(body: String) -> String:
	return FLAG_FORMAT % body


func _normalize_flag(value: String) -> String:
	return value.replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").strip_edges().to_lower()


func handle_demo_end() -> void :
	_scream_mp3.play()
	await _scream_mp3.finished

	for window in get_tree().get_nodes_in_group("glitchable_window"):
		if window != self and window.has_method("glitch_and_close"):
			window.glitch_and_close(1.2, 1.0)

	glitch_and_close(1.2, 0.8)
	await get_tree().create_timer(1.0).timeout

	GameMaster.freeze_main_window(true)
	GameMaster.raise_flag(&"ctf_completed")
	
