extends Behaviour
class_name JobStoveKeeperBehaviour

var stove: RoomStove = null

static var occupied_stoves: Array = []

func loop():
	while true:
		_narrative = ["Checking the stoves...", "Looking for cold rooms...", "Making the rounds with firewood..."].pick_random()
		stove = _find_stove_needing_refuel()

		if stove == null:
			npc.current_job_room = null
			_change_to_idle()
			return

		_claim_stove(stove)
		npc.current_job_room = stove

		if not npc.Item.is_item(Enum.Items.WOOD):
			_narrative = ["Fetching firewood...", "Looking for wood...", "Stocking up the stove..."].pick_random()
			await fetch_item(Enum.Items.WOOD)
			if not npc.Item.is_item(Enum.Items.WOOD):
				_release_stove()
				await pause(2.0)
				continue

		if not is_instance_valid(stove):
			_release_stove()
			continue

		_narrative = ["Stoking the fire...", "Feeding the stove...", "Keeping the place warm..."].pick_random()
		await move(stove.get_floor_position())
		if not is_instance_valid(stove):
			_release_stove()
			continue

		await progress(RoomStove.REFUEL_DURATION)
		if not is_instance_valid(stove):
			_release_stove()
			continue

		_consume_carried_wood()
		stove.refuel()
		_release_stove()

func stop_loop() -> BehaviourSaveData:
	_release_stove()
	npc.current_job_room = null
	return super.stop_loop()

func _find_stove_needing_refuel() -> RoomStove:
	_cleanup_occupied_stoves()
	for candidate: RoomStove in Building.query.all_rooms_of_type(RoomStove):
		if occupied_stoves.has(candidate):
			continue
		if candidate.needs_refuel():
			return candidate
	return null

func _claim_stove(target_stove: RoomStove) -> void:
	stove = target_stove
	if not occupied_stoves.has(stove):
		occupied_stoves.append(stove)
	stove.worker = npc

func _release_stove() -> void:
	if is_instance_valid(stove) and stove.worker == npc:
		stove.worker = null
	occupied_stoves.erase(stove)
	stove = null

func _consume_carried_wood() -> void:
	if npc.Item.current_item == null:
		return
	npc.Item.current_item.destroy()
	npc.Item.current_item = null

static func _cleanup_occupied_stoves() -> void:
	occupied_stoves = occupied_stoves.filter(func(c: RoomStove): return is_instance_valid(c))
