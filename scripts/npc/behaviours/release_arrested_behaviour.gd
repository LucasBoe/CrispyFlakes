extends Behaviour
class_name ReleaseArrestedBehaviour

func loop() -> void:
	_narrative = ["Uncuffing the prisoners...", "Setting them free...", "Releasing the arrested..."].pick_random()
	while true:
		var to_free := _get_next_arrested()
		if not is_instance_valid(to_free):
			break
		_narrative = ["Going to release them...", "Heading over to uncuff..."].pick_random()
		await move(to_free)
		if not is_instance_valid(to_free):
			continue
		to_free.Behaviour.set_behaviour(IdleBehaviour)

	_narrative = ["Heading out...", "Job done.", "Leaving them to it..."].pick_random()
	await move(Global.LEAVE_POSITION)
	if is_instance_valid(npc):
		npc.destroy()

func _get_next_arrested() -> NPCGuest:
	return Util.get_closest(_get_all_arrested(), npc.global_position)

func _get_all_arrested() -> Array:
	var result: Array = []
	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
		if guest.Behaviour.behaviour_instance is ArrestedBehaviour:
			result.append(guest)
	return result
