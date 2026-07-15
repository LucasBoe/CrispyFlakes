extends Node2D

const ROOM_PLACE_DUST_SCENE = preload("res://scenes/room_place_dust_particles.tscn")
const INVALID_TARGET_ICON = preload("res://assets/sprites/ui/icon_exclaimation.png")

enum BuildMode {
	NONE,
	ROOM,
	INFRASTRUCTURE,
}

var is_placing = false
var has_valid_target = false
var build_mode: BuildMode = BuildMode.NONE
var building_data: RoomData
var infrastructure_data : InfrastructureData = null
var location : Vector2i
var landed_location : Vector2i
var highlights : Array = []
var custom_placement_check = null

var previous_notification = null
var _invalid_target_reason := "target invalid"
var _invalid_target_icon: Texture = null

func start_building(data : RoomData, check):
	build_mode = BuildMode.ROOM
	self.building_data = data
	self.infrastructure_data = null
	self.custom_placement_check = check
	is_placing = true
	_prepare_highlights(data.width * data.height)
	Global.UI.selection.block_context_menu(self)

func start_building_infrastructure(data, check = null):
	build_mode = BuildMode.INFRASTRUCTURE
	self.infrastructure_data = data
	self.building_data = null
	self.custom_placement_check = check
	is_placing = true
	_prepare_highlights(data.width * data.height)
	if data.layer_name == BuildingInfrastructure.WATER_LAYER:
		Building.infrastructure.show_water_info()
	Global.UI.selection.block_context_menu(self)

func stop_building():
	is_placing = false
	build_mode = BuildMode.NONE
	if infrastructure_data != null and infrastructure_data.layer_name == BuildingInfrastructure.WATER_LAYER:
		Building.infrastructure.hide_water_info()
	building_data = null
	infrastructure_data = null
	Global.UI.selection.unblock_context_menu(self)
	_clear_highlights()

func _prepare_highlights(count: int) -> void:
	_clear_highlights()
	var anchor_room := _get_highlight_anchor_room()
	if anchor_room == null:
		return
	for _i in count:
		highlights.append(RoomHighlighter.request_rect(anchor_room, Color.WHITE, 2, RoomHighlighter.Priority.SELECTION))

func _clear_highlights() -> void:
	for h in highlights:
		RoomHighlighter.dispose(h)
	highlights.clear()

func _get_highlight_anchor_room() -> RoomBase:
	for floor in Building.floors.values():
		for room in floor.values():
			return room as RoomBase
	return null

func _get_active_data():
	return building_data if build_mode == BuildMode.ROOM else infrastructure_data

func _is_building_room() -> bool:
	return build_mode == BuildMode.ROOM

func _is_digging_room() -> bool:
	return building_data == Building.room_data_digging

func _should_use_above_ground_fall(target_location: Vector2i) -> bool:
	if not _is_building_room():
		return false
	return not building_data.is_outdoor and target_location.y >= 0

func _requires_existing_empty_basement_footprint(target_location: Vector2i) -> bool:
	return _is_building_room() and not _is_digging_room() and target_location.y < 0

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
			if _requires_existing_empty_basement_footprint(target_location):
				if cell is not RoomEmpty:
					return false
				continue
			if cell != null and not cell is RoomEmpty:
				return false
	return true

func _set_invalid_target_reason(reason: String, icon: Texture = null) -> void:
	_invalid_target_reason = reason
	_invalid_target_icon = icon

func _reset_invalid_target_reason() -> void:
	_set_invalid_target_reason("target invalid", INVALID_TARGET_ICON)

func _validate_room_footprint(target_location: Vector2i) -> bool:
	for col in building_data.width:
		for row in building_data.height:
			var cell_location := target_location + Vector2i(col, row)
			var cell = Building.get_room_from_index(cell_location)
			if _requires_existing_empty_basement_footprint(target_location):
				if cell == null:
					_set_invalid_target_reason("requires digging first", Enum.placement_limit_to_icon(Enum.PlacementLimit.BELOW_GROUND))
					return false
				if cell is RoomDigging:
					_set_invalid_target_reason("digging in progress")
					return false
				if cell is not RoomEmpty:
					_set_invalid_target_reason("space occupied")
					return false
				continue
			if cell != null and not cell is RoomEmpty:
				_set_invalid_target_reason("space occupied")
				return false
	return true

func _refresh_tiles_after_fall(impact_strength: float, impact_duration: float, room: Node2D) -> void:
	Building.update_foreground_tiles()
	Camera.add_shake(impact_strength, impact_duration)
	if is_instance_valid(room):
		_spawn_place_dust(room)

func _input(event):
	if not is_placing:
		return

	var active_data = _get_active_data()
	if active_data == null:
		return

	var mouse = get_global_mouse_position()
	location = Building.round_room_index_from_global_position(mouse)
	var validation_location := location
	var has_wrong_placement_category = false
	_reset_invalid_target_reason()

	if _is_building_room():
		landed_location = _get_landed_location(location)
		validation_location = location if _has_direct_empty_override(location) else landed_location

		has_valid_target = _validate_room_footprint(location)
		if validation_location != location:
			has_valid_target = has_valid_target && _validate_room_footprint(validation_location)

		var has_adjacent_room_or_is_ground_floor = false
		if location.y < 0:
			for col in building_data.width:
				for row in building_data.height:
					var cell = location + Vector2i(col, row)
					for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						if Building.get_room_from_index(cell + dir):
							has_adjacent_room_or_is_ground_floor = true
		elif _should_use_above_ground_fall(location):
			has_adjacent_room_or_is_ground_floor = true
		else:
			for col in building_data.width:
				if Building.get_room_from_index(location + Vector2i(col, building_data.height)):
					has_adjacent_room_or_is_ground_floor = true
				if Building.get_room_from_index(location + Vector2i(col, -1)):
					has_adjacent_room_or_is_ground_floor = true
				if location.y == 0:
					has_adjacent_room_or_is_ground_floor = true

		if has_valid_target and not has_adjacent_room_or_is_ground_floor:
			if location.y < 0:
				_set_invalid_target_reason("connect to existing room")
			else:
				_set_invalid_target_reason("needs support below")
			has_valid_target = false

		if not building_data.is_outdoor and validation_location.y >= 0:
			for col in building_data.width:
				var ground_room = Building.get_room_from_index(Vector2i(validation_location.x + col, 0))
				if ground_room is RoomOutsideBase:
					has_valid_target = false
					_set_invalid_target_reason("requires indoor room")

		match building_data.placement_limit:
			Enum.PlacementLimit.ABOVE_GROUND:
				if validation_location.y < 0:
					has_valid_target = false
					has_wrong_placement_category = true
					_set_invalid_target_reason("only above ground", Enum.placement_limit_to_icon(building_data.placement_limit))
			Enum.PlacementLimit.BELOW_GROUND:
				if validation_location.y >= 0:
					has_valid_target = false
					has_wrong_placement_category = true
					_set_invalid_target_reason("only below ground", Enum.placement_limit_to_icon(building_data.placement_limit))
	else:
		landed_location = location
		var placement_check: Dictionary = Building.infrastructure.can_place(infrastructure_data, validation_location)
		has_valid_target = placement_check.valid
		if not has_valid_target:
			_set_invalid_target_reason(placement_check.reason)

	if custom_placement_check:
		var custom_valid: bool = custom_placement_check.call(validation_location)
		if not custom_valid:
			_set_invalid_target_reason(_get_custom_placement_invalid_reason(validation_location))
		has_valid_target = has_valid_target && custom_valid

	var has_money = ResourceHandler.has_money(active_data.construction_price)
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
			var repeat_room_data: RoomData = building_data
			var repeat_infrastructure_data = infrastructure_data
			var repeat_mode := build_mode
			var repeat_check = custom_placement_check
			var shift_held = Input.is_key_pressed(KEY_SHIFT)

			if _is_building_room():
				SoundPlayer.play_construction_placed()
				for col in building_data.width:
					for row in building_data.height:
						var existing = Building.get_room_from_index(placement_location + Vector2i(col, row))
						if existing != null:
							existing.queue_free()
				Building.set_room(building_data, placement_location.x, placement_location.y)

				Building.refresh_adjacent_stair_visuals(placement_location.x, placement_location.y, building_data.width, building_data.height)

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
						tween.finished.connect(_refresh_tiles_after_fall.bind(impact_strength, 0.12, placed_room), CONNECT_ONE_SHOT)
					else:
						Building.update_foreground_tiles()
						Camera.add_shake()
						var placed_room_a = Building.get_room_from_index(placement_location)
						if placed_room_a != null:
							_spawn_place_dust(placed_room_a)
				else:
					Building.update_foreground_tiles()
					Camera.add_shake()
					var placed_room_b = Building.get_room_from_index(placement_location)
					if placed_room_b != null:
						_spawn_place_dust(placed_room_b)

				if building_data == Building.room_data_horse_post:
					var placed_post := Building.get_room_from_index(placement_location) as RoomHorsePost
					if placed_post != null:
						Global.NPCSpawner.assign_loose_horse_to_post(placed_post)
			else:
				if infrastructure_data.layer_name == &"water":
					SoundPlayer.play_pipe_placed(mouse)
				else:
					SoundPlayer.play_construction_placed()
				Building.infrastructure.place(infrastructure_data, placement_location)
				Camera.add_shake(2.0, 0.08)

			stop_building()
			ResourceHandler.change_resource(Enum.Resources.MONEY, -active_data.construction_price)
			if shift_held:
				if repeat_mode == BuildMode.ROOM:
					start_building(repeat_room_data, repeat_check)
				else:
					start_building_infrastructure(repeat_infrastructure_data, repeat_check)
			return
		else:
			if not has_valid_target:
				if previous_notification:
					UiNotifications.try_kill(previous_notification)
				var icon = _invalid_target_icon
				if icon == null and has_wrong_placement_category and building_data != null:
					icon = Enum.placement_limit_to_icon(building_data.placement_limit)
				if icon == null:
					icon = INVALID_TARGET_ICON
				previous_notification = UiNotifications.create_notification_static(_invalid_target_reason, mouse, icon, Color.RED)
				print(_invalid_target_reason)
			elif not has_money:
				if previous_notification:
					UiNotifications.try_kill(previous_notification)
				previous_notification = UiNotifications.create_notification_static("not enough money", mouse, null,  Color.ORANGE)
				print("not enough money")

	var h_color = Color.GREEN if can_place else Color.YELLOW if has_valid_target else Color.RED
	var idx = 0
	for row in active_data.height:
		for col in active_data.width:
			highlights[idx].global_position = Building.global_position_from_room_index(location + Vector2i(col, row)) + Vector2(-24, -48)
			highlights[idx].modulate = h_color
			idx += 1

func _get_custom_placement_invalid_reason(target_location: Vector2i) -> String:
	if building_data == Building.room_data_digging:
		if target_location.y >= 0:
			return "only below ground"
		if Building.get_room_from_index(target_location) != null:
			return "space occupied"
		return "dig from existing room"
	if building_data != null and (building_data.is_outdoor or building_data == Building.room_data_bouncer):
		return "only ground floor"
	return "target invalid"

func _spawn_place_dust(room: Node2D) -> void:
	var dust := ROOM_PLACE_DUST_SCENE.instantiate() as GPUParticles2D
	room.add_child(dust)
	dust.global_position = room.get_center_floor_position()
	dust.finished.connect(dust.queue_free)
	dust.restart()
	dust.emitting = true
