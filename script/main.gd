extends Node2D

@export var player_scene: PackedScene = preload("res://prefab/player.tscn")
@export var MIN_PLAYERS_TO_START: int = 2

var game_started = false
var port = 9421

func _ready():
	$MultiplayerSpawner.spawn_path = $players.get_path()
	$MultiplayerSpawner.spawn_function = _spawn_player
	
	# 检测命令行参数或无头模式
	if "--server" in OS.get_cmdline_args() or DisplayServer.get_name() == "headless":
		# 延迟调用以确保所有节点初始化完成
		call_deferred("start_dedicated_server_no_ui")
	else:
		setup_ui()

func start_dedicated_server_no_ui():
	start_dedicated_server()
	# 隐藏 UI 容器
	var ui = get_node_or_null("CanvasLayer")
	if ui: ui.hide()

func setup_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "LobbyUI"
	add_child(canvas)
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	canvas.add_child(vbox)
	
	var server_btn = Button.new()
	server_btn.text = "启动专用服务器 (Server Only)"
	server_btn.pressed.connect(start_dedicated_server)
	vbox.add_child(server_btn)
	
	var host_btn = Button.new()
	host_btn.text = "启动主机 (Host + Player)"
	host_btn.pressed.connect(host_game)
	vbox.add_child(host_btn)
	
	var join_btn = Button.new()
	join_btn.text = "加入房间 (Join)"
	join_btn.pressed.connect(join_game)
	vbox.add_child(join_btn)
	
	# 用于显示状态的标签
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "等待操作..."
	vbox.add_child(status_label)

func update_status(msg):
	var label = get_node_or_null("CanvasLayer/VBoxContainer/StatusLabel")
	if label: label.text = msg
	print(msg)

func start_dedicated_server():
	create_multiplayer_interface(true)
	update_status("专用服务器已启动，等待玩家...")

func host_game():
	create_multiplayer_interface(false)
	add_player(1) # 主机模式给自己加个玩家
	update_status("主机已启动")

func join_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client("47.112.2.183", port)
	if error != OK:
		update_status("无法连接: " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	update_status("正在连接服务器...")

func create_multiplayer_interface(is_dedicated):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error != OK:
		update_status("创建服务器失败: " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id):
	update_status("新玩家连接: " + str(id))
	add_player(id)
	check_game_start()

func _on_peer_disconnected(id):
	update_status("玩家断开: " + str(id))
	remove_player(id)

func add_player(id):
	if not multiplayer.is_server(): return
	var spawn_pos = Vector2(100 + randf() * 200, 100 + randf() * 200)
	$MultiplayerSpawner.spawn({"id": id, "pos": spawn_pos})
	
	# 隐藏大厅 UI
	var lobby_ui = get_node_or_null("LobbyUI")
	if lobby_ui:
		lobby_ui.hide()
		print("已为客机隐藏 UI")

func _spawn_player(data):
	var player = player_scene.instantiate()
	player.name = str(data.id)
	player.position = data.pos
	return player

func remove_player(id):
	var player = $players.get_node_or_null(str(id))
	if player: player.queue_free()

func check_game_start():
	# 计算当前玩家数量（排除服务器自身，如果服务器是 1 号位且没生成玩家的话）
	var current_players = $players.get_child_count()
	update_status("当前玩家: %d/%d" % [current_players, MIN_PLAYERS_TO_START])
	
	if current_players >= MIN_PLAYERS_TO_START:
		start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game():
	update_status("游戏开始！")
		
	# 这里可以放置其他初始化逻辑，比如锁定鼠标、切换场景等
	# 隐藏大厅 UI
	var lobby_ui = get_node_or_null("LobbyUI")
	if lobby_ui:
		lobby_ui.hide()
		print("已为客机隐藏 UI")
