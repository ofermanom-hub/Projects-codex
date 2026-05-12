extends CanvasLayer

const SW = 1280
const SH = 720

var score_lbl    : Label
var best_lbl     : Label
var attempt_lbl  : Label
var speed_fill   : ColorRect
var pct_lbl      : Label
var pct_bar_fill : ColorRect
var menu_overlay     : ColorRect
var dead_overlay     : ColorRect
var complete_overlay : ColorRect
var dead_score_lbl   : Label
var new_best_lbl     : Label

# ── Spawn tuner panel ──────────────────────────────────────────────────────
signal chain_prob_changed(val: float)
signal pad_prob_changed(val: float)
signal obs_freq_changed(val: int)
signal height_var_changed(val: float)
signal obs_weight_changed(cat: String, val: float)

var _tuning_panel  : Control
var _chain_lbl     : Label
var _pad_lbl       : Label
var _freq_lbl      : Label
var _height_lbl    : Label

var _chain_val  : float = 0.15
var _pad_val    : float = 0.40
var _freq_val   : int   = 8
var _height_val : float = 0.60

const OBS_CATS : Array = ["spike","block","diamond","saw","orb","ceil","portal"]
var _obs_vals  : Dictionary = {
	"spike":1.0,"block":1.0,"diamond":1.0,
	"saw":1.0,"orb":1.0,"ceil":1.0,"portal":0.5
}
var _obs_lbls  : Dictionary = {}

func _ready() -> void:
	_build()

func _build() -> void:
	_build_tuning_panel()
	# Score (top-right)
	score_lbl = _lbl("0", 34, Color(1,1,1,0.95))
	score_lbl.position = Vector2(SW - 20, 14)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.size.x = 200
	add_child(score_lbl)

	best_lbl = _lbl("BEST 0", 15, Color(1,1,1,0.4))
	best_lbl.position = Vector2(SW - 180, 54)
	add_child(best_lbl)

	attempt_lbl = _lbl("attempt 0", 14, Color(1,1,1,0.3))
	attempt_lbl.position = Vector2(18, 14)
	add_child(attempt_lbl)

	# Speed bar label
	var spd_lbl := _lbl("SPEED", 11, Color(1,1,1,0.3))
	spd_lbl.position = Vector2(18, 36)
	add_child(spd_lbl)

	var speed_bg := ColorRect.new()
	speed_bg.color    = Color(1,1,1,0.1)
	speed_bg.size     = Vector2(120, 6)
	speed_bg.position = Vector2(18, 52)
	add_child(speed_bg)

	speed_fill = ColorRect.new()
	speed_fill.color    = Color(0.3, 1.0, 0.5, 0.85)
	speed_fill.size     = Vector2(0, 6)
	speed_fill.position = Vector2(18, 52)
	add_child(speed_fill)

	# Progress percentage bar (bottom of screen)
	var pct_bg := ColorRect.new()
	pct_bg.color    = Color(1, 1, 1, 0.08)
	pct_bg.size     = Vector2(SW, 8)
	pct_bg.position = Vector2(0, SH - 8)
	add_child(pct_bg)

	pct_bar_fill = ColorRect.new()
	pct_bar_fill.color    = Color(1.5, 2.0, 3.0, 0.9)
	pct_bar_fill.size     = Vector2(0, 8)
	pct_bar_fill.position = Vector2(0, SH - 8)
	add_child(pct_bar_fill)

	pct_lbl = _lbl("0%", 13, Color(1, 1, 1, 0.5))
	pct_lbl.position = Vector2(SW / 2 - 14, SH - 24)
	add_child(pct_lbl)

	menu_overlay = _build_menu()
	add_child(menu_overlay)

	dead_overlay = _build_dead()
	dead_overlay.visible = false
	add_child(dead_overlay)

	complete_overlay = _build_complete()
	complete_overlay.visible = false
	add_child(complete_overlay)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_menu() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.size  = Vector2(SW, SH)

	var title := _lbl("GEOMETRY DASH", 60, Color(2.8, 2.2, 0.5, 1.0))
	title.position = Vector2(SW/2 - 310, SH/2 - 90)
	bg.add_child(title)

	var sub := _lbl("SPACE  /  CLICK  to Start", 24, Color(1.4, 1.8, 2.8, 1.0))
	sub.position = Vector2(SW/2 - 175, SH/2 + 10)
	bg.add_child(sub)

	var hint := _lbl("Double jump  •  Avoid spikes & blocks", 16, Color(1,1,1,0.35))
	hint.position = Vector2(SW/2 - 195, SH/2 + 52)
	bg.add_child(hint)

	return bg

func _build_dead() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.8, 0, 0, 0.2)
	bg.size  = Vector2(SW, SH)

	var go := _lbl("GAME OVER", 60, Color(4.0, 0.3, 0.3, 1.0))
	go.position = Vector2(SW/2 - 245, SH/2 - 90)
	bg.add_child(go)

	dead_score_lbl = _lbl("Score: 0", 32, Color(1.4, 2.0, 2.8, 1.0))
	dead_score_lbl.position = Vector2(SW/2 - 80, SH/2 + 5)
	bg.add_child(dead_score_lbl)

	new_best_lbl = _lbl("✦  NEW BEST  ✦", 22, Color(3.0, 2.4, 0.4, 1.0))
	new_best_lbl.position = Vector2(SW/2 - 110, SH/2 + 48)
	new_best_lbl.visible = false
	bg.add_child(new_best_lbl)

	var retry := _lbl("SPACE / CLICK  to try again", 20, Color(1,1,1,0.5))
	retry.position = Vector2(SW/2 - 170, SH/2 + 90)
	bg.add_child(retry)

	return bg

# ── Public API ─────────────────────────────────────────────────────────────
func update_score(s: int, b: int, pct: float = 0.0) -> void:
	score_lbl.text  = str(s)
	best_lbl.text   = "BEST " + str(b)
	speed_fill.size.x = clampf(s / 500.0, 0.0, 1.0) * 120.0
	var r := speed_fill.size.x / 120.0
	speed_fill.color = Color(lerp(0.2, 1.0, r), lerp(1.0, 0.2, r), 0.3, 0.85)
	pct_bar_fill.size.x = pct * SW
	pct_lbl.text = str(int(pct * 100)) + "%"

func update_attempt(a: int) -> void:
	attempt_lbl.text = "attempt " + str(a)

func show_menu() -> void:
	menu_overlay.visible = true
	dead_overlay.visible = false

func hide_menu() -> void:
	menu_overlay.visible = false

func show_dead(s: int, is_best: bool) -> void:
	dead_score_lbl.text  = "Score: " + str(s)
	new_best_lbl.visible = is_best
	dead_overlay.visible = true

func hide_dead() -> void:
	dead_overlay.visible = false

func _build_complete() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.05, 0.15, 0.75)
	bg.size  = Vector2(SW, SH)

	var title := _lbl("LEVEL COMPLETE!", 68, Color(0.5, 4.0, 1.2, 1.0))
	title.position = Vector2(SW/2 - 370, SH/2 - 110)
	bg.add_child(title)

	var sub := _lbl("You made it through!", 28, Color(1.4, 1.8, 2.8, 1.0))
	sub.position = Vector2(SW/2 - 185, SH/2 + 10)
	bg.add_child(sub)

	var hint := _lbl("SPACE / CLICK  to play again", 20, Color(1, 1, 1, 0.5))
	hint.position = Vector2(SW/2 - 185, SH/2 + 70)
	bg.add_child(hint)

	return bg

func show_complete() -> void:
	complete_overlay.visible = true

func hide_complete() -> void:
	complete_overlay.visible = false

# ── Spawn tuner ────────────────────────────────────────────────────────────
func _build_tuning_panel() -> void:
	var panel := ColorRect.new()
	panel.color    = Color(0.0, 0.0, 0.0, 0.72)
	panel.size     = Vector2(310, 188 + OBS_CATS.size() * 30 + 36)
	panel.position = Vector2(16, 70)
	panel.visible  = false
	_tuning_panel  = panel
	add_child(panel)

	# Title
	var title := _lbl("SPAWN TUNER   [Tab to close]", 13, Color(1, 1, 0.4, 0.9))
	title.position = Vector2(10, 8)
	panel.add_child(title)

	var div := _divider(panel, 28)

	# Spawn rate rows
	_chain_lbl  = _make_tuner_row(panel, "Chain pad rate", 36,
		func(): _adjust_chain(-0.05),  func(): _adjust_chain(+0.05))
	_pad_lbl    = _make_tuner_row(panel, "Pad in pattern", 72,
		func(): _adjust_pad(-0.05),    func(): _adjust_pad(+0.05))
	_freq_lbl   = _make_tuner_row(panel, "Obs frequency ", 108,
		func(): _adjust_freq(-1),      func(): _adjust_freq(+1))
	_height_lbl = _make_tuner_row(panel, "Height variety", 144,
		func(): _adjust_height(-0.10), func(): _adjust_height(+0.10))

	# Obstacle mix section
	_divider(panel, 178)
	var sec := _lbl("OBSTACLE MIX  (weight)", 13, Color(1, 0.6, 0.2, 0.9))
	sec.position = Vector2(10, 186)
	panel.add_child(sec)
	_divider(panel, 204)

	for idx in OBS_CATS.size():
		var cat : String = OBS_CATS[idx]
		var row_y : int  = 212 + idx * 30
		var lbl := _make_tuner_row(panel,
			cat.capitalize() + "      ",
			row_y,
			func(): _adjust_obs(cat, -0.25),
			func(): _adjust_obs(cat, +0.25))
		_obs_lbls[cat] = lbl

	_refresh_tuning_labels()

func _divider(parent: Control, y: int) -> ColorRect:
	var d := ColorRect.new()
	d.color    = Color(1, 1, 1, 0.12)
	d.size     = Vector2(290, 1)
	d.position = Vector2(10, y)
	parent.add_child(d)
	return d

func _make_tuner_row(parent: Control, label: String, y: int,
                     on_minus: Callable, on_plus: Callable) -> Label:
	var lbl := _lbl(label, 14, Color(0.8, 0.9, 1.0, 0.85))
	lbl.position = Vector2(12, y)
	parent.add_child(lbl)

	var btn_minus := Button.new()
	btn_minus.text = " − "
	btn_minus.add_theme_font_size_override("font_size", 15)
	btn_minus.position = Vector2(178, y - 2)
	btn_minus.pressed.connect(on_minus)
	parent.add_child(btn_minus)

	var val_lbl := _lbl("", 15, Color(0.4, 1.0, 0.6, 1.0))
	val_lbl.position = Vector2(220, y)
	val_lbl.size.x   = 52
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(val_lbl)

	var btn_plus := Button.new()
	btn_plus.text = " + "
	btn_plus.add_theme_font_size_override("font_size", 15)
	btn_plus.position = Vector2(270, y - 2)
	btn_plus.pressed.connect(on_plus)
	parent.add_child(btn_plus)

	return val_lbl

func _refresh_tuning_labels() -> void:
	_chain_lbl.text  = "%d%%" % roundi(_chain_val * 100)
	_pad_lbl.text    = "%d%%" % roundi(_pad_val   * 100)
	_freq_lbl.text   = "%d / 10" % _freq_val
	_height_lbl.text = "%d%%" % roundi(_height_val * 100)
	for cat in _obs_lbls:
		_obs_lbls[cat].text = "%.2f" % _obs_vals.get(cat, 1.0)

func _adjust_chain(delta: float) -> void:
	_chain_val = clampf(_chain_val + delta, 0.0, 1.0)
	_refresh_tuning_labels()
	chain_prob_changed.emit(_chain_val)

func _adjust_pad(delta: float) -> void:
	_pad_val = clampf(_pad_val + delta, 0.0, 1.0)
	_refresh_tuning_labels()
	pad_prob_changed.emit(_pad_val)

func _adjust_freq(delta: int) -> void:
	_freq_val = clampi(_freq_val + delta, 1, 10)
	_refresh_tuning_labels()
	obs_freq_changed.emit(_freq_val)

func _adjust_height(delta: float) -> void:
	_height_val = clampf(_height_val + delta, 0.0, 1.0)
	_refresh_tuning_labels()
	height_var_changed.emit(_height_val)

func _adjust_obs(cat: String, delta: float) -> void:
	_obs_vals[cat] = clampf(_obs_vals.get(cat, 1.0) + delta, 0.0, 3.0)
	_refresh_tuning_labels()
	obs_weight_changed.emit(cat, _obs_vals[cat])

func toggle_tuning() -> void:
	_tuning_panel.visible = not _tuning_panel.visible
