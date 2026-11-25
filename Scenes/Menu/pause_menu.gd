extends Control

@onready var transitionPlayer := $Transition;
@onready var settings_screen: Control = $SettingsScreen;

var paused := false;
var mouse_before_pause: Input.MouseMode = Input.MOUSE_MODE_CAPTURED #Show the mouse was before paused
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if settings_screen != null and settings_screen.is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit"):
		pause();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func pause() -> void:
	if !paused:
		mouse_before_pause = Input.mouse_mode
		if settings_screen != null:
			settings_screen.hide()
		transitionPlayer.play("open");
		get_tree().paused = true;
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		paused = true;
	else:
		if settings_screen != null:
			settings_screen.hide()
		transitionPlayer.play("close");
		get_tree().paused = false;
		Input.mouse_mode = mouse_before_pause
		paused = false;


func _on_settings_pressed() -> void:
	if settings_screen != null:
		settings_screen.show()


func _on_resume_pressed() -> void:
	pause()


func _on_exit_pressed() -> void:
	Dialogue.stop()
	get_tree().paused = false;
	paused = false;
	get_tree().change_scene_to_file("res://Scenes/Menu/main_menu.tscn");
