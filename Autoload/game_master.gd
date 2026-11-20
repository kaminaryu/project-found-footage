extends Node

signal freezing_main_window(frozen: bool)


func freeze_main_window(frozen: bool) -> void:
	freezing_main_window.emit(frozen)
