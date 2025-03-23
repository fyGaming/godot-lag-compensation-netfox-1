extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"

# 普通模式的多人玩家场景
var normal_multiplayer_scene = preload("res://scenes/multiplayer_player.tscn")

# 吸血鬼模式的玩家场景
var vampire_killer_scene = preload("res://scenes/mpsurvivor/killer.tscn")
var vampire_survivor_scene = preload("res://scenes/mpsurvivor/survivor.tscn")

var multiplayer_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var _players_spawn_node
var game_mode = 0  # 0=普通模式，1=吸血鬼模式

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
	
	var player_to_add
	
	# 根据游戏模式选择不同的玩家场景
	if game_mode == 1: # 吸血鬼模式
		if multiplayer.is_server() and id == 1: # 主机作为杀手
			player_to_add = vampire_killer_scene.instantiate()
		else: # 客户端作为幸存者
			player_to_add = vampire_survivor_scene.instantiate()
	else: # 普通模式
		player_to_add = normal_multiplayer_scene.instantiate()
	
	player_to_add.player_id = id
	player_to_add.name = str(id)
	
	_players_spawn_node.add_child(player_to_add, true)
	
func _del_player(id: int):
	print("Player %s left the game!" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()

	
	
	
	
	
	
	
	
