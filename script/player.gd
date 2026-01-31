extends CharacterBody2D

const SPEED = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _enter_tree() -> void:
	# 设置多玩家权限。如果节点名称是数字（peer ID），则将其设为权限所有者。
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	# 只有本地玩家（拥有权限的客户端）启用自己的摄像机
	if is_multiplayer_authority():
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false
		
	# 确保在 ready 之后才开始同步，避免初始化顺序问题
	if not is_multiplayer_authority():
		# 非权限端可以做一些初始化，比如禁用预测或设置插值
		pass

func _physics_process(_delta: float) -> void:
	# 如果还没有设置好权限（比如节点刚进入树但还没被重命名），先跳过
	if name == "Player":
		return
	
	# 只有拥有权限的客户端（本地玩家）才能控制移动
	if is_multiplayer_authority():
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = direction * SPEED
		move_and_slide()
	
	# 所有客户端都运行动画逻辑，基于同步的 velocity 和 flip_h (由权限端控制)
	if velocity.length() > 0:
		animated_sprite.play("downidle")
		if is_multiplayer_authority() and velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0
	else:
		animated_sprite.stop()
