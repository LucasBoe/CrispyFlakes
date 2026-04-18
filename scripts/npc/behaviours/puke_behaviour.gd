extends Behaviour
class_name PukeBehaviour

func loop():
	_narrative = ["Feeling sick...", "About to hurl...", "Shouldn't have had that last one..."].pick_random()
	npc.Animator.is_puking = true
	
	await pause(1.5)
	npc.Animator.is_puking = false
	SoundPlayer.play_puke(npc.global_position)
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PUKE)
	npc.Needs.drunkenness.strength -= 0.2
