@tool
extends DesktopIconBase

@export var audio_name: String = "Audio-XXX.mp3":
	set(name) :
		audio_name = name
		icon_name = audio_name
		_update_audio_name()

@export var audio_file: AudioStream


func _ready() -> void :
	super._ready()
	program_ran.connect(_on_program_ran)


func _update_audio_name() -> void :
	update_visuals()


func _on_program_ran(audio_player: Node) -> void :
	audio_player.play_stream(audio_file, audio_name)
