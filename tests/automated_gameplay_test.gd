extends SceneTree

func _init() -> void:
	print("====================================================")
	print("Starting Comprehensive TowerTock Gameplay Test Suite")
	print("====================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var passed: int = 0
	var failed: int = 0

	# 1. Load game scene
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	if not game_scene:
		print("FAIL: Could not load game.tscn")
		quit(1)
		return

	var game := game_scene.instantiate()
	root.add_child(game)

	# Allow initialization frames
	for i in range(15):
		await process_frame

	var gc: Node2D = game
	var crane: Node2D = game.get_node("Crane")
	var stacking: Node = game.get_node("StackingController")
	var stability: Node = game.get_node("StabilityController")
	var camera: Camera2D = game.get_node("GameCamera")
	var tower_root: Node2D = game.get_node("TowerRoot")
	var hud: CanvasLayer = game.get_node("HUD")
	var scoring: Node = root.get_node_or_null("/root/ScoringSystem")
	var gsm: Node = root.get_node_or_null("/root/GameStateManager")
	var tm: Node = root.get_node_or_null("/root/ThemeManager")
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if sm:
		sm.set_powerup_count("second_chance", 0)

	const EXPECTED_WIDTH: float = 220.0
	const EXPECTED_HEIGHT: float = 100.0

	crane.start_crane(0)

	# --- Test 1: Initial Game State ---
	print("\n--- Test 1: Initial Game State ---")
	var initial_score: int = scoring.get_score() if scoring else 0
	var initial_stab: float = stability.stability if stability else 100.0
	if gc.lives == 3 and initial_score == 0 and stacking.tower_height_count == 0 and initial_stab == 100.0:
		print("PASS: Game starts with 3 lives, score 0, stability 100, and 0 stacked sections.")
		passed += 1
	else:
		print("FAIL: Unexpected initial state! lives=%d, score=%d, height=%d, stability=%.1f" % [
			gc.lives, initial_score, stacking.tower_height_count, initial_stab
		])
		failed += 1

	# --- Test 2: Platform and Crane Coordinates Alignment ---
	print("\n--- Test 2: Coordinate Space Alignment ---")
	print("Platform center: %.1f, Top Y: %.1f" % [stacking.current_top_center_x, stacking.current_top_y])
	if absf(stacking.current_top_center_x - 540.0) < 5.0 and stacking.current_top_y == 1600.0:
		print("PASS: Platform bounds correctly centered around X=540 at Y=1600.")
		passed += 1
	else:
		print("FAIL: Platform bounds misaligned! Center=%.1f" % stacking.current_top_center_x)
		failed += 1

	# --- Test 3: Drop and Stack First Building (220x100px, NO TRIMMING) ---
	print("\n--- Test 3: Drop and Stack First Building (220x100px, NO TRIMMING) ---")
	crane.carriage.position.x = 0.0
	crane.pendulum_angle = 0.0
	crane.pendulum_velocity = 0.0
	crane._position_building()

	var active_b: Node2D = crane.active_building
	if not active_b:
		print("FAIL: No active building on crane!")
		failed += 1
	else:
		gsm.transition_to(gsm.GameState.CRANE_MOVING)
		crane.release_building()
		var landing_detected: bool = false
		for f in range(120):
			stacking._physics_process(1.0 / 60.0)
			if stacking.tower_height_count == 1:
				landing_detected = true
				break

		var score_val: int = scoring.get_score() if scoring else 0
		var floor_w: float = active_b.get_meta("width", 0.0)
		var floor_h: float = active_b.get_meta("height", 0.0)
		if landing_detected and score_val > 0 and floor_w == EXPECTED_WIDTH and floor_h == EXPECTED_HEIGHT:
			print("PASS: First building landed intact! Score=%d, Dimensions=%.1fx%.1f (100%% Intact)" % [score_val, floor_w, floor_h])
			passed += 1
		else:
			print("FAIL: First building failed to land intact! Height=%d, Score=%d, Dimensions=%.1fx%.1f" % [
				stacking.tower_height_count, score_val, floor_w, floor_h
			])
			failed += 1

	# --- Test 4: Consecutively stack 5 more sections (Total 6 floors, all intact 220x100px) ---
	print("\n--- Test 4: Stacking Consecutive Sections (Full Width Verification) ---")
	var consecutive_success: bool = true
	var all_full_width: bool = true

	for floor_idx in range(2, 7):
		crane.start_crane(0)
		crane.carriage.position.x = randf_range(-10.0, 10.0)
		crane.pendulum_angle = 0.0
		crane.pendulum_velocity = 0.0
		crane._position_building()
		var b_node: Node2D = crane.active_building
		gsm.transition_to(gsm.GameState.CRANE_MOVING)
		crane.release_building()

		var landed: bool = false
		for f in range(120):
			stacking._physics_process(1.0 / 60.0)
			if stacking.tower_height_count == floor_idx:
				landed = true
				break

		if not landed:
			consecutive_success = false
			print("FAIL: Floor %d failed to land! Current count=%d" % [floor_idx, stacking.tower_height_count])
			break

		if b_node and b_node.get_meta("width", 0.0) != EXPECTED_WIDTH:
			all_full_width = false

	if consecutive_success and all_full_width:
		print("PASS: Successfully stacked 6 floors! All 6 floors retain full %.1fpx width (ZERO trimming)." % EXPECTED_WIDTH)
		passed += 1
	else:
		failed += 1

	# --- Test 5: Verify Camera and Crane Follow Tower Upward ---
	print("\n--- Test 5: Camera & Crane Vertical Tracking ---")
	var tower_top_y: float = stacking.get_tower_top_world_y()
	gc._on_tower_height_changed(stacking.tower_height_count)
	print("Tower top Y: %.1f | Camera target Y: %.1f | Crane target Y: %.1f" % [tower_top_y, camera._target_y, crane.target_y])
	if camera._target_y < 960.0 and crane.target_y < 240.0:
		print("PASS: Both camera and crane targets moved upward as tower grew.")
		passed += 1
	else:
		print("FAIL: Camera or crane failed to track upward!")
		failed += 1

	# --- Test 6: Off-Center Intact Placement & Tower Stability/Lean ---
	print("\n--- Test 6: Off-Center Intact Placement & Tower Stability/Lean ---")
	var stab_before: float = stability.stability if stability else 100.0
	crane.start_crane(0)
	crane.carriage.position.x = 55.0
	crane.pendulum_angle = 0.0
	crane.pendulum_velocity = 0.0
	crane._position_building()
	var off_b: Node2D = crane.active_building
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()

	for f in range(120):
		stacking._physics_process(1.0 / 60.0)

	var stab_after: float = stability.stability if stability else 100.0
	var off_w: float = off_b.get_meta("width", 0.0) if off_b else 0.0
	print("Floor width: %.1f (expected %.1f) | Stability: before=%.1f, after=%.1f | Lean: %.1f" % [
		off_w, EXPECTED_WIDTH, stab_before, stab_after, stability.accumulated_lean
	])
	if off_w == EXPECTED_WIDTH and stab_after < stab_before and stability.accumulated_lean != 0.0:
		print("PASS: Off-center floor kept full dimensions, reduced stability, and created directional lean!")
		passed += 1
	else:
		print("FAIL: Off-center placement failed criteria!")
		failed += 1

	# --- Test 7: Power-Up Activations (Slow Motion, Stability Boost, Guide Line) ---
	print("\n--- Test 7: Power-Up Triggers & Mechanics ---")
	var stab_val_prior: float = stability.stability
	gc._on_powerup_stab()
	var stab_val_post: float = stability.stability

	gc._on_powerup_slow()
	var speed_mult_slow: float = crane.speed_multiplier

	gc._on_powerup_guide()
	var guide_is_active: bool = hud._guide_active

	print("Stability Boost: %.1f -> %.1f | Slow Mo Multiplier: %.2f | Guide Active: %s" % [
		stab_val_prior, stab_val_post, speed_mult_slow, str(guide_is_active)
	])
	if stab_val_post > stab_val_prior and speed_mult_slow == 0.5 and guide_is_active:
		print("PASS: Power-ups triggered successfully and modified physics/visuals as intended.")
		passed += 1
	else:
		print("FAIL: Power-up execution failed!")
		failed += 1

	# --- Test 8: Theme Switching without Physics Interference ---
	print("\n--- Test 8: Theme Switching Integrity ---")
	var themes_tested := ["neon_city", "sunset_city", "morning_metropolis", "rainy_city", "cyberpunk_district"]
	var all_themes_switched := true
	for tid in themes_tested:
		sm.unlock_theme(tid)
		var ok: bool = tm.set_theme(tid)
		if not ok or tm.current_theme_id != tid:
			all_themes_switched = false
			print("FAIL: Could not switch to theme %s" % tid)
			break

	# Verify dimensions and physics parameters remained invariant
	if all_themes_switched and stacking.building_width == EXPECTED_WIDTH and stacking.building_height == EXPECTED_HEIGHT:
		print("PASS: Successfully switched across all 5 themes with zero physics/collision alteration.")
		passed += 1
	else:
		failed += 1

	# --- Test 9: Severe Misalignment Tumble & Life Loss ---
	print("\n--- Test 9: Severe Misalignment Tumble & Life Loss ---")
	var lives_before: int = gc.lives
	crane.start_crane(0)
	crane.carriage.position.x = 180.0 # Severely misaligned drop (overhang > 98px)
	crane.pendulum_angle = 0.0
	crane._position_building()
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()

	for f in range(160):
		stacking._physics_process(1.0 / 60.0)

	var lives_after: int = gc.lives
	print("Lives before: %d | Lives after: %d" % [lives_before, lives_after])
	if lives_after == lives_before - 1:
		print("PASS: Unstable overhanging floor tumbled off intact and consumed exactly 1 life.")
		passed += 1
	else:
		print("FAIL: Tumble deduction incorrect! lives_before=%d, lives_after=%d" % [lives_before, lives_after])
		failed += 1

	# --- Test 10: Game Over & Rewarded Revive ---
	print("\n--- Test 10: Game Over & Rewarded Revive ---")
	gc.lives = 1
	gc._handle_miss() # Drops to 0 lives
	if gc.lives == 0:
		print("PASS: Lives reached 0.")
		passed += 1
	else:
		print("FAIL: Expected 0 lives, got %d" % gc.lives)
		failed += 1

	gc.revive_used_this_run = false
	gsm.transition_to(gsm.GameState.GAME_OVER)
	gsm.transition_to(gsm.GameState.REVIVE_AD_PENDING)
	gsm.transition_to(gsm.GameState.REVIVE_AD_SHOWING)
	gc._on_ad_reward_earned("revive", 1)
	gc._apply_revive()
	if gc.lives == 1 and gc.revive_used_this_run:
		print("PASS: Revive successfully restored 1 life and preserved tower progress.")
		passed += 1
	else:
		print("FAIL: Revive flow failed!")
		failed += 1

	# --- Test 11: 10 Consecutive Clean Restarts ---
	print("\n--- Test 11: 10 Consecutive Clean Restarts ---")
	var restarts_clean: bool = true
	for r in range(10):
		gc.start_new_run()
		await process_frame
		var s_val: int = scoring.get_score() if scoring else 0
		var r_stab: float = stability.stability if stability else 100.0
		if gc.lives != 3 or s_val != 0 or stacking.tower_height_count != 0 or tower_root.get_child_count() != 0 or r_stab != 100.0:
			restarts_clean = false
			print("FAIL: Restart #%d leaked state! lives=%d, score=%d, sections=%d, nodes=%d, stab=%.1f" % [
				r + 1, gc.lives, s_val, stacking.tower_height_count, tower_root.get_child_count(), r_stab
			])
			break

	if restarts_clean:
		print("PASS: 10 consecutive restarts completed with 100% clean state and stability reset to 100!")
		passed += 1
	else:
		failed += 1

	print("\n====================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("====================================================")
	if failed == 0:
		print("ALL TEST SCENARIOS PASSED PERFECTLY!")
		quit(0)
	else:
		quit(1)
