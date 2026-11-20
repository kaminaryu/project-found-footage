@tool
extends Control

const SAVE_DIR := "user://"

var _data: Dictionary = {}
var _editors: Dictionary = {}  # key -> editor Control
var _current_path: String = ""

@onready var _file_picker: OptionButton = %FilePicker
@onready var _rows: VBoxContainer = %Rows
@onready var _status: Label = %Status


func _ready() -> void:
	_refresh_file_list()


func _refresh_file_list() -> void:
	_file_picker.clear()
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		if file_name.get_extension() == "json":
			_file_picker.add_item(file_name)

	if _file_picker.item_count == 0:
		_clear_rows()
		_set_status("No .json files in user://")
		return

	_file_picker.select(0)
	_on_file_selected(0)


func _on_file_selected(index: int) -> void:
	_current_path = SAVE_DIR + _file_picker.get_item_text(index)

	var file := FileAccess.open(_current_path, FileAccess.READ)
	if file == null:
		_clear_rows()
		_set_status("Open failed: %s" % error_string(FileAccess.get_open_error()))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		_data = parsed
		_build_rows()
		_set_status("Loaded " + _current_path)
	else:
		_clear_rows()
		_set_status("Not a JSON object, can't edit")


func _build_rows() -> void:
	_clear_rows()
	for key in _data:
		var row := HBoxContainer.new()
		_rows.add_child(row)

		var label := Label.new()
		label.text = str(key)
		label.custom_minimum_size.x = 200
		row.add_child(label)

		var editor := _make_editor(_data[key])
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(editor)
		_editors[key] = editor


func _make_editor(value: Variant) -> Control:
	match typeof(value):
		TYPE_BOOL:
			var box := CheckBox.new()
			box.button_pressed = value
			return box
		TYPE_INT, TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.min_value = -1e12
			spin.max_value = 1e12
			spin.step = 0.001
			spin.update_on_text_changed = true
			spin.value = value
			return spin
		TYPE_STRING:
			var line := LineEdit.new()
			line.text = value
			return line
		_:
			# Arrays, nested dictionaries, null -> edited as raw JSON text
			var json_line := LineEdit.new()
			json_line.text = JSON.stringify(value)
			return json_line


func _on_save_pressed() -> void:
	var out := {}
	for key in _editors:
		var editor: Control = _editors[key]
		if editor is CheckBox:
			out[key] = editor.button_pressed
		elif editor is SpinBox:
			out[key] = editor.value
		elif typeof(_data[key]) == TYPE_STRING:
			out[key] = editor.text
		else:
			var parsed = JSON.parse_string(editor.text)
			if parsed == null and editor.text.strip_edges() != "null":
				_set_status("Bad JSON in '%s', nothing saved" % key)
				return
			out[key] = parsed

	var file := FileAccess.open(_current_path, FileAccess.WRITE)
	if file == null:
		_set_status("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return

	file.store_string(JSON.stringify(out, "    "))
	file.close()
	_data = out
	_set_status("Saved " + _current_path)


func _clear_rows() -> void:
	_editors.clear()
	for child in _rows.get_children():
		child.queue_free()


func _set_status(text: String) -> void:
	_status.text = text
