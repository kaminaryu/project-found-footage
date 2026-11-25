@tool
extends Control

const CLICK_BUFFER_TIME_S := 0.3
const ERROR_POPUP_SCENE := preload("res://Objects/Mechanism/Desktop/ErrorPopup.tscn")
const DEFAULT_TEXTURE := preload("res://Assets/UI/Desktop/Icons/DefaultIcon64.png")

signal blocked_launch_attempted

@export_group("Configuration")
@export var icon_texture: Texture2D = DEFAULT_TEXTURE:
	set(value):
		icon_texture = value
		_apply_visuals()
@export var icon_name: String = "Application":
	set(value):
		icon_name = value
		_apply_visuals()
@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		_apply_visuals()
@export var application: PackedScene
@export_file("*.txt") var launch_file: String = ""
@export var photo_index := -1

@export_group("Launch Guard")
@export var blocked_save_flag: String = ""
@export var blocked_title: String = "System Error"
@export_multiline var blocked_message: String = "This program has stopped working."
@export var blocked_icon: Texture2D

@export_group("Reveal")
@export var hidden_until_revealed: bool = false
@export var reveal_save_flag: String = ""
@export var hide_if_save_flag: String = ""

@export_group("Stage Visibility")
@export var show_from_flag_stage: int = -1

@export_group("Unlock")
@export var unlock_game_flag: StringName = &""

@export_group("References")
@export var thumbnail: TextureButton
@export var name_label: Label

var click_counter := 0
var _launch_popup: ErrorPopup


func _ready() -> void :
	_apply_visuals()

	if Engine.is_editor_hint():
		set_process(false)
		return

	add_to_group("desktop_icon")
	refresh_visibility()


func _apply_visuals() -> void:
	if thumbnail == null or name_label == null:
		return

	thumbnail.texture_normal = icon_texture if icon_texture != null else DEFAULT_TEXTURE
	name_label.text = icon_name
	name_label.add_theme_color_override("font_color", text_color)


func _process(_delta: float) -> void :
	if Engine.is_editor_hint():
		return

	# double click
	if (click_counter >= 2) :
		click_counter = 0
		_run_program()


func _run_program() -> void :
	if (not application) :
		# get_tree().quit()
		return

	if (_blocked_by_save_flag()) :
		_show_blocked_popup()
		return

	var app := application.instantiate()
	_get_desktop_window().add_child(app)  # this allows app to open INSIDE the desktop window and not the main game window


	# for txt reader
	if not launch_file.is_empty() and app.has_method("open_file"):
		app.call("open_file", launch_file)

	# for photo editor
	if photo_index != -1 and app.has_method("set_selected_photo") :
		app.set_selected_photo(photo_index)


func _get_desktop_window() -> Window:
	var node: Node = get_parent()
	while node != null:
		if node is DesktopWindow:
			return node
		node = node.get_parent()
	return get_window()


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
	GameMaster.raise_flag(&"rerun_the_game")

	if not _launch_popup.closed.is_connected(_on_blocked_popup_closed):
		_launch_popup.closed.connect(_on_blocked_popup_closed, CONNECT_ONE_SHOT)


func _on_blocked_popup_closed() -> void :
	blocked_launch_attempted.emit()


func reveal() -> void :
	_show_icon()

	if not reveal_save_flag.is_empty():
		var saved_data := _load_save_data()
		saved_data[reveal_save_flag] = true
		_save_save_data(saved_data)

	get_tree().call_group("desktop_icon", "refresh_visibility")



func refresh_visibility() -> void:
	var saved_data := _load_save_data()
	var should_show := true

	if hidden_until_revealed:
		should_show = bool(saved_data.get(reveal_save_flag, false))

	if not hide_if_save_flag.is_empty() and bool(saved_data.get(hide_if_save_flag, false)):
		should_show = false

	if show_from_flag_stage > 0:
		var current_stage := int(saved_data.get("ctf_flag_index", 0)) + 1
		if current_stage < show_from_flag_stage:
			should_show = false

	if unlock_game_flag != &"" and not GameMaster.is_flag_raised(unlock_game_flag):
		should_show = false

	if should_show:
		_show_icon()
	else:
		hide_icon()


func _show_icon() -> void :
	click_counter = 0
	visible = true
	set_process(true)


func hide_icon() -> void :
	click_counter = 0
	hide()
	set_process(false)


func _load_save_data() -> Dictionary:
	if not FileAccess.file_exists("user://save.json"):
		return {}

	var file := FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _save_save_data(data: Dictionary) -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(data))
	file.close()


func _on_thumbnail_pressed() -> void:
	if Engine.is_editor_hint():
		return

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


func _on_thumbnail_button_down() -> void:
	thumbnail.material.set_shader_parameter("flash_value", 0.5);


func _on_thumbnail_button_up() -> void:
	thumbnail.material.set_shader_parameter("flash_value", 0);
