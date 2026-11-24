#Things that happens in Main Menu upon launch, including the splash screen

extends Node3D

@onready var opening := $UI/Opening;
@onready var splash_screen := $UI/SplashScreen
var splash_screen_finished := false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	splash_screen.get_node("AnimationPlayer").animation_finished.connect(_splash_screen_end);
	DisplaySettings.apply_to_scene(self)


func _splash_screen_end(anim := 'non') -> void:
	splash_screen_finished = true;
	splash_screen.visible = false;
	opening.play("opening");

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and !splash_screen_finished:
		splash_screen.get_node("AnimationPlayer").stop();
		_splash_screen_end();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
