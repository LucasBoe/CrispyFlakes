extends RoomBase
class_name RoomMineshaftEntrance

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.MINER

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)
