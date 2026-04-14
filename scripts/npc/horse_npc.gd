extends Node2D
class_name HorseNPC

var owner_guest: NPCGuest = null
var tied_post: RoomHorsePost = null

const TEX_HORSE = preload("res://assets/sprites/horse.png")
const TIE_FEE = 5
const WANDER_SPEED = 12.0
const WANDER_RANGE_X = 80.0
const FREE_DIRT_INTERVAL_MIN = 10.0
const FREE_DIRT_INTERVAL_MAX = 22.0

const SQUASH_STRENGTH = 0.06
const IDLE_SPEED = 2.0
const IDLE_PEAK_SHARPNESS = 4
const WALK_SPEED = 10.0
const LERP_SPEED = 0.15

@onready var sprite: Sprite2D = $Sprite2D

var _home_x: float = 0.0
var _home_y: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _x_orientation: float = 1.0
var _is_moving: bool = false
var _random_offset: float = 0.0
var _dirt_timer: float = 0.0

func _ready():
	sprite.texture = TEX_HORSE
	_random_offset = randf()
	_reset_dirt_timer()

func _process(delta):
	if not visible or owner_guest == null:
		return

	# While mounted: follow guest position
	if is_instance_valid(owner_guest) and owner_guest.Animator.is_riding:
		global_position = owner_guest.global_position
		_x_orientation = owner_guest.Animator.x_orientation
		_is_moving = owner_guest.Navigation.is_moving
		_animate()
		return

	_is_moving = false

	# Tied to post: idle in place
	if tied_post != null:
		_animate()
		return

	# Free: wander
	_dirt_timer -= delta
	if _dirt_timer <= 0.0:
		DirtHandler.create_dirt_at(global_position)
		_reset_dirt_timer()

	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 2.0:
		_pick_wander_target()

	var dir = _wander_target - global_position
	if dir.length() > 1.0:
		global_position = global_position.move_toward(_wander_target, WANDER_SPEED * delta)
		_x_orientation = sign(dir.x)
		_is_moving = true

	_animate()

func _animate():
	var t = Global.time_now + _random_offset
	var target_pos: Vector2
	var target_scale: Vector2

	if _is_moving:
		var s = t * WALK_SPEED
		var raw = pow(abs(sin(s)), 0.3) * sign(sin(s))
		var bob = abs(raw) * SQUASH_STRENGTH
		target_pos = Vector2(0, 2.0 - abs(raw) * 3.0)
		target_scale = Vector2(_x_orientation * (1.0 + bob), 1.0 + abs(bob - SQUASH_STRENGTH))
	else:
		var s = sin(t * IDLE_SPEED)
		var base = pow(abs(s), IDLE_PEAK_SHARPNESS) * SQUASH_STRENGTH
		target_pos = Vector2(0, 2)
		target_scale = Vector2(_x_orientation * (1.0 + abs(base - SQUASH_STRENGTH)), 1.0 + base)

	sprite.position = lerp(sprite.position, target_pos, LERP_SPEED)
	sprite.scale = lerp(sprite.scale, target_scale, LERP_SPEED)

func _get_building_left_edge() -> float:
	var min_x = INF
	if not Building.floors.has(0):
		return 0.0
	for x in Building.floors[0]:
		var room = Building.floors[0][x]
		if room != null and room is not RoomEmpty:
			min_x = minf(min_x, x)
	if min_x == INF:
		return 0.0
	# left pixel edge of that room cell
	return min_x * 48.0 - 4.0

func _pick_wander_target():
	_wander_timer = randf_range(2.0, 5.0)
	var offset_x = randf_range(-WANDER_RANGE_X * 0.5, WANDER_RANGE_X * 0.5)
	var max_x = _get_building_left_edge()
	var candidate_x = minf(_home_x + offset_x, max_x)
	_wander_target = Vector2(candidate_x, _home_y)

func drop_at(pos: Vector2) -> void:
	global_position = pos
	_home_x = pos.x
	_home_y = pos.y
	_wander_target = pos
	_reset_dirt_timer()

func tie_to(post: RoomHorsePost) -> void:
	if not post.tie_horse(self):
		drop_at(global_position)
		return
	tied_post = post
	global_position = post.get_random_floor_position()
	_home_x = global_position.x
	_home_y = global_position.y

# Called when the post is deleted — horse stays and starts wandering freely.
func on_post_destroyed() -> void:
	tied_post = null
	_home_x = global_position.x
	_reset_dirt_timer()

# Guest walks here, pays fee if still tied, mounts up.
# Returns the fee paid (0 if post was gone).
func collect(_guest: NPCGuest) -> int:
	var fee = 0
	if is_instance_valid(tied_post):
		fee = TIE_FEE
		tied_post.untie_horse(self)
		tied_post = null
	return fee

func _reset_dirt_timer() -> void:
	_dirt_timer = randf_range(FREE_DIRT_INTERVAL_MIN, FREE_DIRT_INTERVAL_MAX)
