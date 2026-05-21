extends Behaviour
class_name CollectBountiesBehaviour

func loop():
	_narrative = ["Rounding up the criminals...", "Here for the bounty...", "Looking for the arrested..."].pick_random()
	DebugLog.info("[Sheriff]", npc, "starting bounty collection")
	while true:
		var to_take_away := _get_next_collectible_guest()
		if not is_instance_valid(to_take_away):
			break

		_narrative = ["Collecting a bounty...", "Going to pick them up...", "Taking them in..."].pick_random()
		DebugLog.info("[Sheriff]", npc, "target selected", to_take_away)
		await move(to_take_away)

		if not is_instance_valid(to_take_away):
			continue

		var current_behaviour := to_take_away.Behaviour.behaviour_instance
		if current_behaviour is ArrestedBehaviour:
			if _has_penalty(to_take_away):
				DebugLog.info("[Sheriff]", npc, "collect arrested target", to_take_away, "payout", _get_total_penalty(to_take_away))
				_collect_bounty(to_take_away)
				var follow_b := to_take_away.force_behaviour(FollowSheriffBehaviour) as FollowSheriffBehaviour
				follow_b.sheriff = npc
			else:
				DebugLog.info("[Sheriff]", npc, "release arrested target without penalty", to_take_away)
				to_take_away.Behaviour.set_behaviour(IdleBehaviour)
			continue

		if _can_collect_free_guest(to_take_away):
			DebugLog.info("[Sheriff]", npc, "start arrest fight for free target", to_take_away, "payout", _get_total_penalty(to_take_away))
			var arrest_fight := FightHandler.create_defense_fight(to_take_away, npc)
			if arrest_fight != null:
				return

	_narrative = ["Heading out...", "Job done.", "Taking them away..."].pick_random()
	DebugLog.info("[Sheriff]", npc, "leaving town")
	await move(Global.LEAVE_POSITION)

	if is_instance_valid(npc):
		npc.destroy()

func _get_next_collectible_guest() -> NPCGuest:
	var collectible := _get_all_collectible_guests()
	if collectible.is_empty():
		DebugLog.warn("[Sheriff]", npc, "no collectible guests found", _get_collectible_debug_snapshot())
		return null
	var selected := Util.get_closest(collectible, npc.global_position) as NPCGuest
	DebugLog.info("[Sheriff]", npc, "collectible candidates", _get_collectible_debug_snapshot(), "selected", selected)
	return selected

func _get_all_collectible_guests() -> Array:
	var result: Array[NPCGuest] = []
	for guest : NPCGuest in Global.NPCSpawner.get_live_guests():
		if not is_instance_valid(guest):
			continue
		if _is_collectible_guest(guest):
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
	return _get_total_penalty(guest) > 0

func _get_total_penalty(guest: NPCGuest) -> int:
	var bounty: int = BountyHandler.npc_bounties.get(guest.look_info, 0) if guest.look_info != null else 0
	var fine: int = BountyHandler.npc_fight_fines.get(guest, 0)
	return bounty + fine

func _is_collectible_guest(guest: NPCGuest) -> bool:
	if guest == null or not is_instance_valid(guest) or guest.Behaviour == null:
		return false
	var current_behaviour := guest.Behaviour.behaviour_instance
	if current_behaviour is ArrestedBehaviour:
		return true
	return _can_collect_free_guest(guest)

func _can_collect_free_guest(guest: NPCGuest) -> bool:
	return ConflictResponseHandler.can_be_arrested(guest) and _has_penalty(guest)

func _get_collectible_debug_snapshot() -> String:
	if Global.NPCSpawner == null:
		return "<no spawner>"
	var parts := PackedStringArray()
	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
		if not is_instance_valid(guest):
			continue
		var behaviour_name := "none"
		if guest.Behaviour != null and guest.Behaviour.behaviour_instance != null:
			behaviour_name = guest.Behaviour.behaviour_instance.get_script().resource_path.get_file()
		var state := "ignored"
		if guest.Behaviour != null and guest.Behaviour.behaviour_instance is ArrestedBehaviour:
			state = "arrested"
		elif _can_collect_free_guest(guest):
			state = "wanted"
		var bounty = BountyHandler.get_official_bounty_for(guest)
		var fine = BountyHandler.get_fight_fine_for(guest)
		parts.append("%s(%s,b=%s,f=%s,%s)" % [guest.get_debug_display_name(), behaviour_name, str(bounty), str(fine), state])
	return "; ".join(parts)

func _collect_bounty(prisoner: NPCGuest):
	var bounty: int = BountyHandler.npc_bounties.get(prisoner.look_info, 0) if prisoner.look_info != null else 0
	var fine: int = BountyHandler.npc_fight_fines.get(prisoner, 0)
	var payout := bounty + fine
	if payout > 0:
		ResourceHandler.add_animated(Enum.Resources.MONEY, payout, npc.global_position + Vector2(0, 12))
		ResourceHandler.change_money(payout)
	if prisoner.look_info != null:
		BountyHandler.npc_bounties.erase(prisoner.look_info)
	BountyHandler.clear_fine(prisoner)
