extends Node2D

class_name NPCSpawner

const workerScene : PackedScene = preload("res://scenes/npcs/npc_worker.tscn");
const guestScene : PackedScene = preload("res://scenes/npcs/npc_guest.tscn")

var guests = []
var workers = []

var guests_per_day_rate = 3.0
var next_guest_progression = 0.0

signal spawned_guest_signal

func _ready():
	Global.NPCSpawner = self

func _process(delta):
	if Input.is_key_pressed(KEY_P):
		SpawnNewGuest()
		
	if not Global.should_auto_spawn_guests:
		return
		
	next_guest_progression += delta * (guests_per_day_rate / Global.DAY_DURATION)
	if next_guest_progression > 1.0:
		SpawnNewGuest()
		next_guest_progression = 0.0	
	
func SpawnNewWorker(opt_spawn_position = Vector2(-320,0)):
	var worker = workerScene.instantiate()
	worker.global_position = opt_spawn_position
	add_child(worker)
	
	workers.append(worker)
	return worker
	
func SpawnNewGuest():
	var guest = guestScene.instantiate()
	guest.global_position = Vector2(-320,0)
	add_child(guest)
	
	guests.append(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, 1)
	spawned_guest_signal.emit(guests.size())
	return guest

func on_guest_destroy(guest):
	guests.erase(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, -1)
