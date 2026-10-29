extends SceneTree

func _init() -> void:
	print("====================================================")
	print("Testing Tower Collapse and Instability Thresholds")
	print("====================================================")
	call_deferred("_run_collapse_tests")

func _run_collapse_tests() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game := game_scene.instantiate()
	root.add_child(game)

	for i in range(15):
		await process_frame

	var gc: Node2D = game
	var crane: Node2D = game.get_node("Crane")
	var stacking: Node = game.get_node("StackingController")
	var stability: Node = game.get_node("StabilityController")
	var gsm: Node = root.get_node_or_null("/root/GameStateManager")
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if sm:
		sm.set_powerup_count("second_chance", 0)

	# 1. Stack 4 floors
	for i in range(4):
		crane.start_crane(0)
		crane.carriage.position.x = 0.0
		crane.pendulum_angle = 0.0
		crane._position_building()
		gsm.transition_to(gsm.GameState.CRANE_MOVING)
		crane.release_building()
		for f in range(120):
			stacking._physics_process(1.0 / 60.0)
			if stacking.tower_height_count == i + 1:
				break

	print("Initial 4 floors stacked. Height = %d, Stability = %.1f" % [stacking.tower_height_count, stability.stability])
	assert(stacking.tower_height_count == 4, "Should have 4 floors")

	# 2. Force stability below critical threshold (< 20)
	stability.stability = 15.0
	stability.accumulated_instability = 0.85
	print("Forced tower into critical instability: Stability = %.1f, is_critically_unstable = %s" % [
		stability.stability, str(stability.is_critically_unstable())
	])
	assert(stability.is_critically_unstable(), "Tower should be critically unstable")

	# 3. Drop a misaligned building on this critically unstable tower
	var height_before: int = stacking.tower_height_count
	var lives_before: int = gc.lives

	crane.start_crane(0)
	crane.carriage.position.x = 65.0 # Noticeably misaligned
	crane.pendulum_angle = 0.0
	crane._position_building()
	gsm.transition_to(gsm.GameState.CRANE_MOVING)
	crane.release_building()

	for f in range(160):
		stacking._physics_process(1.0 / 60.0)

	var height_after: int = stacking.tower_height_count
	var lives_after: int = gc.lives
	print("After collapse: Height before=%d, after=%d | Lives before=%d, after=%d" % [
		height_before, height_after, lives_before, lives_after
	])

	if height_after < height_before and lives_after == lives_before - 1:
		print("SUCCESS: Critical instability triggered collapse of upper floor and deducted 1 life!")
		quit(0)
	else:
		print("FAILURE: Collapse did not trigger as expected!")
		quit(1)
