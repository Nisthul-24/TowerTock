extends CanvasLayer

## ThemeSelector / Shop — Modal UI for purchasing and managing Themes and Consumable Power-Ups using Coins.

signal closed

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox
@onready var title_label: Label = $Panel/VBox/Title
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var container: VBoxContainer = $Panel/VBox/Scroll/CardsContainer
@onready var close_btn: Button = $Panel/VBox/CloseButton

enum ShopTab {
	THEMES,
	POWERUPS
}

var current_tab: ShopTab = ShopTab.THEMES
var _balance_label: Label
var _tab_container: HBoxContainer
var _btn_tab_themes: Button
var _btn_tab_powerups: Button
var _feedback_label: Label
var _feedback_tween: Tween

const POWERUP_DATA: Array[Dictionary] = [
	{
		"id": "slow_motion",
		"name": "Slow Motion",
		"desc": "Temporarily slows crane carriage and pendulum speed by 50% for 6s.",
		"price": 75,
		"icon_color": Color(0.3, 0.7, 1.0)
	},
	{
		"id": "precision_guide",
		"name": "Precision Guide",
		"desc": "Projects a vertical laser drop guide between crane and tower top.",
		"price": 100,
		"icon_color": Color(1.0, 0.85, 0.25)
	},
	{
		"id": "stability_assist",
		"name": "Stability Assist",
		"desc": "Damps excessive tower sway velocity to 0 and restores +25% stability.",
		"price": 150,
		"icon_color": Color(0.4, 0.95, 0.6)
	},
	{
		"id": "second_chance",
		"name": "Second Chance",
		"desc": "Safety drone catches and recovers one missed or fallen floor per run.",
		"price": 200,
		"icon_color": Color(0.9, 0.45, 1.0)
	}
]

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_on_close_pressed)
	_setup_shop_header()

func _setup_shop_header() -> void:
	title_label.text = "TOWER SHOP"

	# Balance display
	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 22)
	_balance_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	vbox.add_child(_balance_label)
	vbox.move_child(_balance_label, 1)

	# Tab bar
	_tab_container = HBoxContainer.new()
	_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_container.add_theme_constant_override("separation", 20)
	vbox.add_child(_tab_container)
	vbox.move_child(_tab_container, 2)

	_btn_tab_themes = Button.new()
	_btn_tab_themes.text = "🎨 CITY THEMES"
	_btn_tab_themes.custom_minimum_size = Vector2(220, 48)
	_btn_tab_themes.add_theme_font_size_override("font_size", 18)
	_btn_tab_themes.pressed.connect(func(): _switch_tab(ShopTab.THEMES))
	_tab_container.add_child(_btn_tab_themes)

	_btn_tab_powerups = Button.new()
	_btn_tab_powerups.text = "⚡ POWER-UPS"
	_btn_tab_powerups.custom_minimum_size = Vector2(220, 48)
	_btn_tab_powerups.add_theme_font_size_override("font_size", 18)
	_btn_tab_powerups.pressed.connect(func(): _switch_tab(ShopTab.POWERUPS))
	_tab_container.add_child(_btn_tab_powerups)

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 16)
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_feedback_label.modulate.a = 0.0
	vbox.add_child(_feedback_label)
	vbox.move_child(_feedback_label, 3)

func open(initial_tab: ShopTab = ShopTab.THEMES) -> void:
	current_tab = initial_tab
	_update_header()
	_refresh_cards()
	show()
	panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.25)

func _switch_tab(tab: ShopTab) -> void:
	AudioManager.play_sfx("button_click")
	current_tab = tab
	_update_header()
	_refresh_cards()

func _update_header() -> void:
	var coins := SaveManager.get_coins()
	_balance_label.text = "🪙 Coin Balance: %d" % coins

	if current_tab == ShopTab.THEMES:
		_btn_tab_themes.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		_btn_tab_powerups.add_theme_color_override("font_color", Color.WHITE)
	else:
		_btn_tab_powerups.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		_btn_tab_themes.add_theme_color_override("font_color", Color.WHITE)

func _show_feedback(msg: String, is_success: bool = false) -> void:
	_feedback_label.text = msg
	_feedback_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6) if is_success else Color(1.0, 0.4, 0.4))
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_feedback_label, "modulate:a", 1.0, 0.15)
	_feedback_tween.tween_interval(2.0)
	_feedback_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.3)

func _on_close_pressed() -> void:
	AudioManager.play_sfx("button_click")
	hide()
	closed.emit()

func _refresh_cards() -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()

	_update_header()

	if current_tab == ShopTab.THEMES:
		_build_themes_view()
	else:
		_build_powerups_view()

# ── Themes View ───────────────────────────────────────────────────

func _build_themes_view() -> void:
	var tm: Node = get_node_or_null("/root/ThemeManager")
	if not tm:
		return

	var current_id: String = tm.current_theme_id
	var all_themes: Array = tm.get_all_themes()
	var coins := SaveManager.get_coins()

	for tdata in all_themes:
		var tid: String = tdata.get("id", "")
		var tname: String = tdata.get("name", "")
		var tdesc: String = tdata.get("desc", "")
		var price: int = SaveManager.get_theme_price(tid)
		var is_unlocked: bool = SaveManager.is_theme_unlocked(tid)
		var is_selected: bool = (tid == current_id)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(500, 95)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		card.add_child(hbox)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(70, 80)
		swatch.color = tdata.get("sky_mid", Color.NAVY_BLUE)
		hbox.add_child(swatch)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info_vbox)

		var lbl_name := Label.new()
		lbl_name.text = tname
		lbl_name.add_theme_font_size_override("font_size", 22)
		lbl_name.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35) if is_selected else Color.WHITE)
		info_vbox.add_child(lbl_name)

		var lbl_desc := Label.new()
		lbl_desc.text = tdesc
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.add_theme_font_size_override("font_size", 13)
		lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		info_vbox.add_child(lbl_desc)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 50)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if is_selected:
			btn.text = "ACTIVE"
			btn.disabled = true
		elif is_unlocked:
			btn.text = "SELECT"
			btn.pressed.connect(func():
				AudioManager.play_sfx("button_click")
				tm.set_theme(tid)
				_refresh_cards()
			)
		else:
			btn.text = "BUY %d 🪙" % price
			btn.pressed.connect(func():
				if SaveManager.buy_theme(tid):
					AudioManager.play_sfx("perfect")
					_show_feedback("🎉 Unlocked %s!" % tname, true)
					tm.set_theme(tid)
					_refresh_cards()
				else:
					AudioManager.play_sfx("miss")
					var shortage := price - SaveManager.get_coins()
					_show_feedback("Need %d more coins!" % shortage, false)
			)

		hbox.add_child(btn)
		container.add_child(card)

# ── Power-Ups View ────────────────────────────────────────────────

func _build_powerups_view() -> void:
	for pdata in POWERUP_DATA:
		var pid: String = pdata.id
		var pname: String = pdata.name
		var pdesc: String = pdata.desc
		var price: int = pdata.price
		var icon_col: Color = pdata.icon_color
		var owned_count := SaveManager.get_powerup_count(pid)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(500, 95)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		card.add_child(hbox)

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(70, 80)
		icon.color = icon_col
		hbox.add_child(icon)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info_vbox)

		var lbl_name := Label.new()
		lbl_name.text = "%s  (Owned: x%d)" % [pname, owned_count]
		lbl_name.add_theme_font_size_override("font_size", 20)
		lbl_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		info_vbox.add_child(lbl_name)

		var lbl_desc := Label.new()
		lbl_desc.text = pdesc
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.add_theme_font_size_override("font_size", 13)
		lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		info_vbox.add_child(lbl_desc)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 50)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.text = "+1 (%d 🪙)" % price

		btn.pressed.connect(func():
			if SaveManager.buy_powerup(pid):
				AudioManager.play_sfx("perfect")
				_show_feedback("Purchased 1x %s!" % pname, true)
				_refresh_cards()
			else:
				AudioManager.play_sfx("miss")
				var shortage := price - SaveManager.get_coins()
				_show_feedback("Need %d more coins!" % shortage, false)
		)

		hbox.add_child(btn)
		container.add_child(card)
