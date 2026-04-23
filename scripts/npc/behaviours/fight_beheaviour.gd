extends NeedBehaviour
class_name FightBehaviour

var fight: Fight = null
var arrived_at_room: bool = false

func loop():
	if npc is NPCWorker:
		_narrative = ["Responding to a fight!", "There's trouble!", "On my way!"].pick_random()
	else:
		_narrative = ["Starting a brawl!", "Looking for trouble!", "Feeling feisty!", "Someone's gonna get it!", "Time to scrap!"].pick_random()

	if fight == null:
		fight = FightHandler.get_or_create_fight(npc)

	if fight == null or fight.room == null:
		return

	await move(fight.room)
	arrived_at_room = true

	while not fight.has_started and not fight.is_over:
		#this is also where the npc should move to it's current fight target
		await end_of_frame()

	npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)

	if npc is NPCWorker:
		_narrative = ["In the fight!", "Restoring order!", "Breaking it up!", "Nobody gets hurt on my watch!", "Settle down!"].pick_random()
	else:
		_narrative = ["Throwing punches!", "Eat knuckles!", "Come on then!", "Y'all asked for this!", "Yeehaw!"].pick_random()

	while not fight.is_over:
		await end_of_frame()

	if npc is NPCWorker:
		(npc as NPCWorker).resume_job_behaviour()

func stop_loop():
	npc.Tint.remove_tint_for(self)
	return super.stop_loop()
