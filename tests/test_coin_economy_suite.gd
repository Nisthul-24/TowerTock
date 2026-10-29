extends SceneTree

## Comprehensive test suite for Part 8: Required Coin Economy & Shop Tests (1-12)

func _init() -> void:
	print("====================================================")
	print("STARTING PART 8: COIN ECONOMY & SHOP VERIFICATION SUITE")
	print("====================================================")
	call_deferred("_run_suite")

func _run_suite() -> void:
	var passed: int = 0
	var failed: int = 0

	var scoring: Node = root.get_node_or_null("/root/ScoringSystem")
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	var gsm: Node = root.get_node_or_null("/root/GameStateManager")

	# Reset save state to clean baseline
	sm.set_coins(500)
	sm._config.set_value("themes", "unlocked_themes", ["neon_city"])
	sm._save()
	var initial_coins: int = sm.get_coins()

	# ── TEST 1: Successfully place a floor and verify correct reward ──
	print("\n--- Coin Test 1: Successful Placement Base Reward ---")
	scoring.reset_for_new_run()
	scoring.begin_new_building()
	# Partial placement on floor 1 (overlap 70%, align_err 60px): base tier 1 reward = 2 coins, accuracy = 0
	var q1: int = scoring.evaluate_placement(0.70, 60.0, 1)
	var coins_t1: int = scoring.coins_earned_this_run
	print("Floor 1 partial placement: Quality=%d, Coins earned=%d (expected 2)" % [q1, coins_t1])
	if coins_t1 == 2:
		print("PASS: Floor placement awarded correct base tier reward (2 coins).")
		passed += 1
	else:
		print("FAIL: Expected 2 coins, got %d" % coins_t1)
		failed += 1

	# ── TEST 2: Perfect placement accuracy bonus ──
	print("\n--- Coin Test 2: Perfect Placement Accuracy Bonus ---")
	scoring.begin_new_building()
	# Perfect placement on floor 2 (overlap 98%, align_err 2px): base tier 1 = 2 coins + accuracy bonus = 3 coins -> total 5 coins
	var coins_before: int = scoring.coins_earned_this_run
	var q2: int = scoring.evaluate_placement(0.98, 2.0, 2)
	var coins_earned_t2: int = scoring.coins_earned_this_run - coins_before
	print("Floor 2 perfect placement: Quality=%d, Coins earned=%d (expected 5: base 2 + bonus 3)" % [q2, coins_earned_t2])
	if q2 == scoring.PlacementQuality.PERFECT and coins_earned_t2 == 5:
		print("PASS: Perfect placement granted full accuracy bonus (+3 coins).")
		passed += 1
	else:
		print("FAIL: Expected 5 coins, got %d" % coins_earned_t2)
		failed += 1

	# ── TEST 3: Reach higher floors and verify reward progression ──
	print("\n--- Coin Test 3: Higher-Floor Progression Rewards ---")
	var r_f3: int = scoring.get_floor_base_reward(3)   # Tier 1 (1-5): 2
	var r_f8: int = scoring.get_floor_base_reward(8)   # Tier 2 (6-10): 3
	var r_f15: int = scoring.get_floor_base_reward(15) # Tier 3 (11-20): 4
	var r_f25: int = scoring.get_floor_base_reward(25) # Tier 4 (21-35): 5
	var r_f40: int = scoring.get_floor_base_reward(40) # Tier 5 (36-50): 7
	var r_f60: int = scoring.get_floor_base_reward(60) # Tier 6 (51+): 10

	print("Base rewards: F3=%d, F8=%d, F15=%d, F25=%d, F40=%d, F60=%d" % [
		r_f3, r_f8, r_f15, r_f25, r_f40, r_f60
	])
	if r_f3 == 2 and r_f8 == 3 and r_f15 == 4 and r_f25 == 5 and r_f40 == 7 and r_f60 == 10:
		print("PASS: Progressive floor rewards scale up strictly according to difficulty tiers.")
		passed += 1
	else:
		print("FAIL: Floor reward progression incorrect!")
		failed += 1

	# ── TEST 4: Milestone bonus granted only once per run ──
	print("\n--- Coin Test 4: Milestone Reward Granted Once Per Run ---")
	scoring.reset_for_new_run()
	scoring.begin_new_building()
	# Hit Floor 5 milestone (bonus: +10 coins; base: 2 coins; accuracy GOOD: +1 coin = 13 total)
	scoring.evaluate_placement(0.80, 40.0, 5)
	var coins_m5: int = scoring.milestone_coins_this_run

	# Attempt to trigger Floor 5 milestone a second time in same run
	scoring.begin_new_building()
	scoring.evaluate_placement(0.80, 40.0, 5)
	var coins_m5_after: int = scoring.milestone_coins_this_run

	print("Milestone coins first claim: %d | Second attempt: %d (expected 10 both)" % [coins_m5, coins_m5_after])
	if coins_m5 == 10 and coins_m5_after == 10:
		print("PASS: Milestone bonus (+10 coins) granted strictly once in the run.")
		passed += 1
	else:
		print("FAIL: Milestone bonus duplicated!")
		failed += 1

	# ── TEST 5: Restart run prevents claiming prior run's rewards ──
	print("\n--- Coin Test 5: Run Restart Safeguards & Idempotency ---")
	var bal_before_reset: int = sm.get_coins()
	scoring.reset_for_new_run()
	var run_coins_after_reset: int = scoring.coins_earned_this_run
	var bal_after_reset: int = sm.get_coins()

	print("Run coins after reset: %d | Persistent balance: %d" % [run_coins_after_reset, bal_after_reset])
	if run_coins_after_reset == 0 and bal_after_reset == bal_before_reset:
		print("PASS: Restart cleanly reset run earnings without corrupting or duplicating persistent balance.")
		passed += 1
	else:
		print("FAIL: Restart corrupted rewards!")
		failed += 1

	# ── TEST 6: Purchase a theme with sufficient coins ──
	print("\n--- Coin Test 6: Theme Purchase With Sufficient Coins ---")
	sm.set_coins(500)
	# Sunset City costs 250 coins
	var buy_sunset_ok: bool = sm.buy_theme("sunset_city")
	var bal_post_sunset: int = sm.get_coins()
	var sunset_owned: bool = sm.is_theme_unlocked("sunset_city")

	print("Purchase success: %s | Balance: 500 -> %d (expected 250) | Owned: %s" % [
		str(buy_sunset_ok), bal_post_sunset, str(sunset_owned)
	])
	if buy_sunset_ok and bal_post_sunset == 250 and sunset_owned:
		print("PASS: Theme purchased successfully; deducted exactly 250 coins and marked permanently owned.")
		passed += 1
	else:
		print("FAIL: Theme purchase failed!")
		failed += 1

	# ── TEST 7: Attempt to purchase theme without enough coins ──
	print("\n--- Coin Test 7: Theme Purchase Rejection With Insufficient Coins ---")
	sm.set_coins(100) # Cyberpunk District costs 1,000 coins
	var buy_cyber_ok: bool = sm.buy_theme("cyberpunk_district")
	var bal_post_cyber: int = sm.get_coins()
	var cyber_owned: bool = sm.is_theme_unlocked("cyberpunk_district")

	print("Purchase rejected: %s | Balance untouched: %d (expected 100) | Owned: %s" % [
		str(not buy_cyber_ok), bal_post_cyber, str(cyber_owned)
	])
	if not buy_cyber_ok and bal_post_cyber == 100 and not cyber_owned:
		print("PASS: Purchase rejected cleanly; zero coins deducted and theme remained locked.")
		passed += 1
	else:
		print("FAIL: Unauthorized purchase allowed!")
		failed += 1

	# ── TEST 8: Owned theme cannot be charged for again ──
	print("\n--- Coin Test 8: Prevent Double Charging For Owned Theme ---")
	sm.set_coins(300)
	var bal_prior_recharge: int = sm.get_coins()
	# Sunset City is already owned from Test 6
	var buy_again_result: bool = sm.buy_theme("sunset_city")
	var bal_post_recharge: int = sm.get_coins()

	print("Re-buy result: %s | Balance untouched: %d -> %d" % [
		str(buy_again_result), bal_prior_recharge, bal_post_recharge
	])
	if buy_again_result and bal_post_recharge == bal_prior_recharge:
		print("PASS: Re-purchasing already-owned theme did not deduct any coins.")
		passed += 1
	else:
		print("FAIL: Re-purchased theme was charged again!")
		failed += 1

	# ── TEST 9: Purchase power-up and verify consumable inventory ──
	print("\n--- Coin Test 9: Power-Up Purchase & Inventory Tracking ---")
	sm.set_coins(300)
	var slow_prior: int = sm.get_powerup_count("slow_motion")
	# Slow motion costs 75 coins
	var buy_slow_ok: bool = sm.buy_powerup("slow_motion")
	var slow_post: int = sm.get_powerup_count("slow_motion")
	var bal_post_slow: int = sm.get_coins()

	print("Bought Slow Mo: %s | Inventory: %d -> %d | Balance: 300 -> %d (expected 225)" % [
		str(buy_slow_ok), slow_prior, slow_post, bal_post_slow
	])
	if buy_slow_ok and slow_post == slow_prior + 1 and bal_post_slow == 225:
		print("PASS: Power-up purchased and exactly 1 consumable charge added to inventory.")
		passed += 1
	else:
		print("FAIL: Power-up purchase failed!")
		failed += 1

	# ── TEST 10: Activate power-up and verify exactly 1 charge consumed ──
	print("\n--- Coin Test 10: Consume Exactly One Power-Up Charge ---")
	var count_before_use: int = sm.get_powerup_count("slow_motion")
	var consume_ok: bool = sm.consume_powerup("slow_motion")
	var count_after_use: int = sm.get_powerup_count("slow_motion")

	print("Consumption success: %s | Count: %d -> %d" % [
		str(consume_ok), count_before_use, count_after_use
	])
	if consume_ok and count_after_use == count_before_use - 1:
		print("PASS: Power-up activation cleanly deducted exactly 1 charge.")
		passed += 1
	else:
		print("FAIL: Power-up consumption failed!")
		failed += 1

	# ── TEST 11: Persistence across restart / disk reload ──
	print("\n--- Coin Test 11: Data Persistence Verification ---")
	sm.set_coins(850)
	sm.unlock_theme("rainy_city")
	sm.add_powerup("precision_guide", 3)

	var saved_coins: int = sm.get_coins()
	var saved_rainy: bool = sm.is_theme_unlocked("rainy_city")
	var saved_guide_count: int = sm.get_powerup_count("precision_guide")

	# Re-execute _load() from disk config
	sm._load()

	var loaded_coins: int = sm.get_coins()
	var loaded_rainy: bool = sm.is_theme_unlocked("rainy_city")
	var loaded_guide_count: int = sm.get_powerup_count("precision_guide")

	print("Coins: %d -> %d | Theme Rainy: %s -> %s | Guide count: %d -> %d" % [
		saved_coins, loaded_coins, str(saved_rainy), str(loaded_rainy), saved_guide_count, loaded_guide_count
	])
	if loaded_coins == saved_coins and loaded_rainy == saved_rainy and loaded_guide_count == saved_guide_count:
		print("PASS: Coin balance, theme ownership, and power-up inventory persisted 100% across disk reload.")
		passed += 1
	else:
		print("FAIL: Data persistence verification failed!")
		failed += 1

	# ── TEST 12: Game over reward settlement idempotency ──
	print("\n--- Coin Test 12: Game Over Settlement Idempotency ---")
	scoring.reset_for_new_run()
	scoring.begin_new_building()
	scoring.evaluate_placement(1.0, 0.0, 1) # 2 + 3 = 5 coins
	var run_reward_1: int = scoring.settle_run_coins()
	# Settle second time (e.g. reopening game over screen)
	var run_reward_2: int = scoring.settle_run_coins()

	print("First settlement: %d coins | Second settlement: %d coins" % [run_reward_1, run_reward_2])
	if run_reward_1 == 5 and run_reward_2 == 5 and scoring._run_settled:
		print("PASS: Run reward settlement is idempotent; no duplicate rewards can be granted.")
		passed += 1
	else:
		print("FAIL: Settlement duplicated!")
		failed += 1

	print("\n====================================================")
	print("COIN ECONOMY & SHOP RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("====================================================")
	if failed == 0:
		print("ALL 12 COIN ECONOMY & SHOP TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		quit(1)
