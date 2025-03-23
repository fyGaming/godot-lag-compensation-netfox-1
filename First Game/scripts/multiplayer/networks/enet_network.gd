extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"

var multiplayer_scene = preload("res://scenes/multiplayer_player.tscn")
var killer_scene = preload("res://scenes/mpsurvivor/killer.tscn")
var survivor_scene = preload("res://scenes/mpsurvivor/survivor.tscn")
var multiplayer_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var _players_spawn_node

func become_host():
	print("Starting host!")
	
	multiplayer_peer.create_server(SERVER_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_del_player)

	if not OS.has_feature("dedicated_server"):
		_add_player_to_game(1)
	
func join_as_client(lobby_id):
	print("Player 2 joining")
	
	multiplayer_peer.create_client(SERVER_IP, SERVER_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# 客户端连接后主动请求同步UI
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _add_player_to_game(id: int):
	print("Player %s joined the game!" % id)
	
	# 检查当前场景类型决定生成什么角色
	var current_scene = get_tree().get_current_scene()
	var scene_name = current_scene.name
	
	var player_to_add
	
	if scene_name == "GameMPSurvivor":
		# 在吸血鬼模式中
		if multiplayer.is_server() and id == multiplayer.get_unique_id():
			# 主机自己是Killer
			player_to_add = killer_scene.instantiate()
			# 开始时禁用Killer移动，倒计时结束后启用
			player_to_add.can_move = false
		else:
			# 其他玩家都是Survivor
			player_to_add = survivor_scene.instantiate()
			player_to_add.health = 50
	else:
		# 普通模式使用默认角色
		player_to_add = multiplayer_scene.instantiate()
	
	player_to_add.player_id = id
	player_to_add.name = str(id)
	
	_players_spawn_node.add_child(player_to_add, true)
	
	# 通知游戏管理器更新UI
	if scene_name == "GameMPSurvivor":
		var game_manager = get_tree().get_current_scene().get_node_or_null("%GameManager")
		if game_manager:
			game_manager._update_player_info_ui()
			game_manager._update_start_game_button()
			
			# 服务器通知所有客户端更新UI
			if multiplayer.is_server():
				_sync_all_clients_ui.rpc()

func _on_connected_to_server():
	print("已连接到服务器!")
	# 客户端连接后请求同步玩家信息
	_request_sync_from_server.rpc_id(1)

func _on_server_disconnected():
	print("与服务器断开连接!")

@rpc("any_peer", "call_local")
func _request_sync_from_server():
	print("收到来自客户端 " + str(multiplayer.get_remote_sender_id()) + " 的同步请求")
	if multiplayer.is_server():
		print("服务器正在处理同步请求...")
		# 服务器收到同步请求，通知所有客户端更新UI
		_sync_all_clients_ui.rpc()

@rpc("authority", "call_remote")
func _sync_all_clients_ui():
	# 强制所有客户端更新玩家信息UI
	print("执行客户端UI同步...")
	var game_manager = get_tree().get_current_scene().get_node_or_null("%GameManager")
	if game_manager and get_tree().get_current_scene().name == "GameMPSurvivor":
		game_manager._update_player_info_ui()
		print("客户端UI更新完成")
	else:
		print("客户端无法找到游戏管理器或不在正确的场景中")

func _del_player(id: int):
	print("Player %s left the game!" % id)
	
	# 从游戏中移除玩家
	var player_node = _players_spawn_node.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()
	
	var scene_name = get_tree().get_current_scene().name
	# 通知游戏管理器更新UI
	if scene_name == "GameMPSurvivor":
		var game_manager = get_tree().get_current_scene().get_node_or_null("%GameManager")
		if game_manager:
			game_manager._update_player_info_ui()
			game_manager._update_start_game_button()
			
			# 服务器通知所有客户端更新UI
			if multiplayer.is_server():
				_sync_all_clients_ui.rpc()

	
	
	
	
	
	
	
	
