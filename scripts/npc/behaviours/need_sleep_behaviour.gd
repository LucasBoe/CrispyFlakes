extends NeedBehaviour
class_name NeedSleepBehaviour

var bed: RoomBed

static func get_probability_by_needs(needs: NeedsModule):
	return 1.0 - needs.Energy.strength

func loop():
	_narrative = ["Dead tired...", "Can barely keep their eyes open...", "Exhausted..."].pick_random()
	bed = _find_available_bed()

	if bed == null:
		npc.Needs.satisfaction.strength -= 0.3
		npc.notify(UiNotifications.ICON_MINUS_1)
		await pause(2)
		return

	_narrative = ["Looking for a bed...", "Searching for somewhere to sleep...", "Heading to the bunkhouse..."].pick_random()
	await move(bed.get_random_floor_position())

	while is_instance_valid(bed) and bed.is_used_by_other_then(npc):
		await end_of_frame()

	if not is_instance_valid(bed) or bed.needs_cleaning:
		return

	await move(bed.get_center_floor_position())

	if not is_instance_valid(bed) or bed.needs_cleaning:
		return

	_narrative = ["Sleeping...", "Out like a light...", "Snoring away..."].pick_random()
	bed.occupy(npc)
	npc.Animator.set_sleeping(true)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_ROOM_CONTENT)
	npc.global_position = bed.get_sleep_position_for(npc)

	await progress(RoomBed.SLEEP_DURATION)

	if is_instance_valid(npc):
		npc.Animator.set_sleeping(false)

	if is_instance_valid(bed):
		bed.release(npc)
		npc.global_position = bed.get_center_floor_position()
		ResourceHandler.add_animated(Enum.Resources.MONEY, bed.get_sleep_price(), bed.get_center_position(), Vector2i(bed.x, bed.y))

	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	npc.Needs.Energy.strength = minf(1.0, npc.Needs.Energy.strength + 0.8)
	npc.Needs.satisfaction.strength = 0.7

func _find_available_bed() -> RoomBed:
	for candidate: RoomBed in get_all_rooms_of_type_ordered_by_distance(RoomBed):
		if candidate.is_available_for(npc):
			return candidate
	return null

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(npc):
		npc.Animator.set_sleeping(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	if is_instance_valid(bed) and npc in bed.current_guests:
		bed.release(npc)
	return super.stop_loop()
