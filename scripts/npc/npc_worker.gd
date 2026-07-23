extends NPC
class_name NPCWorker

const NPCNameLibraryScript = preload("res://scripts/npc/npc_name_library.gd")
const INJURED_MOVE_SPEED_MULTIPLIER := 0.5
const INJURED_WORK_DURATION_MULTIPLIER := 2.0

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

var salary: int = Pricing.WORKER_BASE_SALARY
var character_name = ""
var saloon_fight_response: SaloonFightResponse = SaloonFightResponse.FIGHT

@onready var anim : Sprite2D = $AnimationModule

static var picked_up_npc : NPC = null
static var was_dragging = false

const DRAG_THRESHOLD = 8.0
const MELEE_CONFLICT_ENGAGE_RANGE := 24.0
const FIGHT_ENERGY_REGEN_PER_SECOND := 0.2
const FALL_GRAVITY = 800.0
var _drag_pending = false
var _drag_start_mouse = Vector2.ZERO
var _is_falling: bool = false
var _fall_velocity: float = 0.0
var _fall_target: Vector2 = Vector2.ZERO
var _fall_room: RoomBase = null
var _fall_landed_room: RoomBase = null
var _drop_mouse_pos: Vector2 = Vector2.ZERO

func _ready():
	super._ready()
	if character_name.is_empty():
		character_name = NPCNameLibraryScript.get_random_name()
	apply_trait_conflict_preference()
	_refresh_nametag()

func get_display_name() -> String:
	return character_name if not character_name.is_empty() else "Worker"

func _process(delta):
	super._process(delta)
	_regenerate_fight_energy(delta)

	if picked_up_npc == self:
		global_position = get_global_mouse_position()

	if _is_falling:
		_fall_velocity += FALL_GRAVITY * delta
		global_position.y += _fall_velocity * delta
		if global_position.y >= _fall_target.y:
			global_position.y = _fall_target.y
			_finish_drop()
		return

	if Behaviour.has_behaviour:
		return

	if Status != null:
		if Status.has_status(Enum.NpcStatus.WELL_TREATED) or Status.has_status(Enum.NpcStatus.BADLY_TREATED):
			Behaviour.set_behaviour(NeedSickWardBehaviour)
			return

	var treatment_behaviour = InjuryHandler.get_treatment_behaviour(self)
	if treatment_behaviour != null:
		Behaviour.set_behaviour(treatment_behaviour)
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
	if not FightHandler.can_npc_participate_in_fights(self):
		return false
	if Traits.refuses_voluntary_fights():
		return false
	if Traits.forces_fight_response():
		return true
	return saloon_fight_response == SaloonFightResponse.FIGHT

func get_move_speed_multiplier() -> float:
	var multiplier := super.get_move_speed_multiplier()
	if Status != null and Status.has_status(Enum.NpcStatus.INJURED):
		multiplier *= INJURED_MOVE_SPEED_MULTIPLIER
	return multiplier

func get_work_duration_multiplier() -> float:
	var multiplier := super.get_work_duration_multiplier()
	if Status != null and Status.has_status(Enum.NpcStatus.INJURED):
		multiplier *= INJURED_WORK_DURATION_MULTIPLIER
	return multiplier

func destroy():
	for j: Array in JobHandler.workers.values():
		j.erase(self)
	super.destroy()

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
	Animator.set_z(Enum.ZLayer.NPC_DRAGGED)
	# picking the worker up overrides whatever they were doing - stop cleanly
	# rather than leave a stale in-progress phase to be wrongly resumed once
	# they're dropped somewhere else entirely
	Navigation.stop_navigation()
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

	var room : RoomBase = Building.query.room_at_position(global_position) as RoomBase

	#if not assignmentIndicator.visible:
	#	assignmentIndicator.visible = true

	if not current_job_room_highlight && current_job != Enum.Jobs.IDLE && current_job_room:
		current_job_room_highlight = RoomHighlighter.request_rect(current_job_room, Color(1,1,0,0.5), 2, RoomHighlighter.Priority.SELECTION)

	if is_instance_valid(new_room_highlight) and new_room_highlight.get_meta(&"room", null) != room:
		RoomHighlighter.dispose(new_room_highlight)
		new_room_highlight = null

	if not new_room_highlight && room:
		new_room_highlight = RoomHighlighter.request_rect(room, Color.WHITE, 2, RoomHighlighter.Priority.SELECTION)

	if room and new_room_highlight and current_job_room != room:
		new_room_highlight.modulate = Color.GREEN if room.associated_job else Color.WHITE

	if room && room.associated_job:
		if is_instance_valid(new_job_room_highlight) and new_job_room_highlight.get_meta(&"room", null) != room:
			RoomHighlighter.dispose(new_job_room_highlight)
			new_job_room_highlight = null
		if not new_job_room_highlight:
			new_job_room_highlight = RoomHighlighter.request_arrow(room, RoomHighlighter.Priority.SELECTION, Vector2(24, -16))
	else:
		RoomHighlighter.dispose(new_job_room_highlight)
		new_job_room_highlight = null

	if event.is_action_released("click"):
		_drop_mouse_pos = get_global_mouse_position()
		_fall_room = room
		_fall_target = _get_drop_target_position(room, global_position)
		_fall_landed_room = Building.query.room_at_floor_position(_fall_target) as RoomBase
		_fall_velocity = 0.0
		_is_falling = true
		picked_up_npc = null
		var drop_visual_room: RoomBase = _fall_landed_room if _fall_landed_room != null else room
		var drop_z: Enum.ZLayer = Enum.ZLayer.NPC_OUTSIDE if (drop_visual_room == null or drop_visual_room.is_outside_room) else Enum.ZLayer.NPC_DEFAULT
		Animator.set_z(drop_z)

		RoomHighlighter.dispose(current_job_room_highlight)
		current_job_room_highlight = null

		RoomHighlighter.dispose(new_job_room_highlight)
		new_job_room_highlight = null

		RoomHighlighter.dispose(new_room_highlight)
		new_room_highlight = null

		for h in available_rooms_highlights:
			RoomHighlighter.dispose(h)

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

	var arrest_fight := FightHandler.create_defense_fight(target, self)
	if arrest_fight != null:
		return true
	if not is_instance_valid(target):
		return true
	var current_behaviour = target.Behaviour.behaviour_instance if target.Behaviour != null else null
	return (
		not ConflictResponseHandler.is_marked_for_arrest(target)
		or current_behaviour is ArrestedBehaviour
		or current_behaviour is FollowSheriffBehaviour
	)

func get_current_room() -> RoomBase:
	var exact := Building.query.room_at_floor_position(global_position) as RoomBase
	if exact != null:
		return exact
	return Building.query.closest_on_current_floor(RoomBase, global_position) as RoomBase

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
	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
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

func _find_land_position(drop_pos: Vector2) -> Vector2:
	var drop_idx: Vector2i = Building.round_room_index_from_global_position(drop_pos)
	var floor_indexes: Array = Building.floors.keys()
	floor_indexes.sort()
	var bottom_floor: int = int(floor_indexes[0]) if not floor_indexes.is_empty() else -1
	for y_idx in range(drop_idx.y, bottom_floor - 1, -1):
		var landed_room: RoomBase = Building.get_room_from_index(Vector2i(drop_idx.x, y_idx)) as RoomBase
		if landed_room != null:
			return Vector2(drop_pos.x, landed_room.global_position.y)
	var ground_room: RoomBase = Building.query.closest_on_floor(RoomBase, drop_pos, 0) as RoomBase
	if ground_room != null:
		return Vector2(drop_pos.x, ground_room.global_position.y)
	return drop_pos

func _get_drop_target_position(room: RoomBase, drop_pos: Vector2) -> Vector2:
	if room is RoomDigging:
		return (room as RoomDigging).get_dig_start_position()
	return _find_land_position(drop_pos)

func _finish_drop():
	_is_falling = false
	var resolved_drop_room: RoomBase = _fall_landed_room if _fall_landed_room != null else _fall_room
	var assignment_room: RoomBase = _fall_room if _fall_room is RoomDigging else resolved_drop_room
	var should_snap_to_drop_target := assignment_room is RoomDigging
	if should_snap_to_drop_target:
		global_position = _fall_target
	else:
		global_position.y = _fall_target.y
	Camera.add_shake(clampf(_fall_velocity * 0.005, 1.0, 5.0), 0.05)
	_fall_velocity = 0.0
	if assignment_room != null:
		Navigation.stop_navigation()
		var handled_context_action := false
		if assignment_room == resolved_drop_room:
			if try_stop_fight_in_room(resolved_drop_room):
				handled_context_action = true
			elif try_arrest_in_room(resolved_drop_room):
				handled_context_action = true
		if not handled_context_action:
			try_change_job_based_on_room(assignment_room)
		Animator.direction = Vector2.ZERO
	_fall_room = null
	_fall_landed_room = null
	Navigation.set_process(true)
