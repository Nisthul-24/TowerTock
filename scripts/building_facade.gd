extends Node

## BuildingFacade — Generates rich, authentic urban architectural facades for TowerTock.
## Every floor retains identical gameplay dimensions: 220px wide x 100px tall.
## Taller, narrower proportions provide authentic skyscraper aesthetics and precision physics.

const FLOOR_WIDTH  := 220.0
const FLOOR_HEIGHT := 100.0

enum Style {
	RED_BRICK_BROWNSTONE,
	WARM_TERRACOTTA,
	AZURE_GLASS_OFFICE,
	SLATE_CONCRETE_LOFT,
	EMERALD_ECO_TOWER,
	VIOLET_LUXURY,
	PENTHOUSE_CROWN
}

enum SpecialType {
	NONE,
	GOLDEN,
	REINFORCED,
	HEAVY
}

static func create_floor(style_index: int, special: SpecialType = SpecialType.NONE) -> Node2D:
	var floor_node := Node2D.new()
	floor_node.name = "BuildingFloor"
	floor_node.set_meta("width", FLOOR_WIDTH)
	floor_node.set_meta("height", FLOOR_HEIGHT)

	var s: Style = (style_index % 7) as Style

	# 1. Base drop shadow on bottom edge
	var shadow := ColorRect.new()
	shadow.name = "BaseShadow"
	shadow.size = Vector2(FLOOR_WIDTH, 7.0)
	shadow.position = Vector2(-FLOOR_WIDTH / 2.0, FLOOR_HEIGHT / 2.0 - 5.0)
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	floor_node.add_child(shadow)

	# 2. Build architectural style or special floor
	match special:
		SpecialType.GOLDEN:
			floor_node.set_meta("special_type", "golden")
			_build_golden(floor_node)
		SpecialType.REINFORCED:
			floor_node.set_meta("special_type", "reinforced")
			_build_reinforced(floor_node)
		SpecialType.HEAVY:
			floor_node.set_meta("special_type", "heavy")
			_build_heavy(floor_node)
		_:
			floor_node.set_meta("special_type", "normal")
			match s:
				Style.RED_BRICK_BROWNSTONE:
					_build_red_brick(floor_node)
				Style.WARM_TERRACOTTA:
					_build_terracotta(floor_node)
				Style.AZURE_GLASS_OFFICE:
					_build_azure_glass(floor_node)
				Style.SLATE_CONCRETE_LOFT:
					_build_concrete_loft(floor_node)
				Style.EMERALD_ECO_TOWER:
					_build_emerald_eco(floor_node)
				Style.VIOLET_LUXURY:
					_build_violet_luxury(floor_node)
				Style.PENTHOUSE_CROWN:
					_build_penthouse(floor_node)

	# 3. Steel hoisting hook on top center for crane cable
	var hook := ColorRect.new()
	hook.name = "HoistHook"
	hook.size = Vector2(16.0, 10.0)
	hook.position = Vector2(-8.0, -FLOOR_HEIGHT / 2.0 - 10.0)
	hook.color = Color(0.35, 0.38, 0.42, 1.0)
	floor_node.add_child(hook)

	var hook_ring := ColorRect.new()
	hook_ring.size = Vector2(8.0, 4.0)
	hook_ring.position = Vector2(-4.0, -FLOOR_HEIGHT / 2.0 - 14.0)
	hook_ring.color = Color(0.65, 0.70, 0.75, 1.0)
	floor_node.add_child(hook_ring)

	return floor_node

# ── Special Floors: Golden, Reinforced, Heavy ─────────────────────
static func _build_golden(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.96, 0.80, 0.25, 1.0)
	parent.add_child(wall)

	# Shimmering gold cornice
	var top_c := ColorRect.new()
	top_c.size = Vector2(FLOOR_WIDTH, 7.0)
	top_c.position = Vector2(-hw, -hh)
	top_c.color = Color(1.0, 0.95, 0.60, 1.0)
	parent.add_child(top_c)

	# Windows with brilliant warm glow
	for i in range(3):
		var wx := -hw + 24.0 + i * 62.0
		var glass := ColorRect.new()
		glass.size = Vector2(48.0, 68.0)
		glass.position = Vector2(wx, -hh + 16.0)
		glass.color = Color(1.0, 0.94, 0.70, 0.95)
		parent.add_child(glass)

	# Badge banner
	var badge := Label.new()
	badge.text = "★ GOLDEN BONUS ★"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.position = Vector2(-hw, hh - 28.0)
	badge.size = Vector2(FLOOR_WIDTH, 22.0)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(0.35, 0.22, 0.05))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)

static func _build_reinforced(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.24, 0.32, 0.42, 1.0)
	parent.add_child(wall)

	# Heavy titanium cross-bracing
	var beam_top := ColorRect.new()
	beam_top.size = Vector2(FLOOR_WIDTH, 8.0)
	beam_top.position = Vector2(-hw, -hh)
	beam_top.color = Color(0.48, 0.58, 0.70, 1.0)
	parent.add_child(beam_top)

	var beam_bot := ColorRect.new()
	beam_bot.size = Vector2(FLOOR_WIDTH, 8.0)
	beam_bot.position = Vector2(-hw, hh - 8.0)
	beam_bot.color = Color(0.48, 0.58, 0.70, 1.0)
	parent.add_child(beam_bot)

	for p in range(4):
		var col := ColorRect.new()
		col.size = Vector2(10.0, FLOOR_HEIGHT)
		col.position = Vector2(-hw + p * 68.0 + 8.0, -hh)
		col.color = Color(0.38, 0.48, 0.60, 1.0)
		parent.add_child(col)

	var badge := Label.new()
	badge.text = "🛡️ REINFORCED (+15 STAB) 🛡️"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.position = Vector2(-hw, -12.0)
	badge.size = Vector2(FLOOR_WIDTH, 24.0)
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(0.40, 0.95, 0.65))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)

static func _build_heavy(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.18, 0.20, 0.24, 1.0)
	parent.add_child(wall)

	# Industrial hazard striping
	var stripe_w := 20.0
	for s in range(int(FLOOR_WIDTH / stripe_w) + 1):
		if s % 2 == 0:
			var strp := ColorRect.new()
			strp.size = Vector2(stripe_w, 8.0)
			strp.position = Vector2(-hw + s * stripe_w, -hh)
			strp.color = Color(0.92, 0.75, 0.15, 0.85)
			parent.add_child(strp)

	var badge := Label.new()
	badge.text = "⚓ HEAVY MASS ⚓"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.position = Vector2(-hw, -12.0)
	badge.size = Vector2(FLOOR_WIDTH, 24.0)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)

# ── Style 1: Red Brick Brownstone (Historic East Coast) ───────────
static func _build_red_brick(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	# Brick wall body
	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.68, 0.24, 0.18, 1.0)
	parent.add_child(wall)

	# Subtle mortar courses
	for row in range(1, 8):
		var mortar := ColorRect.new()
		mortar.size = Vector2(FLOOR_WIDTH, 1.0)
		mortar.position = Vector2(-hw, -hh + row * 12.0)
		mortar.color = Color(0.50, 0.18, 0.14, 0.6)
		parent.add_child(mortar)

	# Roof/floor dividing cornices
	var top_cornice := ColorRect.new()
	top_cornice.size = Vector2(FLOOR_WIDTH, 6.0)
	top_cornice.position = Vector2(-hw, -hh)
	top_cornice.color = Color(0.85, 0.82, 0.75, 1.0)
	parent.add_child(top_cornice)

	var bot_cornice := ColorRect.new()
	bot_cornice.size = Vector2(FLOOR_WIDTH, 5.0)
	bot_cornice.position = Vector2(-hw, hh - 5.0)
	bot_cornice.color = Color(0.48, 0.16, 0.12, 1.0)
	parent.add_child(bot_cornice)

	# 2 Tiers of 3 Elegant Windows (6 windows total)
	var win_w := 34.0
	var win_h := 32.0
	var xs := [-hw + 24.0, -win_w / 2.0, hw - 24.0 - win_w]
	var ys := [-hh + 12.0, -hh + 54.0]

	for y in ys:
		for x in xs:
			# Stone Lintel
			var lintel := ColorRect.new()
			lintel.size = Vector2(win_w + 6.0, 4.0)
			lintel.position = Vector2(x - 3.0, y - 4.0)
			lintel.color = Color(0.90, 0.88, 0.82, 1.0)
			parent.add_child(lintel)

			# Frame
			var frame := ColorRect.new()
			frame.size = Vector2(win_w, win_h)
			frame.position = Vector2(x, y)
			frame.color = Color(0.18, 0.14, 0.12, 1.0)
			parent.add_child(frame)

			# Glass pane
			var glass := ColorRect.new()
			glass.size = Vector2(win_w - 4.0, win_h - 4.0)
			glass.position = Vector2(x + 2.0, y + 2.0)
			glass.color = Color(0.24, 0.42, 0.58, 0.95)
			parent.add_child(glass)

			# Window sash cross-mullion
			var mull_v := ColorRect.new()
			mull_v.size = Vector2(2.0, win_h - 4.0)
			mull_v.position = Vector2(x + win_w / 2.0 - 1.0, y + 2.0)
			mull_v.color = Color(0.85, 0.82, 0.75, 0.8)
			parent.add_child(mull_v)

			# Stone Sill
			var sill := ColorRect.new()
			sill.size = Vector2(win_w + 8.0, 4.0)
			sill.position = Vector2(x - 4.0, y + win_h)
			sill.color = Color(0.90, 0.88, 0.82, 1.0)
			parent.add_child(sill)

# ── Style 2: Warm Terracotta Modern Apartments ────────────────────
static func _build_terracotta(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.86, 0.46, 0.22, 1.0)
	parent.add_child(wall)

	# Left/Right balcony frames
	var left_balcony := ColorRect.new()
	left_balcony.size = Vector2(55.0, 78.0)
	left_balcony.position = Vector2(-hw + 14.0, -hh + 11.0)
	left_balcony.color = Color(0.18, 0.18, 0.22, 1.0)
	parent.add_child(left_balcony)

	var left_glass := ColorRect.new()
	left_glass.size = Vector2(49.0, 72.0)
	left_glass.position = Vector2(-hw + 17.0, -hh + 14.0)
	left_glass.color = Color(0.35, 0.62, 0.78, 0.9)
	parent.add_child(left_glass)

	# Balcony Railing
	var left_rail := ColorRect.new()
	left_rail.size = Vector2(55.0, 16.0)
	left_rail.position = Vector2(-hw + 14.0, -hh + 73.0)
	left_rail.color = Color(0.92, 0.90, 0.85, 0.9)
	parent.add_child(left_rail)

	# Right balcony frame
	var right_balcony := ColorRect.new()
	right_balcony.size = Vector2(55.0, 78.0)
	right_balcony.position = Vector2(hw - 69.0, -hh + 11.0)
	right_balcony.color = Color(0.18, 0.18, 0.22, 1.0)
	parent.add_child(right_balcony)

	var right_glass := ColorRect.new()
	right_glass.size = Vector2(49.0, 72.0)
	right_glass.position = Vector2(hw - 66.0, -hh + 14.0)
	right_glass.color = Color(0.35, 0.62, 0.78, 0.9)
	parent.add_child(right_glass)

	var right_rail := ColorRect.new()
	right_rail.size = Vector2(55.0, 16.0)
	right_rail.position = Vector2(hw - 69.0, -hh + 73.0)
	right_rail.color = Color(0.92, 0.90, 0.85, 0.9)
	parent.add_child(right_rail)

	# Center floor-to-ceiling picture window with warm glow
	var center_win := ColorRect.new()
	center_win.size = Vector2(60.0, 78.0)
	center_win.position = Vector2(-30.0, -hh + 11.0)
	center_win.color = Color(0.98, 0.86, 0.52, 0.85)
	parent.add_child(center_win)

	var center_trim := ColorRect.new()
	center_trim.size = Vector2(60.0, 3.0)
	center_trim.position = Vector2(-30.0, -hh + 48.0)
	center_trim.color = Color(0.35, 0.22, 0.14, 0.8)
	parent.add_child(center_trim)

	# Top and bottom architectural ledges
	var top_band := ColorRect.new()
	top_band.size = Vector2(FLOOR_WIDTH, 5.0)
	top_band.position = Vector2(-hw, -hh)
	top_band.color = Color(0.96, 0.92, 0.85, 1.0)
	parent.add_child(top_band)

# ── Style 3: Azure Modern Glass Corporate Tower ───────────────────
static func _build_azure_glass(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	# Dark structural core
	var core := ColorRect.new()
	core.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	core.position = Vector2(-hw, -hh)
	core.color = Color(0.08, 0.14, 0.24, 1.0)
	parent.add_child(core)

	# 4 Glass curtain wall bays
	var bay_w := 48.0
	var bay_gap := 4.0
	for b in range(4):
		var bx := -hw + 8.0 + b * (bay_w + bay_gap)
		var glass := ColorRect.new()
		glass.size = Vector2(bay_w, 88.0)
		glass.position = Vector2(bx, -hh + 6.0)
		glass.color = Color(0.18, 0.42, 0.68, 0.9)
		parent.add_child(glass)

		# Glass reflection highlight streak
		var sheen := ColorRect.new()
		sheen.size = Vector2(10.0, 88.0)
		sheen.position = Vector2(bx + 6.0, -hh + 6.0)
		sheen.color = Color(0.60, 0.82, 1.0, 0.35)
		parent.add_child(sheen)

	# Polished aluminium spandrel bands
	var top_spandrel := ColorRect.new()
	top_spandrel.size = Vector2(FLOOR_WIDTH, 6.0)
	top_spandrel.position = Vector2(-hw, -hh)
	top_spandrel.color = Color(0.82, 0.88, 0.95, 1.0)
	parent.add_child(top_spandrel)

	var mid_spandrel := ColorRect.new()
	mid_spandrel.size = Vector2(FLOOR_WIDTH, 3.0)
	mid_spandrel.position = Vector2(-hw, -hh + 48.0)
	mid_spandrel.color = Color(0.70, 0.78, 0.88, 0.8)
	parent.add_child(mid_spandrel)

# ── Style 4: Slate Concrete Industrial Loft ───────────────────────
static func _build_concrete_loft(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var concrete := ColorRect.new()
	concrete.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	concrete.position = Vector2(-hw, -hh)
	concrete.color = Color(0.32, 0.36, 0.42, 1.0)
	parent.add_child(concrete)

	# Left & right structural piers
	var left_pier := ColorRect.new()
	left_pier.size = Vector2(16.0, FLOOR_HEIGHT)
	left_pier.position = Vector2(-hw, -hh)
	left_pier.color = Color(0.24, 0.28, 0.34, 1.0)
	parent.add_child(left_pier)

	var right_pier := ColorRect.new()
	right_pier.size = Vector2(16.0, FLOOR_HEIGHT)
	right_pier.position = Vector2(hw - 16.0, -hh)
	right_pier.color = Color(0.24, 0.28, 0.34, 1.0)
	parent.add_child(right_pier)

	# 2 Tiers of dark bronze industrial windows
	var win_w := 78.0
	var win_h := 36.0
	var xs := [-hw + 26.0, hw - 26.0 - win_w]
	var ys := [-hh + 10.0, -hh + 54.0]

	for y in ys:
		for x in xs:
			var frame := ColorRect.new()
			frame.size = Vector2(win_w, win_h)
			frame.position = Vector2(x, y)
			frame.color = Color(0.12, 0.14, 0.16, 1.0)
			parent.add_child(frame)

			var glass := ColorRect.new()
			glass.size = Vector2(win_w - 4.0, win_h - 4.0)
			glass.position = Vector2(x + 2.0, y + 2.0)
			glass.color = Color(0.28, 0.48, 0.58, 0.85)
			parent.add_child(glass)

			# Industrial crossbars
			var bar := ColorRect.new()
			bar.size = Vector2(win_w - 4.0, 2.0)
			bar.position = Vector2(x + 2.0, y + win_h / 2.0 - 1.0)
			bar.color = Color(0.12, 0.14, 0.16, 0.9)
			parent.add_child(bar)

	# Heavy concrete floor dividing beam
	var beam := ColorRect.new()
	beam.size = Vector2(FLOOR_WIDTH, 6.0)
	beam.position = Vector2(-hw, -hh)
	beam.color = Color(0.44, 0.48, 0.54, 1.0)
	parent.add_child(beam)

# ── Style 5: Emerald Eco-Skyscraper ───────────────────────────────
static func _build_emerald_eco(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.16, 0.28, 0.24, 1.0)
	parent.add_child(wall)

	# Vertical architectural fins (bronze/emerald)
	for i in range(5):
		var fin := ColorRect.new()
		fin.size = Vector2(4.0, FLOOR_HEIGHT)
		fin.position = Vector2(-hw + 14.0 + i * 48.0, -hh)
		fin.color = Color(0.38, 0.65, 0.50, 0.9)
		parent.add_child(fin)

	# High-efficiency green glass bays
	for i in range(4):
		var glass := ColorRect.new()
		glass.size = Vector2(40.0, 78.0)
		glass.position = Vector2(-hw + 20.0 + i * 48.0, -hh + 11.0)
		glass.color = Color(0.22, 0.52, 0.42, 0.88)
		parent.add_child(glass)

	# Living green balcony planter band at floor bottom
	var planter := ColorRect.new()
	planter.size = Vector2(FLOOR_WIDTH, 10.0)
	planter.position = Vector2(-hw, hh - 10.0)
	planter.color = Color(0.22, 0.42, 0.28, 1.0)
	parent.add_child(planter)

	var leaves := ColorRect.new()
	leaves.size = Vector2(FLOOR_WIDTH - 20.0, 4.0)
	leaves.position = Vector2(-hw + 10.0, hh - 12.0)
	leaves.color = Color(0.45, 0.75, 0.40, 0.95)
	parent.add_child(leaves)

# ── Style 6: Violet Luxury Tower ──────────────────────────────────
static func _build_violet_luxury(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.20, 0.14, 0.28, 1.0)
	parent.add_child(wall)

	# Gold/brass vertical louvres
	var gold_trim_l := ColorRect.new()
	gold_trim_l.size = Vector2(6.0, FLOOR_HEIGHT)
	gold_trim_l.position = Vector2(-hw + 8.0, -hh)
	gold_trim_l.color = Color(0.92, 0.78, 0.35, 1.0)
	parent.add_child(gold_trim_l)

	var gold_trim_r := ColorRect.new()
	gold_trim_r.size = Vector2(6.0, FLOOR_HEIGHT)
	gold_trim_r.position = Vector2(hw - 14.0, -hh)
	gold_trim_r.color = Color(0.92, 0.78, 0.35, 1.0)
	parent.add_child(gold_trim_r)

	# Penthouse tinted windows with interior chandelier glow
	var win_w := 48.0
	var win_h := 74.0
	for i in range(3):
		var wx := -hw + 26.0 + i * 58.0
		var frame := ColorRect.new()
		frame.size = Vector2(win_w, win_h)
		frame.position = Vector2(wx, -hh + 13.0)
		frame.color = Color(0.12, 0.08, 0.16, 1.0)
		parent.add_child(frame)

		var glass := ColorRect.new()
		glass.size = Vector2(win_w - 4.0, win_h - 4.0)
		glass.position = Vector2(wx + 2.0, -hh + 15.0)
		glass.color = Color(0.85, 0.72, 0.45, 0.65)
		parent.add_child(glass)

	# Top gold cornice
	var cornice := ColorRect.new()
	cornice.size = Vector2(FLOOR_WIDTH, 6.0)
	cornice.position = Vector2(-hw, -hh)
	cornice.color = Color(0.94, 0.82, 0.40, 1.0)
	parent.add_child(cornice)

# ── Style 7: Penthouse Crown Parapet ──────────────────────────────
static func _build_penthouse(parent: Node2D) -> void:
	var hw := FLOOR_WIDTH / 2.0
	var hh := FLOOR_HEIGHT / 2.0

	var wall := ColorRect.new()
	wall.size = Vector2(FLOOR_WIDTH, FLOOR_HEIGHT)
	wall.position = Vector2(-hw, -hh)
	wall.color = Color(0.24, 0.28, 0.36, 1.0)
	parent.add_child(wall)

	# Arched central observation window
	var arch := ColorRect.new()
	arch.size = Vector2(90.0, 70.0)
	arch.position = Vector2(-45.0, -hh + 15.0)
	arch.color = Color(0.12, 0.16, 0.22, 1.0)
	parent.add_child(arch)

	var arch_glass := ColorRect.new()
	arch_glass.size = Vector2(82.0, 64.0)
	arch_glass.position = Vector2(-41.0, -hh + 18.0)
	arch_glass.color = Color(0.35, 0.65, 0.85, 0.9)
	parent.add_child(arch_glass)

	# Classical balustrade balusters
	for b in range(12):
		var baluster := ColorRect.new()
		baluster.size = Vector2(6.0, 14.0)
		baluster.position = Vector2(-hw + 14.0 + b * 17.0, -hh)
		baluster.color = Color(0.88, 0.90, 0.94, 1.0)
		parent.add_child(baluster)

	# Heavy neoclassical crown ledge
	var crown := ColorRect.new()
	crown.size = Vector2(FLOOR_WIDTH + 8.0, 6.0)
	crown.position = Vector2(-hw - 4.0, -hh - 4.0)
	crown.color = Color(0.96, 0.96, 0.98, 1.0)
	parent.add_child(crown)
