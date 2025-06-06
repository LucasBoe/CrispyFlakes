extends RoomEmpty
class_name RoomBrewery

const GRID_SIZE = 48
@onready var progressBar : TextureProgressBar = $ProgressBar

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	progressBar.visible = false
	associatedJob = Enum.Jobs.BREWERY
