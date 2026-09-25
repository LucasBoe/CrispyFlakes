extends Node
class_name BehaviourModule

const NEED_GAMBLING_BEHAVIOUR = preload("res://scripts/npc/behaviours/need_gambling_behaviour.gd")
const NEED_SNAKE_OIL_BEHAVIOUR = preload("res://scripts/npc/behaviours/need_snake_oil_behaviour.gd")
const NEED_SOUP_BEHAVIOUR = preload("res://scripts/npc/behaviours/need_soup_behaviour.gd")
const ROOM_KITCHEN_SCRIPT = preload("res://scripts/room_kitchen.gd")

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
	#DebugLog.info("new behaviour", behaviour_script, "previous:", behaviour_instance)
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

## Behaviour -> service id, for weighting against the NPC's archetype
## (see NPCArchetype.service_weights).
var SERVICE_ID_BY_BEHAVIOUR := {
	NeedDrinkingBehaviour: "drinking",
	NEED_SOUP_BEHAVIOUR: "soup",
	NeedCleaningBehaviour: "cleaning",
	NEED_GAMBLING_BEHAVIOUR: "gambling",
	NEED_SNAKE_OIL_BEHAVIOUR: "snake_oil",
}

func get_behaviour_from_available_rooms(all_rooms):
	var all = []

	for room in all_rooms:
		if room is RoomBar:
			all.append(NeedDrinkingBehaviour)

		if is_instance_of(room, ROOM_KITCHEN_SCRIPT):
			all.append(NEED_SOUP_BEHAVIOUR)

		if room is RoomBath:
			all.append(NeedCleaningBehaviour)

		if room is RoomGambling and (room as RoomGambling).can_accept_guest():
			all.append(NEED_GAMBLING_BEHAVIOUR)

	if npc is NPCGuest and Global.NPCSpawner != null and Global.NPCSpawner.find_snake_oil_salesman_provider(npc) != null:
		all.append(NEED_SNAKE_OIL_BEHAVIOUR)

	if all.size() > 0:
		return _pick_weighted_behaviour(all)

	return IdleBehaviour

func _pick_weighted_behaviour(candidates: Array):
	var archetype = NPCArchetypeLibrary.get_archetype_for_look(npc.look_info if npc != null else null)

	var total_weight := 0.0
	var weights: Array[float] = []
	for candidate in candidates:
		var service_id: String = SERVICE_ID_BY_BEHAVIOUR.get(candidate, "")
		var weight: float = archetype.get_service_weight(service_id) if service_id != "" else 1.0
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return candidates.pick_random()

	var roll := randf() * total_weight
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]

	return candidates[candidates.size() - 1]
