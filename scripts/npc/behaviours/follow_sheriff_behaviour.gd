extends Behaviour
class_name FollowSheriffBehaviour

var sheriff: NPC = null

func loop():
	npc.Animator.handcuffs.show()

	while is_instance_valid(sheriff):
		await move(sheriff)

	# Sheriff left — follow out
	await move(Vector2(-256, 0))

	if npc is NPCGuest:
		Global.NPCSpawner.on_guest_destroy(npc)
	npc.destroy()

func stop_loop() -> BehaviourSaveData:
	npc.Animator.handcuffs.hide()
	return super.stop_loop()
