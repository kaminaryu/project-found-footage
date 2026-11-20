extends MeshInstance3D

func run() -> void :
	if ($AudioStreamPlayer.playing) :
		$AudioStreamPlayer.stop()
		$CPUParticles3D.emitting = false
	else :
		$AudioStreamPlayer.play()
		$CPUParticles3D.emitting = true


func _on_audio_stream_player_finished() -> void:
	$CPUParticles3D.emitting = false
