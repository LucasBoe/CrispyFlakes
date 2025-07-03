extends Area2D

class_name NPC

var Animator : AnimationModule;
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule

func _input_event(viewport, event, shape_idx):
	if event.is_action_pressed("click"):	
		click_on_self();
		
func click_on_self():
	print("npc click")
