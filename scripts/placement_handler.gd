extends Node2D

var is_placing = false
var has_valid_target = false
var building
var cost
var location
var highlight : Sprite2D = null
var custom_placement_check = null

var previous_notification = null

func start_building(building : PackedScene, cost : int, custom_placement_check):
	self.building = building
	self.custom_placement_check = custom_placement_check
	self.cost = cost
	is_placing = true
	
	if not highlight:
		highlight = RoomHighlighter.request_rect(Global.Building.floors[0][0])
	
func stop_building():
	if highlight:
		is_placing = false
		RoomHighlighter.dispose(highlight)
		highlight = null
	
func _process(delta):
	if not is_placing:
		return
		
	var mouse = get_global_mouse_position()
	location = Global.Building.round_room_index_from_global_position(mouse + Vector2(24,0))
	has_valid_target = Global.Building.get_room_from_index(location) == null
	var has_money = ResourceHandler.resources[Enum.Resources.MONEY] >= cost
	
	# check adjacent_rooms
	var has_adjacent_room_or_is_ground_floor = false
	
	if Global.Building.get_room_from_index(location + Vector2i.UP):
		has_adjacent_room_or_is_ground_floor = true
	
	if Global.Building.get_room_from_index(location + Vector2i.DOWN):
		has_adjacent_room_or_is_ground_floor = true
		
	# check grund level
	if location.y == 0:
		has_adjacent_room_or_is_ground_floor = true
		
	has_valid_target = has_valid_target && has_adjacent_room_or_is_ground_floor
	
	# check custom
	if custom_placement_check:
		has_valid_target = has_valid_target && custom_placement_check.call(location)
	
	var can_place = has_valid_target && has_money
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		stop_building()
		return
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if can_place:
			SoundPlayer.construction_placed.play()
			Global.Building.set_room(building, location.x, location.y)
			Global.Building.update_foreground_tiles()
			stop_building()
			ResourceHandler.change_resource(Enum.Resources.MONEY, -cost)
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
		var highlight_target_pos = Global.Building.global_position_from_room_index(location) + Vector2(0,-24)
		highlight.global_position = highlight_target_pos
		highlight.modulate = Color.GREEN if can_place else Color.YELLOW if has_valid_target else Color.RED
