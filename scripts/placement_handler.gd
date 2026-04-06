extends Node2D

var is_placing = false
var has_valid_target = false
var building_data : RoomData
var location : Vector2i
var highlight : Sprite2D = null
var custom_placement_check = null

var previous_notification = null
var _raw_location : Vector2i

func start_building(data : RoomData, check):
	self.building_data = data
	self.custom_placement_check = check
	is_placing = true

	if not highlight:
		highlight = RoomHighlighter.request_rect(Global.Building.floors[0][0])

func stop_building():
	if highlight:
		is_placing = false
		RoomHighlighter.dispose(highlight)
		highlight = null

# Returns the lowest free y in column x (Tetris gravity for above-ground rooms).
func _get_tetris_y(x: int) -> int:
	var y = 0
	while y < 100:
		var room = Global.Building.get_room_from_index(Vector2i(x, y))
		if room == null or room is RoomEmpty:
			return y
		y += 1
	return y

func _input(event):
	if not is_placing:
		return

	var mouse = get_global_mouse_position()
	_raw_location = Global.Building.round_room_index_from_global_position(mouse + Vector2(24,0))

	# Outdoor rooms always use the raw mouse location (custom_placement_check enforces y==0).
	# Basement rooms (y < 0) use raw location — adjacency rules apply instead of gravity.
	# Above-ground indoor rooms snap highlight to the lowest free slot in the column.
	if _raw_location.y >= 0 and not building_data.is_outdoor:
		location = Vector2i(_raw_location.x, _get_tetris_y(_raw_location.x))
	else:
		location = _raw_location

	var room_at_location = Global.Building.get_room_from_index(location)
	has_valid_target = room_at_location == null or room_at_location is RoomEmpty
	var has_money = ResourceHandler.has_money(building_data.construction_price)

	# Adjacency check
	var has_adjacent_room_or_is_ground_floor = false

	if location.y < 0:
		# Basement: require adjacency in all 4 directions (left, right, up, down)
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if Global.Building.get_room_from_index(location + dir):
				has_adjacent_room_or_is_ground_floor = true
				break
	else:
		# Above ground: require a room above or below, or be on ground floor
		if Global.Building.get_room_from_index(location + Vector2i.UP):
			has_adjacent_room_or_is_ground_floor = true
		if Global.Building.get_room_from_index(location + Vector2i.DOWN):
			has_adjacent_room_or_is_ground_floor = true
		if location.y == 0:
			has_adjacent_room_or_is_ground_floor = true

	has_valid_target = has_valid_target && has_adjacent_room_or_is_ground_floor

	# Indoor rooms cannot be placed in a column where y=0 is an outdoor room
	if not building_data.is_outdoor:
		var ground_room = Global.Building.get_room_from_index(Vector2i(location.x, 0))
		if ground_room is RoomOutsideBase:
			has_valid_target = false

	# check custom
	if custom_placement_check:
		has_valid_target = has_valid_target && custom_placement_check.call(location)

	var can_place = has_valid_target && has_money

	DebugLog.info(get_viewport().gui_get_hovered_control())

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and not event.pressed \
	and get_viewport().gui_get_hovered_control() is UICloseHandler:#bottom most ui used for checking click on none ui
		if can_place:
			SoundPlayer.construction_placed.play()
			if room_at_location != null:
				room_at_location.queue_free()
			Global.Building.set_room(building_data, location.x, location.y)
			Global.Building.update_foreground_tiles()

			# Tween the placed room down from the cursor y to its landed position
			var drop_distance = _raw_location.y - location.y
			if drop_distance > 0:
				var placed_room = Global.Building.get_room_from_index(location)
				if placed_room:
					var final_y = placed_room.position.y
					placed_room.position.y = _raw_location.y * -48.0
					var tween = placed_room.create_tween()
					tween.tween_property(placed_room, "position:y", final_y, 0.15 + drop_distance * 0.02) \
						.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

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

	if highlight:
		var highlight_target_pos = Global.Building.global_position_from_room_index(_raw_location) + Vector2(0,-24)
		highlight.global_position = highlight_target_pos
		highlight.modulate = Color.GREEN if can_place else Color.YELLOW if has_valid_target else Color.RED
