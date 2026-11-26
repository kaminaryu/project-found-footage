class_name  GameWindow
extends Window

const GlitchOverlayScene := preload("res://Mechanism/Desktop/Overlays/glitch_overlay.tscn")
const SHAKE_RANGE := 4
const SHAKE_INTERVAL := 0.035

var _glitch_overlay
var _is_glitching := false
var _shake_time := 0.0
var _shake_tick := 0.0
var _shake_base_position := Vector2i.ZERO
@export var skip_open_animation := false;

## Base ready function for all programs
func _ready() -> void:
	_setup_shared()
	_window_ready()
	if !skip_open_animation: _play_open_animation();


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

## Ready function for anything specific to the program.
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

func _play_open_animation() -> void:
	var target_size = size;
	var size_delta = Vector2i(100,100);
	var sb = get_theme_stylebox('embedded_border')
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT);
	if get_theme_stylebox('embedded_border') is StyleBoxTexture: tween.tween_property(sb,"modulate_color:a", 1.0, 0.3).from(0.0);
	tween.tween_property(self, "size", target_size, 0.3).from(target_size - size_delta) 
	tween.tween_property(self, "position", position - (size_delta / 2), 0.3);

func _start_shake(duration: float) -> void:
	_shake_base_position = position
	_shake_time = duration
	_shake_tick = 0.0


func _on_close_pressed() -> void:
	_on_close_requested()


func _on_close_requested() -> void:
	queue_free()
