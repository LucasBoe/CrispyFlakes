extends Behaviour
class_name JobMinerBehaviour

const DIG_DURATION := 48.0
const DIG_SOUND_INTERVAL := 1.0
const COAL_DROP_MIN := 1
const COAL_DROP_MAX := 3

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
		var dig_pos: Vector2 = origin_room.get_center_floor_position()

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
		var new_room: RoomBase = Building.get_room_from_index(target)
		_spawn_coal_drops(new_room)
		if origin_room is RoomMineshaft:
			(origin_room as RoomMineshaft).refresh_tunnel_layout()
		elif origin_room is RoomMineshaftEntrance:
			(origin_room as RoomMineshaftEntrance).refresh_entrance_layout()
		if new_room is RoomMineshaft:
			(new_room as RoomMineshaft).refresh_tunnel_layout()

func _dig_at(pos: Vector2, dir: Vector2i) -> void:
	var dig_progress := 0.0
	var sound_elapsed := DIG_SOUND_INTERVAL

	npc.Navigation.stop_navigation()
	npc.Navigation.is_moving = true
	npc.Animator.direction = Vector2(dir)

	var bar := _NPC_PROGRESS_BAR.instantiate() as TextureProgressBar
	npc.add_child(bar)
	_owned_progress_bars.append(bar)
	_register_progress_bar(bar)
	bar.visible = true

	while dig_progress < 1.0:
		if stopped or not is_instance_valid(entrance):
			npc.Navigation.is_moving = false
			npc.Animator.direction = Vector2.ZERO
			_finish_dig_progress_bar(bar)
			return
		# Recomputed every frame so a mid-dig equipment swap changes pace immediately.
		var duration := _get_progress_duration(DIG_DURATION)
		var delta := npc.get_process_delta_time()
		dig_progress = minf(dig_progress + delta / duration, 1.0)
		sound_elapsed += delta
		_refresh_pickaxe_visual()
		if is_instance_valid(bar):
			bar.value = dig_progress * 100
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
	if not npc.Item.is_item(Enum.Items.PICKAXE):
		if npc.Item.current_item != null:
			npc.Item.drop_current()
		var pickaxe := Global.ItemSpawner.create(Enum.Items.PICKAXE, npc.global_position)
		npc.Item.pick_up(pickaxe)
	_refresh_pickaxe_visual()

func _refresh_pickaxe_visual() -> void:
	var item: Item = npc.Item.current_item
	if item == null:
		return
	var equipped := npc.Equipment.get_equipped_data() if npc.Equipment else null
	if equipped != null and equipped.carried_item_override != null and equipped.carried_item_type == Enum.Items.PICKAXE:
		item.apply_texture(equipped.carried_item_override, 0, 0, 1)
	else:
		item.refresh_texture()

func _clear_pickaxe() -> void:
	if not is_instance_valid(npc) or npc.Item == null:
		return
	if not npc.Item.is_item(Enum.Items.PICKAXE):
		return
	npc.Item.current_item.destroy()
	npc.Item.current_item = null

func _spawn_coal_drops(room: RoomBase) -> void:
	if not is_instance_valid(room):
		return

	var drop_count := randi_range(COAL_DROP_MIN, COAL_DROP_MAX)
	for _i in range(drop_count):
		var spawn_pos: Vector2 = room.get_random_floor_position()
		if room is RoomMineshaft:
			spawn_pos = (room as RoomMineshaft).get_random_dug_floor_position()
		Global.ItemSpawner.create(Enum.Items.COAL, spawn_pos)
