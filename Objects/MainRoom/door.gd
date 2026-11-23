extends Node3D

var _is_door_open := false
var _is_animation_running := false

func run(_player: Node) -> void :
	if (_is_animation_running) :
		return

	_is_animation_running = true
	var sound := $AudioStreamPlayer as AudioStreamPlayer
	$AudioStreamPlayer.pitch_scale = randf_range(0.9, 1.1)
	$AudioStreamPlayer.play()
	if (_is_door_open) :
		$AnimationPlayer.play("DoorClose")
		_is_door_open = false
	else :
		$AnimationPlayer.play("DoorOpen")
		_is_door_open = true


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	_is_animation_running = false
