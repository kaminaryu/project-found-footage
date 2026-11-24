#Things that happens in Main Menu upon launch, including the splash screen

extends Control
var splash_screen_finished := false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.animation_finished.connect(_splash_screen_end);
	DisplaySettings.apply_to_scene(self)


func _splash_screen_end(anim := 'non') -> void:
	splash_screen_finished = true;
	get_tree().change_scene_to_file("res://Scenes/Menu/main_menu.tscn");

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and !splash_screen_finished:
		_splash_screen_end();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
