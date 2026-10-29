extends CanvasLayer

## PauseMenu — In-game pause overlay with audio toggles, resume, restart, and menu options.

signal resume_pressed
signal restart_pressed
signal main_menu_pressed

@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var restart_btn: Button = $Panel/VBox/RestartButton
@onready var menu_btn: Button = $Panel/VBox/MainMenuButton
@onready var music_toggle: Button = $Panel/VBox/SoundRow/MusicToggle
@onready var sfx_toggle: Button = $Panel/VBox/SoundRow/SfxToggle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if resume_btn and not resume_btn.pressed.is_connected(_on_resume_button_pressed):
		resume_btn.pressed.connect(_on_resume_button_pressed)
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart_button_pressed):
		restart_btn.pressed.connect(_on_restart_button_pressed)
	if menu_btn and not menu_btn.pressed.is_connected(_on_main_menu_button_pressed):
		menu_btn.pressed.connect(_on_main_menu_button_pressed)
	if music_toggle and not music_toggle.pressed.is_connected(_on_music_toggle_pressed):
		music_toggle.pressed.connect(_on_music_toggle_pressed)
	if sfx_toggle and not sfx_toggle.pressed.is_connected(_on_sfx_toggle_pressed):
		sfx_toggle.pressed.connect(_on_sfx_toggle_pressed)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_refresh_audio_buttons()

func _on_visibility_changed() -> void:
	if visible:
		_refresh_audio_buttons()

func show_menu() -> void:
	_refresh_audio_buttons()
	show()
	show()

func _refresh_audio_buttons() -> void:
	if music_toggle:
		music_toggle.text = "Music ON" if SaveManager.get_music_enabled() else "Music OFF"
	if sfx_toggle:
		sfx_toggle.text = "SFX ON" if SaveManager.get_sfx_enabled() else "SFX OFF"

func _on_music_toggle_pressed() -> void:
	AudioManager.play_sfx("button_click")
	SettingsManager.set_music_enabled(not SaveManager.get_music_enabled())
	_refresh_audio_buttons()

func _on_sfx_toggle_pressed() -> void:
	AudioManager.play_sfx("button_click")
	SettingsManager.set_sfx_enabled(not SaveManager.get_sfx_enabled())
	_refresh_audio_buttons()

func _on_resume_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	resume_pressed.emit()

func _on_restart_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	restart_pressed.emit()

func _on_main_menu_button_pressed() -> void:
	AudioManager.play_sfx("button_click")
	main_menu_pressed.emit()
