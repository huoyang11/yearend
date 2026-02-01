extends CharacterBody2D

const SPEED = 90.0

# 用于插值同步的变量
var sync_position := Vector2.ZERO
var sync_velocity := Vector2.ZERO

# 记录最后的朝向，用于静止时保持 idle 动画方向
var last_dir := "down"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _enter_tree() -> void:
	# 设置多玩家权限。如果节点名称是数字（peer ID），则将其设为权限所有者。
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	# 初始化同步位置，防止从 0,0 开始插值
	sync_position = global_position
	
	# 只有本地玩家（拥有权限的客户端）启用自己的摄像机
	if is_multiplayer_authority():
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false

func _input(event: InputEvent) -> void:
	# 只有本地玩家可以触发发射
	if is_multiplayer_authority():
		# 检查是否按下空格或回车 (ui_accept) 或鼠标左键
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			# 权限端先生成随机参数
			var angle = randf_range($FireworkItem.angle_min, $FireworkItem.angle_max)
			var color = $FireworkItem._get_color()
			
			# 如果 FireworkItem 的 explosion_type 是 -1 (随机)，这里也生成一个确定的随机类型
			var type = $FireworkItem.explosion_type
			if type == -1:
				type = randi() % 10 # 假设一共有 10 种类型
				
			# 通过 RPC 通知所有客户端同步发射烟花
			fire_firework.rpc(angle, color, type)

@rpc("any_peer", "call_local", "reliable")
func fire_firework(angle: float, color: Color, type: int):
	if has_node("FireworkItem"):
		$FireworkItem.fire(angle, color, type)

func _physics_process(delta: float) -> void:
	# 如果还没有设置好权限，先跳过
	if name == "Player":
		return
	
	if is_multiplayer_authority():
		# 权限端：正常移动并更新同步变量
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = direction * SPEED
		move_and_slide()
		sync_position = global_position
		sync_velocity = velocity
	else:
		# 非权限端：平滑插值移动到同步位置
		# 使用 lerp 实现平滑跟随，15.0 是平滑系数，可以根据手感调整
		global_position = global_position.lerp(sync_position, delta * 15.0)
		velocity = sync_velocity
	
	# 所有客户端都运行动画逻辑，基于同步的 velocity
	update_animation(velocity)

func update_animation(vel: Vector2) -> void:
	if vel.length() > 0:
		# 确定主要移动方向
		if abs(vel.x) > abs(vel.y):
			# 左右移动
			last_dir = "right"
			animated_sprite.play("rightrun")
			# 只有权限端负责设置翻转，非权限端通过同步的 flip_h 自动处理
			if is_multiplayer_authority():
				animated_sprite.flip_h = vel.x < 0
		else:
			# 上下移动
			if vel.y < 0:
				last_dir = "up"
				animated_sprite.play("uprun")
			else:
				last_dir = "down"
				animated_sprite.play("downrun")
			if is_multiplayer_authority():
				animated_sprite.flip_h = false
	else:
		# 静止状态，播放对应的 idle
		match last_dir:
			"up": animated_sprite.play("upidle")
			"down": animated_sprite.play("downidle")
			"right": animated_sprite.play("rightidle")
