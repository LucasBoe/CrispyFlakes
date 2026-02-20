extends Node2D
class_name RoomBase

var x
var y
var isBasement
var data : RoomData
var associatedJob = null
var isOutsideRoom = false
var has_upgrades = false
var worker = null

@onready var backWallSprite2D = $"Back-wall"

const backwallDefault = preload("res://assets/sprites/back-wall.png");
const backwallBasement = preload("res://assets/sprites/back-wall_basement.png");


func InitRoom(x : int, y : int):
	self.x = x
	self.y = y
	isBasement = y < 0
	
	if not isOutsideRoom:
		backWallSprite2D.texture = backwallBasement if isBasement else backwallDefault

func get_random_floor_position():
	var offset = Vector2(randi_range(4, 44), 0)
	return global_position + offset

func get_center_position():
	return global_position + Vector2(24, -24)
	
func get_top_center_position():
	return global_position + Vector2(24, -48)
	
func get_center_floor_position():
	return global_position + Vector2(24, 0)
