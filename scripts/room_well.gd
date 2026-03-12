extends RoomOutsideBase
class_name RoomWell

@onready var progressBar : TextureProgressBar = $ProgressBar

var current_user
var registered_users = []

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	progressBar.visible = false
	associated_job = Enum.Jobs.WELL

func register(npc : NPC):
	registered_users.append(npc)
	check_next()

func unregister(npc : NPC):
	registered_users.erase(npc)
	check_next()

func check_next():
	if registered_users.size() > 0:
		current_user = registered_users[0]
	else:
		current_user = null
