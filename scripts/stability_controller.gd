extends Node

## StabilityController — Physically accurate structural stability & dynamic sway model.
## Separates placement accuracy, structural support, center-of-mass lean, dynamic sway,
## and physical failure thresholds.

signal stability_changed(new_stability: float)
signal instability_changed(new_instability: float)
signal tower_collapsed(floors_collapsed: int)

# ── Stability State (0.0 to 100.0) ────────────────────────────────
var stability: float = 100.0
var accumulated_instability: float = 0.0 # 0.0 (calm) to 1.0 (critical)
var accumulated_lean: float = 0.0        # Cumulative center-of-mass lean offset in px

# ── Dynamic Damped Harmonic Oscillator Sway ───────────────────────
var sway_displacement: float = 0.0       # Current dynamic top sway deflection in px
var sway_velocity: float = 0.0           # Current sway velocity in px/s
var tower_height_count: int = 0
var is_collapsing: bool = false

# Damping ratio (0.22 = structural damping: gently oscillates and settles)
const DAMPING_RATIO: float = 0.22

# Reference to tower sections tracked by StackingController
var _tower_sections: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func reset() -> void:
	stability = 100.0
	accumulated_instability = 0.0
	accumulated_lean = 0.0
	sway_displacement = 0.0
	sway_velocity = 0.0
	tower_height_count = 0
	is_collapsing = false
	_tower_sections.clear()
	stability_changed.emit(stability)
	instability_changed.emit(0.0)

func set_tower_sections_ref(sections: Array[Dictionary]) -> void:
	_tower_sections = sections

## Register a floor placement and update physical stability, center-of-mass, and sway
func register_placement(align_error: float, tower_height: int) -> void:
	tower_height_count = tower_height
	var abs_err := absf(align_error)
	var err_dir := signf(align_error)

	# Building width is 220px (half-width 110px)
	# 1. PERFECT PLACEMENT (error <= 8.5px, overlap >= 96.1%):
	# Zero penalty! Small recovery if stability was degraded. Damps lean and sway.
	if abs_err <= 8.5:
		stability = minf(100.0, stability + 4.0)
		accumulated_lean *= 0.75
		sway_velocity *= 0.50
	# 2. GOOD PLACEMENT (8.5px < error <= 25.0px, overlap >= 88.6%):
	# Zero penalty! Sufficient support exists; tower remains structurally solid.
	# Imparts only a subtle, controlled sway impulse.
	elif abs_err <= 25.0:
		accumulated_lean += err_dir * 1.0
		# Sway impulse proportional to error and tower height lever arm
		var lever_mult := 1.0 + float(min(tower_height, 25)) * 0.04
		sway_velocity += err_dir * (abs_err * 0.4) * lever_mult
	# 3. MODERATE MISALIGNMENT (25.0px < error <= 55.0px, overlap >= 75%):
	# Proportional penalty based on misalignment severity.
	elif abs_err <= 55.0:
		var frac := (abs_err - 25.0) / 30.0
		var penalty := lerpf(4.0, 12.0, frac)
		stability = maxf(0.0, stability - penalty)
		accumulated_lean += err_dir * 4.0
		var lever_mult := 1.0 + float(min(tower_height, 25)) * 0.06
		sway_velocity += err_dir * (abs_err * 0.8) * lever_mult
	# 4. SEVERE MISALIGNMENT (55.0px < error <= 90.0px, overlap >= 59%):
	# Large penalty, pronounced lean and sway.
	elif abs_err <= 90.0:
		var frac := (abs_err - 55.0) / 35.0
		var penalty := lerpf(15.0, 30.0, frac)
		stability = maxf(0.0, stability - penalty)
		accumulated_lean += err_dir * 9.0
		var lever_mult := 1.0 + float(min(tower_height, 25)) * 0.08
		sway_velocity += err_dir * (abs_err * 1.3) * lever_mult
	# 5. VERY SEVERE / OVERHANG (error > 90.0px):
	# Handled as tumble/slip-off in StackingController, registers shockwave.
	else:
		stability = maxf(0.0, stability - 25.0)
		accumulated_lean += err_dir * 14.0
		sway_velocity += err_dir * 120.0

	# Clamp lean within readable visual limits (±100px)
	accumulated_lean = clampf(accumulated_lean, -100.0, 100.0)

	# Normalized instability for UI & feedback: 0.0 (calm) to 1.0 (critical)
	accumulated_instability = clampf((100.0 - stability) / 100.0, 0.0, 1.0)

	stability_changed.emit(stability)
	instability_changed.emit(accumulated_instability)

func register_collapse() -> void:
	# Heavy shockwave after a collapse
	stability = maxf(0.0, stability - 30.0)
	accumulated_instability = clampf((100.0 - stability) / 100.0, 0.0, 1.0)
	sway_velocity = randf_range(-150.0, 150.0)
	stability_changed.emit(stability)
	instability_changed.emit(accumulated_instability)

func restore_stability(amount: float) -> void:
	stability = minf(100.0, stability + amount)
	accumulated_lean *= 0.50
	sway_displacement *= 0.50
	sway_velocity = 0.0
	accumulated_instability = clampf((100.0 - stability) / 100.0, 0.0, 1.0)
	stability_changed.emit(stability)
	instability_changed.emit(accumulated_instability)

## Stability Assist power-up effect: directly damps sway and recovers stability
func apply_stability_assist() -> void:
	restore_stability(25.0)

## Check if the tower is in a critical failure state that triggers upper floor collapse
func is_critically_unstable() -> bool:
	return stability < 20.0 or absf(accumulated_lean) >= 90.0

func _physics_process(delta: float) -> void:
	if _tower_sections.is_empty():
		sway_displacement = 0.0
		sway_velocity = 0.0
		return

	# Natural frequency decreases with height (tall skyscrapers flex with slower period)
	var omega_n: float = maxf(1.3, 2.6 - float(tower_height_count) * 0.035)

	# Target resting displacement is the static center-of-mass lean
	var target_x: float = accumulated_lean

	# Second-order damped harmonic oscillator:
	# d^2x/dt^2 = -omega_n^2 * (x - target_x) - 2 * damping * omega_n * dx/dt
	var spring_force := -pow(omega_n, 2.0) * (sway_displacement - target_x)
	var damping_force := -2.0 * DAMPING_RATIO * omega_n * sway_velocity

	var sway_accel := spring_force + damping_force
	sway_velocity += sway_accel * delta
	sway_displacement += sway_velocity * delta

	# Apply flex curve along the tower height (beam deflection)
	var n_floors := _tower_sections.size()
	for i in range(n_floors):
		var section: Dictionary = _tower_sections[i]
		var node: Node2D = section.get("node")
		if not node or not is_instance_valid(node):
			continue

		# Normalized vertical position: 0 at base, 1 at highest floor
		var t := float(i + 1) / float(n_floors)
		var flex := pow(t, 1.4)

		var base_x: float = section.get("base_center_x", 540.0)
		var base_y: float = section.get("base_center_y", 800.0)

		# Top displacement scaled along the tower's height
		var dx := sway_displacement * flex

		# Natural tilt rotation proportional to deflection and lever arm
		var rot := (sway_displacement / 600.0) * t

		node.position.x = base_x + dx
		node.position.y = base_y
		node.rotation = rot

## Get current world horizontal deflection of the top floor
func get_top_sway_dx() -> float:
	if _tower_sections.is_empty():
		return 0.0
	return sway_displacement
