extends NPC
class_name NPCWorker

var current_job = Enum.Jobs.IDLE
var current_job_room = null
var pickUpOrigin
 
var current_job_room_highlight = null
var new_job_room_highlight = null
var new_room_highlight = null

var salary = 6
var character_name = ""

const possible_names = [
"Wyatt McGraw",
"Jesse Dalton",
"Silas Crowley",
"Clint Hargrove",
"Colt Ransom",
"Jedediah Boone",
"Virgil Haines",
"Doc Hollister",
"Amos Redford",
"Rufus Calhoun",
"Levi Pickett",
"Zeke Hartwell",
"Hank Mercer",
"Clay Thornton",
"Gus McAllister",
"Boone Kincaid",
"Eli Sutter",
"Seth Callahan",
"Otis Barrow",
"Abe Whitlock",
"Calvin Prescott",
"Emmett Tolland",
"Fletcher Grady",
"Gideon Pruitt",
"Harvey Bledsoe",
"Irving Tatum",
"Jasper Sloane",
"Kip Hardin",
"Leland Driscoll",
"Miles Sorrell",
"Nolan Breckin",
"Orville Tanner",
"Percy Maddox",
"Quincy Marlow",
"Roscoe Vance",
"Sawyer Keene",
"Thaddeus Wicker",
"Tucker Hollis",
"Wade Cavanaugh",
"Yancy Cole",
"Brody Lang",
"Casey Ridley",
"Dusty Monroe",
"Earl Dwyer",
"Franklin Rourke",
"Graham Pike",
"Howell Strickland",
"Ike Malloy",
"Jonah Merritt",
"Kendrick Lowry",
"Lonnie Rusk",
"Marshall Dempsey",
"Newton Briggs",
"Owen Talbot",
"Porter Galloway",
"Reed Huxley",
"Sterling Vaughn",
"Travis Morrow",
"Vernon Slade",
"Walker Brannigan",
"Rhett Winslow",
"Beau Whitaker",
"Jebediah Knox",
"Ryder Folsom",
"Darby Hawke",
"Cyrus Lockwood",
"Finn O'Riley",
"Garrett Blackwell",
"Hayes Donnelly",
"Judd Kilpatrick",
"Kellan Ashford",
"Luther McKenna",
"Monty Barlow",
"Nate Buckner",
"Ransom DeWitt",
"Shane Everhart",
"Temple Rawlings",
"Vince Harland",
"Wesley Kearns",
"Zachary Flint",
"Archie Baines",
"Benji Carver",
"Carlisle Quinn",
"Duncan Mears",
"Edwin Larkin",
"Felix Harlan",
"Griffin Mallory",
"Hugh Redd",
"Isaac Dunbar",
"Jeremiah Holt",
"Kirkland Shaw",
"Lyle Montrose",
"Marty Ketter",
"Noah Burnett",
"Oren Wycliff",
"Perry Stokes",
"Rowan Bickford",
"Stuart Blaine",
"Terrence Cobb",
"Vaughn Redding",
"Wilbur Kersey",
"Zebediah Price",
"Abigail Hart",
"Ada Mayfield",
"Alma Prescott",
"Annabelle Crowe",
"Beatrice Hensley",
"Belle Whitman",
"Clara McCoy",
"Daisy Kellan",
"Delilah Rose",
"Ellie Sumner",
"Faye Langley",
"Georgia Wren",
"Hattie Sinclair",
"Ivy Calloway",
"Josie Caldwell",
"Kitty Marston",
"Loretta Sloan",
"Maeve Holliday",
"Molly Redfern",
"Nora Penrose",
"Opal Greer",
"Pearl Whitlock",
"Rosemary Keene",
"Sadie Barlow",
"Tessa Hartley",
"Violet Quinn",
"Willa Drury",
"Bonnie Raines",
"Cora Tolland",
"Dottie Kincaid",
"Etta Galloway",
"Flora Maddox",
"Greta Winslow",
"Honor Sutter",
"June Calhoun",
"Lillian Vance",
"Millie Talbot",
"Nevaeh? nope"
]

@onready var anim : Sprite2D = $AnimationModule 
var possible_sprites = ["res://assets/sprites/worker_charesmatitc.png", "res://assets/sprites/worker_fast.png", "res://assets/sprites/worker_strongt.png"]

static var picked_up_npc : NPC = null

func _ready():
	super._ready()
	character_name = possible_names.pick_random()
	anim.texture = load(possible_sprites.pick_random())

func _process(delta):
	if picked_up_npc == self:
		global_position = get_global_mouse_position()
		
	if Behaviour.has_behaviour:
		return
		
	change_job(current_job)

func change_job(new):
	current_job = new
	Behaviour.set_behaviour_from_job(current_job);
	JobHandler.on_job_changed(self, current_job)
	print(str("change job to ", Enum.Jobs.keys()[current_job]))
	
	if new == 0:
		return
		
	UiNotifications.create_notification_dynamic(str("New Job: ", Enum.Jobs.keys()[new]), self, Vector2(0,-32))	

func click_on():
	
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
	
	var room : RoomBase = Global.Building.get_closest_room_of_type(RoomBase, global_position, null, Vector2(-24,0))
	if room:
		targetPos = room.global_position + Vector2(24,0)

	#if not assignmentIndicator.visible:
	#	assignmentIndicator.visible = true
	
	if not current_job_room_highlight && current_job != Enum.Jobs.IDLE && current_job_room:
		current_job_room_highlight = RoomHighlighter.request_rect(current_job_room, Color(1,0,1,0.5))
		
	print(room.associatedJob)
	
	if not new_room_highlight && room:
		new_room_highlight = RoomHighlighter.request_rect(room)
		
	if targetPos && new_room_highlight:
		new_room_highlight.global_position = room.get_center_position()
		
	if room and new_room_highlight and current_job_room != room:
		new_room_highlight.modulate = Color.GREEN if room.associatedJob else Color.WHITE
		
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

func checkJobChange(room : RoomBase):
	var new_job = room.associatedJob
	current_job_room = room
	
	if new_job == null:
		new_job = Enum.Jobs.IDLE
			
	if current_job != new_job:
		change_job(new_job)
