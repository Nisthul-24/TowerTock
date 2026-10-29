extends Node2D

## CraneController — Physically accurate crane carriage, pendulum swinging, and clean release.
## Implements continuous carriage acceleration, smooth S-curve motor ramp-up,
## physically coupled pendulum swinging, braided steel cable tracking, and recoil feedback.

signal building_released(building: Node2D, velocity: Vector2, angular_velocity: float)
signal building_section_ready

const BuildingFacade = preload("res://scripts/building_facade.gd")

# ── References ────────────────────────────────────────────────────
@onready var carriage: Node2D = $Carriage
@onready var cable_line: Line2D = $CableLine
@onready var building_attachment: Marker2D = $Carriage/AttachmentPoint

# ── Crane rail limits (in local X coordinates) ────────────────────
@export var rail_left:  float = -360.0
@export var rail_right: float =  360.0

# ── Carriage Movement parameters ──────────────────────────────────
@export var base_speed: float = 230.0
var max_speed: float = base_speed
var carriage_vx: float = 0.0
var carriage_accel: float = 650.0 # px/s^2 smooth cruise acceleration
var target_direction: float = 1.0
var speed_multiplier: float = 1.0
var _motor_time: float = 0.0      # Motor spin-up elapsed time for smooth S-curve

# Turnaround deceleration zone (pixels from rail end where deceleration begins)
const TURN_ZONE: float = 75.0

# ── Pendulum parameters ────────────────────────────────────────────
@export var pendulum_length: float = 160.0  # pixels from trolley pivot to building center
var pendulum_angle: float = 0.0             # theta (rad)
var pendulum_velocity: float = 0.0          # omega (rad/s)
var gravity_accel: float = 980.0
const PENDULUM_DAMPING: float = 0.993       # Natural underdamped air resistance

# ── Active building ────────────────────────────────────────────────
var active_building: Node2D = null
var _building_released := false
var _crane_active := false

# Vertical tracking toward target Y (following tower growth)
var initial_y: float = 240.0
var target_y: float = 240.0
var _style_counter: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	initial_y = position.y
	target_y = initial_y
	_setup_crane_visual()

func _setup_crane_visual() -> void:
	if cable_line:
		cable_line.width = 3.5
		cable_line.default_color = Color(0.85, 0.88, 0.92, 0.95)
		cable_line.antialiased = true

func reset() -> void:
	_building_released = false
	_crane_active = false
	_motor_time = 0.0
	if active_building and is_instance_valid(active_building):
		active_building.queue_free()
	active_building = null
	pendulum_angle = 0.0
	pendulum_velocity = 0.0
	carriage_vx = 0.0
	target_direction = 1.0
	_style_counter = 0
	target_y = initial_y
	position.y = initial_y
	if carriage:
		carriage.position = Vector2.ZERO
	if cable_line:
		cable_line.clear_points()

func set_crane_target_y(new_target_y: float) -> void:
	target_y = new_target_y

func start_crane(difficulty_level: int) -> void:
	_building_released = false
	_crane_active = true
	_motor_time = 0.0

	# Controlled speed progression (230 px/s early -> up to 420 px/s late game)
	max_speed = minf(base_speed + float(difficulty_level) * 22.0, 420.0)

	_spawn_building()

func _spawn_building() -> void:
	if active_building and is_instance_valid(active_building):
		active_building.queue_free()
		active_building = null

	var special := BuildingFacade.SpecialType.NONE
	if _style_counter > 0 and _style_counter % 5 == 0:
		var sp_idx := (_style_counter / 5) % 3
		match sp_idx:
			1: special = BuildingFacade.SpecialType.GOLDEN
			2: special = BuildingFacade.SpecialType.REINFORCED
			0: special = BuildingFacade.SpecialType.HEAVY

	var building: Node2D = BuildingFacade.create_floor(_style_counter, special)
	_style_counter += 1
	add_child(building)
	active_building = building
	
	# Explicitly position building and cable immediately upon spawn before frame render
	_position_building()
	_update_cable()
	building_section_ready.emit()

func _physics_process(delta: float) -> void:
	# Vertical tracking toward target Y (following tower growth smoothly)
	position.y = lerpf(position.y, target_y, delta * 4.0)

	# Mechanical carriage recoil recovery
	if carriage:
		carriage.position.y = lerpf(carriage.position.y, 0.0, delta * 12.0)

	if not _crane_active or _building_released:
		return

	# Smooth motor S-curve acceleration ramp from standstill (prevents initial impulse jerk)
	_motor_time += delta
	var ramp_t := clampf(_motor_time / 0.35, 0.0, 1.0)
	var ramp_factor := ramp_t * ramp_t * (3.0 - 2.0 * ramp_t) # Smoothstep
	var cur_accel := carriage_accel * maxf(ramp_factor, 0.25)

	var prev_vx := carriage_vx
	_move_carriage(delta, cur_accel)
	var effective_carriage_accel := (carriage_vx - prev_vx) / maxf(delta, 0.0001)

	_update_pendulum(delta, effective_carriage_accel)
	_position_building()
	_update_cable()

func _move_carriage(delta: float, cur_accel: float) -> void:
	var desired_cruise_speed := max_speed * speed_multiplier

	# 1. Turnaround zones with smooth deceleration at rail boundaries
	if carriage.position.x >= (rail_right - TURN_ZONE) and target_direction > 0.0:
		var dist_to_edge := maxf(0.0, rail_right - carriage.position.x)
		var brake_ratio := dist_to_edge / TURN_ZONE
		var target_speed := desired_cruise_speed * sqrt(brake_ratio)
		carriage_vx = move_toward(carriage_vx, target_speed, cur_accel * 1.5 * delta)

		if carriage.position.x >= rail_right or carriage_vx <= 15.0:
			carriage.position.x = rail_right
			target_direction = -1.0
			carriage_vx = 0.0 # Clean zero-speed reversal, no unnatural impulse
	elif carriage.position.x <= (rail_left + TURN_ZONE) and target_direction < 0.0:
		var dist_to_edge := maxf(0.0, carriage.position.x - rail_left)
		var brake_ratio := dist_to_edge / TURN_ZONE
		var target_speed := -desired_cruise_speed * sqrt(brake_ratio)
		carriage_vx = move_toward(carriage_vx, target_speed, cur_accel * 1.5 * delta)

		if carriage.position.x <= rail_left or carriage_vx >= -15.0:
			carriage.position.x = rail_left
			target_direction = 1.0
			carriage_vx = 0.0
	else:
		# Standard cruise acceleration with motor ramp
		var target_vx := target_direction * desired_cruise_speed
		carriage_vx = move_toward(carriage_vx, target_vx, cur_accel * delta)

	carriage.position.x += carriage_vx * delta
	carriage.position.x = clampf(carriage.position.x, rail_left, rail_right)

func _update_pendulum(delta: float, a_carriage: float) -> void:
	# Physical pendulum equations driven by gravity and carriage acceleration:
	# alpha = - (g / L) * sin(theta) - (a_carriage / L) * cos(theta) - damping_force
	var torque_gravity := -(gravity_accel / pendulum_length) * sin(pendulum_angle)
	var torque_inertia := -(a_carriage / pendulum_length) * cos(pendulum_angle)

	var natural_freq := sqrt(gravity_accel / pendulum_length)
	var damping_force := -2.0 * 0.08 * natural_freq * pendulum_velocity

	var angular_accel := torque_gravity + torque_inertia + damping_force
	pendulum_velocity += angular_accel * delta
	pendulum_velocity *= pow(PENDULUM_DAMPING, delta * 60.0)
	pendulum_angle += pendulum_velocity * delta

	# Clamp angle to realistic readable swing range (±26 degrees = ±0.45 rad)
	pendulum_angle = clampf(pendulum_angle, -0.45, 0.45)

func _position_building() -> void:
	if active_building == null or not is_instance_valid(active_building):
		return
	# Strict crane-local coordinate positioning to eliminate transform lag
	var attach_pos := carriage.position + Vector2(0.0, 22.0)
	var cable_dir := Vector2(sin(pendulum_angle), cos(pendulum_angle))
	active_building.position = attach_pos + cable_dir * pendulum_length
	active_building.rotation = -pendulum_angle

func _update_cable() -> void:
	if active_building == null or cable_line == null or not is_instance_valid(active_building):
		return
	var attach_pos := carriage.position + Vector2(0.0, 22.0)
	var cable_dir := Vector2(sin(pendulum_angle), cos(pendulum_angle))
	# Cable connects directly from trolley fairlead to the top hoist hook ring (h = 60px above center)
	var hook_pos := attach_pos + cable_dir * (pendulum_length - 60.0)

	cable_line.clear_points()
	cable_line.add_point(attach_pos)
	cable_line.add_point(hook_pos)

## Called when player taps to release building
func release_building() -> void:
	if _building_released or active_building == null or not is_instance_valid(active_building):
		return
	if not GameStateManager.is_in_state(GameStateManager.GameState.CRANE_MOVING):
		return

	_building_released = true
	_crane_active = false
	GameStateManager.transition_to(GameStateManager.GameState.BUILDING_RELEASED)

	# Calculate true tangential and linear release velocity
	# Center of mass is distance L along cable direction
	var tangential_speed := pendulum_velocity * pendulum_length
	var release_vx := carriage_vx + tangential_speed * cos(pendulum_angle)
	var release_vy := -tangential_speed * sin(pendulum_angle)
	var release_omega := -pendulum_velocity

	# Detach building cleanly from crane hierarchy — reparent to Game root
	var world_pos := active_building.global_position
	var world_rot := active_building.rotation
	remove_child(active_building)
	get_parent().add_child(active_building)
	active_building.global_position = world_pos
	active_building.rotation = world_rot

	# Upward mechanical recoil feedback on carriage
	if carriage:
		carriage.position.y = -3.5

	cable_line.clear_points()

	AudioManager.play_sfx("building_release")
	var released := active_building
	active_building = null
	building_released.emit(released, Vector2(release_vx, release_vy), release_omega)

	GameStateManager.transition_to(GameStateManager.GameState.BUILDING_FALLING)
