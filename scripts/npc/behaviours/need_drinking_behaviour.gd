extends NeedBehaviour
class_name NeedDrinkingBehaviour

var bar : RoomBar;
var table : RoomTable;

static func get_probability_by_needs(needs : NeedsModule):
	return (needs.Money.strength) * (needs.Mood.strength)

func loop():
	_narrative = ["Thirsty...", "Parched...", "Craving a drink..."].pick_random()
	bar = get_least_loaded_room_of_type(
		RoomBar,
		Callable(),
		func(candidate: RoomBar): return candidate.drink_requests.size()
	)

	if not bar:
		await pause(3)
		return

	await move(bar.get_random_floor_position())

	if not is_instance_valid(bar):
		return

	SoundPlayer.play_talk(npc.global_position)
	_narrative = ["Waiting for a drink...", "At the bar...", "Ready to order..."].pick_random()
	var request = bar.request_drink(self)
	var sent_notification = false
	var notification_start_check_time = Global.time_now

	while request.status == Enum.RequestStatus.OPEN:
		if stopped:
			return
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
		item.drink_source_type = drink_type
		npc.Item.pick_up(item)

		table = get_least_loaded_room_of_type(
			RoomTable,
			func(candidate: RoomTable): return candidate.is_free(),
			func(candidate: RoomTable): return candidate.max_guest_count - candidate.get_free_count(),
			func(candidate: RoomTable): return candidate.max_guest_count
		)

		if table:
			await move(table.sit(npc))
			if stopped or not is_instance_valid(table):
				return
			table.on_seated(npc)
		else:
			await move(get_guest_allowed_random_floor_position(npc.Needs.drunkenness.strength))
			if stopped:
				return

		CowboyTalk.talk(["I needed that.", "Hits the spot.", "Mighty fine.", "Ahh."].pick_random(), npc)

		if is_instance_valid(table) and table.guests.values().any(func(g): return g != null and g != npc):
			CowboyTalk.talk("Have you heard about MECH BROTLAUCH? He seems to be the evil guy around here.", npc)

		var drunkenenes_increase = 0.0
		var satisfaction_increase = 0.2

		if drink_type == Enum.Items.BEER_BARREL:
			drunkenenes_increase = .1
			satisfaction_increase = .7

		elif drink_type == Enum.Items.WISKEY_BOX:
			drunkenenes_increase = .3
			satisfaction_increase = 1.0

		if not table:
			satisfaction_increase /= 4

		var drink_duration = 10


		for i in drink_duration:
			if stopped:
				return
			if randf() < 0.3:
				SoundPlayer.play_talk(npc.global_position)
			await pause(i)
			if stopped:
				return
			npc.Needs.drunkenness.strength += drunkenenes_increase / float(drink_duration)
			add_satisfaction(satisfaction_increase / float(drink_duration), "Drinking")

		if is_instance_valid(table) and table.is_guest_seated(npc):
			table.stand_up(npc)

		var drink = npc.Item.drop_current()
		if drink != null:
			drink.destroy()
	else:
		#UiNotifications.create_notification_dynamic("...", npc, Vector2(0,-32))
		npc.add_satisfaction(-0.1, "No Drink")
		npc.notify(UiNotifications.ICON_MINUS_1)

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(table) and table.is_guest_seated(npc):
		table.stand_up(npc)
	if npc.Item.is_item(Enum.Items.DRINK):
		npc.Item.drop_current()
	return super.stop_loop()
