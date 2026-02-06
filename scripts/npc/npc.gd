extends Area2D

class_name NPC

var Animator : AnimationModule;
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule

var spawn_time

func _ready():
	spawn_time = Time.get_ticks_usec()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
		
func _on_mouse_entered():
	HoverHandler.notify_hover_enter(self)
	
func _on_mouse_exited():
	HoverHandler.notify_hover_exit(self)
		
func get_age():
	return Time.get_ticks_usec() - spawn_time
		
func click_on():
	print("npc click")
