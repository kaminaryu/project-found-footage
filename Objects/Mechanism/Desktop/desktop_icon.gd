extends Control

@export_group("Configuration")
@export var icon_texture: Texture2D
@export var icon_name: String

@export_group("References")
@export var thumbnail: TextureButton
@export var name_label: Label

const CLICK_BUFFER_TIME_S := 0.3

var click_counter := 0


func _ready() -> void :
	thumbnail.texture_normal = icon_texture
	name_label.text = icon_name


func _process(_delta: float) -> void :
	# double click
	if (click_counter >= 2) :
		_run_program()


func _run_program() -> void :
	get_tree().quit()


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
	timer.queue_free()
