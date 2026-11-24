extends Node3D

@export var player: CharacterBody3D

@onready var carpet_sound: Node = %CarpetWalkSound
@onready var wood_sound: Node   = %WoodWalkSound

const DIST_IN_A_STEP := 50.0

var floor_is_carpet := false
var dist_travelled := 0.0

func _physics_process(delta: float) -> void :
	var is_player_walking := player.velocity != Vector3.ZERO

	dist_travelled += player.velocity.length()

	if (dist_travelled < DIST_IN_A_STEP) :
		return

	dist_travelled = 0

	if (floor_is_carpet) :
		carpet_sound.play()
	else :
		wood_sound.play()



func _on_carpet_area_body_entered(body: Node3D) -> void:
	if (body != player) :
		return
	floor_is_carpet = true
	wood_sound.stop()
	carpet_sound.stop()

func _on_carpet_area_body_exited(body: Node3D) -> void:
	if (body != player) :
		return
	floor_is_carpet = false
	wood_sound.stop()
	carpet_sound.stop()
