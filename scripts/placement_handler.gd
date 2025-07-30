extends Node2D

var is_placing = false
var has_valid_target = false
var building
var cost
var location
var highlight : Sprite2D = null

func start_building(building : PackedScene, cost : int):
	self.building = building
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
	
	var can_place = has_valid_target && has_money
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		stop_building()
		return
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if can_place:
			Global.Building.set_room(building, location.x, location.y)
			Global.Building.update_foreground_tiles()
			stop_building()
			return
		else:
			if not has_valid_target:
				print("target invalid")
				UiNotifications.create_notification_static("target invalid", mouse, load("res://assets/sprites/ui/icon_exclaimation.png"),  Color.RED)
			elif not has_money:
				UiNotifications.create_notification_static("not enough money", mouse, null,  Color.ORANGE)
				print("not enough money")
	
	if highlight:
		var highlight_target_pos = Global.Building.global_position_from_room_index(location) + Vector2(0,-24)
		highlight.global_position = highlight_target_pos
		highlight.modulate = Color.GREEN if can_place else Color.RED
