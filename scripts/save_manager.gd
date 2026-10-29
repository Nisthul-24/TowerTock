extends Node

## SaveManager — Persistent data for TowerTock
## Handles high score, max tower height, theme unlocks, settings, player stats,
## coin economy balances, and consumable power-up inventory.

signal coins_changed(new_balance: int)
signal inventory_changed(item_id: String, new_count: int)

const SAVE_PATH := "user://towertock_save.cfg"
const SCHEMA_VERSION := 4

const THEME_PRICES: Dictionary = {
	"neon_city": 0,
	"sunset_city": 250,
	"morning_metropolis": 400,
	"rainy_city": 600,
	"cyberpunk_district": 1000
}

const POWERUP_PRICES: Dictionary = {
	"slow_motion": 75,
	"precision_guide": 100,
	"stability_assist": 150,
	"second_chance": 200
}

var _config := ConfigFile.new()
var _loaded := false

func _ready() -> void:
	_load()

func _load() -> void:
	var err := _config.load(SAVE_PATH)
	if err == OK:
		var version: int = _config.get_value("meta", "schema_version", 0)
		if version < SCHEMA_VERSION:
			_migrate(version)
		_loaded = true
	else:
		_apply_defaults()
		_save()
		_loaded = true

func _apply_defaults() -> void:
	_config.set_value("meta",       "schema_version",   SCHEMA_VERSION)
	_config.set_value("economy",    "coins",            0)
	_config.set_value("inventory",  "slow_motion",      1)
	_config.set_value("inventory",  "precision_guide",  1)
	_config.set_value("inventory",  "stability_assist", 1)
	_config.set_value("inventory",  "second_chance",    1)
	_config.set_value("scores",     "high_score",       0)
	_config.set_value("scores",     "best_height",      0)
	_config.set_value("themes",     "selected_theme",   "neon_city")
	_config.set_value("themes",     "unlocked_themes",  ["neon_city"])
	_config.set_value("stats",      "total_placed",     0)
	_config.set_value("stats",      "perfect_count",    0)
	_config.set_value("stats",      "total_coins_earned", 0)
	_config.set_value("audio",      "music_enabled",    true)
	_config.set_value("audio",      "sfx_enabled",      true)
	_config.set_value("audio",      "music_volume",     0.8)
	_config.set_value("audio",      "sfx_volume",       1.0)
	_config.set_value("settings",   "vibration",        true)

func _migrate(from_version: int) -> void:
	if from_version < 2:
		if not _config.has_section_key("audio", "music_volume"):
			_config.set_value("audio", "music_volume", 0.8)
		if not _config.has_section_key("audio", "sfx_volume"):
			_config.set_value("audio", "sfx_volume", 1.0)
	if from_version < 3:
		if not _config.has_section_key("scores", "best_height"):
			_config.set_value("scores", "best_height", 0)
		if not _config.has_section_key("themes", "selected_theme"):
			_config.set_value("themes", "selected_theme", "neon_city")
		if not _config.has_section_key("themes", "unlocked_themes"):
			_config.set_value("themes", "unlocked_themes", ["neon_city"])
	if from_version < 4:
		if not _config.has_section_key("economy", "coins"):
			_config.set_value("economy", "coins", 0)
		if not _config.has_section_key("inventory", "slow_motion"):
			_config.set_value("inventory", "slow_motion", 1)
		if not _config.has_section_key("inventory", "precision_guide"):
			_config.set_value("inventory", "precision_guide", 1)
		if not _config.has_section_key("inventory", "stability_assist"):
			_config.set_value("inventory", "stability_assist", 1)
		if not _config.has_section_key("inventory", "second_chance"):
			_config.set_value("inventory", "second_chance", 1)
		if not _config.has_section_key("stats", "total_coins_earned"):
			_config.set_value("stats", "total_coins_earned", 0)

	_config.set_value("meta", "schema_version", SCHEMA_VERSION)
	_save()

func _save() -> void:
	_config.save(SAVE_PATH)

# ── Coin Economy ──────────────────────────────────────────────────

func get_coins() -> int:
	return _config.get_value("economy", "coins", 0)

func set_coins(amount: int) -> void:
	var safe_amount := maxi(0, amount)
	_config.set_value("economy", "coins", safe_amount)
	_save()
	coins_changed.emit(safe_amount)

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	var current := get_coins()
	var new_bal := current + amount
	_config.set_value("economy", "coins", new_bal)
	increment_stat("total_coins_earned", amount)
	_save()
	coins_changed.emit(new_bal)

func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	var current := get_coins()
	if current < amount:
		return false
	var new_bal := current - amount
	_config.set_value("economy", "coins", new_bal)
	_save()
	coins_changed.emit(new_bal)
	return true

# ── Power-Up Consumable Inventory ─────────────────────────────────

func get_powerup_count(id: String) -> int:
	return _config.get_value("inventory", id, 0)

func add_powerup(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	var current := get_powerup_count(id)
	var new_count := current + amount
	_config.set_value("inventory", id, new_count)
	_save()
	inventory_changed.emit(id, new_count)

func set_powerup_count(id: String, amount: int) -> void:
	var new_count := maxi(0, amount)
	_config.set_value("inventory", id, new_count)
	_save()
	inventory_changed.emit(id, new_count)

func consume_powerup(id: String) -> bool:
	var current := get_powerup_count(id)
	if current <= 0:
		return false
	var new_count := current - 1
	_config.set_value("inventory", id, new_count)
	_save()
	inventory_changed.emit(id, new_count)
	return true

func buy_powerup(id: String) -> bool:
	if not POWERUP_PRICES.has(id):
		return false
	var price: int = POWERUP_PRICES[id]
	if spend_coins(price):
		add_powerup(id, 1)
		return true
	return false

# ── Theme Purchases ───────────────────────────────────────────────

func get_theme_price(theme_id: String) -> int:
	return THEME_PRICES.get(theme_id, 0)

func buy_theme(theme_id: String) -> bool:
	if not THEME_PRICES.has(theme_id):
		return false
	if is_theme_unlocked(theme_id):
		return true # Already owned, don't charge again

	var price: int = THEME_PRICES[theme_id]
	if spend_coins(price):
		unlock_theme(theme_id)
		return true
	return false

# ── High Score & Best Height ──────────────────────────────────────

func get_high_score() -> int:
	return _config.get_value("scores", "high_score", 0)

func save_high_score(score: int) -> void:
	var current: int = get_high_score()
	if score > current:
		_config.set_value("scores", "high_score", score)
		_save()

func get_best_height() -> int:
	return _config.get_value("scores", "best_height", 0)

func save_best_height(height: int) -> void:
	var current: int = get_best_height()
	if height > current:
		_config.set_value("scores", "best_height", height)
		_save()

# ── Theme Progression ─────────────────────────────────────────────

func get_selected_theme() -> String:
	return _config.get_value("themes", "selected_theme", "neon_city")

func set_selected_theme(theme_id: String) -> void:
	_config.set_value("themes", "selected_theme", theme_id)
	_save()

func get_unlocked_themes() -> Array:
	return _config.get_value("themes", "unlocked_themes", ["neon_city"])

func is_theme_unlocked(theme_id: String) -> bool:
	var list: Array = get_unlocked_themes()
	return theme_id in list

func unlock_theme(theme_id: String) -> void:
	var list: Array = get_unlocked_themes()
	if not (theme_id in list):
		list.append(theme_id)
		_config.set_value("themes", "unlocked_themes", list)
		_save()

# ── Stats ─────────────────────────────────────────────────────────

func get_stat(key: String, default_val: int = 0) -> int:
	return _config.get_value("stats", key, default_val)

func increment_stat(key: String, amount: int = 1) -> void:
	var current: int = get_stat(key, 0)
	_config.set_value("stats", key, current + amount)
	_save()

# ── Audio Preferences ─────────────────────────────────────────────

func get_music_enabled() -> bool:
	return _config.get_value("audio", "music_enabled", true)

func set_music_enabled(enabled: bool) -> void:
	_config.set_value("audio", "music_enabled", enabled)
	_save()

func get_sfx_enabled() -> bool:
	return _config.get_value("audio", "sfx_enabled", true)

func set_sfx_enabled(enabled: bool) -> void:
	_config.set_value("audio", "sfx_enabled", enabled)
	_save()

func get_music_volume() -> float:
	return _config.get_value("audio", "music_volume", 0.8)

func set_music_volume(vol: float) -> void:
	_config.set_value("audio", "music_volume", clampf(vol, 0.0, 1.0))
	_save()

func get_sfx_volume() -> float:
	return _config.get_value("audio", "sfx_volume", 1.0)

func set_sfx_volume(vol: float) -> void:
	_config.set_value("audio", "sfx_volume", clampf(vol, 0.0, 1.0))
	_save()

func get_vibration_enabled() -> bool:
	return _config.get_value("settings", "vibration", true)

func set_vibration_enabled(enabled: bool) -> void:
	_config.set_value("settings", "vibration", enabled)
	_save()
