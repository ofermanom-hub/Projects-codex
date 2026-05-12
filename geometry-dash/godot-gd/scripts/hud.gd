class_name HUD
extends CanvasLayer

var _score_lbl: Label
var _best_lbl: Label
var _attempt_lbl: Label
var _milestone_lbl: Label
var _menu_overlay: ColorRect
var _dead_overlay: ColorRect
var _dead_score_lbl: Label
var _dead_new_best_lbl: Label
var _milestone_tween: Tween

func _ready() -> void:
	layer = 10
	_build_ui()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.died.connect(_on_died)
	GameManager.restarted.connect(_on_restarted)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Score
	_score_lbl = _make_label("0", 28, Color.WHITE)
	_score_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_score_lbl.offset_left = -140.0
	_score_lbl.offset_bottom = 46.0
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_score_lbl)

	# Best
	_best_lbl = _make_label("BEST " + str(GameManager.best), 14, Color(1, 1, 1, 0.4))
	_best_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_best_lbl.offset_left = -140.0
	_best_lbl.offset_top = 46.0
	_best_lbl.offset_bottom = 68.0
	_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_best_lbl)

	# Attempt
	_attempt_lbl = _make_label("attempt 0", 14, Color(1, 1, 1, 0.3))
	_attempt_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_attempt_lbl.offset_right = 220.0
	_attempt_lbl.offset_bottom = 36.0
	_attempt_lbl.offset_left = 20.0
	_attempt_lbl.offset_top = 10.0
	root.add_child(_attempt_lbl)

	# Milestone flash
	_milestone_lbl = _make_label("", 52, Color(1.0, 0.84, 0.0))
	_milestone_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_milestone_lbl.offset_left = -150.0
	_milestone_lbl.offset_right = 150.0
	_milestone_lbl.offset_top = -100.0
	_milestone_lbl.offset_bottom = -40.0
	_milestone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_lbl.modulate.a = 0.0
	root.add_child(_milestone_lbl)

	# Menu overlay
	_menu_overlay = _build_menu_overlay()
	root.add_child(_menu_overlay)

	# Dead overlay
	_dead_overlay = _build_dead_overlay()
	_dead_overlay.visible = false
	root.add_child(_dead_overlay)

func _build_menu_overlay() -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)

	var title := _make_label("GEOMETRY DASH", 56, Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -450.0; title.offset_right = 450.0
	title.offset_top = 140.0; title.offset_bottom = 210.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(title)

	var sub := _make_label("Press  SPACE  /  CLICK  to Start", 20, Color(0.5, 1.0, 1.0))
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -450.0; sub.offset_right = 450.0
	sub.offset_top = 245.0; sub.offset_bottom = 275.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(sub)

	var hint := _make_label("Double jump available  •  Avoid spikes & blocks", 15, Color(1, 1, 1, 0.35))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -450.0; hint.offset_right = 450.0
	hint.offset_top = 288.0; hint.offset_bottom = 313.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(hint)

	return bg

func _build_dead_overlay() -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.8, 0, 0, 0.22)

	var title := _make_label("GAME OVER", 52, Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -450.0; title.offset_right = 450.0
	title.offset_top = 130.0; title.offset_bottom = 195.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(title)

	_dead_score_lbl = _make_label("Score: 0", 26, Color(0.5, 1.0, 1.0))
	_dead_score_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_dead_score_lbl.offset_left = -450.0; _dead_score_lbl.offset_right = 450.0
	_dead_score_lbl.offset_top = 230.0; _dead_score_lbl.offset_bottom = 265.0
	_dead_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(_dead_score_lbl)

	_dead_new_best_lbl = _make_label("NEW BEST!", 20, Color(1.0, 0.84, 0.0))
	_dead_new_best_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_dead_new_best_lbl.offset_left = -450.0; _dead_new_best_lbl.offset_right = 450.0
	_dead_new_best_lbl.offset_top = 272.0; _dead_new_best_lbl.offset_bottom = 300.0
	_dead_new_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dead_new_best_lbl.visible = false
	bg.add_child(_dead_new_best_lbl)

	var retry := _make_label("SPACE / CLICK to try again", 18, Color(1, 1, 1, 0.5))
	retry.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	retry.offset_left = -450.0; retry.offset_right = 450.0
	retry.offset_top = 326.0; retry.offset_bottom = 354.0
	retry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(retry)

	return bg

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _on_score_changed(new_score: int) -> void:
	_score_lbl.text = str(new_score)
	if GameManager.is_milestone(new_score):
		GameManager.mark_milestone()
		_flash_milestone(new_score)

func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.MENU:
			_menu_overlay.visible = true
			_dead_overlay.visible = false
		GameManager.State.PLAYING:
			_menu_overlay.visible = false
			_dead_overlay.visible = false
			_attempt_lbl.text = "attempt " + str(GameManager.attempts)

func _on_died() -> void:
	_dead_overlay.visible = true
	_dead_score_lbl.text = "Score: " + str(GameManager.score)
	_dead_new_best_lbl.visible = GameManager.score > 0 and GameManager.score >= GameManager.best
	_best_lbl.text = "BEST " + str(GameManager.best)

func _on_restarted() -> void:
	_score_lbl.text = "0"

func _flash_milestone(s: int) -> void:
	_milestone_lbl.text = str(s) + "!"
	_milestone_lbl.scale = Vector2(0.4, 0.4)
	_milestone_lbl.modulate.a = 1.0
	if _milestone_tween:
		_milestone_tween.kill()
	_milestone_tween = create_tween().set_parallel(true)
	_milestone_tween.tween_property(_milestone_lbl, "scale", Vector2(1.2, 1.2), 0.35)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_milestone_tween.tween_property(_milestone_lbl, "modulate:a", 0.0, 0.8).set_delay(0.4)
