extends Node

var potential_arrests: Array = []
const AUTO_ARREST_JOBS := [Enum.Jobs.PRISON, Enum.Jobs.BOUNCER]

func mark_for_arrest(guest) -> void:
	if not can_be_arrested(guest):
		return
	if not potential_arrests.has(guest):
		potential_arrests.append(guest)
		DebugLog.info("[ArrestRouting]", "marked for arrest", guest, "queue_size", potential_arrests.size())

func unmark_for_arrest(guest) -> void:
	if potential_arrests.has(guest):
		potential_arrests.erase(guest)
		DebugLog.info("[ArrestRouting]", "unmarked arrest", guest, "queue_size", potential_arrests.size())

func is_marked_for_arrest(guest) -> bool:
	return can_be_arrested(guest) and potential_arrests.has(guest)

func can_be_arrested(guest) -> bool:
	if not is_instance_valid(guest) or not guest is NPCGuest or guest.is_on_horse():
		return false
	if guest.Behaviour == null:
		return true
	var current = guest.Behaviour.behaviour_instance
	return not (current is ArrestedBehaviour or current is FollowSheriffBehaviour)

func can_worker_respond_to_position(worker: NPCWorker, position: Vector2) -> bool:
	return _can_worker_respond(worker, position)

func _process(_delta: float) -> void:
	if Global.NPCSpawner == null:
		return
	_refresh_potential_arrests()
	_try_pair_arrests()
	_try_join_brawls()

func try_join_brawl(fight: Fight) -> bool:
	if Global.NPCSpawner == null:
		return false
	if not _can_join_brawl(fight):
		return false

	var joined := false
	for worker: NPCWorker in Global.NPCSpawner.workers:
		if not is_instance_valid(worker):
			continue
		
		if not FightHandler.can_worker_respond_to_fight(worker, fight):
			continue
		if fight.has_participant(worker):
			continue
		DebugLog.info("[ArrestRouting]", "worker joining active fight", worker, fight.debug_label())
		fight.make_join_fight(worker)
		joined = true
	return joined

func _refresh_potential_arrests() -> void:
	for i: int in range(potential_arrests.size() - 1, -1, -1):
		var guest = potential_arrests[i]
		if not can_be_arrested(guest):
			potential_arrests.remove_at(i)

func _try_pair_arrests() -> void:
	if potential_arrests.is_empty():
		return

	for i: int in range(potential_arrests.size() - 1, -1, -1):
		var guest = potential_arrests[i]
		if not can_be_arrested(guest):
			potential_arrests.remove_at(i)
			continue
		var responders := _find_responders_for_position(guest.global_position)
		if responders.is_empty():
			continue
		var arrest_fight := _find_active_arrest_fight_for_guest(guest)
		if arrest_fight == null:
			var lead_worker := responders.pop_front() as NPCWorker
			DebugLog.info("[ArrestRouting]", "pair arrest response", "guest", guest, "lead_worker", lead_worker, "helpers", responders.size())
			arrest_fight = FightHandler.create_defense_fight(guest, lead_worker)
		if arrest_fight == null:
			continue
		for worker: NPCWorker in responders:
			if arrest_fight.has_participant(worker):
				continue
			DebugLog.info("[ArrestRouting]", "helper joining arrest response", "guest", guest, "worker", worker, arrest_fight.debug_label())
			arrest_fight.make_join_fight(worker)

func _try_join_brawls() -> void:
	for fight: Fight in FightHandler.active_fights:
		try_join_brawl(fight)

func _find_responders_for_position(position: Vector2) -> Array[NPCWorker]:
	var preferred: Array[NPCWorker] = []
	var fallback: Array[NPCWorker] = []
	for job: int in AUTO_ARREST_JOBS:
		for worker: NPCWorker in Global.NPCSpawner.workers:
			if worker.current_job != job:
				continue
			if _can_worker_auto_respond_to_arrest(worker, position):
				if not preferred.has(worker):
					preferred.append(worker)

	for worker: NPCWorker in Global.NPCSpawner.workers:
		if _can_worker_respond(worker, position):
			if not preferred.has(worker) and not fallback.has(worker):
				fallback.append(worker)

	var ordered: Array[NPCWorker] = []
	var preferred_pool := preferred.duplicate()
	while not preferred_pool.is_empty():
		var closest_preferred := Util.get_closest(preferred_pool, position) as NPCWorker
		ordered.append(closest_preferred)
		preferred_pool.erase(closest_preferred)

	var fallback_pool := fallback.duplicate()
	while not fallback_pool.is_empty():
		var closest_fallback := Util.get_closest(fallback_pool, position) as NPCWorker
		ordered.append(closest_fallback)
		fallback_pool.erase(closest_fallback)

	if not fallback.is_empty():
		DebugLog.info("[ArrestRouting]", "using non-priority responders", fallback.size())
	return ordered

func _find_active_arrest_fight_for_guest(guest: NPCGuest) -> Fight:
	for fight: Fight in FightHandler.active_fights:
		if fight.fight_type == Fight.FightType.ARREST and fight.has_participant(guest):
			return fight
	return null

func _can_worker_auto_respond_to_arrest(worker: NPCWorker, position: Vector2) -> bool:
	if not _can_worker_respond(worker, position):
		return false
	return AUTO_ARREST_JOBS.has(worker.current_job)

func _can_worker_respond(worker: NPCWorker, position: Vector2) -> bool:
	if not is_instance_valid(worker):
		return false
	if worker.current_job == Enum.Jobs.PRISON and JobPrisonBehaviour.has_pending_prison_transfer(worker.current_job_room as RoomPrison):
		return false
	if not worker.should_fight_conflicts():
		return false
	if NPCWorker.picked_up_npc == worker:
		return false
	if worker.Behaviour == null or worker.Behaviour.behaviour_instance is FightBehaviour:
		return false
	if worker.Behaviour.behaviour_instance is KnockedOutBehaviour:
		return false
	return FightHandler.is_within_fight_detection_range(worker.global_position, position)

func _can_join_brawl(fight: Fight) -> bool:
	if fight == null or not is_instance_valid(fight):
		return false
	if fight.is_over or fight.fight_type == Fight.FightType.ARREST:
		return false
	if fight.room == null:
		return false
	return _has_active_guest_participant(fight)

func _has_active_guest_participant(fight: Fight) -> bool:
	for participant in fight.get_active_participants():
		var guest := participant as NPCGuest
		if is_instance_valid(guest):
			return true
	return false

func _is_in_active_fight(guest) -> bool:
	if not can_be_arrested(guest):
		return false
	for fight: Fight in FightHandler.active_fights:
		if fight.has_participant(guest):
			return true
	return false
