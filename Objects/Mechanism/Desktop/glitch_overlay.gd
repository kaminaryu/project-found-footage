class_name GlitchOverlay
extends CanvasLayer

signal finished

@onready var _color_rect: ColorRect = $ColorRect
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer

var _material: ShaderMaterial
var _tween: Tween
var _playing := false


func _ready() -> void:
	_material = (_color_rect.material as ShaderMaterial).duplicate()
	_color_rect.material = _material
	_color_rect.hide()
	_set_intensity(0.0)


func play(duration := 1.0, strength := 1.0) -> void:
	if _playing:
		return

	_playing = true
	_color_rect.show()
	_reroll_seed()

	if _audio.stream != null:
		_audio.pitch_scale = randf_range(0.85, 1.15)
		_audio.play()

	var pulses := maxi(3, roundi(duration / 0.09))
	var step := duration / float(pulses)
	var current := 0.0

	_tween = create_tween()
	_tween.tween_method(_set_intensity, current, strength, step * 0.5)
	current = strength
	_tween.tween_callback(_reroll_seed)

	for i in pulses - 1:
		var peak := randf_range(0.35, 1.0) * strength
		_tween.tween_method(_set_intensity, current, peak, step * 0.35)
		current = peak

		var low := peak * randf_range(0.0, 0.4)
		_tween.tween_method(_set_intensity, current, low, step * 0.65)
		current = low
		_tween.tween_callback(_reroll_seed)

	_tween.tween_method(_set_intensity, current, 0.0, step * 0.5)
	_tween.finished.connect(_on_tween_finished)


func _on_tween_finished() -> void:
	_playing = false
	_color_rect.hide()
	finished.emit()


func _reroll_seed() -> void:
	_set_seed(randf() * 100.0)


func _set_intensity(value: float) -> void:
	_material.set_shader_parameter("intensity", value)


func _set_seed(value: float) -> void:
	_material.set_shader_parameter("seed", value)
