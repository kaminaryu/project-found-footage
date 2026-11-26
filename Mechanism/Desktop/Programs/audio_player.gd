class_name AudioPlayer
extends GameWindow

@export_group("Audio")
@export var stream: AudioStream
@export_range(-80.0, 24.0, 0.1) var volume_db := 0.0

@onready var _audio: AudioStreamPlayer = %Audio
@onready var _track_label: Label = %TrackLabel
@onready var _progress: ProgressBar = %Progress
@onready var _time_label: Label = %TimeLabel
@onready var _play_pause: Button = %PlayPause

const NO_TRACK_LABEL := "NO TRACK SELECTED"


func _window_ready() -> void:
	_audio.finished.connect(_on_audio_finished)
	_play_pause.pressed.connect(_toggle_playback)

	if stream != null:
		_apply_stream(stream, "")

	_refresh_ui()


func play_stream(new_stream: AudioStream, display_name: String = "") -> void:
	_audio.stop()
	_apply_stream(new_stream, display_name)
	_refresh_ui()

	if new_stream != null:
		_audio.play()
		_refresh_ui()


func _apply_stream(new_stream: AudioStream, display_name: String) -> void:
	stream = new_stream
	_audio.stream = new_stream
	_audio.volume_db = volume_db
	_audio.stream_paused = false

	var track_title = display_name if not display_name.is_empty() else _get_stream_name(new_stream)
	_track_label.text = track_title if not track_title.is_empty() else NO_TRACK_LABEL

	_progress.value = 0.0
	_progress.max_value = maxf(_stream_length(new_stream), 0.001)
	_update_time(0.0)


func _toggle_playback() -> void:
	if _audio.stream == null:
		return

	if _audio.stream_paused:
		_audio.stream_paused = false
	elif _audio.playing:
		_audio.stream_paused = true
	else:
		_audio.play()

	_refresh_ui()



func _window_process(_delta: float) -> void:
	if _audio.stream == null:
		return

	_progress.max_value = maxf(_stream_length(_audio.stream), 0.001)

	if _audio.playing and not _audio.stream_paused:
		var position := _audio.get_playback_position()
		_progress.value = position
		_update_time(position)


func _on_audio_finished() -> void:
	_progress.value = 0.0
	_update_time(0.0)
	_refresh_ui()


func _refresh_ui() -> void:
	var has_stream := _audio.stream != null
	_play_pause.disabled = not has_stream
	_play_pause.text = "PAUSE" if has_stream and _audio.playing and not _audio.stream_paused else "PLAY"


func _update_time(position: float) -> void:
	_time_label.text = "%s / %s" % [
		_format_time(position),
		_format_time(_stream_length(_audio.stream))
	]


func _stream_length(audio_stream: AudioStream) -> float:
	return audio_stream.get_length() if audio_stream != null else 0.0


func _get_stream_name(audio_stream: AudioStream) -> String:
	if audio_stream == null:
		return ""

	return audio_stream.resource_path.get_file()


func _format_time(seconds: float) -> String:
	var total := maxi(0, roundi(seconds))
	return "%d:%02d" % [floori(total / 60.0), total % 60]
