extends NPC
class_name NPCWorker

enum SaloonFightResponse {
	FIGHT,
	FLEE,
}

var current_job = Enum.Jobs.IDLE
var current_job_room = null
var pick_up_origin
var available_rooms_highlights = []

var current_job_room_highlight = null
var new_job_room_highlight = null
var new_room_highlight = null

var salary = 6
var character_name = ""
var saloon_fight_response: SaloonFightResponse = SaloonFightResponse.FIGHT

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

static var picked_up_npc : NPC = null
static var was_dragging = false

const DRAG_THRESHOLD = 8.0
const MELEE_CONFLICT_ENGAGE_RANGE := 24.0
const FIGHT_ENERGY_REGEN_PER_SECOND := 0.2
var _drag_pending = false
var _drag_start_mouse = Vector2.ZERO

func _ready():
	super._ready()
	character_name = possible_names.pick_random()
	apply_trait_conflict_preference()

func _process(delta):
	super._process(delta)
	_regenerate_fight_energy(delta)

	if picked_up_npc == self:
		global_position = get_global_mouse_position()

	if Behaviour.has_behaviour:
		return

	change_job(current_job)

func _regenerate_fight_energy(delta: float) -> void:
	if Behaviour != null and Behaviour.behaviour_instance is FightBehaviour:
		return
	energy = minf(get_max_energy(), energy + FIGHT_ENERGY_REGEN_PER_SECOND * delta)

func apply_trait_conflict_preference() -> void:
	if Traits.forces_fight_response():
		saloon_fight_response = SaloonFightResponse.FIGHT
	elif Traits.refuses_voluntary_fights():
		saloon_fight_response = SaloonFightResponse.FLEE

func should_fight_conflicts() -> bool:
	if Traits.refuses_voluntary_fights():
		return false
	if Traits.forces_fight_response():
		return true
	return saloon_fight_response == SaloonFightResponse.FIGHT

func change_job(new):
	current_job = new
	Behaviour.set_behaviour_from_job(current_job);
	JobHandler.on_job_changed(self, current_job)

	if new == 0:
		return

	SoundPlayer.play_talk(global_position)
	UiNotifications.create_notification_dynamic(str("New Job: ", Enum.Jobs.keys()[new]), self, Vector2(0,-32))

func click_on():

	if picked_up_npc != null:
		return;

	was_dragging = false
	_drag_pending = true
	_drag_start_mouse = get_global_mouse_position()
	pick_up_origin = global_position

func _activate_drag():
	was_dragging = true
	picked_up_npc = self
	_drag_pending = false
	Navigation.set_process(false)

	available_rooms_highlights.clear()
	for room : RoomBase in Building.query.all_rooms_of_type(RoomBase):
		if room.associated_job == null:
			continue

		if not room.can_accept_worker(room.associated_job):
			continue

		var highlight = RoomHighlighter.request_rect(room, Color.GREEN_YELLOW, 1, RoomHighlighter.Priority.SELECTION)
		available_rooms_highlights.append(highlight)

func _input(event):

	if _drag_pending:
		if event.is_action_released("click"):
			_drag_pending = false
			return
		if get_global_mouse_position().distance_to(_drag_start_mouse) >= DRAG_THRESHOLD:
			_activate_drag()

	if picked_up_npc != self:
		#if (assignmentIndicator.visible):
		#	assignmentIndicator.visible = false
		return

	var target_pos = null

	var room : RoomBase = Building.query.closest_room_of_type(RoomBase, global_position, null, Vector2(-24,0))
	if room:
		target_pos = room.global_position + Vector2(24,0)

	#if not assignmentIndicator.visible:
	#	assignmentIndicator.visible = true

	if not current_job_room_highlight && current_job != Enum.Jobs.IDLE && current_job_room:
		current_job_room_highlight = RoomHighlighter.request_rect(current_job_room, Color(1,1,0,0.5), 2, RoomHighlighter.Priority.SELECTION)

	if not new_room_highlight && room:
		new_room_highlight = RoomHighlighter.request_rect(room, Color.WHITE, 2, RoomHighlighter.Priority.SELECTION)

	if target_pos && new_room_highlight:
		new_room_highlight.global_position = Vector2(room.global_position.x, room.global_position.y - room.data.height * 48)

	if room and new_room_highlight and current_job_room != room:
		new_room_highlight.modulate = Color.GREEN if room.associated_job else Color.WHITE

	if room && room.associated_job:
		if not new_job_room_highlight:
			new_job_room_highlight = RoomHighlighter.request_arrow(room)
		new_job_room_highlight.global_position = target_pos + Vector2(0,-16)
	else:
		RoomHighlighter.dispose(new_job_room_highlight)
		new_job_room_highlight = null

	if event.is_action_released("click"):
		if target_pos:
			global_position = target_pos
			Navigation.stop_navigation()
			if not try_stop_fight_in_room(room):
				if not try_arrest_in_room(room):
					try_change_job_based_on_room(room)
			Animator.direction = Vector2.ZERO
		else:
			global_position = pick_up_origin
		picked_up_npc = null

		RoomHighlighter.dispose(current_job_room_highlight)
		current_job_room_highlight = null

		RoomHighlighter.dispose(new_job_room_highlight)
		new_job_room_highlight = null

		RoomHighlighter.dispose(new_room_highlight)
		new_room_highlight = null

		for h in available_rooms_highlights:
			RoomHighlighter.dispose(h)

		Navigation.set_process(true)

func try_stop_fight_in_room(room : RoomBase):
	var fight = FightHandler.get_fight_for_room(room)

	if fight == null:
		return false

	fight.make_join_fight(self)
	return true

func try_arrest_in_room(room: RoomBase) -> bool:
	var target := _get_pending_arrest_in_room(room)
	if target == null:
		return false

	FightHandler.create_defense_fight(target, self)
	return true

func get_current_room() -> RoomBase:
	var exact := Building.query.room_at_position(global_position) as RoomBase
	if exact != null:
		return exact
	return Building.query.closest_room_of_type(RoomBase, global_position) as RoomBase

func _can_join_fight_in_room(room: RoomBase) -> bool:
	if room == null or current_job_room == null:
		return false
	if current_job_room == room:
		return true
	if Navigation == null:
		return false
	return Navigation.get_connected_rooms(current_job_room).has(room)

func should_auto_join_saloon_fight(room: RoomBase, _target_position: Vector2 = Vector2.INF) -> bool:
	if not should_fight_conflicts():
		return false
	if not _can_join_fight_in_room(room):
		return false
	if picked_up_npc == self:
		return false

	var behaviour = Behaviour.behaviour_instance
	if behaviour is FightBehaviour:
		return false
	return true

func should_auto_respond_to_arrest(room: RoomBase) -> bool:
	if not should_fight_conflicts():
		return false
	if room == null or current_job_room != room:
		return false
	if picked_up_npc == self:
		return false

	var current_room := get_current_room()
	if current_room != null and current_room.is_outside_room != room.is_outside_room:
		return false

	var behaviour = Behaviour.behaviour_instance
	return not (behaviour is FightBehaviour)


func resume_job_behaviour() -> void:
	Behaviour.set_behaviour_from_job(current_job)


func _get_pending_arrest_in_room(room: RoomBase) -> NPCGuest:
	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not ConflictResponseHandler.is_marked_for_arrest(guest):
			continue
		var guest_room = FightHandler._get_actor_room(guest)
		if guest_room == room:
			return guest
	return null

func try_change_job_based_on_room(room : RoomBase):
	var new_job = room.associated_job

	if new_job != null and current_job_room != room and not room.can_accept_worker(new_job):
		return

	current_job_room = room

	if new_job == null:
		new_job = Enum.Jobs.IDLE

	change_job(new_job)
