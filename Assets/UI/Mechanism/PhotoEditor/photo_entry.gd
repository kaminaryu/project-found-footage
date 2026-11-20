class_name PhotoEntry #Global name that can put anywhere
extends Resource

@export var image: Texture2D
@export_multiline var caption: String = "" #allows text under photo example "September 11,2001 - LOL"

#strong the filter
var exposure: float = 0.0
var contrast: float = 1.0
var noise: float = 0.0
var filter: int = 0


func is_edited() -> bool:
	return exposure != 0.0 or contrast != 1.0 or noise != 0.0 or filter != 0


func reset() -> void:
	exposure = 0.0
	contrast = 1.0
	noise = 0.0
	filter = 0
