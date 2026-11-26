extends Area3D

@export var highlight_material: Material


var phone_mesh: Array[MeshInstance3D] = []

func _ready() -> void:
	#Collect the phone and all its part (lid, battery, cover)
	var phone := get_parent() as MeshInstance3D
	phone_mesh.append(phone)
	for child in phone.find_children("*", "MeshInstance3D"):
		phone_mesh.append(child as MeshInstance3D)

#this setting highlight around the phone
func set_highlight(on:bool) -> void:
	for mesh in phone_mesh:
		mesh.material_overlay = highlight_material if on else null

#This will open window when the player interact on em
func interact(player: Node) -> void:
	player.add_item("phone")
	get_parent().queue_free()
