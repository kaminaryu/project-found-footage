@tool
class_name WindowTopBar
extends WindowDragHandle

signal close_pressed

@export var title_text: String = "" :
	set(value) :
		title_text = value
		_update_visual()

@onready var _title: Label = %TitleLabel
@onready var _close: TextureButton = %Close


func _ready() -> void:
	if (Engine.is_editor_hint()) :
		return

	_title.text = title_text
	_close.pressed.connect(_on_close_pressed)


func set_title(value: String) -> void:
	title_text = value


func _update_visual() -> void :
	if is_node_ready():
		_title.text = title_text


func _on_close_pressed() -> void:
	close_pressed.emit()


func _on_close_mouse_entered() -> void:
	_close.material.set_shader_parameter("flash_value", 0.2)


func _on_close_mouse_exited() -> void:
	_close.material.set_shader_parameter("flash_value", 0.0)
