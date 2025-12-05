extends RoomEmpty
class_name RoomWell


func InitRoom(x : int, y : int):
	isOutsideRoom = true
	super.InitRoom(x,y)

static func custom_placement_check(location) -> bool:
	return location.y == 0
