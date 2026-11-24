extends Node

signal bindings_changed

const SETTINGS_PATH := "user://keybinds.json"
const KEYBINDS_KEY := "keybinds"

const ACTION_ORDER: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
	&"crouch",
	&"interact",
	&"use_phone",
	&"take_item",
	&"quit",
	&"skip_cutscene",
]

const ACTION_LABELS := {
	&"move_forward": "Move Forward",
	&"move_back": "Move Back",
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	&"crouch": "Crouch",
	&"interact": "Interact",
	&"use_phone": "Use Phone",
	&"take_item": "Take Item",
	&"quit": "Quit",
	&"skip_cutscene": "Skip Cutscene",
}

var _defaults: Dictionary = {}
var _overrides: Dictionary = {}


func _ready() -> void:
	_cache_defaults()
	_load()
	_apply_overrides()


func get_action_label(action: StringName) -> String:
	return ACTION_LABELS.get(action, String(action).capitalize())


func get_action_key_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)

	if events.is_empty():
		return "Unbound"

	var labels: Array[String] = []

	for event in events:
		labels.append(_event_to_text(event))

	return " / ".join(labels)


func set_binding(action: StringName, event: InputEvent) -> void:
	if event == null or not InputMap.has_action(action):
		return

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_overrides[String(action)] = [_serialize_event(event)]
	_save()
	bindings_changed.emit()


func reset_all() -> void:
	_overrides.clear()

	for action in ACTION_ORDER:
		_restore_default(action)

	_save()
	bindings_changed.emit()


func reset_action(action: StringName) -> void:
	_overrides.erase(String(action))
	_restore_default(action)
	_save()
	bindings_changed.emit()


func _cache_defaults() -> void:
	for action in ACTION_ORDER:
		if not InputMap.has_action(action):
			continue

		var events: Array = []

		for event in InputMap.action_get_events(action):
			events.append(event.duplicate())

		_defaults[String(action)] = events


func _restore_default(action: StringName) -> void:
	var events: Variant = _defaults.get(String(action))

	if not events is Array:
		return

	InputMap.action_erase_events(action)

	for event in events:
		InputMap.action_add_event(action, (event as InputEvent).duplicate())


func _apply_overrides() -> void:
	for action in _overrides:
		if not InputMap.has_action(action):
			continue

		var saved: Variant = _overrides[action]

		if not saved is Array:
			continue

		InputMap.action_erase_events(action)

		for data in saved:
			if not data is Dictionary:
				continue

			var event := _deserialize_event(data)

			if event != null:
				InputMap.action_add_event(action, event)


func _event_to_text(event: InputEvent) -> String:
	var text := ""

	if event is InputEventKey:
		var key := event as InputEventKey
		var keycode: int = key.keycode if key.keycode != 0 else key.physical_keycode

		text = OS.get_keycode_string(keycode)

		if text.is_empty():
			return "Unbound"
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		text = _mouse_button_name(mouse.button_index)
	else:
		text = event.as_text()

	var parts: Array[String] = []

	if event is InputEventWithModifiers:
		var modified := event as InputEventWithModifiers

		if modified.ctrl_pressed:
			parts.append("Ctrl")
		if modified.shift_pressed:
			parts.append("Shift")
		if modified.alt_pressed:
			parts.append("Alt")
		if modified.meta_pressed:
			parts.append("Meta")

	parts.append(text)
	return "+".join(parts)


func _mouse_button_name(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "Left Click"
		MOUSE_BUTTON_RIGHT:
			return "Right Click"
		MOUSE_BUTTON_MIDDLE:
			return "Middle Click"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "Wheel Right"
		_:
			return "Mouse %d" % button_index


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey

		return {
			"type": "key",
			"keycode": key.keycode,
			"physical_keycode": key.physical_keycode,
			"ctrl": key.ctrl_pressed,
			"shift": key.shift_pressed,
			"alt": key.alt_pressed,
			"meta": key.meta_pressed,
		}

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton

		return {
			"type": "mouse",
			"button_index": mouse.button_index,
			"ctrl": mouse.ctrl_pressed,
			"shift": mouse.shift_pressed,
			"alt": mouse.alt_pressed,
			"meta": mouse.meta_pressed,
		}

	return {}


func _deserialize_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var key := InputEventKey.new()
			key.keycode = int(data.get("keycode", 0))
			key.physical_keycode = int(data.get("physical_keycode", 0))
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.shift_pressed = bool(data.get("shift", false))
			key.alt_pressed = bool(data.get("alt", false))
			key.meta_pressed = bool(data.get("meta", false))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button_index", MOUSE_BUTTON_LEFT))
			mouse.ctrl_pressed = bool(data.get("ctrl", false))
			mouse.shift_pressed = bool(data.get("shift", false))
			mouse.alt_pressed = bool(data.get("alt", false))
			mouse.meta_pressed = bool(data.get("meta", false))
			return mouse

	return null


func _save() -> void:
	var saved := _read()

	if _overrides.is_empty():
		saved.erase(KEYBINDS_KEY)
	else:
		saved[KEYBINDS_KEY] = _overrides

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify(saved))
	file.close()


func _load() -> void:
	var saved := _read()
	var data: Variant = saved.get(KEYBINDS_KEY, {})

	_overrides = data if data is Dictionary else {}


func _read() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	return parsed if parsed is Dictionary else {}
