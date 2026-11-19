extends Node2D

@export var window_size: Vector2

@onready var desktop_window_scene := preload("res://Objects/Mechanism/Desktop/Desktopwindow.tscn")

func _ready() -> void:
	# make it open up a new ass window
	get_tree().root.gui_embed_subwindows = false


func _on_button_pressed() -> void:
	# var desktop_win =  Window.new()
	#
	# desktop_win.title = "User Desktop"
	# desktop_win.size = window_size
	#
	# # when closing the image
	# desktop_win.close_requested.connect(desktop_win.queue_free)
	#
	# get_tree().root.add_child(desktop_win)
	# desktop_win.popup_centered()
	var desktop_win = desktop_window_scene.instantiate()

	add_child(desktop_win)
