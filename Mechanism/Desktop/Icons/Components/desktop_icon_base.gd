@tool
@abstract
class_name DesktopIconBase
extends Control

@export var desktop_icon_visuals: VBoxContainer

@export_group("Configuration")
@export var icon_texture: Texture2D :
	set(value):
		icon_texture = value
		update_visuals()


@export var icon_name: String = "Application" :
	set(value):
		icon_name = value
		update_visuals()

@export var font_color: Color = Color.WHITE :
	set(value):
		font_color = value
		update_visuals()

@export var program_to_run: PackedScene


signal program_ran(program: Node)

var _instantiated_prog: Node


func _ready() -> void :
	update_visuals()


func update_visuals() -> void :
	if (desktop_icon_visuals == null) :
		return

	desktop_icon_visuals.update_thumbnail(icon_texture)
	desktop_icon_visuals.update_name(icon_name)
	desktop_icon_visuals.update_name_color(font_color)


func _gui_input(event: InputEvent) -> void :
	if (not event is InputEventMouseButton) :
		return

	if (event.double_click and event.button_index == MOUSE_BUTTON_LEFT) :
		_run_program()


func _run_program() -> void :
	if (program_to_run == null) :
		return
	
	if (Engine.is_editor_hint()) :
		return

	_instantiated_prog = program_to_run.instantiate()
	var main_window := _get_main_window()

	main_window.add_child(_instantiated_prog)
	program_ran.emit(_instantiated_prog)


func _get_main_window() -> DesktopWindow :
	var node = self

	while (not node is DesktopWindow) :
		node = node.get_parent()

		if (node == get_tree().root) :
			assert(false, "Icon is somehow not attached to any DesktopWindow node!!")

	return node


@abstract func _on_program_ran(app: Node) -> void
