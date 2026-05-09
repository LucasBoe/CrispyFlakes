extends Behaviour
class_name CollectBountiesBehaviour

func loop():
	_narrative = ["Rounding up the criminals...", "Here for the bounty...", "Looking for the arrested..."].pick_random()
	# Keep checking for newly arrested guests until none are left.
	while true:
		var to_take_away := _get_next_arrested()
		if not is_instance_valid(to_take_away):
			break

		_narrative = ["Collecting a bounty...", "Going to pick them up...", "Taking them in..."].pick_random()
		await move(to_take_away)

		if not is_instance_valid(to_take_away):
			continue

		if _has_penalty(to_take_away):
			_collect_bounty(to_take_away)
			var follow_b := to_take_away.force_behaviour(FollowSheriffBehaviour) as FollowSheriffBehaviour
			follow_b.sheriff = npc
		else:
			to_take_away.Behaviour.set_behaviour(IdleBehaviour)

	# Walk out
	_narrative = ["Heading out...", "Job done.", "Taking them away..."].pick_random()
	await move(Global.LEAVE_POSITION)

	if is_instance_valid(npc):
		npc.destroy()

func _get_next_arrested() -> NPCGuest:
	for guest : NPCGuest in Global.NPCSpawner.guests:
		if is_instance_valid(guest) and guest.Behaviour.behaviour_instance is ArrestedBehaviour:
			return guest
	return null

func _get_all_arrested() -> Array:
	var result = []
	for guest : NPCGuest in Global.NPCSpawner.guests:
		if is_instance_valid(guest) and guest.Behaviour.behaviour_instance is ArrestedBehaviour:
			result.append(guest)
	return result

func _get_all_prisoners() -> Array:
	var result = []
	for room: RoomPrison in Building.query.all_rooms_of_type(RoomPrison):
		for prisoner in room.prisoners.duplicate():
			if is_instance_valid(prisoner) and prisoner is NPCGuest:
				result.append(prisoner)
	return result

func _has_penalty(guest: NPCGuest) -> bool:
	var bounty: int = BountyHandler.npc_bounties.get(guest.look_info, 0) if guest.look_info != null else 0
	var fine: int = BountyHandler.npc_fight_fines.get(guest, 0)
	return bounty + fine > 0

func _collect_bounty(prisoner: NPCGuest):
	if prisoner.look_info == null:
		return
	var bounty: int = BountyHandler.npc_bounties.get(prisoner.look_info, 0)
	var fine: int = BountyHandler.npc_fight_fines.get(prisoner, 0)
	ResourceHandler.add_animated(Enum.Resources.MONEY, bounty + fine, npc.global_position + Vector2(0, 12))
	ResourceHandler.change_money(bounty + fine)
	BountyHandler.npc_bounties.erase(prisoner.look_info)
	BountyHandler.npc_fight_fines.erase(prisoner)
