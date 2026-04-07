extends Area2D

class_name NPC

var Animator : AnimationModule;
var Tint : TintModule
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule


var look_info : NPCLookInfo
var strength: float = 0.5
var agility: float = 0.5
var intelligence: float = 0.5
var stamina: float = 1.0
var health: float = 1.0

const STAMINA_DRAIN = 0.08
const STAMINA_REGEN = 0.05

func _init():
	Tint = TintModule.new(self)

func _ready():
	strength = randf_range(0.3, 1.0)
	agility = randf_range(0.3, 1.0)
	intelligence = randf_range(0.3, 1.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
		
func _on_mouse_entered():
	HoverHandler.notify_hover_enter(self)
	
func _on_mouse_exited():
	HoverHandler.notify_hover_exit(self)
		
func _process(delta):
	var in_fight = Behaviour != null and (Behaviour.behaviour_instance is FightBehaviour or Behaviour.behaviour_instance is StopFightBehaviour)
	if in_fight:
		stamina = max(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = min(1.0, stamina + STAMINA_REGEN * delta)

func click_on():
	print("npc click")
	
func force_behaviour(new_behaviour): 
	return Behaviour.set_behaviour(new_behaviour)

func destroy():
	NPCEventHandler.on_destroy_npc_signal.emit(self)
	queue_free()
