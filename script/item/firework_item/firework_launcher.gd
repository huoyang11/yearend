extends Node2D
class_name FireworkLauncher

## 烟花发射器
## 管理烟花的发射和爆炸效果 - 多种炫酷爆炸类型

signal firework_exploded(position: Vector2, color: Color)

enum ExplosionType {
	SPHERE,          # 球形爆炸
	RING,            # 环形爆炸
	DOUBLE_RING,     # 双环爆炸
	WILLOW,          # 垂柳效果
	CHRYSANTHEMUM,   # 菊花爆炸
	PALM,            # 棕榈树效果
	SPARKLE,         # 闪烁星星
	HEART,           # 心形爆炸
	CROSSETTE,       # 交叉爆炸
	KAMURO,          # 锦冠（金色拖尾）
}

@export_group("发射设置")
@export var auto_launch: bool = true           # 自动发射
@export var launch_interval: float = 1.5       # 发射间隔
@export var launch_from_bottom: bool = true    # 从底部发射

@export_group("烟花外观")
@export var firework_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3),   # 红
	Color(0.3, 1.0, 0.3),   # 绿  
	Color(0.3, 0.5, 1.0),   # 蓝
	Color(1.0, 1.0, 0.3),   # 黄
	Color(1.0, 0.5, 0.0),   # 橙
	Color(1.0, 0.3, 1.0),   # 粉
	Color(0.5, 1.0, 1.0),   # 青
	Color(1.0, 0.8, 0.9),   # 樱花粉
	Color(0.9, 0.7, 1.0),   # 淡紫
	Color(1.0, 0.95, 0.8),  # 金色
]

@export_group("爆炸效果")
## 爆炸缩放倍率
@export var explosion_scale: float = 1.0

var launch_timer: float = 0.0
var viewport_size: Vector2

func _ready() -> void:
	viewport_size = get_viewport_rect().size

func _process(delta: float) -> void:
	if auto_launch:
		launch_timer += delta
		if launch_timer >= launch_interval:
			launch_timer = 0.0
			launch_random_firework()

func launch_random_firework() -> void:
	"""随机发射一个烟花"""
	var rocket = FireworkRocket.new()
	
	# 随机颜色
	var color = firework_colors[randi() % firework_colors.size()]
	rocket.rocket_color = color
	
	# 随机起始位置（屏幕底部）
	if launch_from_bottom:
		rocket.position = Vector2(
			randf_range(viewport_size.x * 0.2, viewport_size.x * 0.8),
			viewport_size.y + 20
		)
	else:
		rocket.position = position
	
	# 随机目标高度
	var target_y = randf_range(viewport_size.y * 0.15, viewport_size.y * 0.45)
	var target_x = rocket.position.x + randf_range(-100, 100)
	
	add_child(rocket)
	
	# 连接爆炸信号
	rocket.exploded.connect(_on_rocket_exploded.bind(color))
	
	# 发射到目标
	rocket.launch_to_target(Vector2(target_x, target_y))

func launch_firework_at(start_pos: Vector2, target_pos: Vector2, color: Color = Color.WHITE) -> FireworkRocket:
	"""在指定位置发射烟花"""
	var rocket = FireworkRocket.new()
	rocket.rocket_color = color if color != Color.WHITE else firework_colors[randi() % firework_colors.size()]
	rocket.position = start_pos
	
	add_child(rocket)
	rocket.exploded.connect(_on_rocket_exploded.bind(rocket.rocket_color))
	rocket.launch_to_target(target_pos)
	
	return rocket

func _on_rocket_exploded(pos: Vector2, color: Color) -> void:
	firework_exploded.emit(pos, color)
	# 随机选择爆炸类型
	var explosion_type = randi() % ExplosionType.size()
	_create_explosion_effect(pos, color, explosion_type)

func _create_explosion_effect(pos: Vector2, color: Color, type: int = -1) -> void:
	"""创建爆炸粒子效果 - 多种类型"""
	if type == -1:
		type = randi() % ExplosionType.size()
	
	# 创建爆炸中心的光源
	_create_explosion_light(pos, color)
	
	match type:
		ExplosionType.SPHERE:
			_create_sphere_explosion(pos, color)
		ExplosionType.RING:
			_create_ring_explosion(pos, color)
		ExplosionType.DOUBLE_RING:
			_create_double_ring_explosion(pos, color)
		ExplosionType.WILLOW:
			_create_willow_explosion(pos, color)
		ExplosionType.CHRYSANTHEMUM:
			_create_chrysanthemum_explosion(pos, color)
		ExplosionType.PALM:
			_create_palm_explosion(pos, color)
		ExplosionType.SPARKLE:
			_create_sparkle_explosion(pos, color)
		ExplosionType.HEART:
			_create_heart_explosion(pos, color)
		ExplosionType.CROSSETTE:
			_create_crossette_explosion(pos, color)
		ExplosionType.KAMURO:
			_create_kamuro_explosion(pos, color)

# ==================== 爆炸效果实现 ====================

func _create_explosion_light(pos: Vector2, color: Color) -> void:
	var light = PointLight2D.new()
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	# 确保光晕在纹理边缘完全消失，防止出现方块感
	texture.fill_to = Vector2(0.5, 0.0) 
	texture.width = 32
	texture.height = 32
	
	light.texture = texture
	light.position = pos
	light.color = color
	light.energy = 1.2
	# 爆炸瞬间的灯光大小随 explosion_scale 缩放
	light.texture_scale = 4.0 * explosion_scale
	add_child(light)
	
	# 光源渐灭动画
	var tween = create_tween()
	tween.set_parallel(true)
	# 缩短消失时间，让闪光更急促、更自然
	tween.tween_property(light, "energy", 0.0, 0.5 * explosion_scale)
	tween.tween_property(light, "texture_scale", 8.0 * explosion_scale, 0.5 * explosion_scale)
	tween.set_parallel(false)
	tween.tween_callback(light.queue_free)

func _create_sphere_explosion(pos: Vector2, color: Color) -> void:
	"""球形爆炸 - 经典烟花"""
	var explosion = CPUParticles2D.new()
	explosion.position = pos
	explosion.emitting = true
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.amount = 80
	explosion.lifetime = 1.2
	
	explosion.direction = Vector2(0, -1)
	explosion.spread = 180.0
	explosion.initial_velocity_min = 150.0 * explosion_scale
	explosion.initial_velocity_max = 250.0 * explosion_scale
	explosion.gravity = Vector2(0, 120 * explosion_scale)
	
	explosion.scale_amount_min = 3.0 * explosion_scale
	explosion.scale_amount_max = 6.0 * explosion_scale
	explosion.scale_amount_curve = _create_fade_curve()
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.1, color)
	gradient.add_point(0.7, color)
	gradient.add_point(1.0, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
	explosion.color_ramp = gradient
	
	add_child(explosion)
	_auto_destroy(explosion, 2.0)

func _create_ring_explosion(pos: Vector2, color: Color) -> void:
	"""环形爆炸 - 圆环扩散"""
	# 使用多个粒子系统模拟环形
	var ring_count = 24
	for i in range(ring_count):
		var angle = (float(i) / ring_count) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 1.0
		particle.amount = 8
		particle.lifetime = 0.8 * explosion_scale
		
		particle.direction = dir
		particle.spread = 5.0
		particle.initial_velocity_min = 180.0 * explosion_scale
		particle.initial_velocity_max = 200.0 * explosion_scale
		particle.gravity = Vector2(0, 80 * explosion_scale)
		
		particle.scale_amount_min = 4.0 * explosion_scale
		particle.scale_amount_max = 6.0 * explosion_scale
		particle.scale_amount_curve = _create_fade_curve()
		
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(0.2, color)
		gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 1.5)

func _create_double_ring_explosion(pos: Vector2, color: Color) -> void:
	"""双环爆炸 - 两层不同颜色"""
	var color2 = _get_complementary_color(color)
	
	# 内环
	_create_ring_at_speed(pos, color, 120.0, 16)
	# 外环 - 延迟一点
	var timer = get_tree().create_timer(0.05)
	timer.timeout.connect(func(): _create_ring_at_speed(pos, color2, 200.0, 20))

func _create_ring_at_speed(pos: Vector2, color: Color, speed: float, count: int) -> void:
	for i in range(count):
		var angle = (float(i) / count) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 1.0
		particle.amount = 6
		particle.lifetime = 0.9
		
		particle.direction = dir
		particle.spread = 8.0
		particle.initial_velocity_min = speed * 0.9 * explosion_scale
		particle.initial_velocity_max = speed * 1.1 * explosion_scale
		particle.gravity = Vector2(0, 60 * explosion_scale)
		
		particle.scale_amount_min = 3.0 * explosion_scale
		particle.scale_amount_max = 5.0 * explosion_scale
		particle.scale_amount_curve = _create_fade_curve()
		
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(0.15, color)
		gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 1.5)

func _create_willow_explosion(pos: Vector2, color: Color) -> void:
	"""垂柳效果 - 粒子向下飘落"""
	var explosion = CPUParticles2D.new()
	explosion.position = pos
	explosion.emitting = true
	explosion.one_shot = true
	explosion.explosiveness = 0.9
	explosion.amount = 100
	explosion.lifetime = 2.5
	
	explosion.direction = Vector2(0, -1)
	explosion.spread = 180.0
	explosion.initial_velocity_min = 80.0 * explosion_scale
	explosion.initial_velocity_max = 180.0 * explosion_scale
	explosion.gravity = Vector2(0, 200 * explosion_scale)  # 更强重力
	explosion.damping_min = 20.0 * explosion_scale
	explosion.damping_max = 40.0 * explosion_scale
	
	explosion.scale_amount_min = 2.0 * explosion_scale
	explosion.scale_amount_max = 4.0 * explosion_scale
	explosion.scale_amount_curve = _create_willow_size_curve()
	
	# 金色渐变最适合垂柳
	var gold_color = Color(1.0, 0.9, 0.5) if color == Color.WHITE else color
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.1, gold_color)
	gradient.add_point(0.5, gold_color)
	gradient.add_point(1.0, Color(gold_color.r * 0.5, gold_color.g * 0.3, 0.0, 0.0))
	explosion.color_ramp = gradient
	
	add_child(explosion)
	_auto_destroy(explosion, 3.5)

func _create_chrysanthemum_explosion(pos: Vector2, color: Color) -> void:
	"""菊花爆炸 - 密集的射线"""
	var ray_count = 36
	for i in range(ray_count):
		var angle = (float(i) / ray_count) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 0.95
		particle.amount = 15
		particle.lifetime = 1.0 * explosion_scale
		
		particle.direction = dir
		particle.spread = 2.0  # 非常窄的扩散
		particle.initial_velocity_min = 100.0 * explosion_scale
		particle.initial_velocity_max = 250.0 * explosion_scale
		particle.gravity = Vector2(0, 100 * explosion_scale)
		
		particle.scale_amount_min = 2.0 * explosion_scale
		particle.scale_amount_max = 4.0 * explosion_scale
		particle.scale_amount_curve = _create_fade_curve()
		
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(0.1, color)
		gradient.add_point(0.8, color)
		gradient.add_point(1.0, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.0))
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 2.0)

func _create_palm_explosion(pos: Vector2, color: Color) -> void:
	"""棕榈树效果 - 先上升再下落"""
	# 主干上升
	var trunk = CPUParticles2D.new()
	trunk.position = pos
	trunk.emitting = true
	trunk.one_shot = true
	trunk.explosiveness = 0.8
	trunk.amount = 30
	trunk.lifetime = 0.6 * explosion_scale
	
	trunk.direction = Vector2(0, -1)
	trunk.spread = 15.0
	trunk.initial_velocity_min = 200.0 * explosion_scale
	trunk.initial_velocity_max = 280.0 * explosion_scale
	trunk.gravity = Vector2(0, 300 * explosion_scale)
	
	trunk.scale_amount_min = 3.0 * explosion_scale
	trunk.scale_amount_max = 5.0 * explosion_scale
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.2, color)
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	trunk.color_ramp = gradient
	
	add_child(trunk)
	_auto_destroy(trunk, 1.5)
	
	# 延迟创建下落的"叶子"
	var timer = get_tree().create_timer(0.3 * explosion_scale)
	timer.timeout.connect(func(): _create_palm_leaves(pos + Vector2(0, -80 * explosion_scale), color))

func _create_palm_leaves(pos: Vector2, color: Color) -> void:
	var leaf_count = 12
	for i in range(leaf_count):
		var angle = (float(i) / leaf_count) * TAU
		var dir = Vector2(cos(angle), sin(angle) - 0.3)  # 稍微向上偏
		
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 0.9
		particle.amount = 20
		particle.lifetime = 1.8 * explosion_scale
		
		particle.direction = dir
		particle.spread = 10.0
		particle.initial_velocity_min = 60.0 * explosion_scale
		particle.initial_velocity_max = 120.0 * explosion_scale
		particle.gravity = Vector2(0, 180 * explosion_scale)
		particle.damping_min = 10.0 * explosion_scale
		particle.damping_max = 20.0 * explosion_scale
		
		particle.scale_amount_min = 2.0 * explosion_scale
		particle.scale_amount_max = 4.0 * explosion_scale
		particle.scale_amount_curve = _create_willow_size_curve()
		
		var gradient = Gradient.new()
		gradient.add_point(0.0, color)
		gradient.add_point(0.6, color)
		gradient.add_point(1.0, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 2.5)

func _create_sparkle_explosion(pos: Vector2, color: Color) -> void:
	"""闪烁星星 - 带有闪烁效果的粒子"""
	# 主爆炸
	var explosion = CPUParticles2D.new()
	explosion.position = pos
	explosion.emitting = true
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.amount = 60
	explosion.lifetime = 1.5 * explosion_scale
	
	explosion.direction = Vector2(0, -1)
	explosion.spread = 180.0
	explosion.initial_velocity_min = 100.0 * explosion_scale
	explosion.initial_velocity_max = 200.0 * explosion_scale
	explosion.gravity = Vector2(0, 100 * explosion_scale)
	
	explosion.scale_amount_min = 2.0 * explosion_scale
	explosion.scale_amount_max = 5.0 * explosion_scale
	explosion.scale_amount_curve = _create_sparkle_curve()
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.1, color)
	gradient.add_point(0.9, color)
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	explosion.color_ramp = gradient
	
	add_child(explosion)
	_auto_destroy(explosion, 2.0)
	
	# 额外的闪光点
	for j in range(3):
		var timer = get_tree().create_timer(0.2 * j * explosion_scale)
		timer.timeout.connect(func(): _create_sparkle_burst(pos, color))

func _create_sparkle_burst(pos: Vector2, color: Color) -> void:
	var sparkle = CPUParticles2D.new()
	sparkle.position = pos + Vector2(randf_range(-50, 50) * explosion_scale, randf_range(-50, 50) * explosion_scale)
	sparkle.emitting = true
	sparkle.one_shot = true
	sparkle.explosiveness = 1.0
	sparkle.amount = 15
	sparkle.lifetime = 0.5 * explosion_scale
	
	sparkle.direction = Vector2(0, -1)
	sparkle.spread = 180.0
	sparkle.initial_velocity_min = 30.0 * explosion_scale
	sparkle.initial_velocity_max = 80.0 * explosion_scale
	sparkle.gravity = Vector2(0, 50 * explosion_scale)
	
	sparkle.scale_amount_min = 4.0 * explosion_scale
	sparkle.scale_amount_max = 8.0 * explosion_scale
	sparkle.scale_amount_curve = _create_fade_curve()
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.5, color)
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	sparkle.color_ramp = gradient
	
	add_child(sparkle)
	_auto_destroy(sparkle, 1.0)

func _create_heart_explosion(pos: Vector2, color: Color) -> void:
	"""心形爆炸"""
	# 使用心形参数方程发射粒子
	var heart_points = 30
	for i in range(heart_points):
		var t = (float(i) / heart_points) * TAU
		# 心形参数方程
		var hx = 16.0 * pow(sin(t), 3)
		var hy = -(13.0 * cos(t) - 5.0 * cos(2.0*t) - 2.0 * cos(3.0*t) - cos(4.0*t))
		var dir = Vector2(hx, hy).normalized()
		
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 1.0
		particle.amount = 8
		particle.lifetime = 1.2 * explosion_scale
		
		particle.direction = dir
		particle.spread = 5.0
		particle.initial_velocity_min = 80.0 * explosion_scale
		particle.initial_velocity_max = 120.0 * explosion_scale
		particle.gravity = Vector2(0, 60 * explosion_scale)
		
		particle.scale_amount_min = 3.0 * explosion_scale
		particle.scale_amount_max = 5.0 * explosion_scale
		particle.scale_amount_curve = _create_fade_curve()
		
		# 心形用粉红/红色最好看
		var heart_color = Color(1.0, 0.4, 0.5) if color == Color.WHITE else color
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(0.15, heart_color)
		gradient.add_point(0.8, heart_color)
		gradient.add_point(1.0, Color(heart_color.r * 0.5, heart_color.g * 0.2, heart_color.b * 0.3, 0.0))
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 2.0)

func _create_crossette_explosion(pos: Vector2, color: Color) -> void:
	"""交叉爆炸 - 先炸开，粒子再次爆炸"""
	# 第一层爆炸
	var directions = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)
	]
	
	for dir in directions:
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 1.0
		particle.amount = 10
		particle.lifetime = 0.4 * explosion_scale
		
		particle.direction = dir
		particle.spread = 10.0
		particle.initial_velocity_min = 150.0 * explosion_scale
		particle.initial_velocity_max = 180.0 * explosion_scale
		particle.gravity = Vector2(0, 50 * explosion_scale)
		
		particle.scale_amount_min = 4.0 * explosion_scale
		particle.scale_amount_max = 6.0 * explosion_scale
		
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(0.2, color)
		gradient.add_point(1.0, color)
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 1.0)
		
		# 延迟二次爆炸
		var end_pos = pos + dir * 100 * explosion_scale
		var timer = get_tree().create_timer(0.35 * explosion_scale)
		timer.timeout.connect(func(): _create_mini_explosion(end_pos, color))

func _create_mini_explosion(pos: Vector2, color: Color) -> void:
	var mini = CPUParticles2D.new()
	mini.position = pos
	mini.emitting = true
	mini.one_shot = true
	mini.explosiveness = 1.0
	mini.amount = 25
	mini.lifetime = 0.8 * explosion_scale
	
	mini.direction = Vector2(0, -1)
	mini.spread = 180.0
	mini.initial_velocity_min = 60.0 * explosion_scale
	mini.initial_velocity_max = 120.0 * explosion_scale
	mini.gravity = Vector2(0, 120 * explosion_scale)
	
	mini.scale_amount_min = 2.0 * explosion_scale
	mini.scale_amount_max = 4.0 * explosion_scale
	mini.scale_amount_curve = _create_fade_curve()
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.1, color)
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	mini.color_ramp = gradient
	
	add_child(mini)
	_auto_destroy(mini, 1.5)

func _create_kamuro_explosion(pos: Vector2, color: Color) -> void:
	"""锦冠效果 - 金色长拖尾"""
	var ray_count = 48
	for i in range(ray_count):
		var angle = (float(i) / ray_count) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		var particle = CPUParticles2D.new()
		particle.position = pos
		particle.emitting = true
		particle.one_shot = true
		particle.explosiveness = 0.98
		particle.amount = 25
		particle.lifetime = 2.0 * explosion_scale
		
		particle.direction = dir
		particle.spread = 3.0
		particle.initial_velocity_min = 50.0 * explosion_scale
		particle.initial_velocity_max = 200.0 * explosion_scale
		particle.gravity = Vector2(0, 150 * explosion_scale)
		particle.damping_min = 30.0 * explosion_scale
		particle.damping_max = 50.0 * explosion_scale
		
		particle.scale_amount_min = 2.0 * explosion_scale
		particle.scale_amount_max = 4.0 * explosion_scale
		particle.scale_amount_curve = _create_kamuro_size_curve()
		
		# 金色渐变
		var gold = Color(1.0, 0.85, 0.4)
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(0.05, gold)
		gradient.add_point(0.4, gold)
		gradient.add_point(0.7, Color(1.0, 0.6, 0.2))
		gradient.add_point(1.0, Color(0.8, 0.3, 0.0, 0.0))
		particle.color_ramp = gradient
		
		add_child(particle)
		_auto_destroy(particle, 3.0)

# ==================== 辅助函数 ====================

func _create_fade_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.8, 0.6))
	curve.add_point(Vector2(1, 0))
	return curve

func _create_willow_size_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.8))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.2))
	return curve

func _create_sparkle_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.2, 0.3))
	curve.add_point(Vector2(0.4, 1))
	curve.add_point(Vector2(0.6, 0.4))
	curve.add_point(Vector2(0.8, 0.8))
	curve.add_point(Vector2(1, 0))
	return curve

func _create_kamuro_size_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.2))
	curve.add_point(Vector2(0.1, 1.0))
	curve.add_point(Vector2(0.5, 0.6))
	curve.add_point(Vector2(1, 0.1))
	return curve

func _get_complementary_color(color: Color) -> Color:
	"""获取互补色"""
	return Color(1.0 - color.r * 0.5, 1.0 - color.g * 0.5, 1.0 - color.b * 0.5)

func _auto_destroy(node: Node, delay: float) -> void:
	# 设置粒子材质为 unshaded，使其不受环境变暗影响
	if node is CanvasItem:
		var mat = CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		node.material = mat
		
	var tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(node.queue_free)
