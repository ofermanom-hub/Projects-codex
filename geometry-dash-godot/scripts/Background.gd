extends Node2D

const SW        = 1280
const SH        = 720
const GROUND_Y  = 670
const CEILING_Y = 80

var scroll : float = 0.0
var hue    : float = 0.6
var spd    : float = 420.0

var cols_far  : Array = []
var cols_near : Array = []

var sky_gif              = null  # GifPool.GifAnim, set by Main after pool_ready
var _sky_tex : ImageTexture = null

func _ready() -> void:
	for i in 10:
		cols_far.append({"ox": i * 140.0, "h": 30.0 + randf() * 50.0})
	for i in 8:
		cols_near.append({"ox": i * 170.0, "h": 50.0 + randf() * 80.0})

func bg_update(delta: float, new_spd: float, new_hue: float) -> void:
	spd    = new_spd
	hue    = new_hue
	scroll += new_spd * delta
	if sky_gif != null:
		_sky_tex = sky_gif.advance(delta)
	queue_redraw()

func _draw() -> void:
	var ch := fmod(hue + 0.55, 1.0)

	# Sky (CEILING_Y → GROUND_Y play area)
	draw_rect(Rect2(0, CEILING_Y, SW, GROUND_Y - CEILING_Y),
	          Color.from_hsv(hue, 0.55, 0.18))
	var sky_bot := Color.from_hsv(fmod(hue + 0.07, 1.0), 0.55, 0.10)
	sky_bot.a = 0.55
	draw_rect(Rect2(0, CEILING_Y + (GROUND_Y - CEILING_Y) * 0.4,
	               SW, (GROUND_Y - CEILING_Y) * 0.6), sky_bot)
	# GIF background layer
	if _sky_tex:
		draw_texture_rect(_sky_tex,
			Rect2(0, CEILING_Y, SW, GROUND_Y - CEILING_Y),
			false, Color(1, 1, 1, 0.65))

	# Ceiling zone fill
	draw_rect(Rect2(0, 0, SW, CEILING_Y),
	          Color.from_hsv(ch, 0.55, 0.16))

	# Parallax far columns (ground-anchored)
	for col in cols_far:
		var x := fmod(col["ox"] - scroll * 0.18, SW + 160.0) - 20.0
		var c := Color.from_hsv(ch, 0.3, 0.4)
		c.a = 0.10
		draw_rect(Rect2(x, GROUND_Y - col["h"], 2.0, col["h"]), c)

	# Parallax near columns
	for col in cols_near:
		var x := fmod(col["ox"] - scroll * 0.42, SW + 190.0) - 20.0
		var c := Color.from_hsv(ch, 0.35, 0.55)
		c.a = 0.15
		draw_rect(Rect2(x, GROUND_Y - col["h"], 3.0, col["h"]), c)

	# Ground fill
	draw_rect(Rect2(0, GROUND_Y, SW, SH - GROUND_Y),
	          Color.from_hsv(ch, 0.5, 0.20))

	# Ground grid
	var grid_off := fmod(scroll * 0.5, 50.0)
	for xi in range(-1, int(SW / 50) + 2):
		var x := xi * 50.0 - grid_off
		var gc := Color.from_hsv(ch, 0.5, 0.6)
		gc.a = 0.18
		draw_line(Vector2(x, GROUND_Y), Vector2(x, SH), gc, 1.0)

	# Ground HDR glow line
	var glow := Color.from_hsv(ch, 0.9, 1.0) * 4.0
	glow.a = 1.0
	draw_line(Vector2(0, GROUND_Y), Vector2(SW, GROUND_Y), glow, 2.5)

	# Ceiling grid (mirrored)
	for xi in range(-1, int(SW / 50) + 2):
		var x := xi * 50.0 - grid_off
		var gc := Color.from_hsv(fmod(ch + 0.15, 1.0), 0.5, 0.6)
		gc.a = 0.13
		draw_line(Vector2(x, 0), Vector2(x, CEILING_Y), gc, 1.0)

	# Ceiling HDR glow line
	var cglow := Color.from_hsv(fmod(ch + 0.15, 1.0), 0.9, 1.0) * 3.5
	cglow.a = 1.0
	draw_line(Vector2(0, CEILING_Y), Vector2(SW, CEILING_Y), cglow, 2.5)

	# Drifting star-specks (play area only)
	for i in 28:
		var sx := fmod(i * 137.5 + scroll * 0.08, float(SW))
		var sy := fmod(i * 73.1 + i * i * 0.5, float(GROUND_Y - CEILING_Y - 20)) + CEILING_Y
		var sc := Color.from_hsv(fmod(hue + i * 0.04, 1.0), 0.4, 1.0) * 2.5
		sc.a = 0.50
		draw_rect(Rect2(sx - 1, sy - 1, 2, 2), sc)
