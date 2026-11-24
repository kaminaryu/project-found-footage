extends MarginContainer

@onready var _keybind_list: VBoxContainer = $VBoxContainer/MarginContainer/KeybindList
@onready var _reset_button: Button = %ResetButton

var _buttons: Dictionary = {}
var _listening_action := &""
var _listening_button: Button = null


func _ready() -> void:
	set_process_input(false)

	for row in _keybind_list.get_children():
		var action := _row_action(row)

		if action == &"":
			continue

		var button := row.get_node_or_null("Keybind") as Button

		if button == null:
			continue

		_buttons[action] = button
		button.pressed.connect(_on_bind_pressed.bind(action, button))

	_reset_button.pressed.connect(_on_reset_pressed)
	KeybindSettings.bindings_changed.connect(_refresh_bindings)
	_refresh_bindings()


func _row_action(row: Node) -> StringName:
	var value: Variant = row.get_meta("action", &"")
	return value if value is StringName else StringName(value)


func _on_bind_pressed(action: StringName, button: Button) -> void:
	if _listening_action != &"":
		_stop_listening()

	_listening_action = action
	_listening_button = button
	button.text = "Press a key..."
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _listening_action == &"":
		return

	if event is InputEventKey:
		if not event.pressed or event.echo:
			return

		if event.keycode == KEY_ESCAPE:
			_stop_listening()
			get_viewport().set_input_as_handled()
			return

		_assign_binding(event)
	elif event is InputEventMouseButton:
		if not event.pressed:
			return

		_assign_binding(event)


func _assign_binding(event: InputEvent) -> void:
	KeybindSettings.set_binding(_listening_action, event)
	_stop_listening()
	get_viewport().set_input_as_handled()


func _stop_listening() -> void:
	_listening_action = &""
	_listening_button = null
	set_process_input(false)
	_refresh_bindings()


func _on_reset_pressed() -> void:
	if _listening_action != &"":
		_stop_listening()

	KeybindSettings.reset_all()


func _refresh_bindings() -> void:
	for action in _buttons:
		var button: Button = _buttons[action]

		if button == _listening_button:
			continue

		button.text = KeybindSettings.get_action_key_label(StringName(action))
