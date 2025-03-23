extends Node

# 用于多人游戏的管理脚本

# 信号
signal game_started
signal game_ended(winner)

# 游戏状态
var game_active = false
var killer_player_id = 1  # 默认房主是Killer
const DAMAGE_AMOUNT = 10  # 杀手造成的伤害

# 场景引用
@onready var arena = $Arena
@onready var start_button = $UI/HostPanel/StartGameButton
@onready var host_panel = $UI/HostPanel
@onready var connection_panel = $UI/ConnectionPanel
@onready var address_input = $UI/ConnectionPanel/VBoxContainer/AddressInput

func _ready():
	# 设置多人游戏事件处理
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# 初始UI状态
	host_panel.visible = false  # 初始隐藏主机面板，等待连接

# 当点击创建游戏按钮
func _on_host_button_pressed():
	# 创建服务器
	var network_peer = ENetMultiplayerPeer.new()
	network_peer.create_server(4433)
	multiplayer.multiplayer_peer = network_peer
	
	print("服务器已启动")
	
	# 隐藏连接面板，显示主机控制面板
	connection_panel.visible = false
	host_panel.visible = true
	
	# 房主自动生成Killer
	spawn_player(1)

# 当点击加入游戏按钮
func _on_join_button_pressed():
	if address_input.text.is_empty():
		print("请输入服务器地址")
		return
	
	# 连接到服务器
	var network_peer = ENetMultiplayerPeer.new()
	network_peer.create_client(address_input.text, 4433)
	multiplayer.multiplayer_peer = network_peer
	
	print("正在连接到: ", address_input.text)
	
	# 隐藏连接面板
	connection_panel.visible = false

# 设置网络
func _setup_network():
	# 获取多人玩家管理器
	var network_peer = ENetMultiplayerPeer.new()
	
	if OS.has_environment("SERVER"):
		# 如果是服务器模式，创建服务器
		var port = 4433
		if OS.has_environment("PORT"):
			port = int(OS.get_environment("PORT"))
		
		network_peer.create_server(port)
		multiplayer.multiplayer_peer = network_peer
		print("服务器启动在端口: ", port)
	else:
		# 客户端模式，尝试连接到主机
		var args = OS.get_cmdline_args()
		# 检查是否有join参数
		if "--join" in args:
			var join_index = args.find("--join")
			if join_index != -1 and join_index < args.size() - 1:
				var host = args[join_index + 1]
				network_peer.create_client(host, 4433)
				multiplayer.multiplayer_peer = network_peer
				print("连接到: ", host)

# 当玩家连接时分配角色
func _on_peer_connected(id):
	print("玩家连接: ", id)
	# 房主是Killer，其他人是Survivor
	if multiplayer.is_server():
		spawn_player(id)

# 当玩家断开连接时处理清理
func _on_peer_disconnected(id):
	print("玩家断开连接: ", id)
	if arena.has_node(str(id)):
		arena.get_node(str(id)).queue_free()

# 根据ID生成对应的角色
func spawn_player(id):
	var player_scene
	var player_instance
	
	# 房主（服务器）是Killer，其他玩家是Survivor
	if id == 1:
		player_scene = preload("res://scenes/MPSurvivor/killer.tscn")
		player_instance = player_scene.instantiate()
		player_instance.name = str(id)
		arena.add_child(player_instance)
		# 连接信号
		player_instance.survivor_hit.connect(_on_killer_hit_survivor)
	else:
		player_scene = preload("res://scenes/MPSurvivor/survivor.tscn")
		player_instance = player_scene.instantiate()
		player_instance.name = str(id)
		arena.add_child(player_instance)
		# 连接信号
		player_instance.survivor_died.connect(_on_survivor_died.bind(player_instance))

# 当杀手撞到幸存者时
func _on_killer_hit_survivor(survivor):
	if game_active and multiplayer.is_server():
		# 服务器执行伤害计算
		survivor.take_damage(DAMAGE_AMOUNT)

# 当幸存者死亡时
func _on_survivor_died(survivor):
	if game_active and multiplayer.is_server():
		# 从游戏中移除幸存者
		print("幸存者死亡: ", survivor.name)
		
		# 检查游戏是否结束
		var survivors_alive = false
		
		for child in arena.get_children():
			if child.is_in_group("survivor") and child.health > 0:
				survivors_alive = true
				break
		
		if not survivors_alive:
			# 所有幸存者都死亡，游戏结束
			end_game("killer")

# 开始游戏（只能由房主调用）
func start_game():
	if not multiplayer.is_server():
		return
		
	game_active = true
	start_button.disabled = true
	
	# 通知所有客户端游戏开始
	rpc("game_started_rpc")
	
	# 获取Killer节点并启动游戏
	var killer = arena.get_node_or_null(str(killer_player_id))
	if killer:
		killer.start_game()
		print("游戏开始，杀手5秒后可以移动")

# RPC函数，在所有客户端执行游戏开始逻辑
@rpc("authority", "call_local")
func game_started_rpc():
	game_active = true
	game_started.emit()
	print("游戏已开始")
	
	# 因为房主是服务器并且是Killer，所以不需要再次调用start_game

# 结束游戏
func end_game(winner):
	if not multiplayer.is_server():
		return
		
	game_active = false
	start_button.disabled = false
	
	# 通知所有客户端游戏结束
	rpc("game_ended_rpc", winner)

# RPC函数，在所有客户端执行游戏结束逻辑
@rpc("authority", "call_local")
func game_ended_rpc(winner):
	game_active = false
	game_ended.emit(winner)
	
	# 显示游戏结束UI
	print("游戏结束，胜利者: ", winner) 
