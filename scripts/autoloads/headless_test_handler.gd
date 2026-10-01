extends Node

## Cross-cutting assertion commands for headless/automated test scripts. Each prints
## PASS/FAIL and, on failure, quits immediately with a non-zero exit code so a CI
## runner gets a real pass/fail signal instead of having to scrape console text.
## These deliberately span rooms/workers/guests/money, so they live here rather
## than being bolted onto one unrelated system.

func _ready() -> void:
	Console.add_command("assert_room_count", _assert_room_count, ["room_type", "expected"], 2, "Fails (quits non-zero) unless the placed count of the given room type equals 'expected'.")
	Console.add_command("assert_worker_count", _assert_worker_count, ["expected", "job"], 1, "Fails unless the live worker count (optionally filtered by job name) equals 'expected'.")
	Console.add_command("assert_guest_count", _assert_guest_count, ["expected"], 1, "Fails unless the live guest count equals 'expected'.")
	Console.add_command("assert_money", _assert_money, ["expected"], 1, "Fails unless the current free money pool equals 'expected'.")
	Console.add_command("place_guest_for_performance", _place_guest_for_performance, ["guest_index", "room_type", "placement"], 3, "Moves the indexed live guest into the target performance room. placement: 'self' or 'adjacent'.")
	Console.add_command("force_performance_sway", _force_performance_sway, ["room_type", "on_off"], 2, "Forces the target entertainment/opera room's sway flag on or off for headless testing.")
	Console.add_command("assert_guest_swaying", _assert_guest_swaying, ["guest_index", "expected"], 2, "Fails unless the indexed live guest is currently swaying to music (true/false).")
	Console.add_command("guest_performance_state", _guest_performance_state, ["guest_index"], 1, "Prints the indexed live guest's current room plus per-performance-room active/in-range/swaying state.")
	Console.add_command("continue_save", _continue_save, ["save_path"], 0, "Ends the current session (incl. tutorial) and loads the given save, or the newest one - same as quitting to menu and pressing Continue.")
	Console.add_command("watch_spawn_odds", _watch_spawn_odds, ["interval_game_seconds", "samples"], 2, "Every interval (in game seconds) prints per-type guest spawn odds, live mood stats and spawns since the last sample; quits after the given number of samples.")

func _continue_save(save_path : String) -> void:
	await SaveHandler.end_session()
	Building.visible = true
	RoomStatusHandler.enabled = true
	await SaveHandler.console_load(save_path)

func _watch_spawn_odds(interval : String, samples : String) -> void:
	if not interval.is_valid_float() or not samples.is_valid_int():
		_fail("watch_spawn_odds: expected a number of game seconds and an integer sample count.")
		return
	var spawned_since_sample := {}
	var on_spawned := func(_count) -> void:
		var guest := Global.NPCSpawner.guests.back() as NPCGuest
		if guest != null and guest.look_info != null:
			spawned_since_sample[guest.look_info.body_type] = spawned_since_sample.get(guest.look_info.body_type, 0) + 1
	# Game-time timer, so it can't elapse while a preceding continue_save holds its pause lock.
	await get_tree().create_timer(1.0, false).timeout
	Global.NPCSpawner.spawned_guest_signal.connect(on_spawned)

	for sample in int(samples) + 1:
		_print_spawn_odds_sample(sample, float(interval) * sample, spawned_since_sample)
		spawned_since_sample.clear()
		if sample < int(samples):
			await get_tree().create_timer(float(interval), false).timeout

	Global.NPCSpawner.spawned_guest_signal.disconnect(on_spawned)
	get_tree().quit()

func _print_spawn_odds_sample(sample : int, game_seconds : float, spawned : Dictionary) -> void:
	var stats := Global.NPCSpawner.get_guest_type_stats()
	var weights := NPCLookInfo.get_spawn_weights()
	var percentages := NPCLookInfo.get_spawn_chance_percentages()
	Console.print_line("ODDS sample=%d t=%.0fs day=%.2f guests=%d avg_mood=%.2f rate/day=%.2f" % [
		sample, game_seconds, game_seconds / Global.DAY_DURATION,
		Global.NPCSpawner.get_active_guest_count(), Global.NPCSpawner.get_average_mood(), Global.NPCSpawner.guests_per_day_rate(),
	])
	for body_type in weights.keys():
		var entry : Dictionary = stats.get(body_type, {})
		Console.print_line("ODDS   %-9s live=%2d avg_mood=%s reputation=%.2f weight=%.2f chance=%5.1f%% spawned=%d" % [
			NPCArchetypeLibrary.get_archetype(body_type).display_name,
			entry.get("count", 0),
			"%.2f" % entry.avg_mood if entry.has("avg_mood") else " -  ",
			Global.NPCSpawner.get_type_reputation(body_type),
			weights[body_type],
			percentages[body_type],
			spawned.get(body_type, 0),
		])

func _assert_room_count(room_type : String, expected : String) -> void:
	if not expected.is_valid_int():
		_fail("assert_room_count: '%s' is not a valid integer." % expected)
		return
	var normalized_type := room_type.strip_edges().to_lower()
	var count := 0
	for y in Building.floors:
		for x in Building.floors[y]:
			var room := Building.floors[y][x] as RoomBase
			if room != null and _room_type_key(room) == normalized_type:
				count += 1
	_check("room_count %s" % normalized_type, count, int(expected))

func _assert_worker_count(expected : String, job : String) -> void:
	if not expected.is_valid_int():
		_fail("assert_worker_count: '%s' is not a valid integer." % expected)
		return
	var normalized_job := job.strip_edges().to_upper()
	var count := 0
	if Global.NPCSpawner != null:
		for worker : NPCWorker in Global.NPCSpawner.get_live_workers():
			if normalized_job.is_empty() or Enum.Jobs.keys()[worker.current_job] == normalized_job:
				count += 1
	var label := "worker_count" if normalized_job.is_empty() else "worker_count %s" % normalized_job
	_check(label, count, int(expected))

func _assert_guest_count(expected : String) -> void:
	if not expected.is_valid_int():
		_fail("assert_guest_count: '%s' is not a valid integer." % expected)
		return
	var count := 0
	if Global.NPCSpawner != null:
		count = Global.NPCSpawner.get_live_guests().size()
	_check("guest_count", count, int(expected))

func _assert_money(expected : String) -> void:
	if not expected.is_valid_int():
		_fail("assert_money: '%s' is not a valid integer." % expected)
		return
	_check("money", int(ResourceHandler.resources.get(Enum.Resources.MONEY, 0)), int(expected))

func _place_guest_for_performance(guest_index : String, room_type : String, placement : String) -> void:
	if not guest_index.is_valid_int():
		_fail("place_guest_for_performance: '%s' is not a valid guest index." % guest_index)
		return

	var guest := _get_guest_by_index(int(guest_index))
	if guest == null:
		_fail("place_guest_for_performance: no live guest at index %s." % guest_index)
		return

	var room := _find_performance_room(room_type)
	if room == null:
		_fail("place_guest_for_performance: no performance room found for '%s'." % room_type)
		return

	var target_room: RoomBase = room
	var normalized_placement := placement.strip_edges().to_lower()
	if normalized_placement == "adjacent":
		target_room = _find_same_level_adjacent_room(room)
		if target_room == null:
			_fail("place_guest_for_performance: no adjacent room found for '%s'." % room_type)
			return
	elif normalized_placement != "self":
		_fail("place_guest_for_performance: placement must be 'self' or 'adjacent', got '%s'." % placement)
		return

	guest.manual_behaviour = true
	if guest.Behaviour != null:
		guest.Behaviour.clear_behaviour()
	if guest.Navigation != null:
		guest.Navigation.stop_navigation()
	guest.global_position = target_room.get_center_floor_position()
	if guest.Animator != null:
		guest.Animator.direction = Vector2.ZERO
	Console.print_line("Placed guest %s into %s for %s (%s) at %s." % [
		guest.get_display_name(),
		_room_type_key(target_room),
		_room_type_key(room),
		normalized_placement,
		str(guest.global_position),
	])
	_guest_performance_state(guest_index)

func _force_performance_sway(room_type : String, on_off : String) -> void:
	var room := _find_performance_room(room_type)
	if room == null:
		_fail("force_performance_sway: no performance room found for '%s'." % room_type)
		return

	var normalized := on_off.strip_edges().to_lower()
	var enabled := normalized == "on" or normalized == "true" or normalized == "1"
	if not enabled and not (normalized == "off" or normalized == "false" or normalized == "0"):
		_fail("force_performance_sway: expected on/off, got '%s'." % on_off)
		return

	room.set_guests_swaying(enabled)
	Console.print_line("Forced %s sway %s." % [_room_type_key(room), "ON" if enabled else "OFF"])

func _assert_guest_swaying(guest_index : String, expected : String) -> void:
	if not guest_index.is_valid_int():
		_fail("assert_guest_swaying: '%s' is not a valid guest index." % guest_index)
		return

	var guest := _get_guest_by_index(int(guest_index))
	if guest == null:
		_fail("assert_guest_swaying: no live guest at index %s." % guest_index)
		return

	var normalized := expected.strip_edges().to_lower()
	var expected_value := normalized == "true" or normalized == "on" or normalized == "1"
	if not expected_value and not (normalized == "false" or normalized == "off" or normalized == "0"):
		_fail("assert_guest_swaying: expected true/false, got '%s'." % expected)
		return

	var actual := guest.Animator != null and guest.Animator.is_swaying_to_music()
	if actual == expected_value:
		Console.print_line("PASS: guest_swaying[%d] == %s | %s" % [int(guest_index), str(expected_value), _get_guest_performance_debug_snapshot(guest)])
	else:
		_fail("FAIL: guest_swaying[%d] == %s, expected %s | %s" % [int(guest_index), str(actual), str(expected_value), _get_guest_performance_debug_snapshot(guest)])

func _guest_performance_state(guest_index : String) -> void:
	if not guest_index.is_valid_int():
		_fail("guest_performance_state: '%s' is not a valid guest index." % guest_index)
		return

	var guest := _get_guest_by_index(int(guest_index))
	if guest == null:
		_fail("guest_performance_state: no live guest at index %s." % guest_index)
		return

	Console.print_line(_get_guest_performance_debug_snapshot(guest))

func _check(label : String, actual : int, expected : int) -> void:
	if actual == expected:
		Console.print_line("PASS: %s == %d" % [label, expected])
	else:
		_fail("FAIL: %s == %d, expected %d" % [label, actual, expected])

func _fail(message : String) -> void:
	Console.print_error(message)
	get_tree().quit(1)

func _get_guest_by_index(index : int) -> NPCGuest:
	if Global.NPCSpawner == null:
		return null
	var guests := Global.NPCSpawner.get_live_guests()
	if index < 0 or index >= guests.size():
		return null
	return guests[index]

func _find_performance_room(room_type : String) -> RoomEntertainment:
	var normalized_type := room_type.strip_edges().to_lower()
	for candidate : RoomEntertainment in Building.query.all_rooms_of_type(RoomEntertainment):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if _room_type_key(candidate) == normalized_type:
			return candidate
	return null

func _find_same_level_adjacent_room(room : RoomEntertainment) -> RoomBase:
	if room == null or room.data == null:
		return null

	for col in room.data.width:
		for row in room.data.height:
			var index := Vector2i(room.x + col, room.y + row)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT]:
				var candidate := Building.get_room_from_index(index + direction) as RoomBase
				if candidate == null or candidate == room or candidate.data == null or candidate.is_outside_room:
					continue
				if candidate.y != room.y:
					continue
				return candidate
	return null

func _room_type_key(room : RoomBase) -> String:
	if room.data == null:
		return "?"
	var file_name := room.data.resource_path.get_file().get_basename()
	if file_name.begins_with("room_"):
		file_name = file_name.substr(5)
	return file_name

func _get_guest_performance_debug_snapshot(guest: NPCGuest) -> String:
	if guest == null or not is_instance_valid(guest):
		return "guest=<invalid>"

	var guest_room := Building.query.room_at_floor_position(guest.global_position) as RoomBase
	var guest_room_label := _debug_room_label(guest_room)
	var swaying := guest.Animator != null and guest.Animator.is_swaying_to_music()
	var source_count := AnimationModule.get_music_sway_source_count()

	var room_states: Array[String] = []
	var seen_room_ids := {}
	for candidate: RoomEntertainment in Building.query.all_rooms_of_type(RoomEntertainment):
		if candidate == null or not is_instance_valid(candidate):
			continue
		var room_id := candidate.get_instance_id()
		if seen_room_ids.has(room_id):
			continue
		seen_room_ids[room_id] = true
		room_states.append("%s active=%s sway=%s in_range=%s" % [
			_debug_room_label(candidate),
			str(candidate.has_active_performance()),
			str(candidate._guests_swaying_enabled),
			str(candidate.is_guest_in_performance_range(guest)),
		])

	return "guest=%s pos=%s room=%s swaying=%s sources=%d rooms=[%s]" % [
		guest.get_display_name(),
		str(guest.global_position),
		guest_room_label,
		str(swaying),
		source_count,
		"; ".join(room_states),
	]

func _debug_room_label(room: RoomBase) -> String:
	if room == null:
		return "<none>"
	if not is_instance_valid(room):
		return "<stale>"
	return "%s(%d,%d)" % [_room_type_key(room), room.x, room.y]
