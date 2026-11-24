extends MeshInstance3D

#Array song radio
@export var songs: Array[AudioStream] = []

var current_song := -1 #This will decide which song will be played (btw -1 means off)
const CREEPY_PITCH := 0.7 #how low the music drags after the sokoban (1.0 = normal)
const CREEPY_SONG := 1 #the song the radio plays by itself after the sokoban
var _pitch_tween: Tween
var _haunted := false #true while the radio is playing the creepy song

func _ready() -> void:
	GameMaster.flag_raised.connect(_on_flag_raised)

func _on_flag_raised(flag: StringName) -> void:
	if flag == &"desktop_jumpscare_over":
		_haunt()

#After the sokoban the radio switches to the creepy song by itself and it drags down like a dying cassette tape
func _haunt() -> void:
	_haunted = true
	current_song = CREEPY_SONG
	play_music()
	if _pitch_tween:
		_pitch_tween.kill()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property($AudioStreamPlayer, "pitch_scale", CREEPY_PITCH, 2.0)

func run(_player: Node) -> void:
	if _haunted:
		current_song = -1
		stop_music() #pressing E on the haunted radio switches it off
	else:
		next_song()
	$ButtonClick.play()

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
	GameMaster.show_hint("Stopped playing.")
	$AudioStreamPlayer.stop()
	$CPUParticles3D.emitting = false
	$AnimationPlayer.stop()
	if _pitch_tween:
		_pitch_tween.kill() 
	$AudioStreamPlayer.pitch_scale = 1.0 #back to normal for next time
	_haunted = false

func _on_audio_stream_player_finished() -> void:
	next_song() # this allows when the song ended, it will go next ones
