extends Node2D
class_name TextFireworkItem

## 文字烟花道具
## 发射烟花，爆炸时显示文字粒子效果

signal fired()
signal exploded(position: Vector2, text: String)

@export_group("文字设置")
## 爆炸显示的文字列表（随机选择一个）
@export var explosion_texts: Array[String] = ["2025", "新年快乐", "恭喜发财"]
## 是否顺序显示文字（否则随机）
@export var sequential_text: bool = false
## 字体大小
@export var font_size: int = 60
## 字体（留空使用默认）
@export var font: Font
## 粒子采样步长（越小越密集，性能越差）
@export_range(3, 8) var sample_step: int = 4
## 粒子大小
@export var particle_size: float = 3.0

@export_group("发射角度")
@export_range(-60, 60) var angle_min: float = -10.0
@export_range(-60, 60) var angle_max: float = 10.0

@export_group("爆炸时间")
@export var explosion_time_min: float = 0.8
@export var explosion_time_max: float = 1.2

@export_group("动画时间")
## 文字停留时间
@export var hold_time: float = 1.5
## 文字爆炸时间
@export var explode_time: float = 0.8
## 文字出现延迟（烟花爆炸后多久出现文字）
@export var text_appear_delay: float = 0.1

@export_group("烟花爆炸效果")
## 烟花爆炸粒子数量
@export var firework_particle_count: int = 60
## 烟花爆炸范围
@export var firework_explosion_speed: float = 200.0

@export_group("火箭参数")
@export var rocket_speed: float = 450.0
@export var rocket_gravity: float = 200.0
@export var rocket_size: float = 6.0
@export var show_trail: bool = true
@export var rocket_color: Color = Color(1.0, 0.9, 0.5)

@export_group("音效设置")
## 上升音效
@export var sfx_up: AudioStream = preload("res://resource/music/upbomb.mp3")
## 爆炸音效
@export var sfx_bomb: AudioStream = preload("res://resource/music/bomb.mp3")

# 内部变量
var _current_text_index: int = 0
var _up_audio_player: AudioStreamPlayer  # 当前上升音效播放器
var _text_explosion_scene: PackedScene

func _ready() -> void:
	pass

func fire() -> void:
	"""发射一颗文字烟花"""
	if explosion_texts.is_empty():
		push_warning("TextFireworkItem: 没有配置爆炸文字")
		return
	
	# 创建火箭
	var rocket = FireworkRocket.new()
	rocket.rocket_color = rocket_color
	rocket.launch_speed = rocket_speed
	rocket.gravity = rocket_gravity
	rocket.rocket_size = rocket_size
	rocket.trail_enabled = show_trail
	rocket.use_timed_explosion = true
	rocket.explosion_time_min = explosion_time_min
	rocket.explosion_time_max = explosion_time_max
	
	# 设置发射位置
	rocket.position = Vector2.ZERO
	
	# 计算发射方向
	var angle = randf_range(angle_min, angle_max)
	var angle_rad = deg_to_rad(angle)
	var direction = Vector2(sin(angle_rad), -cos(angle_rad))
	
	add_child(rocket)
	
	# 选择文字
	var text = _get_next_text()
	
	# 连接爆炸信号
	rocket.exploded.connect(_on_rocket_exploded.bind(text))
	
	# 发射
	rocket.launch(direction, randf_range(0.9, 1.1))
	
	# 播放上升音效
	_play_up_sound()
	
	fired.emit()

func fire_with_text(text: String) -> void:
	"""发射指定文字的烟花"""
	var rocket = FireworkRocket.new()
	rocket.rocket_color = rocket_color
	rocket.launch_speed = rocket_speed
	rocket.gravity = rocket_gravity
	rocket.rocket_size = rocket_size
	rocket.trail_enabled = show_trail
	rocket.use_timed_explosion = true
	rocket.explosion_time_min = explosion_time_min
	rocket.explosion_time_max = explosion_time_max
	
	rocket.position = Vector2.ZERO
	
	var angle = randf_range(angle_min, angle_max)
	var angle_rad = deg_to_rad(angle)
	var direction = Vector2(sin(angle_rad), -cos(angle_rad))
	
	add_child(rocket)
	rocket.exploded.connect(_on_rocket_exploded.bind(text))
	rocket.launch(direction, randf_range(0.9, 1.1))
	
	# 播放上升音效
	_play_up_sound()
	
	fired.emit()

func fire_burst(count: int = 3, delay: float = 0.3) -> void:
	"""连续发射多颗"""
	for i in range(count):
		if i == 0:
			fire()
		else:
			var timer = get_tree().create_timer(delay * i)
			timer.timeout.connect(fire)

func _get_next_text() -> String:
	"""获取下一个要显示的文字"""
	if explosion_texts.is_empty():
		return ""
	
	var text: String
	if sequential_text:
		text = explosion_texts[_current_text_index]
		_current_text_index = (_current_text_index + 1) % explosion_texts.size()
	else:
		text = explosion_texts[randi() % explosion_texts.size()]
	
	return text

func _on_rocket_exploded(pos: Vector2, text: String) -> void:
	"""火箭爆炸时：先烟花爆炸，再显示文字"""
	# 停止上升音效，播放爆炸音效
	_stop_up_sound()
	_play_bomb_sound()
	
	# 1. 先播放普通烟花爆炸
	_create_firework_explosion(pos)
	
	# 2. 延迟后显示文字
	if text_appear_delay > 0:
		var timer = get_tree().create_timer(text_appear_delay)
		timer.timeout.connect(func(): _create_text_explosion(pos, text))
	else:
		_create_text_explosion(pos, text)
	
	exploded.emit(pos, text)

func _create_firework_explosion(pos: Vector2) -> void:
	"""创建普通烟花爆炸效果"""
	var explosion = CPUParticles2D.new()
	explosion.position = pos
	explosion.top_level = true
	explosion.emitting = true
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.amount = firework_particle_count
	explosion.lifetime = 1.0
	
	explosion.direction = Vector2(0, -1)
	explosion.spread = 180.0
	explosion.initial_velocity_min = firework_explosion_speed * 0.6
	explosion.initial_velocity_max = firework_explosion_speed
	explosion.gravity = Vector2(0, 150)
	
	explosion.scale_amount_min = 3.0
	explosion.scale_amount_max = 5.0
	
	# 使用火箭颜色
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.15, rocket_color)
	gradient.add_point(0.6, rocket_color)
	gradient.add_point(1.0, Color(rocket_color.r * 0.3, rocket_color.g * 0.3, rocket_color.b * 0.3, 0.0))
	explosion.color_ramp = gradient
	
	# 大小曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.6))
	curve.add_point(Vector2(1, 0))
	explosion.scale_amount_curve = curve
	
	add_child(explosion)
	
	# 自动销毁
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(explosion.queue_free)

func _create_text_explosion(pos: Vector2, text: String) -> void:
	"""在指定位置创建文字粒子效果（直接出现→停留→爆炸）"""
	var text_fx = TextParticleExplosionAdvanced.new()
	text_fx.position = pos
	text_fx.text = text
	text_fx.font_size = font_size
	text_fx.sample_step = sample_step
	text_fx.particle_size = particle_size
	text_fx.hold_time = hold_time
	text_fx.explode_time = explode_time
	# 文字颜色和火箭颜色一致
	var colors: Array[Color] = [rocket_color]
	text_fx.particle_colors = colors
	
	if font:
		text_fx.font = font
	
	# 使用顶层坐标
	text_fx.top_level = true
	
	add_child(text_fx)
	
	# 播放动画 - 文字直接出现，停留，然后爆炸
	text_fx.play_appear_then_explode()
	
	# 动画完成后自动销毁
	text_fx.animation_finished.connect(func(): text_fx.queue_free())

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
