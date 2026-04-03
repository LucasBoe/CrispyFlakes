extends NeedBehaviour
class_name FightBehaviour

var energy = 1.0
var fight : Fight = null
var arrived_at_roon = false

var notification_instance

func start_loop():
	super.start_loop()
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_FIGHT, true)
	
func loop():
	if fight == null:
		fight = FightHandler.get_or_create_fight(npc)
	print("[FIGHT_BEHAVIOUR] starting loop, bar:", fight.bar, " npc:", npc.name)
	while fight.bar > 0.0 and fight.bar < 1.0:
		await move(fight.room.get_random_floor_position())
		arrived_at_roon = true
		print("[FIGHT_BEHAVIOUR] arrived at room, bar:", fight.bar)
		npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)
		await pause(2)
	print("[FIGHT_BEHAVIOUR] loop exited, bar:", fight.bar)

func stop_loop():
	npc.Tint.remove_tint_for(self)
	UiNotifications.try_kill(notification_instance)
	return super.stop_loop()
