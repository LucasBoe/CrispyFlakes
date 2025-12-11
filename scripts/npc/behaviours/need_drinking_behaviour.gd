extends NeedBehaviour
class_name NeedDrinkingBehaviour

var bar : RoomBar;
var table : RoomTable;

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.Strength) * (needs.Mood.Strength)
	
func loop():
	
	bar = Global.Building.get_all_rooms_of_type(RoomBar).pick_random();
	table = Global.Building.get_closest_room_of_type(RoomTable, bar.global_position)
	
	await move(bar)
	bar.request_drink(self)
	while not bar.has_drink(self):
		await endOfFrame()
	npc.Item.PickUp(bar.pick_up_drink(self))
	if table:
		await move(table.get_random_floor_position())
	else:
		await move(Global.Building.floors.values().pick_random().pick_random().get_random_floor_position())
	
	await pause(8)
	npc.Item.DropCurrent().Destroy()
