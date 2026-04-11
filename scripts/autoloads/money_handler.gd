extends Node

# Money stored per room location (Vector2i). Persists even when the room is deleted.
var location_money: Dictionary = {}  # Vector2i -> float

# Unattributed funds (starting money, bounties, fines, etc.)
var free_pool: float = 100.0

signal changed

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
	changed.emit()

# Deposit unattributed money (bounties, fines, etc.), capped at total capacity.
func deposit_free(amount: float) -> void:
	var space = maxf(0.0, total_capacity() - _total())
	free_pool += minf(amount, space)
	changed.emit()

# Transfer all money from `source` to `target` location (safe worker collecting).
func collect_to(source: Vector2i, target: Vector2i) -> float:
	var amount = location_money.get(source, 0.0)
	if amount <= 0.0:
		return 0.0
	location_money[source] = 0.0
	location_money[target] = location_money.get(target, 0.0) + amount
	changed.emit()
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
	changed.emit()

func get_money_at(location: Vector2i) -> float:
	return location_money.get(location, 0.0)

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
