extends MeshInstance3D

@export var highlight_material: Material

func _physics_process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var mouse_pos := get_viewport().get_mouse_position()

	# Ray start: the point on the camera that the mouse pixel maps to
	var from := cam.project_ray_origin(mouse_pos)
	# Ray end: 1000 units forward along the direction through that pixel
	var to := from + cam.project_ray_normal(mouse_pos) * 1000.0

	# Describe the ray segment for the physics engine
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Cast the ray. Returns the CLOSEST hit as a dictionary, or {} if nothing was hit.
	# Because only the closest hit is returned, anything in front blocks your object.
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var hovered: bool = not hit.is_empty() and hit.collider == get_child(0)

	material_overlay = highlight_material if hovered else null
