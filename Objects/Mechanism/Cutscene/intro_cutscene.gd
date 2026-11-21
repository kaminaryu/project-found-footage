extends Node3D
## Chapter One intro. Plays along with the [Intro] conversation in ChapterOne.txt
## (GameMaster.start_game() freezes the player and starts it).
##
## The camera stays at the player's eyes and turns on its own. The @event lines in the
## dialogue file decide what happens and when:
##   @event look_door          turn the camera to the marker LookAt/door (any LookAt child works)
##   @event look_customer      follow the customer's face
##   @event look_box           look at the box of scraps
##   @event Customer_walk_in   bell rings, the main door opens, the customer walks to the counter
##   @event box_on_table       the box of scraps lands on the counter
##   @event cust_angry         the customer points angrily once (cust_argue does the same)
##   @event writing            writing sound
##   @event cust_leave         the customer walks out, then the box goes back on the floor
## When the conversation is over (and the customer is gone) the player can move again,
## looking the same way the camera did.
##
## To change where things happen, move the Marker3D children of this node in main_walk.
## The customer stops where the Customer node stands in the level.

const CONVERSATION := "Intro"

@export var player: Node3D
@export var customer: Node3D
@export var box: Node3D
## The two panels of the shop's main door (inside the scaryroom model).
@export var door_left: Node3D
@export var door_right: Node3D
## Things to hide while the intro plays (like the objectives list), shown again afterwards.
@export var hide_while_playing: Array[CanvasItem] = []

@export_group("Feel")
## How fast the customer walks, in metres per second.
@export var walk_speed := 1.3
## How quickly the camera turns towards what it looks at (higher = snappier).
@export var turn_speed := 2.2
## How far the main door swings open, in degrees.
@export var door_angle := 75.0

@onready var _camera: Camera3D = $Camera
@onready var _look_markers: Node3D = $LookAt
@onready var _outside: Marker3D = $CustomerPath/Outside
@onready var _inside: Marker3D = $CustomerPath/Inside
@onready var _box_spot: Marker3D = $BoxOnCounter
@onready var _bell: AudioStreamPlayer = $BellSound
@onready var _writing: AudioStreamPlayer = $WritingSound

var _running := false
var _look_target: Node3D               # what the camera turns towards (null = keep still)
var _look_basis := Basis()             # where the camera points, before the handheld sway
var _time := 0.0
var _shake := 0.0
var _customer_busy := false            # walking in or out
var _angry_run := 0

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _head := -1
var _player_camera: Camera3D
var _customer_spot: Transform3D        # where he stands at the counter = his place in the level
var _box_home: Transform3D             # the box's place on the floor
var _box_layer := 1
var _doors: Array[Node3D] = []
var _door_home: Array[Transform3D] = []
var _door_hinge: Array[Vector3] = []
var _door_sign: Array[float] = []
var _door_open := 0.0                  # 0 = closed, 1 = open
var _door_tween: Tween
var _hidden: Array[CanvasItem] = []    # what we hid, to show again at the end


func _ready() -> void:
	_anim = customer.get_node("AnimationPlayer")
	_skeleton = customer.find_children("*", "Skeleton3D", true, false)[0]
	_head = _skeleton.find_bone("mixamorig_Head")
	_player_camera = player.find_children("*", "Camera3D", true, false)[0]
	_customer_spot = customer.global_transform
	_box_home = box.global_transform
	_find_door_hinges()

	Dialogue.started.connect(_on_started)
	Dialogue.event.connect(_on_event)
	Dialogue.finished.connect(_on_finished)
	_check_intro_exists.call_deferred()


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	var target: Variant = _look_point()
	if target != null:
		var from := _camera.global_position
		var to: Vector3 = target
		if from.distance_to(to) > 0.05:
			var want := Basis.looking_at(to - from)
			_look_basis = _look_basis.slerp(want, 1.0 - exp(-turn_speed * delta)).orthonormalized()
	# A little handheld sway, like someone breathing, plus a shake when the customer gets angry.
	_shake = maxf(_shake - delta * 1.5, 0.0)
	var sway := Vector3(sin(_time * 0.9) * 0.006, sin(_time * 0.6) * 0.008, sin(_time * 0.7) * 0.004)
	sway += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.015
	_camera.global_basis = _look_basis * Basis.from_euler(sway)


# ---------------------------------------------------------------- start and end

## Without the [Intro] text the player would stay frozen forever, so let them move.
func _check_intro_exists() -> void:
	if not Dialogue.has_conversation(CONVERSATION):
		push_warning("IntroCutscene: there is no [%s] in the dialogue files, so the intro is skipped." % CONVERSATION)
		GameMaster.freeze_player(false)


func _on_started(conversation: String) -> void:
	if conversation != CONVERSATION:
		if _running:
			_end()   # something else cut the intro off: don't leave the player stuck
		return
	_running = true
	customer.hide()
	box.hide()
	_set_box_interactable(false)
	_camera.global_transform = _player_camera.global_transform
	_camera.fov = _player_camera.fov
	_look_basis = _camera.global_basis
	_look_target = null
	_camera.make_current()
	for item in hide_while_playing:
		if item and item.visible:
			item.hide()
			_hidden.append(item)


func _on_finished(conversation: String) -> void:
	if conversation != CONVERSATION or not _running:
		return
	# dialogue.gd lets the player move whenever any conversation ends, but the customer
	# may still be walking out: keep the player still until the cutscene is really over.
	GameMaster.freeze_player(true)
	while _customer_busy:   # let him finish walking out first
		await get_tree().process_frame
	_end()


func _end() -> void:
	_running = false
	# Give the view back to the player, facing where the camera ended up.
	var forward := -_look_basis.z
	player.rotation.y = atan2(-forward.x, -forward.z)
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot:
		pivot.rotation.x = clampf(asin(clampf(forward.y, -1.0, 1.0)), deg_to_rad(-80.0), deg_to_rad(80.0))
	_player_camera.make_current()
	customer.hide()
	if _door_tween:
		_door_tween.kill()
	_set_door(0.0)
	box.global_transform = _box_home
	box.show()
	_set_box_interactable(true)
	for item in _hidden:
		if is_instance_valid(item):
			item.show()
	_hidden.clear()
	GameMaster.freeze_player(false)


# ---------------------------------------------------------------- events from the dialogue

func _on_event(event_name: String) -> void:
	if not _running:
		return
	if event_name.begins_with("look_"):
		_look(event_name.trim_prefix("look_"))
		return
	match event_name:
		"Customer_walk_in":
			_walk_in()
		"box_on_table":
			_put_box_on_counter()
		"cust_angry", "cust_argue":
			_angry()
		"writing":
			_writing.play()
		"cust_leave":
			_walk_out()


func _look(what: String) -> void:
	match what:
		"customer":
			_look_target = customer
		"box":
			_look_target = box
		_:
			var marker := _look_markers.get_node_or_null(what) as Node3D
			if marker == null:
				push_warning("IntroCutscene: there is no marker LookAt/%s to look at." % what)
				return
			_look_target = marker


## The point the camera turns towards: a marker, the box, or the customer's face.
func _look_point() -> Variant:
	if _look_target == null:
		return null
	if _look_target == customer:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_head).origin
	return _look_target.global_position


func _walk_in() -> void:
	_customer_busy = true
	_bell.play()
	_swing_door(true)
	customer.global_transform = Transform3D(_facing(_inside.global_position - _outside.global_position), _outside.global_position)
	customer.global_position.y = _customer_spot.origin.y
	customer.show()
	_anim.play("walk")
	_look_target = customer
	await _sleep(0.4)   # the door is half open before he steps in
	await _walk_to(_inside.global_position)
	_swing_door(false)
	await _walk_to(_customer_spot.origin)
	_anim.play("idle", 0.4)
	await _turn_to(_customer_spot.basis, 0.4)
	_customer_busy = false


func _walk_out() -> void:
	_customer_busy = true
	_angry_run += 1   # stop a pending "back to idle"
	_anim.play("walk", 0.3)
	_open_door_later(0.7)
	await _walk_to(_inside.global_position)
	await _walk_to(_outside.global_position)
	customer.hide()
	_anim.play("idle")
	box.global_transform = _box_home   # the box goes back on the floor
	await _swing_door(false)           # the cutscene ends once the door has shut
	_customer_busy = false


func _put_box_on_counter() -> void:
	var spot := _box_spot.global_transform
	box.global_transform = spot.translated(Vector3(0.0, 0.25, 0.0))
	box.show()
	var drop := create_tween()
	drop.tween_property(box, "global_position", spot.origin, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Glance at it, then back at him.
	_look_target = box
	await _sleep(2.0)
	if _look_target == box:
		_look_target = customer


func _angry() -> void:
	_angry_run += 1
	var run := _angry_run
	if _anim.current_animation == "angry_point":
		_anim.seek(0.0, true)
	else:
		_anim.play("angry_point", 0.2)
	_shake = 0.6
	var fov := create_tween()
	fov.tween_property(_camera, "fov", _player_camera.fov - 7.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fov.tween_property(_camera, "fov", _player_camera.fov, 1.4).set_trans(Tween.TRANS_SINE)
	await _sleep(_anim.get_animation("angry_point").length - 0.3)
	if run == _angry_run and _running and not _customer_busy:
		_anim.play("idle", 0.4)


# ---------------------------------------------------------------- customer movement

## Walks the customer in a straight line to `spot`, facing the way he goes.
func _walk_to(spot: Vector3) -> void:
	var start := customer.global_position
	spot.y = start.y
	var distance := start.distance_to(spot)
	if distance < 0.01:
		return
	_turn_to(_facing(spot - start), 0.25)   # turns while he starts walking
	var step := create_tween()
	step.tween_property(customer, "global_position", spot, distance / walk_speed)
	await step.finished


## A rotation that makes the customer face `direction` (his model looks along +Z).
func _facing(direction: Vector3) -> Basis:
	direction.y = 0.0
	return Basis.looking_at(direction.normalized(), Vector3.UP, true)


func _turn_to(goal_basis: Basis, time: float) -> void:
	var from := customer.global_basis.get_rotation_quaternion()
	var goal := goal_basis.get_rotation_quaternion()
	var turn := create_tween()
	turn.tween_method(func(t: float) -> void: customer.global_basis = Basis(from.slerp(goal, t)), 0.0, 1.0, time)
	await turn.finished


# ---------------------------------------------------------------- the main door

## The door panels are modelled in place, so they swing around their outer edges (the hinges).
func _find_door_hinges() -> void:
	_doors.append(door_left)
	_doors.append(door_right)
	var boxes: Array[AABB] = []
	for door in _doors:
		_door_home.append(door.global_transform)
		boxes.append(_global_box(door))
	var inward := _customer_spot.origin - (boxes[0].get_center() + boxes[1].get_center()) * 0.5
	inward.y = 0.0
	for i in 2:
		var mine := boxes[i]
		var other := boxes[1 - i].get_center()
		# The hinge is the edge furthest from the other panel.
		var hinge := mine.get_center()
		if mine.size.z >= mine.size.x:
			hinge.z = mine.position.z if absf(mine.position.z - other.z) > absf(mine.end.z - other.z) else mine.end.z
		else:
			hinge.x = mine.position.x if absf(mine.position.x - other.x) > absf(mine.end.x - other.x) else mine.end.x
		hinge.y = 0.0
		_door_hinge.append(hinge)
		# Swing into the shop, not out into the street.
		var centre := mine.get_center()
		var test := Basis(Vector3.UP, deg_to_rad(30.0)) * (centre - hinge) + hinge
		_door_sign.append(1.0 if (test - centre).dot(inward) > 0.0 else -1.0)


func _global_box(node: Node3D) -> AABB:
	var mesh := node as MeshInstance3D
	return mesh.global_transform * mesh.get_aabb() if mesh else AABB(node.global_position, Vector3.ZERO)


func _swing_door(open: bool) -> void:
	if _door_tween:
		_door_tween.kill()   # a new swing takes over from the one still moving
	_door_tween = create_tween()
	_door_tween.tween_method(_set_door, _door_open, 1.0 if open else 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _door_tween.finished


func _open_door_later(seconds: float) -> void:
	await _sleep(seconds)
	if _running:
		_swing_door(true)


func _set_door(amount: float) -> void:
	_door_open = amount
	for i in _doors.size():
		var turn := Basis(Vector3.UP, deg_to_rad(door_angle) * amount * _door_sign[i])
		var hinge := _door_hinge[i]
		_doors[i].global_transform = Transform3D(turn, hinge - turn * hinge) * _door_home[i]


# ---------------------------------------------------------------- helpers

func _set_box_interactable(on: bool) -> void:
	var cube := box.get_node_or_null("InteractionCube") as CollisionObject3D
	if cube == null:
		return
	if on:
		cube.collision_layer = _box_layer
	elif cube.collision_layer != 0:
		_box_layer = cube.collision_layer
		cube.collision_layer = 0


## Waits, but pauses along with the game (unlike a plain timer).
func _sleep(seconds: float) -> void:
	await create_tween().tween_interval(seconds).finished
