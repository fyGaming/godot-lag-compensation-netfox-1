extends Node

#@onready var start_game_button = $"../StartGameButton"
@onready var start_game_button: Button = %StartGameButton

#@onready var countdown_label = $"../CountdownLabel"sa
#@onready var countdown_timer = $"../CountdownTimer"
@onready var countdown_label: Label = %CountdownLabel
@onready var countdown_timer: Timer = %CountdownTimer

# 玩家信息UI相关
@onready var player_info_container = $"../PlayerInfoUI/PanelContainer/VBoxContainer/PlayerList"
# 我们在运行时加载玩家信息项场景，而不是预加载
var player_info_item_scene = null
var killer_icon = preload("res://icon.svg") # 替换为真实的杀手图标路径
var survivor_icon = preload("res://icon.svg") # 替换为真实的幸存者图标路径

var killer_scene = load("res://scenes/mpsurvivor/killer.tscn")
var survivor_scene = load("res://scenes/mpsurvivor/survivor.tscn")
var game_started = false
var players_info = {}

# 使用静态函数获取全局模块
func get_global():
	return get_node("/root/Global")

func _ready():
	# 加载玩家信息项场景
	player_info_item_scene = load("res://scenes/player_info_item.tscn")
	if player_info_item_scene == null:
		push_error("无法加载玩家信息项场景")
	
	# 初始化全局模块引用
	if not "Global" in get_tree().root.get_children():
		var global_scene = load("res://scripts/multiplayer/global.tscn").instantiate()
		global_scene.name = "Global"
		get_tree().root.add_child(global_scene)
		
	# 显示玩家信息UI
	$"../PlayerInfoUI".visible = true
	
	# 更新UI
	_update_player_info_ui()
	_update_start_game_button()
	
	# 监听网络事件
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _on_player_connected(peer_id):
	print("玩家 %d 已连接" % peer_id)
	
	# 网络模块会负责生成玩家，这里只负责更新UI
	_update_player_info_ui()
	_update_start_game_button()

func _on_player_disconnected(peer_id):
	print("玩家 %d 已断开连接" % peer_id)
	
	# 网络模块会负责移除玩家，这里只负责更新UI
	_update_player_info_ui()
	_update_start_game_button()

func _update_player_info_ui():
	# 清空玩家信息面板
	for child in player_info_container.get_children():
		child.queue_free()
	
	# 获取网络模块的玩家生成节点
	var network = get_global().get_network()
	if not network:
		print("无法获取网络模块")
		return
	
	var players_node = network._players_spawn_node
	if not players_node:
		print("无法获取玩家节点")
		return
	
	# 遍历所有玩家节点，为每个玩家创建信息面板
	var player_count = 0
	for player_node in players_node.get_children():
		var player_id = player_node.player_id
		player_count += 1
		
		# 创建玩家信息面板
		var player_info_item = player_info_item_scene.instantiate()
		player_info_container.add_child(player_info_item)
		
		# 设置玩家信息
		var player_name = "玩家 " + str(player_id)
		if player_id == multiplayer.get_unique_id():
			player_name += " (你)"
		elif player_id == 1:
			player_name += " (主机)"
		
		player_info_item.get_node("PlayerName").text = player_name
		
		# 根据角色类型设置图标
		var icon_texture
		if player_node.is_in_group("killer"):
			icon_texture = killer_icon
		else:
			icon_texture = survivor_icon
		
		player_info_item.get_node("PlayerIcon").texture = icon_texture
	
	print("已更新玩家UI，当前玩家数: ", player_count)

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
		print("服务器启动游戏!")
		_start_game.rpc()

@rpc("authority", "call_local")
func _start_game():
	print("收到游戏开始信号!")
	game_started = true
	
	# 隐藏开始按钮
	if start_game_button:
		start_game_button.visible = false
	
	# 显示并启动倒计时
	if countdown_label:
		countdown_label.visible = true
		countdown_label.text = "5"
	
	if countdown_timer:
		countdown_timer.start()
	
	# 确认每个玩家的角色设置
	_sync_player_roles()

func _sync_player_roles():
	print("同步玩家角色信息")
	var network = get_global().get_network()
	if not network:
		print("无法获取网络模块")
		return
	
	var players_node = network._players_spawn_node
	if not players_node:
		print("无法获取玩家节点")
		return
	
	for player_node in players_node.get_children():
		var player_id = player_node.player_id
		
		# 确保玩家节点有正确的分组
		if player_id == 1:  # 主机是杀手
			if not player_node.is_in_group("killer"):
				player_node.add_to_group("killer")
				print("将玩家 " + str(player_id) + " 设置为杀手")
		else:  # 其他玩家是幸存者
			if not player_node.is_in_group("survivor"):
				player_node.add_to_group("survivor")
				print("将玩家 " + str(player_id) + " 设置为幸存者")
	
	# 更新UI以反映角色变化
	_update_player_info_ui()

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
	# 仅对服务器显示开始游戏按钮
	if not multiplayer.is_server():
		start_game_button.visible = false
		return
	
	# 对于服务器，总是显示开始按钮，但根据人数决定是否启用
	start_game_button.visible = true
	
	# 获取玩家数量
	var network = get_global().get_network()
	if not network:
		print("无法获取网络模块")
		return
		
	var players_node = network._players_spawn_node
	var player_count = players_node.get_child_count()
	
	# 只有当至少有两个玩家连接时才启用开始按钮
	start_game_button.disabled = player_count < 2
	
	print("更新开始游戏按钮，当前玩家数: ", player_count, ", 按钮状态: ", "启用" if not start_game_button.disabled else "禁用")
