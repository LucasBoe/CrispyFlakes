extends NeedBehaviour
class_name NeedCleaningBehaviour

var bath : RoomBath

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.Strength) * (needs.Mood.Strength)
	
func loop():
	
	bath = Global.Building.get_all_rooms_of_type(RoomBath).pick_random();
	
	if bath == null:
		return
	
	await move(bath)
	bath.register_as_customer(self)
	while npc.is_dirty:
		await endOfFrame()
