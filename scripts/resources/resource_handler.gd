extends Node2D

var resources : Dictionary = {}
signal on_resource_changed_signal
signal on_animate_resource_add_signal
signal on_animate_resource_spend_signal
signal on_money_changed_signal

var money_transaction_history: Array[Dictionary] = []
var money_source_totals: Dictionary = {}

func _ready():
	for r in Enum.Resources.values():
		resources[r] = 0 if r != Enum.Resources.MONEY else 100
		print("init resource", r)
	call_deferred("_register_console_commands")

func _register_console_commands() -> void:
	if not is_instance_valid(Console):
		return
	Console.add_command("money_breakdown", _console_print_money_breakdown, 0, 0, "Debug: prints tracked money income and expenses with percentages to the dev console and Godot output.")
	Console.add_command("debug_money_breakdown", _console_print_money_breakdown, 0, 0, "Debug: prints tracked money income and expenses with percentages to the dev console and Godot output.")
	Console.add_command("money", _console_print_money, 0, 0, "Prints the current free money pool.")
	Console.add_command("add_money", _console_add_money, ["amount"], 1, "Adds (or, with a negative amount, removes) money from the free pool.")
	Console.add_command("set_money", _console_set_money, ["amount"], 1, "Sets the free money pool to an exact amount.")

func _console_print_money() -> void:
	Console.print_line("money = %d" % int(resources.get(Enum.Resources.MONEY, 0)))

func _console_add_money(amount : String) -> void:
	if not amount.is_valid_int():
		Console.print_error("'%s' is not a valid integer amount." % amount)
		return
	change_money(int(amount), "console")
	_console_print_money()

func _console_set_money(amount : String) -> void:
	if not amount.is_valid_int():
		Console.print_error("'%s' is not a valid integer amount." % amount)
		return
	var target := int(amount)
	var current := int(resources.get(Enum.Resources.MONEY, 0))
	change_money(target - current, "console")
	_console_print_money()

func reset_money_tracking() -> void:
	money_transaction_history.clear()
	money_source_totals.clear()

func change_resource(resource, change, source: String = ""):
	var r = resource as Enum.Resources
	#print("on change resource ", Enum.Resources.keys()[r], " (", change, ")")
	resources[r] += change
	on_resource_changed_signal.emit(r, resources[r], change)
	if r == Enum.Resources.MONEY and change < 0:
		MoneyHandler.spend(-change)
			
	if not resource == Enum.Resources.MONEY:
		return

	_record_money_transaction(change, source)
	on_money_changed_signal.emit()

func change_money(change, source: String = ""):
	change_resource(Enum.Resources.MONEY, change, source)

func _change_money_without_storage(change: int, source: String = "") -> void:
	resources[Enum.Resources.MONEY] += change
	on_resource_changed_signal.emit(Enum.Resources.MONEY, resources[Enum.Resources.MONEY], change)
	_record_money_transaction(change, source)
	on_money_changed_signal.emit()

func has(resource, amount):
	if not resources.has(resource):
		return false
		
	if resources[resource] < amount:
		return false
		
	return true
			
func has_money(amount) -> bool:
	return has(Enum.Resources.MONEY, amount)

func add_animated(resource, amount, global_pos, room_location: Vector2i = Vector2i(-9999, -9999), source: String = ""):

	#if resource == Enum.Resources.MONEY:
		#SoundPlayer.play_treasure()

	var animation_duration = 1.0
	on_animate_resource_add_signal.emit(resource, amount, global_pos, animation_duration, source)
	await get_tree().create_timer(animation_duration).timeout
	if resource == Enum.Resources.MONEY and amount > 0:
		if room_location != Vector2i(-9999, -9999):
			MoneyHandler.deposit(room_location, amount)
		else:
			MoneyHandler.deposit_free(amount)

func add_animated_money_to_room_or_floor(amount: int, global_pos: Vector2, room: RoomBase = null, source: String = "") -> void:
	if amount <= 0:
		return

	var room_location := Vector2i(-9999, -9999)
	var room_can_store_money := room != null and room.data != null and room.data.money_capacity > 0
	if room_can_store_money:
		room_location = Vector2i(room.x, room.y)

	await add_animated(Enum.Resources.MONEY, amount, global_pos, room_location, source)

	if room_can_store_money:
		return

	Global.ItemSpawner.create(Enum.Items.MONEY, global_pos).set_money_amount(float(amount))
	

func notify_stolen(amount: int, source: String = "Robbery") -> void:
	resources[Enum.Resources.MONEY] -= amount
	on_resource_changed_signal.emit(Enum.Resources.MONEY, resources[Enum.Resources.MONEY], -amount)
	_record_money_transaction(-amount, source)
	on_money_changed_signal.emit()

func spend_animated(amount: int, global_pos: Vector2, source: String = "") -> void:
	change_money(-amount, source)
	SoundPlayer.play_treasure()
	var animation_duration = .3
	on_animate_resource_spend_signal.emit(amount, global_pos, animation_duration)
	await get_tree().create_timer(animation_duration).timeout

func spend_animated_from_room_first(amount: int, global_pos: Vector2, room_location: Vector2i, source: String = "") -> void:
	var taken_from_room := MoneyHandler.withdraw(room_location, amount)
	var remaining_shared := float(amount) - taken_from_room
	if remaining_shared > 0.0:
		MoneyHandler.spend(remaining_shared)

	_change_money_without_storage(-amount, source)
	SoundPlayer.play_treasure()
	var animation_duration = .3
	on_animate_resource_spend_signal.emit(amount, global_pos, animation_duration)
	await get_tree().create_timer(animation_duration).timeout

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
		_format_money_amount(float(resources.get(Enum.Resources.MONEY, 0.0))),
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

func _process(delta):
	if Input.is_key_pressed(KEY_5):
		add_animated(Enum.Resources.MONEY, 4, get_global_mouse_position(), Vector2i(-9999, -9999), "Debug Add Money")
