extends Node

const DIRT_THRESHOLD = 4
const MOOD_LOSS := 0.05
const MOOD_TICK_SECONDS := 10.0

func _ready() -> void:
	_status_update_loop()
	_mood_penalty_loop()

func _status_update_loop() -> void:
	while true:
		var guests: Array[NPCGuest] = Global.NPCSpawner.get_live_guests()
		for i: int in guests.size():
			await get_tree().process_frame
			if not is_instance_valid(guests[i]):
				continue
			var guest: NPCGuest = guests[i]
			if guest.Status == null:
				continue
			var mood_sensitivity: float = NPCArchetypeLibrary.get_archetype_for_look(guest.look_info).mood_sensitivity
			var threshold: int = maxi(1, roundi(DIRT_THRESHOLD * mood_sensitivity))
			var disgusted := DirtHandler.get_all_in_range(guest.global_position, 48).size() >= threshold
			if disgusted:
				guest.Status.set_status(Enum.NpcStatus.DISGUSTED)
			else:
				guest.Status.clear_status(Enum.NpcStatus.DISGUSTED)
		await get_tree().process_frame

func _mood_penalty_loop() -> void:
	while true:
		await get_tree().create_timer(MOOD_TICK_SECONDS).timeout
		for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
			if guest.Status == null or not guest.Status.has_status(Enum.NpcStatus.DISGUSTED):
				continue
			var mood_sensitivity: float = NPCArchetypeLibrary.get_archetype_for_look(guest.look_info).mood_sensitivity
			guest.add_mood(-MOOD_LOSS * mood_sensitivity, "Disgusted by dirt")
