extends Behaviour
class_name LeaveOnHorseBehaviour

func loop():
	_narrative = ["Riding off...", "Galloping away...", "Heading back to the range..."].pick_random()
	if npc is NPCGuest:
		Global.NPCSpawner.on_guest_destroy(npc)

	var horse = npc.get_meta("horse", null)

	if is_instance_valid(horse):
		# Walk to the horse (wherever it ended up)
		await move(horse.global_position)

		# Pay tying fee if it was on a post
		var fee = horse.collect(npc)
		if fee > 0:
			await ResourceHandler.add_animated(Enum.Resources.MONEY, fee, horse.global_position)

	# Mount and ride off — bypass room pathfinder
	npc.Animator.set_riding(true)
	npc.Navigation.stop_navigation()
	npc.Navigation.is_moving = true
	var target = Vector2(-512, npc.global_position.y)
	var speed = 80.0
	while npc.global_position.distance_to(target) > 2.0:
		var dir = (target - npc.global_position).normalized()
		npc.global_position += dir * speed * npc.get_process_delta_time()
		npc.Animator.direction = dir
		horse.global_position = npc.global_position
		await end_of_frame()
	npc.Animator.direction = Vector2.ZERO
	npc.Navigation.is_moving = false

	if is_instance_valid(horse):
		horse.queue_free()

	npc.destroy()
