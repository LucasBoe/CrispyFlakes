extends Node2D

class_name NPCSpawner

const workerScene : PackedScene = preload("res://scenes/npcs/npc_worker.tscn");
const guestScene : PackedScene = preload("res://scenes/npcs/npc_guest.tscn")

var guests = []

func _ready():
	Global.NPCSpawner = self

func _process(delta):
	if Input.is_key_pressed(KEY_P):
		if randf() < .5:
			SpawnNewWorker()
		else:
			SpawnNewGuest()
		
func SpawnNewWorker():
	var worker = workerScene.instantiate()
	worker.global_position = Vector2(-320,0)
	add_child(worker)
	
func SpawnNewGuest():
	var guest = guestScene.instantiate()
	guest.global_position = Vector2(-320,0)
	add_child(guest)
	
	guests.append(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, 1)

func on_guest_destroy(guest):
	guests.erase(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, -1)
