extends Area3D

@export var highlight_material: Material
@export var phone_window_scene: PackedScene

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
	var window := phone_window_scene.instantiate() as Window
	window.close_requested.connect(_on_phone_closed.bind(window, player)) #it will bind the player and the window
	get_tree().root.add_child(window)
	player.freeze(true) #freeze the player

#this makes it that when the window close only that the player able to move
func _on_phone_closed(window: Window, player: Node) -> void:
	window.hide()
	window.queue_free()
	player.freeze(false)
