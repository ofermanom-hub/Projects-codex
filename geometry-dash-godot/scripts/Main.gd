extends Node2D

# ── Screen / physics constants ─────────────────────────────────────────────
const SW         = 1280
const SH         = 720
const GROUND_Y   = 670
const CEILING_Y  = 80
const PLAYER_X   = 200
const PW         = 52.0
const PH         = 52.0
const GRAVITY    = 2800.0
const JUMP_VEL   = -960.0
const MAX_JUMPS  = 3
const GLIDE_GRAV = 0.14   # fraction of gravity applied while gliding
const BASE_SPEED = 420.0
const MAX_SPEED  = 1100.0
const OBS_SCALE         = 4.0    # scale up obstacles so GIFs are clearly visible
const BG_CYCLE_INTERVAL = 8.0

# ── Obstacle patterns ──────────────────────────────────────────────────────
# "t"    : type string
# "dx"   : x offset from spawn edge (added to SW+80)
# "w/h"  : width / height
# "pos_y": absolute world y (overrides default anchor)
# Ceiling spikes and gravity/speed portals auto-anchor to CEILING_Y
const PATTERNS : Array = [
	# 0-9  Easy — always spawnable ──────────────────────────────────────────
	[{"t":"pad",  "dx":0,"w":54,"h":22}],
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"pad","dx":230,"w":54,"h":22}],
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"pad","dx":240,"w":54,"h":22},{"t":"pad","dx":480,"w":54,"h":22}],
	[{"t":"spike","dx":0,"w":52,"h":52}],
	[{"t":"block","dx":0,"w":52,"h":52}],
	[{"t":"diamond","dx":0,"w":60,"h":60}],
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"spike","dx":280,"w":52,"h":52}],
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"diamond","dx":290,"w":60,"h":60}],
	[{"t":"spike","dx":0,"w":52,"h":52},{"t":"spike","dx":230,"w":52,"h":52}],
	[{"t":"orb",  "dx":50,"w":44,"h":44,"pos_y":500}],
	# 10-19  Medium ──────────────────────────────────────────────────────────
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"pad","dx":230,"w":54,"h":22},{"t":"spike","dx":460,"w":52,"h":52}],
	[{"t":"ceil_block","dx":0,"w":90,"h":150}],
	[{"t":"ceil_saw","dx":0,"w":80,"h":140}],
	[{"t":"diamond","dx":0,"w":60,"h":60},{"t":"diamond","dx":260,"w":60,"h":60}],
	[{"t":"saw",  "dx":0,"w":60,"h":60}],
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"ceil_block","dx":210,"w":90,"h":150}],
	[{"t":"block","dx":0,"w":52,"h":52},{"t":"spike","dx":230,"w":52,"h":52}],
	[{"t":"orb",  "dx":40,"w":44,"h":44,"pos_y":500},{"t":"diamond","dx":230,"w":60,"h":60}],
	[{"t":"ceil_spike","dx":0,"w":52,"h":120}],
	[{"t":"pad",  "dx":0,"w":54,"h":22},{"t":"orb","dx":210,"w":44,"h":44,"pos_y":500}],
	# 20-27  Hard ────────────────────────────────────────────────────────────
	[{"t":"saw",  "dx":0,"w":60,"h":60},{"t":"spike","dx":260,"w":52,"h":52}],
	[{"t":"spike","dx":0,"w":52,"h":52},{"t":"ceil_spike","dx":30,"w":52,"h":120}],
	[{"t":"ceil_spike","dx":0,"w":52,"h":120},{"t":"ceil_spike","dx":80,"w":52,"h":120}],
	[{"t":"ceil_saw","dx":0,"w":80,"h":140},{"t":"spike","dx":100,"w":52,"h":52}],
	[{"t":"diamond","dx":0,"w":60,"h":60},{"t":"ceil_block","dx":30,"w":90,"h":170},{"t":"diamond","dx":260,"w":60,"h":60}],
	[{"t":"block","dx":0,"w":52,"h":104}],
	# Portals — late game ────────────────────────────────────────────────────
	[{"t":"speed_portal","dx":0,"w":28,"h":360}],
	[{"t":"gravity_portal","dx":0,"w":28,"h":360}],
]

# ── Chain patterns ─────────────────────────────────────────────────────────
# Physics-verified at BASE_SPEED=420, GRAVITY=2800, JUMP_VEL=-960.
# "bounce": multiplier on JUMP_VEL (default 1.90). Chain pads use smaller
# values so mid-air bounces stay on screen.
# "chain_next":[dx,dy] is offset to next pad for arc drawing.
const CHAIN_PATTERNS : Array = [
	# A — ground triple bounce (up→up→up, t=1.31s per hop, dx≈550)
	[{"t":"pad","dx":0,   "w":64,"h":26,"pos_y":670,"dir":1,"bounce":1.90,"chain_next":[550,0]},
	 {"t":"pad","dx":550, "w":64,"h":26,"pos_y":670,"dir":1,"bounce":1.90,"chain_next":[550,0]},
	 {"t":"pad","dx":1100,"w":64,"h":26,"pos_y":670,"dir":1,"bounce":1.90}],
	# B — ground→ceiling→ground (up→down→up, dx=190+104=294)
	[{"t":"pad","dx":0,  "w":64,"h":26,"pos_y":670,"dir":1, "bounce":1.90,"chain_next":[190,-590]},
	 {"t":"pad","dx":190,"w":64,"h":26,"pos_y":80, "dir":-1,"bounce":1.90,"chain_next":[104, 590]},
	 {"t":"pad","dx":294,"w":64,"h":26,"pos_y":670,"dir":1, "bounce":1.90}],
	# C — ascending staircase (soft 1.0x bounce, 3 mid-screen hops then back to ground)
	[{"t":"pad","dx":0,  "w":64,"h":26,"pos_y":670,"dir":1,"bounce":1.00,"chain_next":[200,-140]},
	 {"t":"pad","dx":200,"w":64,"h":26,"pos_y":530,"dir":1,"bounce":1.00,"chain_next":[200,-140]},
	 {"t":"pad","dx":400,"w":64,"h":26,"pos_y":390,"dir":1,"bounce":1.00,"chain_next":[380, 280]},
	 {"t":"pad","dx":780,"w":64,"h":26,"pos_y":670,"dir":1,"bounce":1.90}],
	# D — ground→mid-air down-pad→ground (full-speed redirect, dx=87+65=152)
	[{"t":"pad","dx":0,  "w":64,"h":26,"pos_y":670,"dir":1, "bounce":1.90,"chain_next":[87,-370]},
	 {"t":"pad","dx":87, "w":64,"h":26,"pos_y":300,"dir":-1,"bounce":1.90,"chain_next":[65, 370]},
	 {"t":"pad","dx":152,"w":64,"h":26,"pos_y":670,"dir":1, "bounce":1.90}],
]

const LEVEL_LENGTH : int = 1000

const ObstacleScript = preload("res://scripts/Obstacle.gd")

# Indices within PATTERNS that contain at least one pad obstacle
const PAD_PATTERN_INDICES : Array = [0, 1, 2, 6, 7, 10, 15, 19]

# Primary category for every non-pad PATTERN index (used for weighted picking)
const PATTERN_CATEGORY : Array = [
	"pad","pad","pad",          # 0-2
	"spike","block","diamond",  # 3-5
	"pad","pad",                # 6-7
	"spike","orb",              # 8-9
	"pad",                      # 10
	"ceil","ceil",              # 11-12
	"diamond","saw",            # 13-14
	"pad","spike",              # 15-16
	"orb","ceil",               # 17-18
	"pad","spike",              # 19-20
	"spike","ceil","ceil",      # 21-23
	"diamond","block",          # 24-25
	"portal","portal",          # 26-27
]

# ── Spawn tuning (live-tweakable via Tab panel) ───────────────────────────
var chain_prob       : float = 0.15   # probability of spawning a chain pattern
var pad_pattern_prob : float = 0.40   # probability of picking a pad-containing normal pattern
var obs_freq         : int   = 8      # 1-10; maps to spawn gap via lerp(5.0, 0.6, (f-1)/9)
var height_var       : float = 0.60   # 0-1; chance a floor obstacle spawns at random height

# Per-category obstacle weights (default 1.0 = equal chance)
var obs_weights : Dictionary = {
	"spike": 1.0, "block": 1.0, "diamond": 1.0,
	"saw":   1.0, "orb":   1.0, "ceil":    1.0, "portal": 0.5,
}

# ── Game state ─────────────────────────────────────────────────────────────
enum GS { MENU, PLAYING, DEAD, COMPLETE }
var gs       : GS    = GS.MENU
var score    : int   = 0
var best     : int   = 0
var attempts : int   = 0
var elapsed  : float = 0.0
var speed    : float = BASE_SPEED
var bg_hue   : float = 0.6

# ── Player physics ─────────────────────────────────────────────────────────
var py           : float = GROUND_Y - PH
var pvy          : float = 0.0
var prot         : float = 0.0
var jumps        : int   = 0
var was_on_ground : bool = true
var gravity_dir  : float = 1.0   # 1 = normal, -1 = flipped

# ── Orb proximity tracking ─────────────────────────────────────────────────
var _near_orb : Dictionary = {}

# ── Obstacles ──────────────────────────────────────────────────────────────
var obs_data    : Array = []
var spawn_timer : float = 1.0

# ── Node refs ──────────────────────────────────────────────────────────────
@onready var shake_root    : Node2D      = $ShakeRoot
@onready var obs_container : Node2D      = $ShakeRoot/ObstacleContainer
@onready var player_node   : Node2D      = $ShakeRoot/Player
@onready var bg_node       : Node2D      = $Background
@onready var hud_node      : CanvasLayer = $HUD
@onready var flash_rect    : ColorRect   = $FlashLayer/FlashRect
@onready var audio_mgr     : Node        = $AudioManager

var shake_trauma : float = 0.0
var _gifs_ready      : bool  = false
var is_gliding       : bool  = false
var _bg_cycle_timer  : float = 0.0

# ── Ready ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	GifPool.pool_ready.connect(_on_gifs_ready)
	hud_node.chain_prob_changed.connect(func(v): chain_prob = v)
	hud_node.pad_prob_changed.connect(func(v): pad_pattern_prob = v)
	hud_node.obs_freq_changed.connect(func(v): obs_freq = v)
	hud_node.height_var_changed.connect(func(v): height_var = v)
	hud_node.obs_weight_changed.connect(func(cat, v): obs_weights[cat] = v)
	hud_node.show_menu()

# ── Input ──────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			hud_node.toggle_tuning()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F, KEY_F11]:
			var mode := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
			pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	match gs:
		GS.MENU:     _start_game()
		GS.PLAYING:  _do_jump()
		GS.DEAD:     _reset_game()
		GS.COMPLETE: _reset_game()

# ── GIF pool ───────────────────────────────────────────────────────────────
func _on_gifs_ready() -> void:
	_gifs_ready = true
	bg_node.sky_gif = GifPool.get_background_gif()

# ── State transitions ──────────────────────────────────────────────────────
func _start_game() -> void:
	gs = GS.PLAYING
	attempts += 1
	elapsed = 0.0;  score = 0
	speed = BASE_SPEED
	spawn_timer = 1.0
	_bg_cycle_timer = 0.0
	gravity_dir = 1.0
	if _gifs_ready:
		GifPool.assign_session_gifs()
		bg_node.sky_gif = GifPool.get_background_gif()
	hud_node.hide_menu()
	hud_node.update_attempt(attempts)
	audio_mgr.start_music()

func _reset_game() -> void:
	for od in obs_data:
		od["node"].queue_free()
	obs_data.clear()
	py = GROUND_Y - PH;  pvy = 0.0;  prot = 0.0;  jumps = 0
	was_on_ground = true;  gravity_dir = 1.0;  _near_orb = {}
	player_node.reset_visual()
	player_node.set_gravity(1.0)
	gs = GS.PLAYING
	attempts += 1
	elapsed = 0.0;  score = 0
	speed = BASE_SPEED
	spawn_timer = 1.0
	_bg_cycle_timer = 0.0
	shake_trauma = 0.0
	shake_root.position = Vector2.ZERO
	flash_rect.color.a = 0.0
	hud_node.hide_dead()
	hud_node.hide_complete()
	hud_node.update_attempt(attempts)
	audio_mgr.start_music()

func _do_jump() -> void:
	# Orb takes priority over normal jump
	if not _near_orb.is_empty() and not _near_orb.get("triggered", false):
		pvy = JUMP_VEL * 1.30 * gravity_dir
		jumps = mini(jumps + 1, MAX_JUMPS)
		_near_orb["triggered"] = true
		player_node.emit_jump(jumps >= 2, bg_hue)
		audio_mgr.play_jump(jumps >= 2)
		return
	if jumps < MAX_JUMPS:
		pvy = (JUMP_VEL - float(jumps) * 80.0) * gravity_dir
		jumps += 1
		player_node.emit_jump(jumps >= 2, bg_hue)
		audio_mgr.play_jump(jumps >= 2)

# ── Process ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_update_shake(delta)
	bg_hue = fmod(bg_hue + delta * 0.04, 1.0)
	bg_node.bg_update(delta, speed if gs == GS.PLAYING else BASE_SPEED * 0.25, bg_hue)

	if gs != GS.PLAYING:
		return

	elapsed += delta
	score    = int(elapsed * 12.0)
	speed    = minf(BASE_SPEED + float(score) * 0.55, MAX_SPEED)

	# Background cycling
	_bg_cycle_timer += delta
	if _bg_cycle_timer >= BG_CYCLE_INTERVAL and _gifs_ready:
		_bg_cycle_timer = 0.0
		bg_node.sky_gif = GifPool.cycle_background_gif()

	# ── Player physics ────────────────────────────────────────────────────
	var space_held := (Input.is_key_pressed(KEY_SPACE) or
	                   Input.is_key_pressed(KEY_UP) or
	                   Input.is_key_pressed(KEY_W))
	is_gliding = space_held and jumps > 0

	var grav_mult := GLIDE_GRAV if is_gliding else 1.0
	pvy += GRAVITY * gravity_dir * delta * grav_mult
	# Cap descent speed while gliding
	if is_gliding and pvy * gravity_dir > 100.0:
		pvy = 100.0 * gravity_dir

	py  += pvy * delta

	var on_ground : bool = false
	if gravity_dir > 0:
		if py >= GROUND_Y - PH:
			py = GROUND_Y - PH;  pvy = 0.0;  jumps = 0
			on_ground = true
		elif py < float(CEILING_Y):
			py = float(CEILING_Y);  pvy = 0.0
	else:
		if py <= float(CEILING_Y):
			py = float(CEILING_Y);  pvy = 0.0;  jumps = 0
			on_ground = true
		elif py > GROUND_Y - PH:
			py = GROUND_Y - PH;  pvy = 0.0

	# Landing squash
	if on_ground and not was_on_ground:
		player_node.land_squash()
	was_on_ground = on_ground

	# Velocity-based tilt (cats lean naturally)
	prot = clampf(pvy * 0.020, -22.0, 22.0)
	player_node.update_visual(py, prot, speed, bg_hue, delta, is_gliding)

	# ── Obstacles ─────────────────────────────────────────────────────────
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn()
		var gap_center    : float = lerpf(5.0, 0.6, float(obs_freq - 1) / 9.0)
		var gap_reduction : float = clampf(float(score) / 2000.0, 0.0, 0.60)
		spawn_timer = randf_range(gap_center - 0.7, gap_center + 0.7) - gap_reduction

	var kept : Array = []
	for od in obs_data:
		od["x"] -= speed * delta
		od["node"].position.x = od["x"]
		if od["t"] not in ["gravity_portal", "speed_portal"]:
			var fy : float = float(od["base_y"]) + sin(elapsed * 2.2 + float(od["float_phase"])) * 15.0
			od["node"].position.y = fy
			od["y"] = fy
		if od["x"] > -200.0:
			kept.append(od)
		else:
			od["node"].queue_free()
	obs_data = kept

	_check_interactions()
	_check_collisions()

	var pct : float = clampf(float(score) / LEVEL_LENGTH, 0.0, 1.0)
	hud_node.update_score(score, best, pct)
	if score >= LEVEL_LENGTH and gs == GS.PLAYING:
		_level_complete()

# ── Camera shake ───────────────────────────────────────────────────────────
func _update_shake(delta: float) -> void:
	shake_trauma = maxf(0.0, shake_trauma - delta * 2.2)
	var amt := pow(shake_trauma, 2.0)
	shake_root.position = Vector2(
		randf_range(-1.0, 1.0) * 20.0 * amt,
		randf_range(-1.0, 1.0) * 14.0 * amt
	)

# ── Spawn ──────────────────────────────────────────────────────────────────
func _spawn_piece(piece: Dictionary) -> void:
	var t      : String = piece["t"]
	var base_y : float
	if piece.has("pos_y"):
		base_y = float(piece["pos_y"])
	elif t in ["ceil_spike","ceil_block","ceil_saw","gravity_portal","speed_portal"]:
		base_y = float(CEILING_Y)
	else:
		base_y = float(GROUND_Y)
		# Height variety: float eligible obstacles to random mid-screen heights
		if height_var > 0.0 and t in ["block","diamond","saw"] and randf() < height_var:
			var max_lift : float = height_var * (GROUND_Y - CEILING_Y - 200.0)
			base_y = randf_range(GROUND_Y - max_lift, GROUND_Y - 80.0)
	var sc  : float
	if t in ["gravity_portal", "speed_portal"]:
		sc = 1.0
	elif t in ["ceil_block", "ceil_saw", "ceil_spike"]:
		sc = 1.40
	else:
		sc = OBS_SCALE
	var pw  : float = float(piece["w"]) * sc
	var ph  : float = float(piece["h"]) * sc
	var node := Node2D.new()
	node.set_script(ObstacleScript)
	node.set_meta("obs_type", t)
	node.set_meta("obs_w",    pw)
	node.set_meta("obs_h",    ph)
	if t == "pad":
		node.set_meta("pad_dir", piece.get("dir", 1))
		if piece.has("chain_next"):
			var cn : Array = piece["chain_next"]
			node.set_meta("chain_next", Vector2(float(cn[0]), float(cn[1])))
	node.position = Vector2(SW + 80.0 + float(piece.get("dx", 0)), base_y)
	obs_container.add_child(node)
	node.gif_anim = GifPool.get_obstacle_gif(t)
	var has_poly: bool = node.gif_anim != null and not node.gif_anim.current_polygon().is_empty()
	obs_data.append({
		"x": node.position.x, "y": node.position.y, "base_y": node.position.y,
		"w": pw, "h": ph,
		"t": t, "node": node, "triggered": false,
		"has_polygon": has_poly,
		"float_phase": randf() * TAU,
		"pad_dir": piece.get("dir", 1),
		"bounce_mult": piece.get("bounce", 1.90),
	})

func _weighted_pick(pool: Array) -> int:
	var weights : Array = []
	var total   : float = 0.0
	for i in pool:
		var w : float = obs_weights.get(PATTERN_CATEGORY[i], 1.0)
		weights.append(w)
		total += w
	if total <= 0.0:
		return pool[randi() % pool.size()]
	var r   : float = randf() * total
	var acc : float = 0.0
	for j in pool.size():
		acc += weights[j]
		if r <= acc:
			return pool[j]
	return pool[-1]

func _spawn() -> void:
	if randf() < chain_prob:
		var chain : Array = CHAIN_PATTERNS[randi() % CHAIN_PATTERNS.size()]
		for piece in chain:
			_spawn_piece(piece)
		return

	var diff    : int = mini(score / 38, PATTERNS.size() - 5)
	var max_idx : int = mini(4 + diff, PATTERNS.size() - 1)

	var pad_pool    : Array = []
	var nonpad_pool : Array = []
	for i in range(max_idx + 1):
		if i in PAD_PATTERN_INDICES:
			pad_pool.append(i)
		else:
			nonpad_pool.append(i)

	var pool : Array
	if pad_pool.is_empty():
		pool = nonpad_pool
	elif nonpad_pool.is_empty():
		pool = pad_pool
	else:
		pool = pad_pool if randf() < pad_pattern_prob else nonpad_pool

	var pat : Array = PATTERNS[_weighted_pick(pool)]
	for piece in pat:
		_spawn_piece(piece)

# ── Non-lethal interactions (pads, orbs, portals) ─────────────────────────
func _check_interactions() -> void:
	var cat_cx     : float = PLAYER_X + PW * 0.5
	var cat_cy     : float = py + PH * 0.5
	var cat_bottom : float = py + PH

	_near_orb = {}

	for od in obs_data:
		var ox : float  = od["x"];  var ow : float = od["w"]
		var oy : float  = od["y"];  var oh : float = od["h"]
		var t  : String = od["t"]

		match t:
			"pad":
				var pad_dir    : int  = od.get("pad_dir", 1)
				var px_overlap : bool = PLAYER_X + PW > ox and PLAYER_X < ox + ow
				var is_mid     : bool = od["base_y"] < GROUND_Y - 20 and od["base_y"] > CEILING_Y + 20
				if is_mid and pad_dir == 1:
					# Mid-screen up-pad: solid platform — cat lands on top, no auto-bounce
					if px_overlap and pvy >= 0:
						var surf_y : float = oy - od["h"] * 0.68
						if py + PH >= surf_y - 8 and py + PH <= surf_y + 30:
							py  = surf_y - PH
							pvy = 0.0
							jumps = 0
				else:
					if od.get("triggered", false): continue
					var hit : bool = false
					if pad_dir == 1:
						hit = abs(cat_bottom - oy) < 28.0 and pvy >= -200.0
					else:
						hit = abs(py - oy) < 28.0 and pvy <= 200.0
					if hit and px_overlap:
						pvy = JUMP_VEL * od.get("bounce_mult", 1.90) * float(pad_dir)
						jumps = 1
						od["triggered"] = true
						player_node.emit_jump(false, bg_hue)
						audio_mgr.play_jump(false)

			"orb":
				if od.get("triggered", false): continue
				var orb_cx : float = ox + ow * 0.5
				var orb_cy : float = oy + oh * 0.5
				if abs(cat_cx - orb_cx) < 72.0 and abs(cat_cy - orb_cy) < 72.0:
					_near_orb = od

			"gravity_portal":
				if od.get("triggered", false): continue
				if PLAYER_X > ox and PLAYER_X < ox + ow:
					gravity_dir *= -1.0
					od["triggered"] = true
					player_node.set_gravity(gravity_dir)
					# Brief gravity-flip flash (blue-purple)
					var tw := create_tween()
					flash_rect.color = Color(0.4, 0.1, 0.9, 0.0)
					tw.tween_property(flash_rect, "color:a", 0.5, 0.06)
					tw.tween_property(flash_rect, "color:a", 0.0, 0.3)

			"speed_portal":
				if od.get("triggered", false): continue
				if PLAYER_X > ox:
					speed = minf(speed * 1.30, MAX_SPEED)
					od["triggered"] = true
					# Teal flash
					var tw := create_tween()
					flash_rect.color = Color(0.1, 0.6, 0.8, 0.0)
					tw.tween_property(flash_rect, "color:a", 0.35, 0.05)
					tw.tween_property(flash_rect, "color:a", 0.0, 0.25)

# ── Lethal collisions ──────────────────────────────────────────────────────
func _check_collisions() -> void:
	var m   : float = 9.0
	var px1 : float = PLAYER_X + m
	var px2 : float = PLAYER_X + PW - m
	var py1 : float = py + m
	var py2 : float = py + PH - m
	var corners := [Vector2(px1,py1), Vector2(px2,py1), Vector2(px1,py2), Vector2(px2,py2)]

	for od in obs_data:
		if od["t"] == "pad": continue   # pads are non-lethal, handled in _check_interactions
		var hit : bool  = false
		var ox  : float = od["x"];  var oy : float = od["y"]
		var ow  : float = od["w"];  var oh : float = od["h"]

		# AI subject polygon collision
		if od.get("has_polygon", false):
			var ga = od["node"].gif_anim
			if ga != null:
				var poly: PackedVector2Array = ga.current_polygon()
				if not poly.is_empty():
					var is_ceil: bool = od["t"] in ["ceil_block", "ceil_saw", "ceil_spike"]
					var world_poly := PackedVector2Array()
					for p in poly:
						world_poly.append(Vector2(
							ox + float(p.x) * ow,
							oy + float(p.y) * oh - (0.0 if is_ceil else oh)
						))
					for c in corners:
						if Geometry2D.is_point_in_polygon(c, world_poly):
							hit = true; break
					if hit:
						_die(); return
					continue

		match od["t"]:
			"spike":
				var apex := Vector2(ox + ow * 0.5, oy - oh)
				var bl   := Vector2(ox, oy)
				var br   := Vector2(ox + ow, oy)
				for c in [Vector2(px1,py1),Vector2(px2,py1),Vector2(px1,py2),Vector2(px2,py2)]:
					if _in_tri(c, apex, bl, br): hit = true; break
			"ceil_spike":
				# Triangle points DOWN from ceiling anchor
				var apex := Vector2(ox + ow * 0.5, oy + oh)
				var bl   := Vector2(ox, oy)
				var br   := Vector2(ox + ow, oy)
				for c in [Vector2(px1,py1),Vector2(px2,py1),Vector2(px1,py2),Vector2(px2,py2)]:
					if _in_tri(c, apex, bl, br): hit = true; break
			"block":
				hit = px1 < ox+ow and px2 > ox and py1 < oy and py2 > oy-oh
			"saw":
				var cx   : float = ox + ow * 0.5
				var cy   : float = oy - oh * 0.5
				var cr   : float = ow * 0.5 - 5.0
				var pcx  : float = PLAYER_X + PW * 0.5
				var pcy  : float = py + PH * 0.5
				var pr   : float = minf(PW, PH) * 0.5 - m
				hit = sqrt((pcx-cx)*(pcx-cx) + (pcy-cy)*(pcy-cy)) < cr + pr
			"diamond":
				# Rotated square — split into two triangles
				var cx   := ox + ow * 0.5
				var top  := Vector2(cx, oy - oh)
				var rgt  := Vector2(ox + ow, oy - oh * 0.5)
				var bot  := Vector2(cx, oy)
				var lft  := Vector2(ox, oy - oh * 0.5)
				for c in [Vector2(px1,py1),Vector2(px2,py1),Vector2(px1,py2),Vector2(px2,py2)]:
					if _in_tri(c, top, rgt, bot) or _in_tri(c, top, bot, lft):
						hit = true; break
			"ceil_block":
				# Hangs down from oy = CEILING_Y
				hit = px1 < ox+ow and px2 > ox and py1 < oy+oh and py2 > oy
			"ceil_saw":
				var cx   : float = ox + ow * 0.5
				var cy   : float = oy + oh * 0.5
				var cr   : float = oh * 0.5 - 5.0
				var pcx  : float = PLAYER_X + PW * 0.5
				var pcy  : float = py + PH * 0.5
				var pr   : float = minf(PW, PH) * 0.5 - m
				hit = sqrt((pcx-cx)*(pcx-cx) + (pcy-cy)*(pcy-cy)) < cr + pr
		if hit:
			_die(); return

func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x-b.x)*(a.y-b.y) - (a.x-b.x)*(p.y-b.y)
	var d2 := (p.x-c.x)*(b.y-c.y) - (b.x-c.x)*(p.y-c.y)
	var d3 := (p.x-a.x)*(c.y-a.y) - (c.x-a.x)*(p.y-a.y)
	return not (((d1<0) or (d2<0) or (d3<0)) and ((d1>0) or (d2>0) or (d3>0)))

# ── Death ──────────────────────────────────────────────────────────────────
func _die() -> void:
	gs = GS.DEAD
	if score > best: best = score
	shake_trauma = 1.0
	player_node.explode()
	audio_mgr.play_death()
	audio_mgr.stop_music()
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.65, 0.04)
	tw.tween_property(flash_rect, "color:a", 0.0,  0.4)
	await get_tree().create_timer(0.35).timeout
	hud_node.show_dead(score, score >= best and score > 0)

func _level_complete() -> void:
	gs = GS.COMPLETE
	if score > best: best = score
	audio_mgr.stop_music()
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.4, 0.08)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.6)
	await get_tree().create_timer(0.5).timeout
	hud_node.show_complete()
