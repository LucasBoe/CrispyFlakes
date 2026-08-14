extends Node

var workers : Dictionary[Enum.Jobs, Array]

#var payment_total = 0
#var payment_cycle_progression = 0.0

signal on_jobs_changed_signal

func _ready() -> void:
	Console.add_command("fire_workers_of_room", console_fire_workers_of_room, ["room_type"], 1, "Fires every worker currently assigned to rooms of the given room type (e.g. 'bar', 'well').")
	Console.add_command("assign_job", console_assign_job, ["worker_name", "x", "y"], 3, "Assigns the named worker to the job of the room at (x,y), same as dragging them onto it. Quote names with spaces.")

func on_job_changed(npc : NPCWorker, new_job):
	
	if npc is not NPCWorker:
		return
		
	var previous_job = null

	for job in workers.keys():
		for worker in workers[job]:
			if npc == worker:
				previous_job = job
		
	#print_debug("npc ", npc.get_script().get_global_name(), " changed job from ",previous_job ," to ", new_job)
	#
	if previous_job != null:
		if workers.has(previous_job):
			workers[previous_job].erase(npc)
			if workers[previous_job].size() == 0:
				workers.erase(previous_job)
		
	if not workers.has(new_job):
		workers[new_job] = []
		
	workers[new_job].append(npc)
	
	#payment_total = 0
	#for w in workers.values():
		#for worker in w:
			#payment_total += worker.salary

	on_jobs_changed_signal.emit()
	
#func _process(delta):
	#payment_cycle_progression += delta / Global.DAY_DURATION
	#if payment_cycle_progression >= 1.0:
		#payment_cycle_progression = 0.0
		#execute_payments()

#func execute_payments():
	#ResourceHandler.change_money(-payment_total)

func count_workers_in(job):
	if not workers.has(job):
		return 0
		
	if workers[job] == null:
		return 0
		
	return workers[job].size()
	
func count_rooms_for(job):
	var count = 0
	for room: RoomBase in _get_unique_rooms():
		count += room.get_job_capacity(job)
	
	return count

func get_worker_capacity() -> int:
	var count := 0
	for room: RoomBase in _get_unique_rooms():
		if room.associated_job == null:
			continue
		count += room.get_job_capacity(room.associated_job)
	return count

# find idle person and change their job to new job
func add_more_people_to_job(job):
	
	if not workers.has(Enum.Jobs.IDLE):
		return
	
	var worker = workers[Enum.Jobs.IDLE].pick_random()
	worker.change_job(job)

# find working person and change their job to idle
func remove_people_from_job(job):
	
	if not workers.has(job):
		return
	
	var worker = workers[job].pick_random()
	worker.change_job(Enum.Jobs.IDLE)

func fire_worker(worker):

	if not is_instance_valid(worker):
		return

	worker.change_job(Enum.Jobs.IDLE)
	for j : Array in workers.values():
		if j.has(worker):
			j.erase(worker)

	worker.destroy()

## Console/headless-test command: fires every worker whose current job room matches
## the given room type key, e.g. "bar", "well", "brewery" (the same names used for
## RoomData resource files, "room_<key>.tres").
func console_fire_workers_of_room(room_type : String) -> void:
	if Global.NPCSpawner == null:
		Console.print_error("NPCSpawner is not available.")
		return

	var normalized_type := room_type.strip_edges().to_lower()
	var fired := 0
	for worker : NPCWorker in Global.NPCSpawner.get_live_workers().duplicate():
		if not is_instance_valid(worker):
			continue
		var room := worker.current_job_room as RoomBase
		if room == null or _room_type_key(room) != normalized_type:
			continue
		fire_worker(worker)
		fired += 1

	Console.print_line("Fired %d worker(s) assigned to '%s' rooms." % [fired, normalized_type])

## Console/headless-test command: assigns a worker to the job of the room at (x,y),
## reusing the same capacity/eligibility checks as dragging a worker onto that room.
func console_assign_job(worker_name : String, x : String, y : String) -> void:
	if not (x.is_valid_int() and y.is_valid_int()):
		Console.print_error("(x,y) must be integers, got (%s,%s)." % [x, y])
		return
	var room := Building.get_room_from_index(Vector2i(int(x), int(y))) as RoomBase
	if room == null:
		Console.print_error("No room at (%s,%s)." % [x, y])
		return

	var worker := _find_worker_by_name(worker_name)
	if worker == null:
		Console.print_error("No live worker named '%s'." % worker_name)
		return

	worker.try_change_job_based_on_room(room)
	if worker.current_job_room == room:
		Console.print_line("%s is now working %s at (%s,%s)." % [worker.get_display_name(), Enum.Jobs.keys()[worker.current_job], x, y])
	else:
		Console.print_error("%s could not be assigned to the room at (%s,%s) (it may be full or have no job)." % [worker.get_display_name(), x, y])

func _find_worker_by_name(worker_name : String) -> NPCWorker:
	if Global.NPCSpawner == null:
		return null
	for worker : NPCWorker in Global.NPCSpawner.get_live_workers():
		if worker.get_display_name() == worker_name:
			return worker
	return null

func _room_type_key(room : RoomBase) -> String:
	if room.data == null:
		return ""
	var file_name := room.data.resource_path.get_file().get_basename()
	if file_name.begins_with("room_"):
		file_name = file_name.substr(5)
	return file_name

func _get_unique_rooms() -> Array[RoomBase]:
	var rooms: Array[RoomBase] = []
	var seen := {}

	if not is_instance_valid(Building):
		return rooms

	for floor in Building.floors.values():
		for candidate in floor.values():
			var room := candidate as RoomBase
			if room == null or not is_instance_valid(room):
				continue
			var instance_id := room.get_instance_id()
			if seen.has(instance_id):
				continue
			seen[instance_id] = true
			rooms.append(room)

	return rooms
