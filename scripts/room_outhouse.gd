extends RoomBase
class_name RoomOuthouse

var user : NPC

@onready var progressBar : TextureProgressBar = $ProgressBar

func InitRoom(x : int, y : int):
	isOutsideRoom = true
	super.InitRoom(x,y)
	progressBar.visible = false
	
func is_used_by_other_then(npc : NPC):
	if user == null:
		return false
	
	return user != npc
	
static func custom_placement_check(location) -> bool:
	return location.y == 0
