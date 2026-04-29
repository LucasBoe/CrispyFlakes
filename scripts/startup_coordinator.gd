extends Node

var done: bool = false


func _process(_delta: float) -> void:
	if done:
		return
	done = true

	setup_building()
	spawn_bounties(3)
	spawn_item_stack(Enum.Items.WOOD, 3, 0, 10)
	ProgressionHandler.unlock_default_rooms()

	var skip_layer := create_skip_tutorial_button()

	RoomStatusHandler.enabled = false
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").hide()

	#await LetterUIHandler.present()
	#await TutorialHandler.do_first_tutorial()

	await get_tree().create_timer(1).timeout

	RoomStatusHandler.enabled = true
	Global.UI.resources.get_node("HBoxContainer/UIVisitorInfo").show()
	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true
	
	skip_layer.queue_free()

func spawn_bounties(count: int) -> void:
	for i in count:
		var look = NPCLookInfo.new_random()
		var bounty: int = randi_range(1, 5) * 10
		BountyHandler.create_bounty(look, bounty)

func setup_building() -> void:
	var b: Node = Building
	b.set_room(b.room_data_bounty_board, -6, 0, false)
	b.set_room(b.room_data_junk, -2, 0, false)
	b.set_room(b.room_data_bar, -1, 0, false)
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
