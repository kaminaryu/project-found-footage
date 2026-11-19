class_name DesktopWindow
extends GameWindow

@export var normal_wallpaper: TextureRect
@export var EVIL_wallpaper: TextureRect



func _window_ready() -> void:
	var saved_data := load_data_from_saves()
	var sokoban_finished: bool = saved_data.get("sokoban_finished", false)

	print(saved_data)

	set_wallpaper(sokoban_finished)


func load_data_from_saves() -> Dictionary :
	if not FileAccess.file_exists("user://save.json"):
		return {}

	var file := FileAccess.open("user://save.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func set_wallpaper(sokoban_finished: bool) -> void :
	if (sokoban_finished) :
		normal_wallpaper.hide()
		EVIL_wallpaper.show()
	
	else :
		normal_wallpaper.show()
		EVIL_wallpaper.hide()
