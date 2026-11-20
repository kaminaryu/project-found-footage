extends Node3D

const RAY_LENGTH := 1000.0

@export var rotation_sensitivity := 0.01
@export var selected_object_container: Node3D
@export var placed_objects_container: Node3D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var selected_obj = get_selected_object()

		if (selected_obj == null) :
			return

		selected_obj.rotate_object_local(Vector3.UP, event.relative.x * rotation_sensitivity)


func _unhandled_input(event: InputEvent) -> void :
	if (not (event is InputEventMouseButton)) :
		return

	var mouse_event := event as InputEventMouseButton

	if (not mouse_event.is_action_pressed("take_item")) :
		return

	if (selected_object_container.get_child_count() > 0) :
		return

	var obj := get_placed_object_under_mouse(mouse_event.position)

	if (obj == null) :
		return

	select_placed_object(obj)


func get_placed_object_under_mouse(mouse_pos: Vector2) -> Node3D :
	var cam := get_viewport().get_camera_3d()

	if (cam == null) :
		return null

	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if (hit.is_empty()) :
		return null

	var node := hit.collider as Node

	if (node == null or node.is_in_group("hover_detectors")) :
		return null

	while (node != null) :
		if (node.get_parent() == placed_objects_container) :
			return node as Node3D

		node = node.get_parent()

	return null


func select_placed_object(obj: Node3D) -> void :
	if (selected_object_container.get_child_count() > 0) :
		return

	obj.add_to_group("selected_item")
	obj.reparent(selected_object_container, false)
	obj.position = Vector3.ZERO
	obj.rotation = Vector3.ZERO


func get_selected_object() -> Node3D :
	if (selected_object_container.get_child_count() == 0) :
		return null

	var selected_obj = selected_object_container.get_child(0)
	return selected_obj


func _on_put_down_button_pressed() -> void:
	var selected_obj = get_selected_object()

	if (selected_obj == null) :
		return

	selected_obj.reparent(placed_objects_container, false)
	selected_obj.remove_from_group("selected_item")
