extends CharacterBody2D

const SPEED = 250.0  # 幸存者的移动速度
@export var health = 50  # 幸存者的总血量
@export var can_move = true  # 游戏开始即可移动

signal health_changed(current_health)
signal survivor_died()

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

# 当被杀手撞击时掉血
func take_damage(amount):
	health -= amount
	health_changed.emit(health)
	
	if health <= 0:
		survivor_died.emit()
		can_move = false  # 死亡时不能移动
		
	# 显示受伤效果
	modulate = Color(1, 0, 0, 1)  # 变红
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)  # 恢复正常颜色
	
# 处理健康值变化
func _on_health_changed(new_health):
	# 更新健康值条
	$HealthBar.value = new_health 
