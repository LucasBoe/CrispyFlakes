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

	await LetterUIHandler.present()
	await TutorialHandler.do_first_tutorial()
	
	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true
