class_name PartSlot
extends Node3D

signal part_attached(part: Node3D)

@export var accepted_type: StringName

var attached_part: Node3D
var attached_transform := Transform3D.IDENTITY


func _ready() -> void :
	attached_part = find_attached_part()

	if (attached_part != null) :
		attached_transform = attached_part.transform

	InventoryManager.removing_item.connect(_try_attach)
	child_entered_tree.connect(_on_child_entered)
	child_exiting_tree.connect(_on_child_exiting)


func find_attached_part() -> Node3D :
	for child in get_children() :
		if (child is Node3D and get_part_type(child as Node3D) == accepted_type) :
			return child

	return null


func _try_attach(mesh: Node3D) -> void :
	if (not is_owner_selected()) :
		return

	if (not can_accept(mesh)) :
		return


	mesh.remove_from_group("inventory_items")
	mesh.reparent(self, false)
	mesh.transform = attached_transform

	part_attached.emit(mesh)


func is_owner_selected() -> bool :
	var node := get_parent()

	while (node != null) :
		if (node.is_in_group("selected_item")) :
			return true

		node = node.get_parent()

	return false


func can_accept(mesh: Node3D) -> bool :
	if (accepted_type == &"") :
		return false

	if (attached_part != null and is_instance_valid(attached_part) and attached_part.get_parent() == self) :
		return false

	return get_part_type(mesh) == accepted_type


func get_part_type(mesh: Node3D) -> StringName :
	if (mesh is PlaceablePart) :
		return (mesh as PlaceablePart).part_type

	return StringName(mesh.get_meta("part_type", &""))


func _on_child_entered(node: Node) -> void :
	if (node is Node3D and get_part_type(node as Node3D) == accepted_type) :
		attached_part = node


func _on_child_exiting(node: Node) -> void :
	if (node == attached_part) :
		attached_part = null
