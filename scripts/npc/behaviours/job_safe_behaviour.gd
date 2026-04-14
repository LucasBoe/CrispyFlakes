extends Behaviour
class_name JobSafeBehaviour

var safe : RoomSafe

static var occupied_safes = []

func start_loop():
	safe = try_get_room_if_not_occupied(data, RoomSafe, occupied_safes)

func loop():
	await move(safe.get_random_floor_position())

	while true:
		var safe_loc = Vector2i(safe.x, safe.y)
		var target_loc = MoneyHandler.richest_location(safe_loc)

		if target_loc == Vector2i(-9999, -9999) or MoneyHandler.get_money_at(target_loc) < 1.0:
			# Nothing to collect — idle at safe
			_narrative = ["Watching the safe...", "Keeping an eye on things...", "Nothing to collect yet..."].pick_random()
			await move(safe.get_random_floor_position())
			await pause(2)
			continue

		# Walk to the target room location
		_narrative = ["Collecting the take...", "Going to pick up the earnings...", "Making the rounds..."].pick_random()
		var target_room = Building.get_room_from_index(target_loc)
		if is_instance_valid(target_room):
			await move(target_room.get_random_floor_position())
		else:
			var world_pos = Building.global_position_from_room_index(target_loc)
			await move(world_pos)

		# Brief collect animation
		if is_instance_valid(target_room) and is_instance_valid(target_room.get_node_or_null("ProgressBar")):
			await progress(1.0, target_room.get_node("ProgressBar"))

		# Spawn money item and carry it to the safe
		var spawn_pos = npc.global_position
		var money_item = Global.ItemSpawner.create(Enum.Items.MONEY, spawn_pos)
		npc.Item.pick_up(money_item)

		MoneyHandler.collect_to(target_loc, safe_loc)

		# Return to safe and deposit
		_narrative = ["Returning to the safe...", "Securing the funds...", "Depositing the earnings..."].pick_random()
		await move(safe.get_random_floor_position())

		var carried = npc.Item.drop_current()
		if is_instance_valid(carried):
			carried.destroy()

func stop_loop() -> BehaviourSaveData:
	occupied_safes.erase(safe)
	if is_instance_valid(safe):
		safe.worker = null

	var _data = BehaviourSaveData.new(get_script())
	_data.room = safe
	return _data
