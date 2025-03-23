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
	
func _del_player(id: int):
	print("Player %s left the game!" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()

	
	
	
	
	
	
	
	
