extends RoomOutsideBase
class_name RoomOuthouse

const MAX_USES = 5

var user : NPC
var uses : int = 0

@onready var progressBar : TextureProgressBar = $ProgressBar

func init_room(_x : int, _y : int):
	associated_job = Enum.Jobs.OUTHOUSE_CLEANER
	super.init_room(_x, _y)
	progressBar.visible = false

func is_used_by_other_then(npc : NPC):
	if user == null:
		return false

	return user != npc

func is_full() -> bool:
	return uses >= MAX_USES
