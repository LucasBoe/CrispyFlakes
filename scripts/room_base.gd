extends Node2D
class_name RoomBase

var x
var y
var is_basement
var data : RoomData
var associated_job = null
var is_outside_room = false
var worker : NPCWorker = null
var current_module = null
var _outline_sources: Dictionary = {}

@onready var back_wall_sprite_2d = get_node_or_null("Back-wall")

const backwallDefault = preload("res://assets/sprites/back-wall.png");
const backwallBasement = preload("res://assets/sprites/back-wall_basement.png");
const ROOM_MONEY_SPRITESHEET = preload("res://assets/sprites/room_money_spritesheet.png")
const ROOM_MONEY_HFRAMES := 16
const ROOM_MONEY_MAX_VISUAL_AMOUNT := 500.0
const ROOM_MONEY_Z_INDEX := -5
const ROOM_MONEY_BUMP_SCALE := Vector2(1.12, 1.12)
const ROOM_MONEY_BUMP_DURATION_UP := 0.07
const ROOM_MONEY_BUMP_DURATION_DOWN := 0.08
const backwallVariants : Array = [
	preload("res://assets/sprites/back-wall.png"),
	preload("res://assets/sprites/back-wall_window1.png"),
	preload("res://assets/sprites/back-wall_window2.png"),
	preload("res://assets/sprites/back-wall_window3.png"),
]

signal on_destroy_signal
var _room_money_sprite: Sprite2D = null
var _room_money_tween: Tween = null
var _last_room_money_amount: float = -1.0

func init_room(x : int, y : int):
	self.x = x
	self.y = y
	is_basement = y < 0

	if not is_outside_room and back_wall_sprite_2d != null:
		if is_basement:
			back_wall_sprite_2d.texture = backwallBasement
		else:
			back_wall_sprite_2d.texture = backwallVariants[randi() % backwallVariants.size()]

	var modules_root: Node = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				if not module.has_method("set_bought"):
					continue
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					_on_module_bought(module)

	_setup_room_money_visual()

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	current_module = module

func set_outline(state: bool, source = null) -> void:
	var key = source if source != null else &"default"
	if state:
		_outline_sources[key] = true
	else:
		_outline_sources.erase(key)
	_apply_outline_state(not _outline_sources.is_empty())

func _apply_outline_state(state: bool) -> void:
	var sprite: CanvasItem = null
	sprite = get_child(1) as CanvasItem
	
	if not sprite:
		return

	sprite.visible = state	

func get_random_floor_position():
	var offset = Vector2(randi_range(4, 44), 0)
	return global_position + offset

func get_center_position():
	return global_position + Vector2(24, -24)

func get_top_center_position():
	return global_position + Vector2(24, -48)

func get_center_floor_position():
	return global_position + Vector2(24, 0)

func get_preferred_horizontal_queue_direction(fallback_direction: float = 1.0) -> float:
	var left_span: int = _get_contiguous_queue_span(-1)
	var right_span: int = _get_contiguous_queue_span(1)

	if left_span == 0 and right_span == 0:
		return fallback_direction
	if left_span == right_span:
		return fallback_direction
	return -1.0 if left_span > right_span else 1.0

func _get_contiguous_queue_span(direction: int) -> int:
	var room_width: int = data.width if data != null else 1
	var current_x: int = x - 1 if direction < 0 else x + room_width
	var span: int = 0

	while true:
		var room := Building.get_room_from_index(Vector2i(current_x, y)) as RoomBase
		if room == null or room is RoomStairs:
			return span
		span += 1
		current_x += direction

	return span

func get_notification_position():
	return global_position + Vector2(2, -32)

func _setup_room_money_visual() -> void:
	if data == null or data.money_capacity <= 0 or data == Building.room_data_safe:
		return
	if MoneyHandler.on_money_changed_signal.is_connected(_update_room_money_visual):
		return

	_room_money_sprite = Sprite2D.new()
	_room_money_sprite.texture = ROOM_MONEY_SPRITESHEET
	_room_money_sprite.hframes = ROOM_MONEY_HFRAMES
	_room_money_sprite.centered = true
	_room_money_sprite.z_index = ROOM_MONEY_Z_INDEX
	_room_money_sprite.position = _get_room_money_visual_position()
	_room_money_sprite.visible = false
	add_child(_room_money_sprite)

	MoneyHandler.on_money_changed_signal.connect(_update_room_money_visual)
	_update_room_money_visual()

func _get_room_money_visual_position() -> Vector2:
	var anchor := get_node_or_null("MoneySpriteAnchor") as Node2D
	if anchor != null:
		return anchor.position
	return Vector2(float(data.width) * 48.0 - 24.5, -24.0)

func _update_room_money_visual() -> void:
	if _room_money_sprite == null or data == null:
		return

	var amount := MoneyHandler.get_money_at(Vector2i(x, y))
	var had_previous_amount := _last_room_money_amount >= 0.0
	var amount_changed := had_previous_amount and not is_equal_approx(amount, _last_room_money_amount)
	var frame := _get_room_money_frame(amount)
	_room_money_sprite.visible = frame >= 0
	if frame >= 0:
		_room_money_sprite.frame = frame
	if amount_changed:
		_bump_room_money_visual()
	_last_room_money_amount = amount

func _bump_room_money_visual() -> void:
	if _room_money_sprite == null:
		return

	if _room_money_tween != null and _room_money_tween.is_valid():
		_room_money_tween.kill()

	_room_money_sprite.scale = Vector2.ONE
	_room_money_tween = create_tween()
	_room_money_tween.tween_property(_room_money_sprite, "scale", ROOM_MONEY_BUMP_SCALE, ROOM_MONEY_BUMP_DURATION_UP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_room_money_tween.tween_property(_room_money_sprite, "scale", Vector2.ONE, ROOM_MONEY_BUMP_DURATION_DOWN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _get_room_money_frame(amount: float) -> int:
	if amount < 1.0:
		return -1

	var capped_amount := clampf(amount, 1.0, ROOM_MONEY_MAX_VISUAL_AMOUNT)
	var normalized := log(capped_amount) / log(ROOM_MONEY_MAX_VISUAL_AMOUNT)
	return clampi(int(floor(normalized * float(ROOM_MONEY_HFRAMES - 1))), 0, ROOM_MONEY_HFRAMES - 1)

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func get_associated_job_capacity(job = null) -> int:
	if job == null:
		job = associated_job
	if associated_job == null or job != associated_job:
		return 0
	return 1

func get_service_price() -> int:
	return 0

func get_assigned_worker_count(job = null) -> int:
	if job == null:
		job = associated_job
	if associated_job == null or job != associated_job:
		return 0
	return 1 if worker != null else 0

func can_accept_worker(job = null) -> bool:
	if job == null:
		job = associated_job
	return get_assigned_worker_count(job) < get_job_capacity(job)

func get_provided_infrastructure_layers() -> Array[StringName]:
	var provided: Array[StringName] = []
	return provided

func uses_infrastructure_layer(_layer_name: StringName) -> bool:
	return false

func wants_infrastructure_layer(_layer_name: StringName) -> bool:
	return false

func requires_infrastructure_layer(_layer_name: StringName) -> bool:
	return false

func refresh_infrastructure_visuals() -> void:
	if is_instance_valid(Building.infrastructure):
		Building.infrastructure.refresh_visuals()

func clear_infrastructure_output_tiles(_layer_name: StringName) -> void:
	return

func add_infrastructure_output_tile(_layer_name: StringName, _room_index: Vector2i, _tile_index: int) -> void:
	return

func destroy():
	if MoneyHandler.on_money_changed_signal.is_connected(_update_room_money_visual):
		MoneyHandler.on_money_changed_signal.disconnect(_update_room_money_visual)
	if _room_money_tween != null and _room_money_tween.is_valid():
		_room_money_tween.kill()
	on_destroy_signal.emit()
	queue_free()
