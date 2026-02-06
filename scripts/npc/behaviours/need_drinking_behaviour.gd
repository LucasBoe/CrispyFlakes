extends NeedBehaviour
class_name NeedDrinkingBehaviour

var bar : RoomBar;
var table : RoomTable;

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.strength) * (needs.Mood.strength)
	
func loop():
	
	bar = Global.Building.get_all_rooms_of_type(RoomBar).pick_random();
	
	if not bar:
		await pause(3)
		return
		
	table = Global.Building.get_closest_room_of_type(RoomTable, bar.global_position)
	
	await move(bar.get_random_floor_position())
	var request = bar.request_drink(self)
	UiNotifications.create_notification_dynamic("!", npc, Vector2(0,-32), Item.get_info(bar.drink_type).Tex)	
	
	while request.status == Enum.RequestStatus.OPEN:
		await endOfFrame()
		
	if request.status == Enum.RequestStatus.FULFILLED:
		var item = Global.ItemSpawner.Create(Enum.Items.DRINK, bar.get_random_floor_position())
		npc.Item.PickUp(item)
		if table:
			await move(table.get_random_floor_position())
		else:
			await move(Global.Building.floors.values().pick_random().values().pick_random().get_random_floor_position())
		
		await pause(8)
		npc.Item.DropCurrent().Destroy()
