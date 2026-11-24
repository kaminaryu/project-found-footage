extends MeshInstance3D

@export var duration: float = 1.0

var _tween: Tween

func run(player: Node) -> void :
	if (player == null) :
		return

	$SfxPlayer.play()
	sit_its_ass_down(player)


@export var rotation_offset: int = -90
@export var rotate_time: float = 0.4
@export var move_time: float = 0.8
@export var drop_time: float = 0.3

func sit_its_ass_down(target: Node3D) -> void:
	if _tween:
		_tween.kill()


	var start_pos := target.global_position
	var start_quat := target.global_basis.get_rotation_quaternion()
	var start_scale := target.global_basis.get_scale()
	var end_pos := global_position
	var end_quat := global_basis.get_rotation_quaternion() * Quaternion(Vector3.UP, deg_to_rad(rotation_offset))
	var end_flat_pos := Vector3(end_pos.x, start_pos.y, end_pos.z)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 1. rotate to the object rotation plus adjustable 90 degree steps
	_tween.tween_method(func(t: float) -> void:
		target.global_basis = Basis(start_quat.slerp(end_quat, t)) * Basis.from_scale(start_scale)
	, 0.0, 1.0, rotate_time)

	# 2. move to the object position on XZ, ignoring Y
	_tween.tween_method(func(t: float) -> void:
		target.global_position = start_pos.lerp(end_flat_pos, t)
	, 0.0, 1.0, move_time)
	_tween.tween_callback(target.sit_down)
	# 3. drop to the exact Y position
	_tween.tween_method(func(t: float) -> void:
		target.global_position.y = lerpf(start_pos.y, end_pos.y, t)
	, 0.0, 1.0, drop_time)


func _on_bean_bag_area_body_exited(body: Node3D) -> void:
	if (body.has_method("stand_up")) :
		body.stand_up()
