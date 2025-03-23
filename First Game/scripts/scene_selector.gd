extends Node2D

func _ready():
	# 确保场景选择器是全屏的
	$ColorRect.size = get_viewport_rect().size

func _on_normal_mode_button_pressed():
	# 切换到普通游戏模式
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_mp_survivor_button_pressed():
	# 切换到多人吸血鬼模式
	get_tree().change_scene_to_file("res://scenes/game_mpsurvivor.tscn") 