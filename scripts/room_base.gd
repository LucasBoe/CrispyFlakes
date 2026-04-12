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

@onready var back_wall_sprite_2d = get_node_or_null("Back-wall") as Sprite2D

const backwallDefault = preload("res://assets/sprites/back-wall.png");
const backwallBasement = preload("res://assets/sprites/back-wall_basement.png");

signal on_destroy_signal

func init_room(x : int, y : int):
	self.x = x
	self.y = y
	is_basement = y < 0

	if not is_outside_room and back_wall_sprite_2d != null:
		back_wall_sprite_2d.texture = backwallBasement if is_basement else backwallDefault

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
