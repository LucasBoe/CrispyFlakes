extends NeedBehaviour
class_name NeedPeeBehaviour

const ROOM_RELIEF_SATISFACTION := 0.35
const OUTSIDE_RELIEF_DURATION := 2.0

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

	outhouse = _get_usable_outhouse()
	if outhouse != null:
		if await _use_outhouse():
			return
		if stopped:
			return

	await _pee_outside()

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(toilet):
		toilet.leave_queue(npc)
		toilet.release_stall(npc)
	if _hidden_in_toilet:
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		_hidden_in_toilet = false

	if is_instance_valid(outhouse):
		outhouse.leave_queue(npc)
		if outhouse.user == npc:
			npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
			outhouse.user = null
	return super.stop_loop()

func _get_usable_toilet() -> RoomToilet:
	var reachable = npc.Navigation.get_reachable_rooms()
	var toilets = Building.query.all_rooms_of_type(RoomToilet, reachable)
	toilets = toilets.filter(func(t: RoomToilet): return t.has_working_water_supply())
	if toilets.is_empty():
		return null
	return toilets.pick_random()

func _get_usable_outhouse() -> RoomOuthouse:
	var reachable = npc.Navigation.get_reachable_rooms()
	var outhouses = Building.query.all_rooms_of_type(RoomOuthouse, reachable)
	outhouses = outhouses.filter(func(o: RoomOuthouse): return not o.is_full())
	if outhouses.is_empty():
		return null
	return outhouses.pick_random()

func _use_outhouse() -> bool:
	if outhouse.is_full():
		_handle_full_outhouse()
		return false

	_narrative = ["Heading to the outhouse...", "Making their way outside...", "In a real hurry now..."].pick_random()
	outhouse.join_queue(npc)

	if not await _wait_for_queue_turn(
		outhouse,
		"Waiting for the outhouse...",
		func(): return outhouse.get_queue_position(npc),
		func(): return outhouse.is_at_front(npc) and not outhouse.is_occupied()
	):
		return false

	if outhouse.is_full():
		outhouse.leave_queue(npc)
		_handle_full_outhouse()
		return false

	outhouse.leave_queue(npc)
	outhouse.user = npc

	_narrative = ["Taking care of business...", "Doing what they gotta do...", "Finally made it..."].pick_random()
	await move(outhouse.get_center_floor_position())
	if stopped or not is_instance_valid(outhouse):
		return false

	SoundPlayer.play_outhouse_door(outhouse.global_position)
	await outhouse.play_open_animation()
	npc.Animator.set_z(Enum.ZLayer.NPC_IN_OUTHOUSE)
	await outhouse.play_close_animation()

	await progress(RoomOuthouse.USE_DURATION)

	if is_instance_valid(outhouse):
		SoundPlayer.play_outhouse_door(outhouse.global_position)
		await outhouse.play_open_animation()
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)

	if is_instance_valid(outhouse):
		await outhouse.play_close_animation()
		outhouse.user = null
		outhouse.uses += 1
		return _finish_relief(outhouse, "Used Bathroom", ROOM_RELIEF_SATISFACTION)

	return false

func _use_toilet() -> bool:
	_narrative = ["Heading to the toilet...", "Making for the indoor stalls...", "Looking for a stall..."].pick_random()
	toilet.join_queue(npc)

	if not await _wait_for_queue_turn(
		toilet,
		"Waiting for a toilet stall...",
		func(): return toilet.get_queue_position(npc),
		func(): return toilet.can_enter(npc),
		_ensure_toilet_water_supply
	):
		return false

	if not toilet.reserve_stall(npc):
		toilet.leave_queue(npc)
		return false

	_narrative = ["Using the indoor toilet...", "Taking care of business...", "Finally got a stall..."].pick_random()
	await move(toilet.get_stall_position(npc))
	if stopped or not is_instance_valid(toilet):
		return false

	var stall_index: int = toilet.get_stall_index(npc)
	SoundPlayer.play_outhouse_door(toilet.global_position)
	await toilet.play_open_animation(stall_index)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	_hidden_in_toilet = true
	await toilet.play_close_animation(stall_index)

	await progress(RoomToilet.USE_DURATION)

	if is_instance_valid(toilet):
		SoundPlayer.play_outhouse_door(toilet.global_position)
		await toilet.play_open_animation(stall_index)
	if _hidden_in_toilet:
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		_hidden_in_toilet = false
	if is_instance_valid(toilet):
		await toilet.play_close_animation(stall_index)
		toilet.release_stall(npc)
		return _finish_relief(toilet, "Used Bathroom", ROOM_RELIEF_SATISFACTION)

	return false

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
	await pause(OUTSIDE_RELIEF_DURATION)
	npc.Animator.is_peeing = false
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PEE)
	_finish_relief()

func _wait_for_queue_turn(room: Node, waiting_narrative: String, get_queue_position: Callable, can_enter: Callable, on_wait_tick: Callable = Callable()) -> bool:
	await move(get_queue_position.call())
	if stopped or not is_instance_valid(room):
		return false

	while is_instance_valid(room) and not can_enter.call():
		if stopped or not is_instance_valid(room):
			return false
		if not on_wait_tick.is_null() and not on_wait_tick.call():
			return false

		_narrative = waiting_narrative
		var target_pos: Vector2 = get_queue_position.call()
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	return not stopped and is_instance_valid(room)

func _ensure_toilet_water_supply() -> bool:
	if toilet.has_working_water_supply():
		return true
	toilet.leave_queue(npc)
	return false

func _handle_full_outhouse() -> void:
	npc.add_satisfaction(-0.3, "Outhouse Full")
	npc.notify(UiNotifications.ICON_MINUS_2)

func _finish_relief(room: RoomBase = null, reason: String = "", satisfaction: float = 0.0) -> bool:
	npc.needs_to_pee = 0.0

	if room != null and room.get_service_price() > 0:
		ResourceHandler.add_animated(Enum.Resources.MONEY, room.get_service_price(), room.get_center_position(), Vector2i(room.x, room.y))

	if satisfaction > 0.0:
		add_satisfaction(satisfaction, reason)

	return not stopped
