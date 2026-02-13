extends Node

var current_tier = 0
var max_tier = 3

signal tier_unlocked_signal

var tier_icons = [
	preload("res://assets/sprites/ui/icon_locked_1.png"),
	preload("res://assets/sprites/ui/icon_locked_2.png"),
	preload("res://assets/sprites/ui/icon_locked_3.png"),
	preload("res://assets/sprites/ui/icon_locked_4.png"),
]

var tier_visitors_needed = [
	0,
	5,
	10,
	15
]

func _ready():
	await get_tree().process_frame
	Global.NPCSpawner.spawned_guest_signal.connect(_on_spawned_guest)
	
func _on_spawned_guest(guest_count):
	if current_tier >= max_tier:
		return
		
	if tier_visitors_needed[current_tier+1] <= guest_count:
		current_tier = current_tier+1
		tier_unlocked_signal.emit(current_tier)
