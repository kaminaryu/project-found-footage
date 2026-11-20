extends MeshInstance3D

@export var pile: MeshInstance3D


func _ready() -> void :
	if (GameMaster.is_flag_raised(&"scrap_collected")) :
		pile.hide()


func run(_player: Node) -> void :
	if (GameMaster.is_flag_raised(&"scrap_collected")) :
		GameMaster.show_hint("Box is empty.")
		return

	GameMaster.collect_scrap()
	pile.hide()
