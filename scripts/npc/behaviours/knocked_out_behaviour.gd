extends Behaviour
class_name KnockedOutBehaviour

const DURATION = 60.0

var notification_instance

func start_loop():
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_KNOCKED_OUT, true)

func loop():
	await pause(DURATION)

func stop_loop() -> BehaviourSaveData:
	UiNotifications.try_kill(notification_instance)
	return super.stop_loop()
