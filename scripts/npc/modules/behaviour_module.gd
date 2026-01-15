extends Node

class_name BehaviourModule

@onready var behaviourHost = $Host;

var npc
var behaviour_instance = null
var has_behaviour = false

func _ready():
	npc = get_parent() as NPC
	if npc:
		pass
		
	npc.Behaviour = self

func set_behaviour_from_job(job : Enum.Jobs):
	set_behaviour(Enum.job_to_behaviour(job))
	
func set_behaviour(behaviour):	
	clear_behaviour()
			
	behaviourHost.set_script(behaviour)
	
	behaviour_instance = (behaviourHost as Behaviour)
	behaviour_instance.npc = npc
	
	behaviourHost.set_process(true)
	has_behaviour = true
	
func clear_behaviour():
	
	if behaviour_instance != null:
		behaviour_instance.stop_loop()
		behaviour_instance.is_running = false
		
	behaviourHost.set_process(false)
	behaviourHost.set_script(null)
	behaviour_instance = null
	has_behaviour = false
