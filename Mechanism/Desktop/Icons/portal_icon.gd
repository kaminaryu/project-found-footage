@tool
extends DesktopIconBase

func _ready() -> void :
	super._ready()
	program_ran.connect(_on_program_ran)


func _on_program_ran(_app: Node) -> void :
	pass
