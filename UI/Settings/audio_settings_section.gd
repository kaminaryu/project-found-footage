extends MarginContainer

@onready var _sliders: Dictionary = {
	&"Master": %MasterSlider,
	&"Music": %MusicSlider,
	&"SFX": %SfxSlider,
	&"Voice": %VoiceSlider,
}


func _ready() -> void:
	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index == -1:
			push_warning("Audio settings: missing bus " + str(bus_name))
			slider.editable = false
			continue

		slider.value = 0.0 if AudioServer.is_bus_mute(bus_index) else _db_to_slider(AudioServer.get_bus_volume_db(bus_index))
		slider.value_changed.connect(_on_slider_value_changed.bind(bus_index))


func _on_slider_value_changed(value: float, bus_index: int) -> void:
	var muted := value <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	AudioServer.set_bus_volume_db(bus_index, -80.0 if muted else linear_to_db(value / 100.0))


func _db_to_slider(db: float) -> float:
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)
