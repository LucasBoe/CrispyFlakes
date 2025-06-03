extends RoomEmpty
class_name RoomBrewery

const GRID_SIZE = 48


func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	associatedJob = Enum.Jobs.BREWERY
