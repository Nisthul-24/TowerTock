extends Node

## ThemeManager — Manages environment themes, lighting palettes, and unlocks.
## Ensures theme changes NEVER modify gameplay physics or collision boundaries.

signal theme_changed(theme_id: String)
signal theme_unlocked(theme_id: String)

enum ThemeId {
	NEON_CITY,
	SUNSET_CITY,
	MORNING_METROPOLIS,
	RAINY_CITY,
	CYBERPUNK_DISTRICT
}

const THEMES: Dictionary = {
	"neon_city": {
		"id": "neon_city",
		"name": "Neon City",
		"desc": "Classic midnight skyscrapers bathed in cool cyan and neon.",
		"unlock_floors": 0,
		"sky_top": Color(0.04, 0.07, 0.16, 1.0),
		"sky_mid": Color(0.08, 0.13, 0.25, 1.0),
		"sky_bottom": Color(0.12, 0.18, 0.32, 1.0),
		"far_color": Color(0.07, 0.11, 0.20, 0.95),
		"mid_color": Color(0.10, 0.15, 0.26, 0.98),
		"fore_color": Color(0.14, 0.19, 0.30, 1.0),
		"win_warm": Color(0.98, 0.82, 0.45, 0.75),
		"win_cyan": Color(0.60, 0.85, 1.00, 0.70),
		"has_moon": true,
		"has_sun": false,
		"has_rain": false,
		"has_clouds": false
	},
	"sunset_city": {
		"id": "sunset_city",
		"name": "Sunset City",
		"desc": "Warm amber horizon with golden hour architectural highlights.",
		"unlock_floors": 5,
		"sky_top": Color(0.18, 0.08, 0.24, 1.0),
		"sky_mid": Color(0.48, 0.18, 0.28, 1.0),
		"sky_bottom": Color(0.85, 0.42, 0.22, 1.0),
		"far_color": Color(0.24, 0.12, 0.22, 0.95),
		"mid_color": Color(0.32, 0.16, 0.25, 0.98),
		"fore_color": Color(0.22, 0.14, 0.20, 1.0),
		"win_warm": Color(1.00, 0.92, 0.60, 0.85),
		"win_cyan": Color(0.95, 0.65, 0.40, 0.75),
		"has_moon": false,
		"has_sun": true,
		"has_rain": false,
		"has_clouds": false
	},
	"morning_metropolis": {
		"id": "morning_metropolis",
		"name": "Morning Metropolis",
		"desc": "Crisp morning daylight over towering modern glass towers.",
		"unlock_floors": 10,
		"sky_top": Color(0.22, 0.48, 0.82, 1.0),
		"sky_mid": Color(0.45, 0.68, 0.92, 1.0),
		"sky_bottom": Color(0.75, 0.88, 0.98, 1.0),
		"far_color": Color(0.35, 0.48, 0.62, 0.95),
		"mid_color": Color(0.28, 0.38, 0.52, 0.98),
		"fore_color": Color(0.20, 0.28, 0.38, 1.0),
		"win_warm": Color(0.95, 0.95, 1.00, 0.85),
		"win_cyan": Color(0.70, 0.90, 1.00, 0.80),
		"has_moon": false,
		"has_sun": true,
		"has_rain": false,
		"has_clouds": true
	},
	"rainy_city": {
		"id": "rainy_city",
		"name": "Rainy City",
		"desc": "Atmospheric downpour with reflective streets and stormy skies.",
		"unlock_floors": 15,
		"sky_top": Color(0.06, 0.08, 0.12, 1.0),
		"sky_mid": Color(0.12, 0.15, 0.20, 1.0),
		"sky_bottom": Color(0.18, 0.22, 0.28, 1.0),
		"far_color": Color(0.08, 0.10, 0.14, 0.95),
		"mid_color": Color(0.11, 0.14, 0.18, 0.98),
		"fore_color": Color(0.14, 0.17, 0.22, 1.0),
		"win_warm": Color(0.95, 0.80, 0.40, 0.70),
		"win_cyan": Color(0.50, 0.75, 0.90, 0.65),
		"has_moon": false,
		"has_sun": false,
		"has_rain": true,
		"has_clouds": false
	},
	"cyberpunk_district": {
		"id": "cyberpunk_district",
		"name": "Cyberpunk District",
		"desc": "High-tech future skyline pulsing with neon magenta and cyan.",
		"unlock_floors": 20,
		"sky_top": Color(0.06, 0.02, 0.14, 1.0),
		"sky_mid": Color(0.18, 0.05, 0.28, 1.0),
		"sky_bottom": Color(0.28, 0.08, 0.42, 1.0),
		"far_color": Color(0.12, 0.06, 0.22, 0.95),
		"mid_color": Color(0.16, 0.08, 0.28, 0.98),
		"fore_color": Color(0.18, 0.10, 0.30, 1.0),
		"win_warm": Color(1.00, 0.15, 0.65, 0.85), # Neon Magenta
		"win_cyan": Color(0.10, 0.95, 0.95, 0.85), # Neon Cyan
		"has_moon": true,
		"has_sun": false,
		"has_rain": false,
		"has_clouds": false
	}
}

var current_theme_id: String = "neon_city"

func _ready() -> void:
	current_theme_id = SaveManager.get_selected_theme()
	if not (current_theme_id in THEMES):
		current_theme_id = "neon_city"

func get_current_theme() -> Dictionary:
	return THEMES.get(current_theme_id, THEMES["neon_city"])

func set_theme(theme_id: String) -> bool:
	if not (theme_id in THEMES):
		return false
	if not SaveManager.is_theme_unlocked(theme_id):
		return false

	current_theme_id = theme_id
	SaveManager.set_selected_theme(theme_id)
	theme_changed.emit(current_theme_id)
	return true

func check_unlocks(max_floors_reached: int) -> void:
	for tid in THEMES:
		var tdata: Dictionary = THEMES[tid]
		var req_floors: int = tdata.get("unlock_floors", 0)
		if max_floors_reached >= req_floors and not SaveManager.is_theme_unlocked(tid):
			SaveManager.unlock_theme(tid)
			theme_unlocked.emit(tid)

func get_all_themes() -> Array:
	var res: Array = []
	for k in ["neon_city", "sunset_city", "morning_metropolis", "rainy_city", "cyberpunk_district"]:
		res.append(THEMES[k])
	return res
