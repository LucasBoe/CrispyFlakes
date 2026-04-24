extends Node2D
class_name RoomBase

var x
var y
var is_basement
var data : RoomData
var associated_job = null
var is_outside_room = false
var has_upgrades = false
var worker : NPCWorker = null
var current_module = null

@onready var back_wall_sprite_2d = get_node_or_null("Back-wall") as Sprite2D

const backwallDefault = preload("res://assets/sprites/back-wall.png");
const backwallBasement = preload("res://assets/sprites/back-wall_basement.png");
const backwallVariants : Array = [
	preload("res://assets/sprites/back-wall.png"),
	preload("res://assets/sprites/back-wall_window1.png"),
	preload("res://assets/sprites/back-wall_window2.png"),
	preload("res://assets/sprites/back-wall_window3.png"),
]

signal on_destroy_signal

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

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	current_module = module

func set_outline(state):
	
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

func get_job_capacity(job = null) -> int:
	if job == null:
		job = associated_job
	if associated_job == null or job != associated_job:
		return 0
	return 1

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

func destroy():
	on_destroy_signal.emit()
	queue_free()
