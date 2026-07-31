extends Behaviour
class_name JobMinerBehaviour

const DIG_DURATION := 48.0
const DIG_SOUND_INTERVAL := 1.0

var entrance: RoomMineshaftEntrance
static var occupied_entrances = []

func start_loop():
	entrance = try_get_room_if_not_occupied(data, RoomMineshaftEntrance, occupied_entrances)

func loop():
	while not stopped:
		if not is_instance_valid(entrance):
			_change_to_idle()
			return

		var plan = _find_dig_plan(entrance)
		if plan == null:
			_narrative = "No room to dig..."
			await end_of_frame()
			continue

		var origin_room: RoomBase = plan.origin
		var target: Vector2i = plan.target
		var edge_offset: float = 8.0 if plan.dir == Vector2i.LEFT else 48.0
		var dig_pos: Vector2 = origin_room.global_position + Vector2(edge_offset, 0)

		_narrative = ["Digging out the mineshaft...", "Following the vein deeper...", "Carving through rock..."].pick_random()
		_ensure_pickaxe()
		await move(dig_pos)
		if stopped or not is_instance_valid(entrance) or not is_instance_valid(origin_room):
			_clear_pickaxe()
			return

		await _dig_at(dig_pos, plan.dir)
		if stopped:
			_clear_pickaxe()
			return
		if not is_instance_valid(entrance) or Building.get_room_from_index(target) != null:
			continue

		Building.set_room(Building.room_data_mineshaft, target.x, target.y)
		Building.update_foreground_tiles()

func _dig_at(pos: Vector2, dir: Vector2i) -> void:
	var duration := DIG_DURATION
	var elapsed := 0.0
	var sound_elapsed := DIG_SOUND_INTERVAL
	var adjusted := _get_progress_duration(duration)

	npc.Navigation.stop_navigation()
	npc.Navigation.is_moving = true
	npc.Animator.direction = Vector2(dir)

	var bar := _NPC_PROGRESS_BAR.instantiate() as TextureProgressBar
	npc.add_child(bar)
	_owned_progress_bars.append(bar)
	_register_progress_bar(bar)
	bar.visible = true

	while elapsed < adjusted:
		if stopped or not is_instance_valid(entrance):
			npc.Navigation.is_moving = false
			npc.Animator.direction = Vector2.ZERO
			_finish_dig_progress_bar(bar)
			return
		elapsed += npc.get_process_delta_time()
		sound_elapsed += npc.get_process_delta_time()
		if is_instance_valid(bar):
			bar.value = (elapsed / adjusted) * 100
		if sound_elapsed >= DIG_SOUND_INTERVAL:
			SoundPlayer.play_digging(pos)
			sound_elapsed = 0.0
		await end_of_frame()

	npc.Navigation.is_moving = false
	npc.Animator.direction = Vector2.ZERO
	_finish_dig_progress_bar(bar)

func _finish_dig_progress_bar(bar: TextureProgressBar) -> void:
	_unregister_progress_bar(bar)
	_unregister_owned_progress_bar(bar)
	if is_instance_valid(bar):
		bar.queue_free()

func _find_dig_plan(from_room: RoomBase) -> Variant:
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		var origin_room: RoomBase = from_room
		while true:
			var next_index := Vector2i(origin_room.x, origin_room.y) + dir
			var next_room = Building.get_room_from_index(next_index)
			if next_room == null:
				return {"origin": origin_room, "target": next_index, "dir": dir}
			if next_room is RoomMineshaft:
				origin_room = next_room
				continue
			break
	return null

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(npc) and npc.Navigation != null:
		npc.Navigation.is_moving = false
		npc.Animator.direction = Vector2.ZERO
	_clear_pickaxe()
	if is_instance_valid(entrance):
		entrance.worker = null
	occupied_entrances.erase(entrance)

	var save = super.stop_loop()
	save.room = entrance
	return save

func _ensure_pickaxe() -> void:
	if not is_instance_valid(npc) or npc.Item == null:
		return
	if npc.Item.is_item(Enum.Items.PICKAXE):
		return
	if npc.Item.current_item != null:
		npc.Item.drop_current()
	var pickaxe := Global.ItemSpawner.create(Enum.Items.PICKAXE, npc.global_position)
	npc.Item.pick_up(pickaxe)

func _clear_pickaxe() -> void:
	if not is_instance_valid(npc) or npc.Item == null:
		return
	if not npc.Item.is_item(Enum.Items.PICKAXE):
		return
	npc.Item.current_item.destroy()
	npc.Item.current_item = null
