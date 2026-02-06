extends Node

signal sold_beer

func start_tutorial():
	Global.should_auto_spawn_guests = true
	#Global.UI.resources.hide()
	#ResourceHandler.change_resource(Enum.Resources.MONEY, 100000)
	#Global.UI.menu.hide()
	#for button : Button in Global.UI.menu.build_tab.all_buttons:
		#button.disabled = true
	#
	#var tutorial_worker = Global.NPCSpawner.SpawnNewWorker(Vector2(-72,0)) as NPCWorker
	#await get_tree().create_timer(2).timeout
	#await Global.UI.dialogue.print_dialogue("Oh boi, what a mess uncle jack left here.", tutorial_worker)
	#
	#var total_rooms = Global.Building.get_all_rooms_of_type(RoomJunk).size()
	#
	#var asign_junk = Global.UI.tutorial.add_task("Use drag and drop to asign workers to rooms")
	#var clean_text = "Clean out all rooms full of junk"
	#var clean_junk = Global.UI.tutorial.add_task(junk_text(clean_text, 0, total_rooms))
	#
	#while tutorial_worker.Behaviour.behaviour_instance is not JobJunkBehaviour:
		#await end_of_frame()
		#
	#asign_junk.set_done()
	#
	#var missing_rooms = total_rooms
	#
	#while missing_rooms > 0:
		#missing_rooms = Global.Building.get_all_rooms_of_type(RoomJunk).size()
		#clean_junk.set_text(junk_text(clean_text, total_rooms - missing_rooms, total_rooms))
		#await end_of_frame()
	#
	#clean_junk.set_done()
	#
	#await Global.UI.dialogue.print_dialogue("That was easier that I thought. Now I'm ready... to wait for guests.", tutorial_worker)
	#
	#Global.UI.tutorial.clear_tasks()
	#
	#var wait_for_guests = Global.UI.tutorial.add_task("Wait for guests")
	#
	#var tutorial_guest = Global.NPCSpawner.SpawnNewGuest() as NPCGuest
	#tutorial_guest.manual_behaviour = true
	#await get_tree().process_frame
	#tutorial_guest.Behaviour.set_behaviour(NeedDrinkingBehaviour)
	#await tutorial_guest.Navigation.target_reached_signal
	#
	#wait_for_guests.set_done()
	#await Global.UI.dialogue.print_dialogue("Howdy, partner. I'm parched. Get over here and pour me somethin', would ya?", tutorial_guest)
	#Global.UI.tutorial.clear_tasks()
	#var asign_worker = Global.UI.tutorial.add_task("Assign a worker to the bar")
	#
	#var bar =  Global.Building.get_all_rooms_of_type(RoomBar)[0]
	#var room_highlight_rect = RoomHighlighter.request_rect(bar)
	#var workers = Global.NPCSpawner.workers
	#while not workers.any(worker_is_working_at_bar):		
		#await end_of_frame()
		#
	#RoomHighlighter.dispose(room_highlight_rect)
	#asign_worker.set_done()
	#
	#var wait_for_drink_todo = Global.UI.tutorial.add_task("Wait for worker to pour drink")
	#var speed_up_todo = Global.UI.tutorial.add_task("(Opt.) Speed up the time")
	#
	#while not Global.NPCSpawner.guests.any(npc_has_item):
		#
		#if not speed_up_todo.is_done:
			#if 	Engine.time_scale > 1:
				#speed_up_todo.set_done()
		#
		#await end_of_frame()
		#
	#wait_for_drink_todo.set_done()
	#await Global.UI.dialogue.print_dialogue("This here water? You tryin' to finish me off? I need somethin' with a kick to make it through that desert.", tutorial_guest)
	#Global.UI.tutorial.clear_tasks()
	#
	#tutorial_guest.Item.DropCurrent()
	#tutorial_guest.Behaviour.clear_behaviour()
	#tutorial_guest.set_process(false)
	##tutorial_guest.Behaviour.set_behaviour(NeedDrinkingBehaviour)
	#
	#Global.UI.menu.build_tab.buttery_button.disabled = false
	#Global.UI.menu.build_tab.brewery_button.disabled = false
	#Global.UI.menu.show()
	#
	#var brewery_todo = Global.UI.tutorial.add_task("Build a Brewery")
	#var buttery_todo = Global.UI.tutorial.add_task("Build a Buttery")
	#var beer_bar_todo = Global.UI.tutorial.add_task("Upgrade the bar to sell Beer")
	#
	#while not beer_bar_todo.is_done or not brewery_todo.is_done or not buttery_todo.is_done:
		#
		#if not beer_bar_todo.is_done:
			#if Global.Building.get_all_rooms_of_type(RoomBar).any(bar_has_beer):
				#beer_bar_todo.set_done()
				#
		#if not brewery_todo.is_done:
			#if Global.Building.get_all_rooms_of_type(RoomBrewery).size() > 0:
				#brewery_todo.set_done()
				#
		#if not buttery_todo.is_done:
			#if Global.Building.get_all_rooms_of_type(RoomButtery).size() > 0:
				#buttery_todo.set_done()
		#
		#await end_of_frame()
		#
	#await Global.UI.dialogue.print_dialogue("That's a whole heap for one pair of hands. Gear up and hire some help.", tutorial_guest)
		#
	#Global.UI.tutorial.clear_tasks()	
	#
	#var hire_todo = Global.UI.tutorial.add_task("Hire a new worker")
	#var asign_todo = Global.UI.tutorial.add_task("Asign it to the brewery")
	#
	#while Global.NPCSpawner.workers.size() <2:
		#await end_of_frame()
		#
	#hire_todo.set_done()
	#
	#while not workers.all(worker_is_working_at_bar_or_brewery):		
		#await end_of_frame()
	#
	#asign_todo.set_done()
	#
	#var guest_beer = Global.UI.tutorial.add_task("Wait for your guest to get his first beer")
	#
	#while workers.any(npc_has_beer):
		#await end_of_frame()
	#
	#tutorial_guest.Behaviour.set_behaviour(NeedDrinkingBehaviour)
	#tutorial_guest.set_process(true)
	#
	#await npc_has_item(tutorial_guest)
	#guest_beer.set_done()
	#
	#await Global.UI.dialogue.print_dialogue("Much obliged. I'll spread the word to my cowpoke pals and this place'll be hummin' in no time. Now show me how to run this place, yeah?", tutorial_guest)
#
	#ResourceHandler.change_resource(Enum.Resources.MONEY, -(ResourceHandler.resources[Enum.Resources.MONEY] - 100))
	#Global.UI.resources.show()
	#Global.should_auto_spawn_guests = true
	#tutorial_guest.manual_behaviour = false
	#
	#for button : Button in Global.UI.menu.build_tab.all_buttons:
		#button.disabled = false
	#
	#var sell_beer
	#
	#for i in 30:
		#Global.UI.tutorial.clear_tasks()
		#sell_beer = Global.UI.tutorial.add_task(str("Sell ", 30, " Beer (", i,")"))
		#await sold_beer
		#
	#sell_beer.set_done()
	
func junk_text(text, amount_done, amount_needed):
	return str(text, " (", amount_done, "/",amount_needed,")")
	
func try_notify_sold_beer():
	sold_beer.emit()
	
func worker_is_working_at_bar(worker : NPCWorker):
	return worker.Behaviour.behaviour_instance is JobBarBehaviour
	
func worker_is_working_at_bar_or_brewery(worker : NPCWorker):
	var bi = worker.Behaviour.behaviour_instance
	return bi is JobBarBehaviour or bi is JobBreweryBehaviour

func npc_has_item(npc : NPC):
	return npc.Item.currentItem
	
func npc_has_beer(npc : NPC):
	return npc.Item.currentItem and npc.Item.currentItem.itemType == Enum.Items.BEER_BARREL
	
func bar_has_beer(bar : RoomBar):
	return bar.drink_type == Enum.Items.BEER_BARREL

func end_of_frame():
	await get_tree().process_frame
