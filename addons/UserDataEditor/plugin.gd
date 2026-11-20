@tool
extends EditorPlugin

const SCENE := preload("res://addons/UserDataEditor/user_data_editor.tscn")

var panel: Control


func _enter_tree() -> void:
	panel = SCENE.instantiate()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(panel)
	_make_visible(false)


func _exit_tree() -> void:
	if panel:
		panel.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if panel:
		panel.visible = visible


func _get_plugin_name() -> String:
	return "User Data"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Edit", "EditorIcons")
