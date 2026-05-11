extends Node

const STARTUP_QUESTS := preload("res://scripts/startup/startup_quests.gd")
const ARROW_RED_DOWN_PATH := "res://assets/sprites/ui/2x/arrow_red_down.png"
const GOLDEN_GLOW_SHADER := preload("res://assets/shaders/golden_glow_red_replace.gdshader")
const STARTUP_WAIT_BEHAVIOUR := preload("res://scripts/npc/behaviours/startup_wait_behaviour.gd")
const TUTORIAL_WORKER_TARGET := Vector2(-128, 0)
const STARTUP_INITIAL_MONEY := 30
const STARTUP_SKIP_MONEY := 70  # STARTUP_INITIAL_MONEY(30) + 4 quest rewards(10 each)
const OUTSIDE_OVERLAY_FADE_DURATION := 1.0
const MENU_ARROW_OFFSET := Vector2(-2, -52)
const MENU_ARROW_HOVER_HEIGHT := 3.0
const MENU_ARROW_HOVER_DURATION := 0.5

var done: bool = false
var _menu_tutorial_arrow: TextureRect
var _menu_tutorial_arrow_hover_tween: Tween
var _menu_tutorial_arrow_material: ShaderMaterial
var _menu_tutorial_arrow_texture: Texture2D
var _quests
var _tutorial_worker: NPCWorker
var _skip_requested := false
var _startup_content_ready := false
var _served_startup_guests: Array[NPCGuest] = []


func _ready() -> void:
	_prepare_startup_content()

func _process(_delta: float) -> void:
	if done:
		return
	done = true

	await _run_startup_sequence()

func _run_startup_sequence() -> void:
	if not _startup_content_ready:
		await _poll_until(func(): return _startup_content_ready)

	_reset_outside_overlay()
	Global.UI.menu.start_tutorial_menu_gating()
	Global.UI.selection.set_context_menu_blocked(true)
	spawn_bounties(3)
	spawn_item_stack(Enum.Items.WOOD, 3, 0, 10)
	_set_startup_money(STARTUP_INITIAL_MONEY)
	ProgressionHandler.unlock_default_rooms()
	Global.should_auto_spawn_guests = false
	_skip_requested = false

	var skip_layer := create_skip_tutorial_button()

	RoomStatusHandler.enabled = false
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").hide()
	_tutorial_worker = await _spawn_tutorial_worker()
	var tutorial_worker := _tutorial_worker
	await _fade_outside_overlay()
	if not _skip_requested and is_instance_valid(tutorial_worker):
		_reveal_quest_for_target(_quests.cleanup, tutorial_worker)
		if _finish_startup_if_aborted(skip_layer, await _wait_for_tutorial_activation(_quests.cleanup)):
			return
		_quests.cleanup.start()
		if _finish_startup_if_aborted(skip_layer, await _wait_for_cleanup_completion(_quests.cleanup)):
			return
		_quests.cleanup.set_done()
		Global.UI.selection.set_context_menu_blocked(false)

		_reveal_quest_for_target(_quests.build_bar, tutorial_worker)
		if _finish_startup_if_aborted(skip_layer, await _wait_for_tutorial_activation(_quests.build_bar)):
			return
		_quests.build_bar.start()
		Global.UI.menu.unlock_tutorial_build_menu()
		if _finish_startup_if_aborted(
			skip_layer,
			await _wait_for_tab_arrow_step(
				Global.UI.menu.build_button,
				Global.UI.menu.build_tab.tab_cointainer,
				1,
				Global.UI.menu.build_tab.data_to_button.get(Building.room_data_bar),
				func(): return not Building.query.all_rooms_of_type(RoomBar).is_empty()
			)
		):
			return
		if _finish_startup_if_aborted(skip_layer, await _wait_for_bar_setup_completion(tutorial_worker)):
			return
		_quests.build_bar.set_done()
		if _finish_startup_if_aborted(skip_layer, await _wait_for_initial_bar_water_stock(tutorial_worker)):
			return

		_reveal_quest_for_target(_quests.serve_guests, tutorial_worker)
		if _finish_startup_if_aborted(skip_layer, await _wait_for_tutorial_activation(_quests.serve_guests)):
			return
		_quests.serve_guests.start()

		RoomStatusHandler.enabled = true
		Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").show()
		Global.UI.resources.show()
		Global.should_auto_spawn_guests = true

		_reset_startup_served_guest_tracking()
		await _spawn_tutorial_guest_wave(
			maxi(
				STARTUP_QUESTS.SERVE_GUESTS_TARGET,
				STARTUP_QUESTS.BUILD_TABLE_TRIGGER_SERVED_GUEST_COUNT
			)
		)
		if _finish_startup_if_aborted(skip_layer, await _wait_for_served_guest_completion(_quests.serve_guests)):
			return
		_quests.serve_guests.set_done()

		if _finish_startup_if_aborted(
			skip_layer,
			await _wait_for_served_guest_milestone(STARTUP_QUESTS.BUILD_TABLE_TRIGGER_SERVED_GUEST_COUNT)
		):
			return

		var table_quest_target: Node2D = _get_served_guest_for_milestone(STARTUP_QUESTS.BUILD_TABLE_TRIGGER_SERVED_GUEST_COUNT)
		if not is_instance_valid(table_quest_target):
			table_quest_target = tutorial_worker
		if is_instance_valid(table_quest_target):
			_reveal_quest_for_target(_quests.build_table, table_quest_target)
			if _finish_startup_if_aborted(skip_layer, await _wait_for_tutorial_activation(_quests.build_table)):
				return
		else:
			TutorialHandler.activate_quest(_quests.build_table)

		_quests.build_table.start()
		Global.UI.menu.unlock_tutorial_build_menu()
		if _finish_startup_if_aborted(
			skip_layer,
			await _wait_for_tab_arrow_step(
				Global.UI.menu.build_button,
				Global.UI.menu.build_tab.tab_cointainer,
				0,
				Global.UI.menu.build_tab.data_to_button.get(Building.room_data_table),
				func(): return not Building.query.all_rooms_of_type(RoomTable).is_empty()
			)
		):
			return
		_quests.build_table.set_done()

	_finish_startup(skip_layer, _skip_requested)


func _prepare_startup_content() -> void:
	await get_tree().process_frame
	setup_building()
	_create_startup_quests()
	_startup_content_ready = true


func _set_startup_money(amount: int) -> void:
	var current_money := int(ResourceHandler.resources.get(Enum.Resources.MONEY, 0))
	var delta := amount - current_money
	ResourceHandler.resources[Enum.Resources.MONEY] = amount
	ResourceHandler.money_transaction_history.clear()
	ResourceHandler.on_resource_changed.emit(Enum.Resources.MONEY, amount, delta)
	ResourceHandler.on_money_changed.emit()

	MoneyHandler.free_pool = amount
	MoneyHandler.location_money.clear()
	MoneyHandler.changed.emit()

func spawn_bounties(count: int) -> void:
	for i in count:
		var look = NPCLookInfo.new_random()
		var bounty: int = randi_range(1, 5) * 10
		BountyHandler.create_bounty(look, bounty)

func setup_building() -> void:
	var b: Node = Building
	b.set_room(b.room_data_bounty_board, -6, 0, false)
	b.set_room(b.room_data_junk, -2, 0, false)
	b.set_room(b.room_data_empty, -1, 0, false)
	b.set_room(b.room_data_empty, 0, 0, false)
	b.set_room(b.room_data_well, 3, 0, false)
	b.set_room(b.room_data_stairs, 0, -1, false)
	b.set_room(b.room_data_junk, -1, -1, false)
	b.initialize_all_rooms()
	b.update_foreground_tiles()

func create_skip_tutorial_button() -> CanvasLayer:
	var skip_layer := CanvasLayer.new()
	skip_layer.layer = 101
	var skip_button := Button.new()
	skip_button.text = "Skip Tutorial"
	skip_button.anchor_left = 0.0
	skip_button.anchor_top = 1.0
	skip_button.anchor_right = 0.0
	skip_button.anchor_bottom = 1.0
	skip_button.offset_left = 8.0
	skip_button.offset_top = -28.0
	skip_button.offset_right = 100.0
	skip_button.offset_bottom = -8.0
	skip_button.pressed.connect(func():
		_skip_requested = true
		LetterUIHandler.skip()
		Global.UI.dialogue.finish_dialogue()
		TutorialHandler.clear_quests()
	, CONNECT_ONE_SHOT)
	skip_layer.add_child(skip_button)
	add_child(skip_layer)
	return skip_layer

func _spawn_tutorial_worker() -> NPCWorker:
	var worker := Global.NPCSpawner.spawn_new_worker(Vector2(-320, 0)) as NPCWorker
	if worker == null:
		return null
	
	await get_tree().process_frame
	worker.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)
	worker.force_behaviour(STARTUP_WAIT_BEHAVIOUR)
	worker.Navigation.set_target(TUTORIAL_WORKER_TARGET, -1)
	if await _poll_until(func(): return not is_instance_valid(worker) or worker.global_position.distance_to(TUTORIAL_WORKER_TARGET) < 4.0):
		if is_instance_valid(worker):
			worker.Navigation.stop_navigation()
			worker.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)
		return worker
	return worker


func _get_outside_overlay() -> CanvasItem:
	return Building.get_node_or_null("OutsideOverlay") as CanvasItem


func _reset_outside_overlay() -> void:
	var overlay := _get_outside_overlay()
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _fade_outside_overlay() -> void:
	var overlay := _get_outside_overlay()
	if overlay == null or not overlay.visible:
		return

	if _skip_requested:
		overlay.visible = false
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.0, OUTSIDE_OVERLAY_FADE_DURATION)

	while tween.is_running() and not _skip_requested:
		await get_tree().process_frame

	tween.kill()
	if is_instance_valid(overlay):
		overlay.visible = false


func _wait_for_menu_arrow_step(button: Button, completion_condition: Callable) -> bool:
	if button == null:
		return await _poll_until(completion_condition)

	_show_menu_tutorial_arrow(button)
	while not _skip_requested and not completion_condition.call():
		_update_menu_tutorial_arrow_visibility()
		await get_tree().process_frame

	_destroy_menu_tutorial_arrow()
	return _skip_requested


func _wait_for_tab_arrow_step(button: Button, tab_bar: TabBar, tab_index: int, tab_content_button: Button, completion_condition: Callable) -> bool:
	var current_state := -1
	while not _skip_requested and not completion_condition.call():
		var menu := Global.UI.menu
		var new_state: int
		if menu.visible_tab != menu.build_tab:
			new_state = 0
		elif tab_bar.current_tab != tab_index:
			new_state = 1
		else:
			new_state = 2
		if new_state != current_state:
			current_state = new_state
			match current_state:
				0: _show_menu_tutorial_arrow(button)
				1: _show_menu_tutorial_arrow_at_tab(tab_bar, tab_index)
				2: _show_menu_tutorial_arrow(tab_content_button)
		if current_state == 0:
			_update_menu_tutorial_arrow_visibility()
		await get_tree().process_frame
	_destroy_menu_tutorial_arrow()
	return _skip_requested


func _show_menu_tutorial_arrow_at_tab(tab_bar: TabBar, tab_index: int) -> void:
	_destroy_menu_tutorial_arrow()
	if tab_bar == null:
		return

	var arrow_texture := _get_menu_tutorial_arrow_texture()
	if arrow_texture == null:
		return

	if _menu_tutorial_arrow_material == null:
		_menu_tutorial_arrow_material = ShaderMaterial.new()
		_menu_tutorial_arrow_material.shader = GOLDEN_GLOW_SHADER

	var tab_rect := tab_bar.get_tab_rect(tab_index)
	var arrow_size := arrow_texture.get_size()

	var arrow := TextureRect.new()
	arrow.name = "TutorialMenuArrow"
	arrow.texture = arrow_texture
	arrow.material = _menu_tutorial_arrow_material
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP
	arrow.size = arrow_size
	arrow.position = Vector2(
		tab_rect.position.x + tab_rect.size.x * 0.5 - arrow_size.x * 0.5 + MENU_ARROW_OFFSET.x,
		MENU_ARROW_OFFSET.y
	)
	tab_bar.add_child(arrow)
	_menu_tutorial_arrow = arrow

	var base_y := MENU_ARROW_OFFSET.y
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arrow, "position:y", base_y - MENU_ARROW_HOVER_HEIGHT, MENU_ARROW_HOVER_DURATION)
	tween.tween_property(arrow, "position:y", base_y, MENU_ARROW_HOVER_DURATION)
	_menu_tutorial_arrow_hover_tween = tween


func _show_menu_tutorial_arrow(button: Button) -> void:
	_destroy_menu_tutorial_arrow()
	if button == null:
		return

	var arrow_texture := _get_menu_tutorial_arrow_texture()
	if arrow_texture == null:
		return

	if _menu_tutorial_arrow_material == null:
		_menu_tutorial_arrow_material = ShaderMaterial.new()
		_menu_tutorial_arrow_material.shader = GOLDEN_GLOW_SHADER

	var arrow := TextureRect.new()
	arrow.name = "TutorialMenuArrow"
	arrow.texture = arrow_texture
	arrow.material = _menu_tutorial_arrow_material
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP
	arrow.size = arrow_texture.get_size()
	arrow.position = MENU_ARROW_OFFSET
	button.add_child(arrow)
	_menu_tutorial_arrow = arrow

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arrow, "position:y", MENU_ARROW_OFFSET.y - MENU_ARROW_HOVER_HEIGHT, MENU_ARROW_HOVER_DURATION)
	tween.tween_property(arrow, "position:y", MENU_ARROW_OFFSET.y, MENU_ARROW_HOVER_DURATION)
	_menu_tutorial_arrow_hover_tween = tween


func _update_menu_tutorial_arrow_visibility() -> void:
	if _menu_tutorial_arrow == null or not is_instance_valid(_menu_tutorial_arrow):
		return
	var menu := Global.UI.menu
	_menu_tutorial_arrow.visible = menu != null and menu.visible_tab == null


func _destroy_menu_tutorial_arrow() -> void:
	if _menu_tutorial_arrow_hover_tween != null:
		_menu_tutorial_arrow_hover_tween.kill()
		_menu_tutorial_arrow_hover_tween = null

	if _menu_tutorial_arrow != null and is_instance_valid(_menu_tutorial_arrow):
		_menu_tutorial_arrow.queue_free()
	_menu_tutorial_arrow = null


func _get_menu_tutorial_arrow_texture() -> Texture2D:
	if _menu_tutorial_arrow_texture != null:
		return _menu_tutorial_arrow_texture

	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(ARROW_RED_DOWN_PATH))
	if error != OK:
		push_error("Failed to load tutorial arrow texture: %s" % ARROW_RED_DOWN_PATH)
		return null

	_menu_tutorial_arrow_texture = ImageTexture.create_from_image(image)
	return _menu_tutorial_arrow_texture

func _create_startup_quests() -> void:
	_quests = STARTUP_QUESTS.new(Building.query.all_rooms_of_type(RoomJunk).size())


func _reveal_quest_for_target(quest, target: Node2D) -> void:
	TutorialHandler.set_quest_reveal_target(quest, target)
	TutorialHandler.reveal_quest(quest)

func _wait_for_tutorial_activation(quest) -> bool:
	return await _poll_until(func():
		return quest != null and quest.phase == TutorialHandler.TutorialPhase.ACTIVE
	)

func _wait_for_tutorial_claim(quest) -> bool:
	return await _poll_until(func():
		return quest == null or not TutorialHandler.has_quest(quest)
	)

func _wait_for_cleanup_completion(task) -> bool:
	var total_rooms: int = Building.query.all_rooms_of_type(RoomJunk).size()
	while not _skip_requested:
		var missing_rooms: int = Building.query.all_rooms_of_type(RoomJunk).size()
		var cleaned_rooms: int = maxi(total_rooms - missing_rooms, 0)
		task.set_text(STARTUP_QUESTS.cleanup_text(cleaned_rooms, total_rooms))
		if missing_rooms == 0:
			return false
		await get_tree().process_frame
	return true

func _wait_for_bar_setup_completion(worker: NPCWorker) -> bool:
	return await _poll_until(func():
		var bars: Array = Building.query.all_rooms_of_type(RoomBar)
		return not bars.is_empty() and is_instance_valid(worker) and worker.current_job == Enum.Jobs.BAR and worker.current_job_room is RoomBar
	)


func _wait_for_initial_bar_water_stock(worker: NPCWorker) -> bool:
	return await _poll_until(func():
		if not is_instance_valid(worker):
			return false
		if worker.current_job != Enum.Jobs.BAR or worker.current_job_room is not RoomBar:
			return false

		var behaviour_module := worker.Behaviour
		if behaviour_module == null or behaviour_module.behaviour_instance is not JobBarBehaviour:
			return false

		var bar_behaviour := behaviour_module.behaviour_instance as JobBarBehaviour
		return bar_behaviour.drinks_available > 0.0
	)


func _spawn_tutorial_guest_wave(count: int) -> void:
	for _guest_index in count:
		if _skip_requested:
			return
		var guest := Global.NPCSpawner.spawn_new_guest() as NPCGuest
		if guest == null:
			continue
		await get_tree().create_timer(3).timeout

func _wait_for_served_guest_completion(task) -> bool:
	while not _skip_requested:
		var served_guest_count := _get_startup_served_guest_count()
		task.set_text(
			STARTUP_QUESTS.serve_guests_text(
				mini(served_guest_count, STARTUP_QUESTS.SERVE_GUESTS_TARGET),
				STARTUP_QUESTS.SERVE_GUESTS_TARGET
			)
		)
		if served_guest_count >= STARTUP_QUESTS.SERVE_GUESTS_TARGET:
			return false
		await get_tree().process_frame
	return true


func _wait_for_served_guest_milestone(served_guest_count: int) -> bool:
	return await _poll_until(func():
		return _get_startup_served_guest_count() >= served_guest_count
	)


func _reset_startup_served_guest_tracking() -> void:
	_served_startup_guests.clear()


func _get_startup_served_guest_count() -> int:
	_track_served_startup_guests()
	return _served_startup_guests.size()


func _get_served_guest_for_milestone(served_guest_count: int) -> NPCGuest:
	_track_served_startup_guests()
	var milestone_index := maxi(served_guest_count - 1, 0)
	if milestone_index >= _served_startup_guests.size():
		return null
	var guest := _served_startup_guests[milestone_index]
	if not is_instance_valid(guest):
		return null
	return guest


func _track_served_startup_guests() -> void:
	for guest in Global.NPCSpawner.guests:
		if guest is not NPCGuest:
			continue
		if not is_instance_valid(guest):
			continue
		if guest in _served_startup_guests:
			continue
		if guest.Item == null or guest.Item.current_item == null:
			continue
		_served_startup_guests.append(guest)
		guest.manual_behaviour = false

func _poll_until(condition: Callable) -> bool:
	while not _skip_requested and not condition.call():
		await get_tree().process_frame
	return _skip_requested


func _finish_startup_if_aborted(skip_layer: CanvasLayer, aborted: bool) -> bool:
	if not aborted:
		return false
	_finish_startup(skip_layer, true)
	return true


func _finish_startup(skip_layer: CanvasLayer, skipped := false) -> void:
	if skipped:
		_set_startup_money(STARTUP_SKIP_MONEY)
		for room in Building.query.all_rooms_of_type(RoomJunk).duplicate():
			Building.replace_with_empty(room)
		if is_instance_valid(_tutorial_worker):
			_tutorial_worker.global_position = TUTORIAL_WORKER_TARGET
			_tutorial_worker.Navigation.stop_navigation()
			_tutorial_worker.Behaviour.clear_behaviour()
	_tutorial_worker = null
	_destroy_menu_tutorial_arrow()
	Global.UI.menu.finish_tutorial_menu_gating()
	Global.UI.selection.set_context_menu_blocked(false)
	RoomStatusHandler.enabled = true
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").show()
	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true
	Global.UI.controls.hide()
	if is_instance_valid(skip_layer):
		skip_layer.queue_free()
	_skip_requested = false

func spawn_item_stack(item_type: Enum.Items, room_x: int, room_y: int, amount: int = 1) -> void:
	const COLS := 4
	const X_STEP := 5
	const X_HALF_STEP := 2
	const Y_STEP := 4
	var base_pos := Vector2(room_x * 48, room_y * -48 + 2)
	var col := 0
	var row := 0
	for i in amount:
		var row_offset_x := X_HALF_STEP * (row % 2)
		var item = Global.ItemSpawner.create(item_type, base_pos + Vector2(col * X_STEP + row_offset_x, -row * Y_STEP))
		item.rotation = -.75
		col += 1
		if col >= COLS:
			col = 0
			row += 1
