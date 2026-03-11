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

@onready var back_wall_sprite_2d = $"Back-wall"

const backwallDefault = preload("res://assets/sprites/back-wall.png");
const backwallBasement = preload("res://assets/sprites/back-wall_basement.png");

signal on_destroy_signal

func init_room(_x : int, _y : int):
	x = _x
	y = _y
	is_basement = _y < 0

	if not is_outside_room:
		back_wall_sprite_2d.texture = backwallBasement if is_basement else backwallDefault

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

func destroy():
	on_destroy_signal.emit()
	queue_free()
