extends NeedBehaviour
class_name NeedCleaningBehaviour

var bath : RoomBath
const TIMEOUT = 5000

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.Strength) * (needs.Mood.Strength)
	
func loop():
	
	bath = Global.Building.get_all_rooms_of_type(RoomBath).pick_random();
	
	if bath == null:
		return
	
	await move(bath.get_random_floor_position())
	var request_time = Time.get_ticks_msec()
	bath.register_as_customer(self)
	UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32))	
	while npc.is_dirty and Time.get_ticks_msec() - request_time < TIMEOUT:
		await endOfFrame()
	bath.unregister_as_customer(self)
