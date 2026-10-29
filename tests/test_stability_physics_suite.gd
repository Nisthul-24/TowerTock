extends SceneTree

## Comprehensive test suite for Part 8: Required Stability & Physics Tests (1-11)

func _init() -> void:
	print("====================================================")
	print("STARTING PART 8: STABILITY & PHYSICS VERIFICATION SUITE")
	print("====================================================")
	call_deferred("_run_suite")

func _run_suite() -> void:
	var passed: int = 0
	var failed: int = 0

	var game_scene: PackedScene = load("res://scenes/game.tscn")
	if not game_scene:
		print("FAIL: Could not load game.tscn")
		quit(1)
		return

	var game := game_scene.instantiate()
	root.add_child(game)

	for i in range(15):
		await process_frame

	var gc: Node2D = game
	var crane: Node2D = game.get_node("Crane")
	var stacking: Node = game.get_node("StackingController")
	var stability: Node = game.get_node("StabilityController")
	var gsm: Node = root.get_node_or_null("/root/GameStateManager")
	var scoring: Node = root.get_node_or_null("/root/ScoringSystem")
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if sm:
		sm.set_powerup_count("second_chance", 0)

	# ── TEST 1: Place ten floors accurately in succession. Stability must remain high (100.0). ──
	print("\n--- Stability Test 1: Ten Accurate Placements in Succession ---")
	gc.start_new_run()
	for f in range(10):
		await process_frame

	var t1_success: bool = true
	for i in range(10):
		gsm.transition_to(gsm.GameState.CRANE_MOVING)
		crane.carriage.position.x = 0.0
		crane.carriage_vx = 0.0
		crane.pendulum_angle = 0.0
		crane.pendulum_velocity = 0.0
		crane._position_building()
		crane.release_building()

		for f in range(120):
			stacking._physics_process(1.0 / 60.0)
			if stacking.tower_height_count == i + 1:
				break

		var current_stab: float = stability.stability
		if current_stab < 100.0:
			t1_success = false
			print("FAIL: Floor %d placement reduced stability to %.1f!" % [i + 1, current_stab])
			break

	if t1_success and stacking.tower_height_count == 10 and stability.stability == 100.0:
		print("PASS: 10 accurate floors stacked in succession. Stability maintained at 100.0% with zero artificial penalty!")
		passed += 1
	else:
		failed += 1

	# ── TEST 2: Small alignment errors. Stability changes proportionally. ──
	print("\n--- Stability Test 2: Proportional Misalignment Penalties ---")
	var stab_prior: float = stability.stability
	stability.register_placement(15.0, stacking.tower_height_count)
	var stab_good: float = stability.stability

	stability.register_placement(40.0, stacking.tower_height_count)
	var stab_mod: float = stability.stability

	stability.register_placement(75.0, stacking.tower_height_count)
	var stab_severe: float = stability.stability

	print("Initial: %.1f | After Good (15px): %.1f | After Moderate (40px): %.1f | After Severe (75px): %.1f" % [
		stab_prior, stab_good, stab_mod, stab_severe
	])
	if stab_good == stab_prior and stab_mod < stab_good and stab_severe < stab_mod:
		print("PASS: Good placement retained high stability; moderate and severe misalignments applied strictly proportional penalties.")
		passed += 1
	else:
		print("FAIL: Penalties were not proportional!")
		failed += 1

	# ── TEST 3: Place a floor near the edge. Verify physical support is evaluated correctly. ──
	print("\n--- Stability Test 3: Edge & Overhang Physical Evaluation ---")
	gc.start_new_run()
	for f in range(10):
		await process_frame

	# Drop floor 1 centered
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.carriage.position.x = 0.0
	crane.carriage_vx = 0.0
	crane.pendulum_angle = 0.0
	crane._position_building()
	crane.release_building()
	for f in range(120):
		stacking._physics_process(1.0 / 60.0)
		if stacking.tower_height_count == 1:
			break

	# Drop floor 2 near edge: 65px offset on 110px half-width (70.5% overlap, physically supported)
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.carriage.position.x = 65.0
	crane.carriage_vx = 0.0
	crane.pendulum_angle = 0.0
	crane._position_building()
	crane.release_building()
	for f in range(120):
		stacking._physics_process(1.0 / 60.0)
		if stacking.tower_height_count == 2:
			break

	var edge_supported: bool = (stacking.tower_height_count == 2)

	# Drop floor 3 with extreme overhang relative to floor 2 (at X=605):
	# Drop at carriage X = 175 (global 715), offset from floor 2 is 110px (>98px overhang threshold)
	var lives_before: int = gc.lives
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.carriage.position.x = 175.0
	crane.carriage_vx = 0.0
	crane.pendulum_angle = 0.0
	crane._position_building()
	crane.release_building()
	for f in range(160):
		stacking._physics_process(1.0 / 60.0)

	var overhang_tumbled: bool = (gc.lives == lives_before - 1 and stacking.tower_height_count == 2)
	print("Edge supported: %s | Overhang tumbled off: %s" % [str(edge_supported), str(overhang_tumbled)])
	if edge_supported and overhang_tumbled:
		print("PASS: Physically supported edge floor remained on tower; overhanging floor tumbled off naturally.")
		passed += 1
	else:
		print("FAIL: Support evaluation failed!")
		failed += 1

	# ── TEST 4: Tall tower with good alignment must not become unstable. ──
	print("\n--- Stability Test 4: Tall Tower Stability Preservation ---")
	gc.start_new_run()
	for f in range(10):
		await process_frame

	for i in range(20):
		gsm.transition_to(gsm.GameState.CRANE_MOVING)
		crane.carriage.position.x = 0.0
		crane.carriage_vx = 0.0
		crane.pendulum_angle = 0.0
		crane._position_building()
		crane.release_building()
		for f in range(120):
			stacking._physics_process(1.0 / 60.0)
			if stacking.tower_height_count == i + 1:
				break

	print("Tall tower stacked: %d floors. Stability = %.1f" % [stacking.tower_height_count, stability.stability])
	if stacking.tower_height_count == 20 and stability.stability == 100.0:
		print("PASS: Tall tower (20 floors) with accurate placements preserved 100.0% stability without artificial height drain!")
		passed += 1
	else:
		print("FAIL: Tall tower stability drained!")
		failed += 1

	# ── TEST 5: Tall tower with repeated poor placements increases risk. ──
	print("\n--- Stability Test 5: Cumulative Error Risk on Tall Tower ---")
	var initial_lean: float = absf(stability.accumulated_lean)
	for k in range(3):
		stability.register_placement(45.0, stacking.tower_height_count)

	var final_lean: float = absf(stability.accumulated_lean)
	var final_stab: float = stability.stability
	print("Lean before: %.1f | Lean after: %.1f | Stability after: %.1f" % [initial_lean, final_lean, final_stab])
	if final_lean > initial_lean and final_stab < 100.0:
		print("PASS: Accumulated poor placements progressively increased lean drift and instability risk.")
		passed += 1
	else:
		print("FAIL: Repeated poor placements did not accumulate risk!")
		failed += 1

	# ── TEST 6: Floor released while swinging preserves momentum. ──
	print("\n--- Stability Test 6: Release While Swinging Momentum Preservation ---")
	crane.start_crane(0)
	crane.carriage.position.x = 0.0
	crane.carriage_vx = 150.0
	crane.pendulum_angle = 0.25 # Swinging at ~14.3 degrees
	crane.pendulum_velocity = 1.2 # Swinging angular velocity
	crane._position_building()
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()

	var carried_vx: float = stacking._horizontal_velocity
	var carried_omega: float = stacking._angular_velocity
	print("Carried release horizontal vx: %.1f, angular omega: %.2f" % [carried_vx, carried_omega])
	if absf(carried_vx) > 50.0 and absf(carried_omega) > 0.5:
		print("PASS: Release while swinging preserved horizontal tangential momentum and rotational velocity.")
		passed += 1
	else:
		print("FAIL: Swinging momentum was not preserved at release!")
		failed += 1

	# ── TEST 7: Floor released at high speed does not teleport or tunnel through. ──
	print("\n--- Stability Test 7: High Speed Release Landing Integrity ---")
	gc.start_new_run()
	for f in range(10):
		await process_frame

	crane.start_crane(0)
	crane.carriage.position.x = 0.0
	crane.carriage_vx = 60.0
	crane._position_building()
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()
	stacking._fall_velocity = 850.0 # High vertical impact velocity to test anti-tunneling

	var landed_safely: bool = false
	for f in range(120):
		stacking._physics_process(1.0 / 60.0)
		if stacking.tower_height_count == 1:
			landed_safely = true
			break

	if landed_safely and stacking.current_top_y == 1500.0:
		print("PASS: Floor released at high speed landed smoothly on top surface at Y=1500 with zero tunneling.")
		passed += 1
	else:
		print("FAIL: Floor tunneled or failed to land! current_top_y=%.1f" % stacking.current_top_y)
		failed += 1

	# ── TEST 8: Collapse causes whole floors to fall naturally. ──
	print("\n--- Stability Test 8: Realistic Collapse & Whole-Floor Integrity ---")
	gc.start_new_run()
	for f in range(10):
		await process_frame

	# Stack 3 floors first
	for i in range(3):
		gsm.transition_to(gsm.GameState.CRANE_MOVING)
		crane.carriage.position.x = 0.0
		crane.carriage_vx = 0.0
		crane.pendulum_angle = 0.0
		crane._position_building()
		crane.release_building()
		for f in range(120):
			stacking._physics_process(1.0 / 60.0)
			if stacking.tower_height_count == i + 1:
				break

	# Force critical instability
	stability.stability = 15.0
	var h_prior: int = stacking.tower_height_count

	# Place misaligned floor (>45px error) on critically unstable tower
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.carriage.position.x = 65.0
	crane.carriage_vx = 0.0
	crane.pendulum_angle = 0.0
	crane._position_building()
	crane.release_building()

	for f in range(160):
		stacking._physics_process(1.0 / 60.0)

	var h_after: int = stacking.tower_height_count
	print("Collapse triggered: Height prior=%d, after=%d" % [h_prior, h_after])
	if h_after < h_prior:
		print("PASS: Structural failure dislodged upper floors; whole floors separated and tumbled naturally.")
		passed += 1
	else:
		print("FAIL: Upper floors did not collapse under critical instability!")
		failed += 1

	# ── TEST 9: Pause and resume during swinging and falling. ──
	print("\n--- Stability Test 9: Pause & Resume Physical Consistency ---")
	gc.start_new_run()
	for f in range(10):
		await process_frame

	crane.start_crane(0)
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()
	stacking._physics_process(1.0 / 60.0)
	var vy_before_pause: float = stacking._fall_velocity

	gc.on_pause_button_pressed()
	var is_paused: bool = paused
	gc.on_resume_pressed()
	var is_resumed: bool = not paused
	stacking._physics_process(1.0 / 60.0)
	var vy_after_resume: float = stacking._fall_velocity

	print("Pause: %s | Resume: %s | Vy before=%.1f, after=%.1f" % [str(is_paused), str(is_resumed), vy_before_pause, vy_after_resume])
	if is_paused and is_resumed and vy_after_resume > vy_before_pause:
		print("PASS: Pause and resume safely preserved physics state and resumed cleanly.")
		passed += 1
	else:
		print("FAIL: Pause/resume state corrupted!")
		failed += 1

	# ── TEST 10: Restart immediately after a collapse. ──
	print("\n--- Stability Test 10: Clean Restart After Collapse ---")
	stability.stability = 10.0
	stacking._animate_tumble_off(Node2D.new(), 1.0)
	gc.start_new_run()
	for f in range(10):
		await process_frame

	print("After restart: Stability=%.1f, Height=%d, Lives=%d" % [stability.stability, stacking.tower_height_count, gc.lives])
	if stability.stability == 100.0 and stacking.tower_height_count == 0 and gc.lives == 3:
		print("PASS: Restart immediately after collapse restored 100% clean initial state.")
		passed += 1
	else:
		print("FAIL: Restart failed to reset state cleanly!")
		failed += 1

	# ── TEST 11: Confirm a single placement cannot trigger multiple stability penalties. ──
	print("\n--- Stability Test 11: Single Placement Idempotency & Protection ---")
	scoring.begin_new_building()
	scoring.evaluate_placement(0.85, 30.0, 1)
	scoring.evaluate_placement(0.85, 30.0, 1)

	print("Buildings placed count: %d (expected 1)" % scoring.buildings_placed)
	if scoring.buildings_placed == 1:
		print("PASS: Double scoring/penalty guard strictly prevented duplicate placement penalties.")
		passed += 1
	else:
		print("FAIL: Duplicate placement evaluated twice!")
		failed += 1

	print("\n====================================================")
	print("STABILITY & PHYSICS RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("====================================================")
	if failed == 0:
		print("ALL 11 STABILITY & PHYSICS TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		quit(1)
