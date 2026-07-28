extends Node

const MOOD_LOSS := 0.05
const MOOD_GAIN := 0.05
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
			var temperature := TemperatureHandler.get_temperature_at_global_position(guest.global_position)
			if TemperatureHandler.is_cold(temperature):
				guest.Status.set_status(Enum.NpcStatus.COLD)
			else:
				guest.Status.clear_status(Enum.NpcStatus.COLD)
		await get_tree().process_frame

func _mood_penalty_loop() -> void:
	while true:
		await get_tree().create_timer(MOOD_TICK_SECONDS).timeout
		for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
			if not is_instance_valid(guest):
				continue
			if guest.Status != null and guest.Status.has_status(Enum.NpcStatus.COLD):
				guest.add_mood(-MOOD_LOSS, "Cold")

			var temperature := TemperatureHandler.get_temperature_at_global_position(guest.global_position)
			if temperature >= TemperatureHandler.PRIMARY_HEAT_TEMPERATURE:
				guest.add_mood(MOOD_GAIN, "Warmed by the stove")
