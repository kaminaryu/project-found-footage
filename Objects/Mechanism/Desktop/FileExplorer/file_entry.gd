class_name FileExplorerEntry
extends VBoxContainer

signal activated(entry: FileExplorerEntry)

const DEFAULT_TEXTURE := preload("res://Assets/UI/Desktop/Icons/DefaultIcon64.png")

@export var file_texture: Texture2D = DEFAULT_TEXTURE
@export var file_name: String = "file"
@export var audio_stream: AudioStream

@onready var _thumbnail: TextureButton = $Thumbnail
@onready var _name: Label = $Name


func _ready() -> void:
	_thumbnail.gui_input.connect(_on_thumbnail_gui_input)
	_apply()


func setup(texture: Texture2D, display_name: String, audio: AudioStream = null) -> void:
	file_texture = texture if texture != null else DEFAULT_TEXTURE
	file_name = display_name
	audio_stream = audio

	if is_node_ready():
		_apply()


func _apply() -> void:
	_thumbnail.texture_normal = file_texture
	_name.text = file_name


func _on_thumbnail_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
	):
		activated.emit(self)
		get_viewport().set_input_as_handled()
