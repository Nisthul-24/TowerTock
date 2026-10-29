extends Node2D

## Main Menu scene controller with Tower Shop and persistent Coin balance display.

@onready var high_score_label: Label = $UI/VBox/HighScoreLabel
@onready var music_toggle: Button = $UI/BottomBar/MusicToggle
@onready var sfx_toggle: Button   = $UI/BottomBar/SfxToggle
@onready var theme_selector: CanvasLayer = $ThemeSelector
@onready var themes_button: Button = $UI/VBox/ThemesButton

var _coin_pill: PanelContainer
var _coin_label: Label

func _ready() -> void:
	if not GameStateManager.is_in_state(GameStateManager.GameState.MAIN_MENU):
		GameStateManager.transition_to(GameStateManager.GameState.MAIN_MENU)
	themes_button.text = "🛒 TOWER SHOP"
	_setup_coin_counter()
	_refresh_high_score()
	_refresh_audio_buttons()
	_refresh_coins()
	AudioManager.play_music()

	if not SaveManager.coins_changed.is_connected(_on_coins_changed):
		SaveManager.coins_changed.connect(_on_coins_changed)

func _setup_coin_counter() -> void:
	_coin_pill = PanelContainer.new()
	_coin_pill.position = Vector2(1080 - 240, 30)
	_coin_pill.size = Vector2(200, 50)
	$UI.add_child(_coin_pill)

	_coin_label = Label.new()
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 24)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	_coin_pill.add_child(_coin_label)

func _refresh_coins() -> void:
	if _coin_label:
		_coin_label.text = "🪙 %d" % SaveManager.get_coins()

func _on_coins_changed(_val: int) -> void:
	_refresh_coins()

func _refresh_high_score() -> void:
	var hs := SaveManager.get_high_score()
	var bh := SaveManager.get_best_height()
	if hs > 0:
		high_score_label.text = "Best Score: %d  |  Height: %d Floors" % [hs, bh]
	else:
		high_score_label.text = "Tap PLAY to Start!"

func _refresh_audio_buttons() -> void:
	music_toggle.text = "Music ON"  if SaveManager.get_music_enabled() else "Music OFF"
	sfx_toggle.text   = "SFX ON"   if SaveManager.get_sfx_enabled()   else "SFX OFF"

func _on_play_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_themes_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	theme_selector.open()

func _on_music_toggle_pressed() -> void:
	SettingsManager.set_music_enabled(not SaveManager.get_music_enabled())
	_refresh_audio_buttons()

func _on_sfx_toggle_pressed() -> void:
	SettingsManager.set_sfx_enabled(not SaveManager.get_sfx_enabled())
	_refresh_audio_buttons()

func _on_privacy_button_pressed() -> void:
	OS.shell_open("https://your-privacy-policy-url.com")
