@tool
extends EditorPlugin
## Turns the VHS Dialogue add-on on and off (Project > Project Settings > Plugins).
## Turning it on adds the "Dialogue" autoload, so every script can call Dialogue.play("name").

const AUTOLOAD_NAME := "Dialogue"
const AUTOLOAD_PATH := "res://addons/vhs_dialogue/dialogue.tscn"

var _export_plugin: EditorExportPlugin


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _enter_tree() -> void:
	# Dialogue .txt files are not game resources, so Godot would leave them out of an
	# exported game. This export plugin packs them in.
	_export_plugin = preload("res://addons/vhs_dialogue/export_plugin.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
