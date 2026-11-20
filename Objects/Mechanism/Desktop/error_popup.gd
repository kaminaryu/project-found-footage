class_name ErrorPopup
extends CanvasLayer

signal closed

@export_multiline var message: String = "Something went wrong."
@export var icon: Texture2D = preload("res://Assets/UI/Desktop/Icons/Error64.svg")
@export var header_text: String = "Error"
@export var animate: bool = true

@onready var _backdrop: Control = %Backdrop
@onready var _dialog: PanelContainer = %Dialog
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %TitleLabel
@onready var _message: Label = %MessageLabel
@onready var _ok_button: Button = %OkButton
@onready var _close_button: Button = %CloseButton

var _tween: Tween
var _is_open := false


func _ready() -> void:
	_close_button.pressed.connect(close)
	_ok_button.pressed.connect(close)
	_apply_content("", null, "")
	hide()


func trigger(custom_message: String = "", custom_icon: Texture2D = null, custom_header: String = "") -> void:
	_apply_content(custom_message, custom_icon, custom_header)

	if _is_open:
		_ok_button.grab_focus()
		return

	_is_open = true
	if get_parent() != null:
		get_parent().move_child(self, -1)

	show()
	_ok_button.grab_focus()

	if animate:
		_animate_in()
	else:
		_reset_visuals()


func close() -> void:
	if not _is_open:
		return

	_is_open = false
	_kill_tween()
	_ok_button.release_focus()
	hide()
	closed.emit()


func _apply_content(custom_message: String, custom_icon: Texture2D, custom_header: String) -> void:
	_message.text = message if custom_message.is_empty() else custom_message
	_title.text = header_text if custom_header.is_empty() else custom_header

	var texture: Texture2D = icon if custom_icon == null else custom_icon
	_icon.texture = texture
	_icon.visible = texture != null


func _animate_in() -> void:
	_kill_tween()
	_backdrop.modulate.a = 0.0
	_dialog.scale = Vector2(0.94, 0.94)
	await get_tree().process_frame

	if not _is_open:
		return

	_dialog.pivot_offset = _dialog.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.12)
	_tween.tween_property(_dialog, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_visuals() -> void:
	_backdrop.modulate.a = 1.0
	_dialog.scale = Vector2.ONE


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _unhandled_key_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		close()

	get_viewport().set_input_as_handled()
