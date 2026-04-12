extends Behaviour
class_name KnockedOutBehaviour

const DURATION = 60.0

var notification_instance
var time_remaining: float = DURATION

func start_loop():
	_narrative = ["Down for the count...", "Out cold...", "Seeing stars..."].pick_random()
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_KNOCKED_OUT, true)

func loop():
	time_remaining = DURATION
	while time_remaining > 0.0:
		time_remaining -= npc.get_process_delta_time()
		await end_of_frame()

func stop_loop() -> BehaviourSaveData:
	UiNotifications.try_kill(notification_instance)
	return super.stop_loop()
