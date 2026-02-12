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
		var drink_type = bar.drink_type
		
		var item = Global.ItemSpawner.Create(Enum.Items.DRINK, bar.get_random_floor_position())
		npc.Item.PickUp(item)
		if table:
			await move(table.get_random_floor_position())
		else:
			await move(Global.Building.floors.values().pick_random().values().pick_random().get_random_floor_position())
		
		var drunkenenes_increase = 0.0
		var satisfaction_increase = 0.1
		
		if drink_type == Enum.Items.BEER_BARREL:
			drunkenenes_increase = .2
			satisfaction_increase = .2
			
		elif drink_type == Enum.Items.WISKEY_BOX:
			drunkenenes_increase = .4
			satisfaction_increase = .3
		
		for i in 8:
			await pause(i)
			npc.Needs.drunkenness.strength += drunkenenes_increase / 8.0
			npc.Needs.satisfaction.strength += satisfaction_increase / 8.0
			
		npc.Item.DropCurrent().Destroy()
	else:
		npc.Needs.satisfaction.strength -= .1
