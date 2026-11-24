extends Node

signal successfully_remove_item

signal adding_item(item: Node3D)
signal removing_item(item: Node3D)

func add_item(obj: Node3D) -> void :
	adding_item.emit(obj)


func remove_item(obj: Node3D) -> void :
	removing_item.emit(obj)

