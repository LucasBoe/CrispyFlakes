extends NeedBehaviour
class_name FightBehaviour

var energy = 1.0
var fight : Fight = null
	
func loop():
	fight = FightHandler.get_or_create_fight(npc)
	while fight.energy > 0.0:
		await move(fight.room.get_random_floor_position())
		npc.Animator.modulate = Color(1, .5, .5, 1)
		UiNotifications.create_notification_dynamic("take this!", npc, Vector2(0, -32))
		await pause(2)

func stop_loop():
	npc.Animator.modulate = Color.WHITE
	return super.stop_loop()
