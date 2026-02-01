extends Node2D
class_name TextParticleExplosionAdvanced

## 文字粒子爆炸效果
## 使用 SubViewport 渲染文字并精确采样像素位置
## 优化版：使用 MultiMesh2D 批量渲染粒子

signal animation_finished()

@export_group("文字设置")
@export var text: String = "2025"
@export var font_size: int = 60
@export var font: Font = load("res://resource/font/SourceHanSansSC-Bold.otf")

@export_group("粒子设置")
## 采样步长（越小粒子越密集，但性能越差）
@export_range(2, 10) var sample_step: int = 4
## 粒子大小
@export var particle_size: float = 3.0
## 粒子颜色列表
@export var particle_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3),
	Color(1.0, 0.6, 0.2),
	Color(1.0, 1.0, 0.3),
	Color(0.3, 1.0, 0.5),
	Color(0.3, 0.7, 1.0),
	Color(0.8, 0.4, 1.0),
]

@export_group("动画时间")
@export var gather_time: float = 1.0
@export var hold_time: float = 1.5
@export var explode_time: float = 0.8

@export_group("动画范围")
@export var gather_radius: float = 400.0
@export var explode_radius: float = 500.0

# 状态
enum State { IDLE, GATHERING, HOLDING, EXPLODING, FINISHED }
var _state: State = State.IDLE
var _time: float = 0.0

# 粒子数据 - 使用 PackedArray 提高性能
var _start_positions: PackedVector2Array
var _target_positions: PackedVector2Array
var _explode_positions: PackedVector2Array
var _colors: PackedColorArray
var _sizes: PackedFloat32Array
var _delays: PackedFloat32Array

# MultiMesh 相关
var _multi_mesh: MultiMesh
var _multi_mesh_instance: MultiMeshInstance2D
var _particle_count: int = 0

var _viewport: SubViewport
var _label: Label

func _ready() -> void:
	# 创建用于渲染文字的 SubViewport
	_setup_viewport()
	# 创建 MultiMesh 用于批量渲染
	_setup_multimesh()

func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(800, 200)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(800, 200)
	
	_viewport.add_child(_label)
	add_child(_viewport)

func _setup_multimesh() -> void:
	# 创建 MultiMesh
	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	_multi_mesh.use_colors = true
	
	# 创建圆形粒子网格
	var circle_mesh = _create_circle_mesh()
	_multi_mesh.mesh = circle_mesh
	
	# 创建 MultiMeshInstance2D
	_multi_mesh_instance = MultiMeshInstance2D.new()
	_multi_mesh_instance.multimesh = _multi_mesh
	add_child(_multi_mesh_instance)

func _create_circle_mesh() -> ArrayMesh:
	"""创建一个单位圆形网格"""
	var mesh = ArrayMesh.new()
	var vertices = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	
	# 圆心
	vertices.append(Vector2.ZERO)
	colors.append(Color.WHITE)
	
	# 圆周点 - 用较少的顶点来提高性能
	var segments = 8  # 8边形足够模拟圆形
	for i in range(segments):
		var angle = TAU * i / segments
		vertices.append(Vector2(cos(angle), sin(angle)))
		colors.append(Color.WHITE)
	
	# 三角形索引
	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append((i + 1) % segments + 1)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func play() -> void:
	"""播放完整动画"""
	await _sample_text_async()
	_state = State.GATHERING
	_time = 0.0

func play_explode() -> void:
	"""只播放爆炸（无停留）"""
	await _sample_text_async()
	# 直接从目标位置开始
	_setup_explode_targets()
	_update_multimesh_instant(_target_positions, 1.0)
	_state = State.EXPLODING
	_time = 0.0

func play_appear_then_explode() -> void:
	"""文字直接出现 → 停留 → 爆炸（跳过聚合）"""
	await _sample_text_async()
	# 直接显示在目标位置
	_setup_explode_targets()
	_update_multimesh_instant(_target_positions, 1.0)
	_state = State.HOLDING
	_time = 0.0

func stop() -> void:
	_state = State.IDLE
	_start_positions.clear()
	_multi_mesh.instance_count = 0

func _sample_text_async() -> void:
	"""异步采样文字像素"""
	# 设置 Label
	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
	if font:
		_label.add_theme_font_override("font", font)
	_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 计算需要的视口大小
	var text_size = _label.get_theme_font("font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	var vp_size = Vector2i(int(text_size.x) + 40, int(text_size.y) + 40)
	_viewport.size = vp_size
	_label.size = Vector2(vp_size)
	
	# 渲染一帧
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	
	# 获取图像并采样
	var image = _viewport.get_texture().get_image()
	_sample_from_image(image, vp_size)

func _sample_from_image(image: Image, size: Vector2i) -> void:
	"""从图像采样非透明像素"""
	_start_positions.clear()
	_target_positions.clear()
	_explode_positions.clear()
	_colors.clear()
	_sizes.clear()
	_delays.clear()
	
	var center_offset = Vector2(-size.x / 2.0, -size.y / 2.0)
	
	# 采样像素
	for y in range(0, size.y, sample_step):
		for x in range(0, size.x, sample_step):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0.5:  # 非透明像素
				var target_pos = Vector2(x, y) + center_offset
				
				# 随机起始位置
				var angle = randf() * TAU
				var dist = gather_radius * randf_range(0.5, 1.0)
				var start_pos = target_pos + Vector2(cos(angle), sin(angle)) * dist
				
				_target_positions.append(target_pos)
				_start_positions.append(start_pos)
				_explode_positions.append(Vector2.ZERO)
				
				# 随机颜色
				var color = particle_colors[randi() % particle_colors.size()]
				_colors.append(color)
				
				_sizes.append(particle_size * randf_range(0.7, 1.3))
				_delays.append(randf() * 0.3)
	
	# 更新 MultiMesh 实例数量
	_particle_count = _target_positions.size()
	_multi_mesh.instance_count = _particle_count

func _setup_explode_targets() -> void:
	for i in range(_target_positions.size()):
		var angle = randf() * TAU
		var dist = explode_radius * randf_range(0.3, 1.0)
		var target = _target_positions[i] + Vector2(cos(angle), sin(angle)) * dist
		target.y += randf() * 100
		_explode_positions[i] = target

func _process(delta: float) -> void:
	if _state == State.IDLE or _state == State.FINISHED:
		return
	
	_time += delta
	
	match _state:
		State.GATHERING:
			_update_gathering()
		State.HOLDING:
			_update_holding()
		State.EXPLODING:
			_update_exploding()

func _update_gathering() -> void:
	var all_done = true
	
	for i in range(_particle_count):
		var delay = _delays[i]
		var t = clampf((_time - delay) / gather_time, 0.0, 1.0)
		var eased = 1.0 - pow(1.0 - t, 3.0)  # ease out
		
		var pos = _start_positions[i].lerp(_target_positions[i], eased)
		var alpha = 0.3 + eased * 0.7
		
		_update_particle_instance(i, pos, alpha)
		
		if t < 1.0:
			all_done = false
	
	if all_done:
		_setup_explode_targets()
		_state = State.HOLDING
		_time = 0.0

func _update_holding() -> void:
	if _time >= hold_time:
		_state = State.EXPLODING
		_time = 0.0

func _update_exploding() -> void:
	var all_done = true
	
	for i in range(_particle_count):
		var delay = _delays[i] * 0.5
		var t = clampf((_time - delay) / explode_time, 0.0, 1.0)
		var eased = t * t  # ease in
		
		var pos = _target_positions[i].lerp(_explode_positions[i], eased)
		var alpha = 1.0 - eased
		
		_update_particle_instance(i, pos, alpha)
		
		if t < 1.0:
			all_done = false
	
	if all_done:
		_state = State.FINISHED
		animation_finished.emit()

func _update_particle_instance(index: int, pos: Vector2, alpha: float) -> void:
	"""更新单个粒子实例的变换和颜色"""
	var size = _sizes[index]
	var transform = Transform2D(0, Vector2(size, size), 0, pos)
	_multi_mesh.set_instance_transform_2d(index, transform)
	
	var color = _colors[index]
	color.a = alpha
	_multi_mesh.set_instance_color(index, color)

func _update_multimesh_instant(positions: PackedVector2Array, alpha: float) -> void:
	"""一次性更新所有粒子到指定位置"""
	for i in range(_particle_count):
		var size = _sizes[i]
		var transform = Transform2D(0, Vector2(size, size), 0, positions[i])
		_multi_mesh.set_instance_transform_2d(i, transform)
		
		var color = _colors[i]
		color.a = alpha
		_multi_mesh.set_instance_color(i, color)
