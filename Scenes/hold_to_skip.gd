extends CanvasLayer
#If the hold BACKSPACE tu... if the playert lepas,. it will runs back

signal skipped

#how log the key must be held , in second
@export var hold_time := 2.0

@onready var _bar: ProgressBar = $BoxSkip/Bar

var _held := 0.0 #to keep track how long the player has held the button
var _done := false #Initial flag , it will return true once the player held long enough

func _ready () -> void:
	hide() #at first the progress bar will hide

func _process(delta:float) -> void:
	if not visible or _done:
		return #to see if the Hold to skip is not visible or if it's done, it will ignore this
	if Input.is_action_pressed("skip_cutscene"):
		_held+=delta #count how many second the player hold\
	else:
		_held = move_toward(_held, 0.0, delta * 3.0)
	_bar.value = _held / hold_time * 100.00 #some formula of percentage value
	if _held >= hold_time:
		_done = true
		skipped.emit()
		
