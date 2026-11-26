class_name  GameWindow
extends Window

const GlitchOverlayScene := preload("res://Objects/Mechanism/Desktop/glitch_overlay.tscn")
const SHAKE_RANGE := 4
const SHAKE_INTERVAL := 0.035

var _glitch_overlay
var _is_glitching := false
var _shake_time := 0.0
var _shake_tick := 0.0
var _shake_base_position := Vector2i.ZERO


func _ready() -> void:
	_setup_shared()
	_window_ready()


func glitch(duration: float = 1.0, strength: float = 1.0) -> void:
	if _is_glitching:
		return

	_is_glitching = true
	_glitch_overlay.play(duration, strength)
	_start_shake(duration)
	await get_tree().create_timer(duration + 0.05).timeout
	_is_glitching = false


func glitch_and_close(duration: float = 1.0, strength: float = 1.0) -> void:
	await glitch(duration, strength)
	_on_close_requested()


func _window_ready() -> void:
	pass


func _window_process(_delta: float) -> void:
	pass


func _window_key_input(_event: InputEvent) -> void:
	pass


func _process(delta: float) -> void:
	_update_shake(delta)
	_window_process(delta)


func _setup_shared() -> void:
	_glitch_overlay = GlitchOverlayScene.instantiate()
	add_child(_glitch_overlay)
	add_to_group("glitchable_window")


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return

	_shake_time -= delta
	if _shake_time <= 0.0:
		position = _shake_base_position
		return

	_shake_tick -= delta
	if _shake_tick > 0.0:
		return

	_shake_tick = SHAKE_INTERVAL
	position = _shake_base_position + Vector2i(
		randi_range(-SHAKE_RANGE, SHAKE_RANGE),
		randi_range(-SHAKE_RANGE, SHAKE_RANGE)
	)


func _start_shake(duration: float) -> void:
	_shake_base_position = position
	_shake_time = duration
	_shake_tick = 0.0


func _on_close_pressed() -> void:
	_on_close_requested()


func _on_close_requested() -> void:
	queue_free()
