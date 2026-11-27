class_name DesktopWindow
extends GameWindow

@export var normal_wallpaper: TextureRect
@export var EVIL_wallpaper: TextureRect
@export var game_exe: DesktopIconBase
@export var jumpscare_screen: ColorRect
@export var static_sound: AudioStreamPlayer


func _window_ready() -> void:
	jumpscare_screen.hide()
	var saved_data := load_data_from_saves()
	var sokoban_finished: bool = saved_data.get("sokoban_finished", false)
	var ctf_revealed: bool = saved_data.get("ctf_revealed", false)

	set_wallpaper(sokoban_finished)
	game_exe.visible = GameMaster.is_flag_raised(&"uploaded_data_to_pc") and not ctf_revealed

	if (not Engine.is_editor_hint()) :
		initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN   


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

#OOPS JUMPSKEK
func eyes_jumpscare() -> void:
	#every app there glitches
	for child in get_children():
		if child is GameWindow:
			child.glitch_and_close(1.2,1.0)
		elif child is Window:
			child.queue_free()
		glitch(1.2, 1.0)
	await get_tree().create_timer(1.4).timeout
	
	#Black screen with eyes spooky
	jumpscare_screen.show()
	static_sound.play()
	await get_tree().create_timer(2.0).timeout
	
	static_sound.stop()
	_on_close_requested()
	GameMaster.raise_flag(&"desktop_jumpscare_over")
	GameMaster.show_hint("YOU: What... was that?")
	_on_close_requested()
