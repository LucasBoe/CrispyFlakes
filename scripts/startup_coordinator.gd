extends Node

const CLEANUP_TUTORIAL_TITLE := "What a shithole"
const BUILD_BAR_TUTORIAL_TITLE := "This place needs a Bar"
const SERVE_GUESTS_TUTORIAL_TITLE := "A new Beginning"
const BAR_PROGRESSION_ITEM := preload("res://assets/resources/progression/prog_bar.tres")
const ARROW_RED_DOWN_PATH := "res://assets/sprites/ui/2x/arrow_red_down.png"
const GOLDEN_GLOW_SHADER := preload("res://assets/shaders/golden_glow_red_replace.gdshader")
const STARTUP_WAIT_BEHAVIOUR := preload("res://scripts/npc/behaviours/startup_wait_behaviour.gd")
const CLEANUP_REWARD := 30
const BUILD_BAR_REWARD := 30
const SERVE_GUESTS_REWARD := 50
const SERVE_GUESTS_TARGET := 5
const TUTORIAL_WORKER_TARGET := Vector2(-128, 0)
const OUTSIDE_OVERLAY_FADE_DURATION := 1.0
const MENU_ARROW_OFFSET := Vector2(-2, -52)
const MENU_ARROW_HOVER_HEIGHT := 3.0
const MENU_ARROW_HOVER_DURATION := 0.5

var done: bool = false
var _menu_tutorial_arrow: TextureRect
var _menu_tutorial_arrow_hover_tween: Tween
var _menu_tutorial_arrow_material: ShaderMaterial
var _menu_tutorial_arrow_texture: Texture2D


func _process(_delta: float) -> void:
	if done:
		return
	done = true

	await _run_startup_sequence()

func _run_startup_sequence() -> void:
	setup_building()
	_reset_outside_overlay()
	spawn_bounties(3)
	spawn_item_stack(Enum.Items.WOOD, 3, 0, 10)
	ProgressionHandler.unlock_default_rooms()
	Global.should_auto_spawn_guests = false
	TutorialHandler.skip_requested = false
	TutorialHandler.clear_tasks()

	var skip_layer := create_skip_tutorial_button()

	RoomStatusHandler.enabled = false
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").hide()
	var tutorial_worker := await _spawn_tutorial_worker()
	if not TutorialHandler.skip_requested and is_instance_valid(tutorial_worker):
		await _run_worker_tutorial_sequence(tutorial_worker)

	_finish_startup(skip_layer)

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
		TutorialHandler.skip_requested = true
		LetterUIHandler.skip()
		Global.UI.dialogue.finish_dialogue()
		TutorialHandler.clear_tasks()
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

	await _fade_outside_overlay()
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

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.0, OUTSIDE_OVERLAY_FADE_DURATION)
	await tween.finished

	if is_instance_valid(overlay):
		overlay.visible = false


func _wait_for_menu_arrow_step(button: Button, completion_condition: Callable) -> bool:
	if button == null:
		return await _poll_until(completion_condition)

	_show_menu_tutorial_arrow(button)
	while not TutorialHandler.skip_requested and not completion_condition.call():
		_update_menu_tutorial_arrow_visibility()
		await get_tree().process_frame

	_destroy_menu_tutorial_arrow()
	return TutorialHandler.skip_requested


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
	_update_menu_tutorial_arrow_visibility()


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

func _run_worker_tutorial_sequence(worker: NPCWorker) -> void:
	var cleanup_task = _create_cleanup_tutorial(worker)
	var build_bar_task = _create_build_bar_tutorial(worker)
	var serve_guests_task = _create_serve_guests_tutorial(worker)

	TutorialHandler.reveal_tutorial(CLEANUP_TUTORIAL_TITLE)
	if await _wait_for_tutorial_activation(CLEANUP_TUTORIAL_TITLE):
		return
	cleanup_task.start()
	if await _wait_for_cleanup_completion(cleanup_task):
		return
	cleanup_task.set_done()
	TutorialHandler.complete_tutorial(CLEANUP_TUTORIAL_TITLE)
	if await _wait_for_tutorial_claim(CLEANUP_TUTORIAL_TITLE):
		return

	ProgressionHandler.add_points(BAR_PROGRESSION_ITEM.cost)
	TutorialHandler.reveal_tutorial(BUILD_BAR_TUTORIAL_TITLE)
	if await _wait_for_tutorial_activation(BUILD_BAR_TUTORIAL_TITLE):
		return
	build_bar_task.start()
	if await _wait_for_menu_arrow_step(
		Global.UI.menu.progression_button,
		func(): return ProgressionHandler.is_item_unlocked(BAR_PROGRESSION_ITEM)
	):
		return
	if await _wait_for_menu_arrow_step(
		Global.UI.menu.build_button,
		func(): return not Building.query.all_rooms_of_type(RoomBar).is_empty()
	):
		return
	if await _wait_for_bar_setup_completion(worker):
		return
	build_bar_task.set_done()
	TutorialHandler.complete_tutorial(BUILD_BAR_TUTORIAL_TITLE)
	if await _wait_for_tutorial_claim(BUILD_BAR_TUTORIAL_TITLE):
		return

	TutorialHandler.reveal_tutorial(SERVE_GUESTS_TUTORIAL_TITLE)
	if await _wait_for_tutorial_activation(SERVE_GUESTS_TUTORIAL_TITLE):
		return
	serve_guests_task.start()

	RoomStatusHandler.enabled = true
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").show()
	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true

	await _spawn_tutorial_guest_wave(SERVE_GUESTS_TARGET)
	if await _wait_for_served_guest_completion(serve_guests_task):
		return
	serve_guests_task.set_done()
	TutorialHandler.complete_tutorial(SERVE_GUESTS_TUTORIAL_TITLE)

func _create_cleanup_tutorial(worker: NPCWorker):
	TutorialHandler.create_tutorial(CLEANUP_TUTORIAL_TITLE, CLEANUP_REWARD, "30 $ Reward + 1 Point", TutorialHandler.TutorialPhase.HIDDEN, worker)
	TutorialHandler.set_tutorial_reveal_target(CLEANUP_TUTORIAL_TITLE, worker)
	return TutorialHandler.create_task(
		CLEANUP_TUTORIAL_TITLE,
		junk_text("Clean Up the Mess", 0, Building.query.all_rooms_of_type(RoomJunk).size()),
		[
			"Click and hold the worker",
			"Move it onto the junk to assign them for cleanup",
		]
	)

func _create_build_bar_tutorial(worker: NPCWorker):
	TutorialHandler.create_tutorial(BUILD_BAR_TUTORIAL_TITLE, BUILD_BAR_REWARD, "30 $ Reward", TutorialHandler.TutorialPhase.HIDDEN, worker)
	TutorialHandler.set_tutorial_reveal_target(BUILD_BAR_TUTORIAL_TITLE, worker)
	return TutorialHandler.create_task(
		BUILD_BAR_TUTORIAL_TITLE,
		"Build a Bar",
		[
			"Open the progression menu",
			"Unlock the bar",
			"Place the bar in an empty room",
			"Drop the worker onto the bar",
		]
	)

func _create_serve_guests_tutorial(worker: NPCWorker):
	TutorialHandler.create_tutorial(SERVE_GUESTS_TUTORIAL_TITLE, SERVE_GUESTS_REWARD, "50 $ Reward", TutorialHandler.TutorialPhase.HIDDEN, worker)
	TutorialHandler.set_tutorial_reveal_target(SERVE_GUESTS_TUTORIAL_TITLE, worker)
	return TutorialHandler.create_task(
		SERVE_GUESTS_TUTORIAL_TITLE,
		_serve_guest_text(0, SERVE_GUESTS_TARGET),
		[
			"Wait until 5 guests have had a drink",
		]
	)

func _wait_for_tutorial_activation(section_title: String) -> bool:
	return await _poll_until(func():
		var tutorial = TutorialHandler.get_tutorial(section_title)
		return tutorial != null and tutorial.phase == TutorialHandler.TutorialPhase.ACTIVE
	)

func _wait_for_tutorial_claim(section_title: String) -> bool:
	return await _poll_until(func(): return TutorialHandler.get_tutorial(section_title) == null)

func _wait_for_cleanup_completion(task) -> bool:
	var total_rooms: int = Building.query.all_rooms_of_type(RoomJunk).size()
	while not TutorialHandler.skip_requested:
		var missing_rooms: int = Building.query.all_rooms_of_type(RoomJunk).size()
		var cleaned_rooms: int = maxi(total_rooms - missing_rooms, 0)
		task.set_text(junk_text("Clean Up the Mess", cleaned_rooms, total_rooms))
		if missing_rooms == 0:
			return false
		await get_tree().process_frame
	return true

func _wait_for_bar_setup_completion(worker: NPCWorker) -> bool:
	return await _poll_until(func():
		var bars: Array = Building.query.all_rooms_of_type(RoomBar)
		return not bars.is_empty() and is_instance_valid(worker) and worker.current_job == Enum.Jobs.BAR and worker.current_job_room is RoomBar
	)

func _spawn_tutorial_guest_wave(count: int) -> void:
	for _guest_index in count:
		if TutorialHandler.skip_requested:
			return
		var guest := Global.NPCSpawner.spawn_new_guest() as NPCGuest
		if guest == null:
			continue
		guest.manual_behaviour = true
		await get_tree().process_frame
		if is_instance_valid(guest):
			guest.Behaviour.set_behaviour(NeedDrinkingBehaviour)

func _wait_for_served_guest_completion(task) -> bool:
	var served_guests: Array[NPCGuest] = []
	while not TutorialHandler.skip_requested:
		for guest in Global.NPCSpawner.guests:
			if guest is not NPCGuest:
				continue
			if not is_instance_valid(guest):
				continue
			if guest in served_guests:
				continue
			if guest.Item != null and guest.Item.current_item != null:
				served_guests.append(guest)
				guest.manual_behaviour = false
				task.set_text(_serve_guest_text(served_guests.size(), SERVE_GUESTS_TARGET))
		if served_guests.size() >= SERVE_GUESTS_TARGET:
			return false
		await get_tree().process_frame
	return true

func _serve_guest_text(amount_done: int, amount_needed: int) -> String:
	return "Serve %d Guests (%d/%d)" % [amount_needed, amount_done, amount_needed]

func _poll_until(condition: Callable) -> bool:
	while not TutorialHandler.skip_requested and not condition.call():
		await get_tree().process_frame
	return TutorialHandler.skip_requested

func _finish_startup(skip_layer: CanvasLayer) -> void:
	_destroy_menu_tutorial_arrow()
	RoomStatusHandler.enabled = true
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").show()
	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true
	if is_instance_valid(skip_layer):
		skip_layer.queue_free()
	TutorialHandler.skip_requested = false

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

func junk_text(text, amount_done, amount_needed):
	return str(text, " (", amount_done, "/", amount_needed, ")")
