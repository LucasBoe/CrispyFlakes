extends Node2D

var is_placing = false
var has_valid_target = false
var building_data : RoomData
var location : Vector2i
var highlights : Array = []
var custom_placement_check = null

var previous_notification = null
var _raw_location : Vector2i

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

# Returns the lowest free y in column x (Tetris gravity for above-ground rooms).
func _get_tetris_y(x: int) -> int:
	var y = 0
	while y < 100:
		var room = Building.get_room_from_index(Vector2i(x, y))
		if room == null or room is RoomEmpty:
			return y
		y += 1
	return y

func _input(event):
	if not is_placing:
		return

	var mouse = get_global_mouse_position()
	_raw_location = Building.round_room_index_from_global_position(mouse + Vector2(24,0))

	# Outdoor rooms always use the raw mouse location (custom_placement_check enforces y==0).
	# Basement rooms (y < 0) use raw location — adjacency rules apply instead of gravity.
	# Above-ground indoor rooms snap highlight to the lowest free slot in the column.
	if _raw_location.y >= 0 and not building_data.is_outdoor:
		var base_y = 0
		for col in building_data.width:
			base_y = max(base_y, _get_tetris_y(_raw_location.x + col))
		location = Vector2i(_raw_location.x, base_y)
	else:
		location = _raw_location

	has_valid_target = true
	for col in building_data.width:
		for row in building_data.height:
			var cell = Building.get_room_from_index(location + Vector2i(col, row))
			if cell != null and not cell is RoomEmpty:
				has_valid_target = false
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
	if not building_data.is_outdoor and location.y >= 0:
		for col in building_data.width:
			var ground_room = Building.get_room_from_index(Vector2i(location.x + col, 0))
			if ground_room is RoomOutsideBase:
				has_valid_target = false

	# check custom
	if custom_placement_check:
		has_valid_target = has_valid_target && custom_placement_check.call(location)

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
			var had_horse_post_before_build = Building.count_rooms_by_data(Building.room_data_horse_post) > 0
			SoundPlayer.play_construction_placed()
			for col in building_data.width:
				for row in building_data.height:
					var existing = Building.get_room_from_index(location + Vector2i(col, row))
					if existing != null:
						existing.queue_free()
			Building.set_room(building_data, location.x, location.y)
			Building.update_foreground_tiles()

			# Tween the placed room down from the cursor y to its landed position
			var drop_distance = _raw_location.y - location.y
			if drop_distance > 0:
				var placed_room = Building.get_room_from_index(location)
				if placed_room:
					var final_y = placed_room.position.y
					placed_room.position.y = _raw_location.y * -48.0
					var tween = placed_room.create_tween()
					tween.tween_property(placed_room, "position:y", final_y, 0.15 + drop_distance * 0.02) \
						.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

			if building_data == Building.room_data_horse_post and not had_horse_post_before_build:
				var placed_post := Building.get_room_from_index(location) as RoomHorsePost
				if placed_post != null:
					Global.NPCSpawner.assign_loose_horse_to_post(placed_post)

			stop_building()
			ResourceHandler.change_resource(Enum.Resources.MONEY, -building_data.construction_price)
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
			highlights[idx].global_position = Building.global_position_from_room_index(location + Vector2i(col, row)) + Vector2(0, -24)
			highlights[idx].modulate = h_color
			idx += 1
