extends RoomBase
class_name RoomPrison

var prisoners = []

func InitRoom(x : int, y : int):
	associatedJob = Enum.Jobs.PRISON
	super.InitRoom(x,y)
