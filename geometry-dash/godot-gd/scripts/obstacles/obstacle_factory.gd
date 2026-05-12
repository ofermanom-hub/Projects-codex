class_name ObstacleFactory
extends RefCounted

const BrainrotLore: GDScript = preload("res://scripts/data/brainrot_lore.gd")

# Kenney obstacle textures
const _TEX_SPIKES:   Texture2D = preload("res://assets/sprites/kenney/obs_spikes.png")
const _TEX_SAW:      Texture2D = preload("res://assets/sprites/kenney/obs_saw.png")
const _TEX_BLK_BLUE: Texture2D = preload("res://assets/sprites/kenney/obs_block_blue.png")
const _TEX_BLK_GRN:  Texture2D = preload("res://assets/sprites/kenney/obs_block_green.png")
const _TEX_BLK_RED:  Texture2D = preload("res://assets/sprites/kenney/obs_block_red.png")
const _TEX_BLK_YEL:  Texture2D = preload("res://assets/sprites/kenney/obs_block_yellow.png")
const _TEX_PLANKS:   Texture2D = preload("res://assets/sprites/kenney/obs_block_planks.png")
const _TEX_BRICKS:   Texture2D = preload("res://assets/sprites/kenney/obs_bricks_brown.png")
const _TEX_BRICKS_G: Texture2D = preload("res://assets/sprites/kenney/obs_bricks_grey.png")
const _TEX_EXCL:     Texture2D = preload("res://assets/sprites/kenney/obs_block_exclamation.png")
const _TEX_BLK_SPK:  Texture2D = preload("res://assets/sprites/kenney/obs_block_spikes.png")
const _TEX_BLK_STONE:Texture2D = preload("res://assets/sprites/kenney/obs_block_stone.png")
const _TEX_BOMB:     Texture2D = preload("res://assets/sprites/kenney/obs_bomb.png")
const _OBS_GLOW_SHADER: Shader = preload("res://shaders/obstacle_glow.gdshader")

const _VARIANT_NAMES: Array[String] = ["SpikeUp", "Block", "FloatBlock", "SpikeDown", "BouncePad", "Saw", "Rail", "Brainrot"]
const _COL_NAMES: Array[String] = ["SpikeUpCol", "BlockCol", "FloatBlockCol", "SpikeDownCol", "BouncePadCol", "SawCol", "RailCol", "BrainrotCol"]

var _glow_counter: int = 0
var _theme_block_tex: Array[Texture2D] = []
var _theme_float_tex: Array[Texture2D] = []

func _init() -> void:
	_theme_block_tex.resize(10)
	_theme_float_tex.resize(10)
	# CYBER FOREST DESERT SPACE MUSHROOM SKY CASTLE DUNGEON CITY JUNGLE
	var btex: Array = [_TEX_BRICKS_G, _TEX_PLANKS, _TEX_BRICKS, _TEX_BRICKS_G, _TEX_BLK_RED,
	                   _TEX_PLANKS, _TEX_BRICKS, _TEX_BLK_STONE, _TEX_BRICKS_G, _TEX_PLANKS]
	var ftex: Array = [_TEX_BLK_BLUE, _TEX_BLK_GRN, _TEX_BLK_YEL, _TEX_BLK_BLUE, _TEX_BLK_RED,
	                   _TEX_BLK_GRN, _TEX_EXCL, _TEX_BLK_SPK, _TEX_BRICKS_G, _TEX_BLK_GRN]
	for i: int in 10:
		_theme_block_tex[i] = btex[i]
		_theme_float_tex[i] = ftex[i]

# Build all 7 variant subtrees (rail variant covers both rail_up and rail_down).
# Variants are hidden and their collisions disabled until update_* shows one.
func build_variants(area: Area2D, bounce: Area2D, rail: Area2D, visual: Node2D) -> void:
	_build_spike_up(area, visual)
	_build_block(area, visual)
	_build_float_block(area, visual)
	_build_spike_down(area, visual)
	_build_bounce_pad(bounce, visual)
	_build_saw(area, visual)
	_build_rail(rail, visual)
	_build_brainrot(area, visual)

func hide_all_variants(area: Area2D, bounce: Area2D, rail: Area2D, visual: Node2D) -> void:
	for n: String in _VARIANT_NAMES:
		var v: Node2D = visual.get_node_or_null(n)
		if v:
			v.visible = false
			_set_particles_emitting(v, false)
	for parent: Node in [area, bounce, rail]:
		for child: Node in parent.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = true
			elif child is CollisionPolygon2D:
				(child as CollisionPolygon2D).disabled = true

# ── accessors used by Obstacle.animate() ─────────────────────────────────────
func get_saw_sprite(visual: Node2D) -> Node2D:
	return visual.get_node_or_null("Saw/SawSprite") as Node2D

func get_rail_glow(visual: Node2D) -> Line2D:
	return visual.get_node_or_null("Rail/RailGlow") as Line2D

func get_brain_label(visual: Node2D) -> Label:
	return visual.get_node_or_null("Brainrot/BrainLabel") as Label

func get_brain_aura(visual: Node2D) -> Line2D:
	return visual.get_node_or_null("Brainrot/BrainAura") as Line2D

func get_brain_sprite(visual: Node2D) -> Sprite2D:
	return visual.get_node_or_null("Brainrot/BrainSpr") as Sprite2D

# Returns the primary kenney sprite of a variant — the one we override per
# spawn with a streamed GIF frame. Returns null for variants drawn entirely
# from primitives (Rail, BouncePad/Trampoline).
func get_gif_target_sprite(visual: Node2D, variant_name: String) -> Sprite2D:
	match variant_name:
		"SpikeUp":    return visual.get_node_or_null("SpikeUp/Spr") as Sprite2D
		"SpikeDown":  return visual.get_node_or_null("SpikeDown/Spr") as Sprite2D
		"Saw":        return visual.get_node_or_null("Saw/SawSprite") as Sprite2D
	return null

func get_pulse_parts(visual: Node2D, variant_name: String) -> Node2D:
	return visual.get_node_or_null("%s/PulseParts" % variant_name) as Node2D

# ── theme + glow helpers ─────────────────────────────────────────────────────
func _theme() -> int:
	return clampi(GameManager.theme_index, 0, 9)

func _make_glow_mat(col: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _OBS_GLOW_SHADER
	_refresh_glow_mat(mat, col)
	return mat

func _refresh_glow_mat(mat: ShaderMaterial, col: Color) -> void:
	mat.set_shader_parameter("glow_color", col)
	mat.set_shader_parameter("glow_strength", randf_range(3.0, 6.0))
	mat.set_shader_parameter("glow_speed",    randf_range(1.5, 5.0))
	mat.set_shader_parameter("glow_phase",    fmod(float(_glow_counter) * 2.3999, TAU))
	_glow_counter += 1

func _theme_block_colors() -> Array:
	match _theme():
		0: return [Color(0.05,0.15,0.55), Color(0.4,0.8,2.5,0.9)]   # CYBER
		1: return [Color(0.18,0.48,0.08), Color(0.6,1.8,0.4,0.9)]   # FOREST
		2: return [Color(0.55,0.28,0.05), Color(1.8,1.2,0.3,0.9)]   # DESERT
		3: return [Color(0.02,0.05,0.25), Color(0.3,0.6,2.5,0.9)]   # SPACE
		4: return [Color(0.42,0.04,0.62), Color(1.5,0.5,2.5,0.9)]   # MUSHROOM
		5: return [Color(0.12,0.50,0.12), Color(0.5,2.0,0.4,0.9)]   # SKY
		6: return [Color(0.45,0.32,0.05), Color(2.5,1.8,0.3,0.9)]   # CASTLE
		7: return [Color(0.15,0.05,0.35), Color(1.2,0.4,2.5,0.9)]   # DUNGEON
		8: return [Color(0.35,0.35,0.35), Color(2.5,1.5,0.5,0.9)]   # CITY
		9: return [Color(0.05,0.40,0.10), Color(0.4,2.5,0.6,0.9)]   # JUNGLE
	return [Color(0.53,0.18,0.82), Color(1.2,0.6,2.5,0.9)]

func _theme_spike_color() -> Color:
	match _theme():
		0: return Color(2.5, 0.3, 0.3)
		1: return Color(0.4, 2.0, 0.2)
		2: return Color(2.5, 1.2, 0.2)
		3: return Color(0.4, 1.5, 2.5)
		4: return Color(2.5, 0.3, 2.5)
		5: return Color(0.4, 2.5, 0.5)
		6: return Color(2.5, 2.0, 0.3)
		7: return Color(1.5, 0.5, 2.5)
		8: return Color(2.5, 0.8, 0.1)
		9: return Color(0.3, 2.5, 0.8)
	return Color(2.5, 0.3, 0.3)

# ── pulse particles ──────────────────────────────────────────────────────────
func _build_pulse_particles(parent: Node2D, up: bool) -> void:
	var p := CPUParticles2D.new()
	p.name = "PulseParts"
	p.emitting = false
	p.amount = 18
	p.lifetime = 1.1
	p.explosiveness = 0.0
	p.randomness = 0.7
	p.direction = Vector2(0.0, -1.0 if up else 1.0)
	p.spread = 80.0
	p.gravity = Vector2(0.0, 60.0 if not up else -60.0)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 11.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	parent.add_child(p)

	var p2 := CPUParticles2D.new()
	p2.name = "Sparks"
	p2.emitting = false
	p2.amount = 8; p2.lifetime = 0.6; p2.randomness = 1.0
	p2.direction = Vector2(1.0, 0.0); p2.spread = 90.0; p2.gravity = Vector2.ZERO
	p2.initial_velocity_min = 25.0; p2.initial_velocity_max = 60.0
	p2.scale_amount_min = 2.0; p2.scale_amount_max = 6.0
	var mat2 := CanvasItemMaterial.new()
	mat2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p2.material = mat2
	parent.add_child(p2)

func _refresh_pulse_particles(parent: Node2D, color: Color, pos: Vector2) -> void:
	var p: CPUParticles2D = parent.get_node_or_null("PulseParts") as CPUParticles2D
	if p:
		p.color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, 0.85)
		p.position = pos
		p.emitting = true
	var p2: CPUParticles2D = parent.get_node_or_null("Sparks") as CPUParticles2D
	if p2:
		p2.color = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, 0.6)
		p2.position = pos
		p2.emitting = true

func _set_particles_emitting(parent: Node2D, on: bool) -> void:
	var p: CPUParticles2D = parent.get_node_or_null("PulseParts") as CPUParticles2D
	if p: p.emitting = on
	var p2: CPUParticles2D = parent.get_node_or_null("Sparks") as CPUParticles2D
	if p2: p2.emitting = on

# ════════════════════════════════════════════════════════════════════════════
# Variant builders — called once at obstacle creation. Each creates a hidden
# Node2D under `visual` named after the type, plus a disabled collision shape
# under the appropriate Area2D.
# ════════════════════════════════════════════════════════════════════════════

# ── Spike UP ─────────────────────────────────────────────────────────────────
func _build_spike_up(area: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "SpikeUp"; v.visible = false
	visual.add_child(v)
	var poly := CollisionPolygon2D.new()
	poly.name = "SpikeUpCol"; poly.disabled = true
	poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(20,-40), Vector2(40,0)])
	area.add_child(poly)
	var spr := Sprite2D.new()
	spr.name = "Spr"; spr.texture = _TEX_SPIKES
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.material = _make_glow_mat(Color(2.5, 0.3, 0.3))
	v.add_child(spr)
	var outline := Line2D.new(); outline.name = "Outline"; outline.width = 2.5
	v.add_child(outline)
	_build_pulse_particles(v, true)

func update_spike_up(area: Area2D, visual: Node2D, w: float, h: float) -> void:
	var v: Node2D = visual.get_node("SpikeUp")
	v.visible = true
	var poly: CollisionPolygon2D = area.get_node("SpikeUpCol")
	poly.disabled = false
	poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(w*.5,-h), Vector2(w,0)])
	var col: Color = _theme_spike_color()
	var spr: Sprite2D = v.get_node("Spr")
	spr.scale = Vector2(w/64.0, h/64.0); spr.position = Vector2(w*.5, -h*.5)
	spr.modulate = col
	_refresh_glow_mat(spr.material as ShaderMaterial, col)
	var outline: Line2D = v.get_node("Outline")
	outline.points = PackedVector2Array([Vector2(0,0), Vector2(w*.5,-h), Vector2(w,0), Vector2(0,0)])
	outline.default_color = col
	_refresh_pulse_particles(v, col, Vector2(w*.5, -h*.2))

# ── Block ────────────────────────────────────────────────────────────────────
func _build_block(area: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "Block"; v.visible = false
	visual.add_child(v)
	var shape := CollisionShape2D.new()
	shape.name = "BlockCol"; shape.disabled = true
	shape.shape = RectangleShape2D.new()
	area.add_child(shape)
	var tr := TextureRect.new()
	tr.name = "Tile"
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.material = _make_glow_mat(Color(0.4, 0.8, 2.5, 0.9))
	v.add_child(tr)
	var top := Line2D.new(); top.name = "Top"; top.width = 3.5; v.add_child(top)
	var left := Line2D.new(); left.name = "Left"; left.width = 1.5; v.add_child(left)
	var right := Line2D.new(); right.name = "Right"; right.width = 1.5; v.add_child(right)
	_build_pulse_particles(v, true)

func update_block(area: Area2D, visual: Node2D, w: float, h: float) -> void:
	var v: Node2D = visual.get_node("Block")
	v.visible = true
	var shape: CollisionShape2D = area.get_node("BlockCol")
	shape.disabled = false
	(shape.shape as RectangleShape2D).size = Vector2(w, h)
	shape.position = Vector2(w*.5, -h*.5)
	var cols: Array = _theme_block_colors()
	var col: Color = cols[1]
	var tr: TextureRect = v.get_node("Tile")
	tr.texture = _theme_block_tex[_theme()]
	tr.size = Vector2(w, h); tr.position = Vector2(0.0, -h)
	_refresh_glow_mat(tr.material as ShaderMaterial, col)
	var top: Line2D = v.get_node("Top")
	top.points = PackedVector2Array([Vector2(0,-h), Vector2(w,-h)])
	top.default_color = col
	var left: Line2D = v.get_node("Left")
	left.points = PackedVector2Array([Vector2(0,-h), Vector2(0,0)])
	left.default_color = Color(col.r, col.g, col.b, 0.5)
	var right: Line2D = v.get_node("Right")
	right.points = PackedVector2Array([Vector2(w,-h), Vector2(w,0)])
	right.default_color = Color(col.r, col.g, col.b, 0.5)
	_refresh_pulse_particles(v, col, Vector2(w*.5, -h))

# ── Float block ──────────────────────────────────────────────────────────────
func _build_float_block(area: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "FloatBlock"; v.visible = false
	visual.add_child(v)
	var shape := CollisionShape2D.new()
	shape.name = "FloatBlockCol"; shape.disabled = true
	shape.shape = RectangleShape2D.new()
	area.add_child(shape)
	var tr := TextureRect.new()
	tr.name = "Tile"
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.material = _make_glow_mat(Color(0.5, 2.5, 2.5))
	v.add_child(tr)
	var glow := Line2D.new(); glow.name = "Glow"; glow.width = 4.0; v.add_child(glow)
	var bot := Line2D.new(); bot.name = "Bot"; bot.width = 2.0; v.add_child(bot)
	_build_pulse_particles(v, true)

func update_float_block(area: Area2D, visual: Node2D, w: float, h: float) -> void:
	var v: Node2D = visual.get_node("FloatBlock")
	v.visible = true
	var shape: CollisionShape2D = area.get_node("FloatBlockCol")
	shape.disabled = false
	(shape.shape as RectangleShape2D).size = Vector2(w, h)
	shape.position = Vector2(w*.5, -h*.5)
	var gcol: Color = Color(0.5, 2.5, 2.5)
	var tr: TextureRect = v.get_node("Tile")
	tr.texture = _theme_float_tex[_theme()]
	tr.size = Vector2(w, h); tr.position = Vector2(0.0, -h)
	_refresh_glow_mat(tr.material as ShaderMaterial, gcol)
	var glow: Line2D = v.get_node("Glow")
	glow.points = PackedVector2Array([Vector2(0,-h), Vector2(w,-h)])
	glow.default_color = gcol
	var bot: Line2D = v.get_node("Bot")
	bot.points = PackedVector2Array([Vector2(0,0), Vector2(w,0)])
	bot.default_color = Color(gcol.r, gcol.g, gcol.b, 0.4)
	_refresh_pulse_particles(v, gcol, Vector2(w*.5, -h))

# ── Spike DOWN ───────────────────────────────────────────────────────────────
func _build_spike_down(area: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "SpikeDown"; v.visible = false
	visual.add_child(v)
	var poly := CollisionPolygon2D.new()
	poly.name = "SpikeDownCol"; poly.disabled = true
	poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(40,0), Vector2(20,40)])
	area.add_child(poly)
	var spr := Sprite2D.new()
	spr.name = "Spr"; spr.texture = _TEX_SPIKES
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.flip_v = true
	spr.material = _make_glow_mat(Color(2.5, 0.3, 0.3))
	v.add_child(spr)
	var outline := Line2D.new(); outline.name = "Outline"; outline.width = 2.5
	v.add_child(outline)
	_build_pulse_particles(v, false)

func update_spike_down(area: Area2D, visual: Node2D, w: float, h: float) -> void:
	var v: Node2D = visual.get_node("SpikeDown")
	v.visible = true
	var poly: CollisionPolygon2D = area.get_node("SpikeDownCol")
	poly.disabled = false
	poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(w,0), Vector2(w*.5,h)])
	var col: Color = _theme_spike_color()
	var spr: Sprite2D = v.get_node("Spr")
	spr.scale = Vector2(w/64.0, h/64.0); spr.position = Vector2(w*.5, h*.5)
	spr.modulate = col
	_refresh_glow_mat(spr.material as ShaderMaterial, col)
	var outline: Line2D = v.get_node("Outline")
	outline.points = PackedVector2Array([Vector2(0,0), Vector2(w,0), Vector2(w*.5,h), Vector2(0,0)])
	outline.default_color = col
	_refresh_pulse_particles(v, col, Vector2(w*.5, h*.2))

# ── Bounce pad (rainbow trampoline) ──────────────────────────────────────────
const _TrampolinePadScript: GDScript = preload("res://scripts/obstacles/trampoline_pad.gd")

func _build_bounce_pad(bounce: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "BouncePad"; v.visible = false
	visual.add_child(v)
	var shape := CollisionShape2D.new()
	shape.name = "BouncePadCol"; shape.disabled = true
	shape.shape = RectangleShape2D.new()
	bounce.add_child(shape)
	var pad: TrampolinePad = _TrampolinePadScript.new()
	pad.name = "Tramp"
	v.add_child(pad)
	_build_pulse_particles(v, true)

func update_bounce_pad(bounce: Area2D, visual: Node2D, w: float, h: float) -> void:
	var v: Node2D = visual.get_node("BouncePad")
	v.visible = true
	var shape: CollisionShape2D = bounce.get_node("BouncePadCol")
	shape.disabled = false
	(shape.shape as RectangleShape2D).size = Vector2(w, h * 2.0)
	shape.position = Vector2(w*.5, -h)
	var pad: TrampolinePad = v.get_node("Tramp") as TrampolinePad
	pad.configure(w, h, 1)
	_refresh_pulse_particles(v, Color(0.2, 3.0, 0.3), Vector2(w*.5, -h))

# ── Saw blade ────────────────────────────────────────────────────────────────
func _build_saw(area: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "Saw"; v.visible = false
	visual.add_child(v)
	var shape := CollisionShape2D.new()
	shape.name = "SawCol"; shape.disabled = true
	shape.shape = CircleShape2D.new()
	area.add_child(shape)
	var spr := Sprite2D.new()
	spr.name = "SawSprite"; spr.texture = _TEX_SAW
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.material = _make_glow_mat(Color(2.5, 0.3, 0.3))
	v.add_child(spr)
	_build_pulse_particles(v, true)

func update_saw(area: Area2D, visual: Node2D, w: float) -> void:
	var v: Node2D = visual.get_node("Saw")
	v.visible = true
	var radius: float = w * 0.5
	var shape: CollisionShape2D = area.get_node("SawCol")
	shape.disabled = false
	(shape.shape as CircleShape2D).radius = radius * 0.85
	shape.position = Vector2(radius, -radius)
	var col: Color = _theme_spike_color()
	var spr: Sprite2D = v.get_node("SawSprite")
	spr.rotation_degrees = 0.0
	spr.scale = Vector2(radius * 2.0 / 64.0, radius * 2.0 / 64.0)
	spr.position = Vector2(radius, -radius)
	spr.modulate = col
	_refresh_glow_mat(spr.material as ShaderMaterial, col)
	_refresh_pulse_particles(v, col, Vector2(radius, -radius))

# ── Rail (escalator, both directions) ────────────────────────────────────────
func _build_rail(rail: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "Rail"; v.visible = false
	visual.add_child(v)
	var shape := CollisionShape2D.new()
	shape.name = "RailCol"; shape.disabled = true
	shape.shape = RectangleShape2D.new()
	rail.add_child(shape)
	var body := ColorRect.new(); body.name = "Body"; v.add_child(body)
	var glow := Line2D.new(); glow.name = "RailGlow"; glow.width = 6.0; v.add_child(glow)
	var bot := Line2D.new(); bot.name = "Bot"; bot.width = 4.0; v.add_child(bot)
	for i: int in 5:
		var arr := Line2D.new(); arr.name = "Arr%d" % i; arr.width = 3.0; v.add_child(arr)
		var head := Line2D.new(); head.name = "Head%d" % i; head.width = 3.0; v.add_child(head)
	_build_pulse_particles(v, true)

func update_rail(rail: Area2D, visual: Node2D, w: float, h: float, direction: float) -> void:
	var v: Node2D = visual.get_node("Rail")
	v.visible = true
	var shape: CollisionShape2D = rail.get_node("RailCol")
	shape.disabled = false
	(shape.shape as RectangleShape2D).size = Vector2(w, h + 80.0)
	shape.position = Vector2(w*.5, -(h*.5 + 40.0))

	var is_up: bool = direction < 0.0
	var rail_color: Color = Color(0.0, 3.0, 3.0) if is_up else Color(3.0, 0.2, 2.0)
	var dark_bg: Color   = Color(0.0, 0.15, 0.2) if is_up else Color(0.25, 0.02, 0.18)

	var body: ColorRect = v.get_node("Body")
	body.size = Vector2(w, h + 6.0); body.position = Vector2(0.0, -(h + 3.0))
	body.color = dark_bg
	var glow: Line2D = v.get_node("RailGlow")
	glow.points = PackedVector2Array([Vector2(0, -(h+3.0)), Vector2(w, -(h+3.0))])
	glow.default_color = rail_color
	var bot: Line2D = v.get_node("Bot")
	bot.points = PackedVector2Array([Vector2(0, 3.0), Vector2(w, 3.0)])
	bot.default_color = Color(rail_color.r, rail_color.g, rail_color.b, 0.6)

	for i: int in 5:
		var ax: float = w * (0.1 + i * 0.2)
		var tip_y:  float = -(h+3.0) * 0.85 if is_up else -3.0
		var tail_y: float = -3.0            if is_up else -(h+3.0) * 0.85
		var arr: Line2D = v.get_node("Arr%d" % i)
		arr.points = PackedVector2Array([Vector2(ax, tail_y), Vector2(ax, tip_y)])
		arr.default_color = Color(rail_color.r, rail_color.g, rail_color.b, 0.85)
		var tip_dir: float = -1.0 if is_up else 1.0
		var head: Line2D = v.get_node("Head%d" % i)
		head.points = PackedVector2Array([Vector2(ax - 7.0, tip_y - tip_dir * 10.0),
		                                  Vector2(ax, tip_y),
		                                  Vector2(ax + 7.0, tip_y - tip_dir * 10.0)])
		head.default_color = rail_color
	_refresh_pulse_particles(v, rail_color, Vector2(w*.5, -(h*.5)))

# ── Brainrot character ───────────────────────────────────────────────────────
func _build_brainrot(area: Area2D, visual: Node2D) -> void:
	var v := Node2D.new(); v.name = "Brainrot"; v.visible = false
	visual.add_child(v)
	var shape := CollisionShape2D.new()
	shape.name = "BrainrotCol"; shape.disabled = true
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 34.0
	shape.position = Vector2(0.0, -40.0)
	area.add_child(shape)
	var spr := Sprite2D.new(); spr.name = "BrainSpr"
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.52, 0.52); spr.position = Vector2(0.0, -40.0)
	v.add_child(spr)
	var aura := Line2D.new(); aura.name = "BrainAura"; aura.width = 4.5
	var aura_pts := PackedVector2Array()
	for i: int in 25:
		var ang: float = i * TAU / 24.0
		aura_pts.append(Vector2(cos(ang) * 52.0, sin(ang) * 52.0 - 40.0))
	aura.points = aura_pts
	v.add_child(aura)
	var lbl := Label.new(); lbl.name = "BrainLabel"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.position = Vector2(-35.0, -105.0); lbl.z_index = 10
	v.add_child(lbl)
	_build_pulse_particles(v, true)

func update_brainrot(area: Area2D, visual: Node2D, bi: int) -> void:
	var v: Node2D = visual.get_node("Brainrot")
	v.visible = true
	var shape: CollisionShape2D = area.get_node("BrainrotCol")
	shape.disabled = false
	var col: Color = BrainrotLore.COLS[bi % BrainrotLore.COLS.size()]
	var all_tex: Array = []
	all_tex.append_array(BrainrotLore.TEX_BRAINROT)
	all_tex.append_array(BrainrotLore.TEX_CHARS)
	var spr: Sprite2D = v.get_node("BrainSpr")
	spr.texture = all_tex[bi % all_tex.size()]
	spr.modulate = col
	var aura: Line2D = v.get_node("BrainAura")
	aura.default_color = col
	var lbl: Label = v.get_node("BrainLabel")
	lbl.text = BrainrotLore.NAMES[bi % BrainrotLore.NAMES.size()]
	_refresh_pulse_particles(v, col, Vector2(0.0, -40.0))
