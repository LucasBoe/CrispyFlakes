extends Sprite2D
class_name AnimationModule

@export var direction : Vector2 = Vector2(0,0);
var x_orientation = 1;
var random_instance_offset = 0

const SQUASH_STRENGTH = 0.05
const IDLE_ANIMATION_SPEED = 3
const IDLE_PEAK_SHARPNESS = 4
const WALK_ANIMATION_SPEED = 15.0
const WALK_ROTATION_STRENGTH = .15

var npc

func _ready():
	material = material.duplicate(true)

	npc = get_parent() as NPC
	if npc:
		pass

	npc.Animator = self
	random_instance_offset = randf()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):


	var time_in_seconds = Global.time_now + random_instance_offset
	var target = idle_tween(time_in_seconds)

	if direction.length() > 0:
		target = walk_tween(time_in_seconds)

	var lerp = .2

	position = lerp(position, target.position, lerp)
	rotation = lerp(rotation, target.rotation, lerp)
	scale = lerp(scale, target.scale, lerp)

func walk_tween(time_in_seconds):

	var drunk = 0.0

	if npc and npc is NPCGuest:
		drunk = npc.Needs.drunkenness.strength

	var t = time_in_seconds * WALK_ANIMATION_SPEED / (1.0 + drunk)
	var raw = pow(abs(sin(t)), .2) * sign(sin(t))

	direction = direction * Vector2(1,.2)

	if (direction.x):
		x_orientation = sign(direction.x)

	var dir_to_rotation = Vector2(1, direction.y * 0.2).angle() * x_orientation
	var rotation_target = dir_to_rotation + raw * WALK_ROTATION_STRENGTH * lerp(1.0, (sin(t * .667) + 1.0) * 3.0, drunk)

	var rawS = pow(abs(sin(t)), .4) * sign(sin(t))
	var scale_base = abs(rawS) * SQUASH_STRENGTH

	var x = (1 + scale_base) * x_orientation
	var y = 1 + abs(scale_base - SQUASH_STRENGTH)

	var pos = Vector2(0, 2 - abs(rawS) * 4)

	return TweenTargetData.new(pos, rotation_target, Vector2(x, y))

func idle_tween(time_in_seconds):
	var scaleOffset = sin(time_in_seconds * IDLE_ANIMATION_SPEED)
	var scale_base = pow(abs(scaleOffset), IDLE_PEAK_SHARPNESS) * SQUASH_STRENGTH
	var x = (1 + abs(scale_base - SQUASH_STRENGTH)) * x_orientation
	var y = 1 + scale_base
	return TweenTargetData.new(Vector2.ZERO, 0, Vector2(x, y))

func set_z(z):
	z_index = z

class TweenTargetData:
	@export var position : Vector2
	@export var rotation : float
	@export var scale : Vector2

	func _init(p_position, p_rotation, p_scale):
		position = p_position
		rotation = p_rotation
		scale = p_scale
