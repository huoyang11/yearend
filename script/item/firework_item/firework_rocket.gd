extends Node2D
class_name FireworkRocket

## 烟花发射火箭
## 不需要任何素材，纯代码实现发光弹头和尾迹效果

signal exploded(position: Vector2)  # 爆炸时发出信号

# 发射参数
@export var launch_speed: float = 400.0        # 发射速度
@export var gravity: float = 200.0             # 重力

# 爆炸触发方式
@export var use_timed_explosion: bool = true   # 是否使用定时爆炸
@export var explosion_time_min: float = 0.8    # 最小爆炸时间（秒）
@export var explosion_time_max: float = 1.2    # 最大爆炸时间（秒）
@export var explode_speed_threshold: float = 50.0  # 速度低于此值时爆炸（仅当 use_timed_explosion=false 时生效）

# 外观参数
@export var rocket_color: Color = Color(1.0, 0.9, 0.5, 1.0)  # 弹头颜色
@export var rocket_size: float = 4.0           # 弹头大小
@export var trail_enabled: bool = true         # 是否启用尾迹

var velocity: Vector2 = Vector2.ZERO
var is_launched: bool = false
var flight_time: float = 0.0                   # 飞行时间
var target_explosion_time: float = 0.0         # 目标爆炸时间

# 尾迹粒子
var trail_particles: CPUParticles2D
var rocket_light: PointLight2D

func _ready() -> void:
	if trail_enabled:
		_create_trail_particles()
	_create_rocket_light()

func _create_rocket_light() -> void:
	rocket_light = PointLight2D.new()
	# 创建一个非常小的径向渐变纹理
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	# 显式设置半径，确保光晕在纹理边缘消失
	texture.fill_to = Vector2(0.5, 0.0) 
	texture.width = 16
	texture.height = 16
	
	rocket_light.texture = texture
	rocket_light.texture_scale = 1.0
	rocket_light.color = rocket_color
	# 降低能量值，使其只是轻微照亮周围
	rocket_light.energy = 0.8
	# 开启阴影（可选，如果需要更真实可以开，目前先优化基础显示）
	add_child(rocket_light)

func _create_trail_particles() -> void:
	trail_particles = CPUParticles2D.new()
	add_child(trail_particles)
	
	# 粒子设置 - 尾迹效果
	trail_particles.emitting = false
	trail_particles.amount = 30
	trail_particles.lifetime = 0.5
	trail_particles.one_shot = false
	trail_particles.explosiveness = 0.0
	trail_particles.local_coords = false  # 使用全局坐标，这样尾迹会留在原地
	
	# 发射方向 - 向下发射形成尾迹
	trail_particles.direction = Vector2(0, 1)
	trail_particles.spread = 15.0
	
	# 速度
	trail_particles.initial_velocity_min = 20.0
	trail_particles.initial_velocity_max = 50.0
	
	# 重力 - 轻微下坠
	trail_particles.gravity = Vector2(0, 50)
	
	# 大小 - 从小变更小
	trail_particles.scale_amount_min = 1.0
	trail_particles.scale_amount_max = 2.0
	trail_particles.scale_amount_curve = _create_fade_curve()
	
	# 颜色 - 渐变消失
	var gradient = Gradient.new()
	gradient.set_color(0, rocket_color)
	gradient.set_color(1, Color(rocket_color.r, rocket_color.g, rocket_color.b, 0.0))
	trail_particles.color_ramp = gradient

func _create_fade_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	return curve

func launch(direction: Vector2 = Vector2.UP, speed_multiplier: float = 1.0) -> void:
	"""发射烟花"""
	velocity = direction.normalized() * launch_speed * speed_multiplier
	is_launched = true
	flight_time = 0.0
	
	# 设置随机爆炸时间
	target_explosion_time = randf_range(explosion_time_min, explosion_time_max)
	
	if trail_particles:
		trail_particles.emitting = true

func launch_to_target(target_pos: Vector2) -> void:
	"""发射到指定位置（自动计算角度和速度）"""
	var direction = (target_pos - global_position).normalized()
	# 添加一些随机偏移让效果更自然
	direction = direction.rotated(randf_range(-0.1, 0.1))
	launch(direction, randf_range(0.8, 1.2))

func _process(delta: float) -> void:
	if not is_launched:
		return
	
	# 更新飞行时间
	flight_time += delta
	
	# 应用重力
	velocity.y += gravity * delta
	
	# 移动
	position += velocity * delta
	
	# 检查是否应该爆炸
	var should_explode = false
	if use_timed_explosion:
		# 定时爆炸模式
		should_explode = flight_time >= target_explosion_time
	else:
		# 速度阈值模式（速度变慢或开始下落）
		should_explode = velocity.length() < explode_speed_threshold or velocity.y > 0
	
	if should_explode:
		_explode()
	
	# 更新绘制
	queue_redraw()

func _draw() -> void:
	if not is_launched:
		return
	
	# 绘制发光弹头 - 多层圆形模拟发光效果
	# 外层光晕
	var glow_color = Color(rocket_color.r, rocket_color.g, rocket_color.b, 0.3)
	draw_circle(Vector2.ZERO, rocket_size * 2.5, glow_color)
	
	# 中层光晕
	glow_color.a = 0.5
	draw_circle(Vector2.ZERO, rocket_size * 1.5, glow_color)
	
	# 核心亮点
	draw_circle(Vector2.ZERO, rocket_size, rocket_color)
	
	# 白色核心
	draw_circle(Vector2.ZERO, rocket_size * 0.5, Color.WHITE)

func _explode() -> void:
	is_launched = false
	
	if trail_particles:
		trail_particles.emitting = false
	
	if rocket_light:
		var tween_light = create_tween()
		tween_light.tween_property(rocket_light, "energy", 0.0, 0.2)
	
	# 发出爆炸信号
	exploded.emit(global_position)
	
	# 延迟销毁，等待尾迹粒子消失
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)
