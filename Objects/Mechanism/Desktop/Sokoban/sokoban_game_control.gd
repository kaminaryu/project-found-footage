extends PanelContainer

@export var next_normal: StyleBoxFlat
@export var next_hover: StyleBoxFlat
@export var next_pressed: StyleBoxFlat

@onready var _game: Node2D = $"../SokobanGame"
@onready var _action: Button = $MarginContainer/HBoxContainer/Undo


func _ready() -> void:
	_game.state_changed.connect(_on_game_state_changed)
	_apply_state(false)


func _on_left_pressed() -> void:
	_game.try_move(Vector2i.LEFT)


func _on_down_pressed() -> void:
	_game.try_move(Vector2i.DOWN)


func _on_up_pressed() -> void:
	_game.try_move(Vector2i.UP)


func _on_right_pressed() -> void:
	_game.try_move(Vector2i.RIGHT)


func _on_action_pressed() -> void:
	if _game.has_won():
		_game.next_level()
	else:
		_game.undo()


func _on_game_state_changed(won: bool) -> void:
	_apply_state(won)


func _apply_state(won: bool) -> void:
	_action.text = "Next" if won else "Undo"

	if won:
		_action.add_theme_stylebox_override("normal", next_normal)
		_action.add_theme_stylebox_override("hover", next_hover)
		_action.add_theme_stylebox_override("pressed", next_pressed)
		_action.add_theme_color_override("font_color", Color(0.9, 1, 0.9, 1))
		_action.add_theme_color_override("font_hover_color", Color(0.95, 1, 0.95, 1))
		_action.add_theme_color_override("font_pressed_color", Color(0.85, 1, 0.85, 1))
	else:
		_action.remove_theme_stylebox_override("normal")
		_action.remove_theme_stylebox_override("hover")
		_action.remove_theme_stylebox_override("pressed")
		_action.remove_theme_color_override("font_color")
		_action.remove_theme_color_override("font_hover_color")
		_action.remove_theme_color_override("font_pressed_color")
