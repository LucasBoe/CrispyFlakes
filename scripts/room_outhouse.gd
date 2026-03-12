extends RoomOutsideBase
class_name RoomOuthouse

var user : NPC

@onready var progressBar : TextureProgressBar = $ProgressBar

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	progressBar.visible = false

func is_used_by_other_then(npc : NPC):
	if user == null:
		return false

	return user != npc
