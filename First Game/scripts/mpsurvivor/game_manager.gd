extends Node

signal game_over
signal killer_won
signal survivors_won

var survivors_remaining = 0

@rpc("authority", "call_local")
func survivor_damaged(survivor_id, damage_amount):
	var survivor_node = get_node("/root/GameMPSurvivor/Players/" + str(survivor_id))
	if survivor_node and survivor_node.is_in_group("survivor"):
		var controller = survivor_node.get_node("Controller")
		# 减少生命值
		controller.health -= damage_amount
		# 触发显示伤害效果
		survivor_node.flash()
		
		# 检查是否游戏结束
		if controller.health <= 0:
			_check_game_state()

# 检查游戏状态
func _check_game_state():
	# 计算剩余的幸存者
	survivors_remaining = 0
	var players = get_node("/root/GameMPSurvivor/Players").get_children()
	for player in players:
		if player.is_in_group("survivor") and player.get_node("Controller").health > 0:
			survivors_remaining += 1
	
	# 判断游戏是否结束
	if survivors_remaining == 0:
		# 杀手获胜
		killer_won.emit()
		game_over.emit() 