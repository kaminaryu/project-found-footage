extends Node

signal freezing_main_window(frozen: bool)
signal showing_hint(text: String)

func freeze_main_window(frozen: bool) -> void:
	freezing_main_window.emit(frozen)


func show_hint(text: String) -> void :
	showing_hint.emit(text)
