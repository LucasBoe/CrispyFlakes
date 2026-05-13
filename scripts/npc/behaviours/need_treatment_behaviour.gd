extends NeedBehaviour
class_name NeedTreatmentBehaviour

var infirmary: RoomInfirmary = null
var request: RoomInfirmary.TreatmentRequest = null

func loop() -> void:
	_narrative = ["Looking for a doctor...", "Need treatment...", "Searching for help..."].pick_random()
	infirmary = _find_infirmary()

	if infirmary == null:
		await pause(2.0)
		return

	_narrative = ["Going to the infirmary...", "Heading to the doctor..."].pick_random()
	await move(infirmary.get_random_floor_position())

	if not is_instance_valid(infirmary):
		return

	request = infirmary.request_treatment()
	infirmary.join_queue(npc)

	_narrative = ["Waiting for the doc...", "In the queue...", "Doc'll see you soon..."].pick_random()
	await move(infirmary.get_queue_position(npc))

	while request.status == Enum.RequestStatus.OPEN:
		if stopped or not is_instance_valid(infirmary):
			break
		var target_pos: Vector2 = infirmary.get_queue_position(npc)
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	infirmary.leave_queue(npc)

	if request.status != Enum.RequestStatus.IN_PROGRESS:
		return

	_narrative = ["Lying down...", "Getting on the table..."].pick_random()
	await move(infirmary.get_treatment_position())
	npc.Animator.set_sleeping(true)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	
	var pos_before = npc.global_position
	npc.global_position = infirmary.get_treatment_position()

	while request.status == Enum.RequestStatus.IN_PROGRESS:
		await end_of_frame()

	npc.Animator.set_sleeping(false)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	npc.global_position = pos_before

	if request.status != Enum.RequestStatus.FULFILLED:
		return

	npc.Status.clear_status(Enum.NpcStatus.INJURED)
	InjuryHandler.on_guest_recovered(npc as NPCGuest)
	if request.treatment_quality >= 0.6:
		npc.Status.set_status(Enum.NpcStatus.WELL_TREATED)
	else:
		npc.Status.set_status(Enum.NpcStatus.BADLY_TREATED)

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(npc) and npc.Animator != null and npc.Animator.is_sleeping:
		npc.Animator.set_sleeping(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	if is_instance_valid(infirmary):
		infirmary.leave_queue(npc)
	if request != null and request.status == Enum.RequestStatus.OPEN:
		request.status = Enum.RequestStatus.TIMEOUT
		if is_instance_valid(infirmary):
			infirmary.treatment_requests.erase(request)
	return super.stop_loop()

func _find_infirmary() -> RoomInfirmary:
	var rooms: Array = get_all_rooms_of_type_ordered_by_distance(RoomInfirmary)
	return rooms[0] as RoomInfirmary if not rooms.is_empty() else null
