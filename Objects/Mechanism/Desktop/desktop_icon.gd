extends Control

const CLICK_BUFFER_TIME_S := 0.3
const ERROR_POPUP_SCENE := preload("res://Objects/Mechanism/Desktop/ErrorPopup.tscn")

@export_group("Configuration")
@export var icon_texture: Texture2D
@export var icon_name: String
@export var application: PackedScene

@export_group("Launch Guard")
@export var blocked_save_flag: String = ""
@export var blocked_title: String = "System Error"
@export_multiline var blocked_message: String = "This program has stopped working."
@export var blocked_icon: Texture2D

@export_group("References")
@export var thumbnail: TextureButton
@export var name_label: Label

var click_counter := 0
var _launch_popup: ErrorPopup


func _ready() -> void :
	thumbnail.texture_normal = icon_texture
	name_label.text = icon_name


func _process(_delta: float) -> void :
	# double click
	if (click_counter >= 2) :
		click_counter = 0
		_run_program()


func _run_program() -> void :
	if (not application) :
		get_tree().quit()
		return

	if (_blocked_by_save_flag()) :
		_show_blocked_popup()
		return

	var app := application.instantiate()
	get_tree().root.add_child(app)


func _blocked_by_save_flag() -> bool:
	if blocked_save_flag.is_empty():
		return false

	return bool(_load_save_data().get(blocked_save_flag, false))


func _show_blocked_popup() -> void:
	if _launch_popup == null:
		_launch_popup = get_window().get_node_or_null("ErrorPopup") as ErrorPopup

	if _launch_popup == null:
		_launch_popup = ERROR_POPUP_SCENE.instantiate() as ErrorPopup
		add_child(_launch_popup)

	_launch_popup.trigger(blocked_message, blocked_icon, blocked_title)


func _load_save_data() -> Dictionary:
	if not FileAccess.file_exists("user://save.json"):
		return {}

	var file := FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _on_thumbnail_pressed() -> void:
	click_counter += 1

	var timer = Timer.new()
	timer.wait_time = CLICK_BUFFER_TIME_S
	timer.timeout.connect(_click_no_longer_double_clicking_idk_what_to_name.bind(timer))
	timer.autostart = true
	timer.one_shot = true
	get_tree().root.add_child(timer)


func _click_no_longer_double_clicking_idk_what_to_name(timer: Timer) -> void :
	click_counter -= 1
	click_counter = max(click_counter, 0)
	timer.queue_free()
