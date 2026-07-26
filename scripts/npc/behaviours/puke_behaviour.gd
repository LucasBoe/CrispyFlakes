extends Behaviour
class_name PukeBehaviour

const INDOOR_ACCIDENT_RELIEF_DURATION := 2.0
const INDOOR_ACCIDENT_CHANCE_MULTIPLIER := 0.6

static func should_have_indoor_accident(guest: NPCGuest) -> bool:
	if guest == null or guest.Needs == null:
		return false
	if guest.needs_to_pee < guest.PEE_TRIGGER_THRESHOLD:
		return false

	var current_room := Building.query.room_at_floor_position(guest.global_position) as RoomBase
	if current_room == null or current_room.is_outside_room:
		return false
	if current_room is RoomToilet or current_room is RoomOuthouse:
		return false

	return guest.Needs.drunkenness.strength * INDOOR_ACCIDENT_CHANCE_MULTIPLIER >= randf()

func loop():
	_narrative = ["Feeling sick...", "About to hurl...", "Shouldn't have had that last one..."].pick_random()
	npc.Animator.is_puking = true
	
	await pause(1.5)
	npc.Animator.is_puking = false
	SoundPlayer.play_puke(npc.global_position)
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PUKE)
	await _maybe_relieve_inside()
	npc.Needs.drunkenness.strength -= 0.2

func _maybe_relieve_inside() -> void:
	var guest := npc as NPCGuest
	if not should_have_indoor_accident(guest):
		return

	npc.Animator.is_peeing = true
	SoundPlayer.play_piss(npc.global_position)
	await pause(INDOOR_ACCIDENT_RELIEF_DURATION)
	npc.Animator.is_peeing = false
	PuddleHandler.create(npc.global_position, PuddleHandler.Type.PEE)
	DirtHandler.create_dirt_at(npc.global_position)
	guest.needs_to_pee = 0.0
