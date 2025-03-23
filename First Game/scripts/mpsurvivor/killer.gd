extends CharacterBody2D

const SPEED = 300.0

@onready var rollback_synchronizer = $RollbackSynchronizer

@export var input: PlayerInput
@export var can_move: bool = true

var last_survivor_hit_times = {}

@export var player_id := 1:
	set(id):
		player_id = id
		input.set_multiplayer_authority(id)

func _ready():
	if multiplayer.get_unique_id() == player_id:
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false
	
	# 设置用户名标签
	$Username.text = "Killer (%d)" % player_id
	
	rollback_synchronizer.process_settings()

func _rollback_tick(delta, tick, is_fresh):
	if can_move:
		_apply_movement_from_input(delta)

func _apply_movement_from_input(delta):
	# 获取输入方向
	var direction = Vector2.ZERO
	
	# 从输入系统获取方向（现在是Vector2）
	direction = input.input_direction
	
	# 应用移动
	velocity = direction * SPEED * NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

# 当检测区域与幸存者碰撞时调用
func _on_detection_area_body_entered(body):
	if not multiplayer.is_server() or not can_move:
		return
	
	# 检查碰撞的是否是幸存者
	if body.is_in_group("survivor"):
		var survivor_id = body.player_id
		
		# 检查幸存者是否在冷却时间内（无敌状态）
		var current_time = Time.get_ticks_msec()
		if last_survivor_hit_times.has(survivor_id):
			if current_time - last_survivor_hit_times[survivor_id] < 1000:  # 1秒冷却
				return
		
		# 更新上次击中时间
		last_survivor_hit_times[survivor_id] = current_time
		
		# 造成伤害
		get_node("/root/GameMPSurvivor/GameManager").survivor_damaged.rpc(survivor_id, 10)
		
		# 创建一个Tween动画，使幸存者闪烁表示受伤
		_make_survivor_flash.rpc(survivor_id)

@rpc("authority", "call_local")
func _make_survivor_flash(survivor_id):
	var survivor_node = get_node("/root/GameMPSurvivor/Players/" + str(survivor_id))
	if survivor_node and survivor_node.is_in_group("survivor"):
		var tween = create_tween()
		tween.tween_property(survivor_node.get_node("Circle"), "modulate", Color(1, 0, 0, 0.5), 0.1)
		tween.tween_property(survivor_node.get_node("Circle"), "modulate", Color(1, 1, 1, 1), 0.1) 
