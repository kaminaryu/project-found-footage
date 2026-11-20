class_name WindowTopBar
extends PanelContainer

signal close_pressed

@export var title_text: String = ""

@onready var _title: Label = %TitleLabel
@onready var _close: Button = %Close


func _ready() -> void:
	_title.text = title_text
	_close.pressed.connect(_on_close_pressed)


func set_title(value: String) -> void:
	title_text = value
	if is_node_ready():
		_title.text = value


func _on_close_pressed() -> void:
	close_pressed.emit()
