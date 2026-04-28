extends Node

signal tasks_changed
signal tutorial_finished

var skip_requested: bool = false


func _poll_until(condition: Callable) -> bool:
	while not condition.call() and not skip_requested:
		await get_tree().process_frame
	return skip_requested


class TutorialTask:
	extends RefCounted

	var _handler
	var section_title: String
	var text: String
	var hints: Array[String] = []
	var is_started: bool = false
	var is_done: bool = false

	func _init(handler, new_section_title: String, new_text: String, new_hints: Array[String] = []):
		_handler = handler
		section_title = new_section_title
		text = new_text
		hints = new_hints.duplicate()

	func start() -> void:
		if is_started:
			return
		is_started = true
		_handler._notify_tasks_changed()

	func finish() -> void:
		if is_done:
			return
		is_started = true
		is_done = true
		_handler._notify_tasks_changed()

	func set_done(done := true) -> void:
		is_started = true
		is_done = done
		_handler._notify_tasks_changed()

	func set_text(new_text: String) -> void:
		if text == new_text:
			return
		text = new_text
		_handler._notify_tasks_changed()


var tasks: Array[TutorialTask] = []


func create_task(section_title: String, text: String, hints: Array[String] = []) -> TutorialTask:
	var task := TutorialTask.new(self, section_title, text, hints)
	tasks.append(task)
	_notify_tasks_changed()
	return task


func clear_tasks() -> void:
	tasks.clear()
	_notify_tasks_changed()


func get_current_section_title() -> String:
	for task in tasks:
		if task.is_started and not task.is_done:
			return task.section_title

	for i in range(tasks.size() - 1, -1, -1):
		var task = tasks[i]
		if task.is_started or task.is_done:
			return task.section_title

	return ""


func get_section_tasks(section_title: String) -> Array[TutorialTask]:
	if section_title.is_empty():
		return []

	var section_tasks: Array[TutorialTask] = []
	for task in tasks:
		if task.section_title == section_title:
			section_tasks.append(task)
	return section_tasks


func _notify_tasks_changed() -> void:
	tasks_changed.emit()


func do_first_tutorial():
	skip_requested = false
	clear_tasks()

	var hire_worker_task = TutorialHandler.create_task("A new Beginning", "Hire a new worker", ["click on guest","click hire from contex menu"])
	var asign_job_task = TutorialHandler.create_task("A new Beginning", "Asign a job to your worker", ["click and hold LMB to pick up worker","drop worker to valid room"])

	var tutorial_guest = Global.NPCSpawner.spawn_new_guest() as NPCGuest
	var positive_traits := TraitLibrary.get_all_traits().filter(func(t): return t.is_positive())
	positive_traits.shuffle()
	tutorial_guest.Traits.traits = [positive_traits[0]]
	tutorial_guest.manual_behaviour = true
	tutorial_guest.Behaviour.set_behaviour(NeedDrinkingBehaviour)
	await get_tree().process_frame

	var reached_bar := [false]
	if is_instance_valid(tutorial_guest):
		tutorial_guest.Navigation.target_reached_signal.connect(func(): reached_bar[0] = true, CONNECT_ONE_SHOT)
		if await _poll_until(func(): return reached_bar[0] or not is_instance_valid(tutorial_guest)):
			return
	if is_instance_valid(tutorial_guest):
		await Global.UI.dialogue.print_dialogue("This was such a nice place long ago what a shame...", tutorial_guest)
	if skip_requested:
		return

	hire_worker_task.start()
	if await _poll_until(func(): return Global.NPCSpawner.workers.size() > 0):
		return
	hire_worker_task.finish()

	asign_job_task.start()
	if await _poll_until(func(): return Global.NPCSpawner.workers.any(func(w: NPCWorker): return w.current_job == Enum.Jobs.BAR)):
		return
	asign_job_task.finish()

	var inspect_guest = Global.NPCSpawner.spawn_new_guest() as NPCGuest
	inspect_guest.manual_behaviour = true
	await get_tree().process_frame
	inspect_guest.Behaviour.set_behaviour(IdleBehaviour)

	var guest_clicked := [false]
	var click_conn := func(node: Node): if node is NPCGuest: guest_clicked[0] = true
	HoverHandler.click_hovered_node_signal.connect(click_conn)
	var check_needs_task = TutorialHandler.create_task("A new Beginning", "Click on a guest to inspect their needs", ["left-click on any guest"])
	check_needs_task.start()
	if await _poll_until(func(): return guest_clicked[0]):
		HoverHandler.click_hovered_node_signal.disconnect(click_conn)
		return
	HoverHandler.click_hovered_node_signal.disconnect(click_conn)
	check_needs_task.finish()

	inspect_guest.manual_behaviour = false

	var wait_for_drink_task = TutorialHandler.create_task("A new Beginning", "Wait for the guest to receive their drink")
	wait_for_drink_task.start()
	if await _poll_until(func(): return Global.NPCSpawner.guests.any(npc_has_item)):
		return
	wait_for_drink_task.finish()

	var build_table_task = TutorialHandler.create_task("A new Beginning", "Build a Table so guests have somewhere to sit", ["open the Build menu", "find Tables under Furniture"])
	build_table_task.start()
	if await _poll_until(func(): return Building.query.all_rooms_of_type(RoomTable).size() > 0):
		return
	build_table_task.finish()

	Global.should_auto_spawn_guests = true

	var open_workers_task = TutorialHandler.create_task("A new Beginning", "Open the Workers panel to manage your staff", ["click the Workers button in the menu"])
	open_workers_task.start()
	TimeHandler.set_time(0)
	if await _poll_until(func(): return Global.UI.menu.worker_tab.visible):
		TimeHandler.set_time(1)
		return
	TimeHandler.set_time(1)
	open_workers_task.finish()
	clear_tasks()
	tutorial_finished.emit()

# this function is deprecated but for some lookup it MIGHT be useful or not since a lot of stuff has changed since then
func start_tutorial():
	pass
	#Global.UI.resources.hide()
	#ResourceHandler.change_resource(Enum.Resources.MONEY, 100)
	#Global.UI.menu.hide()
	#for button : Button in Global.UI.menu.build_tab.all_buttons:
		#button.disabled = true
	#
	#var tutorial_worker = Global.NPCSpawner.spawn_new_worker(Vector2(-72,0)) as NPCWorker
	#await get_tree().create_timer(2).timeout
	#await Global.UI.dialogue.print_dialogue("Oh boi, what a mess uncle jack left here.", tutorial_worker)
	#
	#var total_rooms = Building.query.all_rooms_of_type(RoomJunk).size()
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
		#missing_rooms = Building.query.all_rooms_of_type(RoomJunk).size()
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
	#var tutorial_guest = Global.NPCSpawner.spawn_new_guest() as NPCGuest
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
	#var bar = Building.query.all_rooms_of_type(RoomBar)[0]
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
		#if not speed_up_todo.is_done:
			#if Engine.time_scale > 1:
				#speed_up_todo.set_done()
		#await end_of_frame()
		#
	#wait_for_drink_todo.set_done()
	#await Global.UI.dialogue.print_dialogue("This here water? You tryin' to finish me off? I need somethin' with a kick to make it through that desert.", tutorial_guest)
	#Global.UI.tutorial.clear_tasks()
	#
	#tutorial_guest.Item.drop_current()
	#tutorial_guest.Behaviour.clear_behaviour()
	#tutorial_guest.set_process(false)
	##tutorial_guest.Behaviour.set_behaviour(NeedDrinkingBehaviour)
	#
	#Global.UI.menu.build_tab.storage_button.disabled = false
	#Global.UI.menu.build_tab.brewery_button.disabled = false
	#Global.UI.menu.show()
	#
	#var brewery_todo = Global.UI.tutorial.add_task("Build a Brewery")
	#var storage_todo = Global.UI.tutorial.add_task("Build a Storage")
	#var beer_bar_todo = Global.UI.tutorial.add_task("Upgrade the bar to sell Beer")
	#
	#while not beer_bar_todo.is_done or not brewery_todo.is_done or not storage_todo.is_done:
		#if not beer_bar_todo.is_done:
			#if Building.query.all_rooms_of_type(RoomBar).any(bar_has_beer):
				#beer_bar_todo.set_done()
		#if not brewery_todo.is_done:
			#if Building.query.all_rooms_of_type(RoomBrewery).size() > 0:
				#brewery_todo.set_done()
		#if not storage_todo.is_done:
			#if Building.query.all_rooms_of_type(RoomStorage).size() > 0:
				#storage_todo.set_done()
		#await end_of_frame()
		#
	#await Global.UI.dialogue.print_dialogue("That's a whole heap for one pair of hands. Gear up and hire some help.", tutorial_guest)
	#
	#Global.UI.tutorial.clear_tasks()
	#
	#var hire_todo = Global.UI.tutorial.add_task("Hire a new worker")
	#var asign_todo = Global.UI.tutorial.add_task("Asign it to the brewery")
	#
	#while Global.NPCSpawner.workers.size() < 2:
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


func junk_text(text, amount_done, amount_needed):
	return str(text, " (", amount_done, "/", amount_needed, ")")

func worker_is_working_at_bar(worker : NPCWorker):
	return worker.Behaviour.behaviour_instance is JobBarBehaviour

func worker_is_working_at_bar_or_brewery(worker : NPCWorker):
	var bi = worker.Behaviour.behaviour_instance
	return bi is JobBarBehaviour or bi is JobBreweryBehaviour

func npc_has_item(npc : NPC):
	return npc.Item.current_item

func npc_has_beer(npc : NPC):
	return npc.Item.current_item and npc.Item.current_item.itemType == Enum.Items.BEER_BARREL

func bar_has_beer(bar : RoomBar):
	return bar.drink_type == Enum.Items.BEER_BARREL

func end_of_frame():
	await get_tree().process_frame
