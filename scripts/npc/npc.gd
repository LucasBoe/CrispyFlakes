extends Area2D

class_name NPC

var Animator : AnimationModule;
var Tint : TintModule
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule

func _init():
	Tint = TintModule.new(self)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
		
func _on_mouse_entered():
	HoverHandler.notify_hover_enter(self)
	
func _on_mouse_exited():
	HoverHandler.notify_hover_exit(self)
		
func click_on():
	print("npc click")
	
func force_behaviour(new_behaviour): 
	return Behaviour.set_behaviour(new_behaviour)

func destroy():
	NPCEventHandler.on_destroy_npc_signal.emit(self)
	queue_free()
