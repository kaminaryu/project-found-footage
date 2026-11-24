class_name SFXPlayer
extends Node

@export var audio_stream: AudioStream
@export var volume_db: float = 0.0
@export var default_pitch: float = 1.0
@export var randomize_pitch: bool = true
@export var polyphony: int = 8

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var _playback: AudioStreamPlaybackPolyphonic
var _active: Array[int] = []


func _ready() -> void :
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = maxi(polyphony, 2)
	audio_player.stream = poly
	audio_player.volume_db = volume_db
	audio_player.play()
	_playback = audio_player.get_stream_playback() as AudioStreamPlaybackPolyphonic


func play() -> void :
	if audio_stream == null or _playback == null:
		return

	_prune()

	if polyphony == 1:
		stop()

	var pitch := default_pitch
	if randomize_pitch:
		pitch += randf_range(-0.1, 0.1)

	var id := _playback.play_stream(audio_stream, 0.0, 0.0, pitch)
	if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_active.append(id)


func stop() -> void :
	if _playback == null:
		return

	for id in _active:
		if _playback.is_stream_playing(id):
			_playback.stop_stream(id)
	_active.clear()


func get_length() -> float:
	return audio_stream.get_length() if audio_stream != null else 2.0


func _prune() -> void :
	if _playback == null:
		_active.clear()
		return

	var alive: Array[int] = []
	for id in _active:
		if _playback.is_stream_playing(id):
			alive.append(id)
	_active = alive
