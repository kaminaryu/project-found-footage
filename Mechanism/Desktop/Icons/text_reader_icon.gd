@tool
extends DesktopIconBase

@export_file("*.txt", "*.md") var file_path: String :
	set (value) :
		file_path = value
		icon_name = file_path.get_file()
		_update_name()



func _ready() -> void :
	super._ready()
	program_ran.connect(_on_program_ran)


func _update_name() -> void :
	update_visuals()


func _on_program_ran(program: Node) -> void :
	program.open_file(file_path)
