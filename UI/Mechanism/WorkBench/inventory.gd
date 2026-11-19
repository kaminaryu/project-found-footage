extends Control

@export var slot_container: VBoxContainer
@export var popup_container: PanelContainer

func _ready() -> void :
	InventoryManager.adding_item.connect(add_item)
	attach_slot_buttons()


func attach_slot_buttons() -> void :
	for slot in slot_container.get_children() :
		slot.get_node("Button").button_up.connect(remove_item.bind(slot))


func remove_item(slot: PanelContainer) -> void :
	var viewport := get_item_viewport(slot)

	# slot have no item
	if viewport.get_child_count() == 1 :
		return 

	for obj in viewport.get_children() :
		if ((obj is Camera3D) or not (obj is Node3D)) :
			continue

		InventoryManager.remove_item(obj as Node3D)



func _process(delta: float) -> void :
	for obj in get_tree().get_nodes_in_group("inventory_items") :
		obj.rotate_y(-2.0 * delta)


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
	# child 0 is the camera, anything beyond it is an item
	return get_item_viewport(slot).get_child_count() > 1


func get_item_viewport(slot: PanelContainer) -> SubViewport :
	return slot.get_node("SubViewportContainer/SubViewport")


func add_obj_to_slot(obj: Node3D, slot: PanelContainer) -> void :
	const PRESERVE_PREVIOUS_GLOBAL_TRANSFORM := false

	obj.add_to_group("inventory_items")
	obj.reparent(get_item_viewport(slot), PRESERVE_PREVIOUS_GLOBAL_TRANSFORM)



func warn_full_inventory() -> void :
	var timer := Timer.new()

	timer.wait_time = 1.5
	timer.autostart = true
	get_tree().root.add_child(timer)
	timer.timeout.connect(hide_popup)

	popup_container.show()


func hide_popup() -> void :
	popup_container.hide()
