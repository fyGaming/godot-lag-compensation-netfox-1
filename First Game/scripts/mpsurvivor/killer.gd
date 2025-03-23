extends CharacterBody2D

@export var player_id := 1:
	set(id):
		player_id = id
		if input:
			input.set_multiplayer_authority(id)

var username = ""

@onready var input = $Input
@onready var username_label = $Username
@onready var controller = $Controller

func _ready():
	if multiplayer.get_unique_id() == player_id:
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false
	
	# 设置默认用户名标签
	username_label.text = "Killer"

# 网络事件函数
func _network_spawn(data):
	player_id = data.player_id
	if player_id == MultiplayerManager.network_unique_id:
		username = MultiplayerManager.username
	else:
		username = MultiplayerManager.get_username_by_id(player_id)
	
	username_label.text = username

# 当检测区域与幸存者碰撞时调用
func _on_detection_area_body_entered(body):
	if body.is_in_group("survivor"):
		controller.handle_survivor_collision(body) 
