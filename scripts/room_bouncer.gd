extends RoomBase
class_name RoomBouncer

const MAX_BOUNCERS := 3
const BOUNCER_BACKWALL = preload("res://assets/sprites/back-wall_bouncer.png")

var assigned_bouncers: Array[NPCWorker] = []

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	back_wall_sprite_2d.texture = BOUNCER_BACKWALL
	associated_job = Enum.Jobs.BOUNCER

func get_job_capacity(job = null) -> int:
	if job == null:
		job = associated_job
	if job != Enum.Jobs.BOUNCER:
		return 0
	return MAX_BOUNCERS

func get_assigned_worker_count(job = null) -> int:
	if job == null:
		job = associated_job
	if job != Enum.Jobs.BOUNCER:
		return 0
	_cleanup_assigned_bouncers()
	return assigned_bouncers.size()

func register_bouncer(bouncer: NPCWorker) -> bool:
	_cleanup_assigned_bouncers()
	if assigned_bouncers.has(bouncer):
		_refresh_primary_worker()
		return true
	if assigned_bouncers.size() >= MAX_BOUNCERS:
		return false
	assigned_bouncers.append(bouncer)
	_refresh_primary_worker()
	return true

func unregister_bouncer(bouncer: NPCWorker) -> void:
	assigned_bouncers.erase(bouncer)
	_refresh_primary_worker()

func _cleanup_assigned_bouncers() -> void:
	for i in range(assigned_bouncers.size() - 1, -1, -1):
		if not is_instance_valid(assigned_bouncers[i]):
			assigned_bouncers.remove_at(i)
	_refresh_primary_worker()

func _refresh_primary_worker() -> void:
	worker = assigned_bouncers[0] if not assigned_bouncers.is_empty() else null

func has_active_bouncer() -> bool:
	return get_assigned_worker_count(Enum.Jobs.BOUNCER) > 0
