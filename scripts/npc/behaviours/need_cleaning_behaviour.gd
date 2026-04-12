extends NeedBehaviour
class_name NeedCleaningBehaviour

var bath : RoomBath
const TIMEOUT = 5000

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.strength) * (needs.Mood.strength)
	
func loop():
	_narrative = ["In need of a bath...", "Feeling grimy...", "Smelling ripe..."].pick_random()
	bath = get_random_room_of_type(RoomBath)
	
	if bath == null:
		return
	
	await move(bath.get_random_floor_position())
	var request_time = Time.get_ticks_msec()
	bath.register_as_customer(self)
	UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32))	
	while npc.is_dirty and Time.get_ticks_msec() - request_time < TIMEOUT:
		await end_of_frame()
	bath.unregister_as_customer(self)
