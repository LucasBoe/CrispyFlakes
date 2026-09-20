extends "res://scripts/ui/menu_patron_idle_animation.gd"

class Pose:
	var offset: Vector2
	var rotation: float
	var scale: Vector2

	func _init(pose_offset: Vector2, pose_rotation: float, pose_scale: Vector2) -> void:
		offset = pose_offset
		rotation = pose_rotation
		scale = pose_scale

@export var point_a: Marker2D
@export var point_b: Marker2D
@export var move_speed := 10.0
@export var pause_seconds := 1.0

const WALK_ANIMATION_SPEED := 15.0
const WALK_ROTATION_STRENGTH := 0.15
const POSE_SMOOTHING := 0.2

var _point_a_position: Vector2
var _point_b_position: Vector2
var _heading_to_b := true
var _pause_timer := 0.0
var _path_position: Vector2
var _facing := 1.0

func _ready() -> void:
	super._ready()
	if point_a == null or point_b == null:
		return
	# markers may be children of this sprite, so their global position is only a fixed point before it first moves
	_point_a_position = point_a.global_position
	_point_b_position = point_b.global_position
	_path_position = _point_a_position
	global_position = _path_position

func _process(delta: float) -> void:
	if point_a == null or point_b == null:
		super._process(delta)
		return

	var is_walking := false
	if _pause_timer > 0.0:
		_pause_timer -= delta
	else:
		var destination := _point_b_position if _heading_to_b else _point_a_position
		var to_destination := destination - _path_position
		if to_destination.length() <= move_speed * delta:
			_path_position = destination
			_heading_to_b = not _heading_to_b
			_pause_timer = pause_seconds
		else:
			var direction := to_destination.normalized()
			_path_position += direction * move_speed * delta
			if not is_zero_approx(direction.x):
				_facing = signf(direction.x)
			is_walking = true

	var time_in_seconds := Time.get_ticks_msec() / 1000.0 + _time_offset
	var pose := _walk_pose(time_in_seconds) if is_walking else _idle_pose(time_in_seconds)

	# facing lives in the pose's scale.x sign, so flip_h would cancel it out
	var target_scale := Vector2(pose.scale.x * absf(_authored_scale.x), pose.scale.y * absf(_authored_scale.y))
	global_position = lerp(global_position, _path_position + pose.offset, POSE_SMOOTHING)
	rotation = lerp(rotation, pose.rotation, POSE_SMOOTHING)
	scale = lerp(scale, target_scale, POSE_SMOOTHING)

func _idle_pose(time_in_seconds: float) -> Pose:
	var breath_wave := sin(time_in_seconds * IDLE_ANIMATION_SPEED)
	var squash_amount := pow(absf(breath_wave), IDLE_PEAK_SHARPNESS) * SQUASH_STRENGTH
	var width := (1.0 + absf(squash_amount - SQUASH_STRENGTH)) * _facing
	return Pose.new(Vector2.ZERO, 0.0, Vector2(width, 1.0 + squash_amount))

# copied from AnimationModule.walk_tween() without its drunk/injured slowdown and turn angle
func _walk_pose(time_in_seconds: float) -> Pose:
	var step_phase := time_in_seconds * WALK_ANIMATION_SPEED
	var sway: float = pow(absf(sin(step_phase)), 0.2) * signf(sin(step_phase))
	var step_squash: float = pow(absf(sin(step_phase)), 0.4) * signf(sin(step_phase))
	var squash_amount := absf(step_squash) * SQUASH_STRENGTH
	var width := (1.0 + squash_amount) * _facing
	var height := 1.0 + absf(squash_amount - SQUASH_STRENGTH)
	var bob := Vector2(0.0, 2.0 - absf(step_squash) * 4.0)
	return Pose.new(bob, sway * WALK_ROTATION_STRENGTH * _facing, Vector2(width, height))
