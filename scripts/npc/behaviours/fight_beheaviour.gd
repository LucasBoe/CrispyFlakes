extends NeedBehaviour
class_name FightBehaviour

var energy = 1.0
var fight : Fight = null

var notification_instance

func start_loop(data : BehaviourSaveData):
	super.start_loop(data)
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_FIGHT, true)
	
func loop():
	fight = FightHandler.get_or_create_fight(npc)
	while fight.energy > 0.0:
		await move(fight.room.get_random_floor_position())
		npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)
		await pause(2)

func stop_loop():
	npc.Tint.remove_tint_for(self)
	UiNotifications.try_kill(notification_instance)
	return super.stop_loop()
