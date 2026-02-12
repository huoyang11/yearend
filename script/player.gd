extends CharacterBody2D

const SPEED = 90.0

# 用于插值同步的变量
var sync_position := Vector2.ZERO
var sync_velocity := Vector2.ZERO

# 记录最后的朝向，用于静止时保持 idle 动画方向
var last_dir := "down"

# ===== 道具系统 =====
var firework_count := 0        # 烟花弹药数量，捡一个放一个
var camera_fragments := 0      # 已收集的镜片数量
var free_camera_unlocked := false  # 自由镜头是否已解锁（需要 10 个镜片）

# ===== 镜头模式 =====
enum CameraMode { FOLLOW, FREE }
var camera_mode := CameraMode.FOLLOW

# 自由镜头 — 记录进入自由模式前的 zoom，用于切回时恢复
var _cam_saved_zoom := Vector2.ONE

# 自由镜头 — 拖拽平移
var _cam_dragging := false
var _cam_drag_last_pos := Vector2.ZERO

# 自由镜头 — 触屏缩放
var _touch_points := {}          # index -> position
var _pinch_initial_dist := 0.0
var _pinch_initial_zoom := Vector2.ONE
var _is_pinching := false        # 双指缩放中，屏蔽单指平移

const CAM_ZOOM_MIN := 0.03
const CAM_ZOOM_MAX := 3.0
const CAM_ZOOM_STEP := 0.1
const CAM_PAN_SPEED := 0.4       # 触屏平移速度系数（< 1 减速）

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
	if not is_multiplayer_authority():
		return
	
	# Tab 键切换镜头模式
	if event.is_action_pressed("switch"):
		_toggle_camera_mode()
		get_viewport().set_input_as_handled()
		return
	
	if camera_mode == CameraMode.FREE:
		_handle_free_camera_input(event)
	else:
		_handle_follow_mode_input(event)

# 请求主场景显示 HUD 提示（烟花不足、镜片不足等）
func _show_hint_on_main(msg: String, duration: float = 2.0) -> void:
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("_show_hint"):
		main_node._show_hint(msg, duration)

# ---------- 切换镜头模式 ----------
const CAMERA_UNLOCK_NEED := 10  # 与 main 中常量一致，用于提示文案

func _toggle_camera_mode() -> void:
	if camera_mode == CameraMode.FOLLOW:
		if not free_camera_unlocked:
			_show_hint_on_main("镜片不足，需收集 %d 个镜片解锁自由镜头" % CAMERA_UNLOCK_NEED)
			return
		# 保存当前 zoom，进入自由模式
		_cam_saved_zoom = $Camera2D.zoom
		camera_mode = CameraMode.FREE
		get_tree().current_scene.play_BGM("res://resource/music/BGM2.mp3")
		print("镜头模式: 自由")
	else:
		# 复位偏移和 zoom，切回跟随模式
		camera_mode = CameraMode.FOLLOW
		$Camera2D.offset = Vector2.ZERO
		$Camera2D.zoom = _cam_saved_zoom
		_cam_dragging = false
		_touch_points.clear()
		get_tree().current_scene.play_BGM("res://resource/music/BGM.ogg")
		print("镜头模式: 跟随")

# ---------- 跟随模式输入（原有逻辑） ----------
func _handle_follow_mode_input(event: InputEvent) -> void:
	# 检查是否按下空格或回车 (ui_accept) 或鼠标左键
	if event.is_action_pressed("ui_accept"):
		# 需要有烟花弹药才能发射
		if firework_count <= 0:
			_show_hint_on_main("烟花不足")
			return
		firework_count -= 1
		
		# 通知 main 更新 HUD
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("_update_hud"):
			main_node._update_hud()
		
		# 权限端先生成随机参数
		var angle = randf_range($FireworkItem.angle_min, $FireworkItem.angle_max)
		var color = $FireworkItem._get_color()
		
		# 如果 FireworkItem 的 explosion_type 是 -1 (随机)，这里也生成一个确定的随机类型
		var type = $FireworkItem.explosion_type
		if type == -1:
			type = randi() % 10 # 假设一共有 10 种类型
			
		# 通过 RPC 通知所有客户端同步发射烟花
		fire_firework.rpc(angle, color, type)

# ---------- 自由镜头输入 ----------
func _handle_free_camera_input(event: InputEvent) -> void:
	var cam := $Camera2D
	
	# ---- PC：鼠标左键拖拽平移 ----
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_cam_dragging = true
				_cam_drag_last_pos = event.position
			else:
				_cam_dragging = false
		# ---- PC：滚轮缩放 ----
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom = cam.zoom + Vector2.ONE * CAM_ZOOM_STEP * cam.zoom.x
			cam.zoom = new_zoom.clamp(Vector2(CAM_ZOOM_MIN, CAM_ZOOM_MIN), Vector2(CAM_ZOOM_MAX, CAM_ZOOM_MAX))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom = cam.zoom - Vector2.ONE * CAM_ZOOM_STEP * cam.zoom.x
			cam.zoom = new_zoom.clamp(Vector2(CAM_ZOOM_MIN, CAM_ZOOM_MIN), Vector2(CAM_ZOOM_MAX, CAM_ZOOM_MAX))
	
	if event is InputEventMouseMotion and _cam_dragging:
		cam.offset -= event.relative / cam.zoom * CAM_PAN_SPEED
	
	# ---- 移动设备：触控拖拽平移 & 双指缩放（互斥） ----
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
			if _touch_points.size() == 2:
				# 进入缩放模式，锁定平移
				_is_pinching = true
				var pts = _touch_points.values()
				_pinch_initial_dist = pts[0].distance_to(pts[1])
				_pinch_initial_zoom = cam.zoom
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				# 手指数不足 2，退出缩放模式
				_pinch_initial_dist = 0.0
				_is_pinching = false
	
	if event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _is_pinching and _touch_points.size() == 2:
			# 双指捏合 → 仅缩放
			var pts = _touch_points.values()
			var current_dist = pts[0].distance_to(pts[1])
			if _pinch_initial_dist > 0:
				var factor = current_dist / _pinch_initial_dist
				cam.zoom = (_pinch_initial_zoom * factor).clamp(Vector2(CAM_ZOOM_MIN, CAM_ZOOM_MIN), Vector2(CAM_ZOOM_MAX, CAM_ZOOM_MAX))
		elif not _is_pinching and _touch_points.size() == 1:
			# 单指拖拽 → 仅平移（带减速系数）
			cam.offset -= event.relative / cam.zoom * CAM_PAN_SPEED

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
