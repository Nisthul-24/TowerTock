extends Node

## ScoringSystem — Precision scoring, combo progression, and coin economy reward engine.
## Handles progressive floor tier coins, accuracy bonuses, combo rewards, and floor milestones.

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal placement_rated(quality: PlacementQuality, points: int)
signal high_score_beaten(new_score: int)
signal coins_earned(amount: int, breakdown: Dictionary)
signal milestone_reached(milestone_floor: int, reward: int)

enum PlacementQuality {
	PERFECT,
	EXCELLENT,
	GOOD,
	PARTIAL,
	MISS
}

# ── Base points per placement quality ─────────────────────────────
const POINTS_PERFECT:   int = 100
const POINTS_EXCELLENT: int = 75
const POINTS_GOOD:      int = 50
const POINTS_PARTIAL:   int = 20

const MAX_COMBO: int = 10

# ── Milestone coin rewards (milestone floor -> coins) ──────────────
const MILESTONE_REWARDS: Dictionary = {
	5:   10,
	10:  25,
	20:  50,
	30:  75,
	50:  100,
	100: 250
}

# ── Run State ─────────────────────────────────────────────────────
var current_score: int = 0
var current_combo: int = 0
var buildings_placed: int = 0
var high_score: int = 0

# ── Coin Economy Run Breakdown ────────────────────────────────────
var coins_earned_this_run: int = 0
var placement_coins_this_run: int = 0
var accuracy_coins_this_run: int = 0
var combo_coins_this_run: int = 0
var milestone_coins_this_run: int = 0
var milestones_awarded_this_run: Dictionary = {}

var _last_placement_scored: bool = false
var _run_settled: bool = false

func _ready() -> void:
	high_score = SaveManager.get_high_score()

## Called at the start of a new run
func reset_for_new_run() -> void:
	current_score = 0
	current_combo = 0
	buildings_placed = 0
	_last_placement_scored = false
	_run_settled = false

	coins_earned_this_run = 0
	placement_coins_this_run = 0
	accuracy_coins_this_run = 0
	combo_coins_this_run = 0
	milestone_coins_this_run = 0
	milestones_awarded_this_run.clear()

	score_changed.emit(current_score)
	combo_changed.emit(current_combo)

## Mark beginning of new building placement
func begin_new_building() -> void:
	_last_placement_scored = false

## Evaluate placement by overlap and alignment error
## Returns placement quality and calculates both points and coin rewards.
func evaluate_placement(overlap_ratio: float, alignment_error: float, floor_height: int = 1) -> PlacementQuality:
	if _last_placement_scored:
		push_warning("ScoringSystem: evaluate_placement called twice for same building!")
		return PlacementQuality.MISS

	_last_placement_scored = true
	var quality := _determine_quality(overlap_ratio, alignment_error)
	var points := _calculate_points(quality)

	_apply_score(points)
	_update_combo(quality)
	buildings_placed += 1

	if quality == PlacementQuality.PERFECT:
		SaveManager.increment_stat("perfect_count", 1)

	# Calculate and award coins for this placement
	var coin_info := _calculate_placement_coins(quality, floor_height)
	if coin_info.total > 0:
		coins_earned_this_run += coin_info.total
		placement_coins_this_run += coin_info.base
		accuracy_coins_this_run += coin_info.accuracy
		combo_coins_this_run += coin_info.combo
		milestone_coins_this_run += coin_info.milestone

		# Also credit to persistent SaveManager immediately so crash/exit doesn't lose coins
		SaveManager.add_coins(coin_info.total)
		coins_earned.emit(coin_info.total, coin_info)

	placement_rated.emit(quality, points)
	return quality

## Called when a building completely misses or slips off
func register_miss() -> void:
	_last_placement_scored = true
	current_combo = 0
	combo_changed.emit(current_combo)
	placement_rated.emit(PlacementQuality.MISS, 0)

# ── Coin Economy Calculations ─────────────────────────────────────

## Calculates progressive floor tier base reward
func get_floor_base_reward(floor_num: int) -> int:
	if floor_num <= 5:
		return 2
	elif floor_num <= 10:
		return 3
	elif floor_num <= 20:
		return 4
	elif floor_num <= 35:
		return 5
	elif floor_num <= 50:
		return 7
	else:
		return 10

## Calculates full coin reward for a landing
func _calculate_placement_coins(quality: PlacementQuality, floor_num: int) -> Dictionary:
	if quality == PlacementQuality.MISS:
		return { "base": 0, "accuracy": 0, "combo": 0, "milestone": 0, "total": 0 }

	var base := get_floor_base_reward(floor_num)
	var acc := 0

	match quality:
		PlacementQuality.PERFECT:
			acc = 3
		PlacementQuality.EXCELLENT:
			acc = 2
		PlacementQuality.GOOD:
			acc = 1
		PlacementQuality.PARTIAL:
			acc = 0

	var combo_bonus := 0
	if current_combo >= 2:
		combo_bonus = mini(current_combo - 1, 5)

	var milestone_bonus := 0
	if MILESTONE_REWARDS.has(floor_num) and not milestones_awarded_this_run.has(floor_num):
		milestones_awarded_this_run[floor_num] = true
		milestone_bonus = MILESTONE_REWARDS[floor_num]
		milestone_reached.emit(floor_num, milestone_bonus)

	var total := base + acc + combo_bonus + milestone_bonus
	return {
		"base": base,
		"accuracy": acc,
		"combo": combo_bonus,
		"milestone": milestone_bonus,
		"total": total
	}

## Final settlement at Game Over
## Returns total coins earned in this run. Safeguards against double settlement.
func settle_run_coins() -> int:
	if _run_settled:
		return coins_earned_this_run
	_run_settled = true
	return coins_earned_this_run

func get_run_coin_breakdown() -> Dictionary:
	return {
		"total": coins_earned_this_run,
		"placement": placement_coins_this_run,
		"accuracy": accuracy_coins_this_run,
		"combo": combo_coins_this_run,
		"milestones": milestone_coins_this_run
	}

# ── Quality & Scoring ─────────────────────────────────────────────

func _determine_quality(overlap: float, align_err: float) -> PlacementQuality:
	if overlap <= 0.0:
		return PlacementQuality.MISS

	# Alignment error relative to floor width (220px)
	# 8px / 220px = 0.036 (PERFECT)
	# 25px / 220px = 0.113 (EXCELLENT)
	# 55px / 220px = 0.25 (GOOD)
	# 95px / 220px = 0.43 (PARTIAL)
	var abs_err := absf(align_err)
	if abs_err <= 8.5:
		return PlacementQuality.PERFECT
	elif abs_err <= 25.0:
		return PlacementQuality.EXCELLENT
	elif abs_err <= 55.0:
		return PlacementQuality.GOOD
	elif abs_err <= 95.0:
		return PlacementQuality.PARTIAL
	return PlacementQuality.MISS

func _calculate_points(quality: PlacementQuality) -> int:
	var base: int = 0
	match quality:
		PlacementQuality.PERFECT:   base = POINTS_PERFECT
		PlacementQuality.EXCELLENT: base = POINTS_EXCELLENT
		PlacementQuality.GOOD:      base = POINTS_GOOD
		PlacementQuality.PARTIAL:   base = POINTS_PARTIAL
		PlacementQuality.MISS:      return 0

	var multiplier := 1.0 + (float(current_combo) * 0.20)
	return int(float(base) * multiplier)

func _apply_score(points: int) -> void:
	current_score += points
	if current_score > high_score:
		high_score = current_score
		SaveManager.save_high_score(high_score)
		high_score_beaten.emit(high_score)
	score_changed.emit(current_score)

func apply_bonus_points(points: int) -> void:
	_apply_score(points)

func _update_combo(quality: PlacementQuality) -> void:
	match quality:
		PlacementQuality.PERFECT:
			current_combo = min(current_combo + 1, MAX_COMBO)
		PlacementQuality.EXCELLENT:
			if current_combo > 0:
				current_combo = min(current_combo + 1, MAX_COMBO)
			else:
				current_combo = 1
		PlacementQuality.GOOD:
			# Good maintains current combo
			pass
		PlacementQuality.PARTIAL, PlacementQuality.MISS:
			current_combo = 0
	combo_changed.emit(current_combo)

func get_score() -> int:
	return current_score

func get_combo() -> int:
	return current_combo

func get_high_score() -> int:
	return high_score
