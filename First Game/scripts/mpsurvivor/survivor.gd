extends CharacterBody2D

const SPEED = 250.0

@onready var rollback_synchronizer = $RollbackSynchronizer
@onready var health_bar = $HealthBar

@export var input: PlayerInput
@export var health: int = 50:
	set(value):
		health = value
		if health_bar:
			health_bar.value = (float(health) / 50.0) * 100.0

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
	$Username.text = "Survivor (%d)" % player_id
	
	# 初始化健康条
	health_bar.value = (float(health) / 50.0) * 100.0
	
	rollback_synchronizer.process_settings()

func _rollback_tick(delta, tick, is_fresh):
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

# 显示受伤动画
func show_damage():
	var tween = create_tween()
	tween.tween_property($Circle, "modulate", Color(1, 0, 0, 0.5), 0.1)
	tween.tween_property($Circle, "modulate", Color(1, 1, 1, 1), 0.1) 
