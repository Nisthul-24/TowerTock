extends Camera2D

## CameraController — Smooth vertical camera tracking for the growing tower.

@export var follow_speed: float = 4.0
@export var shake_decay: float = 6.0

var _initial_pos: Vector2 = Vector2(540, 960)
var _target_y: float = 960.0
var _shake_intensity: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_initial_pos = position
	_target_y = position.y

func _process(delta: float) -> void:
	# Smooth vertical follow
	position.y = lerpf(position.y, _target_y, delta * follow_speed)

	# Camera Shake
	if _shake_intensity > 0.0:
		_shake_intensity = lerpf(_shake_intensity, 0.0, shake_decay * delta)
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		offset = Vector2.ZERO

## Update target Y based on tower top world position
func update_target(tower_top_world_y: float) -> void:
	# Keep the tower top comfortably framed in the lower-middle half
	var desired := tower_top_world_y - 480.0
	_target_y = minf(_initial_pos.y, desired)

func shake(intensity: float = 7.0) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)

func reset_camera() -> void:
	_target_y = _initial_pos.y
	position = _initial_pos
	offset = Vector2.ZERO
	_shake_intensity = 0.0
