extends Behaviour
class_name ArriveThroughBouncerBehaviour

func loop():
	_narrative = ["Heading inside...", "Coming in from outside...", "Walking up to the saloon..."].pick_random()
	npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)
	var bouncer_room := get_closest_room_of_type(RoomBouncer) as RoomBouncer
	if bouncer_room == null or not bouncer_room.has_active_bouncer():
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		return

	_narrative = ["Waiting to be let in...", "Lining up at the door...", "Hoping they get in..."].pick_random()
	await move(bouncer_room.get_center_floor_position())
	_narrative = ["Being checked in...", "Going through security...", "Getting frisked..."].pick_random()
	await _frisk(bouncer_room)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)

func _frisk(bouncer_room: RoomBouncer) -> void:
	await progress(1.0)

	var bounty = BountyHandler.get_official_bounty_for(npc)
	if bounty == null:
		return

	var best_intelligence := 0.0
	for bouncer in bouncer_room.assigned_bouncers:
		if is_instance_valid(bouncer):
			best_intelligence = maxf(best_intelligence, bouncer.intelligence)

	if best_intelligence == 0.0:
		return

	if randf() < best_intelligence:
		(npc as NPCGuest).is_known_fugitive = true
