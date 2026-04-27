extends Node2D
class_name TraderWagon

const NPCLookInfoScript = preload("res://scripts/npc_look_info.gd")

var target_room = null
var order_items: Dictionary = {}
var scheduled_dropoff_time: float = -1.0
var debug_stop_x: float = 96.0
var debug_travel_y: float = 0.0
var debug_pause_duration: float = 0.5

const MOVE_SPEED := 55.0
const STOP_OFFSET_X := -18.0
const START_PADDING_X := 240.0
const EXIT_PADDING_X := 260.0
const DROP_SPACING_X := 14.0
const DROP_ANIMATION_DURATION := 0.2
const DROP_SETTLE_TIME := 0.5
const HORSE_BOB_SPEED := 11.0
const HORSE_BOB_AMOUNT := 2.1
const HORSE_SWAY_AMOUNT := 1.1
const HORSE_ROTATION_AMOUNT := 0.08
const HORSE_SQUASH_AMOUNT := 0.07
const RIDER_BOB_SPEED := 9.0
const RIDER_BOB_AMOUNT := 1.6
const RIDER_SWAY_AMOUNT := 0.9
const RIDER_ROTATION_AMOUNT := 0.12
const MOTION_BLEND_SPEED := 5.0

@onready var horse_sprite: Sprite2D = $Sprite2D_Horse
@onready var crate_front: Sprite2D = $CrateFront
@onready var crate_back: Sprite2D = $CrateBack
@onready var rider_sprite: Sprite2D = $TraderRider

var _horse_base_position := Vector2.ZERO
var _horse_base_scale := Vector2.ONE
var _horse_base_rotation := 0.0
var _rider_base_position := Vector2.ZERO
var _rider_base_scale := Vector2.ONE
var _rider_base_rotation := 0.0
var _rider_random_offset := 0.0
var _motion_amount := 0.0
var _is_moving := false

func _ready() -> void:
	_cache_base_transforms()
	_setup_rider_visuals()
	_refresh_crate_visuals()
	call_deferred("_run_delivery")

func _process(delta: float) -> void:
	_motion_amount = move_toward(_motion_amount, 1.0 if _is_moving else 0.0, delta * MOTION_BLEND_SPEED)
	_update_horse_motion(delta)
	_update_rider_motion(delta)

func _cache_base_transforms() -> void:
	if horse_sprite != null:
		_horse_base_position = horse_sprite.position
		_horse_base_scale = horse_sprite.scale
		_horse_base_rotation = horse_sprite.rotation

	if rider_sprite != null:
		_rider_base_position = rider_sprite.position
		_rider_base_scale = rider_sprite.scale
		_rider_base_rotation = rider_sprite.rotation

func _update_horse_motion(delta: float) -> void:
	if horse_sprite == null:
		return

	var time: float = Global.time_now * HORSE_BOB_SPEED + _rider_random_offset
	var trot: float = sin(time)
	var lift: float = absf(trot)
	var idle_bob: float = sin(Global.time_now * 2.0 + _rider_random_offset) * 0.15 * (1.0 - _motion_amount)

	var target_position: Vector2 = _horse_base_position + Vector2(
		sin(time * 0.5) * HORSE_SWAY_AMOUNT * _motion_amount,
		-lift * HORSE_BOB_AMOUNT * _motion_amount + idle_bob
	)
	var target_rotation: float = _horse_base_rotation + sin(time + 0.4) * HORSE_ROTATION_AMOUNT * _motion_amount
	var squash: float = lift * HORSE_SQUASH_AMOUNT * _motion_amount
	var target_scale: Vector2 = _horse_base_scale + Vector2(squash, -squash * 0.75)

	horse_sprite.position = horse_sprite.position.lerp(target_position, delta * 10.0)
	horse_sprite.rotation = lerp(horse_sprite.rotation, target_rotation, delta * 10.0)
	horse_sprite.scale = horse_sprite.scale.lerp(target_scale, delta * 10.0)

func _update_rider_motion(delta: float) -> void:
	if rider_sprite == null:
		return

	var time: float = Global.time_now * RIDER_BOB_SPEED + _rider_random_offset
	var bounce: float = sin(time)
	var jolt: float = absf(sin(time * 0.5 + 0.25))
	var idle_bob: float = sin(Global.time_now * 3.0 + _rider_random_offset) * 0.1 * (1.0 - _motion_amount)

	var target_position: Vector2 = _rider_base_position + Vector2(
		sin(time * 0.5) * RIDER_SWAY_AMOUNT * _motion_amount,
		-(jolt * RIDER_BOB_AMOUNT * _motion_amount) + bounce * 0.25 * _motion_amount + idle_bob
	)
	var target_rotation: float = _rider_base_rotation + sin(time * 0.5 + 0.9) * RIDER_ROTATION_AMOUNT * _motion_amount
	var lean: float = jolt * 0.04 * _motion_amount
	var target_scale: Vector2 = _rider_base_scale + Vector2(-lean * 0.35, lean)

	rider_sprite.position = rider_sprite.position.lerp(target_position, delta * 11.0)
	rider_sprite.rotation = lerp(rider_sprite.rotation, target_rotation, delta * 11.0)
	rider_sprite.scale = rider_sprite.scale.lerp(target_scale, delta * 11.0)

func _run_delivery() -> void:
	if order_items.is_empty():
		queue_free()
		return

	var has_target_room := is_instance_valid(target_room)
	var drop_position: Vector2 = target_room.get_drop_position() if has_target_room else Vector2(debug_stop_x, debug_travel_y)
	var start_x := minf(drop_position.x - START_PADDING_X, -320.0)
	var exit_x := maxf(drop_position.x + EXIT_PADDING_X, Global.LEAVE_POSITION.x)
	global_position = Vector2(start_x, drop_position.y)

	await _move_to_x(drop_position.x + STOP_OFFSET_X)
	if not has_target_room:
		await get_tree().create_timer(debug_pause_duration).timeout
		await _move_to_x(exit_x)
		queue_free()
		return

	if not is_instance_valid(target_room):
		queue_free()
		return

	await _wait_for_dropoff_window()
	await _drop_crates(drop_position)
	target_room.on_trader_arrival_complete()
	crate_front.hide()
	crate_back.hide()
	await get_tree().create_timer(DROP_SETTLE_TIME).timeout
	await _move_to_x(exit_x)
	queue_free()

func _move_to_x(target_x: float) -> void:
	_is_moving = true
	while is_instance_valid(self) and absf(global_position.x - target_x) > 1.0:
		global_position.x = move_toward(global_position.x, target_x, MOVE_SPEED * get_process_delta_time())
		await get_tree().process_frame
	_is_moving = false

func _wait_for_dropoff_window() -> void:
	if scheduled_dropoff_time < 0.0:
		return

	var seconds_until_drop_start := (scheduled_dropoff_time - DROP_ANIMATION_DURATION) - Global.time_now
	if seconds_until_drop_start > 0.0:
		await get_tree().create_timer(seconds_until_drop_start).timeout

func _drop_crates(drop_position: Vector2) -> void:
	if not is_instance_valid(target_room):
		return

	var item_types: Array[int] = []
	for item_type in order_items.keys():
		if int(order_items[item_type]) > 0:
			item_types.append(int(item_type))
	item_types.sort()

	var center_offset := (float(item_types.size()) - 1.0) * 0.5
	for i in range(item_types.size()):
		var item_type := item_types[i]
		var amount := int(order_items[item_type])
		var offset_x := (float(i) - center_offset) * DROP_SPACING_X
		var spawn_pos := _get_cargo_spawn_position(offset_x)
		var target_pos := drop_position + Vector2(offset_x, 0.0)
		var crate := Global.ItemSpawner.create(Enum.Items.CRATE, spawn_pos)
		crate.configure_trade_crate(item_type, amount, target_room)
		LooseItemHandler.register_loose_item_instance(crate)
		target_room.register_delivery_crate(crate)
		var tween := crate.create_tween()
		tween.tween_property(crate, "global_position", target_pos, DROP_ANIMATION_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(DROP_ANIMATION_DURATION).timeout

func _refresh_crate_visuals() -> void:
	var crate_count := 0
	for amount in order_items.values():
		if int(amount) > 0:
			crate_count += 1
	crate_front.visible = crate_count > 0
	crate_back.visible = crate_count > 1

func _setup_rider_visuals() -> void:
	if rider_sprite == null:
		return

	_rider_base_position = rider_sprite.position
	_rider_random_offset = randf() * TAU

	var mat := rider_sprite.material as ShaderMaterial
	if mat == null:
		return

	rider_sprite.material = mat.duplicate(true)
	mat = rider_sprite.material as ShaderMaterial

	var look_info = NPCLookInfoScript.new_random()
	mat.set_shader_parameter("base_hue_offset", look_info.color_offsets)
	mat.set_shader_parameter("sprite_index", Vector2(look_info.head_index.x, look_info.head_index.y))

func _get_cargo_spawn_position(offset_x: float) -> Vector2:
	var base := crate_front.global_position
	if crate_back.visible:
		base = crate_back.global_position.lerp(crate_front.global_position, 0.5)
	return base + Vector2(offset_x, 0.0)

static func estimate_dropoff_duration_for_room(room) -> float:
	if room == null or not is_instance_valid(room):
		return DROP_ANIMATION_DURATION

	return estimate_dropoff_duration_for_position(room.get_drop_position())

static func estimate_dropoff_duration_for_position(drop_position: Vector2) -> float:
	var start_x := minf(drop_position.x - START_PADDING_X, -320.0)
	var stop_x := drop_position.x + STOP_OFFSET_X
	var travel_duration := absf(stop_x - start_x) / MOVE_SPEED
	return travel_duration + DROP_ANIMATION_DURATION
