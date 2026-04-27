extends Node2D
class_name TraderWagon

const NPCLookInfoScript = preload("res://scripts/npc_look_info.gd")

var target_room = null
var order_items: Dictionary = {}

const MOVE_SPEED := 55.0
const STOP_OFFSET_X := -18.0
const START_PADDING_X := 240.0
const EXIT_PADDING_X := 260.0
const DROP_SPACING_X := 14.0
const DROP_ANIMATION_DURATION := 0.2
const DROP_SETTLE_TIME := 0.5
const RIDER_BOB_SPEED := 4.5
const RIDER_BOB_AMOUNT := 0.2

@onready var crate_front: Sprite2D = $CrateFront
@onready var crate_back: Sprite2D = $CrateBack
@onready var rider_sprite: Sprite2D = $TraderRider

var _rider_base_position := Vector2.ZERO
var _rider_random_offset := 0.0

func _ready() -> void:
	_setup_rider_visuals()
	_refresh_crate_visuals()
	call_deferred("_run_delivery")

func _process(_delta: float) -> void:
	if rider_sprite == null:
		return

	var bob := sin(Global.time_now * RIDER_BOB_SPEED + _rider_random_offset) * RIDER_BOB_AMOUNT
	rider_sprite.position = _rider_base_position + Vector2(0.0, bob)

func _run_delivery() -> void:
	if not is_instance_valid(target_room) or order_items.is_empty():
		queue_free()
		return

	var drop_position: Vector2 = target_room.get_drop_position()
	var start_x := minf(drop_position.x - START_PADDING_X, -320.0)
	var exit_x := maxf(drop_position.x + EXIT_PADDING_X, Global.LEAVE_POSITION.x)
	global_position = Vector2(start_x, drop_position.y)

	await _move_to_x(drop_position.x + STOP_OFFSET_X)
	if not is_instance_valid(target_room):
		queue_free()
		return

	await _drop_crates(drop_position)
	target_room.on_trader_arrival_complete()
	crate_front.hide()
	crate_back.hide()
	await get_tree().create_timer(DROP_SETTLE_TIME).timeout
	await _move_to_x(exit_x)
	queue_free()

func _move_to_x(target_x: float) -> void:
	while is_instance_valid(self) and absf(global_position.x - target_x) > 1.0:
		global_position.x = move_toward(global_position.x, target_x, MOVE_SPEED * get_process_delta_time())
		await get_tree().process_frame

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
