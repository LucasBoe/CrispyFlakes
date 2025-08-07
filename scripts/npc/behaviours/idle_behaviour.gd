extends NeedBehaviour
class_name IdleBehaviour

static func get_probability_by_needs(needs):
	return needs.Energy.Strength * .5 * (1.0 - needs.Money.Strength)

func loop():
	while isRunning:
		await pause(3)
		await move(npc.Navigation.get_random_target())
		UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32))
