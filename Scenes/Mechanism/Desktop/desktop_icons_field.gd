extends MarginContainer

const SNAP_DURATION := 0.08
const INVALID_CELL := Vector2i(-1, -1)

@export var cell_size := Vector2(96, 96)

@onready var icons_field: Control = $IconsField

var _cells := {}
var _occupied := {}
var _snap_tweens := {}
var _dragging_icon: Control = null
var _connected_icons := {}


func _ready() -> void:
	icons_field.child_entered_tree.connect(_register_icon)
	await get_tree().process_frame

	for child in icons_field.get_children():
		_register_icon(child)


# godot calls ts
func _notification(what: int) -> void:
	# if window  unfocused, stop the dragging so that it doesnt glitched out
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _dragging_icon != null:
		_stop_drag(_dragging_icon)


func _register_icon(icon_node: Node) -> void:
	var icon := icon_node as Control
	if icon == null or _cells.has(icon):
		return

	_connect_icon(icon)

	if not icon.visible:
		return

	_place_icon(icon)


func _connect_icon(icon: Control) -> void:
	if _connected_icons.has(icon):
		return

	_connected_icons[icon] = true
	icon.gui_input.connect(_on_icon_gui_input.bind(icon))
	icon.visibility_changed.connect(_on_icon_visibility_changed.bind(icon))
	icon.tree_exited.connect(_unregister_icon.bind(icon))


func _place_icon(icon: Control) -> void:
	if _cells.has(icon):
		return

	var cell := _nearest_free_cell(_cell_from_position(icon))
	if cell == INVALID_CELL:
		return

	_cells[icon] = cell
	_occupied[cell] = icon
	icon.position = _cell_position(cell, icon)


func _release_icon(icon: Control) -> void:
	var cell: Vector2i = _cells.get(icon, INVALID_CELL)
	if cell != INVALID_CELL and _occupied.get(cell) == icon:
		_occupied.erase(cell)

	_cells.erase(icon)
	_kill_snap_tween(icon)

	if _dragging_icon == icon:
		_dragging_icon = null


func _unregister_icon(icon: Control) -> void:
	_release_icon(icon)
	_connected_icons.erase(icon)


func _on_icon_visibility_changed(icon: Control) -> void:
	if icon.visible:
		_place_icon(icon)
	else:
		_release_icon(icon)


func _on_icon_gui_input(event: InputEvent, icon: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(icon)
		elif _dragging_icon == icon:
			_stop_drag(icon)

	elif event is InputEventMouseMotion and _dragging_icon == icon:
		icon.position += event.relative
		icon.position = icon.position.clamp(
			Vector2.ZERO, icons_field.size - icon.size
		)


func _start_drag(icon: Control) -> void:
	if _dragging_icon != null and _dragging_icon != icon:
		_stop_drag(_dragging_icon)

	_dragging_icon = icon
	_kill_snap_tween(icon)

	var cell: Vector2i = _cells.get(icon, INVALID_CELL)
	if cell != INVALID_CELL and _occupied.get(cell) == icon:
		_occupied.erase(cell)

	icon.move_to_front()


func _stop_drag(icon: Control) -> void:
	_dragging_icon = null

	var cell := _nearest_free_cell(_cell_from_position(icon))
	if cell == INVALID_CELL:
		cell = _cells.get(icon, Vector2i.ZERO)

	_cells[icon] = cell
	_occupied[cell] = icon

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position", _cell_position(cell, icon), SNAP_DURATION)
	_snap_tweens[icon] = tween


func _cell_from_position(icon: Control) -> Vector2i:
	var offset := icon.position + icon.size * 0.5 - cell_size * 0.5
	return Vector2i(
		roundi(offset.x / cell_size.x),
		roundi(offset.y / cell_size.y)
	)


func _cell_position(cell: Vector2i, icon: Control) -> Vector2:
	return Vector2(cell) * cell_size + (cell_size - icon.size) * 0.5


func _grid_size() -> Vector2i:
	return Vector2i(
		maxi(1, floori(icons_field.size.x / cell_size.x)),
		maxi(1, floori(icons_field.size.y / cell_size.y))
	)


func _nearest_free_cell(target: Vector2i) -> Vector2i:
	var grid := _grid_size()
	var best := INVALID_CELL
	var best_distance := INF

	for y in grid.y:
		for x in grid.x:
			var cell := Vector2i(x, y)
			if _occupied.has(cell):
				continue

			var distance := Vector2(cell).distance_squared_to(Vector2(target))
			if distance < best_distance:
				best_distance = distance
				best = cell

	return best


func _kill_snap_tween(icon: Control) -> void:
	var tween: Tween = _snap_tweens.get(icon)
	if tween and tween.is_valid():
		tween.kill()
	_snap_tweens.erase(icon)
