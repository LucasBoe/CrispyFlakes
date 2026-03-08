extends Node
class_name BehaviourModule

var npc: NPC
var behaviour_instance : Behaviour = null
var previous_data : BehaviourSaveData
var has_behaviour := false

func _ready() -> void:
	npc = get_parent() as NPC
	if npc:
		npc.Behaviour = self

func set_behaviour_from_job(job: Enum.Jobs) -> Behaviour:
	return set_behaviour(Enum.job_to_behaviour(job))

func set_behaviour(behaviour_script, data = null) -> Behaviour:
	DebugLog.info("new behaviour", behaviour_script, "previous:",behaviour_instance)
	clear_behaviour()

	behaviour_instance = behaviour_script.new(npc, data) as Behaviour
	behaviour_instance.run()

	has_behaviour = true
	return behaviour_instance

func clear_behaviour() -> void:
	if behaviour_instance != null:
		behaviour_instance.	stopped = true
		previous_data = behaviour_instance.stop_loop()

	behaviour_instance = null
	has_behaviour = false

func restore_previous_behaviour() -> Behaviour:
	var data = previous_data
	return set_behaviour(data.type, data)

func get_behaviour_from_available_rooms(all_rooms):
	var all = []

	for room in all_rooms:
		if room is RoomBar:
			all.append(NeedDrinkingBehaviour)

		if room is RoomBath:
			all.append(NeedCleaningBehaviour)

		if room is RoomOuthouse:
			all.append(UseOuthouseBehaviour)
			
	if all.size() > 0:
		return all.pick_random()
		
	return IdleBehaviour
