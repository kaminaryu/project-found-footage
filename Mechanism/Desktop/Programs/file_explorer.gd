class_name FileExplorer
extends GameWindow

signal file_activated(entry: FileExplorerEntry)

const FILE_ENTRY_SCENE := preload("res://Mechanism/Desktop/FileExplorer/file_entry.tscn")
const AUDIO_PLAYER_SCENE := preload("res://Mechanism/Desktop/Programs/audio_player.tscn")

@onready var _grid: GridContainer = %FileGrid
@onready var _empty_label: Label = %EmptyLabel
@onready var _close_button: Button = $CloseButton

func _window_ready() -> void:
	_grid.child_entered_tree.connect(_on_grid_child_entered)

	for child in _grid.get_children():
		_register_entry(child)

	_update_empty_state()


func add_entry(texture: Texture2D, display_name: String, audio: AudioStream = null) -> FileExplorerEntry:
	var entry := FILE_ENTRY_SCENE.instantiate() as FileExplorerEntry
	_grid.add_child(entry)
	entry.setup(texture, display_name, audio)
	_register_entry(entry)
	_update_empty_state()
	return entry


func _on_grid_child_entered(node: Node) -> void:
	_register_entry(node)


func _register_entry(node: Node) -> void:
	var entry := node as FileExplorerEntry
	if entry == null:
		return

	if not entry.activated.is_connected(_on_entry_activated):
		entry.activated.connect(_on_entry_activated)

	_update_empty_state()


func _on_entry_activated(entry: FileExplorerEntry) -> void:
	file_activated.emit(entry)

	if entry.audio_stream != null:
		_open_audio_player(entry)



func _open_audio_player(entry: FileExplorerEntry) -> void:
	var player := AUDIO_PLAYER_SCENE.instantiate() as AudioPlayer
	get_parent().add_child(player) #open music inside the desktop too
	player.play_stream(entry.audio_stream, entry.file_name)
	player.grab_focus()


func _update_empty_state() -> void:
	_empty_label.visible = _grid.get_child_count() == 0


func _on_close_button_mouse_entered() -> void:
	_close_button.material.set_shader_parameter("flash_value", 0.2)


func _on_close_button_mouse_exited() -> void:
	_close_button.material.set_shader_parameter("flash_value", 0.0)
