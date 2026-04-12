extends NeedBehaviour
class_name IdleBehaviour

var _notification

static func get_probability_by_needs(needs):
	return needs.Energy.strength * .5 * (1.0 - needs.Money.strength)

func start_loop():
	_narrative = ["Wandering around...", "Killing time...", "Looking around idly...", "Just hanging about..."].pick_random()
	if npc is NPCWorker:
		_notification = UiNotifications.create_notification_dynamic("no job", npc, Vector2(0,-32), null, Color.ORANGE, INF)
	else:
		_notification = UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32), null, Color.BLACK, INF)

func stop_loop() -> BehaviourSaveData:
	UiNotifications.try_kill(_notification)
	return BehaviourSaveData.new(get_script())

func loop():
	await pause(3)
	await move(npc.Navigation.get_random_target(), 12)
