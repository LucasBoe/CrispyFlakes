extends RoomEmpty
class_name RoomBar

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	associatedJob = Enum.Jobs.BAR

func TryReceive(item) -> bool:
	item.free_queue()
	return true
