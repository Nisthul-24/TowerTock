extends CanvasLayer

## HUD — High-contrast portrait mobile heads-up display for TowerTock.
## Features dedicated dark backplates, non-overlapping responsive layout,
## floor height counter, dynamic stability gauge, and 48px+ mobile touch targets.

signal pause_pressed
signal powerup_slow_requested
signal powerup_stab_requested
signal powerup_guide_requested
signal powerup_second_chance_requested

@onready var score_label: Label = $ScorePanel/ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var lives_label: Label = $LivesContainer/LivesLabel
@onready var notification_label: Label = $NotificationLabel

var _notification_tween: Tween

# ── Dynamic Stability UI ──────────────────────────────────────────
var _stability_container: PanelContainer
var _stability_bar: ProgressBar
var _stability_label: Label
var _critical_flash_tween: Tween

# ── Dynamic Coin Balance Display ──────────────────────────────────
var _coin_container: PanelContainer
var _coin_label: Label
var _coin_bounce_tween: Tween

# ── Dynamic Floor Height Display ──────────────────────────────────
var _floor_container: PanelContainer
var _floor_label: Label
var _floor_bounce_tween: Tween

# ── Consumable Power-Up Buttons ───────────────────────────────────
var _powerup_container: HBoxContainer
var _btn_slow: Button
var _btn_stab: Button
var _btn_guide: Button
var _btn_second: Button

# ── Precision Guide Line ──────────────────────────────────────────
var _guide_line: Line2D
var _guide_active: bool = false

func _ready() -> void:
	update_score(0)
	update_floors(0)
	update_combo(0)
	update_lives(3)
	notification_label.modulate.a = 0.0

	_setup_coin_display()
	_setup_floor_display()
	_setup_stability_gauge()
	_setup_powerup_buttons()
	_setup_guide_line()

	refresh_powerups_ui()
	update_coins(SaveManager.get_coins())

	if not SaveManager.coins_changed.is_connected(update_coins):
		SaveManager.coins_changed.connect(update_coins)
	if not SaveManager.inventory_changed.is_connected(_on_inventory_changed):
		SaveManager.inventory_changed.connect(_on_inventory_changed)
	if not ScoringSystem.coins_earned.is_connected(show_coin_reward):
		ScoringSystem.coins_earned.connect(show_coin_reward)

func _create_card_style(border_col: Color = Color(0.24, 0.30, 0.42, 0.75)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.16, 0.88)
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _setup_coin_display() -> void:
	_coin_container = PanelContainer.new()
	_coin_container.position = Vector2(302, 20)
	_coin_container.size = Vector2(180, 76)
	_coin_container.custom_minimum_size = Vector2(180, 76)
	_coin_container.add_theme_stylebox_override("panel", _create_card_style(Color(0.85, 0.72, 0.20, 0.6)))
	add_child(_coin_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	_coin_container.add_child(vbox)

	var title := Label.new()
	title.text = "COINS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	vbox.add_child(title)

	_coin_label = Label.new()
	_coin_label.text = "🪙 0"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	vbox.add_child(_coin_label)

func _setup_floor_display() -> void:
	_floor_container = PanelContainer.new()
	_floor_container.position = Vector2(498, 20)
	_floor_container.size = Vector2(180, 76)
	_floor_container.custom_minimum_size = Vector2(180, 76)
	_floor_container.add_theme_stylebox_override("panel", _create_card_style(Color(0.25, 0.75, 0.95, 0.6)))
	add_child(_floor_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	_floor_container.add_child(vbox)

	var title := Label.new()
	title.text = "HEIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	vbox.add_child(title)

	_floor_label = Label.new()
	_floor_label.text = "FLOOR 0"
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_floor_label.add_theme_font_size_override("font_size", 24)
	_floor_label.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
	vbox.add_child(_floor_label)

func _setup_stability_gauge() -> void:
	_stability_container = PanelContainer.new()
	_stability_container.position = Vector2(20, 108)
	_stability_container.size = Vector2(740, 52)
	_stability_container.custom_minimum_size = Vector2(740, 52)
	_stability_container.add_theme_stylebox_override("panel", _create_card_style(Color(0.30, 0.36, 0.48, 0.8)))
	add_child(_stability_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_stability_container.add_child(vbox)

	_stability_label = Label.new()
	_stability_label.text = "STABILITY: 100%"
	_stability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stability_label.add_theme_font_size_override("font_size", 15)
	_stability_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	vbox.add_child(_stability_label)

	_stability_bar = ProgressBar.new()
	_stability_bar.custom_minimum_size = Vector2(720, 16)
	_stability_bar.min_value = 0.0
	_stability_bar.max_value = 100.0
	_stability_bar.value = 100.0
	_stability_bar.show_percentage = false
	vbox.add_child(_stability_bar)

func _setup_powerup_buttons() -> void:
	_powerup_container = HBoxContainer.new()
	_powerup_container.position = Vector2(24, 1780)
	_powerup_container.size = Vector2(1032, 76)
	_powerup_container.add_theme_constant_override("separation", 18)
	add_child(_powerup_container)

	_btn_slow = _create_powerup_btn("⏱️ SLOW", Color(0.3, 0.75, 1.0), func():
		_use_powerup("slow_motion", powerup_slow_requested)
	)
	_btn_stab = _create_powerup_btn("🛡️ +25 STAB", Color(0.4, 0.95, 0.6), func():
		_use_powerup("stability_assist", powerup_stab_requested)
	)
	_btn_guide = _create_powerup_btn("🎯 GUIDE", Color(1.0, 0.85, 0.25), func():
		_use_powerup("precision_guide", powerup_guide_requested)
	)
	_btn_second = _create_powerup_btn("🔄 2ND", Color(0.9, 0.45, 1.0), func():
		_use_powerup("second_chance", powerup_second_chance_requested)
	)

	_powerup_container.add_child(_btn_slow)
	_powerup_container.add_child(_btn_stab)
	_powerup_container.add_child(_btn_guide)
	_powerup_container.add_child(_btn_second)

func _create_powerup_btn(label_txt: String, col: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label_txt
	b.custom_minimum_size = Vector2(244, 76)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(on_press)
	return b

func _setup_guide_line() -> void:
	_guide_line = Line2D.new()
	_guide_line.width = 3.0
	_guide_line.default_color = Color(1.0, 0.2, 0.35, 0.75)
	_guide_line.visible = false
	add_child(_guide_line)

# ── Power-Up Consumable Inventory Logic ───────────────────────────

func refresh_powerups_ui() -> void:
	var slow_count := SaveManager.get_powerup_count("slow_motion")
	var stab_count := SaveManager.get_powerup_count("stability_assist")
	var guide_count := SaveManager.get_powerup_count("precision_guide")
	var second_count := SaveManager.get_powerup_count("second_chance")

	var stacking_node = get_node_or_null("../StackingController")
	var is_second_armed: bool = stacking_node != null and stacking_node.second_chance_active

	if _btn_slow:
		_btn_slow.text = "⏱️ SLOW (x%d)" % slow_count if slow_count > 0 else "⏱️ SLOW (0)"
		_btn_slow.disabled = (slow_count <= 0)
	if _btn_stab:
		_btn_stab.text = "🛡️ STAB (x%d)" % stab_count if stab_count > 0 else "🛡️ STAB (0)"
		_btn_stab.disabled = (stab_count <= 0)
	if _btn_guide:
		_btn_guide.text = "🎯 GUIDE (x%d)" % guide_count if guide_count > 0 else "🎯 GUIDE (0)"
		_btn_guide.disabled = (guide_count <= 0)
	if _btn_second:
		if is_second_armed:
			_btn_second.text = "🔄 ARMED"
			_btn_second.disabled = true
		elif second_count > 0:
			_btn_second.text = "🔄 2ND (x%d)" % second_count
			_btn_second.disabled = false
		else:
			_btn_second.text = "🔄 2ND (0)"
			_btn_second.disabled = true

func _use_powerup(id: String, sig: Signal) -> void:
	if SaveManager.consume_powerup(id):
		refresh_powerups_ui()
		sig.emit()
	else:
		show_notification("Out of stock! Visit the Shop.")

func _on_inventory_changed(_item_id: String, _count: int) -> void:
	refresh_powerups_ui()

func reset_powerups() -> void:
	refresh_powerups_ui()
	_guide_active = false
	if _guide_line:
		_guide_line.visible = false

func set_precision_guide_active(active: bool) -> void:
	_guide_active = active
	if _guide_line:
		_guide_line.visible = active

func update_precision_guide_pos(carriage_world_x: float, crane_world_y: float, target_y: float) -> void:
	if not _guide_active or not _guide_line:
		return
	var cam := get_viewport().get_camera_2d()
	var cam_offset := (cam.global_position - Vector2(540, 960)) if cam else Vector2.ZERO

	var screen_x := carriage_world_x - cam_offset.x
	var screen_y_top := crane_world_y - cam_offset.y
	var screen_y_bot := target_y - cam_offset.y

	_guide_line.clear_points()
	_guide_line.add_point(Vector2(screen_x, screen_y_top))
	_guide_line.add_point(Vector2(screen_x, screen_y_bot))

# ── Floor Display ─────────────────────────────────────────────────

func update_floors(val: int) -> void:
	if not _floor_label:
		return
	_floor_label.text = "FLOOR %d" % val
	if _floor_bounce_tween:
		_floor_bounce_tween.kill()
	_floor_bounce_tween = create_tween()
	_floor_bounce_tween.tween_property(_floor_container, "scale", Vector2(1.12, 1.12), 0.08)
	_floor_bounce_tween.tween_property(_floor_container, "scale", Vector2(1.0, 1.0), 0.12)

# ── Coin UI & Feedback ────────────────────────────────────────────

func update_coins(val: int) -> void:
	if not _coin_label:
		return
	_coin_label.text = "🪙 %d" % val
	if _coin_bounce_tween:
		_coin_bounce_tween.kill()
	_coin_bounce_tween = create_tween()
	_coin_bounce_tween.tween_property(_coin_container, "scale", Vector2(1.15, 1.15), 0.08)
	_coin_bounce_tween.tween_property(_coin_container, "scale", Vector2(1.0, 1.0), 0.12)

func show_coin_reward(amount: int, breakdown: Dictionary) -> void:
	if breakdown.get("milestone", 0) > 0:
		show_notification("🏆 MILESTONE REACHED! +%d COINS!" % amount)
	elif breakdown.get("accuracy", 0) >= 3:
		show_notification("⭐ PERFECT ACCURACY! +%d COINS" % amount)

# ── Stability Gauge ───────────────────────────────────────────────

func update_stability(val: float) -> void:
	if not _stability_bar:
		return
	_stability_bar.value = val

	var col: Color
	if val >= 70.0:
		col = Color(0.35, 0.95, 0.55)
		_stability_label.text = "STABILITY: %d%%" % int(val)
	elif val >= 45.0:
		col = Color(0.95, 0.88, 0.35)
		_stability_label.text = "STABILITY: %d%%" % int(val)
	elif val >= 20.0:
		col = Color(1.0, 0.55, 0.20)
		_stability_label.text = "HIGH SWAY: %d%%" % int(val)
	else:
		col = Color(1.0, 0.20, 0.25)
		_stability_label.text = "CRITICAL: %d%%!" % int(val)

	_stability_label.add_theme_color_override("font_color", col)

	if val < 20.0:
		if not _critical_flash_tween or not _critical_flash_tween.is_valid():
			_critical_flash_tween = create_tween().set_loops()
			_critical_flash_tween.tween_property(_stability_container, "modulate:a", 0.4, 0.25)
			_critical_flash_tween.tween_property(_stability_container, "modulate:a", 1.0, 0.25)
	else:
		if _critical_flash_tween and _critical_flash_tween.is_valid():
			_critical_flash_tween.kill()
		_stability_container.modulate.a = 1.0

func update_score(score: int) -> void:
	score_label.text = str(score)
	var t := create_tween()
	t.tween_property(score_label, "scale", Vector2(1.18, 1.18), 0.08)
	t.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.12)

func update_combo(combo: int) -> void:
	if combo >= 2:
		combo_label.text = "⚡ COMBO x%d" % combo
		combo_label.visible = true
		var t := create_tween()
		t.tween_property(combo_label, "scale", Vector2(1.15, 1.15), 0.1)
		t.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15)
	else:
		combo_label.visible = false

func update_lives(lives: int) -> void:
	var h := ""
	for i in range(3):
		h += "♥ " if i < lives else "♡ "
	lives_label.text = h.strip_edges()

func spawn_score_popup(text: String, world_pos: Vector2, is_perfect: bool = false) -> void:
	var popup := Label.new()
	popup.text = text
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 34 if is_perfect else 28)
	var color := Color(1.0, 0.90, 0.25, 1.0) if is_perfect else Color(0.95, 0.95, 1.0, 0.95)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.10, 0.95))
	popup.add_theme_constant_override("outline_size", 6)

	var canvas_pos := world_pos
	var cam := get_viewport().get_camera_2d()
	if cam:
		canvas_pos = world_pos - (cam.global_position - Vector2(540, 960))

	popup.position = canvas_pos - Vector2(120, 50)
	popup.size = Vector2(240, 50)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 70.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)

func show_notification(msg: String) -> void:
	notification_label.text = msg
	if _notification_tween:
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_property(notification_label, "modulate:a", 1.0, 0.2)
	_notification_tween.tween_interval(2.5)
	_notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.4)

func _on_pause_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	pause_pressed.emit()
