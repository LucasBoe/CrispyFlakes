extends NPC

var current_job = Enum.Jobs.IDLE
var current_job_room = null
var pickUpOrigin

var current_job_room_highlight = null
var new_job_room_highlight = null
var new_room_highlight = null

static var picked_up_npc : NPC = null

func _process(delta):
	if picked_up_npc == self:
		global_position = get_global_mouse_position()
		
	if Behaviour.has_behaviour:
		return
		
	Behaviour.set_behaviour_from_job(current_job);

func click_on_self():
	
	if picked_up_npc != null:
		return;		
		
	picked_up_npc = self
	Navigation.set_process(false)
	pickUpOrigin = global_position

func _input(event):
	
	if picked_up_npc != self:
		#if (assignmentIndicator.visible):
		#	assignmentIndicator.visible = false
		return
		
	var targetPos = null
	
	var room : RoomEmpty = Global.Building.get_closest_room_of_type(RoomEmpty, global_position)
	if room:
		targetPos = room.global_position + Vector2(24,0)

	#if not assignmentIndicator.visible:
	#	assignmentIndicator.visible = true
	
	if not current_job_room_highlight && current_job != Enum.Jobs.IDLE && current_job_room:
		current_job_room_highlight = RoomHighlighter.request_rect(current_job_room, Color(1,1,1,0.5))
		
	if not new_room_highlight && room:
		new_room_highlight = RoomHighlighter.request_rect(room)
		
	if targetPos && new_room_highlight:
		new_room_highlight.global_position = room.get_center_position()
		
	if room && room.associatedJob:
		if not new_job_room_highlight:
			new_job_room_highlight = RoomHighlighter.request_arrow(room)
		new_job_room_highlight.global_position = targetPos + Vector2(0,-16)
	else:
		RoomHighlighter.dispose(new_job_room_highlight)	
		new_job_room_highlight = null
	
	if event.is_action_released("click"):
		if targetPos:
			global_position = targetPos
			Navigation.stop_navigation()
			checkJobChange(room)
			Animator.direction = Vector2.ZERO
		else:
			global_position = pickUpOrigin
		picked_up_npc = null

		RoomHighlighter.dispose(current_job_room_highlight)
		current_job_room_highlight = null

		RoomHighlighter.dispose(new_job_room_highlight)
		new_job_room_highlight = null
		
		RoomHighlighter.dispose(new_room_highlight)
		new_room_highlight = null		
		
		Navigation.set_process(true)
		print("released")

func checkJobChange(room : RoomEmpty):
	var newJob = room.associatedJob
	current_job_room = room
	if not newJob:
		newJob = Enum.Jobs.IDLE
			
	if current_job != newJob:
		print(str("change job to ", Enum.Jobs.keys()[newJob]))	
		current_job = newJob
		
		Behaviour.set_behaviour_from_job(current_job);
