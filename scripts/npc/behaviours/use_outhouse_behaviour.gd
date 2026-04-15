extends Behaviour
class_name UseOuthouseBehaviour

var outhouse : RoomOuthouse

func loop():
	_narrative = ["Nature calls...", "Can't hold it much longer...", "In a hurry..."].pick_random()
	outhouse = get_random_room_of_type(RoomOuthouse)

	if not outhouse:
		await _pee_outside()
		return

	if outhouse.is_full():
		npc.Needs.satisfaction.strength -= .3
		npc.notify(UiNotifications.ICON_MINUS_2)
		return

	_narrative = ["Heading to the outhouse...", "Making their way outside...", "In a real hurry now..."].pick_random()
	await move(outhouse.get_random_floor_position())

	while outhouse.is_used_by_other_then(npc):
		_narrative = "Waiting for the outhouse..."
		await end_of_frame()

	_narrative = ["Taking care of business...", "Doing what they gotta do...", "Finally made it..."].pick_random()
	await move(outhouse.get_center_floor_position())
	if is_instance_valid(outhouse):
		SoundPlayer.play_outhouse_door(outhouse.global_position)
		await outhouse.play_open_animation()
		npc.Animator.hide()
		await outhouse.play_close_animation()

		outhouse.user = npc
		await progress(3)

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
	add_satisfaction(0.3)

func _pee_outside() -> void:
	var bouncer_room := get_closest_room_of_type(RoomBouncer) as RoomBouncer
	if bouncer_room != null:
		_narrative = ["Stepping outside...", "Heading for the exit...", "Slipping out..."].pick_random()
		await move(bouncer_room.get_center_floor_position())
		npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)

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

	if bouncer_room != null and is_instance_valid(bouncer_room):
		await move(bouncer_room.get_center_floor_position())
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
