extends Node
## Fetches approved GIFs from the local curation server, caches spritesheet PNGs
## to user://, slices frames into ImageTexture arrays, and hands out random
## per-session assignments to Obstacle and Background nodes.

signal pool_ready

const SERVER = "http://localhost:8080"

# ── GifAnim ───────────────────────────────────────────────────────────────────
class GifAnim:
	var frames: Array = []          # Array[ImageTexture]
	var subject_frames: Array = []  # Array[ImageTexture] — rembg-extracted RGBA
	var polygons: Array = []        # Array[PackedVector2Array] — per-frame silhouette
	var fps: float    = 10.0
	var frame_count: int = 0
	var _t: float = 0.0
	var _f: int   = 0

	func advance(delta: float) -> ImageTexture:
		if frames.is_empty():
			return null
		_t += delta
		var spf := 1.0 / maxf(fps, 1.0)
		while _t >= spf:
			_t -= spf
			_f  = (_f + 1) % frame_count
		return frames[_f]

	func current() -> ImageTexture:
		return frames[_f] if not frames.is_empty() else null

	func current_polygon() -> PackedVector2Array:
		if polygons.is_empty(): return PackedVector2Array()
		return polygons[_f % polygons.size()]

	func current_subject() -> ImageTexture:
		return subject_frames[_f] if not subject_frames.is_empty() else null

# ── State ─────────────────────────────────────────────────────────────────────
var obstacle_gifs: Array = []   # Array[GifAnim] — every approved obstacle GIF
var background_gifs: Array = [] # Array[GifAnim]

var _session_bg = null  # GifAnim or null — re-randomised each session start
var _bg_idx : int = 0

var _pending: Array = []  # pool entries still to download
var _active_workers: int = 0  # parallel download workers in flight
const MAX_WORKERS := 8

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_pool_fetched)
	var err := req.request(SERVER + "/api/pool")
	if err != OK:
		push_warning("GifPool: server unreachable — playing without GIFs")
		pool_ready.emit()

# ── Pool fetch ────────────────────────────────────────────────────────────────
func _on_pool_fetched(result: int, code: int, _headers, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("GifPool: pool fetch failed (result=%d code=%d)" % [result, code])
		pool_ready.emit()
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		push_warning("GifPool: invalid JSON from server")
		pool_ready.emit()
		return

	for entry in parsed.get("obstacles", []):
		var e: Dictionary = entry
		e["gif_type"] = "obstacle"
		_pending.append(e)
	for entry in parsed.get("backgrounds", []):
		var e: Dictionary = entry
		e["gif_type"] = "background"
		_pending.append(e)

	if _pending.is_empty():
		pool_ready.emit()
		return

	# Fan out parallel download workers — each pulls entries off _pending until
	# the queue is empty, then decrements _active_workers. The last worker
	# emits pool_ready.
	var workers : int = mini(MAX_WORKERS, _pending.size())
	_active_workers = workers
	for i in workers:
		_download_next()

# ── Spritesheet download loop ─────────────────────────────────────────────────
func _download_next() -> void:
	if _pending.is_empty():
		# This worker is done — when the last one exits, emit pool_ready.
		_active_workers -= 1
		if _active_workers <= 0:
			assign_session_gifs()
			pool_ready.emit()
		return

	var entry: Dictionary  = _pending.pop_front()
	var gif_id: String     = entry["id"]
	var cache_path: String = "user://gif_cache/%s/spritesheet.png" % gif_id

	# Always re-download from server so updates show up immediately.
	# Cache file (if present) is overwritten by the response body.
	var abs_dir := OS.get_user_data_dir() + "/gif_cache/" + gif_id
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _hdrs, body):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			# Write to cache
			var f := FileAccess.open(cache_path, FileAccess.WRITE)
			if f:
				f.store_buffer(body)
				f.close()
			_load_spritesheet(entry, cache_path)
		else:
			push_warning("GifPool: failed to download spritesheet for %s" % gif_id)
		_download_subject(entry, func(): _download_next())
	)
	var err := req.request("%s/api/spritesheet/%s" % [SERVER, gif_id])
	if err != OK:
		push_warning("GifPool: request error for %s" % gif_id)
		_download_next()

# ── Subject spritesheet download ──────────────────────────────────────────────
func _download_subject(entry: Dictionary, on_done: Callable) -> void:
	if not entry.get("has_subject", false):
		on_done.call()
		return
	var gif_id: String     = entry["id"]
	var subject_path: String = "user://gif_cache/%s/subject_spritesheet.png" % gif_id
	# Always re-download — cache file is overwritten on success.
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _hdrs, body):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var f := FileAccess.open(subject_path, FileAccess.WRITE)
			if f:
				f.store_buffer(body)
				f.close()
			_load_subject_spritesheet(entry, subject_path)
		else:
			push_warning("GifPool: failed to download subject for %s" % gif_id)
		on_done.call()
	)
	var err := req.request("%s/api/subject/%s" % [SERVER, gif_id])
	if err != OK:
		push_warning("GifPool: subject request error for %s" % gif_id)
		on_done.call()

# ── Load spritesheet from disk → GifAnim ────────────────────────────────────
func _load_spritesheet(entry: Dictionary, cache_path: String) -> void:
	var f := FileAccess.open(cache_path, FileAccess.READ)
	if not f:
		push_warning("GifPool: cannot open %s" % cache_path)
		return
	var data := f.get_buffer(f.get_length())
	f.close()

	var img := Image.new()
	if img.load_png_from_buffer(data) != OK:
		push_warning("GifPool: bad PNG for %s" % entry["id"])
		return

	var frame_count: int = int(entry.get("frame_count", 1))
	var frame_w: int     = int(entry.get("frame_width",  64))
	var frame_h: int     = int(entry.get("frame_height", 64))
	var fps: float       = float(entry.get("fps", 10.0))

	var anim := GifAnim.new()
	anim.fps         = fps
	anim.frame_count = frame_count

	for i in frame_count:
		var region := Rect2i(i * frame_w, 0, frame_w, frame_h)
		var fimg   := img.get_region(region)
		anim.frames.append(ImageTexture.create_from_image(fimg))

	# Load per-frame polygons (normalized [0,1] from server)
	var raw_polys = entry.get("polygons", [])
	for raw_poly in raw_polys:
		var pva := PackedVector2Array()
		for pt in raw_poly:
			if pt is Array and pt.size() >= 2:
				pva.append(Vector2(float(pt[0]), float(pt[1])))
		anim.polygons.append(pva)

	entry["_anim"] = anim  # reference for subject loading

	if entry.get("gif_type") == "obstacle":
		obstacle_gifs.append(anim)
	else:
		background_gifs.append(anim)

# ── Load subject spritesheet → GifAnim.subject_frames ────────────────────────
func _load_subject_spritesheet(entry: Dictionary, cache_path: String) -> void:
	var anim = entry.get("_anim")
	if anim == null:
		return
	var f := FileAccess.open(cache_path, FileAccess.READ)
	if not f:
		push_warning("GifPool: cannot open subject %s" % cache_path)
		return
	var data := f.get_buffer(f.get_length())
	f.close()
	var img := Image.new()
	if img.load_png_from_buffer(data) != OK:
		push_warning("GifPool: bad subject PNG for %s" % entry["id"])
		return
	var frame_count: int = int(entry.get("frame_count", 1))
	var frame_w: int     = int(entry.get("frame_width",  64))
	var frame_h: int     = int(entry.get("frame_height", 64))
	for i in frame_count:
		var region := Rect2i(i * frame_w, 0, frame_w, frame_h)
		var fimg   := img.get_region(region)
		anim.subject_frames.append(ImageTexture.create_from_image(fimg))

# ── Session assignment ────────────────────────────────────────────────────────
func assign_session_gifs() -> void:
	_session_bg = null
	if not background_gifs.is_empty():
		_bg_idx = randi() % background_gifs.size()
		_session_bg = background_gifs[_bg_idx]
	elif not obstacle_gifs.is_empty():
		# Fall back to a random obstacle GIF so the background is never empty
		_bg_idx = randi() % obstacle_gifs.size()
		_session_bg = obstacle_gifs[_bg_idx]

# ── Public API ────────────────────────────────────────────────────────────────
func get_obstacle_gif(_obs_type: String):  # -> GifAnim or null
	# Returns a fresh random pick from the obstacle pool on every call,
	# preferring GIFs that have polygon data so every obstacle can render
	# as a silhouette contour. Falls back to the full pool only if no GIF
	# has polygon data.
	if obstacle_gifs.is_empty():
		return null
	var with_poly : Array = []
	for ga in obstacle_gifs:
		if not ga.polygons.is_empty():
			with_poly.append(ga)
	if not with_poly.is_empty():
		return with_poly[randi() % with_poly.size()]
	return obstacle_gifs[randi() % obstacle_gifs.size()]

func get_background_gif():                 # -> GifAnim or null
	return _session_bg

func cycle_background_gif():              # -> GifAnim or null — cycles through background pool
	if background_gifs.is_empty(): return null
	_bg_idx = (_bg_idx + 1) % background_gifs.size()
	_session_bg = background_gifs[_bg_idx]
	return _session_bg
