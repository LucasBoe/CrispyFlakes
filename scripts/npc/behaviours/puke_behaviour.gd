extends Behaviour
class_name PukeBehaviour

func loop():
	npc.Animator.is_puking = true
	await pause(1.5)
	npc.Animator.is_puking = false
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PUKE)
	npc.Needs.drunkenness.strength -= 0.2
	npc.Needs.satisfaction.strength -= 0.1
	npc.notify(UiNotifications.ICON_MINUS_2)
