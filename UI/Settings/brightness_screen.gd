extends Control

@export var calibration_texture: Texture2D

@onready var _slider: HSlider = %BrightnessSlider
@onready var _panels: Array[TextureRect] = [
	%PanelDark as TextureRect,
	%PanelMid as TextureRect,
	%PanelBright as TextureRect,
]


func _ready() -> void:
	if calibration_texture != null:
		for panel in _panels:
			panel.texture = calibration_texture

	_slider.value_changed.connect(_on_slider_value_changed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	%BackButton.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_sync_from_settings)
	_sync_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func open() -> void:
	show()
	_sync_from_settings()


func _sync_from_settings() -> void:
	_slider.set_value_no_signal(DisplaySettings.brightness)
	_update_panels(DisplaySettings.brightness)


func _on_slider_value_changed(value: float) -> void:
	DisplaySettings.set_brightness(value)
	_update_panels(value)


func _on_reset_pressed() -> void:
	DisplaySettings.reset_brightness()
	_sync_from_settings()


func _on_back_pressed() -> void:
	hide()


func _update_panels(value: float) -> void:
	for panel in _panels:
		var material := panel.material as ShaderMaterial

		if material != null:
			material.set_shader_parameter("brightness", value)
