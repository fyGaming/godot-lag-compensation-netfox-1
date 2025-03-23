class_name PlayerInput extends Node

var input_direction = Vector2.ZERO
var input_jump = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkTime.before_tick_loop.connect(_gather)
	
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	input_direction = Vector2.ZERO

func _gather():
	if not is_multiplayer_authority():
		return
	
	# 获取完整的2D方向输入 (WASD/方向键)
	var x_dir = Input.get_axis("move_left", "move_right")
	var y_dir = Input.get_axis("ui_up", "ui_down")
	input_direction = Vector2(x_dir, y_dir)
	
	# 归一化向量，保证对角线移动速度一致
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()

func _process(delta):
	input_jump = Input.get_action_strength("jump")
