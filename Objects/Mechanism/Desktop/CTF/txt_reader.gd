extends Window

@export_file("*.txt") var file_path: String = "res://Resources/Data/CTF/Texts/readme.txt"

@onready var _top_bar = %TopBar
@onready var _content: RichTextLabel = %TextView
@onready var _copy: Button = %Copy

var _content_text := ""


func _ready() -> void:
	_top_bar.close_pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_pressed)
	_copy.pressed.connect(_copy_all)

	if not file_path.is_empty():
		open_file(file_path)


func open_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		open_text("Text Reader", "Unable to open file:\n%s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		open_text("Text Reader", "Unable to open file:\n%s" % path)
		return

	var text := file.get_as_text()
	file.close()
	open_text(path.get_file(), text)


func open_text(display_title: String, text: String) -> void:
	_content_text = text
	title = display_title
	_top_bar.set_title(display_title)
	_content.text = text


func _copy_all() -> void:
	DisplayServer.clipboard_set(_content_text)


func _on_close_pressed() -> void:
	queue_free()
