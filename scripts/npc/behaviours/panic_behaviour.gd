extends Behaviour
class_name PanicBehaviour

const RECHECK_INTERVAL := 0.5

var _notification = null
var _threat_position: Vector2 = Vector2.ZERO
var _threat_room: RoomBase = null
var _source_fight: Fight = null

func start_loop() -> void:
	_narrative = ["Panicking!", "Getting away!", "Nope nope nope!"].pick_random()
	_notification = UiNotifications.create_notification_dynamic("!", npc, Vector2(0, -32), null, Color.ORANGE, INF)
	_read_data()
	print("[GutlessPanic] behaviour start npc=%s threat_room=%s threat_pos=%s source_fight=%s" % [
		npc.name,
		_threat_room.name if _threat_room != null else "<none>",
		_threat_position,
		_source_fight.debug_label() if _source_fight != null else "<none>",
	])

func loop() -> void:
	
	if npc.Item.current_item != null:
		npc.Item.drop_current()

	var escape_room := _find_escape_room()
	if escape_room != null:
		print("[GutlessPanic] npc=%s fleeing_to=%s pos=%s" % [npc.name, escape_room.name, escape_room.get_center_floor_position()])
		await move(escape_room.get_random_floor_position())
	else:
		print("[GutlessPanic] npc=%s no_escape_room" % npc.name)

	while _should_keep_panicking():
		_narrative = ["Hiding from the fight...", "Keeping clear...", "Waiting it out..."].pick_random()
		await pause(RECHECK_INTERVAL)

	if stopped:
		return

	if npc is NPCWorker:
		var worker := npc as NPCWorker
		if worker.current_job != Enum.Jobs.IDLE:
			_restore_worker_job()

func stop_loop() -> BehaviourSaveData:
	UiNotifications.try_kill(_notification)
	return BehaviourSaveData.new(get_script())

func _read_data() -> void:
	if data == null:
		_threat_position = npc.global_position
		return
	_source_fight = data.extra.get("fight", null)
	_threat_room = data.extra.get("threat_room", null) as RoomBase
	_threat_position = data.extra.get("threat_position", npc.global_position)

func _find_escape_room() -> RoomBase:
	var reachable := npc.Navigation.get_reachable_rooms()
	var best_room: RoomBase = null
	var best_distance := -INF
	print("[GutlessPanic] npc=%s reachable_rooms=%d" % [npc.name, reachable.size()])

	for room: RoomBase in reachable:
		if room == null or room == _threat_room:
			continue
		var distance := room.get_center_floor_position().distance_squared_to(_threat_position)
		if _is_room_near_any_fight(room):
			print("[GutlessPanic] npc=%s reject_escape_room=%s near_fight=true" % [npc.name, room.name])
			continue
		if distance > best_distance:
			best_distance = distance
			best_room = room

	if best_room != null:
		return best_room

	for room: RoomBase in reachable:
		if room == null or room == _threat_room:
			continue
		var distance := room.get_center_floor_position().distance_squared_to(_threat_position)
		if distance > best_distance:
			best_distance = distance
			best_room = room
	return best_room

func _is_room_near_any_fight(room: RoomBase) -> bool:
	for fight: Fight in FightHandler.active_fights:
		if not FightHandler.is_started_active_fight(fight):
			continue
		if fight.room == room:
			return true
		var fight_position := FightHandler.get_fight_position(fight)
		if FightHandler.is_within_fight_detection_range(fight_position, room.get_center_floor_position()):
			return true
	return false

func _should_keep_panicking() -> bool:
	if npc is NPCWorker:
		var worker := npc as NPCWorker
		if is_instance_valid(worker.current_job_room):
			var job_room_unsafe := FightHandler.is_fight_near_room(worker.current_job_room)
			print("[GutlessPanic] npc=%s job_room=%s unsafe=%s" % [npc.name, worker.current_job_room.name, job_room_unsafe])
			return job_room_unsafe
	var source_active := FightHandler.is_started_active_fight(_source_fight)
	print("[GutlessPanic] npc=%s source_fight_active=%s" % [npc.name, source_active])
	return source_active

func _restore_worker_job() -> void:
	var previous_data := npc.Behaviour.previous_data
	print("[GutlessPanic] npc=%s restoring_job previous=%s" % [
		npc.name,
		previous_data.type.resource_path.get_file() if previous_data != null and previous_data.type != null else "<none>",
	])
	if previous_data != null and previous_data.type != get_script():
		npc.Behaviour.restore_previous_behaviour()
	else:
		(npc as NPCWorker).resume_job_behaviour()
