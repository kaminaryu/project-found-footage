class_name PhotoThumbnail
extends Button

signal picked(entry: PhotoEntry) #A signal 

var entry: PhotoEntry #holds the photo thumbnail

func setup(new_entry: PhotoEntry) -> void:
	entry = new_entry
	%Picture.texture = entry.image
	entry.changed.connect(_on_entry_changed)
	_on_entry_changed()

func _on_entry_changed() -> void:
	%Check.visible = entry.is_edited()
func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		picked.emit(entry)
