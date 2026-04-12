extends Node2D

class_name NPCSpawner

const workerScene : PackedScene = preload("res://scenes/npcs/npc_worker.tscn");
const guestScene : PackedScene = preload("res://scenes/npcs/npc_guest.tscn")
const sheriffScene : PackedScene = preload("res://scenes/npcs/npc_sheriff.tscn")

var guests = []
var workers = []

var guests_per_day_rate = 3.0
var next_guest_progression = 0.0

signal spawned_guest_signal

func _init():
	Global.NPCSpawner = self

func _enter_tree():
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
	
	var available_bounties = BountyHandler.get_available_bounties()
	var active_bounty_count = BountyHandler.active_looks.size()
	var bounty_chance = 0.3 / (1.0 + active_bounty_count)
	if randf() < bounty_chance and available_bounties.size() > 0:
		var bounty_entry = available_bounties[randi_range(0, available_bounties.size() - 1)]
		BountyHandler.activate(bounty_entry.look)
		guest.init(bounty_entry.look)
	else:
		guest.init()
		while BountyHandler.is_look_similar_to_any_bounty(guest.look_info):
			guest.apply_look()

	guests.append(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, 1)
	spawned_guest_signal.emit(guests.size())

	var bouncer_room = Building.query.closest_room_of_type(RoomBouncer, guest.global_position) as RoomBouncer
	var has_active_bouncer := bouncer_room != null and bouncer_room.has_active_bouncer()
	if has_active_bouncer:
		guest.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)

	if randf() < 0.3:
		guest.force_behaviour(ArriveOnHorseBehaviour)
	elif has_active_bouncer:
		guest.force_behaviour(ArriveThroughBouncerBehaviour)

	return guest

func spawn_sheriff():
	var sheriff = sheriffScene.instantiate()
	sheriff.global_position = Vector2(-320, 0)
	add_child(sheriff)
	return sheriff

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
		elif adj == "horse":
			guest.force_behaviour(ArriveOnHorseBehaviour)

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
