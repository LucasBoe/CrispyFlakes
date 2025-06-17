extends RoomEmpty
class_name RoomBar

@onready var progressBar : TextureProgressBar = $ProgressBar

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	associatedJob = Enum.Jobs.BAR
	progressBar.visible = false

func TryReceive(item) -> bool:
	item.free_queue()
	return true
