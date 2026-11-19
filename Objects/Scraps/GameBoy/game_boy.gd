extends Node3D

# @export var sensitivity := 0.01
# @export var battery_slot: Node3D
#
#
# func _ready() -> void :
# 	InventoryManager.removing_item.connect(attach_battery)
#
#
# func attach_battery(obj: MeshInstance3D) -> void :
# 	const PRESERVE_PREVIOUS_GLOBAL_TRANSFORM := false
#
# 	obj.remove_from_group("inventory_items")
# 	obj.reparent(battery_slot, PRESERVE_PREVIOUS_GLOBAL_TRANSFORM)
# 	obj.global_rotation = battery_slot.global_rotation
