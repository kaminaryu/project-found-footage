extends PanelContainer

const SAVE_PATH := "user://save.json"
const SAVE_KEY := "todo"
const ITEM_SCENE := preload("res://UI/TodoList/todo_item.tscn")

@export var data: TodoData
@export var start_expanded := true
@export var save_progress := true

@onready var count_label: Label = %Count
@onready var divider: ColorRect = %Divider
@onready var content: VBoxContainer = %Content
@onready var task_title: Label = %TaskTitle
@onready var task_list: VBoxContainer = %TaskList
@onready var empty_label: Label = %EmptyLabel

var _raised_flags: Dictionary = {}
var _rows: Array[TodoItem] = []
var _expanded := true
var _shown_task_index := -1
var _content_tween: Tween
var _ui_tween: Tween


func _ready() -> void:
	_expanded = start_expanded
	_validate_data()
	_load_progress()

	GameMaster.flag_raised.connect(_on_flag_raised)

	_refresh(false)


func reset_progress() -> void:
	_raised_flags.clear()
	_shown_task_index = -1
	_save_progress()

	if is_node_ready():
		_refresh(false)


func _on_flag_raised(flag: StringName) -> void:
	if not _uses_flag(flag):
		return

	if _raised_flags.has(flag):
		return

	_raised_flags[flag] = true
	_save_progress()
	_refresh(true)



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
			row.set_completed(_raised_flags.has(row.flag))


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
	row.setup(text, flag, _raised_flags.has(flag))
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
		return task.flag != &"" and _raised_flags.has(task.flag)

	for sub in task.subtasks:
		if sub == null or sub.flag == &"" or not _raised_flags.has(sub.flag):
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


func _load_progress() -> void:
	_raised_flags.clear()

	if not save_progress:
		return

	var saved := _read_save()
	var todo = saved.get(SAVE_KEY, {})

	if not (todo is Dictionary):
		return

	var flags = todo.get("flags", [])

	if not (flags is Array):
		return

	for flag in flags:
		if flag is String and not flag.is_empty():
			_raised_flags[StringName(flag)] = true


func _save_progress() -> void:
	if not save_progress:
		return

	var saved := _read_save()
	var flags: Array[String] = []

	for flag in _raised_flags.keys():
		flags.append(String(flag))

	flags.sort()
	saved[SAVE_KEY] = {"flags": flags}
	_write_save(saved)


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	return parsed if parsed is Dictionary else {}


func _write_save(saved: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify(saved))
	file.close()
