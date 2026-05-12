extends Node2D

var obs_type : String = "spike"
var obs_w    : float  = 52.0
var obs_h    : float  = 52.0

var pulse_t  : float = 0.0
var spin_t   : float = 0.0
var light    : PointLight2D

var gif_anim              = null  # GifPool.GifAnim assigned by Main after spawn
var _gif_tex : ImageTexture = null
var pad_dir  : int = 1  # 1 = push up, -1 = push down

func _ready() -> void:
	obs_type   = get_meta("obs_type", "spike")
	obs_w      = get_meta("obs_w",    52.0)
	obs_h      = get_meta("obs_h",    52.0)
	pad_dir    = get_meta("pad_dir",  1)
	spin_t     = randf() * TAU
	light_mask = 0   # prevent own PointLight2D from tinting the GIF interior
	_add_light()

func _add_light() -> void:
	light = PointLight2D.new()
	var ceil_type := obs_type in ["ceil_block", "ceil_saw"]
	light.position = Vector2(obs_w * 0.5, obs_h * 0.5 if ceil_type else -obs_h * 0.5)
	light.energy   = 1.4
	light.texture_scale = 1.6
	match obs_type:
		"spike", "ceil_spike": light.color = Color(3.5, 0.3, 0.4, 1.0)
		"saw", "ceil_saw":     light.color = Color(0.4, 0.4, 3.5, 1.0)
		"pad":                 light.color = Color(0.05, 3.5, 2.0, 1.0)
		"orb":                 light.color = Color(4.0, 3.5, 0.2, 1.0)
		"diamond":             light.color = Color(0.3, 3.5, 1.0, 1.0)
		"ceil_block":          light.color = Color(0.2, 1.5, 3.5, 1.0)
		"gravity_portal":      light.color = Color(1.8, 0.2, 3.5, 1.0)
		"speed_portal":        light.color = Color(0.2, 3.5, 2.5, 1.0)
		_:                     light.color = Color(1.5, 0.3, 3.5, 1.0)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for xi in 64:
		for yi in 64:
			var dx := (xi - 32.0) / 32.0
			var dy := (yi - 32.0) / 32.0
			var d  := sqrt(dx*dx + dy*dy)
			var a  := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(xi, yi, Color(1, 1, 1, a * a))
	light.texture = ImageTexture.create_from_image(img)
	add_child(light)

func _process(delta: float) -> void:
	pulse_t += delta * 3.5
	spin_t  += delta * (5.5 if obs_type in ["saw", "ceil_saw"] else 1.8)
	light.energy = 1.4 * (1.0 + 0.25 * sin(pulse_t))
	if gif_anim != null:
		_gif_tex = gif_anim.advance(delta)
	queue_redraw()

func _draw() -> void:
	if obs_type != "pad" and _draw_subject_gif():
		return
	match obs_type:
		"spike":          _draw_spike(false)
		"ceil_spike":     _draw_spike(true)
		"block":          _draw_block()
		"saw":            _draw_saw()
		"pad":            _draw_pad()
		"orb":            _draw_orb()
		"diamond":        _draw_diamond()
		"ceil_block":     _draw_ceil_block()
		"ceil_saw":       _draw_ceil_saw()
		"gravity_portal": _draw_gravity_portal()
		"speed_portal":   _draw_speed_portal()

# ── AI subject polygon rendering ───────────────────────────────────────────────
func _draw_subject_gif() -> bool:
	if gif_anim == null: return false
	var poly: PackedVector2Array = gif_anim.current_polygon()
	if poly.is_empty(): return false
	var tex : ImageTexture = gif_anim.current_subject()
	if tex == null: tex = _gif_tex
	if tex == null: return false
	var is_ceil := obs_type in ["ceil_block", "ceil_saw", "ceil_spike"]
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in poly:
		var lx := float(p.x) * obs_w
		var ly := float(p.y) * obs_h - (0.0 if is_ceil else obs_h)
		pts.append(Vector2(lx, ly))
		uvs.append(Vector2(float(p.x), float(p.y)))

	# Solid black background inside polygon
	draw_polygon(pts, PackedColorArray([Color(0, 0, 0, 1.0)]))
	# GIF at full opacity
	draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 1.0)]), uvs, tex)

	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, _neon_color(), 2.2)

	# Outward perimeter spikes
	var nc       := _neon_color()
	var glow_col := Color(nc.r, nc.g, nc.b, 0.35)
	var n        := pts.size()
	var centroid := Vector2.ZERO
	for p in pts:
		centroid += p
	centroid /= float(n)

	for i in range(n):
		var a   := pts[i]
		var b_  := pts[(i + 1) % n]
		var mid := (a + b_) * 0.5
		var edge := b_ - a
		var edge_len := edge.length()
		if edge_len < 4.0:
			continue
		var normal := Vector2(-edge.y, edge.x) / edge_len
		if normal.dot(mid - centroid) < 0.0:
			normal = -normal
		var spike_len := minf(edge_len * 0.55, obs_w * 0.18)
		var tip       := mid + normal * spike_len
		var base_half := edge_len * 0.18
		var perp      := edge.normalized() * base_half
		var b1        := mid - perp
		var b2        := mid + perp

		# Glow aura
		draw_polygon(PackedVector2Array([b1, b2, tip]),
		             PackedColorArray([glow_col, glow_col, Color(nc.r, nc.g, nc.b, 0.0)]))
		# Solid neon spike
		draw_polygon(PackedVector2Array([b1, b2, tip]),
		             PackedColorArray([nc, nc, Color(nc.r * 0.4, nc.g * 0.4, nc.b * 0.4, 1.0)]))

		# Sparkle at tip
		var spark_alpha := 0.5 + 0.5 * sin(pulse_t * 4.0 + float(i) * 1.3)
		var sc          := Color(nc.r, nc.g, nc.b, spark_alpha)
		var sr          := spike_len * 0.18
		draw_circle(tip, sr * 1.6, Color(sc.r, sc.g, sc.b, sc.a * 0.4))
		draw_circle(tip, sr,       sc)

	return true

func _neon_color() -> Color:
	match obs_type:
		"spike", "ceil_spike": return Color(5.0, 0.5, 0.5, 1.0)
		"saw", "ceil_saw":     return Color(0.4, 0.4, 3.5, 1.0)
		"block":               return Color(2.8, 0.5, 5.0, 1.0)
		"diamond":             return Color(0.5, 5.0, 1.5, 1.0)
		"ceil_block":          return Color(0.4, 2.0, 5.0, 1.0)
		_:                     return Color(2.5, 0.5, 4.5, 1.0)

# ── Spike (floor and ceiling variants) ────────────────────────────────────────
func _draw_spike(inverted: bool) -> void:
	var tip_y : float = -obs_h if not inverted else obs_h
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(obs_w * 0.5, tip_y), Vector2(obs_w, 0)
	])

	# Pulsing danger aura behind spike
	var aura_a := 0.15 + 0.10 * sin(pulse_t * 2.6)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-obs_w * 0.12, 0),
		Vector2(obs_w * 0.50,  tip_y * 1.22),
		Vector2(obs_w * 1.12,  0),
	]), Color(5.0, 0.15, 0.15, aura_a))

	# Flanking sub-spikes (55 % height)
	var st := tip_y * 0.55
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(obs_w * 0.20, st), Vector2(obs_w * 0.36, 0),
	]), Color(3.0, 0.10, 0.12, 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(obs_w * 0.64, 0), Vector2(obs_w * 0.80, st), Vector2(obs_w, 0),
	]), Color(3.0, 0.10, 0.12, 0.88))

	# Main spike body
	if _gif_tex:
		var uvs : PackedVector2Array
		if not inverted:
			uvs = PackedVector2Array([Vector2(0,1), Vector2(0.5,0), Vector2(1,1)])
		else:
			uvs = PackedVector2Array([Vector2(0,0), Vector2(0.5,1), Vector2(1,0)])
		draw_polygon(pts, PackedColorArray([Color(1,1,1,0.90)]), uvs, _gif_tex)
	else:
		draw_colored_polygon(pts, Color(3.8, 0.15, 0.20, 1.0))

	# Barb notches along both edges (3 per side)
	for i in range(3):
		var t   := (float(i) + 0.5) / 3.0
		var lx  : float = lerp(0.0,     obs_w * 0.5, t)
		var rx  : float = lerp(obs_w,   obs_w * 0.5, t)
		var ey  : float = lerp(0.0,     tip_y, t)
		var nw  := obs_w * 0.06
		var nh  := obs_h * 0.10
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx, ey),
			Vector2(lx - nw, ey - tip_y * 0.12),
			Vector2(lx + nw * 0.4, ey),
		]), Color(5.0, 0.3, 0.3, 0.65))
		draw_colored_polygon(PackedVector2Array([
			Vector2(rx, ey),
			Vector2(rx + nw, ey - tip_y * 0.12),
			Vector2(rx - nw * 0.4, ey),
		]), Color(5.0, 0.3, 0.3, 0.65))

	# Neon hot outline
	draw_polyline(PackedVector2Array([
		Vector2(0, 0), Vector2(obs_w*0.5, tip_y), Vector2(obs_w, 0), Vector2(0, 0)
	]), Color(5.5, 0.55, 0.55, 1.0), 2.0)

	# White-hot pulsing tip
	var tip_glow := 0.6 + 0.4 * sin(pulse_t * 5.0)
	draw_circle(Vector2(obs_w * 0.5, tip_y), obs_h * 0.045 * (1.0 + tip_glow * 0.4),
	            Color(1.0, 0.85, 0.88, 0.95))

	# Inner specular streak
	draw_colored_polygon(PackedVector2Array([
		Vector2(obs_w*0.30, tip_y*0.08),
		Vector2(obs_w*0.50, tip_y*0.84),
		Vector2(obs_w*0.55, tip_y*0.08),
	]), Color(1.0, 0.90, 0.95, 0.22))

# ── Block ──────────────────────────────────────────────────────────────────────
func _draw_block() -> void:
	var r := Rect2(0, -obs_h, obs_w, obs_h)

	# Body
	if _gif_tex:
		draw_texture_rect(_gif_tex, r, false, Color(1, 1, 1, 0.90))
	else:
		draw_rect(r, Color(1.4, 0.15, 2.8, 1.0))

	# Internal grid lines for a heavy "studded wall" feel
	for i in range(1, 4):
		var gx := obs_w * float(i) / 4.0
		draw_line(Vector2(gx, -obs_h), Vector2(gx, 0), Color(0, 0, 0, 0.28), 1.0)
	draw_line(Vector2(0, -obs_h * 0.5), Vector2(obs_w, -obs_h * 0.5),
	          Color(0, 0, 0, 0.28), 1.0)

	# Crown spikes along top edge (5 spikes)
	var n_sp := 5
	for i in range(n_sp):
		var t  := (float(i) + 0.5) / float(n_sp)
		var sx := obs_w * t
		var sh := obs_h * 0.38
		var hw := obs_w * 0.065
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - hw, -obs_h),
			Vector2(sx,      -obs_h - sh),
			Vector2(sx + hw, -obs_h),
		]), Color(2.5, 0.3, 4.8, 0.92))
		draw_polyline(PackedVector2Array([
			Vector2(sx - hw, -obs_h),
			Vector2(sx,      -obs_h - sh),
			Vector2(sx + hw, -obs_h),
		]), Color(4.5, 0.8, 6.0, 1.0), 1.5)

	# Corner diagonal barbs
	var bs := obs_h * 0.26
	for corner : Vector2 in [Vector2(0, -obs_h), Vector2(obs_w, -obs_h)]:
		var dir := -1.0 if corner.x == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([
			corner,
			Vector2(corner.x + dir * bs * 0.7, corner.y - bs),
			Vector2(corner.x + dir * bs * 0.5, corner.y),
		]), Color(3.5, 0.5, 5.5, 0.85))

	# Animated crackle outline
	var ep := 0.65 + 0.35 * sin(pulse_t * 4.2)
	draw_rect(r, Color(3.5, 0.65, 6.0, ep), false, 2.5)

	# Top highlight shimmer
	draw_rect(Rect2(3, -obs_h + 3, obs_w - 6, (obs_h - 6) * 0.22), Color(1.0, 0.8, 1.0, 0.14))

# ── Rotating Saw Blade ─────────────────────────────────────────────────────────
func _draw_saw() -> void:
	var cx    : float = obs_w * 0.5
	var cy    : float = -obs_h * 0.5
	var r     : float = obs_w * 0.5
	var teeth : int   = 12

	# Outer danger halo — static pulsing ring of spines (counter-rotates slowly)
	var spine_count := 8
	var halo_r      := r * 1.28
	var halo_a      := 0.20 + 0.12 * sin(pulse_t * 2.2)
	for i in spine_count:
		var ang := -spin_t * 0.35 + float(i) / float(spine_count) * TAU
		var tip := Vector2(cx + cos(ang) * halo_r, cy + sin(ang) * halo_r)
		var base_l := Vector2(cx + cos(ang + 0.18) * r * 1.02,
		                      cy + sin(ang + 0.18) * r * 1.02)
		var base_r := Vector2(cx + cos(ang - 0.18) * r * 1.02,
		                      cy + sin(ang - 0.18) * r * 1.02)
		draw_colored_polygon(PackedVector2Array([base_l, tip, base_r]),
		                     Color(3.5, 0.15, 0.15, halo_a))

	# Main blade teeth
	var outer := PackedVector2Array()
	for i in teeth * 2:
		var ang := spin_t + float(i) * PI / float(teeth)
		var rad := r if i % 2 == 0 else r * 0.68
		outer.append(Vector2(cx + cos(ang) * rad, cy + sin(ang) * rad))

	# GIF fill
	if _gif_tex:
		var n   := 28
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in n:
			var ang := spin_t + float(i) / float(n) * TAU
			pts.append(Vector2(cx + cos(ang) * r * 0.94, cy + sin(ang) * r * 0.94))
			uvs.append(Vector2(0.5 + cos(ang) * 0.5, 0.5 + sin(ang) * 0.5))
		draw_polygon(pts, PackedColorArray([Color(1,1,1,0.88)]), uvs, _gif_tex)
	else:
		draw_colored_polygon(outer, Color(0.12, 0.12, 1.0, 1.0))

	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(0.5, 0.5, 4.5, 1.0), 1.8)

	# Blood-red razor tips on every other tooth
	for i in range(0, teeth * 2, 2):
		var a := outer[i]
		var b := outer[(i + 1) % outer.size()]
		var c := outer[(i + 2) % outer.size()]
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color(4.0, 0.08, 0.08, 0.70))

	# Spinning cross-brace inside (feels mechanical)
	for k in range(4):
		var ang := spin_t * 0.6 + float(k) * PI * 0.5
		draw_line(Vector2(cx + cos(ang) * r * 0.22, cy + sin(ang) * r * 0.22),
		          Vector2(cx + cos(ang) * r * 0.60, cy + sin(ang) * r * 0.60),
		          Color(0.3, 0.3, 2.5, 0.7), 2.0)

	# Hub ring + bolt
	draw_circle(Vector2(cx, cy), r * 0.28, Color(0.04, 0.04, 0.32, 1.0))
	draw_arc(Vector2(cx, cy), r * 0.28, 0, TAU, 20, Color(0.5, 0.5, 3.0, 1.0), 2.5)
	draw_circle(Vector2(cx, cy), r * 0.09, Color(0.95, 0.95, 1.0, 1.0))

# ── Trampoline Pad ────────────────────────────────────────────────────────────
func _draw_pad() -> void:
	# Color schemes: up-pads = cyan/blue, down-pads = orange/red
	var primary   : Color
	var secondary : Color
	var spring_colors : Array
	if pad_dir == 1:
		primary   = Color(0.05, 3.5, 2.5, 1.0)
		secondary = Color(0.0,  2.0, 4.5, 1.0)
		spring_colors = [Color(4.0,0.3,0.5,1.0),Color(4.5,1.5,0.0,1.0),Color(4.5,4.0,0.0,1.0),
		                 Color(0.2,4.5,0.5,1.0),Color(0.0,3.5,5.0,1.0),Color(3.5,0.5,5.0,1.0)]
	else:
		primary   = Color(5.0, 1.5, 0.0, 1.0)
		secondary = Color(4.0, 0.2, 0.1, 1.0)
		spring_colors = [Color(5.0,0.2,0.2,1.0),Color(5.0,1.0,0.0,1.0),Color(4.5,2.5,0.0,1.0),
		                 Color(3.5,0.1,0.1,1.0),Color(5.0,0.5,0.0,1.0),Color(4.0,0.0,0.2,1.0)]

	var b          := sin(pulse_t * 3.2)
	# For down-pads invert the animation so compression happens on the upper surface
	var bd         := b * float(pad_dir)
	var bounce_amt := obs_h * 0.16 * bd
	var bar_w      := 10.0
	var leg_thick  := obs_w * 0.045

	# All geometry is built in up-pad space then flipped by y_flip for down-pads.
	# y=0 is always the "base anchor" (ground contact for up, ceiling contact for down).
	var y_flip  : float = float(pad_dir)        # 1 = normal, -1 = flip
	var frame_y : float = -obs_h * 0.28 * y_flip
	var surf_y  : float = (-obs_h * 0.68 + bounce_amt) * y_flip
	var sag     : float = obs_h * 0.07 * bd

	# Base feet (at anchor line)
	draw_line(Vector2(0,            0.0), Vector2(obs_w * 0.16, 0.0), primary, bar_w)
	draw_line(Vector2(obs_w * 0.84, 0.0), Vector2(obs_w,        0.0), primary, bar_w)

	# Angled legs — filled gradient polygons
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

	# Horizontal frame bar
	draw_line(Vector2(obs_w * 0.18, frame_y), Vector2(obs_w * 0.82, frame_y), secondary, bar_w + 2.0)
	draw_circle(Vector2(obs_w * 0.18, frame_y), (bar_w + 2.0) * 0.5, secondary)
	draw_circle(Vector2(obs_w * 0.82, frame_y), (bar_w + 2.0) * 0.5, secondary)

	# Side poles
	draw_line(Vector2(obs_w * 0.18, frame_y), Vector2(obs_w * 0.12, surf_y), primary, 5.0)
	draw_line(Vector2(obs_w * 0.82, frame_y), Vector2(obs_w * 0.88, surf_y), primary, 5.0)

	# Rainbow springs
	for i in range(6):
		var sx : float = lerp(obs_w * 0.18, obs_w * 0.82, float(i) / 5.0)
		_draw_spring(sx, frame_y, surf_y, spring_colors[i], 4.5)

	# Gradient surface band — stacked rainbow strips + white gloss
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

	# Directional arrows (up or down depending on pad_dir)
	var arrow_alpha := clampf(-bd * 1.4, 0.0, 1.0)
	if arrow_alpha > 0.05:
		var arrow_cols : Array = [
			Color(spring_colors[0].r, spring_colors[0].g, spring_colors[0].b, arrow_alpha),
			Color(spring_colors[2].r, spring_colors[2].g, spring_colors[2].b, arrow_alpha),
			Color(spring_colors[4].r, spring_colors[4].g, spring_colors[4].b, arrow_alpha),
		]
		for i in range(3):
			var ax   := obs_w * (0.28 + i * 0.22)
			var a_y0 := surf_y - obs_h * 0.06 * y_flip
			var a_y1 := surf_y - obs_h * 0.30 * arrow_alpha * y_flip
			var aw   := obs_h * 0.10
			var ac : Color = arrow_cols[i]
			draw_line(Vector2(ax,      a_y0), Vector2(ax, a_y1), ac, 3.5)
			draw_line(Vector2(ax - aw, a_y1 + obs_h * 0.08 * y_flip), Vector2(ax, a_y1), ac, 3.5)
			draw_line(Vector2(ax + aw, a_y1 + obs_h * 0.08 * y_flip), Vector2(ax, a_y1), ac, 3.5)

	# Trajectory arc to next chained pad
	if has_meta("chain_next"):
		var cnext : Vector2 = get_meta("chain_next")
		var origin := Vector2(obs_w * 0.5, surf_y)
		var steps  := 20
		var prev   := origin
		var arc_col := Color(primary.r, primary.g, primary.b, 0.55)
		for si in range(1, steps + 1):
			var ft    := float(si) / float(steps)
			var lp    := origin + Vector2(cnext.x * ft, cnext.y * ft)
			# Parabola offset: rises then falls (or falls then rises for down-pads)
			var para  := -cnext.x * 0.5 * ft * (1.0 - ft) * float(pad_dir)
			lp.y      += para
			if si % 2 == 1:
				draw_line(prev, lp, Color(arc_col.r, arc_col.g, arc_col.b, arc_col.a * (1.0 - ft * 0.6)), 2.0)
			prev = lp

func _draw_spring(x: float, y_top: float, y_bottom: float, col: Color, width: float = 2.0) -> void:
	var segs   := 6
	var half_w := obs_w * 0.038
	var pts    := PackedVector2Array()
	for i in range(segs + 1):
		var t  := float(i) / float(segs)
		var y  : float = lerp(y_top, y_bottom, t)
		var xo := half_w * (1.0 if i % 2 == 0 else -1.0)
		pts.append(Vector2(x + xo, y))
	draw_polyline(pts, col, width)

# ── Jump Orb ──────────────────────────────────────────────────────────────────
func _draw_orb() -> void:
	var cx : float = obs_w * 0.5
	var cy : float = obs_h * 0.5
	var r  : float = obs_w * 0.5
	var pulse : float = 0.85 + 0.15 * sin(pulse_t * 2.8)
	# Outer aura
	draw_arc(Vector2(cx, cy), r * 1.12 * pulse, 0, TAU, 32,
	         Color(4.5, 4.0, 0.2, 0.28), 7.0)
	# GIF fill: circle polygon
	if _gif_tex:
		var n   := 24
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in n:
			var ang := float(i) / float(n) * TAU
			pts.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r))
			uvs.append(Vector2(0.5 + cos(ang) * 0.5, 0.5 + sin(ang) * 0.5))
		draw_polygon(pts, PackedColorArray([Color(1,1,1,0.90)]), uvs, _gif_tex)
	else:
		# Main body
		draw_circle(Vector2(cx, cy), r, Color(3.5, 3.0, 0.15, 1.0))
	# Inner ring
	draw_arc(Vector2(cx, cy), r * 0.68, 0, TAU, 24,
	         Color(5.5, 5.0, 0.3, 0.7), 3.5)
	# Star highlight
	draw_circle(Vector2(cx - r*0.28, cy - r*0.28), r * 0.22, Color(1.0, 1.0, 0.9, 0.85))
	draw_circle(Vector2(cx + r*0.10, cy + r*0.15), r * 0.10, Color(1.0, 1.0, 0.8, 0.50))

# ── Gravity Portal ────────────────────────────────────────────────────────────
func _draw_gravity_portal() -> void:
	# Spans from CEILING_Y downward (obs_h = play area height)
	if _gif_tex:
		draw_texture_rect(_gif_tex, Rect2(0, 0, obs_w, obs_h), false, Color(1,1,1,0.50))
	else:
		draw_rect(Rect2(0, 0, obs_w, obs_h), Color(1.0, 0.15, 2.2, 0.30))
	draw_rect(Rect2(0, 0, obs_w, obs_h), Color(2.5, 0.4, 4.5, 1.0), false, 2.0)
	# Animated chevrons (alternating up/down to show gravity flip)
	var half : float = obs_h * 0.5
	for i in 5:
		var t   : float = float(i) / 4.0
		var yy  : float = obs_h * 0.1 + t * obs_h * 0.8
		var dir : int   = 1 if i % 2 == 0 else -1
		var px  : float = pulse_t - float(i) * 0.5
		var alpha : float = 0.35 + 0.65 * abs(sin(px))
		var mid  : float = obs_w * 0.5
		var arm  : float = obs_w * 0.38
		var tip  : float = yy - dir * 10.0
		draw_line(Vector2(mid - arm, yy + dir * 10.0),
		          Vector2(mid,       tip),       Color(3.0, 0.4, 5.0, alpha), 2.5)
		draw_line(Vector2(mid + arm, yy + dir * 10.0),
		          Vector2(mid,       tip),       Color(3.0, 0.4, 5.0, alpha), 2.5)
	# Center line glow
	draw_line(Vector2(obs_w * 0.5, 0), Vector2(obs_w * 0.5, obs_h),
	          Color(2.5, 0.5, 4.5, 0.25), 4.0)

# ── Speed Portal ──────────────────────────────────────────────────────────────
func _draw_speed_portal() -> void:
	if _gif_tex:
		draw_texture_rect(_gif_tex, Rect2(0, 0, obs_w, obs_h), false, Color(1,1,1,0.50))
	else:
		draw_rect(Rect2(0, 0, obs_w, obs_h), Color(0.1, 1.2, 1.8, 0.28))
	draw_rect(Rect2(0, 0, obs_w, obs_h), Color(0.2, 3.0, 3.5, 1.0), false, 2.0)
	# Three animated chevrons sweeping right
	for row in 3:
		var base_y : float = obs_h * (0.25 + row * 0.25)
		for i in 3:
			var xoff  : float = fmod(pulse_t * 30.0 + float(i) * obs_w / 3.0, obs_w)
			var alpha : float = clampf(1.0 - xoff / obs_w, 0.0, 1.0)
			var arm   : float = obs_h * 0.08
			draw_line(Vector2(xoff, base_y - arm),
			          Vector2(xoff + obs_w * 0.18, base_y),
			          Color(0.3, 3.5, 4.0, alpha * 0.8), 2.5)
			draw_line(Vector2(xoff, base_y + arm),
			          Vector2(xoff + obs_w * 0.18, base_y),
			          Color(0.3, 3.5, 4.0, alpha * 0.8), 2.5)

# ── Diamond ────────────────────────────────────────────────────────────────────
func _draw_diamond() -> void:
	var cx  : float = obs_w * 0.5
	var cy  : float = -obs_h * 0.5
	var pts := PackedVector2Array([
		Vector2(cx,    -obs_h),
		Vector2(obs_w, -obs_h * 0.5),
		Vector2(cx,     0),
		Vector2(0,     -obs_h * 0.5),
	])

	# Pulsing star-point spikes from each vertex
	var sp := obs_h * 0.32 * (0.88 + 0.12 * sin(pulse_t * 3.5))
	var spike_verts := [
		[Vector2(cx, -obs_h),         Vector2(cx, -obs_h - sp)],           # top
		[Vector2(obs_w, -obs_h*0.5),  Vector2(obs_w + sp * 0.7, -obs_h*0.5)],  # right
		[Vector2(cx, 0),              Vector2(cx, sp * 0.7)],               # bottom
		[Vector2(0, -obs_h*0.5),      Vector2(-sp * 0.7, -obs_h*0.5)],    # left
	]
	var hw := obs_w * 0.08
	for sv in spike_verts:
		var base : Vector2 = sv[0]
		var tip  : Vector2 = sv[1]
		var perp := (tip - base).orthogonal().normalized() * hw
		draw_colored_polygon(PackedVector2Array([base - perp, tip, base + perp]),
		                     Color(0.15, 4.5, 1.2, 0.85))
		draw_line(base, tip, Color(0.4, 6.0, 2.0, 1.0), 2.0)

	# Diamond body
	if _gif_tex:
		draw_polygon(pts,
			PackedColorArray([Color(1,1,1,0.90)]),
			PackedVector2Array([Vector2(0.5,0), Vector2(1,0.5), Vector2(0.5,1), Vector2(0,0.5)]),
			_gif_tex)
	else:
		draw_colored_polygon(pts, Color(0.15, 3.2, 0.85, 1.0))

	# Diagonal sub-spikes (star pattern between main vertices)
	var diag_len := obs_h * 0.22
	for k in range(4):
		var ang := spin_t * 0.0 + float(k) * PI * 0.5 + PI * 0.25
		var origin := Vector2(cx + cos(ang) * obs_h * 0.32, cy + sin(ang) * obs_h * 0.32)
		var tip2   := origin + Vector2(cos(ang), sin(ang)) * diag_len
		draw_line(origin, tip2, Color(0.3, 5.5, 1.8, 0.75), 1.8)

	# Animated energy crack through center
	var crack_a : float = 0.45 + 0.35 * absf(sin(pulse_t * 4.5))
	draw_line(Vector2(cx, -obs_h * 0.82), Vector2(cx, -obs_h * 0.18),
	          Color(0.6, 6.0, 2.5, crack_a), 1.5)
	draw_line(Vector2(obs_w * 0.22, -obs_h * 0.5), Vector2(obs_w * 0.78, -obs_h * 0.5),
	          Color(0.6, 6.0, 2.5, crack_a * 0.7), 1.5)

	# Bright neon outline
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
	              Color(0.5, 6.0, 2.0, 1.0), 2.0)

	# Facet highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx * 0.78, -obs_h * 0.82),
		Vector2(cx,         -obs_h * 0.52),
		Vector2(cx * 1.22, -obs_h * 0.82),
	]), Color(1.0, 1.0, 1.0, 0.18))

# ── Ceiling Block ──────────────────────────────────────────────────────────────
func _draw_ceil_block() -> void:
	var r := Rect2(0, 0, obs_w, obs_h)

	if _gif_tex:
		draw_texture_rect(_gif_tex, r, false, Color(1,1,1,0.90))
	else:
		draw_rect(r, Color(0.12, 0.85, 3.0, 1.0))

	# Internal grid
	for i in range(1, 4):
		var gx := obs_w * float(i) / 4.0
		draw_line(Vector2(gx, 0), Vector2(gx, obs_h), Color(0, 0, 0, 0.25), 1.0)
	draw_line(Vector2(0, obs_h * 0.5), Vector2(obs_w, obs_h * 0.5), Color(0, 0, 0, 0.25), 1.0)

	# Downward crown spikes (5 spikes hanging from bottom)
	var n_sp := 5
	for i in range(n_sp):
		var t  := (float(i) + 0.5) / float(n_sp)
		var sx := obs_w * t
		var sh := obs_h * 0.38
		var hw := obs_w * 0.065
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - hw, obs_h),
			Vector2(sx,      obs_h + sh),
			Vector2(sx + hw, obs_h),
		]), Color(0.3, 2.0, 5.0, 0.92))
		draw_polyline(PackedVector2Array([
			Vector2(sx - hw, obs_h),
			Vector2(sx,      obs_h + sh),
			Vector2(sx + hw, obs_h),
		]), Color(0.6, 3.5, 6.5, 1.0), 1.5)

	# Corner barbs (downward)
	var bs := obs_h * 0.26
	for corner : Vector2 in [Vector2(0, obs_h), Vector2(obs_w, obs_h)]:
		var dir := -1.0 if corner.x == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([
			corner,
			Vector2(corner.x + dir * bs * 0.7, corner.y + bs),
			Vector2(corner.x + dir * bs * 0.5, corner.y),
		]), Color(0.4, 2.5, 5.5, 0.85))

	# Animated crackle outline
	var ep := 0.65 + 0.35 * sin(pulse_t * 4.2)
	draw_rect(r, Color(0.5, 2.5, 6.0, ep), false, 2.5)
	draw_rect(Rect2(3, 3, obs_w - 6, obs_h * 0.22), Color(1.0, 0.9, 1.0, 0.12))

# ── Ceiling Saw ────────────────────────────────────────────────────────────────
func _draw_ceil_saw() -> void:
	var cx    : float = obs_w * 0.5
	var cy    : float = obs_h * 0.5
	var r     : float = obs_h * 0.5
	var teeth : int   = 12

	# Outer danger halo (same as floor saw, counter-rotates)
	var spine_count := 8
	var halo_r      := r * 1.28
	var halo_a      := 0.20 + 0.12 * sin(pulse_t * 2.2)
	for i in spine_count:
		var ang := -spin_t * 0.35 + float(i) / float(spine_count) * TAU
		var tip := Vector2(cx + cos(ang) * halo_r, cy + sin(ang) * halo_r)
		var bl  := Vector2(cx + cos(ang + 0.18) * r * 1.02, cy + sin(ang + 0.18) * r * 1.02)
		var br  := Vector2(cx + cos(ang - 0.18) * r * 1.02, cy + sin(ang - 0.18) * r * 1.02)
		draw_colored_polygon(PackedVector2Array([bl, tip, br]), Color(3.5, 0.15, 0.15, halo_a))

	var outer := PackedVector2Array()
	for i in teeth * 2:
		var ang := spin_t + float(i) * PI / float(teeth)
		var rad := r if i % 2 == 0 else r * 0.68
		outer.append(Vector2(cx + cos(ang) * rad, cy + sin(ang) * rad))

	if _gif_tex:
		var n   := 28
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in n:
			var ang := spin_t + float(i) / float(n) * TAU
			pts.append(Vector2(cx + cos(ang)*r*0.94, cy + sin(ang)*r*0.94))
			uvs.append(Vector2(0.5 + cos(ang)*0.5,  0.5 + sin(ang)*0.5))
		draw_polygon(pts, PackedColorArray([Color(1,1,1,0.88)]), uvs, _gif_tex)
	else:
		draw_colored_polygon(outer, Color(0.12, 0.12, 1.0, 1.0))

	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(0.5, 0.5, 4.5, 1.0), 1.8)
	for i in range(0, teeth * 2, 2):
		var a := outer[i];  var b := outer[(i+1) % outer.size()];  var c := outer[(i+2) % outer.size()]
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color(4.0, 0.08, 0.08, 0.70))
	for k in range(4):
		var ang := spin_t * 0.6 + float(k) * PI * 0.5
		draw_line(Vector2(cx + cos(ang)*r*0.22, cy + sin(ang)*r*0.22),
		          Vector2(cx + cos(ang)*r*0.60, cy + sin(ang)*r*0.60),
		          Color(0.3, 0.3, 2.5, 0.7), 2.0)
	draw_circle(Vector2(cx, cy), r * 0.28, Color(0.04, 0.04, 0.32, 1.0))
	draw_arc(Vector2(cx, cy), r * 0.28, 0, TAU, 20, Color(0.5, 0.5, 3.0, 1.0), 2.5)
	draw_circle(Vector2(cx, cy), r * 0.09, Color(0.95, 0.95, 1.0, 1.0))
	# Ceiling mount bar
	draw_line(Vector2(cx, 0), Vector2(cx, cy - r), Color(0.3, 0.3, 1.8, 0.90), 3.5)
