extends Node

## StackingController — Manages tower stacking, whole-floor preservation,
## realistic contact physics, multi-floor collapse dynamics, and Second Chance rescue.
## Floors are strictly preserved as complete 220px x 100px intact sections.

signal placement_resolved(quality: int, overlap_ratio: float, building: Node2D)
signal miss_resolved
signal tower_height_changed(new_height: int)
signal second_chance_triggered
signal second_chance_rescued

@export var platform_center_x: float = 540.0
@export var platform_width: float = 340.0
@export var platform_top_y: float = 1600.0   # World Y of the platform surface
@export var building_width: float = 220.0
@export var building_height: float = 100.0
@export var landing_tolerance: float = 18.0  # Vertical contact snap tolerance in pixels

# ── Tower state ───────────────────────────────────────────────────
# Each entry: { base_center_x: float, base_center_y: float, world_y: float, node: Node2D }
var tower_sections: Array[Dictionary] = []

var current_top_y: float = 1600.0
var current_top_center_x: float = 540.0
var tower_height_count: int = 0

# ── Falling building ──────────────────────────────────────────────
var falling_building: Node2D = null
var _falling_active := false
var _gravity: float = 1350.0
var _fall_velocity: float = 0.0
var _horizontal_velocity: float = 0.0
var _angular_velocity: float = 0.0

# ── Second Chance power-up active state ───────────────────────────
var second_chance_active: bool = false
var second_chance_used_this_run: bool = false

@onready var tower_root: Node2D = get_node_or_null("../TowerRoot")
@onready var stability: Node = get_node_or_null("../StabilityController")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_init_platform_bounds()
	if stability:
		stability.set_tower_sections_ref(tower_sections)

func _init_platform_bounds() -> void:
	current_top_y = platform_top_y
	current_top_center_x = platform_center_x

func reset() -> void:
	_falling_active = false
	_fall_velocity = 0.0
	_horizontal_velocity = 0.0
	_angular_velocity = 0.0
	second_chance_active = false
	second_chance_used_this_run = false

	if falling_building and is_instance_valid(falling_building):
		falling_building.queue_free()
	falling_building = null

	# Clean up all spawned tower sections
	for entry in tower_sections:
		var n: Node2D = entry.get("node")
		if n and is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()
	tower_sections.clear()

	if tower_root and is_instance_valid(tower_root):
		for child in tower_root.get_children():
			tower_root.remove_child(child)
			child.queue_free()

	tower_height_count = 0
	_init_platform_bounds()
	if stability:
		stability.reset()
		stability.set_tower_sections_ref(tower_sections)

	tower_height_changed.emit(0)

## Called by CraneController when a building is released
func receive_falling_building(building: Node2D, velocity: Variant = Vector2.ZERO, angular_vel: float = 0.0) -> void:
	falling_building = building
	_falling_active = true

	if velocity is Vector2:
		_horizontal_velocity = velocity.x
		_fall_velocity = maxf(velocity.y, 100.0)
	elif velocity is float or velocity is int:
		_horizontal_velocity = float(velocity)
		_fall_velocity = 150.0
	else:
		_horizontal_velocity = 0.0
		_fall_velocity = 150.0

	_angular_velocity = angular_vel

func _physics_process(delta: float) -> void:
	if not _falling_active or falling_building == null or not is_instance_valid(falling_building):
		return

	# Apply gravity and aerodynamic drag
	_fall_velocity += _gravity * delta
	falling_building.global_position.y += _fall_velocity * delta
	falling_building.global_position.x += _horizontal_velocity * delta

	# Projectile rotation with slight air resistance
	falling_building.rotation += _angular_velocity * delta
	_horizontal_velocity = lerpf(_horizontal_velocity, 0.0, delta * 3.0)
	_angular_velocity = lerpf(_angular_velocity, 0.0, delta * 4.0)

	# Dynamic top surface coordinate taking into account active sway
	var sup_sway_dx: float = stability.get_top_sway_dx() if stability else 0.0
	var current_support_center_x: float = current_top_center_x + sup_sway_dx

	var target_landing_y: float = current_top_y - building_height / 2.0
	var drop_center_x: float = falling_building.global_position.x
	var align_error: float = absf(drop_center_x - current_support_center_x)

	# Contact check with top of the tower/platform
	if falling_building.global_position.y >= target_landing_y - landing_tolerance:
		# If center of mass is within contact range (half-width 110px + tolerance 8px)
		if align_error <= 118.0:
			_resolve_landing(drop_center_x, current_support_center_x, align_error, sup_sway_dx)
			return

	# If missed completely horizontally and fallen past the tower surface into the abyss
	if falling_building.global_position.y >= platform_top_y + 180.0:
		if is_second_chance_available():
			_rescue_with_second_chance(falling_building)
		else:
			_resolve_miss()

func is_second_chance_available() -> bool:
	if second_chance_active:
		return true
	if not second_chance_used_this_run and SaveManager.get_powerup_count("second_chance") > 0:
		return true
	return false

func _consume_second_chance() -> void:
	if second_chance_active:
		second_chance_active = false
	elif not second_chance_used_this_run and SaveManager.get_powerup_count("second_chance") > 0:
		second_chance_used_this_run = true
		SaveManager.consume_powerup("second_chance")

func _rescue_with_second_chance(building: Node2D) -> void:
	_falling_active = false
	falling_building = null
	_consume_second_chance()

	GameStateManager.transition_to(GameStateManager.GameState.RESOLVING_PLACEMENT)
	second_chance_triggered.emit()

	AudioManager.play_sfx("revive")
	SettingsManager.vibrate(60)

	# Safety Drone & Tractor Beam Visual
	var crane_node: Node2D = get_node_or_null("../Crane")
	var carriage_x: float = crane_node.carriage.global_position.x if (crane_node and crane_node.carriage) else platform_center_x
	var crane_y: float = crane_node.global_position.y if crane_node else 120.0

	var beam := Line2D.new()
	beam.width = 6.0
	beam.default_color = Color(0.2, 0.9, 1.0, 0.85)
	beam.add_point(Vector2(carriage_x, crane_y + 40.0))
	beam.add_point(building.global_position)
	if get_parent():
		get_parent().add_child(beam)

	var drone := ColorRect.new()
	drone.size = Vector2(40, 18)
	drone.color = Color(0.15, 0.85, 1.0, 0.95)
	drone.position = Vector2(carriage_x - 20.0, crane_y + 25.0)
	if get_parent():
		get_parent().add_child(drone)

	var t := create_tween()
	var target_y := crane_y + 80.0
	t.parallel().tween_property(building, "global_position", Vector2(carriage_x, target_y), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(building, "rotation", 0.0, 0.55)
	t.parallel().tween_property(building, "modulate:a", 0.0, 0.55)
	t.parallel().tween_property(beam, "default_color:a", 0.0, 0.55)
	t.parallel().tween_property(drone, "modulate:a", 0.0, 0.55)

	t.chain().tween_callback(func():
		if is_instance_valid(beam):
			beam.queue_free()
		if is_instance_valid(drone):
			drone.queue_free()
		if is_instance_valid(building):
			building.queue_free()
		second_chance_rescued.emit()
	)

func _resolve_landing(drop_center_x: float, sup_center_x: float, align_error: float, sup_sway_dx: float) -> void:
	_falling_active = false
	GameStateManager.transition_to(GameStateManager.GameState.BUILDING_LANDING)

	var building := falling_building
	falling_building = null
	var dir := signf(drop_center_x - sup_center_x)
	if dir == 0.0:
		dir = 1.0

	# 1. Check Second Chance rescue if placement would tumble
	var critically_unstable: bool = (stability != null and stability.is_critically_unstable() and align_error > 45.0 and tower_sections.size() > 1)
	var would_tumble: bool = (align_error > 98.0) or critically_unstable

	if would_tumble:
		if is_second_chance_available():
			_rescue_with_second_chance(building)
			return

		if align_error > 98.0:
			_animate_tumble_off(building, dir)
			return

		# Critical instability collapse:
		if stability and stability.is_critically_unstable() and align_error > 45.0 and tower_sections.size() > 1:
			_trigger_structural_collapse(building, dir)
			return

	# 3. Successful placement: floor STAYS FULL ORIGINAL DIMENSIONS (220px x 100px)!
	AudioManager.play_sfx("building_land")
	GameStateManager.transition_to(GameStateManager.GameState.RESOLVING_PLACEMENT)

	var new_y := current_top_y - building_height
	# Base resting position relative to foundation rest spine
	var placed_base_x := drop_center_x - sup_sway_dx

	# Reparent to TowerRoot
	if tower_root and is_instance_valid(tower_root):
		if building.get_parent():
			building.get_parent().remove_child(building)
		tower_root.add_child(building)

	building.position = Vector2(drop_center_x, new_y + building_height / 2.0)
	building.rotation = 0.0

	# Record in tower sections
	tower_sections.append({
		"base_center_x": placed_base_x,
		"base_center_y": new_y + building_height / 2.0,
		"world_y": new_y,
		"node": building,
	})

	# Update tower state
	current_top_y = new_y
	current_top_center_x = placed_base_x
	tower_height_count += 1

	if stability:
		stability.set_tower_sections_ref(tower_sections)
		stability.register_placement(align_error, tower_height_count)

	tower_height_changed.emit(tower_height_count)

	# Evaluate placement quality and award points & coins
	var overlap_width := maxf(0.0, building_width - align_error)
	var overlap_ratio := overlap_width / building_width
	var quality := ScoringSystem.evaluate_placement(overlap_ratio, align_error, tower_height_count)
	placement_resolved.emit(quality, overlap_ratio, building)

	# Special Floor Rewards
	var sp_type: String = building.get_meta("special_type", "normal")
	if sp_type == "golden":
		ScoringSystem.apply_bonus_points(200)
		AudioManager.play_sfx("perfect")
	elif sp_type == "reinforced" and stability:
		stability.restore_stability(15.0)

	# Feedback: squash & stretch landing impact
	var squash_x := 1.08 if sp_type == "heavy" else 1.05
	var squash_y := 0.90 if sp_type == "heavy" else 0.93
	building.scale = Vector2(squash_x, squash_y)
	var squash_tween := building.create_tween()
	squash_tween.tween_property(building, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_spawn_landing_dust(Vector2(drop_center_x, new_y + building_height))

	if quality == ScoringSystem.PlacementQuality.PERFECT or sp_type == "golden":
		AudioManager.play_sfx("perfect")
		SettingsManager.vibrate(40)
		_flash_perfect(building)
	elif quality in [ScoringSystem.PlacementQuality.EXCELLENT, ScoringSystem.PlacementQuality.GOOD]:
		SettingsManager.vibrate(20)

func _spawn_landing_dust(contact_point: Vector2) -> void:
	if not tower_root or not is_instance_valid(tower_root):
		return
	for i in range(8):
		var dust := ColorRect.new()
		dust.size = Vector2(randf_range(4.0, 7.0), randf_range(3.0, 5.0))
		dust.color = Color(0.85, 0.88, 0.92, 0.65)
		var dir := -1.0 if i < 4 else 1.0
		var offset_x := dir * (building_width * 0.45 + randf_range(0.0, 20.0))
		dust.position = contact_point + Vector2(offset_x, randf_range(-4.0, 2.0))
		tower_root.add_child(dust)

		var t := dust.create_tween()
		t.parallel().tween_property(dust, "position", dust.position + Vector2(dir * randf_range(16.0, 36.0), randf_range(-14.0, 6.0)), 0.35)
		t.parallel().tween_property(dust, "modulate:a", 0.0, 0.35)
		t.tween_callback(dust.queue_free)

func _resolve_miss() -> void:
	_falling_active = false
	var building := falling_building
	falling_building = null
	if building and is_instance_valid(building):
		building.queue_free()

	GameStateManager.transition_to(GameStateManager.GameState.RESOLVING_PLACEMENT)
	ScoringSystem.register_miss()
	AudioManager.play_sfx("miss")
	SettingsManager.vibrate(100)
	miss_resolved.emit()

func _animate_tumble_off(building: Node2D, dir: float) -> void:
	GameStateManager.transition_to(GameStateManager.GameState.RESOLVING_PLACEMENT)

	if dir == 0.0:
		dir = 1.0

	# Animate the intact floor tilting, tumbling, and falling under gravity
	var t := create_tween()
	var tumble_target := building.global_position + Vector2(dir * randf_range(140.0, 220.0), 600.0)
	var tumble_rot := dir * randf_range(2.5, 4.5)

	t.parallel().tween_property(building, "global_position", tumble_target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(building, "rotation", tumble_rot, 0.8)
	t.tween_callback(building.queue_free)

	if stability:
		stability.register_collapse()

	ScoringSystem.register_miss()
	AudioManager.play_sfx("miss")
	SettingsManager.vibrate(100)
	miss_resolved.emit()

func _trigger_structural_collapse(building: Node2D, dir: float) -> void:
	# Tumble the falling building
	_animate_tumble_off(building, dir)

	# Multi-floor collapse: dislodge top floors realistically
	var floors_to_dislodge := mini(2, tower_sections.size())
	for k in range(floors_to_dislodge):
		_dislodge_top_floor(dir * (1.0 if k == 0 else -0.7))

func _dislodge_top_floor(dir: float) -> void:
	if tower_sections.is_empty():
		return

	var top_section: Dictionary = tower_sections.pop_back()
	var top_node: Node2D = top_section.get("node")
	tower_height_count -= 1

	if tower_sections.size() > 0:
		var new_top: Dictionary = tower_sections.back()
		current_top_y = new_top.get("world_y", platform_top_y)
		current_top_center_x = new_top.get("base_center_x", platform_center_x)
	else:
		_init_platform_bounds()

	tower_height_changed.emit(tower_height_count)

	if top_node and is_instance_valid(top_node):
		var t := top_node.create_tween()
		var target := top_node.global_position + Vector2(dir * randf_range(120.0, 180.0), 550.0)
		t.parallel().tween_property(top_node, "global_position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(top_node, "rotation", dir * randf_range(2.0, 3.5), 0.8)
		t.tween_callback(top_node.queue_free)

func _flash_perfect(building: Node2D) -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(building_width + 16, building_height + 12)
	flash.position = Vector2(-flash.size.x / 2.0, -flash.size.y / 2.0)
	flash.color = Color(1.0, 0.95, 0.60, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building.add_child(flash)

	var t := flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.35)
	t.tween_callback(flash.queue_free)

## Get world Y of current tower top
func get_tower_top_world_y() -> float:
	return current_top_y
