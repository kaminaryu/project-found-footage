extends Area3D

@export var highlight_material := preload("res://Assets/Shaders/interactable_highlight.tres")


var meshes: Array[MeshInstance3D] = []

func _ready() -> void :
	# Collect all meshes and put in local array
	var parent_mesh := get_parent() as MeshInstance3D
	meshes.append(parent_mesh)

	for child in parent_mesh.find_children("*", "MeshInstance3D"):
		meshes.append(child as MeshInstance3D)


# this setting highlight around the object
func set_highlight(on:bool) -> void:
	for mesh in meshes:
		mesh.material_overlay = highlight_material if on else null

# This will open window when the player interact on em
func interact(player: Node) -> void:
	var obj := get_parent()

	if (obj.has_method("run")) :
		obj.run()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	pass # Replace with function body.
