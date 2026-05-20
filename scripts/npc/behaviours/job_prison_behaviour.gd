extends Behaviour
class_name JobPrisonBehaviour

var room : RoomPrison

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomPrison, occupied_rooms)
	if room == null:
		DebugLog.warn("[PrisonJob]", npc, "no prison room available")
		return
	DebugLog.info("[PrisonJob]", npc, "assigned room", room)

func loop():
	if room == null:
		return
	while true:
		var to_arrest := get_npc_to_arrest(npc.global_position, room)
		if to_arrest != null:
			if ConflictResponseHandler.is_marked_for_arrest(to_arrest):
				_narrative = ["Going after them...", "Making an arrest...", "They're not getting away..."].pick_random()
				DebugLog.info("[PrisonJob]", npc, "pursuing marked guest", to_arrest, "room", room)
				await move(to_arrest)
				if not is_instance_valid(to_arrest):
					continue
				var updated_behaviour = to_arrest.Behaviour.behaviour_instance if to_arrest.Behaviour != null else null
				if updated_behaviour is ArrestedBehaviour:
					ConflictResponseHandler.unmark_for_arrest(to_arrest)
					DebugLog.info("[PrisonJob]", npc, "marked guest already arrested on arrival", to_arrest, "room", room)
				elif ConflictResponseHandler.is_marked_for_arrest(to_arrest):
					_narrative = ["Subduing them...", "Putting up a fight...", "Bringing them in!"].pick_random()
					DebugLog.info("[PrisonJob]", npc, "starting arrest fight", to_arrest, "room", room)
					FightHandler.create_defense_fight(to_arrest, npc)
					return
				else:
					DebugLog.info("[PrisonJob]", npc, "marked guest no longer arrest target on arrival", to_arrest, "behaviour", updated_behaviour)
					continue

			var behaviour = (to_arrest.Behaviour.behaviour_instance as ArrestedBehaviour)
			if behaviour != null:
				_narrative = ["Escorting to the cell...", "Taking them in...", "Putting them away..."].pick_random()
				DebugLog.info("[PrisonJob]", npc, "escorting arrested guest", to_arrest, "to", room, "assigned_cell", behaviour.cell, "pending_for_room", _get_pending_prison_transfer_count(room))
				await move(to_arrest)
				to_arrest.Animator.set_escort_target(npc)
				behaviour.cell = room
				await move(room.get_center_floor_position())
				await _wait_for_prisoner_to_reach_cell(to_arrest, behaviour)

		elif room.prisoners.size() > 0:
			_narrative = ["Guarding the cell...", "Keeping watch...", "Making sure no one escapes..."].pick_random()
			await move(room.get_random_floor_position())
			await _pause_until_prison_work(10.0)

		else:
			_narrative = ["Watching the cell...", "On duty...", "Waiting for a prisoner..."].pick_random()
			await move(room.get_random_floor_position())
			RoomStatusHandler.notify(room, "no prisoners", Color.ORANGE)
			await _pause_until_prison_work(RoomStatusHandler.REFRESH_RATE - .5)

static func get_npc_to_arrest(position: Vector2, assigned_room: RoomPrison = null) -> NPCGuest:
	var marked: Array = []
	var awaiting_assigned: Array = []
	var awaiting_cell: Array = []
	for g : NPCGuest in Global.NPCSpawner.get_live_guests():
		var behaviour := _get_pending_prison_transfer_behaviour(g)
		if behaviour != null:
			if assigned_room != null and behaviour.cell == assigned_room:
				awaiting_assigned.append(g)
				continue
			if assigned_room == null or behaviour.cell == null:
				awaiting_cell.append(g)
				continue
		if ConflictResponseHandler.is_marked_for_arrest(g):
			marked.append(g)
	if not awaiting_assigned.is_empty():
		return Util.get_closest(awaiting_assigned, position)
	if not awaiting_cell.is_empty():
		return Util.get_closest(awaiting_cell, position)
	if not marked.is_empty():
		return Util.get_closest(marked, position)
	return null

static func count_people_that_need_arrestment() -> int:
	var count = 0
	for g : NPCGuest in Global.NPCSpawner.get_live_guests():
		if ConflictResponseHandler.is_marked_for_arrest(g):
			count += 1
			continue
		if _get_pending_prison_transfer_behaviour(g) != null:
			count += 1
	return count

static func has_pending_prison_transfer(assigned_room: RoomPrison = null) -> bool:
	return _get_pending_prison_transfer_count(assigned_room) > 0

static func _get_pending_prison_transfer_count(assigned_room: RoomPrison = null) -> int:
	var count := 0
	for g: NPCGuest in Global.NPCSpawner.get_live_guests():
		var behaviour := _get_pending_prison_transfer_behaviour(g)
		if behaviour == null:
			continue
		if assigned_room != null and behaviour.cell != null and behaviour.cell != assigned_room:
			continue
		count += 1
	return count

static func _get_pending_prison_transfer_behaviour(guest: NPCGuest) -> ArrestedBehaviour:
	if not is_instance_valid(guest) or guest.Behaviour == null:
		return null
	var behaviour := guest.Behaviour.behaviour_instance as ArrestedBehaviour
	if behaviour == null or behaviour.is_in_cell:
		return null
	return behaviour

func _pause_until_prison_work(duration: float) -> void:
	var remaining := duration
	while remaining > 0.0:
		var pending := get_npc_to_arrest(npc.global_position, room)
		if pending != null:
			DebugLog.debug("[PrisonJob]", npc, "interrupting wait for", pending)
			return
		var step := minf(1.0, remaining)
		await pause(step)
		remaining -= step

func _wait_for_prisoner_to_reach_cell(guest: NPCGuest, tracked_behaviour: ArrestedBehaviour) -> void:
	while not stopped and is_instance_valid(guest):
		var current_behaviour: ArrestedBehaviour = null
		if guest.Behaviour != null:
			current_behaviour = guest.Behaviour.behaviour_instance as ArrestedBehaviour
		if current_behaviour == null or current_behaviour != tracked_behaviour or current_behaviour.is_in_cell:
			return
		await pause(0.25)

func stop_loop() -> BehaviourSaveData:
	DebugLog.info("[PrisonJob]", npc, "releasing room", room)
	if room != null:
		room.worker = null
		occupied_rooms.erase(room)

	var save = super.stop_loop()
	save.room = room
	return save
