extends RoomEmpty
class_name RoomWell

@onready var progressBar : TextureProgressBar = $ProgressBar

var current_user
var registered_users = []

func InitRoom(x : int, y : int):
	isOutsideRoom = true
	super.InitRoom(x,y)
	progressBar.visible = false
	associatedJob = Enum.Jobs.WELL
	
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

static func custom_placement_check(location) -> bool:
	return location.y == 0
