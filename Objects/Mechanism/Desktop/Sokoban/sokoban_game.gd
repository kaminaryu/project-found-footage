extends Node2D

signal state_changed(won: bool)

const BOX_OFF_GOAL := Color(0.9, 0.55, 0.2)
const BOX_ON_GOAL := Color(0.35, 0.85, 0.4)
const FINAL_LEVEL_INDEX := 3

@export var play_area_size := Vector2(640.0, 352.0)

@onready var _levels_root: Node2D = $Levels
@onready var _level_label: Label = $LevelLabel
@onready var _win_label: Label = $WinLabel

var _level_index := 3
var _terrain: TileMapLayer
var _player: Node2D

var _walls := {}
var _goals := {}
var _boxes := {}
var _player_cell := Vector2i.ZERO
var _won := false
var _undo: Array[Dictionary] = []
var _initial_boxes := {}
var _initial_player := Vector2i.ZERO
var _level_states: Array[Dictionary] = []


func _ready() -> void:
	for level in _levels_root.get_children():
		_level_states.append(_capture_initial_state(level))
	load_level(0)


func try_move(dir: Vector2i) -> void:
	if _won:
		return

	var target := _player_cell + dir
	if _walls.has(target):
		return

	var pushed: Node2D = null
	var push_to := Vector2i.ZERO
	if _boxes.has(target):
		push_to = target + dir
		if _walls.has(push_to) or _boxes.has(push_to):
			return
		pushed = _boxes[target]

	_undo.append({"player": _player_cell, "boxes": _boxes.duplicate()})

	_player_cell = target
	if pushed:
		_boxes.erase(target)
		_boxes[push_to] = pushed

	_snap_all()
	_update_box_tints()
	_check_win()


func undo() -> void:
	if _undo.is_empty():
		return

	var state: Dictionary = _undo.pop_back()
	_player_cell = state["player"]
	_boxes = state["boxes"].duplicate()
	_won = false
	_win_label.hide()
	_snap_all()
	_update_box_tints()
	state_changed.emit(false)


func next_level() -> void:
	if not has_won() :
		return

	if is_last_level():
		_win_label.text = "All levels solved!"
		_win_label.show()
		return

	load_level(_level_index + 1)


func is_last_level() -> bool:
	return _level_index >= _levels_root.get_child_count() - 1


func has_won() -> bool:
	return _won


func load_level(index: int) -> void:
	if index < 0 or index >= _levels_root.get_child_count():
		return

	_level_index = index
	for i in _levels_root.get_child_count():
		_levels_root.get_child(i).visible = i == index

	var level: Node2D = _levels_root.get_child(index)
	_terrain = level.get_node("Terrain")
	_player = level.get_node("Player")
	_center_level(level)

	var state: Dictionary = _level_states[index]
	_player_cell = state["player"]
	_boxes = state["boxes"].duplicate()
	_initial_player = _player_cell
	_initial_boxes = _boxes.duplicate()

	_read_board()
	_undo.clear()
	_won = false
	_win_label.text = "Solved!"
	_win_label.hide()
	_snap_all()
	_update_box_tints()
	_level_label.text = "Level %d / %d" % [index + 1, _levels_root.get_child_count()]
	state_changed.emit(false)


func _center_level(level: Node2D) -> void:
	var terrain: TileMapLayer = level.get_node("Terrain")
	if terrain.tile_set == null:
		return

	var tile_size := Vector2(terrain.tile_set.tile_size)
	var half := tile_size * 0.5
	var bounds := Rect2()
	var has_bounds := false

	for cell in terrain.get_used_cells():
		var center := terrain.to_global(terrain.map_to_local(cell))
		var cell_rect := Rect2(center - half, tile_size)
		bounds = cell_rect if not has_bounds else bounds.merge(cell_rect)
		has_bounds = true

	if not has_bounds:
		return

	level.global_position += play_area_size * 0.5 - bounds.get_center()


func _capture_initial_state(level: Node2D) -> Dictionary:
	var terrain: TileMapLayer = level.get_node("Terrain")
	var player: Node2D = level.get_node("Player")
	var boxes_root: Node2D = level.get_node("Boxes")

	var player_cell := terrain.local_to_map(terrain.to_local(player.global_position))
	player.global_position = terrain.to_global(terrain.map_to_local(player_cell))

	var boxes := {}
	for box in boxes_root.get_children():
		if box is Node2D:
			var cell := terrain.local_to_map(terrain.to_local(box.global_position))
			box.global_position = terrain.to_global(terrain.map_to_local(cell))
			boxes[cell] = box

	return {"player": player_cell, "boxes": boxes}


func _read_board() -> void:
	_walls.clear()
	_goals.clear()

	for cell in _terrain.get_used_cells():
		var data := _terrain.get_cell_tile_data(cell)
		if data.get_custom_data("solid"):
			_walls[cell] = true
		if data.get_custom_data("goal"):
			_goals[cell] = true


func _snap_all() -> void:
	for cell in _boxes:
		var box: Node2D = _boxes[cell]
		box.global_position = _cell_center(cell)
	_player.global_position = _cell_center(_player_cell)


func _update_box_tints() -> void:
	for cell in _boxes:
		var box: Sprite2D = _boxes[cell]
		box.modulate = BOX_ON_GOAL if _goals.has(cell) else BOX_OFF_GOAL


func _check_win() -> void:
	for cell in _boxes:
		if not _goals.has(cell):
			return

	if (_level_index == FINAL_LEVEL_INDEX) :
		GameMaster.raise_flag(&"sokoban_completed")
		jumpscare()

	_won = true
	_win_label.text = "All levels solved!" if is_last_level() else "Solved!"
	_win_label.show()
	state_changed.emit(true)


func _cell_center(cell: Vector2i) -> Vector2:
	return _terrain.to_global(_terrain.map_to_local(cell))


func jumpscare() -> void :
	var window := _find_parent_window()
	if window == null:
		return

	for other in get_tree().get_nodes_in_group("glitchable_window"):
		if other != window and other.has_method("glitch_and_close"):
			other.glitch_and_close(1.2, 1.0)


	if window.has_method("glitch_and_close"):
		window.glitch_and_close(1.2, 0.8)
	else:
		window.queue_free()

	set_desktop_flags()
	await get_tree().create_timer(2.0).timeout
	GameMaster.show_hint("Maybe I should re-run the game..")


func _find_parent_window() -> Window:
	var node: Node = get_parent()

	while node != null:
		if node is Window:
			return node as Window
		node = node.get_parent()

	return null


func set_desktop_flags() -> void :
	var saved_data := load_data()

	saved_data["sokoban_finished"] = true

	save_data(saved_data)


func save_data(data: Dictionary) -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func load_data() -> Dictionary:
	if not FileAccess.file_exists("user://save.json"):
		return {}

	var file := FileAccess.open("user://save.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
