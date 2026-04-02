extends Node2D

class_name NPCSpawner

const workerScene : PackedScene = preload("res://scenes/npcs/npc_worker.tscn");
const guestScene : PackedScene = preload("res://scenes/npcs/npc_guest.tscn")

var guests = []
var workers = []

var guests_per_day_rate = 3.0
var next_guest_progression = 0.0

signal spawned_guest_signal

func _init():
	Global.NPCSpawner = self

func _ready():
	Console.add_command("guest", console_spawn_guest, ["adjective"])
	Console.add_command("guests", console_spawn_guests, ["amount", "adjective"], 1)
	Console.add_command("worker", console_spawn_worker)
	Console.add_command("workers", console_spawn_workers, ["amount"])

func _process(delta):
	if not Global.should_auto_spawn_guests:
		return

	next_guest_progression += delta * (guests_per_day_rate / Global.DAY_DURATION)
	if next_guest_progression > 1.0:
		spawn_new_guest()
		next_guest_progression = 0.0

func spawn_new_worker(opt_spawn_position = Vector2(-320,0)):
	var worker = workerScene.instantiate()
	worker.global_position = opt_spawn_position
	add_child(worker)

	workers.append(worker)
	return worker

func spawn_new_guest():
	print("spawn_new_guest")

	var guest = guestScene.instantiate() as NPCGuest
	guest.global_position = Vector2(-320,0)
	add_child(guest)
	
	var available_wanted = WantedHandler.get_available_wanted_npcs()
	if randf() < 0.1 and available_wanted.size() > 0:
		var wanted = available_wanted[randi_range(0, available_wanted.size() - 1)]
		WantedHandler.activate(wanted.look)
		guest.init(wanted.look)
	else:
		guest.init()
		while WantedHandler.is_look_similar_to_any_wanted(guest.look_info):
			guest.apply_look()

	guests.append(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, 1)
	spawned_guest_signal.emit(guests.size())
	return guest

func on_guest_destroy(guest):
	guests.erase(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, -1)

## CONSOLE ##
func console_spawn_guest(adj):
	print("spawn_guest ", adj)
	var guest = spawn_new_guest() as NPCGuest

	if adj and adj != "":
		if adj == "drunk":
			guest.Needs.drunkenness.strength = .5

func console_spawn_guests(amount, adj):
	print("spawn_guests", amount)
	for i in amount.to_int():
		console_spawn_guest(adj)

func console_spawn_worker():
	print("spawn_worker")
	var _worker = spawn_new_worker() as NPCWorker

func console_spawn_workers(amount):
	print("spawn_workers ", amount)
	for i in amount.to_int():
		console_spawn_worker()
