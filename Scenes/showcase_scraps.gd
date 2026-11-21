extends Control


func _on_close_button_pressed() -> void:
	hide()
	GameMaster.freeze_main_window(false)
	GameMaster.show_hint("You collected some scraps.")
