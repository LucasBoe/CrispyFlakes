extends Behaviour
class_name JobBouncerBehaviour

const PATROL_WAIT_MIN := 1.5
const PATROL_WAIT_MAX := 3.5

var room: RoomBouncer = null

func start_loop():
	room = _find_room()
	if room == null:
		_change_to_idle()
		return
	if not room.register_bouncer(npc):
		room = null
		_change_to_idle()
		return
	room.on_destroy_signal.connect(_change_to_idle)

func loop():
	if room == null:
		return
	await move(room.get_random_floor_position())
	while true:
		var worker := npc as NPCWorker
		if worker.should_fight_conflicts() and not FightHandler.active_fights.is_empty():
			_narrative = ["Responding to a fight!", "Breaking it up!", "On my way!"].pick_random()
			var fight: Fight = FightHandler.active_fights[0]
			fight.make_join_fight(npc)
			return

		var arrest_target := _find_pending_arrest_target()
		if worker.should_fight_conflicts() and arrest_target != null:
			_narrative = ["Making an arrest...", "Got a fugitive!", "Going after them..."].pick_random()
			FightHandler.create_defense_fight(arrest_target, npc)
			return

		_narrative = ["On patrol...", "Keeping the peace...", "Eyes peeled...", "All quiet..."].pick_random()
		await move(room.get_random_floor_position())
		await pause(PATROL_WAIT_MIN + randf() * (PATROL_WAIT_MAX - PATROL_WAIT_MIN))

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(room):
		if room.on_destroy_signal.is_connected(_change_to_idle):
			room.on_destroy_signal.disconnect(_change_to_idle)
		room.unregister_bouncer(npc)
	var save := super.stop_loop()
	save.room = room
	return save

func _find_room() -> RoomBouncer:
	if data != null and is_instance_valid(data.room):
		var saved := data.room as RoomBouncer
		if saved != null and saved.can_accept_worker(Enum.Jobs.BOUNCER):
			return saved
	for r: RoomBouncer in get_all_rooms_of_type_ordered_by_distance(RoomBouncer):
		if r.can_accept_worker(Enum.Jobs.BOUNCER):
			return r
	return null

func _find_pending_arrest_target() -> NPCGuest:
	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not ConflictResponseHandler.is_marked_for_arrest(guest):
			continue
		var being_arrested := false
		for fight: Fight in FightHandler.active_fights:
			if fight.fight_type == Fight.FightType.ARREST and fight.has_participant(guest):
				being_arrested = true
				break
		if not being_arrested:
			return guest
	return null
