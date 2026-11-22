extends PanelContainer

const ITEM_SCENE := preload("res://UI/TodoList/todo_item.tscn")

@export var data: TodoData
@export var start_expanded := true

@onready var count_label: Label = %Count
@onready var divider: ColorRect = %Divider
@onready var content: VBoxContainer = %Content
@onready var task_title: Label = %TaskTitle
@onready var task_list: VBoxContainer = %TaskList
@onready var empty_label: Label = %EmptyLabel

var _rows: Array[TodoItem] = []
var _expanded := true
var _shown_task_index := -1
var _content_tween: Tween


func _ready() -> void:
	_expanded = start_expanded
	_validate_data()

	GameMaster.flag_raised.connect(_on_flag_raised)
	GameMaster.flags_cleared.connect(_on_flags_cleared)

	_refresh(false)



func _on_flag_raised(flag: StringName) -> void:
	if not _uses_flag(flag):
		return

	_refresh(true)


func _on_flags_cleared() -> void:
	_shown_task_index = -1
	_refresh(false)


func _refresh(animate: bool) -> void:
	var next_index := _find_current_index()
	var changed := next_index != _shown_task_index

	_shown_task_index = next_index

	if changed:
		_show_task(animate)
	else:
		_update_task()


func _show_task(animate: bool) -> void:
	if _content_tween:
		_content_tween.kill()

	var has_content := task_list.get_child_count() > 0 or empty_label.visible

	if animate and _expanded and has_content:
		_content_tween = create_tween()
		_content_tween.tween_property(content, "modulate:a", 0.0, 0.12)
		_content_tween.tween_callback(_apply_current_task)
		_content_tween.tween_property(content, "modulate:a", 1.0, 0.18)
	else:
		_apply_current_task()
		content.modulate.a = 1.0


func _update_task() -> void:
	for row in _rows:
		if is_instance_valid(row):
			row.set_completed(GameMaster.is_flag_raised(row.flag))


func _apply_current_task() -> void:
	_clear_rows()

	var tasks := _tasks()
	var current := _find_current_index()

	if tasks.is_empty():
		task_title.hide()
		task_list.hide()
		empty_label.text = "NO OBJECTIVES"
		empty_label.show()
		count_label.text = "0 / 0"
		_fit()
		return

	if current >= tasks.size():
		task_title.hide()
		task_list.hide()
		empty_label.text = "ALL OBJECTIVES COMPLETE"
		empty_label.show()
		count_label.text = "%d / %d" % [tasks.size(), tasks.size()]
		_fit()
		return

	var task := tasks[current]

	if task == null:
		return

	empty_label.hide()
	task_list.show()
	count_label.text = "%d / %d" % [current + 1, tasks.size()]

	if task.subtasks.is_empty():
		task_title.hide()
		_add_row(task.text, task.flag)
	else:
		task_title.text = task.text
		task_title.show()

		for sub in task.subtasks:
			if sub != null:
				_add_row(sub.text, sub.flag)

	_fit()


func _add_row(text: String, flag: StringName) -> void:
	var row := ITEM_SCENE.instantiate() as TodoItem
	task_list.add_child(row)
	row.setup(text, flag, GameMaster.is_flag_raised(flag))
	_rows.append(row)


func _clear_rows() -> void:
	for child in task_list.get_children():
		task_list.remove_child(child)
		child.queue_free()

	_rows.clear()


func _fit() -> void:
	call_deferred("reset_size")


func _find_current_index() -> int:
	var tasks := _tasks()

	for i in tasks.size():
		if not _is_task_complete(tasks[i]):
			return i

	return tasks.size()


func _is_task_complete(task: TodoTask) -> bool:
	if task == null:
		return true

	if task.subtasks.is_empty():
		return task.flag != &"" and GameMaster.is_flag_raised(task.flag)

	for sub in task.subtasks:
		if sub == null or sub.flag == &"" or not GameMaster.is_flag_raised(sub.flag):
			return false

	return true


func _uses_flag(flag: StringName) -> bool:
	if flag == &"":
		return false

	for task in _tasks():
		if task == null:
			continue

		if task.subtasks.is_empty():
			if task.flag == flag:
				return true
		else:
			for sub in task.subtasks:
				if sub != null and sub.flag == flag:
					return true

	return false


func _tasks() -> Array[TodoTask]:
	if data == null:
		return []

	return data.tasks


func _validate_data() -> void:
	if data == null:
		push_warning("TodoList: no TodoData assigned.")
		return

	for task in data.tasks:
		if task == null:
			push_warning("TodoList: empty task entry.")
			continue

		if not task.subtasks.is_empty() and task.flag != &"":
			push_warning("TodoList: '%s' has a flag and subtasks; the flag is ignored." % task.text)

		if task.subtasks.is_empty() and task.flag == &"":
			push_warning("TodoList: '%s' has no flag and no subtasks, so it can never complete." % task.text)

		for sub in task.subtasks:
			if sub == null or sub.flag == &"":
				push_warning("TodoList: '%s' has a subtask with no flag." % task.text)
