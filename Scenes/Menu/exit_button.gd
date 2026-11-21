extends HBoxContainer

func _ready() -> void :
	if (OS.has_feature("web")) :
		hide()
	else :
		show()


func _on_label_pressed() -> void:
	get_tree().quit()
