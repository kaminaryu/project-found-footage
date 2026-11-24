extends Control

@onready var _brightness_screen: Control = $BrightnessScreen


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		if _brightness_screen != null and _brightness_screen.is_visible_in_tree():
			return

		hide()
		get_viewport().set_input_as_handled()
