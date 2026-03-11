extends RoomBase
class_name RoomBrewery

@onready var progressBar : TextureProgressBar = $ProgressBar

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	progressBar.visible = false
	associated_job = Enum.Jobs.BREWERY
