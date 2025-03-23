extends CanvasLayer

@onready var steam_name_label: Label = $PanelContainer/VBoxContainer/SteamNameLabel
@onready var latency_label: Label = $PanelContainer/VBoxContainer/LatencyLabel
@onready var min_latency_label: Label = $PanelContainer/VBoxContainer/MinLatencyLabel
@onready var max_latency_label: Label = $PanelContainer/VBoxContainer/MaxLatencyLabel
@onready var latency_indicator: Panel = $PanelContainer/VBoxContainer/LatencyIndicator
@onready var timer: Timer = $UpdateTimer

var latency_history = []
var max_history_size = 10
var min_latency = 9999
var max_latency = 0
var latency_reset_timer = 0
var reset_interval = 5.0  # 每5秒重置一次最大值

# 延迟状态颜色
var good_color: Color = Color(0, 0.8, 0, 1)      # 绿色 (0-50ms)
var ok_color: Color = Color(0.9, 0.9, 0, 1)      # 黄色 (50-100ms)
var bad_color: Color = Color(1, 0.5, 0, 1)       # 橙色 (100-150ms)
var terrible_color: Color = Color(1, 0, 0, 1)    # 红色 (150ms+)

# 当前指示器颜色
var current_indicator_color: Color = good_color

func _ready():
	# 设置更高的更新频率
	timer.wait_time = 0.1
	
	# 连接现有的计时器
	timer.timeout.connect(_update_info)
	
	# 初始更新
	_update_info()
	
	# 设置初始颜色
	latency_indicator.get_theme_stylebox("panel").bg_color = good_color
	current_indicator_color = good_color

func _process(delta):
	# 在进程中更新延迟信息，使其更实时
	if NetworkTime.is_initial_sync_done():
		_update_latency()
	
	# 定期重置最大延迟值，使显示更加实时反映当前网络状况
	latency_reset_timer += delta
	if latency_reset_timer >= reset_interval:
		latency_reset_timer = 0
		# 不完全重置，而是逐渐衰减最大值
		max_latency = max(min_latency, max_latency * 0.8)

func _update_info():
	# 更新Steam名称
	steam_name_label.text = "玩家: %s" % SteamManager.steam_username

func _update_latency():
	if NetworkTime.is_initial_sync_done():
		var current_latency = NetworkTime.remote_rtt * 500  # 转换为毫秒并除以2（单向延迟）
		
		# 更新历史记录
		latency_history.append(current_latency)
		if latency_history.size() > max_history_size:
			latency_history.pop_front()
		
		# 计算平滑延迟值
		var smooth_latency = 0
		for latency in latency_history:
			smooth_latency += latency
		smooth_latency /= latency_history.size()
		
		# 更新最小/最大延迟
		min_latency = min(min_latency, current_latency)
		max_latency = max(max_latency, current_latency)
		
		# 更新UI
		latency_label.text = "延迟: %d ms" % smooth_latency
		min_latency_label.text = "最小延迟: %d ms" % min_latency
		max_latency_label.text = "最大延迟: %d ms" % max_latency
		
		# 更新延迟指示器
		_update_latency_indicator(smooth_latency)
	else:
		latency_label.text = "延迟: 正在计算..."
		min_latency_label.text = "最小延迟: --"
		max_latency_label.text = "最大延迟: --"

func _update_latency_indicator(latency):
	# 确定目标颜色
	var target_color
	if latency < 50:
		target_color = good_color
	elif latency < 100:
		target_color = ok_color
	elif latency < 150:
		target_color = bad_color
	else:
		target_color = terrible_color
	
	# 如果颜色需要变化
	if target_color != current_indicator_color:
		# 创建一个tween来平滑过渡颜色
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		
		# 获取当前样式盒并克隆它
		var style_box = latency_indicator.get_theme_stylebox("panel").duplicate()
		latency_indicator.add_theme_stylebox_override("panel", style_box)
		
		# 从当前颜色渐变到目标颜色
		tween.tween_property(style_box, "bg_color", target_color, 0.3)
		
		# 更新当前颜色
		current_indicator_color = target_color 