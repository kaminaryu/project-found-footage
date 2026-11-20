extends MeshInstance3D

@export var window_size: Vector2

@onready var desktop_window_scene := preload("res://Scenes/Mechanism/Desktop/Desktopwindow.tscn")

var desktop_win: Window

func run() -> void:
	# if the window is already opened
	if (is_instance_valid(desktop_win) and not desktop_win.is_queued_for_deletion()) :
		desktop_win.move_to_foreground()
		desktop_win.grab_focus()
		return

	GameMaster.freezing_main_window.emit(true)

	desktop_win = desktop_window_scene.instantiate()
	add_child(desktop_win)
