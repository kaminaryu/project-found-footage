extends Control

@onready var transitionPlayer := $Transition;

var paused := false;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit"):
		pause();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func pause() -> void:
	if !paused:
		transitionPlayer.play("open");
		get_tree().paused = true;
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		paused = true;
	else:
		transitionPlayer.play("close");
		get_tree().paused = false;
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		paused = false;


func _on_resume_pressed() -> void:
	pause()


func _on_exit_pressed() -> void:
	get_tree().paused = false;
	paused = false;
	get_tree().change_scene_to_file("res://Scenes/Menu/main_menu.tscn");
