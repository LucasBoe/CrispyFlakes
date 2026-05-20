extends Behaviour
class_name BarberSurgeonBehaviour

const NEED_BARBER_SURGEON_TREATMENT_BEHAVIOUR := preload("res://scripts/npc/behaviours/need_barber_surgeon_treatment_behaviour.gd")

const TREAT_DURATION := 8.0
const TREATMENT_QUALITY := 0.75
const TIMEOUT_MSEC := 30000
const QUEUE_SPACING := 10.0
const QUEUE_CLAMP_STEP := 4.0
const NO_SEAT_RETRY_SECONDS := 1.5
const NO_SEAT_NOTIFICATION_DURATION := 1.5

class TreatmentRequest:
	var status: Enum.RequestStatus = Enum.RequestStatus.OPEN
	var treatment_quality: float = 0.5
	var time: int = 0
	var patient: NPC = null

var table: RoomTable = null
var treatment_requests: Array[TreatmentRequest] = []
var waiting_queue: Array[NPC] = []

func loop() -> void:
	while not stopped and is_instance_valid(npc):
		_timeout_old_requests()
		if not _has_pending_or_treatable_patients():
			break

		var seated = await _ensure_seated()
		if not seated:
			continue

		var request := _pop_invalid_request()
		if request == null:
			_narrative = ["Waiting for patients...", "Ready with the instruments...", "Watching for the next patient..."].pick_random()
			await pause(0.5)
			continue

		request.status = Enum.RequestStatus.IN_PROGRESS
		_narrative = ["Treating a patient...", "Stitching someone up...", "Working with the sawbones tools..."].pick_random()
		await progress(TREAT_DURATION)

		if stopped or not is_instance_valid(npc):
			return

		if request.status != Enum.RequestStatus.IN_PROGRESS:
			continue

		request.treatment_quality = TREATMENT_QUALITY
		request.status = Enum.RequestStatus.FULFILLED
		treatment_requests.erase(request)

		if is_instance_valid(request.patient):
			InjuryHandler.apply_treatment(request.patient, request.treatment_quality)

	await _leave()

func request_treatment(patient: NPC = null):
	if not accepts_patient(patient):
		return null
	if patient != null:
		for req: TreatmentRequest in treatment_requests:
			if req.patient == patient and req.status != Enum.RequestStatus.TIMEOUT:
				req.time = Time.get_ticks_msec()
				return req

	var req := TreatmentRequest.new()
	req.time = Time.get_ticks_msec()
	req.patient = patient
	treatment_requests.append(req)
	return req

func join_queue(waiting_npc: NPC) -> void:
	if waiting_npc != null and not waiting_queue.has(waiting_npc):
		waiting_queue.append(waiting_npc)

func leave_queue(waiting_npc: NPC) -> void:
	waiting_queue.erase(waiting_npc)

func accepts_patient(patient: NPC) -> bool:
	if patient == null or not is_instance_valid(patient):
		return false
	if patient is not NPCGuest and patient is not NPCWorker:
		return false
	if not _is_ready_for_patients():
		return false
	return InjuryHandler.can_receive_treatment_now(patient)

func get_waiting_room_position() -> Vector2:
	if is_instance_valid(table):
		return table.get_random_floor_position()
	return npc.global_position

func get_queue_position(waiting_npc: NPC) -> Vector2:
	if not is_instance_valid(table):
		return npc.global_position

	var index: int = waiting_queue.find(waiting_npc)
	if index < 0:
		return table.get_center_floor_position()

	var direction: float = table.get_preferred_horizontal_queue_direction(1.0 if table.global_position.x >= 0.0 else -1.0)
	var queue_target: Vector2 = table.get_center_floor_position() + Vector2(direction * (index + 1) * QUEUE_SPACING, 0.0)
	return _get_valid_queue_position(queue_target)

func get_treatment_position() -> Vector2:
	if is_instance_valid(table):
		return table.global_position + Vector2(24, -14)
	return npc.global_position

func get_assigned_table() -> RoomTable:
	return table if _is_ready_for_patients() else null

func stop_loop() -> BehaviourSaveData:
	for req: TreatmentRequest in treatment_requests:
		if req.status == Enum.RequestStatus.OPEN or req.status == Enum.RequestStatus.IN_PROGRESS:
			req.status = Enum.RequestStatus.TIMEOUT
	treatment_requests.clear()
	waiting_queue.clear()
	_stand_up()
	return super.stop_loop()

func _ensure_seated():
	while not stopped and is_instance_valid(npc):
		if _is_ready_for_patients():
			return true

		table = _find_free_table()
		if table == null:
			_narrative = ["Needs a table...", "Looking for a place to sit...", "Can't operate standing up..."].pick_random()
			UiNotifications.create_notification_dynamic("i need to sit", npc, Vector2(0, -32), null, Color.BLACK, NO_SEAT_NOTIFICATION_DURATION)
			await pause(NO_SEAT_RETRY_SECONDS)
			if not _has_pending_or_treatable_patients():
				return false
			continue

		_narrative = ["Heading for a table...", "Making space for patients...", "Setting up at a table..."].pick_random()
		await move(table.get_center_floor_position())

		if stopped or not is_instance_valid(npc):
			return false
		if not is_instance_valid(table) or not table.is_free():
			table = null
			await end_of_frame()
			continue

		var seat_position: Vector2 = table.sit(npc)
		table.on_seated(npc)
		npc.global_position = seat_position
		return true

	return false

func _find_free_table() -> RoomTable:
	return get_least_loaded_room_of_type(
		RoomTable,
		func(candidate: RoomTable): return candidate.is_free(),
		func(candidate: RoomTable): return candidate.max_guest_count - candidate.get_free_count(),
		func(candidate: RoomTable): return candidate.max_guest_count
	) as RoomTable

func _is_ready_for_patients() -> bool:
	return is_instance_valid(table) and table.is_guest_seated(npc)

func _timeout_old_requests() -> void:
	var now: int = Time.get_ticks_msec()
	for req: TreatmentRequest in treatment_requests.duplicate():
		if now - req.time > TIMEOUT_MSEC:
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
	if req == null or req.patient == null:
		return false
	if not is_instance_valid(req.patient):
		return false
	if not InjuryHandler.can_receive_treatment_now(req.patient):
		return false

	var behaviour := req.patient.Behaviour.behaviour_instance if req.patient.Behaviour != null else null
	if behaviour == null or behaviour.get_script() != NEED_BARBER_SURGEON_TREATMENT_BEHAVIOUR:
		return false

	if req.status == Enum.RequestStatus.IN_PROGRESS:
		return _is_ready_for_patients()

	return accepts_patient(req.patient) and waiting_queue.has(req.patient)

func _has_pending_or_treatable_patients() -> bool:
	for req: TreatmentRequest in treatment_requests:
		if _is_request_valid(req):
			return true

	for patient: NPC in InjuryHandler.get_injured_npcs():
		if not _can_eventually_treat(patient):
			continue
		return true

	return false

func _can_eventually_treat(patient: NPC) -> bool:
	if patient == null or not is_instance_valid(patient):
		return false
	if patient is not NPCGuest and patient is not NPCWorker:
		return false
	if not InjuryHandler.can_receive_treatment_now(patient):
		return false
	if _is_ready_for_patients():
		return patient.Navigation != null and patient.Navigation.is_room_reachable(table)
	return true

func _get_valid_queue_position(queue_target: Vector2) -> Vector2:
	var center: Vector2 = table.get_center_floor_position()
	var clamped_target: Vector2 = queue_target

	while true:
		var room := Building.query.room_at_position(clamped_target) as RoomBase
		if room != null and room.y == table.y and room is not RoomStairs:
			return clamped_target

		if is_equal_approx(clamped_target.x, center.x):
			return center

		clamped_target.x = move_toward(clamped_target.x, center.x, QUEUE_CLAMP_STEP)

	return center

func _stand_up() -> void:
	if _is_ready_for_patients():
		table.stand_up(npc)
		npc.global_position = table.get_center_floor_position()
	elif is_instance_valid(npc) and npc.Animator != null:
		npc.Animator.set_sitting(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	table = null

func _leave() -> void:
	_stand_up()
	_narrative = ["Packing up the instruments...", "No more patients today...", "Heading out after the last treatment..."].pick_random()
	await move(Global.LEAVE_POSITION)
	if is_instance_valid(npc):
		npc.destroy()
