extends NeedBehaviour
class_name FightBehaviour

var energy = 1.0
var fight : Fight = null
var arrived_at_roon = false

func loop():
	if fight == null:
		fight = FightHandler.get_or_create_fight(npc)
	while not fight.is_over:
		await move(fight.room.get_random_floor_position())
		arrived_at_roon = true
		npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)
		await pause(2)

func stop_loop():
	npc.Tint.remove_tint_for(self)
	return super.stop_loop()
