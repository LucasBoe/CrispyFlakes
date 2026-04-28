extends Node

var done: bool = false


func _process(_delta: float) -> void:
	if done:
		return
	done = true

	var b: Node = Building
	b.set_room(b.room_data_bounty_board, -6, 0, false)
	b.set_room(b.room_data_table, -2, 0, false)
	b.set_room(b.room_data_bar, -1, 0, false)
	b.set_room(b.room_data_empty, 0, 0, false)
	b.set_room(b.room_data_well, 3, 0, false)
	b.set_room(b.room_data_stairs, 0, -1, false)
	b.set_room(b.room_data_junk, -1, -1, false)
	b.initialize_all_rooms()
	b.update_foreground_tiles()

	for i in 3:
		var look = NPCLookInfo.new_random()
		var bounty: int = randi_range(1, 5) * 10
		BountyHandler.create_bounty(look, bounty)
		
	ProgressionHandler.unlock_default_rooms()

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

	await LetterUIHandler.present()
	await TutorialHandler.do_first_tutorial()

	skip_layer.queue_free()

	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true
