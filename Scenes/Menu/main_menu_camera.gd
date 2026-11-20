extends Camera3D

@export var pan_speed: float = 0.5
@export var pan_angle_deg: float = 6.0  # Degrees left/right
@export var tilt_angle_deg: float = 2.5 # Degrees up/down

var _time: float = 0.0
var _base_rot: Vector3

func _ready() -> void:
	_base_rot = rotation

func _process(delta: float) -> void:
	_time += delta * pan_speed
	
	rotation.y = _base_rot.y + deg_to_rad(sin(_time) * pan_angle_deg)
	rotation.x = _base_rot.x + deg_to_rad(cos(_time * 0.8) * tilt_angle_deg)
