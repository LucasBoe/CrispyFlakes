extends NeedBehaviour
class_name OperaGuestBehaviour

const WATCH_DURATION := 12.0

var room: RoomOpera
var slot_index := -1

func loop():
	_narrative = ["Heading for the opera...", "Looking for a balcony seat...", "Drawn to the performance..."].pick_random()
	room = get_least_loaded_room_of_type(
		RoomOpera,
		func(candidate: RoomOpera): return candidate.can_accept_guest(),
		func(candidate: RoomOpera): return candidate.get_occupied_balcony_slot_count(),
		func(candidate: RoomOpera): return candidate.get_balcony_slot_count()
	)

	if room == null:
		await pause(2)
		return

	var guest := npc as NPCGuest
	if guest == null:
		return

	slot_index = room.reserve_balcony_slot(guest)
	if slot_index < 0:
		await pause(1)
		return

	await move(room.get_balcony_slot_world_position(slot_index))
	if stopped or not is_instance_valid(room) or not room.has_guest_in_balcony_slot(guest, slot_index):
		return
	guest.Animator.suppress_music_sway = true
	guest.Animator.x_orientation = room.get_balcony_slot_facing_direction(slot_index)
	guest.Animator.direction = Vector2.ZERO

	_narrative = ["Watching from the balcony...", "Taking in the aria...", "Leaning over the railing..."].pick_random()
	await pause(WATCH_DURATION)

func stop_loop() -> BehaviourSaveData:
	var guest := npc as NPCGuest
	if guest != null and guest.Animator != null:
		guest.Animator.suppress_music_sway = false
	if guest != null and is_instance_valid(room):
		room.release_balcony_slot(guest)
	return super.stop_loop()
