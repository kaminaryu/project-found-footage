@tool
extends VBoxContainer

@onready var thumbnail_node: TextureButton = %"Thumbnail"
@onready var name_node: Label = %"Name"


func update_thumbnail(texture: Texture2D) -> void :
	thumbnail_node.texture_normal = texture


func update_name(icon_name: String) -> void :
	name_node.text = icon_name


func update_name_color(color: Color) -> void :
	name_node.add_theme_color_override("font_color", color)
