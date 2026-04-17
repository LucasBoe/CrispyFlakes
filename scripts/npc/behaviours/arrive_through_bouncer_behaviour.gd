extends Behaviour
class_name ArriveThroughBouncerBehaviour

func loop():
	_narrative = ["Heading inside...", "Coming in from outside...", "Walking up to the saloon..."].pick_random()
	npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)
	var bouncer_room := get_closest_room_of_type(RoomBouncer) as RoomBouncer
	if bouncer_room == null:
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		return

	_narrative = ["Waiting to be let in...", "Lining up at the door...", "Hoping they get in..."].pick_random()
	await move(bouncer_room.get_center_floor_position())
