extends NeedBehaviour
class_name NeedTreatmentBehaviour

var infirmary: RoomInfirmary = null
var request: RoomInfirmary.TreatmentRequest = null

func loop() -> void:
	_narrative = ["Looking for a doctor...", "Need treatment...", "Searching for help..."].pick_random()
	infirmary = _find_infirmary()

	if infirmary == null:
		return

	_narrative = ["Going to the infirmary...", "Heading to the doctor..."].pick_random()
	await move(infirmary.get_random_floor_position())

	if not _can_use_infirmary():
		return

	request = infirmary.request_treatment(npc)
	if request == null:
		return

	infirmary.join_queue(npc)

	_narrative = ["Waiting for the doc...", "In the queue...", "Doc'll see you soon..."].pick_random()
	while _should_wait_for_treatment():
		var target_pos: Vector2 = infirmary.get_queue_position(npc)
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	infirmary.leave_queue(npc)

	if request == null or request.status != Enum.RequestStatus.IN_PROGRESS or not _can_use_infirmary():
		return

	_narrative = ["Lying down...", "Getting on the table..."].pick_random()
	await move(infirmary.get_treatment_position())
	npc.Animator.set_sleeping(true)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	
	var pos_before = npc.global_position
	npc.global_position = infirmary.get_treatment_position()

	while request.status == Enum.RequestStatus.IN_PROGRESS and _can_use_infirmary():
		await end_of_frame()

	npc.Animator.set_sleeping(false)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	npc.global_position = pos_before

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(npc) and npc.Animator != null and npc.Animator.is_sleeping:
		npc.Animator.set_sleeping(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	if is_instance_valid(infirmary):
		infirmary.leave_queue(npc)
	if request != null and (request.status == Enum.RequestStatus.OPEN or request.status == Enum.RequestStatus.IN_PROGRESS):
		request.status = Enum.RequestStatus.TIMEOUT
		if is_instance_valid(infirmary):
			infirmary.treatment_requests.erase(request)
	return super.stop_loop()

func _find_infirmary() -> RoomInfirmary:
	return InjuryHandler.find_treatment_infirmary(npc)

func _can_use_infirmary() -> bool:
	return is_instance_valid(infirmary) and infirmary.accepts_patient(npc) and InjuryHandler.can_receive_treatment_now(npc)

func _should_wait_for_treatment() -> bool:
	return not stopped and request != null and request.status == Enum.RequestStatus.OPEN and _can_use_infirmary()
