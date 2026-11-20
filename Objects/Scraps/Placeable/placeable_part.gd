class_name PlaceablePart
extends Node3D

@export var part_type: StringName
@export var display_name: String
@export var fixes_phone := false


func get_friendly_name() -> String :
	return display_name if not display_name.is_empty() else String(name)
