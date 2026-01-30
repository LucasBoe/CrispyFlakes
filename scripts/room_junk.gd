extends RoomBase
class_name RoomJunk

@onready var progressBar : TextureProgressBar = $ProgressBar

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	progressBar.visible = false
	associatedJob = Enum.Jobs.JUNK
