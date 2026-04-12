extends Sprite2D
class_name AnimationModule

const KnockedOutBehaviourScript = preload("res://scripts/npc/behaviours/knocked_out_behaviour.gd")

@export var direction : Vector2 = Vector2(0,0);
var x_orientation = -1;
var random_instance_offset = 0

const SQUASH_STRENGTH = 0.05
const IDLE_ANIMATION_SPEED = 3
const IDLE_PEAK_SHARPNESS = 4
const WALK_ANIMATION_SPEED = 15.0
const WALK_ROTATION_STRENGTH = .15
const FIGHT_ANIMATION_SPEED = 7.0
const FIGHT_MOVE_DISTANCE = 8.0
const FIGHT_ROTATION = 1.0
const BROOM_ANIMATION_SPEED = 12.0
const BROOM_ROTATION_STRENGTH = 0.7

const TEX_STAND = preload("res://assets/sprites/cowboy_raw_stand.png")
const TEX_FIGHT = preload("res://assets/sprites/cowboy_raw_fight.png")
const TEX_CARRY = preload("res://assets/sprites/cowboy_raw_carry.png")
const TEX_SIT   = preload("res://assets/sprites/cowboy_raw_sit.png")
const TEX_RIDE  = preload("res://assets/sprites/cowboy_raw_ride.png")

var npc
var is_sitting : bool = false
var is_riding : bool = false
var is_peeing : bool = false
var is_puking : bool = false
var is_sleeping : bool = false
var is_brooming : bool = false

const RIDE_BODY_OFFSET = Vector2(0, -8)  # NPC sits above horse

func _ready():
	material = material.duplicate(true)

	npc = get_parent() as NPC
	if npc:
		pass

	npc.Animator = self
	random_instance_offset = randf()

func set_sitting(value : bool):
	is_sitting = value

func set_riding(value : bool):
	is_riding = value

func set_sleeping(value : bool):
	is_sleeping = value

func _update_texture():
	if is_riding:
		texture = TEX_RIDE
	elif npc.Behaviour.behaviour_instance is FightBehaviour or npc.Behaviour.behaviour_instance is StopFightBehaviour:
		texture = TEX_FIGHT
	elif is_sleeping:
		texture = TEX_STAND
	elif is_sitting:
		texture = TEX_SIT
	elif npc.Item.current_item != null:
		texture = TEX_CARRY
	else:
		texture = TEX_STAND

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var time_in_seconds = Global.time_now + random_instance_offset

	_update_texture()

	var target = null

	if npc.Behaviour.behaviour_instance is FightBehaviour or npc.Behaviour.behaviour_instance is StopFightBehaviour:
		target = fight_tween(time_in_seconds)
	elif is_brooming:
		target = broom_tween(time_in_seconds)
	elif npc.Behaviour.behaviour_instance is KnockedOutBehaviourScript or is_sleeping:
		target = knocked_out_tween()
	elif is_peeing:
		target = pee_tween(time_in_seconds)
	elif is_puking:
		target = puke_tween(time_in_seconds)
	else:
		target = idle_tween(time_in_seconds)

	if direction.length() > 0:
		target = walk_tween(time_in_seconds)

	var lerp_speed = .2

	var base_pos = RIDE_BODY_OFFSET if is_riding else Vector2.ZERO
	position = lerp(position, base_pos + target.position, lerp_speed)
	rotation = lerp(rotation, target.rotation, lerp_speed)
	scale = lerp(scale, target.scale, lerp_speed)


func walk_tween(time_in_seconds):
	var drunk = 0.0

	if npc and npc is NPCGuest:
		drunk = npc.Needs.drunkenness.strength

	var t = time_in_seconds * WALK_ANIMATION_SPEED / (1.0 + drunk)
	var raw = pow(abs(sin(t)), .2) * sign(sin(t))

	var flat_direction = direction * Vector2(1, .2)

	if (direction.x):
		x_orientation = sign(direction.x)

	var dir_to_rotation = Vector2(1, flat_direction.y * 0.2).angle() * x_orientation
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
	
func fight_tween(time_in_seconds):
	var s = time_in_seconds * FIGHT_ANIMATION_SPEED + random_instance_offset
	var x = clamp( sin(s) * sin(s + 1), 0, 1)
	var scale = Vector2(1 if random_instance_offset < .5 else -1, 1)
	return TweenTargetData.new(Vector2(x * FIGHT_MOVE_DISTANCE, 0), pow(x, 2) * FIGHT_ROTATION, scale)

func broom_tween(time_in_seconds):
	var rot = sin(time_in_seconds * BROOM_ANIMATION_SPEED) * BROOM_ROTATION_STRENGTH
	return TweenTargetData.new(Vector2(0, 1), rot, Vector2(x_orientation, 1.0))

func pee_tween(time_in_seconds):
	# Lean sideways like a dog, with a small bob
	var bob = sin(time_in_seconds * 4.0) * 0.5
	return TweenTargetData.new(Vector2(0, bob), PI / 3.0 * x_orientation, Vector2(x_orientation, 1.0))

func puke_tween(time_in_seconds):
	# Hunch forward with a heaving bob
	var bob = abs(sin(time_in_seconds * 5.0)) * 2.0
	return TweenTargetData.new(Vector2(0, bob), PI / 4.0 * x_orientation, Vector2(x_orientation, 1.0))

func knocked_out_tween():
	var x = -1 if is_sleeping else x_orientation
	return TweenTargetData.new(Vector2(0, -4), PI / 2.0 * x, Vector2.ONE)

func set_z(z : Enum.ZLayer):
	z_index = z

class TweenTargetData:
	@export var position : Vector2
	@export var rotation : float
	@export var scale : Vector2

	func _init(p_position, p_rotation, p_scale):
		position = p_position
		rotation = p_rotation
		scale = p_scale
