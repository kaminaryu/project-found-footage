extends MarginContainer

@export var brightness_screen: Control


func _on_adjust_button_pressed() -> void:
	brightness_screen.open()
