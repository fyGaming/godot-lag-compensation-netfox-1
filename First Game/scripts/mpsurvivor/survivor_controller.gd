extends Node

const SPEED = 250.0

@export var character_body: CharacterBody2D
@export var input: PlayerInput
@export var health: int = 50:
	set(value):
		health = value
		if character_body and character_body.has_node("HealthBar"):
			character_body.get_node("HealthBar").value = (float(health) / 50.0) * 100.0

func _ready():
	if not character_body:
		push_error("幸存者控制器必须连接到CharacterBody2D节点")
		return
	
	# 初始化健康条
	if character_body.has_node("HealthBar"):
		character_body.get_node("HealthBar").value = (float(health) / 50.0) * 100.0

func _rollback_tick(delta, tick, is_fresh):
	_apply_movement_from_input(delta)

func _apply_movement_from_input(delta):
	# 从输入系统获取方向（Vector2）
	var direction = input.input_direction
	
	# 应用移动
	character_body.velocity = direction * SPEED * NetworkTime.physics_factor
	character_body.move_and_slide()
	character_body.velocity /= NetworkTime.physics_factor

# 显示受伤动画
func show_damage():
	if character_body and character_body.has_node("Circle"):
		var tween = create_tween()
		tween.tween_property(character_body.get_node("Circle"), "modulate", Color(1, 0, 0, 0.5), 0.1)
		tween.tween_property(character_body.get_node("Circle"), "modulate", Color(1, 1, 1, 1), 0.1) 