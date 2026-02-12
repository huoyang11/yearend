extends Node2D

@export var player_scene: PackedScene = preload("res://prefab/player.tscn")
@export var MIN_PLAYERS_TO_START: int = 5

var game_started = false
var host = "47.112.2.183"
var port = 9421

# ===== 道具刷新系统 =====
const PICKUP_FIREWORK := 0
const PICKUP_CAMERA := 1
const RESPAWN_TIME := 15.0          # 道具被拾取后重新刷新的秒数
const CAMERA_UNLOCK_NEED := 10      # 解锁自由镜头所需镜片数

var _firework_icon_script = preload("res://script/ui/firework_pickup_icon.gd")
var _camera_icon_script = preload("res://script/ui/camera_pickup_icon.gd")
var _font: Font = preload("res://resource/font/SourceHanSansSC-Bold.otf")

var _spawn_positions: Array = []    # 所有刷新点坐标
var _active_pickups := {}           # spawn_index -> Area2D
var _pickups_initialized := false
var _pickup_container: Node2D

# HUD 引用
var _hud_firework_label: Label
var _hud_camera_label: Label
var _hud_hint_label: Label
var _hint_timer: Timer

# ===== 昼夜循环 =====
const DAY_NIGHT_CYCLE := 120.0   # 一轮 120 秒（2 分钟）
var _day_night_time := 0.0

# 关键帧时间点（归一化 0~1）和对应颜色
# 白天≈60s  过渡≈36s  夜晚≈24s  → 白天:夜晚 ≈ 2:1
var _cycle_t := [0.00, 0.40,  0.50,                  0.58,                  0.78,                  0.90,                  1.00]
var _cycle_c := [
	Color(1.0,  1.0,  1.0),    # 0.00  白天
	Color(1.0,  1.0,  0.95),   # 0.40  白天末尾，微微泛黄
	Color(1.0,  0.55, 0.25),   # 0.50  黄昏高峰（暖橙）
	Color(0.12, 0.12, 0.28),   # 0.58  入夜（深蓝）
	Color(0.12, 0.12, 0.28),   # 0.78  深夜持续
	Color(0.75, 0.6,  0.75),   # 0.90  黎明（淡紫粉）
	Color(1.0,  1.0,  1.0),    # 1.00  回到白天
]

func _ready():
	$MultiplayerSpawner.spawn_path = $world.get_path()
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
	var server_btn = $CanvasLayer/mainpage/server_btn
	server_btn.pressed.connect(start_dedicated_server)
	
	var host_btn = $CanvasLayer/mainpage/host_btn
	host_btn.pressed.connect(host_game)
	
	var join_btn = $CanvasLayer/mainpage/join_btn
	join_btn.pressed.connect(join_game)
	
	# 方向键使用 TouchScreenButton，在编辑器中设置 action 属性即可：
	#   up.action = "ui_up"    down.action = "ui_down"
	#   left.action = "ui_left"  right.action = "ui_right"
	# 无需代码连接，TouchScreenButton 会自动处理多点触控
	
	# switch 和 boom 用信号连接
	#var switch_btn = $CanvasLayer/playerctrl/switch
	#var boom = $CanvasLayer/playerctrl/boom
	#switch_btn.pressed.connect(_on_switch_pressed)
	#boom.pressed.connect(_on_boom_pressed)
	
	# 创建 HUD
	_create_hud()


# 获取本地玩家节点（authority 是自己的那个）
func _get_local_player():
	for c in $world.get_children():
		if c is CharacterBody2D and c.is_multiplayer_authority():
			return c
	return null

func _on_switch_pressed():
	var player = _get_local_player()
	if player:
		player._toggle_camera_mode()

func _on_boom_pressed():
	var player = _get_local_player()
	if not player:
		return
	if player.firework_count <= 0:
		_show_hint("烟花不足")
		return
	player.firework_count -= 1
	_update_hud()
	if player.has_node("FireworkItem"):
		var angle = randf_range(player.get_node("FireworkItem").angle_min, player.get_node("FireworkItem").angle_max)
		var color = player.get_node("FireworkItem")._get_color()
		var type = player.get_node("FireworkItem").explosion_type
		if type == -1:
			type = randi() % 10
		player.fire_firework.rpc(angle, color, type)

func update_status(msg):
	var label = $CanvasLayer/mainpage/status_label
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
	var peer = WebSocketMultiplayerPeer.new()
	var url = "ws://%s:%d" % [host, port]
	var err = peer.create_client(url)
	if err != OK:
		update_status("无法连接: " + str(err))
		return
	multiplayer.multiplayer_peer = peer
	update_status("正在连接服务器...")

func create_multiplayer_interface(_is_dedicated):
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err != OK:
		update_status("创建服务器失败: " + str(err))
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
	var spawn_pos = Vector2(150, 400)
	$MultiplayerSpawner.spawn({"id": id, "pos": spawn_pos})
	
	# 隐藏大厅 UI
	var lobby_ui = $CanvasLayer/mainpage
	if lobby_ui:
		lobby_ui.hide()
		print("已为客机隐藏 UI")
	player_join_game.rpc_id(id)

func _spawn_player(data):
	var player = player_scene.instantiate()
	player.name = str(data.id)
	player.position = data.pos
	# 初始化插值变量
	if "sync_position" in player:
		player.sync_position = data.pos
	return player

func _get_player_count() -> int:
	var n = 0
	for c in $world.get_children():
		if c is CharacterBody2D:
			n += 1
	return n

func remove_player(id):
	var player = $world.get_node_or_null(str(id))
	if player: player.queue_free()
	update_status("当前玩家: %d/%d" % [_get_player_count() - 1, MIN_PLAYERS_TO_START])

func check_game_start():
	var current_players = _get_player_count()
	update_status("当前玩家: %d/%d" % [current_players, MIN_PLAYERS_TO_START])
	
	#if current_players >= MIN_PLAYERS_TO_START:
	#	start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game():
	update_status("游戏开始！")
		
	# 这里可以放置其他初始化逻辑，比如锁定鼠标、切换场景等

@rpc("authority", "call_local", "reliable")
func player_join_game():
	# 隐藏大厅 UI
	var lobby_ui = $CanvasLayer/mainpage
	if lobby_ui:
		lobby_ui.hide()
		print("已为客机隐藏 UI")
	
	# 初始化道具刷新（每个客户端各自刷新，不需要服务器介入）
	_init_pickups()

# ===== 昼夜循环 =====
func _process(delta: float) -> void:
	_day_night_time += delta
	var t := fmod(_day_night_time, DAY_NIGHT_CYCLE) / DAY_NIGHT_CYCLE
	$CanvasModulate.color = _sample_cycle_color(t)

func _sample_cycle_color(t: float) -> Color:
	for i in range(_cycle_t.size() - 1):
		if t <= _cycle_t[i + 1]:
			var seg_len = _cycle_t[i + 1] - _cycle_t[i]
			var local_t = (t - _cycle_t[i]) / seg_len
			# smoothstep 让每段过渡的首尾更柔和
			local_t = local_t * local_t * (3.0 - 2.0 * local_t)
			return _cycle_c[i].lerp(_cycle_c[i + 1], local_t)
	return _cycle_c[0]

# ===== 道具刷新系统 =====
func _init_pickups():
	if _pickups_initialized:
		return
	_pickups_initialized = true
	
	# 创建道具容器
	_pickup_container = Node2D.new()
	_pickup_container.name = "pickups"
	add_child(_pickup_container)
	
	# 读取所有刷新点坐标，隐藏编辑器标记
	for child in $refresh_point.get_children():
		_spawn_positions.append(child.position)
		child.hide()
	
	# 在每个刷新点生成初始道具
	for i in _spawn_positions.size():
		_spawn_pickup_at(i)

func _spawn_pickup_at(index: int):
	if _active_pickups.has(index):
		return
	var pos = _spawn_positions[index]
	# 2/3 概率烟花，1/3 概率镜片
	var type = PICKUP_FIREWORK if randf() < 2.0 / 3.0 else PICKUP_CAMERA
	var pickup = _create_pickup_node(pos, type, index)
	_pickup_container.add_child(pickup)
	_active_pickups[index] = pickup

func _create_pickup_node(pos: Vector2, type: int, index: int) -> Area2D:
	var pickup = Area2D.new()
	pickup.position = pos
	pickup.collision_layer = 0
	pickup.collision_mask = 2   # 检测 player 所在的第 2 层
	pickup.set_meta("pickup_type", type)
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	pickup.add_child(col)
	
	# 自绘动画图标
	var icon: Node2D
	if type == PICKUP_FIREWORK:
		icon = _firework_icon_script.new()
	else:
		icon = _camera_icon_script.new()
	icon.name = "icon"
	pickup.add_child(icon)
	
	# 信号
	pickup.body_entered.connect(_on_pickup_body_entered.bind(pickup, index))
	
	return pickup

func _on_pickup_body_entered(body, pickup: Area2D, index: int):
	# 只有本地玩家（拥有权限的角色）才能拾取
	if not (body is CharacterBody2D and body.is_multiplayer_authority()):
		return
	
	var type = pickup.get_meta("pickup_type")
	if type == PICKUP_FIREWORK:
		body.firework_count += 10
	else:
		body.camera_fragments += 1
		if body.camera_fragments >= CAMERA_UNLOCK_NEED:
			body.free_camera_unlocked = true
	
	# 移除道具
	pickup.queue_free()
	_active_pickups.erase(index)
	
	# 定时重新刷新
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_spawn_pickup_at.bind(index))
	
	# 更新 HUD
	_update_hud()

# ===== HUD =====
func _create_hud():
	var hud = Control.new()
	hud.name = "hud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(hud)
	
	# 烟花数量标签
	_hud_firework_label = Label.new()
	_hud_firework_label.name = "firework_label"
	_hud_firework_label.position = Vector2(8, 6)
	_hud_firework_label.add_theme_font_override("font", _font)
	_hud_firework_label.add_theme_font_size_override("font_size", 14)
	_hud_firework_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_hud_firework_label.add_theme_constant_override("outline_size", 3)
	_hud_firework_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hud_firework_label.text = "烟花 x0"
	hud.add_child(_hud_firework_label)
	
	# 镜片 / 自由镜头进度标签
	_hud_camera_label = Label.new()
	_hud_camera_label.name = "camera_label"
	_hud_camera_label.position = Vector2(8, 26)
	_hud_camera_label.add_theme_font_override("font", _font)
	_hud_camera_label.add_theme_font_size_override("font_size", 14)
	_hud_camera_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	_hud_camera_label.add_theme_constant_override("outline_size", 3)
	_hud_camera_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hud_camera_label.text = "镜片 0/%d" % CAMERA_UNLOCK_NEED
	hud.add_child(_hud_camera_label)
	
	# 提示标签（居中偏上，临时显示“烟花不足”“镜片不足”等）
	_hud_hint_label = Label.new()
	_hud_hint_label.name = "hint_label"
	_hud_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hud_hint_label.add_theme_font_override("font", _font)
	_hud_hint_label.add_theme_font_size_override("font_size", 18)
	_hud_hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_hud_hint_label.add_theme_constant_override("outline_size", 4)
	_hud_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud_hint_label.text = ""
	_hud_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_hint_label.offset_top = 60
	_hud_hint_label.offset_left = 20
	_hud_hint_label.offset_right = -20
	_hud_hint_label.hide()
	hud.add_child(_hud_hint_label)
	
	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_on_hint_timeout)
	hud.add_child(_hint_timer)

func _update_hud():
	var player = _get_local_player()
	if not player:
		return
	if _hud_firework_label:
		_hud_firework_label.text = "烟花 x%d" % player.firework_count
	if _hud_camera_label:
		if player.free_camera_unlocked:
			_hud_camera_label.text = "自由镜头: 已解锁"
		else:
			_hud_camera_label.text = "镜片 %d/%d" % [player.camera_fragments, CAMERA_UNLOCK_NEED]

# 显示临时提示（烟花不足、镜片不足等），duration 秒后自动消失
func _show_hint(msg: String, duration: float = 2.0) -> void:
	if not _hud_hint_label:
		return
	_hud_hint_label.text = msg
	_hud_hint_label.show()
	if _hint_timer.is_stopped() == false:
		_hint_timer.stop()
	_hint_timer.start(duration)

func _on_hint_timeout() -> void:
	if _hud_hint_label:
		_hud_hint_label.text = ""
		_hud_hint_label.hide()
		
		
func play_BGM(path: String):
	var bgm = load(path)
	$BGM.stream = bgm
	$BGM.play()