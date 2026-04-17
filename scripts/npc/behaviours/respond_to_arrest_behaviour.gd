extends Behaviour
class_name RespondToArrestBehaviour

var arrest_target: NPCGuest = null

func loop():
	_narrative = ["Closing in...", "Moving to arrest...", "Getting in position..."].pick_random()

	while is_instance_valid(arrest_target):
		if not arrest_target.pending_arrest:
			break
		if arrest_target.Behaviour.behaviour_instance is ArrestedBehaviour:
			break

		var target_room := FightHandler._get_actor_room(arrest_target)
		if target_room == null or npc.current_job_room != target_room:
			break

		var fight = FightHandler.get_fight_for_room(target_room)
		if fight != null:
			if npc.is_within_conflict_engage_range(arrest_target.global_position):
				var prison := Building.query.closest_room_of_type(RoomPrison, npc.global_position) as RoomPrison
				var stop := npc.force_behaviour(StopFightBehaviour) as StopFightBehaviour
				stop.fight = fight
				if fight.is_arrest_fight:
					stop.arrest_target = arrest_target
					stop.arrest_room = prison
				return
		elif npc.is_within_conflict_engage_range(arrest_target.global_position):
			if FightHandler.try_start_auto_arrest(arrest_target, npc):
				return

		npc.Navigation.set_target(arrest_target, -1)
		while is_instance_valid(arrest_target) and arrest_target.pending_arrest and not npc.is_within_conflict_engage_range(arrest_target.global_position):
			if not npc.Navigation.is_on_stair_path():
				npc.Navigation.refresh_target_path()
			await end_of_frame()
		npc.Navigation.stop_navigation()
		await end_of_frame()

	npc.Navigation.stop_navigation()
	if npc is NPCWorker:
		(npc as NPCWorker).resume_job_behaviour()
	else:
		npc.Behaviour.restore_previous_behaviour()

func stop_loop() -> BehaviourSaveData:
	npc.Navigation.stop_navigation()
	return super.stop_loop()
