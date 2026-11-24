class_name HudItem #One thing that can sit in the bottom-left inventory
extends Resource

@export var display_name: String = ""        #shown in "Press P to place ..."
@export var model: PackedScene                #the 3D model that spins in the slot
@export var model_rotation := Vector3.ZERO    #turn the model (in degrees) so it shows its best side
@export var show_flag: StringName             #the slot appears once this flag is raised
@export var place_flag: StringName            #P at the workbench raises this flag, and the slot disappears (empty = can't be placed)
