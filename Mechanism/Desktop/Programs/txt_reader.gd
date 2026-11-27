extends GameWindow

@onready var _top_bar = %TopBar
@onready var _content: RichTextLabel = %TextView


func _window_ready() -> void:
	_top_bar.close_pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_pressed)


func open_file(path: String) -> void:
	var is_file_exist := FileAccess.file_exists(path)
	if (not is_file_exist):
		_open_text("Unable to open file:\n%s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if (file == null) :
		_open_text("Unable to open file:\n%s" % path)
		return

	var text := file.get_as_text()
	file.close()
	_open_text(text)


func _open_text(text: String) -> void:
	_content.text = text


func _on_close_pressed() -> void:
	queue_free()
