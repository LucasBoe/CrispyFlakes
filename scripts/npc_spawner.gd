extends Node2D

class_name NPCSpawner

const workerScene : PackedScene = preload("res://scenes/npcs/npc_worker.tscn");

func _ready():
	Global.NPCSpawner = self

func _process(delta):
	if Input.is_key_pressed(KEY_P):
		SpawnNewWorker()
		
func SpawnNewWorker():
	var worker = workerScene.instantiate()
	worker.global_position = Vector2(-320,0)
	add_child(worker)
