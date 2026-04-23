extends Behaviour
class_name JobPrisonBehaviour

var room : RoomPrison

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomPrison, occupied_rooms)

func loop():
	while true:
		var to_arrest := get_npc_to_arrest()
		if to_arrest != null:
			if ConflictResponseHandler.is_marked_for_arrest(to_arrest):
				_narrative = ["Going after them...", "Making an arrest...", "They're not getting away..."].pick_random()
				var drunkenness = to_arrest.Needs.drunkenness.strength
				await move(to_arrest)
				if true:
					_narrative = ["Subduing them...", "Putting up a fight...", "Bringing them in!"].pick_random()
					FightHandler.create_defense_fight(to_arrest, npc)
					return
				else:
					ConflictResponseHandler.unmark_for_arrest(to_arrest)
					to_arrest.force_behaviour(ArrestedBehaviour)

			var behaviour = (to_arrest.Behaviour.behaviour_instance as ArrestedBehaviour)
			if behaviour != null:
				_narrative = ["Escorting to the cell...", "Taking them in...", "Putting them away..."].pick_random()
				await move(to_arrest)
				to_arrest.Animator.set_escort_target(npc)
				behaviour.cell = room
				await move(room.get_center_floor_position())

		elif room.prisoners.size() > 0:
			_narrative = ["Guarding the cell...", "Keeping watch...", "Making sure no one escapes..."].pick_random()
			await move(room.get_random_floor_position())
			await pause(10)

		else:
			_narrative = ["Watching the cell...", "On duty...", "Waiting for a prisoner..."].pick_random()
			await move(room.get_random_floor_position())
			RoomStatusHandler.notify(room, "no prisoners", Color.ORANGE)
			await pause(RoomStatusHandler.REFRESH_RATE - .5)

static func get_npc_to_arrest() -> NPCGuest:
	for g : NPCGuest in Global.NPCSpawner.guests:
		if ConflictResponseHandler.is_marked_for_arrest(g):
			return g
		if g.Behaviour.behaviour_instance is ArrestedBehaviour \
		and not (g.Behaviour.behaviour_instance as ArrestedBehaviour).cell:
			return g
	return null

static func count_people_that_need_arrestment() -> int:
	var count = 0
	for g : NPCGuest in Global.NPCSpawner.guests:
		if ConflictResponseHandler.is_marked_for_arrest(g):
			count += 1
			continue
		if g.Behaviour.behaviour_instance is ArrestedBehaviour \
		and not (g.Behaviour.behaviour_instance as ArrestedBehaviour).is_in_cell:
			count += 1
	return count

func stop_loop() -> BehaviourSaveData:
	room.worker = null
	occupied_rooms.erase(room)

	var save = super.stop_loop()
	save.room = room
	return save
