extends StaticBody3D

@export var highlight_material: Material
@export var hover_label: Label3D


func _ready() -> void :
	add_to_group("hover_detectors")

	if (hover_label != null) :
		var object := get_parent() as Node3D

		if (object is PlaceablePart) :
			hover_label.text = "Press [%s]\nto remove %s" % [KeybindSettings.get_action_key_label(&"take_item"), (object as PlaceablePart).get_friendly_name()]


func _physics_process(_delta: float) -> void:
	var object := get_parent() as Node3D

	if (not can_interact(object)) :
		set_hover_state(object, false)
		return


	var cam := get_viewport().get_camera_3d()
	var mouse_pos := get_viewport().get_mouse_position()

	var query := get_raycast_query(cam, mouse_pos)
	var hit   := get_world_3d().direct_space_state.intersect_ray(query) # shoot the raycast

	var hovered: bool = ( ( not hit.is_empty() ) and ( hit.collider == self ) )
	set_hover_state(object, hovered)

	if (Input.is_action_just_pressed("take_item") and hovered) :
		item_selected()


func can_interact(object: Node3D) -> bool :
	if (object in get_tree().get_nodes_in_group("inventory_items")) :
		return false

	if (is_attached_to_slot() and not is_owner_selected()) :
		return false

	return true


func is_attached_to_slot() -> bool :
	var node := get_parent()

	while (node != null) :
		if (node is PartSlot) :
			return true

		node = node.get_parent()

	return false


func is_owner_selected() -> bool :
	var node := get_parent()

	while (node != null) :
		if (node.is_in_group("selected_item")) :
			return true

		node = node.get_parent()

	return false


func get_raycast_query(cam: Camera3D, mouse_pos: Vector2) -> PhysicsRayQueryParameters3D :
	const RAY_LENGTH = 1000.0
	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * RAY_LENGTH

	# create raycast object
	return PhysicsRayQueryParameters3D.create(from, to)


func set_hover_state(object: Node3D, state: bool) -> void :
	var meshes: Array[Node] = []

	if (object is MeshInstance3D) :
		meshes.append(object)

	meshes.append_array(object.find_children("*", "MeshInstance3D", true, false))

	for mesh in meshes :
		(mesh as MeshInstance3D).material_overlay = highlight_material if state else null

	hover_label.visible = state


func item_selected() -> void :
	var obj := get_parent() as Node3D

	if (not can_interact(obj)) :
		return

	InventoryManager.add_item(obj)
