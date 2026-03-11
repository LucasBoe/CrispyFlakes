extends RoomBase
class_name RoomPrison

var prisoners = []

func init_room(_x : int, _y : int):
	associated_job = Enum.Jobs.PRISON
	super.init_room(_x, _y)
