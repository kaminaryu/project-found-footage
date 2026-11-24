extends Node

signal brightness_changed(value: float)

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_KEY := "brightness"
const DEFAULT_BRIGHTNESS := 1.0
const MIN_BRIGHTNESS := 0.5
const MAX_BRIGHTNESS := 2.0

var brightness := DEFAULT_BRIGHTNESS


func _ready() -> void:
	_load()
	call_deferred("apply_to_current_scene")


func set_brightness(value: float) -> void:
	var clamped := clampf(value, MIN_BRIGHTNESS, MAX_BRIGHTNESS)

	if is_equal_approx(clamped, brightness):
		return

	brightness = clamped
	apply_to_current_scene()
	_save()
	brightness_changed.emit(brightness)


func reset_brightness() -> void:
	set_brightness(DEFAULT_BRIGHTNESS)


func apply_to_current_scene() -> void:
	apply_to_scene(get_tree().current_scene)


func apply_to_scene(scene: Node) -> void:
	if scene == null:
		return

	var world_environment := _find_world_environment(scene)

	if world_environment == null or world_environment.environment == null:
		return

	var environment := world_environment.environment
	environment.adjustment_enabled = true
	environment.adjustment_brightness = brightness


func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node

	for child in node.get_children():
		var found := _find_world_environment(child)

		if found != null:
			return found

	return null


func _save() -> void:
	var saved := _read()
	saved[SETTINGS_KEY] = brightness
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify(saved))
	file.close()


func _load() -> void:
	var saved := _read()
	var value: Variant = saved.get(SETTINGS_KEY, DEFAULT_BRIGHTNESS)

	if value is float or value is int:
		brightness = clampf(float(value), MIN_BRIGHTNESS, MAX_BRIGHTNESS)


func _read() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	return parsed if parsed is Dictionary else {}
