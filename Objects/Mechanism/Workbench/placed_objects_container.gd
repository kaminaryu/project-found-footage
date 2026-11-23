extends Node3D

const PLACED_ROTATION_META := &"placed_rotation"

@export var separation := 0.25
@export var left_anchor := -2.0
@export var row_depth := 0.0
@export var table_surface_z := 0.0


func _ready() -> void :
	for child in get_children() :
		if (child is Node3D) :
			_remember_rotation(child as Node3D)

	layout_children()


func _remember_rotation(obj: Node3D) -> void :
	if (not obj.has_meta(PLACED_ROTATION_META)) :
		obj.set_meta(PLACED_ROTATION_META, obj.quaternion)


func store_rotation_from_world(obj: Node3D) -> void :
	var container_rotation := global_basis.orthonormalized()
	var world_rotation := obj.global_basis.orthonormalized()
	var local_rotation := container_rotation.inverse() * world_rotation

	obj.set_meta(PLACED_ROTATION_META, local_rotation.get_rotation_quaternion())


func layout_children() -> void :
	if not is_inside_tree():
		return
	var cursor := left_anchor

	for child in get_children() :
		if (not child is Node3D) :
			continue

		var obj := child as Node3D
		_remember_rotation(obj)

		var placed_rotation: Quaternion = obj.get_meta(PLACED_ROTATION_META, Quaternion.IDENTITY)
		obj.quaternion = placed_rotation

		# Axis-Aligned Bounding Box
		var aabb := get_aabb_in_container_space(obj)

		if (aabb.size == Vector3.ZERO) :
			continue

		var left_offset := aabb.position.x - obj.position.x
		var bottom_offset := aabb.position.z - obj.position.z
		var center_offset := (aabb.position.y + aabb.size.y * 0.5) - obj.position.y

		obj.position = Vector3(
			cursor - left_offset,
			row_depth - center_offset,
			table_surface_z - bottom_offset
		)


		cursor += aabb.size.x + separation


func get_aabb_in_container_space(node: Node3D) -> AABB :
	var result := AABB()
	var found := false
	var to_local := global_transform.affine_inverse()

	var meshes: Array[MeshInstance3D] = []

	if (node is MeshInstance3D) :
		meshes.append(node as MeshInstance3D)

	for mesh in node.find_children("*", "MeshInstance3D", true, false) :
		meshes.append(mesh as MeshInstance3D)

	for mesh in meshes :
		var box: AABB = (to_local * mesh.global_transform) * mesh.get_aabb()

		if (not found) :
			result = box
			found = true
		else :
			result = result.merge(box)

	return result



func _on_children_changed(node: Node) -> void :
	if (node is Node3D) :
		call_deferred("layout_children")
