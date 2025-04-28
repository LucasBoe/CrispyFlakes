extends Node2D
class_name RoomEmpty

var x
var y
var isBasement

func InitRoom(x : int, y : int):
	self.x = x
	self.y = y
	isBasement = y < 0
