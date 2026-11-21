extends CanvasLayer

@export var popup_hint: Label
@export var showcase_scraps: Control


func _ready() -> void :
	GameMaster.showing_hint.connect(_show_hint)
	GameMaster.collecting_scrap.connect(_on_scrap_collected)


func _show_hint(text: String) -> void :
	var anim_player: AnimationPlayer = popup_hint.get_node("AnimationPlayer")
	var timer: Timer = popup_hint.get_node("Timer")

	popup_hint.text = text
	anim_player.play("HintSlideIn")
	timer.start()


func _on_timer_timeout() -> void:
	var anim_player: AnimationPlayer = popup_hint.get_node("AnimationPlayer")
	anim_player.play("HintFadeOut") # Replace with function body.


func _on_scrap_collected() -> void :
	showcase_scraps.show()
	GameMaster.freeze_main_window(true)
