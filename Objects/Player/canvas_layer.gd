extends CanvasLayer

@export var popup_hint: Label

func _ready() -> void :
	GameMaster.showing_hint.connect(_show_hint)


func _show_hint(text: String) -> void :
	var anim_player: AnimationPlayer = popup_hint.get_node("AnimationPlayer")
	var timer: Timer = popup_hint.get_node("Timer")

	popup_hint.text = text
	anim_player.play("HintSlideIn")
	timer.start()


func _on_timer_timeout() -> void:
	var anim_player: AnimationPlayer = popup_hint.get_node("AnimationPlayer")
	anim_player.play("HintFadeOut") # Replace with function body.
