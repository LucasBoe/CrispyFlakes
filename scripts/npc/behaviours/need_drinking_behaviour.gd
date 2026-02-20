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
	
	await move(bar.get_random_floor_position())
	var request = bar.request_drink(self)
	UiNotifications.create_notification_dynamic("!", npc, Vector2(0,-32), Item.get_info(bar.drink_type).Tex)	
	
	while request.status == Enum.RequestStatus.OPEN:
		await endOfFrame()
		
	if request.status == Enum.RequestStatus.FULFILLED:
		var drink_type = bar.drink_type
		
		var item = Global.ItemSpawner.Create(Enum.Items.DRINK, bar.get_random_floor_position())
		npc.Item.PickUp(item)
		
		var tables = Global.Building.get_rooms_of_type_ordered_by_distance(RoomTable, npc.global_position)
		for t : RoomTable in tables:
			if t.is_free():
				table = t
				break
		
		if table:
			await move(table.sit(npc))
		else:
			await move(Global.Building.floors.values().pick_random().values().pick_random().get_random_floor_position())
		
		var drunkenenes_increase = 0.0
		var satisfaction_increase = 0.15
		
		if drink_type == Enum.Items.BEER_BARREL:
			drunkenenes_increase = .3
			satisfaction_increase = .5
			
		elif drink_type == Enum.Items.WISKEY_BOX:
			drunkenenes_increase = .6
			satisfaction_increase = .7
			
		if not table:
			satisfaction_increase /= 3
		
		for i in 8:
			await pause(i)
			npc.Needs.drunkenness.strength += drunkenenes_increase / 8.0
			npc.Needs.satisfaction.strength += satisfaction_increase / 8.0
			
		if table:
			table.stand_up(npc)
			
		npc.Item.DropCurrent().Destroy()
	else:
		UiNotifications.create_notification_dynamic("...", npc, Vector2(0,-32))
		npc.Needs.satisfaction.strength -= .1
