extends RoomBase
class_name RoomInfirmary

const TIMEOUT_MSEC := 30000
const QUEUE_SPACING := 10.0
const QUEUE_CLAMP_STEP := 4.0
const SERVICE_PRICE := 18

var treat_guests := true
var treat_workers := true
var treatment_requests: Array[TreatmentRequest] = []
var waiting_queue: Array[NPC] = []

class TreatmentRequest:
	var status: Enum.RequestStatus = Enum.RequestStatus.OPEN
	var treatment_quality: float = 0.5
	var time: int = 0
	var patient: NPC = null
	var infirmary: RoomInfirmary = null

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.DOCTOR

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func get_service_price() -> int:
	return SERVICE_PRICE

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

func request_treatment(patient: NPC = null) -> TreatmentRequest:
	if patient != null and not accepts_patient(patient):
		return null
	if patient != null:
		for req: TreatmentRequest in treatment_requests:
			if req.patient == patient and req.status != Enum.RequestStatus.TIMEOUT:
				req.time = Time.get_ticks_msec()
				return req

	var req := TreatmentRequest.new()
	req.time = Time.get_ticks_msec()
	req.patient = patient
	req.infirmary = self
	treatment_requests.append(req)
	return req

func accepts_patient(patient: NPC) -> bool:
	if patient == null or not is_instance_valid(patient):
		return false
	if patient is NPCGuest:
		return treat_guests
	if patient is NPCWorker:
		return treat_workers
	return false

func start_next_treatment() -> void:
	var req := _pop_invalid_request()
	if req == null:
		return
	req.status = Enum.RequestStatus.IN_PROGRESS

func fulfill_next_request(quality: float) -> TreatmentRequest:
	var req := _pop_invalid_request()
	if req == null:
		return null
	req.treatment_quality = quality
	req.status = Enum.RequestStatus.FULFILLED
	treatment_requests.erase(req)
	return req

func _timeout_old_requests() -> void:
	var t: int = Time.get_ticks_msec()
	for req: TreatmentRequest in treatment_requests.duplicate():
		if t - req.time > TIMEOUT_MSEC:
			req.status = Enum.RequestStatus.TIMEOUT
			treatment_requests.erase(req)

func _pop_invalid_request() -> TreatmentRequest:
	while not treatment_requests.is_empty():
		var req: TreatmentRequest = treatment_requests[0]
		if _is_request_valid(req):
			return req
		req.status = Enum.RequestStatus.TIMEOUT
		treatment_requests.remove_at(0)
	return null

func _is_request_valid(req: TreatmentRequest) -> bool:
	if req == null:
		return false
	if req.patient == null:
		return true
	if not is_instance_valid(req.patient):
		return false
	if not InjuryHandler.can_receive_treatment_now(req.patient):
		return false
	var behaviour := req.patient.Behaviour.behaviour_instance if req.patient.Behaviour != null else null
	if behaviour is not NeedTreatmentBehaviour:
		return false
	if req.status == Enum.RequestStatus.IN_PROGRESS:
		return true
	return accepts_patient(req.patient) and waiting_queue.has(req.patient)

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
