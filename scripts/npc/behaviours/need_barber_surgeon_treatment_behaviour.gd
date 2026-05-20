extends NeedBehaviour
class_name NeedBarberSurgeonTreatmentBehaviour

var barber = null
var request = null

func loop() -> void:
	_narrative = ["Looking for the barber surgeon...", "Need stitching up...", "Searching for treatment..."].pick_random()
	barber = _find_barber()
	if barber == null:
		return

	_narrative = ["Heading to the barber surgeon...", "Making for the table clinic..."].pick_random()
	await move(barber.get_waiting_room_position())

	if not _can_use_barber():
		return

	request = barber.request_treatment(npc)
	if request == null:
		return

	barber.join_queue(npc)
	_narrative = ["Waiting for treatment...", "Queued for the barber surgeon...", "Waiting their turn..."].pick_random()
	while _should_wait_for_treatment():
		var target_pos: Vector2 = barber.get_queue_position(npc)
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	barber.leave_queue(npc)

	if request == null or request.status != Enum.RequestStatus.IN_PROGRESS or not _can_use_barber():
		return

	_narrative = ["Getting treated...", "Holding still...", "Under the knife..."].pick_random()
	await move(barber.get_treatment_position())
	npc.Animator.set_sleeping(true)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)

	var pos_before := npc.global_position
	npc.global_position = barber.get_treatment_position()

	while request.status == Enum.RequestStatus.IN_PROGRESS and _can_use_barber():
		await end_of_frame()

	npc.Animator.set_sleeping(false)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	npc.global_position = pos_before

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(npc) and npc.Animator != null and npc.Animator.is_sleeping:
		npc.Animator.set_sleeping(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)

	if barber != null:
		barber.leave_queue(npc)

	if request != null and (request.status == Enum.RequestStatus.OPEN or request.status == Enum.RequestStatus.IN_PROGRESS):
		request.status = Enum.RequestStatus.TIMEOUT
		if barber != null:
			barber.treatment_requests.erase(request)

	return super.stop_loop()

func _find_barber():
	return InjuryHandler.find_barber_surgeon_provider(npc)

func _can_use_barber() -> bool:
	return barber != null and is_instance_valid(barber.npc) and barber.accepts_patient(npc) and InjuryHandler.can_receive_treatment_now(npc)

func _should_wait_for_treatment() -> bool:
	return not stopped and request != null and request.status == Enum.RequestStatus.OPEN and _can_use_barber()
