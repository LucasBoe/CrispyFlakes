extends RoomEmpty
class_name RoomWell

@onready var progressBar : TextureProgressBar = $ProgressBar

func InitRoom(x : int, y : int):
	isOutsideRoom = true
	super.InitRoom(x,y)
	progressBar.visible = false
	associatedJob = Enum.Jobs.WELL

static func custom_placement_check(location) -> bool:
	return location.y == 0
