extends CanvasLayer

@onready var steam_name_label: Label = $PanelContainer/VBoxContainer/SteamNameLabel
@onready var latency_label: Label = $PanelContainer/VBoxContainer/LatencyLabel
@onready var timer: Timer = $UpdateTimer

func _ready():
	# 连接现有的计时器
	timer.timeout.connect(_update_info)
	
	# 初始更新
	_update_info()

func _update_info():
	# 更新Steam名称
	steam_name_label.text = "玩家: %s" % SteamManager.steam_username
	
	# 更新延迟信息
	if NetworkTime.is_initial_sync_done():
		var latency_ms = NetworkTime.remote_rtt * 500  # 转换为毫秒并除以2（单向延迟）
		latency_label.text = "延迟: %d ms" % latency_ms
	else:
		latency_label.text = "延迟: 正在计算..." 