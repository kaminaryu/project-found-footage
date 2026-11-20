@tool
extends Control

const SAVE_DIR := "user://"

var _data: Dictionary = {}
var _editors: Dictionary = {}  # key -> editor Control
var _current_path: String = ""
var _bad_json: bool = false


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
	for key in _data:
		print(key, " -> type ", typeof(_data[key]), " | ", _data[key])
	_clear_rows()
	for key in _data:
		var row := HBoxContainer.new()
		_rows.add_child(row)

		var label := Label.new()
		label.text = str(key)
		label.custom_minimum_size.x = 200
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
		TYPE_ARRAY:
			return _make_array_editor(value)
		TYPE_DICTIONARY:
			return _make_dict_editor(value)
		_:
			# Nested dictionaries, null -> edited as raw JSON text
			var json_line := LineEdit.new()
			json_line.text = JSON.stringify(value)
			json_line.set_meta("json", true)
			return json_line


func _make_array_editor(items: Array) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.set_meta("array", true)
	list.set_meta("sample", items[0] if items.size() > 0 else "")

	for item in items:
		_add_array_row(list, item)

	var add_button := Button.new()
	add_button.text = "+ Add"
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_button.pressed.connect(_on_add_item.bind(list))
	list.add_child(add_button)
	return list

func _make_dict_editor(dict: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_meta("dict", true)

	for key in dict:
		var row := HBoxContainer.new()
		box.add_child(row)

		var label := Label.new()
		label.text = str(key)
		label.custom_minimum_size.x = 120
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(label)

		var item_editor := _make_editor(dict[key])
		item_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_editor)
	return box


func _add_array_row(list: VBoxContainer, item: Variant) -> HBoxContainer:
	var row := HBoxContainer.new()
	list.add_child(row)

	var item_editor := _make_editor(item)
	item_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_editor)

	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.pressed.connect(row.queue_free)
	row.add_child(remove_button)
	return row


func _on_add_item(list: VBoxContainer) -> void:
	var row := _add_array_row(list, _default_like(list.get_meta("sample")))
	list.move_child(row, list.get_child_count() - 2)


func _default_like(sample: Variant) -> Variant:
	match typeof(sample):
		TYPE_BOOL:
			return false
		TYPE_INT, TYPE_FLOAT:
			return 0
		_:
			return ""


func _on_save_pressed() -> void:
	var out := {}
	for key in _editors:
		_bad_json = false
		out[key] = _read_editor(_editors[key])
		if _bad_json:
			_set_status("Bad JSON in '%s', nothing saved" % key)
			return

	var file := FileAccess.open(_current_path, FileAccess.WRITE)
	if file == null:
		_set_status("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return

	file.store_string(JSON.stringify(out, "    "))
	file.close()
	_data = out
	_set_status("Saved " + _current_path)


func _read_editor(editor: Control) -> Variant:
	if editor is CheckBox:
		return editor.button_pressed
	if editor is SpinBox:
		return editor.value
	if editor.has_meta("array"):
		var result := []
		for row in editor.get_children():
			if row is HBoxContainer and not row.is_queued_for_deletion():
				result.append(_read_editor(row.get_child(0)))
		return result
	if editor.has_meta("dict"):
		var result := {}
		for row in editor.get_children():
			result[row.get_child(0).text] = _read_editor(row.get_child(1))
		return result
	if editor.has_meta("json"):
		var parsed = JSON.parse_string(editor.text)
		if parsed == null and editor.text.strip_edges() != "null":
			_bad_json = true
		return parsed
	return editor.text


func _clear_rows() -> void:
	_editors.clear()
	for child in _rows.get_children():
		child.queue_free()


func _set_status(text: String) -> void:
	_status.text = text
