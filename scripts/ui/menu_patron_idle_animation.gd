extends Sprite2D

# copied from AnimationModule.idle_tween(); that module needs a full NPC parent these menu sprites lack
const SQUASH_STRENGTH := 0.05
const IDLE_ANIMATION_SPEED := 3.0
const IDLE_PEAK_SHARPNESS := 4.0

var _authored_scale: Vector2
var _time_offset: float

func _ready() -> void:
	_authored_scale = scale
	_time_offset = randf()

func _process(_delta: float) -> void:
	# real time, so the menu keeps animating regardless of gameplay speed or pause
	var time_in_seconds := Time.get_ticks_msec() / 1000.0 + _time_offset
	var breath_wave := sin(time_in_seconds * IDLE_ANIMATION_SPEED)
	var squash_amount := pow(absf(breath_wave), IDLE_PEAK_SHARPNESS) * SQUASH_STRENGTH
	var facing := signf(_authored_scale.x) if _authored_scale.x != 0.0 else 1.0
	scale = Vector2(
		(1.0 + absf(squash_amount - SQUASH_STRENGTH)) * facing * absf(_authored_scale.x),
		(1.0 + squash_amount) * absf(_authored_scale.y)
	)
