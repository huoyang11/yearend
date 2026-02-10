extends Node2D
## 镜片道具图标 — 六边形晶体 + 内部脉动 + 旋转高光 + 折射光线

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var t := _time
	var radius := 8.0

	# ── 构建六边形顶点 ──
	var outer := PackedVector2Array()
	for i in range(6):
		var angle := i * TAU / 6.0 - PI / 6.0
		outer.append(Vector2(cos(angle), sin(angle)) * radius)

	# ── 外层光晕（呼吸） ──
	var glow_alpha := 0.06 + 0.05 * sin(t * 2.0)
	draw_circle(Vector2.ZERO, 14.0, Color(0.3, 0.65, 1.0, glow_alpha))

	# ── 外框填充 ──
	draw_colored_polygon(outer, Color(0.13, 0.38, 0.78, 0.88))

	# ── 内部脉动层 ──
	var pulse := 0.55 + 0.25 * sin(t * 3.2)
	var inner_r := radius * 0.62
	var inner := PackedVector2Array()
	for i in range(6):
		var angle := i * TAU / 6.0 - PI / 6.0
		inner.append(Vector2(cos(angle), sin(angle)) * inner_r)
	draw_colored_polygon(inner, Color(0.42, 0.72, 1.0, pulse))

	# ── 中心光点 ──
	var ca := 0.4 + 0.35 * sin(t * 4.0)
	draw_circle(Vector2.ZERO, 2.8, Color(0.85, 0.96, 1.0, ca))

	# ── 旋转高光 ──
	var shine_angle := t * 1.8
	var shine_pos := Vector2(cos(shine_angle), sin(shine_angle)) * 3.8
	var sa := 0.22 + 0.22 * sin(t * 3.5)
	draw_circle(shine_pos, 2.0, Color(1.0, 1.0, 1.0, sa))

	# ── 折射光线（旋转） ──
	for i in range(3):
		var ray_a := t * 0.9 + i * TAU / 3.0
		var r_start := Vector2(cos(ray_a), sin(ray_a)) * 2.2
		var r_end := Vector2(cos(ray_a), sin(ray_a)) * (radius - 0.8)
		var ra := 0.12 + 0.12 * sin(t * 3.0 + i * 2.1)
		draw_line(r_start, r_end, Color(0.7, 0.9, 1.0, ra), 0.9)

	# ── 边框高亮（依次闪烁） ──
	for i in range(6):
		var edge_a := 0.55 + 0.35 * sin(t * 2.2 + i * 1.05)
		draw_line(outer[i], outer[(i + 1) % 6],
			Color(0.5, 0.82, 1.0, edge_a), 1.3)

	# ── 角顶小星（闪烁） ──
	for i in range(6):
		var star_a: float = 0.5 * max(0.0, sin(t * 2.5 + i * 1.1))
		if star_a > 0.05:
			draw_circle(outer[i], 1.2, Color(0.9, 0.95, 1.0, star_a))
