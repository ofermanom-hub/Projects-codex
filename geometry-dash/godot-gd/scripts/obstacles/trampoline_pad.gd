class_name TrampolinePad
extends Node2D
# Custom-drawn rainbow trampoline. Origin (0,0) is the base anchor — ground
# contact for up-pads, ceiling contact for down-pads. Width/height set via
# configure(); the surface compresses with pulse_t and arrow chevrons point
# in the direction of pad_dir.

var obs_w: float = 60.0
var obs_h: float = 40.0
var pad_dir: int = 1  # 1 = push up, -1 = push down
var pulse_t: float = 0.0

func configure(w: float, h: float, dir: int) -> void:
	obs_w = w
	obs_h = h
	pad_dir = dir
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	pulse_t += delta * 3.5
	queue_redraw()

func _draw() -> void:
	var primary: Color
	var secondary: Color
	var spring_colors: Array
	if pad_dir == 1:
		primary = Color(0.05, 3.5, 2.5, 1.0)
		secondary = Color(0.0, 2.0, 4.5, 1.0)
		spring_colors = [Color(4.0,0.3,0.5,1.0),Color(4.5,1.5,0.0,1.0),Color(4.5,4.0,0.0,1.0),
						 Color(0.2,4.5,0.5,1.0),Color(0.0,3.5,5.0,1.0),Color(3.5,0.5,5.0,1.0)]
	else:
		primary = Color(5.0, 1.5, 0.0, 1.0)
		secondary = Color(4.0, 0.2, 0.1, 1.0)
		spring_colors = [Color(5.0,0.2,0.2,1.0),Color(5.0,1.0,0.0,1.0),Color(4.5,2.5,0.0,1.0),
						 Color(3.5,0.1,0.1,1.0),Color(5.0,0.5,0.0,1.0),Color(4.0,0.0,0.2,1.0)]

	var b: float = sin(pulse_t * 3.2)
	var bd: float = b * float(pad_dir)
	var bounce_amt: float = obs_h * 0.16 * bd
	var bar_w: float = 10.0
	var leg_thick: float = obs_w * 0.045

	var y_flip: float = float(pad_dir)
	var frame_y: float = -obs_h * 0.28 * y_flip
	var surf_y: float = (-obs_h * 0.68 + bounce_amt) * y_flip
	var sag: float = obs_h * 0.07 * bd

	# Base feet
	draw_line(Vector2(0, 0.0), Vector2(obs_w * 0.16, 0.0), primary, bar_w)
	draw_line(Vector2(obs_w * 0.84, 0.0), Vector2(obs_w, 0.0), primary, bar_w)

	# Angled legs
	var l_bot := Vector2(obs_w * 0.07, 0.0)
	var l_top := Vector2(obs_w * 0.18, frame_y)
	var l_dir := (l_top - l_bot).normalized().rotated(PI * 0.5) * leg_thick
	draw_polygon(PackedVector2Array([l_bot - l_dir, l_bot + l_dir, l_top + l_dir, l_top - l_dir]),
				 PackedColorArray([primary, primary, secondary, secondary]))
	var r_bot := Vector2(obs_w * 0.93, 0.0)
	var r_top := Vector2(obs_w * 0.82, frame_y)
	var r_dir := (r_top - r_bot).normalized().rotated(PI * 0.5) * leg_thick
	draw_polygon(PackedVector2Array([r_bot - r_dir, r_bot + r_dir, r_top + r_dir, r_top - r_dir]),
				 PackedColorArray([primary, primary, secondary, secondary]))

	# Frame bar
	draw_line(Vector2(obs_w * 0.18, frame_y), Vector2(obs_w * 0.82, frame_y), secondary, bar_w + 2.0)
	draw_circle(Vector2(obs_w * 0.18, frame_y), (bar_w + 2.0) * 0.5, secondary)
	draw_circle(Vector2(obs_w * 0.82, frame_y), (bar_w + 2.0) * 0.5, secondary)

	# Side poles
	draw_line(Vector2(obs_w * 0.18, frame_y), Vector2(obs_w * 0.12, surf_y), primary, 5.0)
	draw_line(Vector2(obs_w * 0.82, frame_y), Vector2(obs_w * 0.88, surf_y), primary, 5.0)

	# Rainbow springs
	for i in range(6):
		var sx: float = lerp(obs_w * 0.18, obs_w * 0.82, float(i) / 5.0)
		_draw_spring(sx, frame_y, surf_y, spring_colors[i], 4.5)

	# Surface band — stacked rainbow strips + white gloss
	var surf_pts := PackedVector2Array([
		Vector2(obs_w * 0.10, surf_y),
		Vector2(obs_w * 0.32, surf_y + sag * 0.55),
		Vector2(obs_w * 0.50, surf_y + sag),
		Vector2(obs_w * 0.68, surf_y + sag * 0.55),
		Vector2(obs_w * 0.90, surf_y),
	])
	for ci in range(spring_colors.size()):
		draw_polyline(surf_pts, spring_colors[ci], 5.0 - ci * 0.6)
	draw_polyline(surf_pts, Color(5.0, 5.0, 5.0, 0.8), 1.5)
	draw_circle(Vector2(obs_w * 0.10, surf_y), 6.0, spring_colors[0])
	draw_circle(Vector2(obs_w * 0.90, surf_y), 6.0, spring_colors[4])

	# Directional arrows
	var arrow_alpha: float = clampf(-bd * 1.4, 0.0, 1.0)
	if arrow_alpha > 0.05:
		var arrow_cols: Array = [
			Color(spring_colors[0].r, spring_colors[0].g, spring_colors[0].b, arrow_alpha),
			Color(spring_colors[2].r, spring_colors[2].g, spring_colors[2].b, arrow_alpha),
			Color(spring_colors[4].r, spring_colors[4].g, spring_colors[4].b, arrow_alpha),
		]
		for i in range(3):
			var ax: float = obs_w * (0.28 + i * 0.22)
			var a_y0: float = surf_y - obs_h * 0.06 * y_flip
			var a_y1: float = surf_y - obs_h * 0.30 * arrow_alpha * y_flip
			var aw: float = obs_h * 0.10
			var ac: Color = arrow_cols[i]
			draw_line(Vector2(ax, a_y0), Vector2(ax, a_y1), ac, 3.5)
			draw_line(Vector2(ax - aw, a_y1 + obs_h * 0.08 * y_flip), Vector2(ax, a_y1), ac, 3.5)
			draw_line(Vector2(ax + aw, a_y1 + obs_h * 0.08 * y_flip), Vector2(ax, a_y1), ac, 3.5)

func _draw_spring(x: float, y_top: float, y_bottom: float, col: Color, width: float = 2.0) -> void:
	var segs := 6
	var half_w := obs_w * 0.038
	var pts := PackedVector2Array()
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var y: float = lerp(y_top, y_bottom, t)
		var xo: float = half_w * (1.0 if i % 2 == 0 else -1.0)
		pts.append(Vector2(x + xo, y))
	draw_polyline(pts, col, width)
