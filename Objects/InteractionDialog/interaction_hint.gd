extends Label3D


func _ready() -> void :
	top_level = true
	scale = Vector3.ONE
	hide()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()

	if (cam == null) :
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var offset_pos := Vector2(100, -50)

	global_position = cam.project_position(mouse_pos + offset_pos, 2)
