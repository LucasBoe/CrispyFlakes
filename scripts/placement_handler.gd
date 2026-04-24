extends Node2D

var is_placing = false
var has_valid_target = false
var building_data : RoomData
var location : Vector2i
var landed_location : Vector2i
var highlights : Array = []
var custom_placement_check = null

var previous_notification = null

func start_building(data : RoomData, check):
	self.building_data = data
	self.custom_placement_check = check
	is_placing = true

	if highlights.is_empty():
		for _i in building_data.width * building_data.height:
			highlights.append(RoomHighlighter.request_rect(Building.floors[0][0], Color.WHITE, 2, RoomHighlighter.Priority.SELECTION))

func stop_building():
	if not highlights.is_empty():
		is_placing = false
		for h in highlights:
			RoomHighlighter.dispose(h)
		highlights.clear()

func _should_use_above_ground_fall(target_location: Vector2i) -> bool:
	return not building_data.is_outdoor and target_location.y >= 0

func _get_tetris_y(x: int) -> int:
	var y = 0
	while y < 100:
		var room = Building.get_room_from_index(Vector2i(x, y))
		if room == null:
			return y
		y += 1
	return y

func _has_direct_empty_override(target_location: Vector2i) -> bool:
	if not _should_use_above_ground_fall(target_location):
		return false

	var has_empty := false
	for col in building_data.width:
		for row in building_data.height:
			var cell = Building.get_room_from_index(target_location + Vector2i(col, row))
			if cell is RoomEmpty:
				has_empty = true
			elif cell != null:
				return false
	return has_empty

func _get_landed_location(target_location: Vector2i) -> Vector2i:
	if not _should_use_above_ground_fall(target_location):
		return target_location

	var base_y := 0
	for col in building_data.width:
		base_y = max(base_y, _get_tetris_y(target_location.x + col))
	return Vector2i(target_location.x, base_y)

func _is_footprint_empty(target_location: Vector2i) -> bool:
	for col in building_data.width:
		for row in building_data.height:
			var cell = Building.get_room_from_index(target_location + Vector2i(col, row))
			if cell != null and not cell is RoomEmpty:
				return false
	return true

func _refresh_tiles_after_fall(impact_strength: float, impact_duration: float) -> void:
	Building.update_foreground_tiles()
	Camera.add_shake(impact_strength, impact_duration)

func _input(event):
	if not is_placing:
		return

	var mouse = get_global_mouse_position()
	location = Building.round_room_index_from_global_position(mouse)
	landed_location = _get_landed_location(location)
	var validation_location := location if _has_direct_empty_override(location) else landed_location

	has_valid_target = _is_footprint_empty(location)
	if validation_location != location:
		has_valid_target = has_valid_target && _is_footprint_empty(validation_location)
	var has_money = ResourceHandler.has_money(building_data.construction_price)

	# Adjacency check — any cell in the footprint satisfies it
	var has_adjacent_room_or_is_ground_floor = false

	if location.y < 0:
		# Basement: require at least one neighbour in any direction from any footprint cell
		for col in building_data.width:
			for row in building_data.height:
				var cell = location + Vector2i(col, row)
				for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if Building.get_room_from_index(cell + dir):
						has_adjacent_room_or_is_ground_floor = true
	elif _should_use_above_ground_fall(location):
		has_adjacent_room_or_is_ground_floor = true
	else:
		# Above ground: a room above/below the footprint, or any footprint cell is on y==0
		for col in building_data.width:
			if Building.get_room_from_index(location + Vector2i(col, building_data.height)):
				has_adjacent_room_or_is_ground_floor = true
			if Building.get_room_from_index(location + Vector2i(col, -1)):
				has_adjacent_room_or_is_ground_floor = true
			if location.y == 0:
				has_adjacent_room_or_is_ground_floor = true

	has_valid_target = has_valid_target && has_adjacent_room_or_is_ground_floor

	# Above-ground indoor rooms cannot be placed in a column where y=0 is an outdoor room.
	# Basement rooms live below that surface slot, so they should still be placeable there.
	if not building_data.is_outdoor and validation_location.y >= 0:
		for col in building_data.width:
			var ground_room = Building.get_room_from_index(Vector2i(validation_location.x + col, 0))
			if ground_room is RoomOutsideBase:
				has_valid_target = false

	# check custom
	if custom_placement_check:
		has_valid_target = has_valid_target && custom_placement_check.call(validation_location)

	var can_place = has_valid_target && has_money

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_RIGHT \
	and not event.pressed:
		stop_building()
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
		and not event.pressed \
		and get_viewport().gui_get_hovered_control() == null:
		if can_place:
			var placement_location := validation_location
			var had_horse_post_before_build = Building.count_rooms_by_data(Building.room_data_horse_post) > 0
			SoundPlayer.play_construction_placed()
			for col in building_data.width:
				for row in building_data.height:
					var existing = Building.get_room_from_index(placement_location + Vector2i(col, row))
					if existing != null:
						existing.queue_free()
			Building.set_room(building_data, placement_location.x, placement_location.y)

			for col in building_data.width:
				var nx = placement_location.x + col
				var stair_below = Building.get_room_from_index(Vector2i(nx, placement_location.y - 1)) as RoomStairs
				if stair_below != null:
					stair_below.refresh_visuals()
				var stair_above = Building.get_room_from_index(Vector2i(nx, placement_location.y + building_data.height)) as RoomStairs
				if stair_above != null:
					stair_above.refresh_visuals()

			var drop_distance := location.y - placement_location.y
			if drop_distance > 0:
				var placed_room = Building.get_room_from_index(placement_location)
				if placed_room:
					var final_y = placed_room.position.y
					var impact_strength := 4.0 + float(min(drop_distance, 3))
					placed_room.position.y = location.y * -48.0
					var tween = placed_room.create_tween()
					tween.tween_property(placed_room, "position:y", final_y, 0.15 + drop_distance * 0.02) \
						.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
					tween.finished.connect(_refresh_tiles_after_fall.bind(impact_strength, 0.12), CONNECT_ONE_SHOT)
				else:
					Building.update_foreground_tiles()
					Camera.add_shake()
			else:
				Building.update_foreground_tiles()
				Camera.add_shake()

			if building_data == Building.room_data_horse_post and not had_horse_post_before_build:
				var placed_post := Building.get_room_from_index(placement_location) as RoomHorsePost
				if placed_post != null:
					Global.NPCSpawner.assign_loose_horse_to_post(placed_post)

			var repeat_data: RoomData = building_data
			var repeat_check = custom_placement_check
			var shift_held = Input.is_key_pressed(KEY_SHIFT)
			stop_building()
			ResourceHandler.change_resource(Enum.Resources.MONEY, -building_data.construction_price)
			if shift_held:
				start_building(repeat_data, repeat_check)
			return
		else:
			if not has_valid_target:
				if previous_notification:
					UiNotifications.try_kill(previous_notification)
				previous_notification = UiNotifications.create_notification_static("target invalid", mouse, load("res://assets/sprites/ui/icon_exclaimation.png"),  Color.RED)
				print("target invalid")
			elif not has_money:
				if previous_notification:
					UiNotifications.try_kill(previous_notification)
				previous_notification = UiNotifications.create_notification_static("not enough money", mouse, null,  Color.ORANGE)
				print("not enough money")

	var h_color = Color.GREEN if can_place else Color.YELLOW if has_valid_target else Color.RED
	var idx = 0
	for row in building_data.height:
		for col in building_data.width:
			highlights[idx].global_position = Building.global_position_from_room_index(location + Vector2i(col, row)) + Vector2(-24, -48)
			highlights[idx].modulate = h_color
			idx += 1
