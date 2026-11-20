@tool
extends EditorExportPlugin
## Copies every dialogue .txt file into the exported game.

const Reader := preload("res://addons/vhs_dialogue/dialogue_reader.gd")


func _get_name() -> String:
	return "VHSDialogueExport"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	for path in Reader.find_files(Reader.FOLDER):
		add_file(path, FileAccess.get_file_as_bytes(path), false)
