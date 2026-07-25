extends RefCounted
class_name ElevatorRideRequest

signal finished

var npc: NPC
var from_room
var to_room
var direction: int

func _init(ride_npc: NPC = null, ride_from_room = null, ride_to_room = null) -> void:
	npc = ride_npc
	from_room = ride_from_room
	to_room = ride_to_room
	if from_room != null and to_room != null:
		direction = signi(to_room.y - from_room.y)
