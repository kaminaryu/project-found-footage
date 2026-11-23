extends Node3D

const RAY_LENGTH := 1000.0
const FADE_DURATION := 0.22

@export var rotation_sensitivity := 0.01
@export var selected_object_container: Node3D
@export var placed_objects_container: Node3D
@export var start_inactive := true

@onready var camera: Camera3D = $Camera3D
@onready var inventory: Control = $Inventory
@onready var ui_layer: CanvasLayer = $CanvasLayer
@onready var put_down_button: Button = $CanvasLayer/PutDownButton/PutDownButton
@onready var fade_rect: ColorRect = $TransitionLayer/Fade

var is_active := false
var is_transitioning := false
var previous_camera: Camera3D = null

var room_blockers: Array[CollisionObject3D] = []
var room_blocker_layers: Array[int] = []


func _ready() -> void :
	ui_layer.visible = false
	inventory.visible = false
	fade_rect.modulate.a = 0.0
	_cache_room_blockers()
	_update_put_down_button()
	_update_scraps()
	GameMaster.flag_raised.connect(_on_flag_raised)
	selected_object_container.child_exiting_tree.connect(_on_selected_object_left)

	if (start_inactive) :
		process_mode = Node.PROCESS_MODE_DISABLED
	else :
		call_deferred("activate")

func _update_scraps() -> void: #This shit will fix when the scraps only appears on the workbench ONLY ONCE they have been collected from the box
	var collected := GameMaster.is_flag_raised(&"scrap_collected")
	placed_objects_container.visible = collected
	placed_objects_container.process_mode = Node.PROCESS_MODE_INHERIT if collected else Node.PROCESS_MODE_DISABLED

func _on_flag_raised(flag:StringName) -> void:
	if(flag == &"scrap_collected") :
		_update_scraps()
func run(_player: Node) -> void :
	activate()


func activate() -> void :
	if (is_active or is_transitioning) :
		return

	is_transitioning = true
	process_mode = Node.PROCESS_MODE_INHERIT
	previous_camera = get_viewport().get_camera_3d()
	_set_room_blockers_enabled(false)

	GameMaster.freeze_main_window(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await _fade_to(1.0)

	camera.make_current()
	ui_layer.visible = true
	inventory.visible = true
	_update_put_down_button()

	is_active = true
	GameMaster.raise_flag(&"workbench_opened")
	await _fade_to(0.0)
	is_transitioning = false


func deactivate() -> void :
	if (not is_active or is_transitioning) :
		return

	is_transitioning = true

	_on_put_down_button_pressed()

	await _fade_to(1.0)

	ui_layer.visible = false
	inventory.visible = false

	if (is_instance_valid(previous_camera)) :
		previous_camera.make_current()

	previous_camera = null
	_set_room_blockers_enabled(true)

	await _fade_to(0.0)

	is_active = false
	GameMaster.freeze_main_window(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	is_transitioning = false


func _cache_room_blockers() -> void :
	var workbench_root := get_parent()

	if (workbench_root == null) :
		return

	for child in workbench_root.get_children() :
		if (child == self) :
			continue

		if (not (child is StaticBody3D) and not (child is Area3D)) :
			continue

		var blocker := child as CollisionObject3D

		if (blocker == null) :
			continue

		room_blockers.append(blocker)
		room_blocker_layers.append(blocker.collision_layer)


func _set_room_blockers_enabled(enabled: bool) -> void :
	for i in room_blockers.size() :
		room_blockers[i].collision_layer = room_blocker_layers[i] if enabled else 0


func _fade_to(alpha: float) -> void :
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", alpha, FADE_DURATION)
	await tween.finished


func _input(event: InputEvent) -> void:
	if (not is_active or is_transitioning) :
		return

	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit")) :
		get_viewport().set_input_as_handled()
		deactivate()
		return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if (get_viewport().gui_get_hovered_control() != null) :
			return

		var selected_obj = get_selected_object()

		if (selected_obj == null) :
			return

		var table_up: Vector3 = placed_objects_container.global_basis.z.normalized()
		selected_obj.global_rotate(table_up, event.relative.x * rotation_sensitivity)


func _unhandled_input(event: InputEvent) -> void :
	if (not is_active or is_transitioning) :
		return

	if (not (event is InputEventMouseButton)) :
		return

	var mouse_event := event as InputEventMouseButton

	if (not mouse_event.is_action_pressed("take_item")) :
		return

	if (selected_object_container.get_child_count() > 0) :
		return

	var obj := get_placed_object_under_mouse(mouse_event.position)

	if (obj == null) :
		return

	select_placed_object(obj)


func get_placed_object_under_mouse(mouse_pos: Vector2) -> Node3D :
	var cam := get_viewport().get_camera_3d()

	if (cam == null) :
		return null

	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if (hit.is_empty()) :
		return null

	var node := hit.collider as Node

	if (node == null or node.is_in_group("hover_detectors")) :
		return null

	while (node != null) :
		if (node.get_parent() == placed_objects_container) :
			return node as Node3D

		node = node.get_parent()

	return null


func select_placed_object(obj: Node3D) -> void :
	if (selected_object_container.get_child_count() > 0) :
		return

	var world_basis := obj.global_basis

	obj.add_to_group("selected_item")
	obj.reparent(selected_object_container, false)
	obj.position = Vector3.ZERO
	obj.global_basis = world_basis
	_update_put_down_button()


func get_selected_object() -> Node3D :
	if (selected_object_container.get_child_count() == 0) :
		return null

	var selected_obj = selected_object_container.get_child(0)
	return selected_obj


func _on_put_down_button_pressed() -> void:
	var selected_obj = get_selected_object()

	if (selected_obj == null) :
		return

	placed_objects_container.store_rotation_from_world(selected_obj)
	selected_obj.reparent(placed_objects_container, false)
	selected_obj.remove_from_group("selected_item")
	placed_objects_container.layout_children()
	_update_put_down_button()


func _on_exit_button_pressed() -> void :
	deactivate()


func _update_put_down_button() -> void :
	put_down_button.visible = get_selected_object() != null

func _on_selected_object_left(_node: Node) -> void:
	_update_put_down_button.call_deferred()
