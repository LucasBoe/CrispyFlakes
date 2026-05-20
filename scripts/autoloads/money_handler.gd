extends Node

# Money stored per room location (Vector2i). Persists even when the room is deleted.
var location_money: Dictionary = {}  # Vector2i -> float

# Unattributed funds (starting money, bounties, fines, etc.)
var free_pool: float = 100.0

signal on_money_changed_signal

# Returns total money capacity from all currently live rooms.
func total_capacity() -> float:
	if not is_instance_valid(Building):
		return 100.0
	var cap = 0.0
	for y in Building.floors:
		for x in Building.floors[y]:
			var room = Building.floors[y][x]
			if room is RoomBase and room.data != null:
				cap += room.data.money_capacity
	return cap

func total_stored() -> float:
	return _total()

# Deposit `amount` into `location`, capped at total capacity.
func deposit(location: Vector2i, amount: float) -> void:
	var space = maxf(0.0, total_capacity() - _total())
	var to_add = minf(amount, space)
	if to_add <= 0.0:
		return
	location_money[location] = location_money.get(location, 0.0) + to_add
	on_money_changed_signal.emit()

func withdraw(location: Vector2i, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var available: float = location_money.get(location, 0.0)
	if available <= 0.0:
		return 0.0
	var taken: float = minf(available, amount)
	location_money[location] = available - taken
	on_money_changed_signal.emit()
	return taken

# Deposit unattributed money (bounties, fines, etc.) split evenly across all rooms.
func deposit_free(amount: float) -> void:
	var locations: Array[Vector2i] = _room_locations()
	if locations.is_empty():
		var space = maxf(0.0, total_capacity() - _total())
		free_pool += minf(amount, space)
		on_money_changed_signal.emit()
		return
	var per_room: float = amount / locations.size()
	for loc in locations:
		deposit(loc, per_room)

func _room_locations() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_instance_valid(Building):
		return result
	for y in Building.floors:
		for x in Building.floors[y]:
			var room = Building.floors[y][x]
			if room is RoomBase and room.data != null and room.data.money_capacity > 0:
				result.append(Vector2i(x, y))
	return result

# Transfer all money from `source` to `target` location (safe worker collecting).
func collect_to(source: Vector2i, target: Vector2i) -> float:
	var amount = location_money.get(source, 0.0)
	if amount <= 0.0:
		return 0.0
	location_money[source] = 0.0
	location_money[target] = location_money.get(target, 0.0) + amount
	on_money_changed_signal.emit()
	return amount

# Drain `amount` proportionally from all buckets when purchasing.
func spend(amount: float) -> void:
	var total = _total()
	if total <= 0.0:
		return
	var keep_ratio = 1.0 - minf(1.0, amount / total)
	free_pool *= keep_ratio
	for loc in location_money.keys():
		location_money[loc] *= keep_ratio
	on_money_changed_signal.emit()

func get_money_at(location: Vector2i) -> float:
	return location_money.get(location, 0.0)

func steal(location: Vector2i) -> int:
	var amount: int = int(location_money.get(location, 0.0))
	if amount <= 0:
		return 0
	location_money[location] = 0.0
	on_money_changed_signal.emit()
	return amount

# Returns the location with the most stored money, optionally excluding one location.
func richest_location(exclude: Vector2i = Vector2i(-9999, -9999)) -> Vector2i:
	var best_loc = Vector2i(-9999, -9999)
	var best_amount = 0.0
	for loc in location_money.keys():
		if loc == exclude:
			continue
		var amt = location_money[loc]
		if amt > best_amount:
			best_amount = amt
			best_loc = loc
	return best_loc

func _total() -> float:
	var t = free_pool
	for v in location_money.values():
		t += v
	return t
