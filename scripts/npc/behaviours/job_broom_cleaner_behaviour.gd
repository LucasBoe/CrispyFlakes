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
var active_broom_particles: GPUParticles2D

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

		if target is Polygon2D:
			_narrative = ["Mopping up a puddle...", "Cleaning the floor...", "Soaking it up..."].pick_random()
		else:
			_narrative = ["Sweeping up the dirt...", "Getting every last bit...", "Tidying the floor..."].pick_random()
		CleanupTargetHandler.reserve_target(npc, target)
		active_room_target = target if (target is RoomBed or target is RoomOuthouse) else null
		await move(_target_position(target))

		if not is_instance_valid(target):
			_release_room_target(target)
			continue

		_start_broom_effect()
		SoundPlayer.play_broom(npc.global_position)
		await progress(_target_clean_duration(target))

		await _stop_broom_effect()

		if is_instance_valid(target):
			if target is Item:
				_clean_target(target)
			elif target is Polygon2D or target is Sprite2D:
				_clean_floor_mess_target_and_nearby(target)
			else:
				_clean_target(target)

			_release_room_target(target)

func stop_loop() -> BehaviourSaveData:
	CleanupTargetHandler.unregister_cleaner(npc)
	_stop_broom_effect_immediately()
	if is_instance_valid(closet):
		if closet.on_destroy_signal.is_connected(_change_to_idle):
			closet.on_destroy_signal.disconnect(_change_to_idle)
		closet.unregister_cleaner(npc)

	if is_instance_valid(active_room_target):
		_release_room_target(active_room_target)

	if npc.Item.is_item(Enum.Items.BROOM):
		var broom := npc.Item.drop_current()
		if is_instance_valid(closet):
			closet.return_broom()
			if is_instance_valid(broom):
				broom.destroy()

	var save = super.stop_loop()
	save.room = closet
	return save

func _start_broom_effect() -> void:
	_stop_broom_effect_immediately()
	active_broom_particles = BROOM_PARTICLES_SCENE.instantiate() as GPUParticles2D
	npc.add_child(active_broom_particles)
	npc.Animator.is_brooming = true

func _stop_broom_effect() -> void:
	npc.Animator.is_brooming = false
	var particles := active_broom_particles
	active_broom_particles = null
	if not is_instance_valid(particles):
		return
	particles.emitting = false
	await npc.get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _stop_broom_effect_immediately() -> void:
	npc.Animator.is_brooming = false
	if is_instance_valid(active_broom_particles):
		active_broom_particles.queue_free()
	active_broom_particles = null

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
	return CleanupTargetHandler.find_target_for(npc)

func _target_position(target) -> Vector2:
	if not is_instance_valid(target):
		return npc.global_position
	return CleanupTargetHandler.get_target_position(target)

func _broom_pickup_target(broom: Item) -> Vector2:
	var target := broom.global_position
	var room := Building.query.room_at_position(target) as RoomBase
	if room != null:
		target.y = room.get_center_floor_position().y
	return target

func _clean_target(target) -> void:
	if not is_instance_valid(target):
		return

	CleanupTargetHandler.log_cleaned(target, npc)

	if target is Item:
		target.destroy()
	elif target is RoomBed:
		(target as RoomBed).clean_bed()
	elif target is RoomOuthouse:
		(target as RoomOuthouse).uses = 0
	elif target is Polygon2D:
		PuddleHandler.clean_puddle(target)
	elif target is Sprite2D:
		DirtHandler.clean_dirt(target)

func _clean_floor_mess_in_range(center: Vector2) -> void:
	for puddle in PuddleHandler.get_all_in_range(center, FLOOR_MESS_CLEAN_RADIUS):
		CleanupTargetHandler.log_cleaned(puddle, npc)
		PuddleHandler.clean_puddle(puddle)

	for dirt in DirtHandler.get_all_in_range(center, FLOOR_MESS_CLEAN_RADIUS):
		CleanupTargetHandler.log_cleaned(dirt, npc)
		DirtHandler.clean_dirt(dirt)

func _clean_floor_mess_target_and_nearby(target) -> void:
	if not is_instance_valid(target):
		return
	var center := _target_position(target)
	_clean_target(target)
	_clean_floor_mess_in_range(center)

func _target_clean_duration(target) -> float:
	if not is_instance_valid(target):
		return CLEAN_DURATION
	if target is RoomBed:
		return BED_CLEAN_DURATION
	if target is RoomOuthouse:
		return OUTHOUSE_CLEAN_DURATION
	return CLEAN_DURATION

func _release_room_target(target) -> void:
	CleanupTargetHandler.release_target(npc, target)
	if active_room_target == target:
		active_room_target = null
