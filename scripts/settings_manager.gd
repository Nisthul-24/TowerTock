extends Node

## SettingsManager — Read/write wrapper around SaveManager for runtime preferences

signal settings_changed

func _ready() -> void:
	pass

func get_music_enabled() -> bool:
	return SaveManager.get_music_enabled()

func set_music_enabled(v: bool) -> void:
	AudioManager.set_music_enabled(v)
	settings_changed.emit()

func get_sfx_enabled() -> bool:
	return SaveManager.get_sfx_enabled()

func set_sfx_enabled(v: bool) -> void:
	AudioManager.set_sfx_enabled(v)
	settings_changed.emit()

func get_vibration_enabled() -> bool:
	return SaveManager.get_vibration_enabled()

func set_vibration_enabled(v: bool) -> void:
	SaveManager.set_vibration_enabled(v)
	settings_changed.emit()

func vibrate(duration_ms: int = 50) -> void:
	if get_vibration_enabled() and OS.get_name() == "Android":
		Input.vibrate_handheld(duration_ms)
