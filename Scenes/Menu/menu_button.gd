extends Control


@onready var arrow := $"../Arrow";
@onready var label := $"../Label";
var anim_duration := 0.3;
var byebye_distance := 8.5;
var _tween: Tween;

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass


func _on_mouse_entered() -> void:
	
	arrow.position.x = -byebye_distance;
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	_tween.tween_property(arrow, "modulate:a", 1.0, anim_duration);
	_tween.tween_property(arrow, "position:x", 0.0, anim_duration);
	pass # Replace with function body.


func _on_mouse_exited() -> void:
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	_tween.tween_property(arrow, "modulate:a", 0.0, anim_duration);
	_tween.tween_property(arrow, "position:x", -byebye_distance, anim_duration);
	pass # Replace with function body.
