class_name DesktopWindow
extends GameWindow

@export var normal_wallpaper: TextureRect
@export var EVIL_wallpaper: TextureRect
@export var game_exe: VBoxContainer


func _window_ready() -> void:
	var saved_data := load_data_from_saves()
	var sokoban_finished: bool = saved_data.get("sokoban_finished", false)
	var ctf_revealed: bool = saved_data.get("ctf_revealed", false)

	set_wallpaper(sokoban_finished)
	game_exe.visible = GameMaster.is_flag_raised(&"uploaded_data_to_pc") and not ctf_revealed


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


func _on_close_requested() -> void:
	GameMaster.freezing_main_window.emit(false)
	super()

func _window_process(_delta:float) -> void:
	_keep_apps_inside_plz()

#IT MAKES THE APP TO STAYYYY INSIIIIDE
func _keep_apps_inside_plz() -> void:
	for child in get_children():
		if child is Window:
			var app:= child as Window
			var furthest := size - app.size
			app.position = app.position.clamp(Vector2i.ZERO, furthest)
