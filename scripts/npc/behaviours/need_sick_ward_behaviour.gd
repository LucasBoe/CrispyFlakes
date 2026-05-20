extends NeedBehaviour
class_name NeedSickWardBehaviour

const WELL_TREATED_REST_DURATION := 60.0
const BADLY_TREATED_REST_DURATION := 120.0

var room: RoomSickWard = null

func loop() -> void:
	var is_well_treated: bool = npc.Status.has_status(Enum.NpcStatus.WELL_TREATED)

	_narrative = ["Needs medical rest...", "Looking for a sick ward...", "Searching for a bed..."].pick_random()
	room = _find_available_sick_ward()
	var any_ward: RoomSickWard = _find_any_sick_ward()

	if room == null:
		await _rest_on_floor(is_well_treated, any_ward)
		return

	_narrative = ["Heading to sick ward...", "Shuffling to the ward..."].pick_random()
	await move(room.get_random_floor_position())

	var wait_frames: int = 0
	while is_instance_valid(room) and room.is_full():
		await end_of_frame()
		wait_frames += 1
		if wait_frames > 180:
			await _rest_on_floor(is_well_treated, room)
			return

	if not is_instance_valid(room):
		return

	room.occupy(npc)
	npc.Animator.set_sleeping(true)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	npc.global_position = room.get_bed_position_for(npc)

	var rest_duration: float = WELL_TREATED_REST_DURATION if is_well_treated else BADLY_TREATED_REST_DURATION
	_narrative = ["Resting...", "Recovering...", "Hanging in there..."].pick_random()
	await progress(rest_duration)

	if is_instance_valid(npc):
		npc.Animator.set_sleeping(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)

	if is_instance_valid(room):
		room.release(npc)
		npc.global_position = room.get_center_floor_position()

	_apply_recovery(is_well_treated)

func _rest_on_floor(is_well_treated: bool, ward: RoomSickWard) -> void:
	if is_instance_valid(ward):
		_narrative = ["Heading to the ward...", "No beds, but going anyway..."].pick_random()
		await move(ward.get_random_floor_position())
	_narrative = ["Collapsed on the floor...", "Resting where they fell...", "No bed available..."].pick_random()
	npc.Animator.set_sleeping(true)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)

	var rest_duration: float = WELL_TREATED_REST_DURATION if is_well_treated else BADLY_TREATED_REST_DURATION
	await progress(rest_duration * 2.0)

	if is_instance_valid(npc):
		npc.Animator.set_sleeping(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)

	_apply_recovery(is_well_treated)

func _apply_recovery(is_well_treated: bool) -> void:
	if not is_instance_valid(npc) or npc.Status == null:
		return
	npc.Status.clear_status(Enum.NpcStatus.WELL_TREATED)
	npc.Status.clear_status(Enum.NpcStatus.BADLY_TREATED)

	if is_well_treated:
		npc.restore_energy()
		InjuryHandler.collect_recovery_payment(npc)
		return

	var recovery_chance: float = npc.Traits.get_bad_treatment_recovery_chance()
	if randf() < recovery_chance:
		npc.restore_energy()
		InjuryHandler.collect_recovery_payment(npc)
	else:
		npc.Status.set_status(Enum.NpcStatus.INJURED)
		InjuryHandler.on_npc_injured(npc)

func _find_any_sick_ward() -> RoomSickWard:
	var rooms: Array = get_all_rooms_of_type_ordered_by_distance(RoomSickWard)
	for room: RoomSickWard in rooms:
		if room.accepts_patient(npc):
			return room
	return null

func _find_available_sick_ward() -> RoomSickWard:
	for candidate: RoomBase in get_all_rooms_of_type_ordered_by_distance(RoomSickWard):
		var ward := candidate as RoomSickWard
		if ward.accepts_patient(npc) and not ward.is_full():
			return ward
	return null

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(npc):
		if npc.Animator != null and npc.Animator.is_sleeping:
			npc.Animator.set_sleeping(false)
			npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		if is_instance_valid(room) and npc in room.current_guests:
			room.release(npc)
	return super.stop_loop()
