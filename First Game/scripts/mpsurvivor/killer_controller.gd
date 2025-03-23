extends Node

const SPEED = 300.0

@export var character_body: CharacterBody2D
@export var input: PlayerInput
@export var can_move: bool = true

var last_survivor_hit_times = {}

func _ready():
	assert(character_body, "必须连接到CharacterBody2D节点")

func _rollback_tick(delta, tick, is_fresh):
	if can_move:
		_apply_movement_from_input(delta)

func _apply_movement_from_input(delta):
	# 获取输入方向
	var direction = Vector2.ZERO
	
	# 从输入系统获取方向
	direction = input.input_direction
	
	# 应用移动
	character_body.velocity = direction * SPEED * NetworkTime.physics_factor
	character_body.move_and_slide()
	character_body.velocity /= NetworkTime.physics_factor

# 处理与幸存者的碰撞
func handle_survivor_collision(survivor_body):
	if not multiplayer.is_server() or not can_move:
		return
	
	var survivor_id = survivor_body.player_id
	
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
	make_survivor_flash(survivor_id)

# 让幸存者闪烁表示受伤
@rpc("authority", "call_local")
func make_survivor_flash(survivor_id):
	var survivor_node = get_node("/root/GameMPSurvivor/Players/" + str(survivor_id))
	if survivor_node and survivor_node.is_in_group("survivor"):
		survivor_node.flash() 