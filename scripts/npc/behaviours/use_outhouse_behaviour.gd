extends Behaviour
class_name UseOuthouseBehaviour

var outhouse : RoomOuthouse

func loop():

	outhouse = get_random_room_of_type(RoomOuthouse)

	if not outhouse:
		await _pee_outside()
		return

	if outhouse.is_full():
		npc.Needs.satisfaction.strength -= .3
		npc.notify(UiNotifications.ICON_MINUS_2)
		return

	await move(outhouse.get_random_floor_position())

	while outhouse.is_used_by_other_then(npc):
		await end_of_frame()

	await move(outhouse.get_center_floor_position())
	if is_instance_valid(outhouse):
		npc.Animator.hide()
		outhouse.user = npc
		await progress(3, outhouse.progressBar)
		npc.Animator.show()

		if is_instance_valid(outhouse):
			outhouse.user = null
			outhouse.uses += 1

	npc.needs_to_pee = 0.0
	npc.Needs.satisfaction.strength += .3
	npc.notify(UiNotifications.ICON_PLUS_2)

func _pee_outside() -> void:
	var npc_grid_x = Global.Building.round_room_index_from_global_position(npc.global_position).x
	var grid_offset = -1
	while Global.Building.has_any_rooms_on_x(npc_grid_x + grid_offset):
		grid_offset = sign(grid_offset) * (abs(grid_offset) + 1) * -1
	var target_x = (npc_grid_x + grid_offset) * 48 + 24 + randf_range(-24, 24)
	await move(Vector2(target_x, 0))
	npc.Animator.is_peeing = true
	await pause(2)
	npc.Animator.is_peeing = false
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PEE)
	npc.needs_to_pee = 0.0
