extends Area2D

class_name NPC

var Animator : AnimationModule;
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule

var spawn_time

func _ready():
	spawn_time = Time.get_ticks_usec()

func _input_event(viewport, event, shape_idx):
	if event.is_action_pressed("click"):	
		click_on_self();
		
func get_age():
	return Time.get_ticks_usec() - spawn_time
		
func click_on_self():
	print("npc click")
