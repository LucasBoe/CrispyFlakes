extends Sprite2D
class_name AnimationModule

@export var direction : Vector2 = Vector2(0,0);
var xOrientation = 1;
var randomInstanceOffset = 0

const SQUASH_STRENGTH = 0.05
const IDLE_ANIMATION_SPEED = 3
const IDLE_PEAK_SHARPNESS = 4
const WALK_ANIMATION_SPEED = 15.0
const WALK_ROTATION_STRENGTH = .15

func _ready():
	material = material.duplicate(true)
	
	var npc = get_parent() as NPC
	if npc:
		pass
		
	npc.Animator = self
	randomInstanceOffset = randf() * 1000.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	var timeInSeconds = (Time.get_ticks_msec() + randomInstanceOffset) / 1000.0
	var target = idle_tween(timeInSeconds)
	
	if direction.length() > 0:
		target = walk_tween(timeInSeconds)
		
	var lerp = .2
	
	position = lerp(position, target.Position, lerp)
	rotation = lerp(rotation, target.Rotation, lerp)
	scale = lerp(scale, target.Scale, lerp)

func walk_tween(timeInSeconds):
	var t = timeInSeconds * WALK_ANIMATION_SPEED
	var raw = pow(abs(sin(t)), .2) * sign(sin(t))
	
	direction = direction * Vector2(1,.2)
	
	if (direction.x):
		xOrientation = sign(direction.x)
		
	var dirToRotation = Vector2(1, direction.y * 0.2).angle() * xOrientation
	var rotationTarget = dirToRotation + raw * WALK_ROTATION_STRENGTH
		
	var rawS = pow(abs(sin(t)), .4) * sign(sin(t))
	var scaleBase = abs(rawS) * SQUASH_STRENGTH
	
	var x = (1 + scaleBase) * xOrientation
	var y = 1 + abs(scaleBase - SQUASH_STRENGTH)
	
	var pos = Vector2(0, 2 - abs(rawS) * 4)
		
	return TweenTargetData.new(pos ,rotationTarget ,Vector2(x, y))

func idle_tween(timeInSeconds):
	var scaleOffset = sin(timeInSeconds * IDLE_ANIMATION_SPEED)
	var scaleBase = pow(abs(scaleOffset), IDLE_PEAK_SHARPNESS) * SQUASH_STRENGTH
	var x = (1 + abs(scaleBase - SQUASH_STRENGTH)) * xOrientation
	var y = 1 + scaleBase
	return TweenTargetData.new(Vector2.ZERO, 0, Vector2(x, y))
	
class TweenTargetData:
	@export var Position : Vector2
	@export var Rotation : float
	@export var Scale : Vector2
	
	func _init(position, rotation, scale):
		Position = position
		Rotation = rotation
		Scale = scale
