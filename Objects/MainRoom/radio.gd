extends MeshInstance3D

#Array song radio
@export var songs: Array[AudioStream] = []

var current_song := -1 #This will decide which song will be played (btw -1 means off)

func run(_player: Node) -> void:
	next_song()

#Func tht allows next song to be in the lsit aftr the last song
func next_song() -> void:
	current_song += 1
	
	if (current_song >= songs.size()):
		current_song = -1
		stop_music() #if the playlist done, the radio will be off
	else:
		play_music()

func play_music() -> void:
	var song: AudioStream = songs[current_song]
	$AudioStreamPlayer.stream = song
	GameMaster.show_hint("Now Playing: " + song.resource_path.get_file().get_basename())
	$AudioStreamPlayer.play()
	$CPUParticles3D.emitting = true
	$AnimationPlayer.play("MusicPlaying")
	
func stop_music() -> void :
	$AudioStreamPlayer.stop()
	$CPUParticles3D.emitting = false
	$AnimationPlayer.stop()

func _on_audio_stream_player_finished() -> void:
	next_song() # this allows when the song ended, it will go next ones
