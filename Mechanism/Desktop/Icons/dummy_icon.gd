@tool
extends DesktopIconBase

func _ready() -> void :
	super._ready()
	program_ran.connect(_on_program_ran)


func _on_program_ran(err_popup: Node) -> void :
	err_popup.run("Unexpected Error", "%s cannot be run." % icon_name)
