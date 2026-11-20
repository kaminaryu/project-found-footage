extends MeshInstance3D


func run(_player: Node) -> void :
	if (GameMaster.is_flag_raised(&"uploaded_data_to_pc")) :
		GameMaster.show_hint("Data had already been uploaded.")
		return

	var has_floppy := GameMaster.is_flag_raised(&"scrap_collected")
	var has_memcard := GameMaster.is_flag_raised(&"extracted_memcard")

	if (not has_floppy and not has_memcard) :
		GameMaster.show_hint("Need the floppy disk and the memory card.")
		return

	if (not has_floppy) :
		GameMaster.show_hint("Find the floppy disk in the scraps.")
		return

	if (not has_memcard) :
		GameMaster.show_hint("Extract the memory card from the camera first.")
		return

	GameMaster.raise_flag(&"uploaded_data_to_pc")
	GameMaster.show_hint("Uploaded data from both storage devices.")
