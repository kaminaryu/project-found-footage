extends Control

func _process(delta: float) -> void :
	if (GameMaster.is_flag_raised(&"ctf_completed")) :
		show()
		GameMaster.freeze_main_window(true)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu/main_menu.tscn")
