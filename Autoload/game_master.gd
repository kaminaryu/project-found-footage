extends Node

signal freezing_main_window(frozen: bool)
signal showing_hint(text: String)
signal collecting_scrap
signal flag_raised(flag: StringName)

func freeze_main_window(frozen: bool) -> void:
	freezing_main_window.emit(frozen)


func show_hint(text: String) -> void :
	showing_hint.emit(text)


func collect_scrap() -> void :
	collecting_scrap.emit()
	raise_flag(&"scrap_collected")


func raise_flag(flag: StringName) -> void :
	flag_raised.emit(flag)
