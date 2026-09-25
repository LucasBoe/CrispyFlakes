extends NeedBehaviour
class_name NeedSoupBehaviour

const SOUP_ENERGY_GAIN := 0.35
const SOUP_MOOD_GAIN := 0.35
const EAT_DURATION := 8
const ROOM_KITCHEN_SCRIPT := preload("res://scripts/room_kitchen.gd")

var kitchen = null
var table: RoomTable = null

static func get_probability_by_needs(needs: NeedsModule):
	return (1.0 - needs.Energy.strength) * 0.8

func loop() -> void:
	_narrative = ["Craving something warm...", "Thinking about soup...", "Hungry for a hot meal..."].pick_random()
	kitchen = get_least_loaded_room_of_type(
		ROOM_KITCHEN_SCRIPT,
		Callable(),
		func(candidate): return maxf(float(candidate.soup_requests.size()) - float(candidate.soups_available), 0.0)
	)

	if not is_instance_valid(kitchen):
		await pause(3.0)
		return

	await move(kitchen.get_random_floor_position())
	if not is_instance_valid(kitchen):
		return

	_narrative = ["Waiting for soup...", "At the kitchen...", "Ready for a bowl..."].pick_random()
	var request = kitchen.request_soup(self)
	var sent_notification := false
	var notification_start_check_time := Global.time_now

	while request.status == Enum.RequestStatus.OPEN:
		if stopped:
			return
		if not sent_notification and Global.time_now - notification_start_check_time > 2.0:
			if is_instance_valid(kitchen):
				UiNotifications.create_notification_dynamic("!", npc, Vector2(0, -32), Item.get_info(Enum.Items.SOUP_BOWL).Tex)
			sent_notification = true
		await end_of_frame()

	if request.status != Enum.RequestStatus.FULFILLED:
		npc.add_service_mood(-0.1, "No Soup", "soup")
		npc.notify(UiNotifications.ICON_MINUS_1)
		return

	var bowl := Global.ItemSpawner.create(Enum.Items.SOUP_BOWL, kitchen.get_random_floor_position())
	npc.Item.pick_up(bowl)
	table = get_least_loaded_room_of_type(
		RoomTable,
		func(candidate: RoomTable): return candidate.is_free(),
		func(candidate: RoomTable): return candidate.max_guest_count - candidate.get_free_count(),
		func(candidate: RoomTable): return candidate.max_guest_count
	)

	var archetype = NPCArchetypeLibrary.get_archetype_for_look(npc.look_info if npc != null else null)
	if table:
		await move(table.sit(npc))
		if stopped or not is_instance_valid(table):
			return
		table.on_seated(npc)
	else:
		await move(get_guest_allowed_random_floor_position(npc.Needs.drunkenness.strength))
		if stopped:
			return
		if archetype.no_seat_mood_penalty > 0.0:
			add_service_mood(-archetype.no_seat_mood_penalty, "No Seat", "soup")

	CowboyTalk.talk(["Now that's a meal.", "That'll warm me up.", "Smells mighty fine.", "Just what I needed."].pick_random(), npc)

	for i in EAT_DURATION:
		if stopped:
			return
		await pause(1.0)
		if stopped:
			return
		npc.Needs.Energy.strength = minf(1.0, npc.Needs.Energy.strength + SOUP_ENERGY_GAIN / float(EAT_DURATION))
		add_service_mood(SOUP_MOOD_GAIN / float(EAT_DURATION), "Soup", "soup")

	if is_instance_valid(table) and table.is_guest_seated(npc):
		table.stand_up(npc)

	var soup := npc.Item.drop_current()
	if soup != null:
		soup.destroy()

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(table) and table.is_guest_seated(npc):
		table.stand_up(npc)
	if npc.Item.is_item(Enum.Items.SOUP_BOWL):
		var soup := npc.Item.drop_current()
		if soup != null:
			soup.destroy()
	return super.stop_loop()
