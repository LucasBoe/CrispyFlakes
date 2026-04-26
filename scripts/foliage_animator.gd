extends AnimationPlayer

# How fast the wind wave moves left -> right
@export var wave_speed: float = 1.0

# Distance between wave peaks
@export var wave_length: float = 200.0

# Trigger when sine reaches this value
@export_range(-1.0, 1.0) var trigger_threshold: float = 0.95

# Prevent spam triggering
@export var trigger_cooldown: float = 0.6

var _cooldown := 0.0
var _was_above := false


func _process(delta: float) -> void:
	_cooldown -= delta

	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return

	var x := parent_node.global_position.x
	var t := Time.get_ticks_msec() / 1000.0

	# Left -> right moving sine wave
	var wave = sin((x / wave_length) - (t * wave_speed))

	var is_above = wave >= trigger_threshold

	if is_above and not _was_above and _cooldown <= 0.0:
		play(&"sway")
		_cooldown = trigger_cooldown

	_was_above = is_above
