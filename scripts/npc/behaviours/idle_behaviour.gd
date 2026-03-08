extends NeedBehaviour
class_name IdleBehaviour

static func get_probability_by_needs(needs):
	return needs.Energy.strength * .5 * (1.0 - needs.Money.strength)

func loop():
	await pause(3)
	await move(npc.Navigation.get_random_target(), 12)
	if npc is NPCWorker:
		UiNotifications.create_notification_dynamic("no job", npc, Vector2(0,-32), null, Color.ORANGE)
	else:
		UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32))
