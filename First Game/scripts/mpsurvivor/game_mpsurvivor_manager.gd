extends Node

@onready var start_game_button = $StartGameButton
@onready var countdown_label = $CountdownLabel
@onready var countdown_timer = $CountdownTimer

var killer_scene = load("res://scenes/mpsurvivor/killer.tscn")
var survivor_scene = load("res://scenes/mpsurvivor/survivor.tscn")
var game_started = false
var players_info = {}

func _ready():
	if OS.has_feature("dedicated_server"):
		print("启动专用服务器...")
		%NetworkManager.become_host(true)
	
	# 连接网络管理器的信号
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _on_player_connected(peer_id):
	print("玩家 %d 已连接" % peer_id)
	
	if multiplayer.is_server():
		players_info[peer_id] = { "role": "survivor", "health": 50 }
		
		# 如果房间内玩家数量>=2，显示开始游戏按钮
		_update_start_game_button()
	
	# 更新玩家信息UI
	_update_player_info_ui()

func _on_player_disconnected(peer_id):
	print("玩家 %d 已断开连接" % peer_id)
	
	if multiplayer.is_server():
		players_info.erase(peer_id)
		
		# 更新开始游戏按钮状态
		_update_start_game_button()
	
	# 更新玩家信息UI
	_update_player_info_ui()

func _update_player_info_ui():
	# 显示玩家信息UI
	$"../PlayerInfoUI".visible = true
	
	# 更新玩家列表
	var player_list = $"../PlayerInfoUI/PanelContainer/VBoxContainer/PlayerList"
	for child in player_list.get_children():
		child.queue_free()
	
	# 从玩家节点收集信息
	var player_ids = []
	var players_node = $"../Players"
	
	# 获取所有已连接的玩家ID
	for player in players_node.get_children():
		player_ids.append(player.player_id)
	
	player_ids.sort()
	
	for id in player_ids:
		var label = Label.new()
		var role_text = ""
		var player_node = players_node.get_node_or_null(str(id))
		
		if id == multiplayer.get_unique_id():
			role_text = "（你）"
		
		if player_node:
			if player_node.is_in_group("killer"):
				role_text += " [Killer]"
			elif player_node.is_in_group("survivor"):
				role_text += " [Survivor]"
		
		label.text = "玩家 %d %s" % [id, role_text]
		player_list.add_child(label)

func become_host():
	print("成为主机")
	_remove_single_player()
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%NetworkManager.become_host()
	
	# 主机是Killer
	players_info[multiplayer.get_unique_id()] = { "role": "killer", "ready": false }
	
	# 更新玩家信息UI
	_update_player_info_ui()

func join_as_client():
	print("加入为客户端")
	join_lobby()

func use_steam():
	print("使用Steam!")
	%MultiplayerHUD.hide()
	%SteamHUD.show()
	SteamManager.initialize_steam()
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	%NetworkManager.active_network_type = %NetworkManager.MULTIPLAYER_NETWORK_TYPE.STEAM

func list_steam_lobbies():
	print("列出Steam大厅")
	%NetworkManager.list_lobbies()

func join_lobby(lobby_id = 0):
	print("加入大厅 %s" % lobby_id)
	_remove_single_player()
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%NetworkManager.join_as_client(lobby_id)
	
	# 客户端是Survivor
	players_info[multiplayer.get_unique_id()] = { "role": "survivor", "health": 50, "ready": false }
	
	# 更新玩家信息UI
	_update_player_info_ui()

func _on_lobby_match_list(lobbies: Array):
	print("收到大厅列表")
	
	for lobby_child in $"../SteamHUD/Panel/Lobbies/VBoxContainer".get_children():
		lobby_child.queue_free()
		
	for lobby in lobbies:
		var lobby_name: String = Steam.getLobbyData(lobby, "name")
		
		if lobby_name != "":
			var lobby_mode: String = Steam.getLobbyData(lobby, "mode")
			
			var lobby_button: Button = Button.new()
			lobby_button.set_text(lobby_name + " | " + lobby_mode)
			lobby_button.set_size(Vector2(100, 30))
			lobby_button.add_theme_font_size_override("font_size", 8)
			
			var fv = FontVariation.new()
			fv.set_base_font(load("res://assets/fonts/PixelOperator8.ttf"))
			lobby_button.add_theme_font_override("font", fv)
			lobby_button.set_name("lobby_%s" % lobby)
			lobby_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lobby_button.connect("pressed", Callable(self, "join_lobby").bind(lobby))
			
			$"../SteamHUD/Panel/Lobbies/VBoxContainer".add_child(lobby_button)

func _remove_single_player():
	print("移除单人玩家")
	var player_to_remove = get_tree().get_current_scene().get_node_or_null("Player")
	if player_to_remove:
		player_to_remove.queue_free()

func _on_start_game_button_pressed():
	if !game_started and multiplayer.is_server():
		# 只有服务器可以启动游戏
		_start_game.rpc()

@rpc("authority", "call_local")
func _start_game():
	print("游戏开始!")
	game_started = true
	start_game_button.visible = false
	countdown_label.visible = true
	countdown_timer.start()
	
	# 不再在这里生成玩家，由网络模块处理

func _on_countdown_timer_timeout():
	# 倒计时结束，让Killer可以移动
	_enable_killer_movement.rpc()
	countdown_label.visible = false

@rpc("authority", "call_local")
func _enable_killer_movement():
	# 找到所有Killer并启用移动
	for player in $"../Players".get_children():
		if player.is_in_group("killer"):
			player.can_move = true

# 幸存者受伤的处理
@rpc("authority", "call_local")
func survivor_damaged(survivor_id, damage):
	if multiplayer.is_server():
		var survivor_node = $"../Players".get_node_or_null(str(survivor_id))
		if survivor_node and survivor_node.is_in_group("survivor"):
			survivor_node.health -= damage
			if survivor_node.health <= 0:
				_survivor_died.rpc(survivor_id)
			else:
				_update_survivor_health.rpc(survivor_id, survivor_node.health)

@rpc("authority", "call_local")
func _update_survivor_health(survivor_id, new_health):
	var survivor_node = $"../Players".get_node_or_null(str(survivor_id))
	if survivor_node and survivor_node.is_in_group("survivor"):
		survivor_node.health = new_health

@rpc("authority", "call_local")
func _survivor_died(survivor_id):
	print("幸存者 %d 死亡!" % survivor_id)
	# 可以在这里添加幸存者死亡的相关逻辑

# 根据房间内玩家数量更新开始游戏按钮
func _update_start_game_button():
	if multiplayer.is_server() and !game_started:
		# 检查玩家数量 >=2 时可以开始游戏
		var player_count = $"../Players".get_child_count()
		start_game_button.visible = (player_count >= 2)
	else:
		start_game_button.visible = false
