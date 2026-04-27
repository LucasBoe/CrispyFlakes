extends Behaviour
class_name JobTradingOfficeBehaviour

const ROOM_TRADING_OFFICE_SCRIPT = preload("res://scripts/room_trading_office.gd")

var office = null

static var occupied_offices = []

func start_loop():
	office = try_get_room_if_not_occupied(data, ROOM_TRADING_OFFICE_SCRIPT, occupied_offices)

func loop():
	if office == null:
		return

	await move(office.get_random_floor_position())

	while true:
		if not is_instance_valid(office):
			return

		if npc.Item.current_item != null and npc.Item.is_item(Enum.Items.CRATE):
			_narrative = ["Moving the shipment...", "Hauling a crate...", "Taking stock inside..."].pick_random()
			await _store_carried_crate(npc.Item.current_item)
			continue

		var crate_to_unpack := _find_crate_to_unpack()
		if is_instance_valid(crate_to_unpack):
			await _unpack_crate(crate_to_unpack)
			continue

		var crate_to_move := _find_crate_to_move()
		if is_instance_valid(crate_to_move):
			await _pick_up_crate(crate_to_move)
			continue

		_narrative = ["Waiting for a new order...", "Checking the ledger...", "Watching for the trader..."].pick_random()
		await move(office.get_random_floor_position())
		await pause(2.0)

func stop_loop() -> BehaviourSaveData:
	occupied_offices.erase(office)
	if is_instance_valid(office):
		office.worker = null

	var save = super.stop_loop()
	save.room = office
	return save

func _pick_up_crate(crate: Item) -> void:
	if not is_instance_valid(crate):
		return

	_narrative = ["Picking up the shipment...", "Getting that crate...", "Bringing the order inside..."].pick_random()
	var holder := _get_crate_holder(crate)
	await move(_get_crate_interaction_position(crate, holder))

	if not is_instance_valid(crate):
		return

	if holder != null:
		var picked := holder.take_item_instance(crate)
		if picked == null:
			return
		npc.Item.pick_up(picked)
	else:
		npc.Item.pick_up(crate)

	await _store_carried_crate(crate)

func _store_carried_crate(crate: Item) -> void:
	if not is_instance_valid(crate):
		return

	var target_room := _get_preferred_crate_room(crate)
	var drop_position := _get_random_floor_position_in_room(target_room)
	await move(drop_position)
	var dropped := npc.Item.drop_current()
	if is_instance_valid(dropped):
		dropped.global_position = drop_position

func _unpack_crate(crate: Item) -> void:
	while is_instance_valid(crate):
		var holder := _get_crate_holder(crate)
		if holder != null:
			return

		if crate.get_trade_crate_item_amount() <= 0:
			_cleanup_empty_crate(crate, holder)
			return

		var item_type := crate.get_trade_crate_item_type()
		var crate_room := _get_crate_room(crate)

		_narrative = ["Opening a crate...", "Checking the shipment...", "Unpacking the order..."].pick_random()
		await move(_get_crate_interaction_position(crate, holder))

		if not is_instance_valid(crate):
			return

		holder = _get_crate_holder(crate)
		if holder != null:
			return

		crate_room = _get_crate_room(crate)
		var destination := _find_destination_storage_for_item(item_type, crate_room, crate.global_position)

		var loose_item := crate.spawn_one_from_trade_crate(npc.global_position)
		if loose_item == null:
			_cleanup_empty_crate(crate, holder)
			return

		npc.Item.pick_up(loose_item)
		_narrative = ["Stocking the shelves...", "Putting the goods away...", "Sorting the delivery..."].pick_random()

		var stored := false
		if destination != null:
			await move(destination.get_next_free_slot_floor_position())
			stored = npc.Item.try_put_to(destination)
			if not stored:
				var fallback := _find_destination_storage_for_item(item_type, null, npc.global_position)
				if fallback != null and fallback != destination:
					await move(fallback.get_next_free_slot_floor_position())
					stored = npc.Item.try_put_to(fallback)

		if not stored:
			var drop_position := _get_random_floor_position_in_room(crate_room)
			await move(drop_position)
			var dropped := npc.Item.drop_current()
			if is_instance_valid(dropped):
				dropped.global_position = drop_position

		_cleanup_empty_crate(crate, holder)

func _find_crate_to_move() -> Item:
	for crate in office.get_owned_crates():
		if not is_instance_valid(crate):
			continue
		if _is_crate_ready_to_unpack(crate):
			continue
		return crate
	return null

func _find_crate_to_unpack() -> Item:
	for crate in office.get_owned_crates():
		if not is_instance_valid(crate):
			continue
		if _is_crate_ready_to_unpack(crate):
			return crate
	return null

func _get_crate_holder(crate: Item) -> RoomStorageBase:
	if crate == null:
		return null
	return crate.get_parent() as RoomStorageBase

func _get_crate_room(crate: Item) -> RoomBase:
	if crate == null:
		return null

	var holder := _get_crate_holder(crate)
	if is_instance_valid(holder):
		return holder

	return Building.query.room_at_floor_position(crate.global_position) as RoomBase

func _get_preferred_crate_room(crate: Item) -> RoomBase:
	if crate == null:
		return office

	var item_type := crate.get_trade_crate_item_type()
	var current_room := _get_crate_room(crate)
	if current_room is RoomStorage and (current_room as RoomStorage).accepts_item_type(item_type):
		return current_room

	var storage := _find_destination_storage_for_item(item_type, null, crate.global_position)
	if storage != null:
		return storage
	return office

func _find_destination_storage_for_item(item_type: int, current_room: RoomBase, origin: Vector2) -> RoomStorage:
	if current_room is RoomStorage:
		var current_storage := current_room as RoomStorage
		if current_storage.accepts_item_type(item_type) and current_storage.get_next_free_slot() >= 0:
			return current_storage

	var reachable := npc.Navigation.get_reachable_rooms()
	for storage: RoomStorage in Building.query.rooms_of_type_ordered_by_distance(RoomStorage, origin, null, reachable):
		if storage == current_room:
			continue
		if storage.accepts_item_type(item_type) and storage.get_next_free_slot() >= 0:
			return storage

	return null

func _cleanup_empty_crate(crate: Item, holder: RoomStorageBase) -> void:
	if not is_instance_valid(crate):
		return
	if crate.get_trade_crate_item_amount() > 0:
		return

	if is_instance_valid(holder):
		holder.remove_item(crate)
	office.unregister_delivery_crate(crate)
	crate.destroy()

func _get_crate_interaction_position(crate: Item, holder: RoomStorageBase) -> Vector2:
	if is_instance_valid(holder):
		return holder.get_center_floor_position()
	if is_instance_valid(crate):
		return crate.global_position
	return office.get_center_floor_position()

func _get_random_floor_position_in_room(room: RoomBase) -> Vector2:
	if is_instance_valid(room):
		return room.get_random_floor_position()
	return office.get_random_floor_position()

func _is_crate_ready_to_unpack(crate: Item) -> bool:
	if not is_instance_valid(crate):
		return false

	if _get_crate_holder(crate) != null:
		return false

	var current_room := _get_crate_room(crate)
	if current_room == office:
		return _find_destination_storage_for_item(crate.get_trade_crate_item_type(), null, crate.global_position) == null

	if current_room is RoomStorage:
		return (current_room as RoomStorage).accepts_item_type(crate.get_trade_crate_item_type())

	return false
