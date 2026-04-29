extends Behaviour
class_name JobStoveKeeperBehaviour

const STOVE_INFRASTRUCTURE_SCRIPT = preload("res://scripts/infrastructure/stove_infrastructure.gd")

var stove = null

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
		npc.current_job_room = stove.get_backing_room()

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
		await move(stove)
		if not is_instance_valid(stove):
			_release_stove()
			continue

		await progress(STOVE_INFRASTRUCTURE_SCRIPT.REFUEL_DURATION)
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

func _find_stove_needing_refuel():
	_cleanup_occupied_stoves()
	if not is_instance_valid(Building.infrastructure):
		return null

	for candidate in Building.infrastructure.get_all_stoves():
		if not is_instance_valid(candidate):
			continue
		if occupied_stoves.has(candidate):
			continue
		if candidate.needs_refuel():
			return candidate
	return null

func _claim_stove(target_stove) -> void:
	stove = target_stove
	if stove == null:
		return
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
	occupied_stoves = occupied_stoves.filter(func(candidate): return is_instance_valid(candidate))
