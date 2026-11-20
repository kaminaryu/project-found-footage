class_name TodoTask
extends Resource
## One objective. Set a flag for a single-step task, or add subtasks for a multi-step task.

@export var text: String = ""
@export var flag: StringName = &""
@export var subtasks: Array[TodoSubtask] = []
