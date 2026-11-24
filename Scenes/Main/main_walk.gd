extends Node3D


func _ready() -> void:
	DisplaySettings.apply_to_scene(self)
	GameMaster.start_game()
