extends Node

# 网络模块引用
var _network = null

# 获取网络模块
func get_network():
	if _network == null:
		# 尝试在不同可能的路径上查找网络模块
		_network = get_node_or_null("/root/GameMPSurvivor/%NetworkManager")
		if _network == null:
			_network = get_node_or_null("/root/%NetworkManager")
	return _network 
