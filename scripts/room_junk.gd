extends RoomBase
class_name RoomJunk

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.JUNK

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)
