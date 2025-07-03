extends NPC

var current_job = Enum.Jobs.IDLE
var pickUpOrigin

static var picked_up_npc : NPC = null

@onready var assignmentIndicator : AnimatedSprite2D = $RoomAssignmentIndiactor

func _ready():
	assignmentIndicator.visible = false

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
	
	var room = Global.Building.get_closest_room_of_type(RoomEmpty, global_position)
	if room:
		targetPos = room.global_position + Vector2(24,0)

	if not assignmentIndicator.visible:
		assignmentIndicator.visible = true
		
	if targetPos:
		assignmentIndicator.global_position = targetPos + Vector2(0,-16)
	
	if event.is_action_released("click"):
		if targetPos:
			global_position = targetPos
			Navigation.stop_navigation()
			checkJobChange(room)
			Animator.direction = Vector2.ZERO
		else:
			global_position = pickUpOrigin
		picked_up_npc = null

		assignmentIndicator.visible = false
		Navigation.set_process(true)
		print("released")

func checkJobChange(room : RoomEmpty):
	var newJob = room.associatedJob
	if not newJob:
		newJob = Enum.Jobs.IDLE
			
	if current_job != newJob:
		print(str("change job to ", Enum.Jobs.keys()[newJob]))	
		current_job = newJob
		
		Behaviour.set_behaviour_from_job(current_job);
