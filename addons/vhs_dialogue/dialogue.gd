extends CanvasLayer

signal started(conversation: String)
signal finished(conversation: String)
## A subtitle appeared.
signal line_shown(speaker: String, text: String)
## An "@event name" line was reached. Listen to it to make things happen mid-conversation.
signal event(name: String)

const Reader := preload("res://addons/vhs_dialogue/dialogue_reader.gd")

@export_group("Timing")
## Every subtitle stays up at least this many seconds...
@export var min_time := 1.5
## ...plus this much per letter, so long lines stay up longer.
@export var time_per_letter := 0.055
## Letters typed per second. 0 = the whole line appears at once, like real subtitles.
@export var letters_per_second := 0.0
## Blank moment between two subtitles.
@export var gap := 0.15

@export_group("Text")
## Put "NAME: " in front of lines that have a speaker.
@export var show_speaker_names := true

@export_group("Skipping")
## Input action that jumps to the next subtitle, e.g. "ui_accept". Empty = can't skip.
@export var skip_action := ""

@onready var _subtitle: Label = %Subtitle
@onready var _voice: AudioStreamPlayer = %Voice

var _conversations := {}   # name -> list of steps (see dialogue_reader.gd)
var _played := {}          # name -> true once it has started playing
var _current := ""         # conversation playing now ("" for say())
var _playing := false
var _run := 0              # goes up on every play()/stop(); an older conversation sees it changed and quits
var _skip := false


func _ready() -> void:
	_hide()
	reload()


## Reads all dialogue files again. Handy if you edit them while the game is running.
func reload() -> void:
	_conversations = Reader.read_all()


## Plays a conversation from the dialogue files. Whatever was playing is cut off.
## Use "await Dialogue.play(...)" to wait until it has finished.
func play(conversation: String) -> void:
	if not _conversations.has(conversation):
		push_error("Dialogue: there is no [%s] in the files in %s" % [conversation, Reader.FOLDER])
		return
	await _play_steps(conversation, _conversations[conversation])


## Shows one subtitle straight from code. seconds = -1 works out the time from the length.
func say(text: String, speaker := "", seconds := -1.0) -> void:
	var step := {"type": "line", "speaker": speaker, "text": text, "time": seconds}
	await _play_steps("", [step])


## Hides the subtitle and cuts off the conversation that is playing.
func stop() -> void:
	_run += 1
	_current = ""
	_playing = false
	_skip = false
	_hide()
	_voice.stop()

func _play_voice(path:String) -> void:
	var sound:= load(path) as AudioStream
	if sound == null:
		push_warning("No Voice Dialogue")
		return
	_voice.stream = sound
	_voice.play()
func is_playing() -> bool:
	return _playing


## True once the conversation has been played (or started) this game.
func has_played(conversation: String) -> bool:
	return _played.has(conversation)


func has_conversation(conversation: String) -> bool:
	return _conversations.has(conversation)


## All conversation names, e.g. for checking your story in the debugger.
func get_conversation_names() -> PackedStringArray:
	return PackedStringArray(_conversations.keys())


# ---------------------------------------------------------------- playing

func _play_steps(conversation: String, steps: Array) -> void:
	stop()
	var run := _run
	_current = conversation
	_playing = true
	if conversation != "":
		_played[conversation] = true
	started.emit(conversation)

	for step: Dictionary in steps:
		match step.type:
			"line":
				if not await _show_line(step, run):
					return
			"wait":
				if not await _wait(step.time, run):
					return
			"event":
				event.emit(step.name)
				if run != _run:
					return   # whoever listened to the event started something else
			"voice":
				_play_voice(step.path)
	stop_dialogue(conversation)


func _process(delta: float) -> void :
	if (Input.is_action_pressed("stop_dialogue") and _playing) :
		stop_dialogue(_current)


func stop_dialogue(conversation) -> void :
	stop()
	_current = ""
	_playing = false
	print("stopping dialog", _playing)
	GameMaster.freeze_main_window(false)
	finished.emit(conversation)


## Shows one subtitle, waits, hides it. Returns false if the conversation was cut off.
func _show_line(step: Dictionary, run: int) -> bool:
	var text: String = step.text
	if show_speaker_names and step.speaker != "":
		text = "%s: %s" % [step.speaker, text]
	_subtitle.text = text
	_subtitle.visible = true
	line_shown.emit(step.speaker, step.text)

	if letters_per_second > 0.0:
		var letters := _subtitle.get_total_character_count()
		var typed := 0.0
		_subtitle.visible_characters = 0
		while typed < letters:
			if not await _next_frame(run):
				return false
			if _take_skip():
				break   # first press finishes the typing, the next one skips the line
			typed += letters_per_second * get_process_delta_time()
			_subtitle.visible_characters = int(typed)
		_subtitle.visible_characters = -1

	var time: float = step.time
	if time <= 0.0:
		time = min_time + time_per_letter * String(step.text).length()
	if not await _wait(time, run):
		return false
	_hide()
	return await _wait(gap, run)


## Waits a number of seconds (stops early if skipped). Returns false if the conversation was cut off.
func _wait(seconds: float, run: int) -> bool:
	var left := seconds
	while left > 0.0:
		if not await _next_frame(run):
			return false
		if _take_skip():
			return true
		left -= get_process_delta_time()
	return true


## Waits one frame. While the game is paused, the subtitle stays where it is.
func _next_frame(run: int) -> bool:
	await get_tree().process_frame
	while not can_process() and run == _run:
		await get_tree().process_frame
	return run == _run


func _take_skip() -> bool:
	var pressed := _skip
	_skip = false
	return pressed


func _hide() -> void:
	_subtitle.visible = false
	_subtitle.visible_characters = -1


func _unhandled_input(input: InputEvent) -> void:
	if skip_action == "" or not InputMap.has_action(skip_action):
		return
	if is_playing() and input.is_action_pressed(skip_action):
		_skip = true
		get_viewport().set_input_as_handled()
