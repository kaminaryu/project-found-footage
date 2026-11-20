class_name TodoItem
extends HBoxContainer

const TEXT_COLOR := Color("#e8f0ff")
const DIM_COLOR := Color("#6f7f9f")
const DONE_COLOR := Color("#69d98c")

var flag: StringName = &""
var completed := false

@onready var check_label: Label = $Check
@onready var task_text: RichTextLabel = $TaskText

var _text := ""


func setup(text: String, task_flag: StringName, done: bool) -> void:
	_text = text
	flag = task_flag
	completed = done
	_apply_state()


func set_completed(done: bool) -> void:
	if completed == done:
		return

	completed = done
	_apply_state()

	if done:
		_pulse_check()


func _apply_state() -> void:
	check_label.text = "[X]" if completed else "[ ]"
	check_label.add_theme_color_override("font_color", DONE_COLOR if completed else TEXT_COLOR)
	task_text.text = _format_text()
	task_text.modulate = Color(1, 1, 1, 0.5) if completed else Color.WHITE


func _format_text() -> String:
	var escaped := _text.replace("[", "[lb]")

	if completed:
		return "[s][color=#%s]%s[/color][/s]" % [DIM_COLOR.to_html(false), escaped]

	return escaped


func _pulse_check() -> void:
	check_label.pivot_offset = check_label.size * 0.5
	check_label.scale = Vector2(1.4, 1.4)

	var tween := create_tween()
	tween.tween_property(check_label, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
