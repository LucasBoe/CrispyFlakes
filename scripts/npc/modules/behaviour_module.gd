extends Node

class_name BehaviourModule

@onready var behaviourHost = $Host;

var npc;
var has_behaviour = false

func _ready():
	npc = get_parent() as NPC
	if npc:
		pass
		
	npc.Behaviour = self
	
func clear_behaviour():
	if has_behaviour:
		var previous = behaviourHost.get_script()
		if previous is Behaviour:
			previous.isRunning = false
			
	behaviourHost.set_process(false)
	has_behaviour = false

func set_behaviour_from_job(job : Enum.Jobs):
	match job:
	
		Enum.Jobs.IDLE:
			set_behaviour(IdleBehaviour)
		
		Enum.Jobs.BREWERY:
			set_behaviour(JobBreweryBehaviour)
			
		Enum.Jobs.BAR:
			set_behaviour(JobBarBehaviour)
	
func set_behaviour(behaviour):
	
	if has_behaviour:
		var previous = behaviourHost.get_script()
		if previous is Behaviour:
			previous.isRunning = false
			
	behaviourHost.set_script(behaviour)
	(behaviourHost as Behaviour).npc = npc
	behaviourHost.set_process(true)
	has_behaviour = true
	
