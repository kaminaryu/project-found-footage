@tool
class_name DialogueTrigger
extends Area3D
## Plays a conversation when the player walks into this area.
## Add a CollisionShape3D as its child, then pick the conversation in the Inspector.
## It reacts to physics layer 2 ("player"), so only the player sets it off.

const Reader := preload("res://addons/vhs_dialogue/dialogue_reader.gd")

## The [name] of the conversation in your dialogue files.
@export var conversation := ""
## Play only if this conversation hasn't been played yet this game.
@export var only_once := true
## Wait this many seconds after the player walks in.
@export var delay := 0.0

var _busy := false


func _init() -> void:
	collision_layer = 1 << 2   # layer 3, "triggers"
	collision_mask = 1 << 1    # layer 2, "player"
	monitorable = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node3D) -> void:
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue == null:
		push_error("DialogueTrigger: the Dialogue autoload is missing. Turn on the VHS Dialogue plugin.")
		return
	if _busy or (only_once and dialogue.has_played(conversation)):
		return
	_busy = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	await dialogue.play(conversation)
	_busy = false


# In the editor, offer the conversation names from the dialogue files as suggestions.
func _validate_property(property: Dictionary) -> void:
	if property.name == "conversation":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(Reader.read_all(true).keys())
