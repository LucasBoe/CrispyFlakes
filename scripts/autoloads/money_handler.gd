extends Node

## The single source of truth for the player's money: cash lives either in a room location
## (location_money) or in the unattributed free_pool, and the player's total is their sum.
## Every earn/spend goes through here so the total, room cash and money history never drift.

const NO_LOCATION := Vector2i(-9999, -9999)
const EARN_ANIMATION_DURATION := 1.0
const SPEND_ANIMATION_DURATION := 0.3

# Money stored per room location (Vector2i). Persists even when the room is deleted.
var location_money: Dictionary = {}  # Vector2i -> float

# Unattributed funds (starting money, bounties, fines, etc.)
var free_pool: float = 100.0

var money_transaction_history: Array[Dictionary] = []
var money_source_totals: Dictionary = {}

signal on_money_changed_signal
signal on_animate_earn_signal(amount: int, global_pos: Vector2, duration: float)
signal on_animate_spend_signal(amount: int, global_pos: Vector2, duration: float)

func _ready() -> void:
	call_deferred("_register_console_commands")

func _register_console_commands() -> void:
	Console.add_command("money_breakdown", _console_print_money_breakdown, 0, 0, "Debug: prints tracked money income and expenses with percentages to the dev console and Godot output.")
	Console.add_command("debug_money_breakdown", _console_print_money_breakdown, 0, 0, "Debug: prints tracked money income and expenses with percentages to the dev console and Godot output.")
	Console.add_command("money", _console_print_money, 0, 0, "Prints the player's total money (free pool plus money stored in rooms).")
	Console.add_command("add_money", _console_add_money, ["amount"], 1, "Adds (or, with a negative amount, removes) money. Additions go to the free pool and ignore storage capacity.")
	Console.add_command("set_money", _console_set_money, ["amount"], 1, "Sets the player's total money to an exact amount. Additions go to the free pool and ignore storage capacity.")

# Sets starting money for a fresh run, clearing all stored cash and money history.
func set_starting_money(amount: int) -> void:
	free_pool = amount
	location_money.clear()
	reset_money_tracking()
	on_money_changed_signal.emit()

func reset_money_tracking() -> void:
	money_transaction_history.clear()
	money_source_totals.clear()

func has_money(amount: float) -> bool:
	return _total() >= amount

## Adds income at `location` (or split across rooms for NO_LOCATION), capped by storage
## capacity. Returns the amount actually stored.
func earn(amount: float, location: Vector2i = NO_LOCATION, source: String = "") -> float:
	if amount <= 0.0:
		return 0.0
	var before := _total()
	if location != NO_LOCATION:
		deposit(location, amount)
	else:
		deposit_free(amount)
	var stored := _total() - before
	_record_money_transaction(stored, source)
	return stored

## Same as earn(), plus coins flying from `global_pos` to the money HUD. Awaitable: returns once
## the coins have had time to arrive, for callers that pace their behaviour on it.
func earn_animated(amount: float, global_pos: Vector2, location: Vector2i = NO_LOCATION, source: String = "") -> void:
	var stored := earn(amount, location, source)
	if stored > 0.0:
		on_animate_earn_signal.emit(int(stored), global_pos, EARN_ANIMATION_DURATION)
	await get_tree().create_timer(EARN_ANIMATION_DURATION).timeout

## Earns into `room` if it can store money; otherwise drops the cash as a loose money item at
## `global_pos` for safe workers to collect (it only counts once it reaches a safe).
func earn_to_room_or_floor(amount: int, global_pos: Vector2, room: RoomBase, source: String = "") -> void:
	if amount <= 0:
		return
	if room != null and room.data != null and room.data.money_capacity > 0:
		await earn_animated(amount, global_pos, Vector2i(room.x, room.y), source)
		return
	Global.ItemSpawner.create(Enum.Items.MONEY, global_pos).set_money_amount(float(amount))

func spend_animated(amount: int, global_pos: Vector2, source: String = "") -> void:
	spend(amount, source)
	_play_spend_animation(amount, global_pos)
	await get_tree().create_timer(SPEND_ANIMATION_DURATION).timeout

## Spends from the cash stored at `room_location` first, then from everywhere else.
func spend_animated_from_room_first(amount: int, global_pos: Vector2, room_location: Vector2i, source: String = "") -> void:
	var taken_from_room := withdraw(room_location, amount)
	var remaining_shared := float(amount) - taken_from_room
	if remaining_shared > 0.0:
		_drain(remaining_shared)
	_record_money_transaction(-amount, source)
	_play_spend_animation(amount, global_pos)
	await get_tree().create_timer(SPEND_ANIMATION_DURATION).timeout

func _play_spend_animation(amount: int, global_pos: Vector2) -> void:
	SoundPlayer.play_treasure()
	on_animate_spend_signal.emit(amount, global_pos, SPEND_ANIMATION_DURATION)

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

# Pay `amount` for a purchase, drained proportionally from all buckets.
func spend(amount: float, source: String = "") -> void:
	_drain(amount)
	_record_money_transaction(-amount, source)

func _drain(amount: float) -> void:
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
	var amount: float = location_money.get(location, 0.0)
	if amount < 1.0:
		return 0
	location_money[location] = 0.0
	_record_money_transaction(-amount, "Robbery")
	on_money_changed_signal.emit()
	return int(amount)

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

func _console_print_money() -> void:
	Console.print_line("money = %d" % int(_total()))

func _console_add_money(amount : String) -> void:
	if not amount.is_valid_int():
		Console.print_error("'%s' is not a valid integer amount." % amount)
		return
	_console_change_money(int(amount))
	_console_print_money()

func _console_set_money(amount : String) -> void:
	if not amount.is_valid_int():
		Console.print_error("'%s' is not a valid integer amount." % amount)
		return
	_console_change_money(int(amount) - int(_total()))
	_console_print_money()

func _console_change_money(change: int) -> void:
	if change < 0:
		spend(-change, "console")
		return
	free_pool += change
	_record_money_transaction(change, "console")
	on_money_changed_signal.emit()

func _record_money_transaction(change: float, source: String = "") -> void:
	if is_zero_approx(change):
		return

	var now: float = Global.time_now
	var normalized_source := _normalize_money_source(source, change)
	money_transaction_history.append({
		"time": now,
		"change": change,
		"source": normalized_source,
	})
	_trim_money_transaction_history(now)

	var source_totals: Dictionary = money_source_totals.get(normalized_source, {
		"income": 0.0,
		"expense": 0.0,
	})
	if change > 0.0:
		source_totals["income"] = float(source_totals.get("income", 0.0)) + change
	else:
		source_totals["expense"] = float(source_totals.get("expense", 0.0)) + absf(change)
	money_source_totals[normalized_source] = source_totals
	on_money_changed_signal.emit()

func _trim_money_transaction_history(now: float) -> void:
	var day_duration: float = Global.DAY_DURATION
	for index in range(money_transaction_history.size() - 1, -1, -1):
		var entry: Dictionary = money_transaction_history[index]
		if (now - float(entry.get("time", now))) > day_duration:
			money_transaction_history.remove_at(index)

func _normalize_money_source(source: String, change: float) -> String:
	var trimmed := source.strip_edges()
	if trimmed != "":
		return trimmed
	return "Unknown Income" if change > 0.0 else "Unknown Expense"

func _console_print_money_breakdown() -> void:
	for line in get_money_breakdown_lines():
		print(line)
		if is_instance_valid(Console):
			Console.print_line(line)

func get_money_breakdown_lines() -> Array[String]:
	var lines: Array[String] = []
	var total_income := 0.0
	var total_expense := 0.0

	for source in money_source_totals.keys():
		var source_totals: Dictionary = money_source_totals[source]
		total_income += float(source_totals.get("income", 0.0))
		total_expense += float(source_totals.get("expense", 0.0))

	lines.append("=== Money Breakdown ===")
	lines.append("Current money: %s | Income tracked: %s | Expenses tracked: %s | Net tracked: %s" % [
		_format_money_amount(_total()),
		_format_money_amount(total_income),
		_format_money_amount(total_expense),
		_format_signed_money_amount(total_income - total_expense),
	])

	if money_source_totals.is_empty():
		lines.append("No money transactions tracked yet.")
		return lines

	lines.append("-- Income --")
	if total_income <= 0.0:
		lines.append("none")
	else:
		for source in _get_sorted_money_sources("income"):
			var amount := _get_money_source_amount(source, "income")
			if amount <= 0.0:
				continue
			lines.append("%s: %s (%s)" % [
				source,
				_format_money_amount(amount),
				_format_percentage(amount, total_income),
			])

	lines.append("-- Expenses --")
	if total_expense <= 0.0:
		lines.append("none")
	else:
		for source in _get_sorted_money_sources("expense"):
			var amount := _get_money_source_amount(source, "expense")
			if amount <= 0.0:
				continue
			lines.append("%s: %s (%s)" % [
				source,
				_format_money_amount(amount),
				_format_percentage(amount, total_expense),
			])

	return lines

func _get_sorted_money_sources(kind: String) -> Array[String]:
	var sources: Array[String] = []
	for source in money_source_totals.keys():
		sources.append(str(source))

	sources.sort_custom(func(a: String, b: String) -> bool:
		var a_amount := _get_money_source_amount(a, kind)
		var b_amount := _get_money_source_amount(b, kind)
		if is_equal_approx(a_amount, b_amount):
			return a < b
		return a_amount > b_amount
	)
	return sources

func _get_money_source_amount(source: String, kind: String) -> float:
	var source_totals: Dictionary = money_source_totals.get(source, {})
	return float(source_totals.get(kind, 0.0))

func _format_money_amount(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return "%d$" % roundi(amount)
	return "%.2f$" % amount

func _format_signed_money_amount(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return "%+d$" % roundi(amount)
	return "%+.2f$" % amount

func _format_percentage(amount: float, total: float) -> String:
	if total <= 0.0:
		return "0.0%%"
	return "%.1f%%" % [(amount / total) * 100.0]
