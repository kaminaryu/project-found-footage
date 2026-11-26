class_name WindowDragHandle
extends Control


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		get_window().grab_focus()
		get_window().start_drag()
		accept_event()
