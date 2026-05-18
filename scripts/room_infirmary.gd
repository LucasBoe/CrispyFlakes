extends RoomBase
class_name RoomInfirmary

const TIMEOUT_MSEC := 30000
const QUEUE_SPACING := 10.0
const QUEUE_CLAMP_STEP := 4.0

var treatment_requests: Array[TreatmentRequest] = []
var waiting_queue: Array[NPC] = []

class TreatmentRequest:
	var status: Enum.RequestStatus = Enum.RequestStatus.OPEN
	var treatment_quality: float = 0.5
	var time: int = 0

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.DOCTOR

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func _process(_delta: float) -> void:
	_timeout_old_requests()

func get_treatment_position() -> Vector2:
	return global_position + Vector2(32, -14)

func join_queue(waiting_npc: NPC) -> void:
	if not waiting_queue.has(waiting_npc):
		waiting_queue.append(waiting_npc)

func leave_queue(waiting_npc: NPC) -> void:
	waiting_queue.erase(waiting_npc)

func get_queue_position(waiting_npc: NPC) -> Vector2:
	var index: int = waiting_queue.find(waiting_npc)
	if index < 0:
		return get_center_floor_position()
	var direction: float = get_preferred_horizontal_queue_direction(1.0 if global_position.x >= 0.0 else -1.0)
	var queue_target: Vector2 = get_center_floor_position() + Vector2(direction * (index + 1) * QUEUE_SPACING, 0.0)
	return _get_valid_queue_position(queue_target)

func request_treatment() -> TreatmentRequest:
	var req := TreatmentRequest.new()
	req.time = Time.get_ticks_msec()
	treatment_requests.append(req)
	return req

func start_next_treatment() -> void:
	if treatment_requests.is_empty():
		return
	treatment_requests[0].status = Enum.RequestStatus.IN_PROGRESS

func fulfill_next_request(quality: float) -> void:
	if treatment_requests.is_empty():
		return
	var req: TreatmentRequest = treatment_requests[0]
	req.treatment_quality = quality
	req.status = Enum.RequestStatus.FULFILLED
	treatment_requests.erase(req)

func _timeout_old_requests() -> void:
	var t: int = Time.get_ticks_msec()
	for req: TreatmentRequest in treatment_requests.duplicate():
		if t - req.time > TIMEOUT_MSEC:
			req.status = Enum.RequestStatus.TIMEOUT
			treatment_requests.erase(req)

func _get_valid_queue_position(queue_target: Vector2) -> Vector2:
	var center: Vector2 = get_center_floor_position()
	var clamped_target: Vector2 = queue_target

	while true:
		var room := Building.query.room_at_position(clamped_target) as RoomBase
		if room != null and room.y == y and room is not RoomStairs:
			return clamped_target

		if is_equal_approx(clamped_target.x, center.x):
			return center

		clamped_target.x = move_toward(clamped_target.x, center.x, QUEUE_CLAMP_STEP)

	return center
