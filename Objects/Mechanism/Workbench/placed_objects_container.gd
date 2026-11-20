extends Node3D

@export var separation := 0.25
@export var left_anchor := -2.0
@export var row_depth := 0.0
@export var table_surface_z := 0.0


func _ready() -> void :
	layout_children()


func layout_children() -> void :
	var cursor := left_anchor

	for child in get_children() :
		if (not child is Node3D) :
			continue

		var obj := child as Node3D
		obj.rotation = Vector3.ZERO

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
