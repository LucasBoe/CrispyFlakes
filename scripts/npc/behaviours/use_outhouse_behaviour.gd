extends Behaviour
class_name UseOuthouseBehaviour

var outhouse : RoomOuthouse
var toilet : RoomToilet
var _hidden_in_toilet := false

func loop():
	_narrative = ["Nature calls...", "Can't hold it much longer...", "In a hurry..."].pick_random()
	toilet = _get_usable_toilet()
	if toilet != null:
		if await _use_toilet():
			return
		if stopped:
			return

	var blocked_toilet := _get_blocked_toilet()
	if blocked_toilet != null:
		RoomStatusHandler.notify(blocked_toilet, blocked_toilet.get_unusable_status_text(), Color.ORANGE, Building.room_data_water_tower.room_icon)

	outhouse = get_random_room_of_type(RoomOuthouse)

	if not outhouse:
		await _pee_outside()
		return

	if outhouse.is_full():
		npc.add_satisfaction(-0.3, "Outhouse Full")
		npc.notify(UiNotifications.ICON_MINUS_2)
		return

	_narrative = ["Heading to the outhouse...", "Making their way outside...", "In a real hurry now..."].pick_random()
	outhouse.join_queue(npc)
	await move(outhouse.get_queue_position(npc))

	while not (outhouse.is_at_front(npc) and not outhouse.is_occupied()):
		if stopped or not is_instance_valid(outhouse):
			break
		_narrative = "Waiting for the outhouse..."
		var target_pos: Vector2 = outhouse.get_queue_position(npc)
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	if stopped or not is_instance_valid(outhouse):
		return

	if outhouse.is_full():
		outhouse.leave_queue(npc)
		npc.add_satisfaction(-0.3, "Outhouse Full")
		npc.notify(UiNotifications.ICON_MINUS_2)
		return

	outhouse.leave_queue(npc)
	outhouse.user = npc

	_narrative = ["Taking care of business...", "Doing what they gotta do...", "Finally made it..."].pick_random()
	await move(outhouse.get_center_floor_position())
	if is_instance_valid(outhouse):
		SoundPlayer.play_outhouse_door(outhouse.global_position)
		await outhouse.play_open_animation()
		npc.Animator.hide()
		await outhouse.play_close_animation()

		await progress(7)

		if is_instance_valid(outhouse):
			SoundPlayer.play_outhouse_door(outhouse.global_position)
			await outhouse.play_open_animation()
		npc.Animator.show()
		
		if is_instance_valid(outhouse):
			await outhouse.play_close_animation()

		if is_instance_valid(outhouse):
			outhouse.user = null
			outhouse.uses += 1

	npc.needs_to_pee = 0.0
	add_satisfaction(0.3, "Used Outhouse")

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(toilet):
		toilet.leave_queue(npc)
		toilet.release_stall(npc)
	if _hidden_in_toilet:
		npc.Animator.show()
		_hidden_in_toilet = false

	if is_instance_valid(outhouse):
		outhouse.leave_queue(npc)
		if outhouse.user == npc:
			outhouse.user = null
	return super.stop_loop()

func _get_usable_toilet() -> RoomToilet:
	var reachable = npc.Navigation.get_reachable_rooms()
	var toilets = Building.query.all_rooms_of_type(RoomToilet, reachable)
	toilets = toilets.filter(func(t: RoomToilet): return t.has_working_water_supply())
	if toilets.is_empty():
		return null
	return toilets.pick_random()

func _get_blocked_toilet() -> RoomToilet:
	var reachable = npc.Navigation.get_reachable_rooms()
	var toilets = Building.query.all_rooms_of_type(RoomToilet, reachable)
	toilets = toilets.filter(func(t: RoomToilet): return not t.has_working_water_supply())
	if toilets.is_empty():
		return null
	return toilets.pick_random()

func _use_toilet() -> bool:
	_narrative = ["Heading to the toilet...", "Making for the indoor stalls...", "Looking for a stall..."].pick_random()
	toilet.join_queue(npc)
	await move(toilet.get_queue_position(npc))

	if stopped or not is_instance_valid(toilet):
		return false

	while is_instance_valid(toilet) and not toilet.can_enter(npc):
		if stopped or not is_instance_valid(toilet):
			return false
		if not toilet.has_working_water_supply():
			toilet.leave_queue(npc)
			RoomStatusHandler.notify(toilet, toilet.get_unusable_status_text(), Color.ORANGE, Building.room_data_water_tower.room_icon)
			return false
		_narrative = "Waiting for a toilet stall..."
		var target_pos: Vector2 = toilet.get_queue_position(npc)
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	if stopped or not is_instance_valid(toilet):
		return false

	if not toilet.reserve_stall(npc):
		toilet.leave_queue(npc)
		RoomStatusHandler.notify(toilet, toilet.get_unusable_status_text(), Color.ORANGE, Building.room_data_water_tower.room_icon)
		return false

	_narrative = ["Using the indoor toilet...", "Taking care of business...", "Finally got a stall..."].pick_random()
	await move(toilet.get_stall_position(npc))
	if stopped or not is_instance_valid(toilet):
		return false

	npc.Animator.hide()
	_hidden_in_toilet = true
	await progress(RoomToilet.USE_DURATION)
	if _hidden_in_toilet:
		npc.Animator.show()
		_hidden_in_toilet = false
	if is_instance_valid(toilet):
		toilet.release_stall(npc)

	if stopped:
		return false

	npc.needs_to_pee = 0.0
	add_satisfaction(0.35, "Used Toilet")
	return true

func _pee_outside() -> void:
	_narrative = ["Finding a spot outside...", "Looking for some privacy...", "Sneaking behind the building..."].pick_random()
	var npc_grid_x = Building.round_room_index_from_global_position(npc.global_position).x
	var grid_offset = -1
	while Building.has_any_rooms_on_x(npc_grid_x + grid_offset):
		grid_offset = sign(grid_offset) * (abs(grid_offset) + 1) * -1
	var target_x = (npc_grid_x + grid_offset) * 48 + 24 + randf_range(-24, 24)
	await move(Vector2(target_x, 0))
	_narrative = ["Relieving themselves outside...", "Taking care of it behind the bushes...", "Nature's calling answered..."].pick_random()
	npc.Animator.is_peeing = true
	SoundPlayer.play_piss(npc.global_position)
	await pause(2)
	npc.Animator.is_peeing = false
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PEE)
	npc.needs_to_pee = 0.0
