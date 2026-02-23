extends Node

var Building : Building
var ItemSpawner : ItemSpawner
var NPCSpawner : NPCSpawner
var UI : UIHolder

var should_auto_spawn_guests = false

const DAY_DURATION = 60.0

var time_now: float = 0.0

func _physics_process(delta: float) -> void:
	time_now += delta
