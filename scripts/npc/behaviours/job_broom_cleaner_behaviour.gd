extends Behaviour
class_name JobBroomCleanerBehaviour

const BROOM_PARTICLES_SCENE = preload("res://scenes/fight_particles.tscn")

const CLEAN_DURATION := .5
const BED_CLEAN_DURATION := 3.0
const OUTHOUSE_CLEAN_DURATION := 4.0
const IDLE_WAIT_DURATION := 2.0
const FLOOR_MESS_CLEAN_RADIUS := 16.0

var closet: RoomBroomCloset
var active_room_target: RoomBase

static var occupied_beds = []
static var occupied_outhouses = []

func start_loop():
	closet = _find_closet()
	if closet == null:
		var loose_broom = LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.BROOM)
		if loose_broom == null:
			_change_to_idle()
			return

	if closet != null and not closet.register_cleaner(npc):
		closet = null
		_change_to_idle()
		return

	if closet != null:
		closet.on_destroy_signal.connect(_change_to_idle)

func loop():
	if closet != null:
		await move(closet.get_random_floor_position())

	while true:
		_narrative = ["Getting a broom...", "Fetching supplies...", "Looking for a broom..."].pick_random()
		await _ensure_broom()
		if not npc.Item.is_item(Enum.Items.BROOM):
			if closet == null and LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.BROOM) == null:
				_change_to_idle()
				return
			_narrative = ["Waiting for a broom...", "Looking for supplies..."].pick_random()
			await pause(IDLE_WAIT_DURATION)
			continue

		var target = _find_cleanup_target()
		if target == null:
			if is_instance_valid(closet):
				await move(closet.get_random_floor_position())
			_narrative = ["Nothing to clean... for now.", "Waiting for a mess...", "Standing by..."].pick_random()
			await pause(IDLE_WAIT_DURATION)
			continue

		if target is ColorRect:
			_narrative = ["Mopping up a puddle...", "Cleaning the floor...", "Soaking it up..."].pick_random()
		else:
			_narrative = ["Sweeping up the dirt...", "Getting every last bit...", "Tidying the floor..."].pick_random()
		_reserve_room_target(target)
		await move(_target_position(target))

		if not is_instance_valid(target):
			_release_room_target(target)
			continue

		var particles = BROOM_PARTICLES_SCENE.instantiate() as GPUParticles2D
		npc.add_child(particles)
		npc.Animator.is_brooming = true
		SoundPlayer.play_broom(npc.global_position)
		await progress(_target_clean_duration(target))

		npc.Animator.is_brooming = false
		if is_instance_valid(particles):
			particles.emitting = false
			await npc.get_tree().create_timer(1.0).timeout
			particles.queue_free()

		if target is ColorRect or target is Sprite2D:
			_clean_floor_mess_in_range(npc.global_position)
		elif is_instance_valid(target):
			_clean_target(target)
		_release_room_target(target)

func stop_loop() -> BehaviourSaveData:
	npc.Animator.is_brooming = false
	if is_instance_valid(closet):
		if closet.on_destroy_signal.is_connected(_change_to_idle):
			closet.on_destroy_signal.disconnect(_change_to_idle)
		closet.unregister_cleaner(npc)

	if is_instance_valid(active_room_target):
		_release_room_target(active_room_target)

	if npc.Item.is_item(Enum.Items.BROOM):
		npc.Item.drop_current()

	var save = super.stop_loop()
	save.room = closet
	return save

func _find_closet() -> RoomBroomCloset:
	if data != null and is_instance_valid(data.room):
		var saved_room := data.room as RoomBroomCloset
		if saved_room != null and saved_room.can_accept_worker(Enum.Jobs.BROOM_CLEANER):
			return saved_room

	for room: RoomBroomCloset in get_all_rooms_of_type_ordered_by_distance(RoomBroomCloset):
		if room.can_accept_worker(Enum.Jobs.BROOM_CLEANER):
			return room

	return null

func _ensure_broom() -> void:
	if npc.Item.is_item(Enum.Items.BROOM):
		return

	var loose_broom = LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.BROOM)
	if loose_broom != null:
		await move(_broom_pickup_target(loose_broom))
		npc.Item.pick_up(loose_broom)
		return

	if not is_instance_valid(closet):
		closet = _find_closet()
		if closet == null:
			return
		if not closet.register_cleaner(npc):
			return

	await move(closet.get_broom_pickup_position())
	var broom := closet.issue_broom()
	if broom != null:
		npc.Item.pick_up(broom)

func _find_cleanup_target():
	var closest_bed := _find_dirty_bed()
	var closest_outhouse := _find_dirty_outhouse()

	if closest_bed != null or closest_outhouse != null:
		var priority = []
		if closest_bed != null:
			priority.append(closest_bed)
		if closest_outhouse != null:
			priority.append(closest_outhouse)
		priority.sort_custom(func(a, b): return _target_position(a).distance_squared_to(npc.global_position) < _target_position(b).distance_squared_to(npc.global_position))
		return priority[0]

	var closest_dirt := DirtHandler.get_closest_to(npc.global_position)
	var closest_puddle := PuddleHandler.get_closest_to(npc.global_position)
	var candidates = []

	if closest_dirt != null:
		candidates.append(closest_dirt)
	if closest_puddle != null:
		candidates.append(closest_puddle)

	if candidates.is_empty():
		return null

	candidates.sort_custom(func(a, b): return _target_position(a).distance_squared_to(npc.global_position) < _target_position(b).distance_squared_to(npc.global_position))
	return candidates[0]

func _target_position(target) -> Vector2:
	if not is_instance_valid(target):
		return npc.global_position
	if target is ColorRect:
		return target.global_position + target.size * 0.5
	if target is RoomOuthouse or target is RoomBed:
		return target.get_center_floor_position()
	return target.global_position

func _broom_pickup_target(broom: Item) -> Vector2:
	var target := broom.global_position
	var room := Building.query.room_at_position(target) as RoomBase
	if room != null:
		target.y = room.get_center_floor_position().y
	return target

func _clean_target(target) -> void:
	if not is_instance_valid(target):
		return

	if target is RoomBed:
		(target as RoomBed).clean_bed()
	elif target is RoomOuthouse:
		(target as RoomOuthouse).uses = 0
	elif target is ColorRect:
		PuddleHandler.clean_puddle(target)
	elif target is Sprite2D:
		DirtHandler.clean_dirt(target)

func _clean_floor_mess_in_range(center: Vector2) -> void:
	for puddle in PuddleHandler.get_all_in_range(center, FLOOR_MESS_CLEAN_RADIUS):
		PuddleHandler.clean_puddle(puddle)

	for dirt in DirtHandler.get_all_in_range(center, FLOOR_MESS_CLEAN_RADIUS):
		DirtHandler.clean_dirt(dirt)

func _target_clean_duration(target) -> float:
	if not is_instance_valid(target):
		return CLEAN_DURATION
	if target is RoomBed:
		return BED_CLEAN_DURATION
	if target is RoomOuthouse:
		return OUTHOUSE_CLEAN_DURATION
	return CLEAN_DURATION

func _find_dirty_bed() -> RoomBed:
	for bed: RoomBed in get_all_rooms_of_type_ordered_by_distance(RoomBed):
		if bed.needs_cleaning and not occupied_beds.has(bed):
			return bed
	return null

func _find_dirty_outhouse() -> RoomOuthouse:
	for outhouse: RoomOuthouse in get_all_rooms_of_type_ordered_by_distance(RoomOuthouse):
		if outhouse.is_full() and not occupied_outhouses.has(outhouse):
			return outhouse
	return null

func _reserve_room_target(target) -> void:
	if target is RoomBed:
		if not occupied_beds.has(target):
			occupied_beds.append(target)
		target.worker = npc
		active_room_target = target
	elif target is RoomOuthouse:
		if not occupied_outhouses.has(target):
			occupied_outhouses.append(target)
		target.worker = npc
		active_room_target = target
	else:
		active_room_target = null

func _release_room_target(target) -> void:
	
	if is_instance_valid(target):	
		if target is RoomBed:
			occupied_beds.erase(target)
			if is_instance_valid(target) and target.worker == npc:
				target.worker = null
		elif target is RoomOuthouse:
			occupied_outhouses.erase(target)
			if is_instance_valid(target) and target.worker == npc:
				target.worker = null

	if active_room_target == target:
		active_room_target = null
