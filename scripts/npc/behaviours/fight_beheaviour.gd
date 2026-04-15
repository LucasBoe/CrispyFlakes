extends NeedBehaviour
class_name FightBehaviour

var energy = 1.0
var fight : Fight = null
var arrived_at_roon = false

func loop():
	_narrative = ["Starting a brawl!", "Looking for trouble!", "Throwing punches!"].pick_random()
	if fight == null:
		fight = FightHandler.get_or_create_fight(npc)
	while not fight.is_over:
		SoundPlayer.play_punch(npc.global_position)
		await move(fight.room.get_random_floor_position())
		arrived_at_roon = true
		npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)
		await pause(2)
		if not fight.is_over and randf() < 0.4:
			PuddleHandler.create(npc.global_position, PuddleHandler.Type.BLOOD)

func stop_loop():
	npc.Tint.remove_tint_for(self)
	return super.stop_loop()
