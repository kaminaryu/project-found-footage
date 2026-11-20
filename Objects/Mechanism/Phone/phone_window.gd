extends Window
## The phone's own OS window. All the phone logic lives in PhoneUI (Objects/Phone/phone_ui.gd).
## This script only grabs focus and passes "close me" on to the player (player.gd listens to close_requested).


func _ready() -> void:
	grab_focus()
	# Q / Esc inside the phone -> PhoneUI asks to close -> the window tells the player.
	$PhoneUI.close_requested.connect(close_requested.emit)
	$PhoneUI.gui_input.connect(_on_phone_gui_input)

func _on_phone_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_drag()
