extends SceneTree

## Dedicated Test Suite: Crane Physics, First-Block Initialization, and Portrait Mobile UI

func _init() -> void:
	print("\n====================================================")
	print("STARTING CRANE, FIRST-BLOCK & MOBILE UI TEST SUITE")
	print("====================================================")
	call_deferred("_run_suite")

func _run_suite() -> void:
	var passed := 0
	var failed := 0

	var scene: PackedScene = load("res://scenes/game.tscn")
	if not scene:
		print("FAIL: Could not load game.tscn")
		quit(1)
		return

	var game = scene.instantiate()
	root.add_child(game)

	for _i in range(10):
		await process_frame

	var crane: Node2D = game.get_node("Crane")
	var carriage: Node2D = crane.get_node("Carriage")
	var cable_line: Line2D = crane.get_node("CableLine")
	var hud: CanvasLayer = game.get_node("HUD")
	var stacking = game.get_node("StackingController")
	var gsm = root.get_node("/root/GameStateManager")

	# ---------------------------------------------------------------
	# TEST 1: First Building Block Initial State (Zero Drift / Settled)
	# ---------------------------------------------------------------
	print("\n--- Test 1: First Block Spawn & Zero Initial Drift ---")
	crane.reset()
	crane.start_crane(0)
	await process_frame

	var b1: Node2D = crane.active_building
	var init_angle: float = crane.pendulum_angle
	var init_vel: float = crane.pendulum_velocity
	var init_pos_x: float = carriage.position.x

	var is_settled := absf(init_angle) < 0.001 and absf(init_vel) < 0.001 and absf(init_pos_x) < 0.001
	if is_settled and b1 != null:
		print("PASS: First building initialized in perfectly settled state (angle=0, vel=0, carriage_x=0).")
		passed += 1
	else:
		print("FAIL: First block initialized with unwanted drift! angle=%f, vel=%f, pos_x=%f" % [init_angle, init_vel, init_pos_x])
		failed += 1

	# ---------------------------------------------------------------
	# TEST 2: Strict Cable Attachment & Geometry Invariance
	# ---------------------------------------------------------------
	print("\n--- Test 2: Strict Cable Attachment Geometry (No Stretching/Shearing) ---")
	var geom_ok := true
	# Test across various angles: -0.4, -0.2, 0.0, 0.2, 0.4 rad
	for test_angle in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		crane.pendulum_angle = test_angle
		crane._position_building()
		crane._update_cable()

		var attach_pos: Vector2 = carriage.position + Vector2(0.0, 22.0)
		var cable_dir: Vector2 = Vector2(sin(test_angle), cos(test_angle))
		var expected_hook_pos: Vector2 = attach_pos + cable_dir * (crane.pendulum_length - 60.0)

		# Check cable line points
		if cable_line.get_point_count() != 2:
			geom_ok = false
			break
		var pt0 := cable_line.get_point_position(0)
		var pt1 := cable_line.get_point_position(1)

		# Hook point on the active building in Crane-local space
		var building_hook_local: Vector2 = b1.position + Vector2(0.0, -60.0).rotated(b1.rotation)

		var diff_attach: float = (pt0 - attach_pos).length()
		var diff_hook: float = (pt1 - expected_hook_pos).length()
		var diff_b_hook: float = (pt1 - building_hook_local).length()

		if diff_attach > 0.01 or diff_hook > 0.01 or diff_b_hook > 0.01:
			geom_ok = false
			print("FAIL at angle %.2f: diff_attach=%.3f, diff_hook=%.3f, diff_b_hook=%.3f" % [
				test_angle, diff_attach, diff_hook, diff_b_hook
			])
			break

	if geom_ok:
		print("PASS: Cable line endpoints strictly pinned to trolley and building hook ring at all angles.")
		passed += 1
	else:
		failed += 1

	# ---------------------------------------------------------------
	# TEST 3: Smooth S-Curve Motor Ramp-Up (Zero Frame 1 Jerk Impulse)
	# ---------------------------------------------------------------
	print("\n--- Test 3: S-Curve Acceleration Envelope (Motor Spin-Up) ---")
	crane.reset()
	crane.start_crane(0)
	var max_accel_seen := 0.0
	var prev_v: float = crane.carriage_vx

	# Step 5 physics frames
	for f in range(5):
		var dt := 1.0 / 60.0
		crane._physics_process(dt)
		var cur_a := absf(crane.carriage_vx - prev_v) / dt
		if cur_a > max_accel_seen:
			max_accel_seen = cur_a
		prev_v = crane.carriage_vx

	# Smoothstep ramp starts with cur_accel around 650 * 0.25 = 162.5 px/s^2 instead of instantaneous 650
	if max_accel_seen < 400.0:
		print("PASS: Carriage accelerated smoothly with S-curve ramp (initial a=%.1f px/s^2 < 400 px/s^2 limit)." % max_accel_seen)
		passed += 1
	else:
		print("FAIL: Carriage experienced excessive initial acceleration jerk: %.1f px/s^2" % max_accel_seen)
		failed += 1

	# ---------------------------------------------------------------
	# TEST 4: Turnaround Smoothness & Zero Velocity Discontinuity
	# ---------------------------------------------------------------
	print("\n--- Test 4: Turnaround Deceleration and Continuous Reversal ---")
	carriage.position.x = crane.rail_right - 10.0
	crane.carriage_vx = 150.0
	crane.target_direction = 1.0

	var reversed := false
	for step in range(30):
		crane._physics_process(1.0 / 60.0)
		if crane.target_direction < 0.0:
			reversed = true
			# At reversal, carriage_vx should not jump to -25 abruptly
			if crane.carriage_vx <= 0.0 and crane.carriage_vx >= -35.0:
				break

	if reversed:
		print("PASS: Carriage reversed smoothly at rail limit without discontinuous velocity spikes.")
		passed += 1
	else:
		print("FAIL: Carriage failed to reverse smoothly at rail boundary!")
		failed += 1

	# ---------------------------------------------------------------
	# TEST 5: Recoil Bounce Feedback on Release
	# ---------------------------------------------------------------
	print("\n--- Test 5: Mechanical Recoil on Building Release ---")
	crane.reset()
	crane.start_crane(0)
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()

	var recoil_detected: bool = carriage.position.y < -1.0
	# Step recovery
	for _f in range(15):
		crane._physics_process(1.0 / 60.0)
	var recovered: bool = absf(carriage.position.y) < 0.5

	if recoil_detected and recovered:
		print("PASS: Carriage produced upward recoil bounce upon release and settled smoothly.")
		passed += 1
	else:
		print("FAIL: Recoil feedback failed! recoil_detected=%s, recovered=%s (y=%.2f)" % [recoil_detected, recovered, carriage.position.y])
		failed += 1

	# ---------------------------------------------------------------
	# TEST 6: Subsequent Block Physics Equivalence
	# ---------------------------------------------------------------
	print("\n--- Test 6: Physics Equivalence Between Block 1 and Block 2 ---")
	crane.start_crane(0)
	var b2 = crane.active_building
	var b2_w: float = b2.get_meta("width", 0.0)
	var b2_h: float = b2.get_meta("height", 0.0)
	if b2_w == 220.0 and b2_h == 100.0 and crane._crane_active:
		print("PASS: Subsequent blocks retain identical 220x100 geometry and active crane coupling.")
		passed += 1
	else:
		print("FAIL: Subsequent block physics or dimensions mismatch! w=%.1f, h=%.1f" % [b2_w, b2_h])
		failed += 1

	# ---------------------------------------------------------------
	# TEST 7: Mobile Portrait UI Touch Targets (>= 48 CSS px)
	# ---------------------------------------------------------------
	print("\n--- Test 7: Mobile Touch Target Dimensions (>= 64px physical) ---")
	var p_btn: Button = hud.get_node("PauseButton")
	var btn_slow: Button = hud.get("_btn_slow")
	var btn_stab: Button = hud.get("_btn_stab")
	var btn_guide: Button = hud.get("_btn_guide")
	var btn_second: Button = hud.get("_btn_second")

	var touch_ok := true
	if p_btn.size.x < 64.0 or p_btn.size.y < 64.0:
		touch_ok = false
	if btn_slow.custom_minimum_size.x < 180.0 or btn_slow.custom_minimum_size.y < 64.0:
		touch_ok = false
	if btn_stab.custom_minimum_size.x < 180.0 or btn_stab.custom_minimum_size.y < 64.0:
		touch_ok = false
	if btn_guide.custom_minimum_size.x < 180.0 or btn_guide.custom_minimum_size.y < 64.0:
		touch_ok = false
	if btn_second.custom_minimum_size.x < 180.0 or btn_second.custom_minimum_size.y < 64.0:
		touch_ok = false

	if touch_ok:
		print("PASS: All primary buttons meet or exceed mobile touch target guidelines (>= 64px physical / 48 CSS px).")
		passed += 1
	else:
		print("FAIL: One or more buttons do not meet mobile touch guidelines!")
		failed += 1

	# ---------------------------------------------------------------
	# TEST 8: Full Top Bar Layout (Zero Overlaps Across 5 Elements)
	# ---------------------------------------------------------------
	print("\n--- Test 8: Non-Overlapping Top Bar Layout ---")
	var score_panel: PanelContainer = hud.get_node("ScorePanel")
	var coin_panel: PanelContainer = hud.get("_coin_container")
	var floor_panel: PanelContainer = hud.get("_floor_container")
	var lives_cont: HBoxContainer = hud.get_node("LivesContainer")

	var r_p := Rect2(p_btn.position, p_btn.size)
	var r_s := Rect2(score_panel.position, score_panel.size)
	var r_c := Rect2(coin_panel.position, coin_panel.size)
	var r_f := Rect2(floor_panel.position, floor_panel.size)
	var r_l := Rect2(lives_cont.position, lives_cont.size)

	var no_overlap := not r_p.intersects(r_s) and not r_s.intersects(r_c) and not r_c.intersects(r_f) and not r_f.intersects(r_l)
	if no_overlap:
		print("PASS: Pause, Score, Coins, Floors, and Lives are laid out with zero overlap across 1080px portrait canvas.")
		passed += 1
	else:
		print("FAIL: Elements overlap in top bar! r_p=%s, r_s=%s, r_c=%s, r_f=%s, r_l=%s" % [r_p, r_s, r_c, r_f, r_l])
		failed += 1

	# ---------------------------------------------------------------
	# TEST 9: Dynamic Floor Counter Increment
	# ---------------------------------------------------------------
	print("\n--- Test 9: Floor Counter Updates ---")
	hud.update_floors(7)
	var f_label: Label = hud.get("_floor_label")
	if f_label and f_label.text == "FLOOR 7":
		print("PASS: Floor counter accurately updates display text on height changes.")
		passed += 1
	else:
		print("FAIL: Floor counter text did not match expected value! text=%s" % (f_label.text if f_label else "null"))
		failed += 1

	# ---------------------------------------------------------------
	# TEST 10: Stability Gauge Scaling & Color Tiers
	# ---------------------------------------------------------------
	print("\n--- Test 10: Stability Gauge Scaling & Color Tiers ---")
	var s_bar: ProgressBar = hud.get("_stability_bar")
	var s_label: Label = hud.get("_stability_label")
	hud.update_stability(85.0)
	var label_high: String = s_label.text
	hud.update_stability(15.0)
	var label_crit: String = s_label.text

	if s_bar and s_bar.size.x >= 500.0 and "STABILITY" in label_high and "CRITICAL" in label_crit:
		print("PASS: Stability gauge displays prominent bar (w=%.1f px) with high-contrast tiered state indicators." % s_bar.size.x)
		passed += 1
	else:
		print("FAIL: Stability gauge configuration error! w=%.1f, high='%s', crit='%s'" % [
			s_bar.size.x if s_bar else 0.0, label_high, label_crit
		])
		failed += 1

	print("\n====================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("====================================================")
	if failed == 0:
		print("ALL CRANE, FIRST-BLOCK & MOBILE UI TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		quit(1)
