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
