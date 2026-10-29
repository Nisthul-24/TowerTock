extends Node2D

## CityBackground — Stylized, elegant multi-layered city skyline for TowerTock.
## Dynamically adapts to active Theme (Neon City, Sunset City, Morning Metropolis,
## Rainy City, Cyberpunk District) and features vertical parallax tracking.

const VIEWPORT_W := 1080.0
const VIEWPORT_H := 1920.0

var _buildings_far: Array = []
var _buildings_mid: Array = []

var _camera_ref: Camera2D = null
var _cam_initial_y: float = 960.0
var _parallax_offset: float = 0.0

# Dynamic rain simulation state
var _rain_drops: Array[Vector2] = []
var _rain_timer: float = 0.0

func _ready() -> void:
	_generate_city_data()
	_init_rain()
	var tm: Node = get_node_or_null("/root/ThemeManager")
	if tm and not tm.theme_changed.is_connected(_on_theme_changed):
		tm.theme_changed.connect(_on_theme_changed)
	queue_redraw()

func _on_theme_changed(_new_theme: String) -> void:
	queue_redraw()

func _init_rain() -> void:
	_rain_drops.clear()
	for i in range(140):
		_rain_drops.append(Vector2(randf_range(0.0, VIEWPORT_W), randf_range(0.0, VIEWPORT_H)))

func _process(delta: float) -> void:
	if not _camera_ref or not is_instance_valid(_camera_ref):
		_camera_ref = get_viewport().get_camera_2d()
		if _camera_ref:
			_cam_initial_y = _camera_ref.global_position.y

	var needs_redraw := false

	if _camera_ref and is_instance_valid(_camera_ref):
		var target_offset: float = maxf(0.0, _cam_initial_y - _camera_ref.global_position.y)
		if absf(target_offset - _parallax_offset) > 0.5:
			_parallax_offset = lerpf(_parallax_offset, target_offset, delta * 6.0)
			needs_redraw = true

	# Rain animation if theme has rain
	var tm: Node = get_node_or_null("/root/ThemeManager")
	var theme_data: Dictionary = tm.get_current_theme() if tm else {}
	if theme_data.get("has_rain", false):
		_rain_timer += delta
		for i in range(_rain_drops.size()):
			var p: Vector2 = _rain_drops[i]
			p.y += 950.0 * delta
			p.x -= 220.0 * delta # Slanted wind
			if p.y > VIEWPORT_H:
				p.y = 0.0
				p.x = randf_range(0.0, VIEWPORT_W + 150.0)
			_rain_drops[i] = p
		needs_redraw = true

	if needs_redraw:
		queue_redraw()

func _generate_city_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	# Far skyline: 12 sleek skyscrapers with varied heights and spires
	_buildings_far.clear()
	var far_count := 12
	var far_spacing := VIEWPORT_W / far_count
	for i in range(far_count + 1):
		var w := rng.randf_range(70.0, 110.0)
		var h := rng.randf_range(650.0, 1150.0)
		var x := i * far_spacing - 20.0 + rng.randf_range(-15.0, 15.0)
		var has_spire := rng.randf() > 0.4
		_buildings_far.append({
			"x": x, "w": w, "h": h, "spire": has_spire,
			"spire_h": rng.randf_range(35.0, 75.0)
		})

	# Mid skyline: 8 distinct architectural buildings
	_buildings_mid.clear()
	var mid_count := 8
	var mid_spacing := VIEWPORT_W / mid_count
	for i in range(mid_count + 1):
		var w := rng.randf_range(110.0, 170.0)
		var h := rng.randf_range(350.0, 720.0)
		var x := i * mid_spacing - 30.0 + rng.randf_range(-18.0, 18.0)
		_buildings_mid.append({
			"x": x, "w": w, "h": h, "style": i % 3
		})

func _draw() -> void:
	var tm: Node = get_node_or_null("/root/ThemeManager")
	var t: Dictionary = tm.get_current_theme() if tm else {}

	var sky_top: Color = t.get("sky_top", Color(0.04, 0.07, 0.16, 1.0))
	var sky_mid: Color = t.get("sky_mid", Color(0.08, 0.13, 0.25, 1.0))
	var sky_bottom: Color = t.get("sky_bottom", Color(0.12, 0.18, 0.32, 1.0))
	var far_col: Color = t.get("far_color", Color(0.07, 0.11, 0.20, 0.95))
	var mid_col: Color = t.get("mid_color", Color(0.10, 0.15, 0.26, 0.98))
	var win_warm: Color = t.get("win_warm", Color(0.98, 0.82, 0.45, 0.75))
	var win_cyan: Color = t.get("win_cyan", Color(0.60, 0.85, 1.00, 0.70))

	# ── 1. Sky Gradient ─────────────────────────────────────────
	var bands := 28
	for i in range(bands):
		var frac := float(i) / float(bands)
		var col: Color
		if frac < 0.5:
			col = sky_top.lerp(sky_mid, frac * 2.0)
		else:
			col = sky_mid.lerp(sky_bottom, (frac - 0.5) * 2.0)
		var y := frac * VIEWPORT_H
		var bh := (VIEWPORT_H / float(bands)) + 1.0
		draw_rect(Rect2(0, y, VIEWPORT_W, bh), col)

	# ── 2. Atmospheric celestial bodies ─────────────────────────
	if t.get("has_moon", false):
		var moon_center := Vector2(920, 130 + _parallax_offset * 0.02)
		draw_circle(moon_center, 44.0, Color(0.98, 0.96, 0.88, 0.08)) # Halo
		draw_circle(moon_center, 38.0, Color(0.98, 0.96, 0.88, 0.92))
		draw_circle(moon_center + Vector2(14, -8), 34.0, sky_top)
	elif t.get("has_sun", false):
		var sun_center := Vector2(900, 140 + _parallax_offset * 0.02)
		draw_circle(sun_center, 65.0, Color(1.0, 0.85, 0.40, 0.15)) # Atmospheric glow
		draw_circle(sun_center, 45.0, Color(1.0, 0.92, 0.65, 0.90))

	# ── 3. Soft clouds for Morning theme ────────────────────────
	if t.get("has_clouds", false):
		for c in [Vector2(180, 120), Vector2(560, 90), Vector2(850, 160)]:
			draw_circle(c, 36.0, Color(1.0, 1.0, 1.0, 0.28))
			draw_circle(c + Vector2(25, -6), 30.0, Color(1.0, 1.0, 1.0, 0.28))
			draw_circle(c + Vector2(-25, 4), 26.0, Color(1.0, 1.0, 1.0, 0.24))

	# ── 4. Stars (Night & Cyberpunk) ────────────────────────────
	if not t.get("has_sun", false) and not t.get("has_rain", false):
		var star_rng := RandomNumberGenerator.new()
		star_rng.seed = 777
		for i in range(45):
			var sx := star_rng.randf_range(20.0, VIEWPORT_W - 20.0)
			var sy := star_rng.randf_range(20.0, VIEWPORT_H * 0.45)
			var sz := star_rng.randf_range(1.0, 2.0)
			var alpha := star_rng.randf_range(0.25, 0.70)
			draw_rect(Rect2(sx, sy, sz, sz), Color(0.95, 0.95, 1.0, alpha))

	# ── 5. Far Skyline Layer (Parallax: 0.06x) ──────────────────
	var base_far_y := 1650.0 + _parallax_offset * 0.06
	for b in _buildings_far:
		var bx: float = b["x"]
		var bw: float = b["w"]
		var bh: float = b["h"]
		var top_y := base_far_y - bh

		draw_rect(Rect2(bx, top_y, bw, bh + 450.0), far_col)

		if b["spire"]:
			var spire_h: float = b["spire_h"]
			draw_line(Vector2(bx + bw / 2.0, top_y), Vector2(bx + bw / 2.0, top_y - spire_h), far_col.lightened(0.25), 3.0)
			draw_circle(Vector2(bx + bw / 2.0, top_y - spire_h), 2.5, Color(1.0, 0.25, 0.25, 0.85))

	# ── 6. Mid Skyline Layer with illuminated windows (Parallax: 0.16x) ──
	var base_mid_y := 1680.0 + _parallax_offset * 0.16
	var win_rng := RandomNumberGenerator.new()
	win_rng.seed = 101

	for b in _buildings_mid:
		var bx: float = b["x"]
		var bw: float = b["w"]
		var bh: float = b["h"]
		var top_y := base_mid_y - bh

		draw_rect(Rect2(bx, top_y, bw, bh + 450.0), mid_col)
		draw_rect(Rect2(bx, top_y, bw, 4.0), mid_col.lightened(0.20))

		# Architectural roof trims
		if b["style"] == 1 and bw > 130.0:
			draw_rect(Rect2(bx + bw * 0.2, top_y - 14.0, bw * 0.6, 14.0), mid_col.lightened(0.10))
			draw_rect(Rect2(bx + bw * 0.2, top_y - 14.0, bw * 0.6, 2.0), mid_col.lightened(0.25))
		elif b["style"] == 2:
			var tank_x := bx + bw * 0.35
			var tank_w := bw * 0.28
			draw_rect(Rect2(tank_x, top_y - 22.0, tank_w, 22.0), mid_col.lightened(0.12))
			draw_rect(Rect2(tank_x, top_y - 22.0, tank_w, 3.0), mid_col.lightened(0.28))

		# Window rows
		var num_floors := int(bh / 32.0)
		for f in range(1, num_floors):
			var wy := top_y + f * 30.0
			if wy > base_mid_y - 40.0:
				continue
			if win_rng.randf() > 0.35:
				continue

			var win_x_start := bx + 12.0
			var win_x_end := bx + bw - 12.0
			var cols := int((win_x_end - win_x_start) / 18.0)
			for c in range(cols):
				if win_rng.randf() > 0.40:
					var wx := win_x_start + c * 18.0
					var is_warm := win_rng.randf() > 0.3
					var w_col := win_warm if is_warm else win_cyan
					draw_rect(Rect2(wx, wy, 8.0, 9.0), w_col)

	# ── 7. Rain Streaks for Rainy City ──────────────────────────
	if t.get("has_rain", false):
		for drop in _rain_drops:
			draw_line(drop, drop + Vector2(-4.0, 16.0), Color(0.70, 0.85, 1.00, 0.40), 1.5)

	# ── 8. Ground Foundation & Hazard Stripes (Parallax: 0.50x) ──
	var ground_y := 1720.0 + _parallax_offset * 0.50
	if ground_y < VIEWPORT_H + 50.0:
		draw_rect(Rect2(0, ground_y, VIEWPORT_W, 250.0), Color(0.12, 0.14, 0.18, 1.0))
		draw_rect(Rect2(0, ground_y, VIEWPORT_W, 6.0), Color(0.35, 0.38, 0.42, 1.0))

		var stripe_w := 24.0
		for s in range(int(VIEWPORT_W / stripe_w) + 1):
			if s % 2 == 0:
				draw_rect(Rect2(s * stripe_w, ground_y + 6.0, stripe_w, 8.0), Color(0.85, 0.70, 0.15, 0.75))
			else:
				draw_rect(Rect2(s * stripe_w, ground_y + 6.0, stripe_w, 8.0), Color(0.15, 0.15, 0.18, 0.9))
