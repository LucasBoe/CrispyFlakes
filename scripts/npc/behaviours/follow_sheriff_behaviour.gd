extends Behaviour
class_name FollowSheriffBehaviour

var sheriff: NPC = null

func loop():
	_narrative = ["Following the sheriff...", "Being escorted out...", "Going quietly..."].pick_random()
	npc.Animator.handcuffs.show()
	DebugLog.info("FollowSheriffBehaviour handcuffs shown", npc, "sheriff=", sheriff)
	npc.Animator.set_escort_target(sheriff)

	while is_instance_valid(sheriff):
		await move(sheriff)

	# Sheriff left — follow out
	await move(Global.LEAVE_POSITION)

	if npc is NPCGuest:
		Global.NPCSpawner.on_guest_destroy(npc)
	npc.destroy()

func stop_loop() -> BehaviourSaveData:
	DebugLog.info("FollowSheriffBehaviour stop", npc, "sheriff=", sheriff)
	npc.Animator.handcuffs.hide()
	npc.Animator.clear_escort_target()
	return super.stop_loop()
