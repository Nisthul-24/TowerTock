extends SceneTree

## Comprehensive Verification Suite:
## 1. Second Chance Power-Up Flow & Drone Rescue Mechanics
## 2. Pause System (Top-Left Button, Menu, Audio Toggles, Freeze/Resume)
## 3. Top-Bar UI Non-Overlapping Layout Verification
## 4. Graphics & Architectural Facade Generation

var passed_count := 0
var failed_count := 0

func _init() -> void:
	print("\n====================================================")
	print("STARTING SECOND CHANCE, PAUSE & GRAPHICS SUITE")
	print("====================================================\n")
	call_deferred("_run_tests")

func _assert(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % test_name)
		if details != "":
			print("      %s" % details)
	else:
		failed_count += 1
		printerr("FAIL: %s" % test_name)
		if details != "":
			printerr("      %s" % details)

func _run_tests() -> void:
	# Instantiate game scene
	var game_scene = load("res://scenes/game.tscn").instantiate()
	root.add_child(game_scene)

	for _i in range(10):
		await process_frame

	var gc = game_scene
	var crane = gc.get_node("Crane")
	var stacking = gc.get_node("StackingController")
	var hud = gc.get_node("HUD")
	var pause_menu = gc.get_node("PauseMenu")
	var gsm = root.get_node("/root/GameStateManager")
	var sm = root.get_node("/root/SaveManager")
	var scoring = root.get_node("/root/ScoringSystem")

	# ---------------------------------------------------------------
	# TEST 1: Top-Bar UI Layout & Zero Overlaps
	# ---------------------------------------------------------------
	print("\n--- Test 1: Top-Bar UI Layout & Zero Overlaps ---")
	var pause_btn: Button = hud.get_node("PauseButton")
	var score_panel: PanelContainer = hud.get_node("ScorePanel")
	var lives_cont: HBoxContainer = hud.get_node("LivesContainer")
	var coin_cont: PanelContainer = hud.get("_coin_container") as PanelContainer

	var p_rect := Rect2(pause_btn.position, pause_btn.size)
	var s_rect := Rect2(score_panel.position, score_panel.size)
	var c_rect := Rect2(coin_cont.position, coin_cont.size)

	var p_at_top_left: bool = pause_btn.position.x <= 25.0 and pause_btn.position.y <= 25.0
	var p_size_ok: bool = pause_btn.size.x >= 64.0 and pause_btn.size.y >= 64.0
	var no_p_s_overlap: bool = not p_rect.intersects(s_rect)
	var no_s_c_overlap: bool = not s_rect.intersects(c_rect)

	_assert(p_at_top_left and p_size_ok, "Pause button is at top-left with >=64x64 touch target",
		"Pos: %s, Size: %s" % [pause_btn.position, pause_btn.size])
	_assert(no_p_s_overlap and no_s_c_overlap, "Top bar elements have zero overlap",
		"Pause right: %f < Score left: %f; Score right: %f < Coin left: %f" % [
			p_rect.end.x, s_rect.position.x, s_rect.end.x, c_rect.position.x
		])

	# ---------------------------------------------------------------
	# TEST 2: Pause and Resume Lifecycle
	# ---------------------------------------------------------------
	print("\n--- Test 2: Pause and Resume Lifecycle ---")
	gc.start_new_run()
	for _i in range(5): await process_frame

	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	_assert(gsm.is_gameplay_active(), "Gameplay is active before pause")

	# Trigger pause via HUD button
	hud._on_pause_button_pressed()
	for _i in range(5): await process_frame

	var is_paused: bool = paused
	var gsm_paused: bool = gsm.is_in_state(gsm.GameState.PAUSED)
	var menu_visible: bool = pause_menu.visible

	_assert(is_paused and gsm_paused and menu_visible, "Pause button pauses game tree, transitions state, and shows menu",
		"Tree paused: %s, State: %s, Menu visible: %s" % [is_paused, gsm.current_state, menu_visible])

	# Test resume
	pause_menu._on_resume_button_pressed()
	for _i in range(5): await process_frame

	var is_unpaused: bool = not paused
	var menu_hidden: bool = not pause_menu.visible
	var gsm_resumed: bool = gsm.is_in_state(gsm.GameState.CRANE_MOVING)

	_assert(is_unpaused and menu_hidden and gsm_resumed, "Resume button unpauses tree, hides menu, and restores gameplay state",
		"Tree paused: %s, Menu visible: %s, State: %s" % [paused, pause_menu.visible, gsm.current_state])

	# ---------------------------------------------------------------
	# TEST 3: Sound Toggles in Pause Menu
	# ---------------------------------------------------------------
	print("\n--- Test 3: Sound Toggles in Pause Menu ---")
	var initial_music: bool = sm.get_music_enabled()
	var initial_sfx: bool = sm.get_sfx_enabled()

	pause_menu._on_music_toggle_pressed()
	var music_toggled: bool = (sm.get_music_enabled() == not initial_music)
	pause_menu._on_music_toggle_pressed() # Restore
	var music_restored: bool = (sm.get_music_enabled() == initial_music)

	pause_menu._on_sfx_toggle_pressed()
	var sfx_toggled: bool = (sm.get_sfx_enabled() == not initial_sfx)
	pause_menu._on_sfx_toggle_pressed() # Restore
	var sfx_restored: bool = (sm.get_sfx_enabled() == initial_sfx)

	_assert(music_toggled and music_restored and sfx_toggled and sfx_restored,
		"Pause menu sound toggles correctly invert and persist audio settings",
		"Music: %s -> %s -> %s, SFX: %s -> %s -> %s" % [initial_music, not initial_music, initial_music, initial_sfx, not initial_sfx, initial_sfx])

	# ---------------------------------------------------------------
	# TEST 4: Second Chance Activation & Inventory Deduction
	# ---------------------------------------------------------------
	print("\n--- Test 4: Second Chance Activation & Inventory Deduction ---")
	sm.set_powerup_count("second_chance", 2)
	hud.refresh_powerups_ui()

	_assert(sm.get_powerup_count("second_chance") == 2, "Second chance inventory initialized to 2")

	# Arm Second Chance via HUD button
	hud._btn_second.pressed.emit()
	for _i in range(5): await process_frame

	var inventory_after_arm: int = sm.get_powerup_count("second_chance")
	var is_armed: bool = stacking.second_chance_active

	_assert(inventory_after_arm == 1 and is_armed, "Arming Second Chance consumes exactly 1 charge and arms controller",
		"Inventory remaining: %d (expected 1), Armed: %s" % [inventory_after_arm, is_armed])

	# ---------------------------------------------------------------
	# TEST 5: Second Chance Rescue on Complete Abyss Miss
	# ---------------------------------------------------------------
	print("\n--- Test 5: Second Chance Rescue on Complete Abyss Miss ---")
	gc.start_new_run()
	for _i in range(5): await process_frame

	var initial_lives: int = gc.lives
	var initial_combo: int = scoring.current_combo
	var initial_coins: int = sm.get_coins()

	# Arm Second Chance
	stacking.second_chance_active = true

	# Spawn a falling building far off horizontally to simulate missing into the abyss
	var dummy_miss = Node2D.new()
	dummy_miss.position = Vector2(540.0 + 300.0, 1550.0) # Misses platform width completely
	root.add_child(dummy_miss)

	stacking.receive_falling_building(dummy_miss, Vector2.ZERO, 0.0)
	gsm.transition_to(gsm.GameState.BUILDING_FALLING)

	var test_state_5 := {"triggered": false, "rescued": false}
	var on_triggered_5 = func(): test_state_5["triggered"] = true
	var on_rescued_5 = func(): test_state_5["rescued"] = true
	stacking.second_chance_triggered.connect(on_triggered_5)
	stacking.second_chance_rescued.connect(on_rescued_5)

	# Simulate physics until past platform + 180 (triggers rescue)
	for _f in range(40):
		stacking._physics_process(1.0 / 60.0)
		await process_frame

	# Wait for rescue tween timer
	await create_timer(0.8).timeout

	var lives_preserved: bool = (gc.lives == initial_lives)
	var combo_preserved: bool = (scoring.current_combo == initial_combo)
	var coins_preserved: bool = (sm.get_coins() == initial_coins)
	var armed_cleared: bool = (not stacking.second_chance_active)

	_assert(test_state_5["triggered"] and test_state_5["rescued"] and lives_preserved and combo_preserved and coins_preserved and armed_cleared,
		"Second Chance rescues abyss miss: 0 lives lost, 0 fake points/coins, combo preserved",
		"Triggered: %s, Rescued: %s, Lives: %d/%d, Combo: %d, Armed: %s" % [
			test_state_5["triggered"], test_state_5["rescued"], gc.lives, initial_lives, scoring.current_combo, stacking.second_chance_active
		])

	if stacking.second_chance_triggered.is_connected(on_triggered_5):
		stacking.second_chance_triggered.disconnect(on_triggered_5)
	if stacking.second_chance_rescued.is_connected(on_rescued_5):
		stacking.second_chance_rescued.disconnect(on_rescued_5)

	# ---------------------------------------------------------------
	# TEST 6: Second Chance Rescue on Extreme Overhang Tumble (>98px)
	# ---------------------------------------------------------------
	print("\n--- Test 6: Second Chance Rescue on Extreme Overhang Tumble ---")
	gc.start_new_run()
	for _i in range(5): await process_frame

	initial_lives = gc.lives
	sm.set_powerup_count("second_chance", 1)
	stacking.second_chance_active = false
	stacking.second_chance_used_this_run = false

	# Floor placed with 105px overhang (half-width 110, overhang > 98px would tumble)
	var dummy_tumble = Node2D.new()
	dummy_tumble.position = Vector2(540.0 + 105.0, 1550.0)
	root.add_child(dummy_tumble)

	stacking.receive_falling_building(dummy_tumble, Vector2.ZERO, 0.0)
	gsm.transition_to(gsm.GameState.BUILDING_FALLING)

	var test_state_6 := {"triggered": false, "rescued": false}
	var on_triggered_6 = func(): test_state_6["triggered"] = true
	var on_rescued_6 = func(): test_state_6["rescued"] = true
	stacking.second_chance_triggered.connect(on_triggered_6)
	stacking.second_chance_rescued.connect(on_rescued_6)

	# Step down until contact target
	for _f in range(30):
		stacking._physics_process(1.0 / 60.0)
		await process_frame

	# Wait for rescue tween timer
	await create_timer(0.8).timeout

	var charge_consumed: bool = (sm.get_powerup_count("second_chance") == 0)
	lives_preserved = (gc.lives == initial_lives)

	_assert(test_state_6["triggered"] and test_state_6["rescued"] and charge_consumed and lives_preserved,
		"Second Chance automatically rescues extreme tumble, consumes exactly 1 inventory charge, preserves lives",
		"Triggered: %s, Rescued: %s, Remaining inventory: %d (expected 0), Lives: %d/%d" % [
			test_state_6["triggered"], test_state_6["rescued"], sm.get_powerup_count("second_chance"), gc.lives, initial_lives
		])

	if stacking.second_chance_triggered.is_connected(on_triggered_6):
		stacking.second_chance_triggered.disconnect(on_triggered_6)
	if stacking.second_chance_rescued.is_connected(on_rescued_6):
		stacking.second_chance_rescued.disconnect(on_rescued_6)

	# ---------------------------------------------------------------
	# TEST 7: Single Recovery Limit per Run Safeguard
	# ---------------------------------------------------------------
	print("\n--- Test 7: Single Recovery Limit Safeguard ---")
	# Now that second_chance_used_this_run is true, giving another inventory charge should NOT auto-rescue twice in same run
	sm.set_powerup_count("second_chance", 1)

	var dummy_miss2 = Node2D.new()
	dummy_miss2.position = Vector2(540.0 + 300.0, 1550.0)
	root.add_child(dummy_miss2)

	stacking.receive_falling_building(dummy_miss2, Vector2.ZERO, 0.0)
	gsm.transition_to(gsm.GameState.BUILDING_FALLING)

	for _f in range(40):
		stacking._physics_process(1.0 / 60.0)
		await process_frame

	var life_deducted: bool = (gc.lives == initial_lives - 1)
	_assert(life_deducted, "Without re-arming, second fatal failure correctly deducts 1 life",
		"Lives: %d (expected %d)" % [gc.lives, initial_lives - 1])

	# ---------------------------------------------------------------
	# TEST 8: Architectural Facades & Intact Floor Dimensions
	# ---------------------------------------------------------------
	print("\n--- Test 8: Architectural Facades & Intact Floor Dimensions ---")
	var building_facade = load("res://scripts/building_facade.gd")

	var styles_ok := true
	for s_idx in range(7):
		var floor_node: Node2D = building_facade.create_floor(s_idx)
		var f_w: float = floor_node.get_meta("width")
		var f_h: float = floor_node.get_meta("height")
		if f_w != 220.0 or f_h != 100.0 or floor_node.get_child_count() < 3:
			styles_ok = false
		floor_node.queue_free()

	var specials_ok := true
	for sp in [1, 2, 3]: # Golden, Reinforced, Heavy
		var floor_node: Node2D = building_facade.create_floor(0, sp)
		var f_w: float = floor_node.get_meta("width")
		var f_h: float = floor_node.get_meta("height")
		if f_w != 220.0 or f_h != 100.0:
			specials_ok = false
		floor_node.queue_free()

	_assert(styles_ok and specials_ok, "All 7 architectural styles and 3 specials maintain strict 220x100 intact dimensions",
		"Verified styles 0-6 and specials 1-3")

	# Clean up
	game_scene.queue_free()
	for _i in range(5): await process_frame

	print("\n====================================================")
	print("TEST SUITE RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("====================================================")
	if failed_count == 0:
		print("ALL SECOND CHANCE, PAUSE & GRAPHICS TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		push_error("SOME TESTS FAILED!")
		quit(1)
