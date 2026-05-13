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
	if obs_type != "pad":
		_add_light()

func _add_light() -> void:
	light = PointLight2D.new()
	var ceil_type := obs_type in ["ceil_block", "ceil_saw"]
	light.position = Vector2(obs_w * 0.5, obs_h * 0.5 if ceil_type else -obs_h * 0.5)
	light.energy   = 2.0
	light.texture_scale = 3.2
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
	# Solid opaque core + soft outer edge — looks like the chunky GIF mock,
	# not a translucent smooth fade. Inner 55% radius is fully opaque, outer
	# 45% does a quadratic falloff to zero.
	var size := 128
	var inner := 0.55
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for xi in size:
		for yi in size:
			var dx := (xi - size * 0.5) / (size * 0.5)
			var dy := (yi - size * 0.5) / (size * 0.5)
			var d  := sqrt(dx*dx + dy*dy)
			var a : float
			if d < inner:
				a = 1.0
			elif d > 1.0:
				a = 0.0
			else:
				var t := (1.0 - d) / (1.0 - inner)
				a = t * t
			img.set_pixel(xi, yi, Color(1, 1, 1, a))
	light.texture = ImageTexture.create_from_image(img)
	add_child(light)

func _process(delta: float) -> void:
	pulse_t += delta * 3.5
	spin_t  += delta * (5.5 if obs_type in ["saw", "ceil_saw"] else 1.8)
	if gif_anim != null:
		_gif_tex = gif_anim.advance(delta)
	queue_redraw()

func _draw() -> void:
	# Every obstacle type — including pads, orbs, diamonds, portals — renders
	# as the assigned GIF subject silhouette when polygon + texture are ready.
	# Procedural shape draws below are emergency fallbacks only.
	if _draw_subject_gif():
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
	var is_ceil := obs_type in ["ceil_block", "ceil_saw", "ceil_spike"] \
		or (obs_type == "pad" and pad_dir < 0)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in poly:
		var lx := float(p.x) * obs_w
		var ly := float(p.y) * obs_h - (0.0 if is_ceil else obs_h)
		pts.append(Vector2(lx, ly))
		uvs.append(Vector2(float(p.x), float(p.y)))

	# Silhouette-shaped halo — outward-scaled copies of the subject's polygon
	# so the aura hugs the GIF contour like in the mock.
	var nc := _neon_color()
	_draw_silhouette_halo(pts, nc)

	# Soft elliptical ground (or ceiling) shadow
	var shadow_y := (obs_h - 1.0) if is_ceil else 1.0
	_draw_ground_shadow(Vector2(obs_w * 0.5, shadow_y), obs_w * 0.55, obs_h * 0.12)

	# GIF over photo background — no outline, no black backing
	draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 1.0)]), uvs, tex)

	return true

func _saturated_role(role: Color) -> Color:
	# Normalize HDR role colors to a saturated SDR mid-tone (brightest channel
	# = 0.85). Mock palette is sRGB-saturated, not HDR — this matches it.
	var m = max(role.r, max(role.g, role.b))
	var s = 0.85 / m if m > 0.001 else 1.0
	return Color(role.r * s, role.g * s, role.b * s, 1.0)

func _draw_radial_halo(center: Vector2, radius: float, role: Color) -> void:
	# Stacked discs — 3 layers × 14 segments (was 10 × 28). Same banded vibe,
	# ~10× fewer vertices.
	var layers := 3
	var steps  := 14
	var rc := _saturated_role(role)
	for i in range(layers, 0, -1):
		var t := float(i) / float(layers)
		var r := radius * t
		var a := 0.50 * pow(1.0 - t, 1.6)
		var ring := PackedVector2Array()
		for j in steps:
			var ang := TAU * float(j) / float(steps)
			ring.append(center + Vector2(cos(ang) * r, sin(ang) * r))
		draw_polygon(ring, PackedColorArray([Color(rc.r, rc.g, rc.b, a)]))

func _draw_silhouette_halo(pts: PackedVector2Array, role: Color) -> void:
	# Outward-scaled copies of the subject polygon. 2 layers (was 5) — chunky
	# banded look, much cheaper to render.
	if pts.is_empty(): return
	var centroid := Vector2.ZERO
	for p in pts: centroid += p
	centroid /= float(pts.size())
	var rc := _saturated_role(role)
	var scales := [1.65, 1.20]
	var alphas := [0.28, 0.60]
	for i in scales.size():
		var sc : float = scales[i]
		var a  : float = alphas[i]
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(centroid + (p - centroid) * sc)
		draw_polygon(scaled, PackedColorArray([Color(rc.r, rc.g, rc.b, a)]))

func _draw_ground_shadow(center: Vector2, rx: float, ry: float) -> void:
	# Single static ellipse (was 3 stacked layers with pulse animation).
	var steps := 14
	var ring := PackedVector2Array()
	for i in steps:
		var ang := TAU * float(i) / float(steps)
		ring.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polygon(ring, PackedColorArray([Color(0, 0, 0, 0.32)]))

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

	# Silhouette-shaped halo behind spike + ground shadow at base
	var nc := _neon_color()
	_draw_silhouette_halo(pts, nc)
	_draw_ground_shadow(Vector2(obs_w * 0.5, 0.0), obs_w * 0.55, obs_h * 0.12)

	# Main spike body (toned, no HDR blowout)
	if _gif_tex:
		var uvs : PackedVector2Array
		if not inverted:
			uvs = PackedVector2Array([Vector2(0,1), Vector2(0.5,0), Vector2(1,1)])
		else:
			uvs = PackedVector2Array([Vector2(0,0), Vector2(0.5,1), Vector2(1,0)])
		draw_polygon(pts, PackedColorArray([Color(1,1,1,0.95)]), uvs, _gif_tex)
	else:
		draw_colored_polygon(pts, Color(0.12, 0.12, 0.14, 1.0))

# ── Block ──────────────────────────────────────────────────────────────────────
func _draw_block() -> void:
	var r := Rect2(0, -obs_h, obs_w, obs_h)

	# Silhouette halo around the block + ground shadow
	var nc := _neon_color()
	var block_pts := PackedVector2Array([
		Vector2(0, -obs_h), Vector2(obs_w, -obs_h),
		Vector2(obs_w, 0),  Vector2(0, 0)
	])
	_draw_silhouette_halo(block_pts, nc)
	_draw_ground_shadow(Vector2(obs_w * 0.5, 0.0), obs_w * 0.55, obs_h * 0.12)

	# Body
	if _gif_tex:
		draw_texture_rect(_gif_tex, r, false, Color(1, 1, 1, 0.95))
	else:
		draw_rect(r, Color(0.12, 0.12, 0.14, 1.0))

	# Internal grid lines for a heavy "studded wall" feel
	for i in range(1, 4):
		var gx := obs_w * float(i) / 4.0
		draw_line(Vector2(gx, -obs_h), Vector2(gx, 0), Color(0, 0, 0, 0.28), 1.0)
	draw_line(Vector2(0, -obs_h * 0.5), Vector2(obs_w, -obs_h * 0.5),
	          Color(0, 0, 0, 0.28), 1.0)

# ── Rotating Saw Blade ─────────────────────────────────────────────────────────
func _draw_saw() -> void:
	var cx    : float = obs_w * 0.5
	var cy    : float = -obs_h * 0.5
	var r     : float = obs_w * 0.5
	var teeth : int   = 12

	# Radial halo + ground shadow under saw
	_draw_radial_halo(Vector2(cx, cy), r * 2.4, _neon_color())
	_draw_ground_shadow(Vector2(cx, 0.0), r * 1.1, obs_h * 0.10)

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
# Minimal flat bar + single arrow. No springs, frame, rainbow band, trajectory
# arc or PointLight2D — saves ~30 draw calls per pad per frame.
func _draw_pad() -> void:
	var y_flip  : float = float(pad_dir)
	var surf_y  : float = -obs_h * 0.55 * y_flip
	var pad_col : Color = Color(0.10, 0.78, 0.85, 1.0) if pad_dir == 1 \
		else Color(0.95, 0.42, 0.10, 1.0)

	# Flat platform
	var bar_h := obs_h * 0.14
	draw_rect(Rect2(0, surf_y - bar_h * 0.5, obs_w, bar_h), pad_col)

	# Single chevron arrow indicating bounce direction
	var ax := obs_w * 0.5
	var a_y0 := surf_y - bar_h * 0.5 * y_flip
	var a_y1 := surf_y - obs_h * 0.30 * y_flip
	var aw   := obs_w * 0.18
	draw_line(Vector2(ax - aw, a_y1 + bar_h * y_flip), Vector2(ax, a_y1), pad_col, 3.0)
	draw_line(Vector2(ax + aw, a_y1 + bar_h * y_flip), Vector2(ax, a_y1), pad_col, 3.0)

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

	# Silhouette halo + ceiling shadow
	var nc := _neon_color()
	var cblock_pts := PackedVector2Array([
		Vector2(0, 0),     Vector2(obs_w, 0),
		Vector2(obs_w, obs_h), Vector2(0, obs_h)
	])
	_draw_silhouette_halo(cblock_pts, nc)
	_draw_ground_shadow(Vector2(obs_w * 0.5, obs_h), obs_w * 0.55, obs_h * 0.12)

	if _gif_tex:
		draw_texture_rect(_gif_tex, r, false, Color(1,1,1,0.95))
	else:
		draw_rect(r, Color(0.12, 0.12, 0.14, 1.0))

	# Internal grid
	for i in range(1, 4):
		var gx := obs_w * float(i) / 4.0
		draw_line(Vector2(gx, 0), Vector2(gx, obs_h), Color(0, 0, 0, 0.25), 1.0)
	draw_line(Vector2(0, obs_h * 0.5), Vector2(obs_w, obs_h * 0.5), Color(0, 0, 0, 0.25), 1.0)

# ── Ceiling Saw ────────────────────────────────────────────────────────────────
func _draw_ceil_saw() -> void:
	var cx    : float = obs_w * 0.5
	var cy    : float = obs_h * 0.5
	var r     : float = obs_h * 0.5
	var teeth : int   = 12

	# Radial halo + ceiling shadow under saw
	_draw_radial_halo(Vector2(cx, cy), r * 2.4, _neon_color())
	_draw_ground_shadow(Vector2(cx, obs_h), r * 1.1, obs_h * 0.10)

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
