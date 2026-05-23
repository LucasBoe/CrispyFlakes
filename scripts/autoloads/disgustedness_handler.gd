extends Node

const DIRT_THRESHOLD = 4
const SATISFACTION_LOSS := 0.05
const SATISFACTION_TICK_SECONDS := 10.0

func _ready() -> void:
	_status_update_loop()
	_satisfaction_penalty_loop()

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
			var disgusted := DirtHandler.get_all_in_range(guest.global_position, 48).size() >= DIRT_THRESHOLD
			if disgusted:
				guest.Status.set_status(Enum.NpcStatus.DISGUSTED)
			else:
				guest.Status.clear_status(Enum.NpcStatus.DISGUSTED)
		await get_tree().process_frame

func _satisfaction_penalty_loop() -> void:
	while true:
		await get_tree().create_timer(SATISFACTION_TICK_SECONDS).timeout
		for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
			if guest.Status == null or not guest.Status.has_status(Enum.NpcStatus.DISGUSTED):
				continue
			guest.add_satisfaction(-SATISFACTION_LOSS, "Disgusted by dirt")
