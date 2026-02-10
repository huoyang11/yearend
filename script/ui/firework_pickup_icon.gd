extends Node2D
## 烟花道具图标 — 小火箭 + 动态火焰尾迹 + 飞散火花

var _time := 0.0
var _spark_seed := randf() * 100.0   # 每个实例的火花偏移不同

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var t := _time + _spark_seed

	# ── 火箭头部（尖锥） ──
	var head := PackedVector2Array([
		Vector2(-3.0, -5.0), Vector2(3.0, -5.0), Vector2(0.0, -11.0)
	])
	draw_colored_polygon(head, Color(1.0, 0.58, 0.22))

	# ── 火箭身体 ──
	draw_rect(Rect2(-3.0, -5.0, 6.0, 9.0), Color(0.95, 0.35, 0.14))

	# 装饰条纹
	draw_rect(Rect2(-3.0, -2.0, 6.0, 1.5), Color(1.0, 0.75, 0.3))

	# ── 尾翼 ──
	var fin_color := Color(0.82, 0.22, 0.08)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, 4.0), Vector2(-6.0, 7.0), Vector2(-3.0, 0.0)
	]), fin_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, 4.0), Vector2(6.0, 7.0), Vector2(3.0, 0.0)
	]), fin_color)

	# ── 主火焰（动态长度 & 透明度） ──
	var flame_len := 5.0 + 3.5 * sin(t * 7.5)
	var flame_alpha := 0.75 + 0.25 * sin(t * 9.0)

	draw_line(Vector2(0, 4), Vector2(0, 4 + flame_len),
		Color(1.0, 0.82, 0.12, flame_alpha), 2.8)

	# 侧焰
	var side := flame_len * 0.55
	draw_line(Vector2(-1.8, 5.0), Vector2(-3.0, 5.0 + side),
		Color(1.0, 0.6, 0.1, flame_alpha * 0.55), 1.6)
	draw_line(Vector2(1.8, 5.0), Vector2(3.0, 5.0 + side),
		Color(1.0, 0.6, 0.1, flame_alpha * 0.55), 1.6)

	# ── 飞散火花 ──
	for i in range(5):
		var s := i * 1.37 + _spark_seed
		var px := sin(t * 5.5 + s) * 5.0
		var py := 6.0 + fmod(t * 14.0 + s * 3.0, 9.0)
		var pa: float = max(0.0, 1.0 - py / 15.0) * (0.45 + 0.55 * sin(t * 8.5 + i))
		var pr := 0.6 + 0.4 * sin(t * 6.0 + i * 2.0)
		draw_circle(Vector2(px, py), pr, Color(1.0, 0.92, 0.35, pa))

	# ── 光晕呼吸 ──
	var glow_alpha := 0.08 + 0.06 * sin(t * 2.5)
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.6, 0.15, glow_alpha))
