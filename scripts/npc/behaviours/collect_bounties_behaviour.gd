extends Behaviour
class_name CollectBountiesBehaviour

func loop():
	_narrative = ["Rounding up the criminals...", "Here for the bounty...", "Looking for the arrested..."].pick_random()
	#var prisoners = _get_all_prisoners()
	var arrested = _get_all_arrested()

	for to_take_away: NPCGuest in arrested:
		if not is_instance_valid(to_take_away):
			continue

		_narrative = ["Collecting a bounty...", "Going to pick them up...", "Taking them in..."].pick_random()
		await move(to_take_away)

		if not is_instance_valid(to_take_away):
			continue

		_collect_bounty(to_take_away)

		var follow_b := to_take_away.force_behaviour(FollowSheriffBehaviour) as FollowSheriffBehaviour
		follow_b.sheriff = npc

	# Walk out
	_narrative = ["Heading out...", "Job done.", "Taking them away..."].pick_random()
	await move(Global.LEAVE_POSITION)

	if is_instance_valid(npc):
		npc.destroy()
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

func _collect_bounty(prisoner: NPCGuest):
	if prisoner.look_info == null:
		return
	var bounty: int = BountyHandler.npc_bounties.get(prisoner.look_info, 0)
	var fine: int = BountyHandler.npc_fight_fines.get(prisoner, 0)
	if bounty + fine > 0:
		
		ResourceHandler.add_animated(Enum.Resources.MONEY, bounty + fine, npc.global_position + Vector2(0, 12))
		ResourceHandler.change_money(bounty + fine)
		BountyHandler.npc_bounties.erase(prisoner.look_info)
		BountyHandler.npc_fight_fines.erase(prisoner)
	else:
		#add variant where prisoners without fine or bounty are just freed
		return
