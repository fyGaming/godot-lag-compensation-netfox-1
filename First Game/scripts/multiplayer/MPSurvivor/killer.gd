extends CharacterBody2D

const SPEED = 300.0  # 杀手的移动速度
@export var can_move = false  # 游戏开始时无法移动

signal survivor_hit(survivor)

# 获取输入方向并移动
func _physics_process(delta):
	if not can_move:
		return
		
	# 获取上下左右的输入
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	
	# 归一化向量以保持斜向移动速度一致
	if direction.length() > 0:
		direction = direction.normalized()
	
	# 设置速度并移动
	velocity = direction * SPEED
	move_and_slide()

func _on_hitbox_body_entered(body):
	# 检查是否撞到幸存者
	if body.is_in_group("survivor") and can_move:
		survivor_hit.emit(body)

func start_game():
	# 5秒后开始移动
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func(): can_move = true)
	timer.start() 
