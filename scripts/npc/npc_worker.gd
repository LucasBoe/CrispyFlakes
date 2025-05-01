extends NPC

var current_job = Enum.Jobs.IDLE
var isPickedUp = false
var pickUpOrigin

func _process(delta):
	if isPickedUp:
		global_position = get_global_mouse_position()
		
	if Behaviour.has_behaviour:
		return
		
	Behaviour.set_behaviour_from_job(current_job);
	

func _input_event(viewport, event, shape_idx):
	if event.is_action_pressed("click"):
		isPickedUp = true
		Navigation.set_process(false)
		pickUpOrigin = global_position

func _input(event):
	
	if not isPickedUp:
		return
	
	if event.is_action_released("click"):
		var room = Global.building.get_closest_room_of_type(RoomEmpty, global_position)
		if room:
			global_position = room.global_position + Vector2(24,0)
			Navigation.stop_navigation()
			Animator.direction = Vector2.ZERO
		else:
			global_position = pickUpOrigin
		isPickedUp = false
		Navigation.set_process(true)
		print("released")
