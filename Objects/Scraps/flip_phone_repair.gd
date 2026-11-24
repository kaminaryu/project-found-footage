extends Node3D

@onready var battery_slot: PartSlot = $FlipPhoneTop/BatterySlot
@onready var cover_slot: PartSlot = $FlipPhoneTop/CoverSlot


func _ready() -> void :
	battery_slot.part_attached.connect(_on_part_attached)
	cover_slot.part_attached.connect(_on_part_attached)
	if(GameMaster.is_flag_raised(&"fixed_phone")):
		queue_free() 


func _on_part_attached(_part: Node3D) -> void :
	_check_fixed()


func _check_fixed() -> void :
	var battery := battery_slot.find_attached_part()
	var cover := cover_slot.find_attached_part()

	if (battery == null or cover == null) :
		return

	if (battery is PlaceablePart and (battery as PlaceablePart).fixes_phone) :
		GameMaster.show_hint("Flip Phone fixed. Press %s to use it." % KeybindSettings.get_action_key_label(&"use_phone"))
		GameMaster.raise_flag(&"fixed_phone")
		queue_free() #this will leave the workbench when player takes it
