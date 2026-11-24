extends Node

@onready var timer: Timer = $Timer
@onready var sfx_list: Node = $SFXList


func _ready() -> void :
	_set_random_time()
	timer.start()


func _set_random_time() -> void :
	var min_s = 30
	var max_s = 90
	var random_seconds := randi_range(min_s, max_s)

	timer.wait_time = random_seconds


func _play_random_sound() -> void :
	var is_list_empty = sfx_list.get_child_count() == 0
	if (is_list_empty) :
		return

	var sfx_player := _get_random_sfx_player()
	sfx_player.play()


func _get_random_sfx_player() -> SFXPlayer :
	var random_index = randi_range(0, sfx_list.get_child_count() - 1)
	print(random_index)
	var random_sfx_player = sfx_list.get_child(random_index)

	return random_sfx_player


func _on_timer_timeout() -> void :
	_play_random_sound()
	_set_random_time()
