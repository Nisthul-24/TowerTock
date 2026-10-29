extends Node2D

## GameController — Orchestrates the complete TowerTock gameplay loop.
## Attached to the game.tscn root node.

# ── Child node references ─────────────────────────────────────────
@onready var crane: Node2D = $Crane
@onready var stacking: Node = $StackingController
@onready var stability: Node = $StabilityController
@onready var game_camera: Camera2D = $GameCamera
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var game_over_ui: CanvasLayer = $GameOverScreen
@onready var theme_selector: CanvasLayer = $ThemeSelector

# ── Lives / run state ─────────────────────────────────────────────
const MAX_LIVES := 3
var lives: int = MAX_LIVES
var revive_used_this_run := false
var _run_active := false
var _slow_mo_timer: float = 0.0

# ── Difficulty ────────────────────────────────────────────────────
var difficulty_level := 0
var placements_this_run := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wire_signals()
	call_deferred("_begin_session")

func _process(delta: float) -> void:
	if _slow_mo_timer > 0.0:
		_slow_mo_timer -= delta
		if _slow_mo_timer <= 0.0:
			crane.speed_multiplier = 1.0

	if crane and crane.carriage and is_instance_valid(crane.carriage):
		hud.update_precision_guide_pos(crane.carriage.global_position.x, crane.global_position.y, stacking.get_tower_top_world_y())

func _begin_session() -> void:
	var current := GameStateManager.current_state
	if current != GameStateManager.GameState.MAIN_MENU and current != GameStateManager.GameState.READY:
		GameStateManager.transition_to(GameStateManager.GameState.READY)
	await get_tree().create_timer(0.05).timeout
	start_new_run()

func _wire_signals() -> void:
	if not GameStateManager.state_changed.is_connected(_on_state_changed):
		GameStateManager.state_changed.connect(_on_state_changed)
	if not ScoringSystem.placement_rated.is_connected(_on_placement_rated):
		ScoringSystem.placement_rated.connect(_on_placement_rated)

	if not crane.building_released.is_connected(_on_building_released):
		crane.building_released.connect(_on_building_released)

	if not stacking.placement_resolved.is_connected(_on_stacking_placement_resolved):
		stacking.placement_resolved.connect(_on_stacking_placement_resolved)
	if not stacking.miss_resolved.is_connected(_on_stacking_miss_resolved):
		stacking.miss_resolved.connect(_on_stacking_miss_resolved)
	if not stacking.tower_height_changed.is_connected(_on_tower_height_changed):
		stacking.tower_height_changed.connect(_on_tower_height_changed)
	if not stacking.second_chance_triggered.is_connected(_on_second_chance_triggered):
		stacking.second_chance_triggered.connect(_on_second_chance_triggered)
	if not stacking.second_chance_rescued.is_connected(_on_second_chance_rescued):
		stacking.second_chance_rescued.connect(_on_second_chance_rescued)

	if stability and not stability.stability_changed.is_connected(hud.update_stability):
		stability.stability_changed.connect(hud.update_stability)

	if not hud.powerup_slow_requested.is_connected(_on_powerup_slow):
		hud.powerup_slow_requested.connect(_on_powerup_slow)
	if not hud.powerup_stab_requested.is_connected(_on_powerup_stab):
		hud.powerup_stab_requested.connect(_on_powerup_stab)
	if not hud.powerup_guide_requested.is_connected(_on_powerup_guide):
		hud.powerup_guide_requested.connect(_on_powerup_guide)
	if not hud.powerup_second_chance_requested.is_connected(_on_powerup_second_chance):
		hud.powerup_second_chance_requested.connect(_on_powerup_second_chance)

	if not AdManager.reward_earned.is_connected(_on_ad_reward_earned):
		AdManager.reward_earned.connect(_on_ad_reward_earned)
	if not AdManager.ad_closed.is_connected(_on_ad_closed):
		AdManager.ad_closed.connect(_on_ad_closed)
	if not AdManager.ad_failed_to_show.is_connected(_on_ad_failed_to_show):
		AdManager.ad_failed_to_show.connect(_on_ad_failed_to_show)

	if not game_over_ui.revive_requested.is_connected(request_revive):
		game_over_ui.revive_requested.connect(request_revive)
	if not game_over_ui.restart_requested.is_connected(on_restart_pressed):
		game_over_ui.restart_requested.connect(on_restart_pressed)
	if not game_over_ui.main_menu_requested.is_connected(on_main_menu_pressed):
		game_over_ui.main_menu_requested.connect(on_main_menu_pressed)
	if not game_over_ui.theme_picker_requested.is_connected(_on_theme_picker_requested):
		game_over_ui.theme_picker_requested.connect(_on_theme_picker_requested)

	if not pause_menu.resume_pressed.is_connected(on_resume_pressed):
		pause_menu.resume_pressed.connect(on_resume_pressed)
	if not pause_menu.restart_pressed.is_connected(on_restart_pressed):
		pause_menu.restart_pressed.connect(on_restart_pressed)
	if not pause_menu.main_menu_pressed.is_connected(on_main_menu_pressed):
		pause_menu.main_menu_pressed.connect(on_main_menu_pressed)

	if not hud.pause_pressed.is_connected(on_pause_button_pressed):
		hud.pause_pressed.connect(on_pause_button_pressed)

# ── Power-Ups ─────────────────────────────────────────────────────

func _on_powerup_slow() -> void:
	AudioManager.play_sfx("button_click")
	_slow_mo_timer = 6.0
	crane.speed_multiplier = 0.5
	hud.show_notification("⏱️ SLOW MOTION ACTIVE (6s)")

func _on_powerup_stab() -> void:
	AudioManager.play_sfx("button_click")
	if stability:
		stability.apply_stability_assist()
	hud.show_notification("🛡️ STABILITY ASSIST (+25%)")

func _on_powerup_guide() -> void:
	AudioManager.play_sfx("button_click")
	hud.set_precision_guide_active(true)
	hud.show_notification("🎯 PRECISION GUIDE ENGAGED")

func _on_powerup_second_chance() -> void:
	AudioManager.play_sfx("button_click")
	stacking.second_chance_active = true
	hud.show_notification("🔄 SECOND CHANCE ARMED (Drone Standby)")

func _on_second_chance_triggered() -> void:
	AudioManager.play_sfx("revive")
	hud.show_notification("🛡️ SECOND CHANCE RESCUE! Drone Deploying!")
	game_camera.shake(4.0)

func _on_second_chance_rescued() -> void:
	hud.show_notification("🛡️ RESCUE COMPLETE! Free Re-drop!")
	_schedule_next_building()

func _on_theme_picker_requested() -> void:
	theme_selector.open()

# ── Input ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_building"):
		_handle_tap()
	elif event.is_action_pressed("ui_back"):
		_handle_back()

func _handle_tap() -> void:
	if GameStateManager.is_in_state(GameStateManager.GameState.CRANE_MOVING):
		crane.release_building()

func _handle_back() -> void:
	match GameStateManager.current_state:
		GameStateManager.GameState.CRANE_MOVING, \
		GameStateManager.GameState.BUILDING_FALLING:
			on_pause_button_pressed()
		GameStateManager.GameState.PAUSED:
			on_resume_pressed()
		GameStateManager.GameState.MAIN_MENU:
			get_tree().quit()

# ── Run lifecycle ─────────────────────────────────────────────────

func start_new_run() -> void:
	lives = MAX_LIVES
	revive_used_this_run = false
	difficulty_level = 0
	placements_this_run = 0
	_run_active = true

	ScoringSystem.reset_for_new_run()
	AdManager.begin_new_run()
	stacking.reset()
	crane.reset()
	game_camera.reset_camera()

	_slow_mo_timer = 0.0
	crane.speed_multiplier = 1.0
	hud.reset_powerups()
	hud.update_stability(100.0)
	hud.update_coins(SaveManager.get_coins())

	game_over_ui.hide()
	pause_menu.hide()
	get_tree().paused = false

	_update_hud()

	var current := GameStateManager.current_state
	if current != GameStateManager.GameState.READY and current != GameStateManager.GameState.MAIN_MENU:
		GameStateManager.transition_to(GameStateManager.GameState.READY)

	await get_tree().create_timer(0.15).timeout
	if _run_active:
		GameStateManager.transition_to(GameStateManager.GameState.CRANE_MOVING)

func _on_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		GameStateManager.GameState.CRANE_MOVING:
			ScoringSystem.begin_new_building()
			crane.start_crane(difficulty_level)
		GameStateManager.GameState.GAME_OVER:
			_handle_game_over()
		GameStateManager.GameState.GAME_OVER_FINAL:
			_show_final_game_over()
		GameStateManager.GameState.REVIVE_RECOVERY:
			_apply_revive()

# ── Building handoff ──────────────────────────────────────────────

func _on_building_released(building: Node2D, velocity: Variant = Vector2.ZERO, angular_vel: float = 0.0) -> void:
	stacking.receive_falling_building(building, velocity, angular_vel)

# ── Stacking callbacks ────────────────────────────────────────────

func _on_stacking_placement_resolved(quality: int, _overlap_ratio: float, building: Node2D) -> void:
	placements_this_run += 1
	_advance_difficulty()
	_update_hud()

	var popup_txt := ""
	var is_perfect := false
	match quality:
		ScoringSystem.PlacementQuality.PERFECT:
			popup_txt = "+100\nPERFECT!"
			is_perfect = true
			game_camera.shake(3.0)
		ScoringSystem.PlacementQuality.EXCELLENT:
			popup_txt = "+75\nEXCELLENT"
			game_camera.shake(2.0)
		ScoringSystem.PlacementQuality.GOOD:
			popup_txt = "+50\nGOOD"
			game_camera.shake(1.2)
		ScoringSystem.PlacementQuality.PARTIAL:
			popup_txt = "+20"
			game_camera.shake(0.8)

	if popup_txt != "" and building and is_instance_valid(building):
		hud.spawn_score_popup(popup_txt, building.global_position, is_perfect)

func _on_stacking_miss_resolved() -> void:
	placements_this_run += 1
	game_camera.shake(8.0)
	_update_hud()

func _on_tower_height_changed(height: int) -> void:
	var top_y: float = stacking.get_tower_top_world_y()
	game_camera.update_target(top_y)
	var target_crane_y := top_y - 800.0
	crane.set_crane_target_y(minf(crane.initial_y, target_crane_y))
	hud.update_floors(height)

# ── Placement routing ─────────────────────────────────────────────

func _on_placement_rated(quality: int, _points: int) -> void:
	_update_hud()
	match quality:
		ScoringSystem.PlacementQuality.MISS:
			_handle_miss()
		_:
			_schedule_next_building()

func _handle_miss() -> void:
	lives -= 1
	_update_hud()
	SettingsManager.vibrate(80)

	if lives <= 0:
		await get_tree().create_timer(0.6).timeout
		if _run_active:
			GameStateManager.transition_to(GameStateManager.GameState.GAME_OVER)
	else:
		_schedule_next_building()

func _schedule_next_building() -> void:
	if not _run_active:
		return
	await get_tree().create_timer(0.4).timeout
	if not _run_active:
		return
	GameStateManager.transition_to(GameStateManager.GameState.PREPARING_NEXT_BUILDING)
	await get_tree().create_timer(0.2).timeout
	if not _run_active:
		return
	GameStateManager.transition_to(GameStateManager.GameState.CRANE_MOVING)

func _advance_difficulty() -> void:
	var new_level := placements_this_run / 6
	if new_level != difficulty_level:
		difficulty_level = new_level

# ── Pause ─────────────────────────────────────────────────────────

func on_pause_button_pressed() -> void:
	if GameStateManager.is_gameplay_active():
		GameStateManager.transition_to(GameStateManager.GameState.PAUSED)
		get_tree().paused = true
		pause_menu.show()
		AudioManager.pause_all()

func on_resume_pressed() -> void:
	if GameStateManager.is_in_state(GameStateManager.GameState.PAUSED):
		get_tree().paused = false
		pause_menu.hide()
		AudioManager.resume_all()
		var resume_state := GameStateManager.get_state_before_pause()
		GameStateManager.transition_to(resume_state)

# ── Game Over ─────────────────────────────────────────────────────

func _handle_game_over() -> void:
	_run_active = false
	get_tree().paused = false
	AudioManager.play_sfx("game_over")
	var score: int = ScoringSystem.get_score()
	var hs: int = ScoringSystem.get_high_score()
	var height: int = stacking.tower_height_count
	var combo: int = ScoringSystem.get_combo()
	var can_revive := not revive_used_this_run and AdManager.is_rewarded_ad_available()

	ScoringSystem.settle_run_coins()
	var coin_breakdown := ScoringSystem.get_run_coin_breakdown()

	SaveManager.save_best_height(height)
	SaveManager.increment_stat("total_placed", placements_this_run)

	game_over_ui.show_game_over(score, hs, can_revive, height, combo, coin_breakdown)

func _show_final_game_over() -> void:
	_run_active = false
	var score: int = ScoringSystem.get_score()
	var hs: int = ScoringSystem.get_high_score()
	var height: int = stacking.tower_height_count
	var combo: int = ScoringSystem.get_combo()
	var coin_breakdown := ScoringSystem.get_run_coin_breakdown()
	game_over_ui.show_game_over(score, hs, false, height, combo, coin_breakdown)

func request_revive() -> void:
	if revive_used_this_run:
		return
	if not GameStateManager.is_in_state(GameStateManager.GameState.GAME_OVER):
		return
	if not AdManager.is_rewarded_ad_available():
		hud.show_notification("Ad not available right now.")
		return

	GameStateManager.transition_to(GameStateManager.GameState.REVIVE_AD_PENDING)
	await get_tree().create_timer(0.1).timeout
	GameStateManager.transition_to(GameStateManager.GameState.REVIVE_AD_SHOWING)
	AdManager.show_rewarded_ad(AdManager.get_current_run_id())

func _on_ad_reward_earned(_type: String, _amount: int) -> void:
	if not GameStateManager.is_in_state(GameStateManager.GameState.REVIVE_AD_SHOWING):
		return
	if revive_used_this_run:
		return
	revive_used_this_run = true
	GameStateManager.transition_to(GameStateManager.GameState.REVIVE_RECOVERY)

func _on_ad_closed() -> void:
	if GameStateManager.is_in_state(GameStateManager.GameState.REVIVE_AD_SHOWING):
		if not revive_used_this_run:
			GameStateManager.transition_to(GameStateManager.GameState.GAME_OVER_FINAL)

func _on_ad_failed_to_show(_err: int) -> void:
	if GameStateManager.is_in_state(GameStateManager.GameState.REVIVE_AD_SHOWING) or \
	   GameStateManager.is_in_state(GameStateManager.GameState.REVIVE_AD_PENDING):
		GameStateManager.transition_to(GameStateManager.GameState.GAME_OVER_FINAL)

func _apply_revive() -> void:
	lives = 1
	_run_active = true
	game_over_ui.hide()
	AudioManager.play_sfx("revive")
	_update_hud()
	await get_tree().create_timer(0.4).timeout
	if _run_active:
		GameStateManager.transition_to(GameStateManager.GameState.CRANE_MOVING)

# ── Restart / Menu ────────────────────────────────────────────────

func on_restart_pressed() -> void:
	get_tree().paused = false
	pause_menu.hide()
	game_over_ui.hide()
	start_new_run()

func on_main_menu_pressed() -> void:
	_run_active = false
	get_tree().paused = false
	GameStateManager.transition_to(GameStateManager.GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ── HUD ───────────────────────────────────────────────────────────

func _update_hud() -> void:
	hud.update_score(ScoringSystem.get_score())
	hud.update_floors(stacking.tower_height_count if stacking else 0)
	hud.update_combo(ScoringSystem.get_combo())
	hud.update_lives(lives)
	hud.update_coins(SaveManager.get_coins())
