extends Window


func _on_minimize_pressed() -> void:
	pass # Replace with function body.


func _on_close_pressed() -> void:
	_on_close_requested()


func _on_close_requested() -> void:
	queue_free()
