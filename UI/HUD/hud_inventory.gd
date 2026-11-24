extends Control
#The small inventory at the bottom left. Mouse wheel picks a slot, P places it on the workbench.

const SLOT_SIZE := 64        #how big each square slot is
const VIEW_ANGLE := 35.0     #how far each model is turned, so you see it from the side a bit (3/4 view)
const MODEL_SIZE := 2.6      #how big the model is inside its little 3D world

@export var items: Array[HudItem] = []
@export var player: Node   #to know what the player is looking at, and if the game is frozen

@onready var slots_box: VBoxContainer = $Slots
@onready var place_hint: Label = $PlaceHint

var selected := 0                          #which slot is highlighted (0 = the top one)
var _borders: Array[StyleBoxFlat] = []     #one border per slot, so we can recolour the selected one


func _ready() -> void:
	GameMaster.flag_raised.connect(_on_flag_raised)
	_rebuild()


func _on_flag_raised(_flag: StringName) -> void:
	_rebuild()   #a flag may add a slot (scraps collected, phone fixed) or remove one (placed)


## The items that are in the inventory right now, decided by the flags.
func _current_items() -> Array[HudItem]:
	var list: Array[HudItem] = []
	for item in items:
		if item == null or not GameMaster.is_flag_raised(item.show_flag):
			continue   #not collected yet
		if item.place_flag != &"" and GameMaster.is_flag_raised(item.place_flag):
			continue   #already placed on the workbench
		list.append(item)
	return list


## Throws the old slots away and makes new ones for what we have now.
func _rebuild() -> void:
	for slot in slots_box.get_children():
		slot.queue_free()
	_borders.clear()

	var list := _current_items()
	selected = clampi(selected, 0, maxi(list.size() - 1, 0))
	for item in list:
		var slot := _make_slot()
		slots_box.add_child(slot)
		_add_model_view(slot, item)
	slots_box.visible = not list.is_empty()
	_update_borders()


## An empty square slot with a dark background and a border.
func _make_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0.55)
	border.set_content_margin_all(2)
	slot.add_theme_stylebox_override("panel", border)
	_borders.append(border)
	return slot


## A tiny 3D world inside the slot: a camera, lights, and the model standing still at a nice angle.
func _add_model_view(slot: PanelContainer, item: HudItem) -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(holder)        #on screen first, so the model can be measured below

	var world := SubViewport.new()
	world.own_world_3d = true     #its own little world, so the copy never shows up in the room
	world.transparent_bg = true   #see-through background, only the model is drawn
	holder.add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.9, 2.4)
	camera.rotation_degrees.x = -20   #look a bit down at the model
	world.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	world.add_child(light)

	var ambient := WorldEnvironment.new()   #soft light from everywhere, so the dark side isn't black
	ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	world.add_child(ambient)

	var stand := Node3D.new()         #the model stands on this, turned to a nice angle
	stand.rotation_degrees.y = VIEW_ANGLE
	world.add_child(stand)

	if item.model != null:
		var model := item.model.instantiate() as Node3D
		_make_statue(model)
		stand.add_child(model)
		model.rotation_degrees = item.model_rotation
		_fit(model, stand)


## Removes every script from the copy, so it is only a statue
## (otherwise the phone copy would delete itself once the phone is fixed).
func _make_statue(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		_make_statue(child)


## Makes the model the same size as the others and puts its middle on the stand's centre.
func _fit(model: Node3D, stand: Node3D) -> void:
	var box := _bounds(model, stand)
	if box.size == Vector3.ZERO:
		return
	var biggest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var zoom := MODEL_SIZE / biggest
	model.scale *= zoom
	model.position = -box.get_center() * zoom


## The box around all the model's meshes, measured from the stand.
func _bounds(model: Node3D, stand: Node3D) -> AABB:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	var to_stand := stand.global_transform.affine_inverse()
	var box := AABB()
	for i in meshes.size():
		var mesh := meshes[i] as MeshInstance3D
		var part: AABB = (to_stand * mesh.global_transform) * mesh.get_aabb()
		box = part if i == 0 else box.merge(part)
	return box


## Gold thick border on the selected slot, thin grey on the others.
func _update_borders() -> void:
	for i in _borders.size():
		var is_selected := i == selected
		_borders[i].set_border_width_all(3 if is_selected else 1)
		_borders[i].border_color = Color(1.0, 0.82, 0.35) if is_selected else Color(1, 1, 1, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if player.is_frozen:
		return   #desktop, workbench, phone or a cutscene is open
	var list := _current_items()
	if list.is_empty():
		return

	if event.is_action_pressed("inventory_down"):
		selected = wrapi(selected + 1, 0, list.size())
		_update_borders()
	elif event.is_action_pressed("inventory_up"):
		selected = wrapi(selected - 1, 0, list.size())
		_update_borders()
	elif event.is_action_pressed("place_item"):
		var item := list[selected]
		if _can_place(item):
			GameMaster.raise_flag(item.place_flag)   #the workbench hears this and shows the device
			GameMaster.show_hint("You placed the %s on the workbench." % item.display_name)


func _process(_delta: float) -> void:
	var list := _current_items()
	var item: HudItem = list[selected] if selected < list.size() else null
	var show_hint: bool = item != null and not player.is_frozen and _can_place(item)
	place_hint.visible = show_hint
	if show_hint:
		place_hint.text = "Press P to place %s" % item.display_name


func _can_place(item: HudItem) -> bool:
	return item.place_flag != &"" and _looking_at_workbench()


func _looking_at_workbench() -> bool:
	var target = player.looked_at
	return target != null and is_instance_valid(target) and target.is_in_group("workbench")
