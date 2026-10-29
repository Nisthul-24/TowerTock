extends Node

## DifficultyManager — Controls progressive difficulty scaling for TowerTock.
## Called by GameController at defined intervals.

## Difficulty parameters per level
const DIFFICULTY_LEVELS := [
	# level 0 — beginner
	{ "speed_multiplier": 1.0, "pendulum_influence": 0.018, "pendulum_damping": 0.97 },
	# level 1
	{ "speed_multiplier": 1.18, "pendulum_influence": 0.022, "pendulum_damping": 0.975 },
	# level 2
	{ "speed_multiplier": 1.38, "pendulum_influence": 0.028, "pendulum_damping": 0.978 },
	# level 3
	{ "speed_multiplier": 1.60, "pendulum_influence": 0.034, "pendulum_damping": 0.980 },
	# level 4
	{ "speed_multiplier": 1.85, "pendulum_influence": 0.040, "pendulum_damping": 0.982 },
	# level 5+ (max)
	{ "speed_multiplier": 2.10, "pendulum_influence": 0.046, "pendulum_damping": 0.984 },
]

func get_params(level: int) -> Dictionary:
	var idx := clampi(level, 0, DIFFICULTY_LEVELS.size() - 1)
	return DIFFICULTY_LEVELS[idx]

func get_crane_speed(level: int, base_speed: float) -> float:
	return base_speed * get_params(level)["speed_multiplier"]

func get_pendulum_influence(level: int) -> float:
	return get_params(level)["pendulum_influence"]

func get_pendulum_damping(level: int) -> float:
	return get_params(level)["pendulum_damping"]
