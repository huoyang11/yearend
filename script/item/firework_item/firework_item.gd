extends Node2D
class_name FireworkItem

## 烟花道具
## 发射点固定在道具位置，可配置发射角度和高度范围

signal fired()                                    # 发射时触发
signal exploded(position: Vector2, color: Color)  # 爆炸时触发

@export_group("发射角度")
## 最小发射角度（度数，0=正上方，负数=向左偏，正数=向右偏）
@export_range(-60, 60) var angle_min: float = -7.0
## 最大发射角度
@export_range(-60, 60) var angle_max: float = 7.0

@export_group("发射高度")
## 最小发射高度（相对于发射点向上的距离）
@export var height_min: float = 80.0
## 最大发射高度
@export var height_max: float = 120.0

@export_group("发射速度")
## 发射速度倍率最小值
@export_range(0.5, 2.0) var speed_multiplier_min: float = 0.9
## 发射速度倍率最大值
@export_range(0.5, 2.0) var speed_multiplier_max: float = 1.1

@export_group("烟花外观")
## 烟花颜色（留空则随机）
@export var firework_color: Color = Color(0, 0, 0, 0)
## 可选的随机颜色列表
@export var random_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3),   # 红
	Color(0.3, 1.0, 0.3),   # 绿  
	Color(0.3, 0.5, 1.0),   # 蓝
	Color(1.0, 1.0, 0.3),   # 黄
	Color(1.0, 0.5, 0.0),   # 橙
	Color(1.0, 0.3, 1.0),   # 粉
	Color(0.5, 1.0, 1.0),   # 青
	Color(1.0, 0.85, 0.4),  # 金
]

@export_group("爆炸效果")
## 指定爆炸类型（-1 = 随机）
@export_range(-1, 9) var explosion_type: int = -1
## 爆炸缩放倍率
@export var explosion_scale: float = 0.5

@export_group("爆炸时间")
## 最小爆炸时间（秒）- 控制烟花飞行的总距离
@export var explosion_time_min: float = 0.9
## 最大爆炸时间（秒）
@export var explosion_time_max: float = 1.0

@export_group("火箭参数")
## 火箭发射基础速度
@export var rocket_base_speed: float = 250.0
## 火箭重力 - 增加重力会让弹道更有弧度且更短
@export var rocket_gravity: float = 200.0
## 火箭弹头大小
@export var rocket_size: float = 0.2
## 是否显示尾迹
@export var show_trail: bool = true

@export_group("音效设置")
## 上升音效
@export var sfx_up: AudioStream = preload("res://resource/music/upbomb.mp3")
## 爆炸音效
@export var sfx_bomb: AudioStream = preload("res://resource/music/bomb.mp3")

# 内部引用
var _launcher: FireworkLauncher
var _up_audio_player: AudioStreamPlayer  # 当前上升音效播放器

func _ready() -> void:
	# 创建内部的 launcher 用于处理爆炸效果
	_launcher = FireworkLauncher.new()
	_launcher.auto_launch = false  # 禁用自动发射
	_launcher.top_level = true     # 设为顶层，使用全局坐标
	add_child(_launcher)
	
	# 转发爆炸信号
	_launcher.firework_exploded.connect(func(pos, color): exploded.emit(pos, color))

func fire(custom_angle: float = -999.0, custom_color: Color = Color(0,0,0,0), custom_type: int = -2) -> FireworkRocket:
	"""发射一颗烟花，支持传入同步参数"""
	var rocket = FireworkRocket.new()
	rocket.z_index = 1
	
	# 确定颜色
	var color = custom_color if custom_color.a > 0 else _get_color()
	rocket.rocket_color = color
	
	# 确定爆炸类型 (如果传入 -2 则使用默认 logic)
	var final_type = custom_type if custom_type != -2 else explosion_type
	
	# 设置火箭参数
	rocket.launch_speed = rocket_base_speed
	rocket.gravity = rocket_gravity
	rocket.rocket_size = rocket_size
	rocket.trail_enabled = show_trail
	
	# 设置爆炸时间
	rocket.use_timed_explosion = true
	rocket.explosion_time_min = explosion_time_min
	rocket.explosion_time_max = explosion_time_max
	
	rocket.top_level = true
	rocket.global_position = global_position
	rocket.scale = global_scale
	
	# 确定角度
	var angle = custom_angle if custom_angle != -999.0 else randf_range(angle_min, angle_max)
	var speed_mult = randf_range(speed_multiplier_min, speed_multiplier_max)
	
	var angle_rad = deg_to_rad(angle)
	var direction = Vector2(sin(angle_rad), -cos(angle_rad))
	
	add_child(rocket)
	
	# 连接信号时绑定确定的颜色和爆炸类型
	rocket.exploded.connect(_on_rocket_exploded.bind(color, final_type))
	
	rocket.launch(direction, speed_mult)
	_play_up_sound()
	fired.emit()
	return rocket

func fire_burst(count: int = 3, delay: float = 0.1) -> void:
	"""连续发射多颗烟花"""
	for i in range(count):
		if i == 0:
			fire()
		else:
			var timer = get_tree().create_timer(delay * i)
			timer.timeout.connect(fire)

func fire_volley(count: int = 5) -> void:
	"""同时发射多颗烟花（齐射）"""
	for i in range(count):
		fire()

func _get_color() -> Color:
	"""获取烟花颜色"""
	# 如果指定了颜色且不是透明，使用指定颜色
	if firework_color.a > 0:
		return firework_color
	# 否则从随机颜色列表中选择
	if random_colors.size() > 0:
		return random_colors[randi() % random_colors.size()]
	# 默认白色
	return Color.WHITE

func _on_rocket_exploded(pos: Vector2, color: Color, type: int) -> void:
	"""火箭爆炸时创建爆炸效果"""
	# 停止上升音效，播放爆炸音效
	_stop_up_sound()
	_play_bomb_sound()
	
	# pos 已经是全局坐标（来自 FireworkRocket 的 global_position）
	# _launcher 是 top_level，直接使用全局坐标
	_launcher.explosion_scale = explosion_scale
	_launcher._create_explosion_effect(pos, color, type)

func _play_up_sound() -> void:
	"""播放上升音效"""
	if sfx_up == null:
		return
	_up_audio_player = AudioStreamPlayer.new()
	_up_audio_player.stream = sfx_up
	_up_audio_player.bus = "Master"
	add_child(_up_audio_player)
	_up_audio_player.play()
	# 播放完毕后自动销毁
	_up_audio_player.finished.connect(_up_audio_player.queue_free)

func _stop_up_sound() -> void:
	"""停止上升音效"""
	if _up_audio_player != null and is_instance_valid(_up_audio_player):
		_up_audio_player.stop()
		_up_audio_player.queue_free()
		_up_audio_player = null

func _play_bomb_sound() -> void:
	"""播放爆炸音效"""
	if sfx_bomb == null:
		return
	var audio = AudioStreamPlayer.new()
	audio.stream = sfx_bomb
	audio.bus = "Master"
	add_child(audio)
	audio.play()
	# 播放完毕后自动销毁
	audio.finished.connect(audio.queue_free)
