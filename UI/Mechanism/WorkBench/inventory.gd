extends Control

@export var slot_container: VBoxContainer
@export var popup_container: PanelContainer
@export var hover_hint: Label
@export var preview_max_extent := 2.0
@export var new_battery: MeshInstance3D
@export var old_battery: MeshInstance3D

var hovered_slot: PanelContainer = null



func _ready() -> void :
	InventoryManager.adding_item.connect(add_item)
	attach_slot_buttons()
	visibility_changed.connect(_on_visibility_changed)
	hover_hint.hide()

	for slot in slot_container.get_children() :
		get_item_pivot(slot)

	if (GameMaster.is_flag_raised(&"fixed_phone")) :
		InventoryManager.add_item(old_battery)
	else :
		InventoryManager.add_item(new_battery)


func attach_slot_buttons() -> void :
	for slot in slot_container.get_children() :
		var button := slot.get_node("Button") as Button

		button.button_up.connect(remove_item.bind(slot))
		button.mouse_entered.connect(show_insert_hint.bind(slot))
		button.mouse_exited.connect(hide_insert_hint)


func remove_item(slot: PanelContainer) -> void :
	var pivot := get_item_pivot(slot)

	# slot have no item
	if pivot.get_child_count() == 0 :
		return

	for obj in pivot.get_children() :
		if (not (obj is Node3D)) :
			continue

		InventoryManager.remove_item(obj as Node3D)

	if (hovered_slot == slot) :
		if (pivot.get_child_count() == 0) :
			hide_insert_hint()
		else :
			show_insert_hint(slot)



func _process(delta: float) -> void :
	for slot in slot_container.get_children() :
		var pivot := get_item_pivot(slot)

		if (pivot.get_child_count() > 0) :
			pivot.rotate_y(-2.0 * delta)

	if (hover_hint.visible) :
		update_hover_hint_position()


func add_item(obj: Node3D) -> void :
	var slot := find_free_slot()

	if slot == null:
		warn_full_inventory()
		return

	add_obj_to_slot(obj, slot)


func find_free_slot() -> PanelContainer :
	for slot in slot_container.get_children() :
		if not is_slot_taken(slot):
			return slot
	return null


func is_slot_taken(slot: PanelContainer) -> bool :
	return get_item_pivot(slot).get_child_count() > 0


func get_item_viewport(slot: PanelContainer) -> SubViewport :
	return slot.get_node("SubViewportContainer/SubViewport")


func get_item_pivot(slot: PanelContainer) -> Node3D :
	var viewport := get_item_viewport(slot)
	var pivot := viewport.get_node_or_null("ItemPivot") as Node3D

	if (pivot == null) :
		pivot = Node3D.new()
		pivot.name = "ItemPivot"
		viewport.add_child(pivot)

	return pivot


func get_slot_item(slot: PanelContainer) -> Node3D :
	for child in get_item_pivot(slot).get_children() :
		if (child is Node3D) :
			return child as Node3D

	return null


func get_item_display_name(obj: Node3D) -> String :
	if (obj is PlaceablePart) :
		return (obj as PlaceablePart).get_friendly_name()

	return obj.name


func get_item_part_type(obj: Node3D) -> StringName :
	if (obj is PlaceablePart) :
		return (obj as PlaceablePart).part_type

	return StringName(obj.get_meta("part_type", &""))


func can_insert_item(item: Node3D) -> bool :
	var part_type := get_item_part_type(item)

	if (part_type == &"") :
		return false

	for selected in get_tree().get_nodes_in_group("selected_item") :
		for node in selected.find_children("*", "", true, false) :
			if (not (node is PartSlot)) :
				continue

			var slot := node as PartSlot

			if (slot.accepted_type == part_type and slot.can_accept(item)) :
				return true

	return false


func show_insert_hint(slot: PanelContainer) -> void :
	var item := get_slot_item(slot)

	if (item == null) :
		hide_insert_hint()
		return

	if (not can_insert_item(item)) :
		display_wrong_obj_hint(slot)
		return

	display_proper_hint(slot, item)


func hide_insert_hint() -> void :
	hovered_slot = null
	hover_hint.hide()


func display_wrong_obj_hint(slot: PanelContainer) -> void :
	var item = get_slot_item(slot)
	var item_name = get_item_display_name(item)

	hover_hint.text = "Can't insert %s into this object." % item_name
	hover_hint.reset_size()
	hover_hint.show()

	hovered_slot = slot
	update_hover_hint_position()



func display_proper_hint(slot: PanelContainer, item: Node3D) -> void :
	hovered_slot = slot
	hover_hint.text = "Click to Insert %s" % get_item_display_name(item)
	hover_hint.reset_size()
	hover_hint.show()
	update_hover_hint_position()


func update_hover_hint_position() -> void :
	if (not hover_hint.visible) :
		return

	var mouse_pos := get_global_mouse_position()
	var target := mouse_pos + Vector2(-hover_hint.size.x - 20.0, 12.0)
	var viewport_size := get_viewport_rect().size

	target.x = clampf(target.x, 8.0, viewport_size.x - hover_hint.size.x - 8.0)
	target.y = clampf(target.y, 8.0, viewport_size.y - hover_hint.size.y - 8.0)
	hover_hint.global_position = target


func _on_visibility_changed() -> void :
	if (not visible) :
		hide_insert_hint()


func add_obj_to_slot(obj: Node3D, slot: PanelContainer) -> void :
	var pivot := get_item_pivot(slot)

	obj.add_to_group("inventory_items")
	obj.reparent(pivot, false)
	fit_to_preview(obj, pivot)


func fit_to_preview(obj: Node3D, pivot: Node3D) -> void :
	obj.position = Vector3.ZERO

	var aabb := get_aabb_in_space(obj, pivot)

	if (aabb.size == Vector3.ZERO) :
		return

	var max_extent := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))

	if (max_extent <= 0.0) :
		return

	var fit := preview_max_extent / max_extent

	obj.scale = obj.scale * fit
	obj.position = -(aabb.position + aabb.size * 0.5) * fit


func get_aabb_in_space(node: Node3D, space: Node3D) -> AABB :
	var result := AABB()
	var found := false
	var to_local := space.global_transform.affine_inverse()

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



func warn_full_inventory() -> void :
	var timer := Timer.new()

	timer.wait_time = 1.5
	timer.autostart = true
	get_tree().root.add_child(timer)
	timer.timeout.connect(hide_popup)

	popup_container.show()


func hide_popup() -> void :
	popup_container.hide()
