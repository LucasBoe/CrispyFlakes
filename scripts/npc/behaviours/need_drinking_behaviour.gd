extends NeedBehaviour
class_name NeedDrinkingBehaviour

var bar : RoomBar;
var table : RoomTable;

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.strength) * (needs.Mood.strength)

func loop():
	_narrative = ["Thirsty...", "Parched...", "Craving a drink..."].pick_random()
	bar = get_random_room_of_type(RoomBar)

	if not bar:
		await pause(3)
		return

	await move(bar.get_random_floor_position())

	if not is_instance_valid(bar):
		return

	_narrative = ["Waiting for a drink...", "At the bar...", "Ready to order..."].pick_random()
	var request = bar.request_drink(self)

	var sent_notification = false
	var notification_start_check_time = Global.time_now

	while request.status == Enum.RequestStatus.OPEN:
		if not sent_notification:
			var delta = Global.time_now - notification_start_check_time
			if delta > 2:
				if is_instance_valid(bar):
					UiNotifications.create_notification_dynamic("!", npc, Vector2(0,-32), Item.get_info(bar.drink_type).Tex)
				sent_notification = true
		await end_of_frame()

	if request.status == Enum.RequestStatus.FULFILLED:
		_narrative = ["Drinking...", "Enjoying the drink...", "Taking a sip..."].pick_random()
		var drink_type = bar.drink_type

		var item = Global.ItemSpawner.create(Enum.Items.DRINK, bar.get_random_floor_position())
		npc.Item.pick_up(item)

		var tables = get_all_rooms_of_type_ordered_by_distance(RoomTable)
		for t : RoomTable in tables:
			if t.is_free():
				table = t
				break

		if table:
			await move(table.sit(npc))
		else:
			await move(Building.floors.values().pick_random().values().pick_random().get_random_floor_position())

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

		var drink_duration = 10

		for i in drink_duration:
			await pause(i)
			npc.Needs.drunkenness.strength += drunkenenes_increase / float(drink_duration)
			add_satisfaction(satisfaction_increase / float(drink_duration))

		if table:
			table.stand_up(npc)

		npc.Item.drop_current().destroy()
	else:
		#UiNotifications.create_notification_dynamic("...", npc, Vector2(0,-32))
		npc.Needs.satisfaction.strength -= .1
		npc.notify(UiNotifications.ICON_MINUS_1)
