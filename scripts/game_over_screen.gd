extends CanvasLayer

## GameOverScreen — Displayed after run ends.
## Shows detailed score, combo, floor height, complete coin economy breakdown,
## and direct access to the Tower Shop.

signal revive_requested
signal restart_requested
signal main_menu_requested
signal theme_picker_requested

@onready var title_label:      Label  = $Panel/VBox/TitleLabel
@onready var score_label:      Label  = $Panel/VBox/ScoreLabel
@onready var high_score_label: Label  = $Panel/VBox/HighScoreLabel
@onready var floors_label:     Label  = $Panel/VBox/FloorsLabel
@onready var revive_button:    Button = $Panel/VBox/ReviveButton
@onready var restart_button:   Button = $Panel/VBox/RestartButton
@onready var theme_button:     Button = $Panel/VBox/ThemeButton
@onready var menu_button:      Button = $Panel/VBox/MenuButton

var _coins_summary_label: Label

func _ready() -> void:
	hide()
	_setup_coin_summary_ui()

func _setup_coin_summary_ui() -> void:
	_coins_summary_label = Label.new()
	_coins_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coins_summary_label.add_theme_font_size_override("font_size", 18)
	_coins_summary_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	var vbox: VBoxContainer = $Panel/VBox
	vbox.add_child(_coins_summary_label)
	# Insert right after floors label
	var idx := floors_label.get_index()
	vbox.move_child(_coins_summary_label, idx + 1)

	theme_button.text = "🛒 TOWER SHOP"

func show_game_over(score: int, high_score: int, can_revive: bool, floors_reached: int = 0, best_combo: int = 0, coin_breakdown: Dictionary = {}) -> void:
	score_label.text      = "Score: %d" % score
	high_score_label.text = "Best: %d" % high_score
	floors_label.text     = "Height: %d Floors  |  Best Combo: x%d" % [floors_reached, best_combo]

	var run_coins: int = coin_breakdown.get("total", 0)
	var p_coins: int = coin_breakdown.get("placement", 0)
	var a_coins: int = coin_breakdown.get("accuracy", 0)
	var c_coins: int = coin_breakdown.get("combo", 0)
	var m_coins: int = coin_breakdown.get("milestones", 0)
	var total_bal: int = SaveManager.get_coins()

	_coins_summary_label.text = "🪙 Run Reward: +%d Coins (Placement: %d, Accuracy: %d, Milestones: %d)\nTotal Balance: %d 🪙" % [
		run_coins, p_coins, a_coins + c_coins, m_coins, total_bal
	]

	if score >= high_score and score > 0:
		title_label.text = "NEW HIGH SCORE!"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	else:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.38, 1.0))

	revive_button.visible = can_revive
	show()

	# Animate panel entrance
	$Panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property($Panel, "modulate:a", 1.0, 0.35)

func _on_revive_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	revive_requested.emit()

func _on_restart_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	restart_requested.emit()

func _on_theme_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	theme_picker_requested.emit()

func _on_main_menu_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	main_menu_requested.emit()
