extends Node2D

const ROOM_PLACE_DUST_SCENE = preload("res://scenes/room_place_dust_particles.tscn")
const INVALID_TARGET_ICON = preload("res://assets/sprites/ui/icon_exclaimation.png")

enum BuildMode {
	NONE,
	ROOM,
	INFRASTRUCTURE,
	CAGE,
}

var is_placing = false
var has_valid_target = false
var build_mode: BuildMode = BuildMode.NONE
var building_data: RoomData
var infrastructure_data : InfrastructureData = null
var cage_data : CageData = null
var location : Vector2i
var highlights : Array = []
var custom_placement_check = null

var previous_notification = null
var _invalid_target_reason := "target invalid"
var _invalid_target_icon: Texture = null

func _ready() -> void:
	Console.add_command("try_build_room", _console_try_build_room, ["room_type", "x", "y"], 3, "Builds a room like the player would: enforces placement rules and cost, and lands above-ground rooms on the stack (e.g. 'try_build_room bar 2 0').")

func _console_try_build_room(room_type : String, x : String, y : String) -> void:
	if not (x.is_valid_int() and y.is_valid_int()):
		Console.print_error("(x,y) must be integers, got (%s,%s)." % [x, y])
		return
	var path := "res://assets/resources/rooms/room_%s.tres" % room_type.strip_edges().to_lower()
	if not ResourceLoader.exists(path):
		Console.print_error("Unknown room type '%s' (expected a resource at %s)." % [room_type, path])
		return
	var result := try_build_room(load(path) as RoomData, Vector2i(int(x), int(y)))
	if result.valid:
		Console.print_line("Built '%s' at (%d,%d)." % [room_type, result.location.x, result.location.y])
	else:
		Console.print_error("Could not build '%s' at (%s,%s): %s." % [room_type, x, y, result.reason])

func start_building(data : RoomData, check):
	build_mode = BuildMode.ROOM
	self.building_data = data
	self.infrastructure_data = null
	self.custom_placement_check = check
	is_placing = true
	_prepare_highlights(data.width * data.height)
	if data == Building.room_data_stairs or data == Building.room_data_elevator:
		Building.show_stairs_info()
	Global.UI.selection.block_context_menu(self)

func start_building_infrastructure(data, check = null):
	build_mode = BuildMode.INFRASTRUCTURE
	self.infrastructure_data = data
	self.building_data = null
	self.cage_data = null
	self.custom_placement_check = check
	is_placing = true
	_prepare_highlights(data.width * data.height)
	if data.layer_name == BuildingInfrastructure.WATER_LAYER:
		Building.infrastructure.show_water_info()
	if data.layer_name == BuildingInfrastructure.ELECTRICITY_LAYER:
		Building.infrastructure.show_electricity_info()
	Global.UI.selection.block_context_menu(self)

func start_building_cage(data : CageData, check = null):
	build_mode = BuildMode.CAGE
	self.cage_data = data
	self.building_data = null
	self.infrastructure_data = null
	self.custom_placement_check = check
	is_placing = true
	_prepare_highlights(data.width * data.height)
	Global.UI.selection.block_context_menu(self)

func stop_building():
	is_placing = false
	build_mode = BuildMode.NONE
	if infrastructure_data != null and infrastructure_data.layer_name == BuildingInfrastructure.WATER_LAYER:
		Building.infrastructure.hide_water_info()
	if infrastructure_data != null and infrastructure_data.layer_name == BuildingInfrastructure.ELECTRICITY_LAYER:
		Building.infrastructure.hide_electricity_info()
	if building_data == Building.room_data_stairs or building_data == Building.room_data_elevator:
		Building.hide_stairs_info()
	building_data = null
	infrastructure_data = null
	cage_data = null
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
	match build_mode:
		BuildMode.ROOM:
			return building_data
		BuildMode.CAGE:
			return cage_data
		_:
			return infrastructure_data

func _is_building_room() -> bool:
	return build_mode == BuildMode.ROOM

func _is_building_cage() -> bool:
	return build_mode == BuildMode.CAGE

func _should_use_above_ground_fall(data: RoomData, target_location: Vector2i) -> bool:
	return not data.is_outdoor and target_location.y >= 0

func _requires_existing_empty_basement_footprint(data: RoomData, target_location: Vector2i) -> bool:
	return data != Building.room_data_digging and target_location.y < 0

func _get_tetris_y(x: int) -> int:
	var y = 0
	while y < 100:
		var room = Building.get_room_from_index(Vector2i(x, y))
		if room == null:
			return y
		y += 1
	return y

func _has_direct_empty_override(data: RoomData, target_location: Vector2i) -> bool:
	if not _should_use_above_ground_fall(data, target_location):
		return false

	var has_empty := false
	for col in data.width:
		for row in data.height:
			var cell = Building.get_room_from_index(target_location + Vector2i(col, row))
			if cell is RoomEmpty:
				has_empty = true
			elif cell != null:
				return false
	return has_empty

func _get_landed_location(data: RoomData, target_location: Vector2i) -> Vector2i:
	if not _should_use_above_ground_fall(data, target_location):
		return target_location

	var base_y := 0
	for col in data.width:
		base_y = max(base_y, _get_tetris_y(target_location.x + col))
	return Vector2i(target_location.x, base_y)

func _set_invalid_target_reason(reason: String, icon: Texture = null) -> void:
	_invalid_target_reason = reason
	_invalid_target_icon = icon

func _reset_invalid_target_reason() -> void:
	_set_invalid_target_reason("target invalid", INVALID_TARGET_ICON)

func _reject(result: Dictionary, reason: String, icon: Texture = null) -> void:
	result.valid = false
	result.reason = reason
	result.icon = icon

func _validate_room_footprint(data: RoomData, target_location: Vector2i, result: Dictionary) -> void:
	for col in data.width:
		for row in data.height:
			var cell_location := target_location + Vector2i(col, row)
			var cell = Building.get_room_from_index(cell_location)
			if _requires_existing_empty_basement_footprint(data, target_location):
				if cell == null:
					_reject(result, "requires digging first", Enum.placement_limit_to_icon(Enum.PlacementLimit.BELOW_GROUND))
					return
				if cell is RoomDigging:
					_reject(result, "digging in progress")
					return
				if cell is not RoomEmpty:
					_reject(result, "space occupied")
					return
				continue
			if cell != null and not cell is RoomEmpty:
				_reject(result, "space occupied")
				return

func _has_support(data: RoomData, target_location: Vector2i) -> bool:
	if target_location.y < 0:
		for col in data.width:
			for row in data.height:
				var cell = target_location + Vector2i(col, row)
				for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if Building.get_room_from_index(cell + dir):
						return true
		return false
	if _should_use_above_ground_fall(data, target_location) or target_location.y == 0:
		return true
	for col in data.width:
		if Building.get_room_from_index(target_location + Vector2i(col, data.height)):
			return true
		if Building.get_room_from_index(target_location + Vector2i(col, -1)):
			return true
	return false

## Checks whether `data` can be placed when targeting `target_location`, using the same rules
## as the mouse build flow (money excluded). Rooms above ground "fall" onto the stack below, so
## the room actually lands at `result.location`, which may differ from `target_location`.
## Returns { valid, reason, icon, wrong_category, location }.
func evaluate_room_placement(data: RoomData, target_location: Vector2i, custom_check = null) -> Dictionary:
	var result := {
		valid = true,
		reason = "target invalid",
		icon = INVALID_TARGET_ICON,
		wrong_category = false,
		location = target_location,
	}

	var validation_location := target_location
	if not _has_direct_empty_override(data, target_location):
		validation_location = _get_landed_location(data, target_location)
	result.location = validation_location

	_validate_room_footprint(data, target_location, result)
	if result.valid and validation_location != target_location:
		_validate_room_footprint(data, validation_location, result)

	if result.valid and not _has_support(data, target_location):
		_reject(result, "connect to existing room" if target_location.y < 0 else "needs support below")

	if not data.is_outdoor and validation_location.y >= 0:
		for col in data.width:
			if Building.get_room_from_index(Vector2i(validation_location.x + col, 0)) is RoomOutsideBase:
				_reject(result, "requires indoor room")

	match data.placement_limit:
		Enum.PlacementLimit.ABOVE_GROUND:
			if validation_location.y < 0:
				_reject(result, "only above ground", Enum.placement_limit_to_icon(data.placement_limit))
				result.wrong_category = true
		Enum.PlacementLimit.BELOW_GROUND:
			if validation_location.y >= 0:
				_reject(result, "only below ground", Enum.placement_limit_to_icon(data.placement_limit))
				result.wrong_category = true

	if custom_check and not custom_check.call(validation_location):
		_reject(result, _get_custom_placement_invalid_reason(data, validation_location))

	return result

## Places `data` at a location already validated by evaluate_room_placement() and charges its
## price. `drop_distance` > 0 animates the room falling from that many rows above.
func place_room(data: RoomData, placement_location: Vector2i, drop_distance: int = 0) -> void:
	SoundPlayer.play_construction_placed()
	for col in data.width:
		for row in data.height:
			var existing = Building.get_room_from_index(placement_location + Vector2i(col, row))
			if existing != null:
				existing.queue_free()
	Building.set_room(data, placement_location.x, placement_location.y)

	Building.refresh_adjacent_stair_visuals(placement_location.x, placement_location.y, data.width, data.height)

	var placed_room = Building.get_room_from_index(placement_location)
	if drop_distance > 0 and placed_room:
		var final_y = placed_room.position.y
		var impact_strength := 4.0 + float(min(drop_distance, 3))
		placed_room.position.y = (placement_location.y + drop_distance) * -48.0
		var tween = placed_room.create_tween()
		tween.tween_property(placed_room, "position:y", final_y, 0.15 + drop_distance * 0.02) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(_refresh_tiles_after_fall.bind(impact_strength, 0.12, placed_room), CONNECT_ONE_SHOT)
	else:
		Building.update_foreground_tiles()
		Camera.add_shake()
		if placed_room != null:
			_spawn_place_dust(placed_room)

	if data == Building.room_data_horse_post:
		var placed_post := placed_room as RoomHorsePost
		if placed_post != null:
			Global.NPCSpawner.assign_loose_horse_to_post(placed_post)

	MoneyHandler.spend(data.construction_price, "Construction")

## Non-mouse build entry point (autoplay bot, scripts): validates, checks money, then places.
## Returns the evaluate_room_placement() result; on success the room was built at result.location.
func try_build_room(data: RoomData, target_location: Vector2i, custom_check = null) -> Dictionary:
	var result := evaluate_room_placement(data, target_location, custom_check)
	if result.valid and not MoneyHandler.has_money(data.construction_price):
		_reject(result, "not enough money")
	if result.valid:
		place_room(data, result.location, target_location.y - result.location.y)
	return result

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
		var evaluation := evaluate_room_placement(building_data, location, custom_placement_check)
		validation_location = evaluation.location
		has_valid_target = evaluation.valid
		has_wrong_placement_category = evaluation.wrong_category
		if not has_valid_target:
			_set_invalid_target_reason(evaluation.reason, evaluation.icon)
	else:
		var placement_check: Dictionary
		if _is_building_cage():
			placement_check = ElevatorHandler.can_place_cage(validation_location)
		else:
			placement_check = Building.infrastructure.can_place(infrastructure_data, validation_location)
		has_valid_target = placement_check.valid
		if not has_valid_target:
			_set_invalid_target_reason(placement_check.reason)

	var has_money = MoneyHandler.has_money(active_data.construction_price)
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
			var repeat_cage_data: CageData = cage_data
			var repeat_mode := build_mode
			var repeat_check = custom_placement_check
			var shift_held = Input.is_key_pressed(KEY_SHIFT)

			if _is_building_room():
				place_room(building_data, placement_location, location.y - placement_location.y)
			elif _is_building_cage():
				SoundPlayer.play_construction_placed()
				ElevatorHandler.place_cage(placement_location.x, placement_location.y)
				Camera.add_shake(2.0, 0.08)
			else:
				if infrastructure_data.layer_name == &"water":
					SoundPlayer.play_pipe_placed(mouse)
				else:
					SoundPlayer.play_construction_placed()
				Building.infrastructure.place(infrastructure_data, placement_location)
				Camera.add_shake(2.0, 0.08)

			if not _is_building_room():
				MoneyHandler.spend(active_data.construction_price, "Construction")
			stop_building()
			if shift_held:
				match repeat_mode:
					BuildMode.ROOM:
						start_building(repeat_room_data, repeat_check)
					BuildMode.CAGE:
						start_building_cage(repeat_cage_data, repeat_check)
					_:
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

	var needed_highlight_count: int = active_data.width * active_data.height
	if highlights.size() != needed_highlight_count or highlights.any(func(h): return not is_instance_valid(h)):
		_prepare_highlights(needed_highlight_count)
	if highlights.size() != needed_highlight_count:
		return

	var h_color = Color.GREEN if can_place else Color.YELLOW if has_valid_target else Color.RED
	var idx = 0
	for row in active_data.height:
		for col in active_data.width:
			highlights[idx].global_position = Building.global_position_from_room_index(location + Vector2i(col, row)) + Vector2(-24, -48)
			highlights[idx].modulate = h_color
			idx += 1

func _get_custom_placement_invalid_reason(data: RoomData, target_location: Vector2i) -> String:
	if data == Building.room_data_digging:
		if target_location.y >= 0:
			return "only below ground"
		if Building.get_room_from_index(target_location) != null:
			return "space occupied"
		return "dig from existing room"
	if data.is_outdoor or data == Building.room_data_bouncer:
		return "only ground floor"
	return "target invalid"

func _spawn_place_dust(room: Node2D) -> void:
	var dust := ROOM_PLACE_DUST_SCENE.instantiate() as GPUParticles2D
	room.add_child(dust)
	dust.global_position = room.get_center_floor_position()
	dust.finished.connect(dust.queue_free)
	dust.restart()
	dust.emitting = true
