extends NeedBehaviour
class_name NeedLeaveBehaviour

static func get_probability_by_needs(needs : NeedsModule):	
	return (1.0 - needs.Money.strength) * (1.0 - needs.Mood.strength)
	
func loop():
	_narrative = ["Heading out...", "Had enough for one day...", "Calling it a night..."].pick_random()
	if npc is NPCGuest and npc.has_meta("horse"):
		npc.force_behaviour(LeaveOnHorseBehaviour)
		return

	if npc is NPCGuest:
		Global.NPCSpawner.on_guest_destroy(npc)

	var bouncer_room := get_closest_room_of_type(RoomBouncer) as RoomBouncer
	if bouncer_room != null:
		await move(bouncer_room.get_center_floor_position())
		npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)

	await move(Global.LEAVE_POSITION)
	npc.destroy()
