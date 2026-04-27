extends Node

var done = false

func _process(delta):
	if done:
		return

	var b = Building
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
		var bounty = randi_range(1, 5) * 10
		BountyHandler.create_bounty(look, bounty)

	var starter_worker = Global.NPCSpawner.spawn_new_worker(Vector2(-72, 0))
	var positive_traits := TraitLibrary.get_all_traits().filter(func(t): return t.is_positive())
	positive_traits.shuffle()
	starter_worker.Traits.traits = [positive_traits[0]]
	starter_worker.apply_trait_conflict_preference()
	Global.UI.resources.show()
	Global.should_auto_spawn_guests = true

	done = true
