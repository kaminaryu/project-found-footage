extends MeshInstance3D

func run(_player: Node) -> void :
	if ($AudioStreamPlayer.playing) :
		stop_music()
	else :
		play_music()


func play_music() -> void :
	GameMaster.show_hint("Playing: Lukrembo - Marshmallow")
	$AudioStreamPlayer.play()
	$CPUParticles3D.emitting = true
	$AnimationPlayer.play("MusicPlaying")

func stop_music() -> void :
	$AudioStreamPlayer.stop()
	$CPUParticles3D.emitting = false
	$AnimationPlayer.stop("MusicPlaying")


func _on_audio_stream_player_finished() -> void:
	stop_music()
