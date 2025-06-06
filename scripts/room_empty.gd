extends Node2D
class_name RoomEmpty

var x
var y
var isBasement
var associatedJob = null

@onready var backWallSprite2D = $"Back-wall"

const backwallDefault = preload("res://assets/sprites/back-wall.png");
const backwallBasement = preload("res://assets/sprites/back-wall_basement.png");


func InitRoom(x : int, y : int):
	self.x = x
	self.y = y
	isBasement = y < 0
	backWallSprite2D.texture = backwallBasement if isBasement else backwallDefault

func get_random_floor_position():
	var offset = Vector2(randi_range(4, 44), 0)
	return global_position + offset
