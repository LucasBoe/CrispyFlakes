extends Behaviour
class_name JobWaterTowerBehaviour

var tower: RoomWaterTower
static var occupied_towers = []

func start_loop():
	tower = try_get_room_if_not_occupied(data, RoomWaterTower, occupied_towers)

func loop():
	await move(tower.get_random_floor_position())

	while true:
		if tower.is_full():
			_change_to_idle()
			return

		_narrative = ["Pumping water...", "Filling the tank...", "Working the pump..."].pick_random()
		await progress(RoomWaterTower.PUMP_DURATION)
		tower.pump()

func stop_loop():
	tower.worker = null
	occupied_towers.erase(tower)

	var save = super.stop_loop()
	save.room = tower
	return save
